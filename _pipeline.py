from __future__ import annotations

import warnings
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import filters, restoration, feature, exposure, morphology, measure

warnings.filterwarnings("ignore")

QR_SIZE = 33
_TARGET = 64

BLOB_CENTER_REL = (0.4, 0.4)
BLOB_HALF_SIDE_REL = 0.2

def load_gray(path) -> np.ndarray:
    return np.array(Image.open(path).convert("L"), dtype=np.float32)

def estimate_module_grid(gray: np.ndarray, qr_n: int = QR_SIZE):
    h, w = gray.shape
    ms = min(h, w) / qr_n
    gy = np.abs(np.diff(gray, axis=0)).mean(axis=1)
    gx = np.abs(np.diff(gray, axis=1)).mean(axis=0)

    def refine(g1d, ms):
        L = len(g1d)
        best, sc = 0.0, -np.inf
        for off in np.linspace(-ms / 2, ms / 2, 31):
            xs = off + np.arange(1, qr_n) * ms
            xs = xs[(xs >= 1) & (xs < L - 1)].astype(int)
            if len(xs) < qr_n - 3:
                continue
            s = g1d[xs].sum()
            if s > sc:
                sc, best = s, off
        return float(np.clip(best, -ms * 0.3, ms * 0.3))

    return float(ms), refine(gy, ms), refine(gx, ms)

def flatten_illumination(gray, ms):
    sigma = max(ms * 3.0, 8.0)
    bg = np.clip(ndi.gaussian_filter(gray, sigma), 1.0, None)
    flat = gray / bg
    lo, hi = np.percentile(flat, [1, 99])
    return (np.clip((flat - lo) / max(hi - lo, 1e-6), 0, 1) * 255).astype(np.float32)

def denoise_grain(gray, ms):
    med = ndi.median_filter(gray, size=3)
    bil = restoration.denoise_bilateral(
        med / 255.0,
        sigma_color=0.08,
        sigma_spatial=max(ms / 8.0, 1.5),
        channel_axis=None,
    )
    bil = ndi.gaussian_filter(bil, sigma=max(ms / 15.0, 0.6))
    return (bil * 255).astype(np.float32)

def preprocess(gray):
    ms, oy, ox = estimate_module_grid(gray)
    flat = flatten_illumination(gray, ms)
    den = denoise_grain(flat, ms)
    return {"gray": gray, "flat": flat, "denoised": den, "ms": ms, "oy": oy, "ox": ox}

def extract_module(img, ms, oy, ox, r, c):
    y0 = int(round(oy + r * ms))
    y1 = int(round(oy + (r + 1) * ms))
    x0 = int(round(ox + c * ms))
    x1 = int(round(ox + (c + 1) * ms))
    return img[max(y0, 0):y1, max(x0, 0):x1]

def build_functional_mask(qr_n: int = QR_SIZE, quiet: int = 4):
    total = qr_n + 2 * quiet
    f = np.zeros((total, total), dtype=bool)
    f[:quiet, :] = True; f[-quiet:, :] = True
    f[:, :quiet] = True; f[:, -quiet:] = True
    for i in range(7):
        for j in range(7):
            f[quiet + i][quiet + j] = True
            f[quiet + i][total - quiet - 7 + j] = True
            f[total - quiet - 7 + i][quiet + j] = True
    for i in range(8):
        f[quiet + i][quiet + 7] = True
        f[quiet + 7][quiet + i] = True
    for i in range(8, total - 8):
        f[quiet + 6][quiet + i] = True
        f[quiet + i][quiet + 6] = True
    for i in range(9):
        f[quiet + 8][quiet + i] = True
        f[quiet + i][quiet + 8] = True
    return f[quiet:quiet + qr_n, quiet:quiet + qr_n]

FUNCTIONAL = build_functional_mask()

def _to_gray64(img):
    if img.ndim == 3:
        pil = Image.fromarray(img).convert("L")
    else:
        pil = Image.fromarray(img.astype(np.uint8))
    return np.array(pil.resize((_TARGET, _TARGET), Image.LANCZOS))

