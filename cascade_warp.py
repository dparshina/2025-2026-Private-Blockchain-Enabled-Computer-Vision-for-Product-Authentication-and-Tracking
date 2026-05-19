from __future__ import annotations

from pathlib import Path
import warnings

import cv2
import numpy as np

warnings.filterwarnings("ignore")

def _estimate_module_size(gray, default=10.0):
    h, w = gray.shape
    estimates = []
    for frac in [0.3, 0.4, 0.5, 0.6, 0.7]:
        for axis in (0, 1):
            line = gray[int(h * frac), :] if axis == 0 else gray[:, int(w * frac)]
            line = np.convolve(line.astype(np.float32), np.ones(3) / 3, mode="same")
            transitions = np.where(np.diff((line < line.mean()).astype(int)))[0]
            if len(transitions) < 10:
                continue
            small_gap = np.percentile(np.diff(transitions), 25)
            if 2 < small_gap < 50:
                estimates.append(small_gap)
    if len(estimates) < 3:
        return default
    arr = np.array(estimates)
    if arr.std() / max(arr.mean(), 1e-6) > 0.3:
        return default
    return float(np.median(arr))

def _remove_small_components(binary, module_px):
    min_area = max(4, int((module_px * 0.3) ** 2))
    out = np.zeros_like(binary)
    n, labels, stats_, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    for label in range(1, n):
        if stats_[label, cv2.CC_STAT_AREA] >= min_area:
            out[labels == label] = 255
    return out

def _is_quad_sane(pts, shape, tol=0.5):
    h, w = shape
    pts = np.asarray(pts).reshape(-1, 2)
    if len(pts) < 4:
        return False
    slack = max(h, w) * 0.05
    if (pts[:, 0] < -slack).any() or (pts[:, 0] > w + slack).any():
        return False
    if (pts[:, 1] < -slack).any() or (pts[:, 1] > h + slack).any():
        return False
    d1 = np.linalg.norm(pts[1] - pts[0])
    d2 = np.linalg.norm(pts[3] - pts[0])
    if max(d1, d2) / max(min(d1, d2), 1) > 1 + tol:
        return False
    return True

