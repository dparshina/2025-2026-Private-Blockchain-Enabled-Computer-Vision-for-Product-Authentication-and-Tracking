from __future__ import annotations
import numpy as np
import cv2

QR_SIZE = 33
FINDER_CENTER_MODULE = 3

def _largest_dark_component(gray, y0, y1, x0, x1, expected_ms):
    sub = gray[y0:y1, x0:x1]
    k = max(3, int(round(expected_ms * 0.3)))
    if k % 2 == 0: k += 1
    blurred = cv2.GaussianBlur(sub.astype(np.uint8), (k, k), 0)
    _, binr = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    binr = cv2.morphologyEx(binr, cv2.MORPH_CLOSE, np.ones((k, k), np.uint8))
    n, labels, stats, centroids = cv2.connectedComponentsWithStats(binr, connectivity=8)
    best = None; best_score = -1
    target_size = expected_ms * 7
    for i in range(1, n):
        x, y, w, h, a = stats[i]
        cx, cy = centroids[i]
        if abs(w - h) > 0.5 * max(w, h): continue
        size = (w + h) / 2.0
        if size < expected_ms * 3 or size > expected_ms * 11: continue
        size_score = -abs(size - target_size) / target_size
        score = size_score
        if score > best_score:
            best_score = score
            best = (y0 + cy, x0 + cx)
    return best

def detect_finder_centers(gray):
    g = np.clip(gray, 0, 255).astype(np.uint8)
    H, W = g.shape
    ms_guess = min(H, W) / QR_SIZE

    win_y = int(H * 0.45); win_x = int(W * 0.45)

    tl = _largest_dark_component(g, 0, win_y, 0, win_x, ms_guess)
    tr = _largest_dark_component(g, 0, win_y, W - win_x, W, ms_guess)
    bl = _largest_dark_component(g, H - win_y, H, 0, win_x, ms_guess)

    if tl is None or tr is None or bl is None:
        return None, None

    d_tr_tl = np.linalg.norm(np.array(tr) - np.array(tl))
    d_bl_tl = np.linalg.norm(np.array(bl) - np.array(tl))
    ms = (d_tr_tl + d_bl_tl) / (2 * (QR_SIZE - 1 - 2 * FINDER_CENTER_MODULE))

    if abs(d_tr_tl - d_bl_tl) / max(d_tr_tl, d_bl_tl) > 0.15:
        return None, None

    return (tl, tr, bl), ms

def module_center(tl, tr, bl, r, c, qr_n=QR_SIZE):
    fc = FINDER_CENTER_MODULE
    span = qr_n - 1 - 2 * fc
    ex = (np.array(tr) - np.array(tl)) / span
    ey = (np.array(bl) - np.array(tl)) / span
    p = np.array(tl) + (r - fc) * ey + (c - fc) * ex
    return float(p[0]), float(p[1])

def extract_module_aligned(img, tl, tr, bl, r, c, qr_n=QR_SIZE):
    cy, cx = module_center(tl, tr, bl, r, c, qr_n)
    ms = (np.linalg.norm(np.array(tr) - np.array(tl)) +
          np.linalg.norm(np.array(bl) - np.array(tl))) / (2 * (qr_n - 1 - 2 * FINDER_CENTER_MODULE))
    half = ms / 2.0
    y0, y1 = int(round(cy - half)), int(round(cy + half))
    x0, x1 = int(round(cx - half)), int(round(cx + half))
    H, W = img.shape
    return img[max(0, y0):min(H, y1), max(0, x0):min(W, x1)]