def _local_contrast(img, r, c, radius):
    h, w = img.shape
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.sqrt((xs - c) ** 2 + (ys - r) ** 2)
    inner = (d <= radius * 0.9)
    outer = (d > radius * 1.2) & (d <= radius * 2.2)
    a = float(img[inner].mean()) if inner.any() else 0.0
    b = float(img[outer].mean()) if outer.any() else 0.0
    return a - b

def _is_isotropic(img, r, c, radius, n_dirs=12):
    h, w = img.shape
    angles = np.linspace(0, 2 * np.pi, n_dirs, endpoint=False)

    def ring(dist):
        return np.array([
            float(img[int(np.clip(r + dist * np.sin(a), 0, h - 1)),
                      int(np.clip(c + dist * np.cos(a), 0, w - 1))])
            for a in angles
        ])

    inner = ring(max(1.5, radius * 0.45))
    mean_i = inner.mean()
    if mean_i < 0.05 or inner.std() / (mean_i + 1e-6) > 0.6:
        return False
    gy, gx = np.gradient(img)
    boundary_r = max(2.0, radius * 0.85)
    angs = []
    for a in angles:
        ir = int(np.clip(r + boundary_r * np.sin(a), 0, h - 1))
        ic = int(np.clip(c + boundary_r * np.cos(a), 0, w - 1))
        angs.append(float(np.arctan2(gy[ir, ic], gx[ir, ic])))
    coh = abs(np.exp(1j * np.array(angs)).mean())
    if coh > 0.72:
        return False
    outer = ring(max(3.0, radius * 1.6))
    if float((outer < mean_i * 0.65).mean()) < 0.5:
        return False
    return True

def _log_score(log_img, raw_img):
    sz = log_img.shape[0]
    cy_exp = BLOB_CENTER_REL[0] * sz
    cx_exp = BLOB_CENTER_REL[1] * sz
    margin = sz * 0.05
    try:
        blobs = feature.blob_log(
            log_img,
            min_sigma=2.0,
            max_sigma=12.0,
            num_sigma=10,
            threshold=0.030,
            overlap=0.5,
        )
    except Exception:
        return -3.0, None
    if len(blobs) == 0:
        return -4.0, None

    best_score, best_blob = -10.0, None
    for r, c, sigma in blobs:
        radius = sigma * 1.4142
        if radius < 5.0 or radius > sz * 0.35:
            continue
        if r < margin or r > sz - margin or c < margin or c > sz - margin:
            continue
        if not _is_isotropic(raw_img, r, c, radius):
            continue
        dist = np.sqrt((r - cy_exp) ** 2 + (c - cx_exp) ** 2) / (sz * 0.5 * 1.4142)
        contrast = _local_contrast(log_img, r, c, radius)
        score = 0.0
        if dist < 0.20:
            score += 3.5
        elif dist < 0.35:
            score += 2.5
        elif dist < 0.50:
            score += 1.0
        else:
            score -= 1.5
        if contrast > 0.20:
            score += 4.0
        elif contrast > 0.10:
            score += 2.5
        elif contrast > 0.05:
            score += 1.0
        else:
            score -= 1.5
        if 7.0 < radius < 16.0:
            score += 1.5
        else:
            score -= 0.5
        if score > best_score:
            best_score, best_blob = score, (float(r), float(c), float(radius))
    return (best_score if best_score > -10 else -4.0), best_blob

def _shape_score(smoothed, is_dark_bg):
    t_otsu = filters.threshold_otsu(smoothed)
    t_local = filters.threshold_local(smoothed, block_size=15, offset=0.02)
    scores = []
    for binary_raw in [smoothed > t_otsu, smoothed > t_local]:
        binary = binary_raw.astype(np.uint8) * 255
        if not is_dark_bg:
            binary = 255 - binary
        cleaned = morphology.opening(binary > 127, morphology.disk(2)).astype(np.uint8) * 255
        f = _extract_features(cleaned)
        scores.append(_compute_shape_score(f))
    return float(np.mean(scores))