def _process_metal_heavy(gray):
    bg = cv2.GaussianBlur(gray.astype(np.float32), (0, 0), sigmaX=gray.shape[1] // 6)
    bg = np.clip(bg, 1, None)
    normalized = np.clip((gray.astype(np.float32) / bg) * 128, 0, 255).astype(np.uint8)
    p1 = cv2.fastNlMeansDenoising(normalized, h=30,
                                   templateWindowSize=7, searchWindowSize=35)
    p2 = cv2.bilateralFilter(p1, d=7, sigmaColor=50, sigmaSpace=50)
    lo, hi = np.percentile(p2, 5), np.percentile(p2, 95)
    stretched = np.clip((p2.astype(np.float32) - lo) / (hi - lo) * 255, 0, 255).astype(np.uint8)
    ms = _estimate_module_size(stretched)
    k = max(3, int(ms * 0.4)) | 1
    smoothed = cv2.medianBlur(stretched, k)
    otsu_t, _ = cv2.threshold(smoothed, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    _, binary = cv2.threshold(smoothed, otsu_t * 0.85, 255, cv2.THRESH_BINARY_INV)
    open_k = max(2, int(ms * 0.3))
    close_k = max(2, int(ms * 0.2))
    cleaned = cv2.morphologyEx(binary, cv2.MORPH_OPEN, np.ones((open_k, open_k), np.uint8))
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, np.ones((close_k, close_k), np.uint8))
    cleaned = _remove_small_components(cleaned, ms)
    return cleaned, ms

def _stage_user(gray):
    binary, ms = _process_metal_heavy(gray)
    inv = 255 - binary
    det = cv2.QRCodeDetector()
    ok, pts = det.detect(inv)
    method = "user_cv2"
    if not ok or pts is None:
        eq = cv2.equalizeHist(inv)
        ok, pts = det.detect(eq)
        method = "user_cv2_eq"
    if not ok or pts is None:
        return None, "fail_user", ms
    pts = np.asarray(pts).reshape(-1, 2)
    if not _is_quad_sane(pts, binary.shape):
        return None, "fail_user_quad", ms
    return pts, method, ms, binary.shape

def _process_metal_light(gray):
    sigma = max(gray.shape[1] // 10, 20)
    bg = cv2.GaussianBlur(gray.astype(np.float32), (0, 0), sigmaX=sigma)
    bg = np.clip(bg, 1, None)
    normalized = np.clip((gray.astype(np.float32) / bg) * 128, 0, 255).astype(np.uint8)
    den = cv2.fastNlMeansDenoising(normalized, h=12,
                                    templateWindowSize=7, searchWindowSize=21)
    den = cv2.bilateralFilter(den, d=5, sigmaColor=40, sigmaSpace=40)
    ms = _estimate_module_size(den)
    k = max(3, int(ms * 0.15)) | 1
    smoothed = cv2.medianBlur(den, k)
    _, binary = cv2.threshold(smoothed, 0, 255,
                               cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    close_k = max(3, int(ms * 0.2))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE,
                                np.ones((close_k, close_k), np.uint8))
    return binary, ms

def _find_finders_manual(binary, ms):
    contours, hierarchy = cv2.findContours(binary, cv2.RETR_TREE,
                                            cv2.CHAIN_APPROX_SIMPLE)
    if hierarchy is None:
        return None
    h, w = binary.shape
    img_area = h * w
    cands = []
    for cnt in contours:
        a = cv2.contourArea(cnt)
        if a < 0.003 * img_area or a > 0.10 * img_area:
            continue
        x, y, bw, bh = cv2.boundingRect(cnt)
        if abs(bw - bh) > 0.35 * max(bw, bh):
            continue
        cy, cx = y + bh / 2.0, x + bw / 2.0
        cands.append((cy, cx, a))
    if len(cands) < 3:
        return None
    cands.sort(key=lambda t: -t[2])
    used = [False] * len(cands)
    groups = []
    for i, c1 in enumerate(cands):
        if used[i]: continue
        grp = [c1]; used[i] = True
        for j in range(i + 1, len(cands)):
            if used[j]: continue
            c2 = cands[j]
            if abs(c1[0] - c2[0]) < ms * 2 and abs(c1[1] - c2[1]) < ms * 2:
                grp.append(c2); used[j] = True
        ys = [c[0] for c in grp]
        xs = [c[1] for c in grp]
        groups.append((np.mean(ys), np.mean(xs), max(c[2] for c in grp)))
    if len(groups) < 3:
        return None
    groups.sort(key=lambda t: -t[2])
    top = groups[:3]
    centers = np.array([(g[0], g[1]) for g in top])
    tl_i = int(np.argmin(centers[:, 0] + centers[:, 1]))
    tr_i = int(np.argmax(centers[:, 1] - centers[:, 0]))
    bl_i = int(np.argmax(centers[:, 0] - centers[:, 1]))
    if len({tl_i, tr_i, bl_i}) != 3:
        return None
    tl = centers[tl_i]; tr = centers[tr_i]; bl = centers[bl_i]
    br = tr + (bl - tl)
    pts = np.array([[tl[1], tl[0]],
                     [tr[1], tr[0]],
                     [br[1], br[0]],
                     [bl[1], bl[0]]], dtype="float32")
    delta = ms * 3.5
    pts[0] += [-delta, -delta]
    pts[1] += [+delta, -delta]
    pts[2] += [+delta, +delta]
    pts[3] += [-delta, +delta]
    return pts

def _stage_v2(gray):
    binary, ms = _process_metal_light(gray)

    det = cv2.QRCodeDetector()
    ok, pts = det.detect(binary)
    if not ok or pts is None:
        ok, pts = det.detect(gray)
    if ok and pts is not None:
        pts = np.asarray(pts).reshape(-1, 2)
        if _is_quad_sane(pts, binary.shape):
            return pts, "v2_cv2", ms, binary.shape

    try:
        wdet = cv2.wechat_qrcode_WeChatQRCode()
        _, wpts = wdet.detectAndDecode(gray)
        if wpts is not None and len(wpts) > 0:
            pts = np.array(wpts[0], dtype="float32")
            if _is_quad_sane(pts, gray.shape):
                return pts, "v2_wechat", ms, gray.shape
    except (AttributeError, cv2.error):
        pass

    pts = _find_finders_manual(binary, ms)
    if pts is not None and _is_quad_sane(pts, binary.shape):
        return pts, "v2_manual", ms, binary.shape

    return None, "fail_v2", ms, binary.shape

def cascade_warp(image_path, return_color=False):
    image_path = Path(image_path)
    raw_color = cv2.imread(str(image_path))
    if raw_color is None:
        return None, {"success": False, "method": "cannot_read",
                       "ms_est": 0, "out_size": None, "input_shape": None}

    gray = cv2.cvtColor(raw_color, cv2.COLOR_BGR2GRAY)
    orig_h, orig_w = gray.shape

    result_a = _stage_user(gray)
    if result_a[0] is not None:
        pts, method, ms, bin_shape = result_a
    else:
        method_fail_user = result_a[1]
        result_b = _stage_v2(gray)
        if result_b[0] is None:
            return None, {
                "success": False, "method": "fail_both",
                "ms_est": result_b[2], "out_size": None,
                "input_shape": (orig_h, orig_w),
                "_detail": {"stage_a": method_fail_user, "stage_b": result_b[1]},
            }
        pts, method, ms, bin_shape = result_b

    bin_h, bin_w = bin_shape
    scale = np.array([orig_w / bin_w, orig_h / bin_h], dtype="float32")
    src = np.asarray(pts, dtype="float32").reshape(-1, 2) * scale
    tl, tr, br, bl = src[0], src[1], src[2], src[3]

    w_out = int(max(np.linalg.norm(br - bl), np.linalg.norm(tr - tl)))
    h_out = int(max(np.linalg.norm(tr - br), np.linalg.norm(tl - bl)))
    out_size = max(w_out, h_out)
    if out_size < 10:
        return None, {"success": False, "method": "fail_degenerate",
                       "ms_est": ms, "out_size": out_size,
                       "input_shape": (orig_h, orig_w)}

    dst = np.array([[0, 0], [out_size - 1, 0],
                    [out_size - 1, out_size - 1], [0, out_size - 1]],
                   dtype="float32")
    M = cv2.getPerspectiveTransform(np.array([tl, tr, br, bl], dtype="float32"), dst)

    if return_color:
        warped = cv2.warpPerspective(raw_color, M, (out_size, out_size))
    else:
        warped = cv2.warpPerspective(gray, M, (out_size, out_size))

    return warped, {
        "success": True, "method": method, "ms_est": ms,
        "out_size": out_size, "input_shape": (orig_h, orig_w),
    }

def _binarize_for_timing(warped):
    g = cv2.GaussianBlur(warped, (3, 3), 0)
    _, bw = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return bw

def _detect_timing_transitions(line, expected_modules=33, min_dist_frac=0.3):
    smooth = cv2.GaussianBlur(line.reshape(1, -1).astype(np.float32),
                              (1, 5), 0).ravel()
    b = (smooth > smooth.mean()).astype(np.int8)
    trans = np.where(np.diff(b) != 0)[0].astype(np.float32) + 0.5
    if len(trans) < 4:
        return None
    diffs = np.diff(trans)
    med = float(np.median(diffs))
    if med <= 0 or len(line) / med < expected_modules * 0.5:
        return None
    min_dist = med * min_dist_frac
    kept = [trans[0]]
    for t in trans[1:]:
        if t - kept[-1] >= min_dist:
            kept.append(t)
    return np.array(kept, dtype=np.float32)

def _fit_module_grid_from_timing(warped, qr_n=33):
    H, W = warped.shape[:2]
    bw = _binarize_for_timing(warped)

    def _axis_bounds(length, axis):
        nominal_module = length / qr_n
        best = None
        for delta in np.linspace(-1.0, 1.0, 11):
            center = int(round((6.5 + delta) * nominal_module))
            center = max(2, min(length - 3, center))
            if axis == 0:
                line = bw[center-1:center+2, :].mean(axis=0).astype(np.uint8)
            else:
                line = bw[:, center-1:center+2].mean(axis=1).astype(np.uint8)
            tr = _detect_timing_transitions(line, expected_modules=qr_n)
            if tr is None or len(tr) < 10:
                continue
            med = float(np.median(np.diff(tr)))
            err = abs(med - nominal_module) / nominal_module
            if err > 0.30:
                continue
            if best is None or err < best[0]:
                best = (err, tr, med)
        if best is None:
            return None
        _, tr, med = best
        pitch = med
        anchor_target = 7 * nominal_module
        anchor_idx = int(np.argmin(np.abs(tr - anchor_target)))
        x_at_7 = tr[anchor_idx]
        a = x_at_7 - 7 * pitch
        bounds = a + np.arange(qr_n + 1) * pitch
        if bounds[0] < -nominal_module or bounds[-1] > length + nominal_module:
            return None
        return bounds

    row_b = _axis_bounds(H, axis=0)
    col_b = _axis_bounds(W, axis=1)
    if row_b is None and col_b is None:
        return None
    if row_b is None:
        row_b = np.linspace(0, H, qr_n + 1)
    if col_b is None:
        col_b = np.linspace(0, W, qr_n + 1)
    return row_b.astype(np.float32), col_b.astype(np.float32)

def refine_grid_with_timing(warped, qr_n=33):
    out = _fit_module_grid_from_timing(warped, qr_n=qr_n)
    if out is None:
        H, W = warped.shape[:2]
        return (np.linspace(0, H, qr_n + 1).astype(np.float32),
                np.linspace(0, W, qr_n + 1).astype(np.float32))
    return out

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python cascade_warp.py <image.jpg> [out.png]")
        sys.exit(1)
    warped, diag = cascade_warp(sys.argv[1])
    print("diag:", diag)
    if warped is not None:
        out = sys.argv[2] if len(sys.argv) > 2 else "warped_out.png"
        cv2.imwrite(out, warped)
        print(f"Saved {warped.shape} → {out}")
