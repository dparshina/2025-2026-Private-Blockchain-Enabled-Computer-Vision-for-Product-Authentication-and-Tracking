import os, json, hashlib
import numpy as np
from pathlib import Path
from PIL import Image

import _pipeline
from _pipeline import (load_gray, preprocess, extract_module,
                        FUNCTIONAL, QR_SIZE)

ROOT = Path(__file__).parent
OUT_DIR = ROOT / 'cnn_dataset'
OUT_DIR.mkdir(exist_ok=True)

MODULE_SIZE_PX = 48
WINDOW_SCALE = 1.2

EXCLUDE = {'PHOTO_1777551991 copy.png', 'PHOTO_1777551995 copy.png'}

GT = np.zeros((QR_SIZE, QR_SIZE), dtype=np.uint8)
with open(ROOT / 'ground_truth_blobs.txt') as f:
    for line in f:
        line = line.strip()
        if line:
            r, c = [int(x) for x in line.split(',')]
            GT[r, c] = 1

USED = np.zeros((QR_SIZE, QR_SIZE), dtype=bool)
count = 0
for r in range(QR_SIZE):
    for c in range(QR_SIZE):
        if not FUNCTIONAL[r, c]:
            if count < 664:
                USED[r, c] = True
            count += 1

print(f'USED data modules: {USED.sum()}  (functional: {FUNCTIONAL.sum()})')
print(f'GT blobs total: {GT.sum()}  (in USED: {((GT==1)&USED).sum()})')

def extract_module_resized(img, ms, oy, ox, r, c, scale, out_size):
    cy = oy + (r + 0.5) * ms
    cx = ox + (c + 0.5) * ms
    half = ms * scale / 2.0
    H, W = img.shape
    y0 = int(round(cy - half)); y1 = int(round(cy + half))
    x0 = int(round(cx - half)); x1 = int(round(cx + half))
    pad_top = max(0, -y0); pad_bot = max(0, y1 - H)
    pad_left = max(0, -x0); pad_right = max(0, x1 - W)
    y0c, y1c = max(0, y0), min(H, y1)
    x0c, x1c = max(0, x0), min(W, x1)
    crop = img[y0c:y1c, x0c:x1c]
    if pad_top or pad_bot or pad_left or pad_right:
        crop = np.pad(crop, ((pad_top, pad_bot), (pad_left, pad_right)),
                      mode='reflect')
    pil = Image.fromarray(np.clip(crop, 0, 255).astype(np.uint8))
    return np.array(pil.resize((out_size, out_size), Image.LANCZOS))

def list_images():
    out = []
    for sub in ['square_s10', 'square_s15']:
        for p in sorted((ROOT / 'warped_raw' / sub).glob('*.png')):
            if 'qr_final_' in p.name: continue
            if p.name in EXCLUDE: continue
            out.append(p)
    return out

def main():
    imgs = list_images()
    print(f'Processing {len(imgs)} images...')

    all_X = []
    all_y = []
    all_meta = []

    for img_idx, p in enumerate(imgs):
        g = load_gray(p)
        res = preprocess(g)
        ms, oy, ox = res['ms'], res['oy'], res['ox']
        src = res['denoised']
        H, W = src.shape

        for r in range(QR_SIZE):
            for c in range(QR_SIZE):
                crop = extract_module_resized(src, ms, oy, ox, r, c,
                                               WINDOW_SCALE, MODULE_SIZE_PX)
                label = int(GT[r, c])
                all_X.append(crop)
                all_y.append(label)
                all_meta.append({
                    'image': p.name,
                    'image_idx': img_idx,
                    'r': r, 'c': c,
                    'used': bool(USED[r, c]),
                    'functional': bool(FUNCTIONAL[r, c]),
                })
        print(f'  [{img_idx+1:2d}/{len(imgs)}] {p.parent.name}/{p.name:<35} ms={ms:.1f}')

    X = np.stack(all_X, axis=0)
    y = np.array(all_y, dtype=np.uint8)
    print(f'\nDataset: X={X.shape} y={y.shape} positive_rate={y.mean():.3f}')

    np.save(OUT_DIR / 'X.npy', X)
    np.save(OUT_DIR / 'y.npy', y)
    with open(OUT_DIR / 'meta.json', 'w') as f:
        json.dump({
            'module_size_px': MODULE_SIZE_PX,
            'window_scale': WINDOW_SCALE,
            'n_images': len(imgs),
            'images': [str(p.relative_to(ROOT)) for p in imgs],
            'records': all_meta,
        }, f, indent=1)
    print(f'Saved to {OUT_DIR}')

if __name__ == '__main__':
    main()