def _extract_features(binary):
    h, w = binary.shape
    total = h * w
    f = {}
    white = binary > 127
    f["white_ratio"] = float(white.sum() / total)
    labeled, n = measure.label(white, return_num=True, connectivity=2)
    if n == 0:
        return _zero_features(f)
    regions = sorted(measure.regionprops(labeled), key=lambda r: r.area, reverse=True)
    L = regions[0]
    area = L.area
    P = L.perimeter
    f["area_ratio"] = float(area / total)
    f["circularity"] = float(min(4 * np.pi * area / (P ** 2 + 1e-6), 1.0))
    f["aspect_ratio"] = float(L.major_axis_length / (L.minor_axis_length + 1e-6))
    cy, cx = L.centroid
    f["centroid_dist"] = float(
        np.sqrt((cx - BLOB_CENTER_REL[1] * w) ** 2 + (cy - BLOB_CENTER_REL[0] * h) ** 2)
        / (np.sqrt(h ** 2 + w ** 2) / 2.0)
    )
    f["solidity"] = float(area / (L.convex_area + 1e-6))
    f["extent"] = float(area / (L.bbox_area + 1e-6))
    f["eccentricity"] = float(L.eccentricity)
    min_r, min_c, max_r, max_c = L.bbox
    bh = max_r - min_r
    bw_ = max_c - min_c
    f["bbox_squareness"] = float(min(bh, bw_) / (max(bh, bw_) + 1e-6))
    margin = 3
    f["touches_border"] = float(
        min_r <= margin or min_c <= margin or max_r >= h - margin or max_c >= w - margin
    )
    f["n_large"] = float(sum(1 for r in regions if r.area > total * 0.05))
    return f

def _zero_features(f):
    f.update({
        "area_ratio": 0, "circularity": 0, "aspect_ratio": 10,
        "centroid_dist": 1, "solidity": 0, "extent": 0, "eccentricity": 1,
        "bbox_squareness": 0, "touches_border": 1, "n_large": 0,
    })
    return f

def _compute_shape_score(f):
    area = f.get("area_ratio", 0)
    if area < 0.04 or area > 0.55:
        return -6.0
    if f.get("extent", 0) > 0.94:
        return -5.0
    if f.get("aspect_ratio", 10) > 4.0:
        return -5.0
    score = 0.0
    c = f.get("circularity", 0)
    score += 3.0 if c > 0.65 else (1.0 if c > 0.5 else (-0.5 if c > 0.35 else -2.5))
    s = f.get("solidity", 0)
    score += 1.5 if s > 0.8 else (0.5 if s > 0.65 else -1.0)
    ar = f.get("aspect_ratio", 10)
    score += 1.5 if ar < 1.35 else (0.5 if ar < 1.7 else -1.5)
    e = f.get("eccentricity", 1)
    score += 1.0 if e < 0.5 else (-1.0 if e > 0.75 else 0.0)
    ex = f.get("extent", 0)
    if 0.6 < ex < 0.95:
        score += 1.0
    if f.get("touches_border", 1) == 0:
        score += 2.0
    else:
        score -= 3.0
    d = f.get("centroid_dist", 1)
    score += 1.5 if d < 0.30 else (0.5 if d < 0.50 else -1.0)
    n = f.get("n_large", 0)
    score += 0.5 if n == 1 else (-1.0 if n == 0 else -0.5)
    if 0.08 < area < 0.45:
        score += 0.5
    return score

def detect_blob_square(img):
    gray = _to_gray64(img)
    mean = float(gray.mean())
    is_dark_bg = mean < 128
    enhanced = exposure.equalize_adapthist(gray / 255.0, clip_limit=0.03)
    smoothed = filters.gaussian(enhanced, sigma=1.0)
    log_img = smoothed if is_dark_bg else (1.0 - smoothed)
    raw_norm = gray / 255.0 if is_dark_bg else (255.0 - gray) / 255.0
    raw_img = filters.gaussian(raw_norm, sigma=0.8)
    log_score, best_blob = _log_score(log_img, raw_img)
    shape_score = _shape_score(smoothed, is_dark_bg)
    final = 0.4 * log_score + 0.6 * shape_score
    return {
        "has_blob": final > 0,
        "score": float(final),
        "log_score": float(log_score),
        "shape_score": float(shape_score),
        "bg": "dark" if is_dark_bg else "light",
        "blob": best_blob,
    }

def _make_sbd():
    import cv2
    p = cv2.SimpleBlobDetector_Params()
    p.minThreshold = 20; p.maxThreshold = 230; p.thresholdStep = 5
    p.minDistBetweenBlobs = 5
    p.filterByColor = False
    p.filterByArea = True; p.minArea = 60; p.maxArea = 300
    p.filterByCircularity = True; p.minCircularity = 0.75
    p.filterByConvexity = True; p.minConvexity = 0.7
    p.filterByInertia = True; p.minInertiaRatio = 0.3
    return cv2.SimpleBlobDetector_create(p)

def _detect_sbd(module_img, sbd, center_tol=0.35):
    import cv2
    m = module_img.astype(np.uint8)
    h, w = m.shape
    if h < 8: return 0
    corners = np.concatenate([
        m[:h//6, :w//6].ravel(), m[:h//6, -w//6:].ravel(),
        m[-h//6:, :w//6].ravel(), m[-h//6:, -w//6:].ravel(),
    ])
    bg_dark = corners.mean() < 128
    img = 255 - m if bg_dark else m
    kps = sbd.detect(img)
    for k in kps:
        if abs(k.pt[0] - w/2) <= center_tol * w and abs(k.pt[1] - h/2) <= center_tol * h:
            return 1
    return 0

def classify_qr(image_path, source="denoised", return_extras=False, mode="ensemble"):
    g = load_gray(image_path)
    res = preprocess(g)
    src = res[source]
    ms, oy, ox = res["ms"], res["oy"], res["ox"]
    blob = np.zeros((QR_SIZE, QR_SIZE), dtype=np.uint8)
    scores = np.zeros((QR_SIZE, QR_SIZE), dtype=np.float32)

    sbd = _make_sbd() if mode in ("sbd", "ensemble") else None

    for r in range(QR_SIZE):
        for c in range(QR_SIZE):
            m = extract_module(src, ms, oy, ox, r, c)
            if m.size == 0: continue
            if mode == "log_shape":
                d = detect_blob_square(m)
                blob[r, c] = int(d["has_blob"])
                scores[r, c] = d["score"]
            elif mode == "sbd":
                blob[r, c] = _detect_sbd(m, sbd)
            else:
                sbd_yes = _detect_sbd(m, sbd)
                d = detect_blob_square(m)
                scores[r, c] = d["score"]
                blob[r, c] = int(sbd_yes and d["score"] > -3.0)
    if return_extras:
        return blob, scores, res
    return blob

try:
    from reedsolo import RSCodec, ReedSolomonError
    _rs = RSCodec(19)
    SIG_BITS = 664

    def _bits_to_bytes(bits):
        n = len(bits) - len(bits) % 8
        out = bytearray()
        for i in range(0, n, 8):
            b = 0
            for x in bits[i:i + 8]:
                b = (b << 1) | int(x)
            out.append(b)
        return bytes(out)

    def try_decode(blob_matrix):
        bits = [int(blob_matrix[r, c])
                for r in range(QR_SIZE)
                for c in range(QR_SIZE)
                if not FUNCTIONAL[r, c]]
        if len(bits) < SIG_BITS:
            return None
        raw = _bits_to_bytes(bits[:SIG_BITS])
        try:
            d = _rs.decode(raw)
            sig = bytes(d[0] if isinstance(d, tuple) else d)
            return sig if len(sig) == 64 else None
        except ReedSolomonError:
            return None
except ImportError:
    def try_decode(_):
        return None
