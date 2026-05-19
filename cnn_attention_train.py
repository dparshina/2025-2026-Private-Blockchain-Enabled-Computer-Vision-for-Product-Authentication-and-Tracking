import json, time, argparse
from pathlib import Path
from collections import defaultdict

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader

from cnn_models_attention import VARIANTS, n_params
from _pipeline import load_gray, preprocess, FUNCTIONAL, try_decode, QR_SIZE
from cnn_build_dataset import extract_module_resized

ROOT = Path(__file__).parent
WARP_DIR = ROOT / 'cascade_warp_out'
CACHE_DIR = ROOT / 'attn_cache'
CACHE_DIR.mkdir(exist_ok=True)
RES_FILE = ROOT / 'cnn_attention_results.json'
WEIGHTS_DIR = ROOT / 'attn_weights'; WEIGHTS_DIR.mkdir(exist_ok=True)

EXPECTED = 'b2e2bb5898e429e5d5adfd8d34186738bb6699a110304807f03c9edd1ff81bc1e904094a718b9f7be2c80f0bbfa51554c54875546bd4cb852fa9b41b8aacf96d'

MODULE_SIZE_PX = 48
WINDOW_SCALE = 1.2
BATCH = 256
EPOCHS = 20
LR = 1.5e-3
WD = 1e-4
DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'
VAL_FRAC = 0.3
NUM_WORKERS = 2

PATTERNS = ['triangle', 'corner', 'square', 'cross']
SIZE = 's15'
N_FOLDS = 5
CV_SHUFFLE_SEED = 42

GT = np.zeros((QR_SIZE, QR_SIZE), dtype=np.uint8)
with open(ROOT / 'ground_truth_blobs.txt') as f:
    for line in f:
        if line.strip():
            r, c = [int(x) for x in line.strip().split(',')]
            GT[r, c] = 1

USED = np.zeros((QR_SIZE, QR_SIZE), dtype=bool)
_cnt = 0
for r in range(QR_SIZE):
    for c in range(QR_SIZE):
        if not FUNCTIONAL[r, c]:
            if _cnt < 664: USED[r, c] = True
            _cnt += 1

EXCLUDE = {'PHOTO_1777551991 copy.png', 'PHOTO_1777551995 copy.png'}

def list_imgs(pattern):
    folder = WARP_DIR / f'{pattern}_{SIZE}'
    if not folder.exists(): return []
    return [p for p in sorted(folder.glob('*.png'))
            if 'qr_final_' not in p.name and p.name not in EXCLUDE]

def build_dataset(pattern):
    fx = CACHE_DIR / f'{pattern}_X.npy'; fy = CACHE_DIR / f'{pattern}_y.npy'
    fm = CACHE_DIR / f'{pattern}_meta.json'
    if fx.exists() and fy.exists() and fm.exists():
        return np.load(fx), np.load(fy), json.loads(fm.read_text())
    imgs = list_imgs(pattern)
    Xs, ys, recs = [], [], []
    for img_idx, p in enumerate(imgs):
        g = load_gray(p)
        res = preprocess(g)
        for r in range(QR_SIZE):
            for c in range(QR_SIZE):
                crop = extract_module_resized(res['denoised'], res['ms'], res['oy'], res['ox'],
                                              r, c, WINDOW_SCALE, MODULE_SIZE_PX)
                Xs.append(crop); ys.append(int(GT[r, c]))
                recs.append({'image_idx': img_idx, 'r': r, 'c': c})
    X = np.stack(Xs, 0).astype(np.uint8); y = np.array(ys, np.uint8)
    np.save(fx, X); np.save(fy, y)
    meta = {'records': recs, 'image_names': [str(p.relative_to(ROOT)) for p in imgs]}
    fm.write_text(json.dumps(meta))
    return X, y, meta

class DS(Dataset):
    def __init__(self, X, y, idx, augment, pattern):
        self.X, self.y, self.idx, self.aug = X, y, idx, augment
        self.full_rot = pattern in ('corner', 'triangle', 'cross')
    def __len__(self): return len(self.idx)
    def __getitem__(self, i):
        k = self.idx[i]
        img = self.X[k].astype(np.float32) / 255.0
        if self.aug: img = self._aug(img)
        img = (img - img.mean()) / (img.std() + 1e-6)
        return torch.from_numpy(img).unsqueeze(0), torch.tensor(float(self.y[k]))
    def _aug(self, img):
        H, W = img.shape
        dy = np.random.randint(-int(H*0.1), int(H*0.1)+1)
        dx = np.random.randint(-int(W*0.1), int(W*0.1)+1)
        img = np.roll(img, (dy, dx), (0,1))
        img = np.clip(img * np.random.uniform(0.75,1.25) + np.random.uniform(-0.15,0.15), 0, 1)
        if np.random.rand() < 0.5:
            img = np.clip(img + np.random.randn(H,W).astype(np.float32)*0.03, 0, 1)
        if np.random.rand() < 0.4:
            for _ in range(np.random.randint(1,3)):
                sz = np.random.randint(4,9); yy = np.random.randint(0,H-sz); xx = np.random.randint(0,W-sz)
                img[yy:yy+sz, xx:xx+sz] = np.random.uniform(0,1)
        if self.full_rot:
            k = np.random.randint(0,4)
            if k: img = np.rot90(img, k).copy()
            if np.random.rand() < 0.5: img = np.fliplr(img).copy()
            if np.random.rand() < 0.5: img = np.flipud(img).copy()
        else:
            if np.random.rand() < 0.5: img = np.fliplr(img).copy()
            if np.random.rand() < 0.5: img = np.flipud(img).copy()
        return img

def predict_blob(model, X, recs, image_idx):
    blob = np.zeros((QR_SIZE, QR_SIZE), dtype=np.uint8)
    rec_idx = [i for i, m in enumerate(recs) if m['image_idx'] == image_idx]
    batch, coords = [], []
    for k in rec_idx:
        img = X[k].astype(np.float32)/255.0
        img = (img - img.mean()) / (img.std() + 1e-6)
        batch.append(img); coords.append((recs[k]['r'], recs[k]['c']))
    x = torch.from_numpy(np.stack(batch)).unsqueeze(1).to(DEVICE)
    model.eval(); outs = []
    with torch.no_grad():
        for i in range(0, len(x), BATCH):
            outs.append(model(x[i:i+BATCH]).cpu().numpy())
    out = np.concatenate(outs)
    for (r,c), logit in zip(coords, out):
        if USED[r,c]: blob[r,c] = int(logit > 0)
    return blob

def byte_err(blob):
    bits_my = [int(blob[r,c]) for r in range(QR_SIZE) for c in range(QR_SIZE) if not FUNCTIONAL[r,c]][:664]
    bits_gt = [int(GT[r,c]) for r in range(QR_SIZE) for c in range(QR_SIZE) if not FUNCTIONAL[r,c]][:664]
    return sum(1 for i in range(0, 664, 8) if bits_my[i:i+8] != bits_gt[i:i+8])

def eval_only(pattern, variant, fold, X, y, recs, names, weights_path):
    n_img = len(names)
    by_img = [[] for _ in range(n_img)]
    for i, r in enumerate(recs): by_img[r['image_idx']].append(i)
    splits = cv_split(n_img)
    _, val_imgs = splits[fold]
    model = VARIANTS[variant](in_size=MODULE_SIZE_PX).to(DEVICE)
    state = torch.load(weights_path, map_location=DEVICE)
    model.load_state_dict(state); model.eval()
    per_img = []; decoded = 0
    for ii in val_imgs:
        blob = predict_blob(model, X, recs, ii)
        be = byte_err(blob); sig = try_decode(blob)
        ok = bool(sig and sig.hex() == EXPECTED)
        if ok: decoded += 1
        per_img.append({'image': names[ii], 'byte_err': be, 'decoded': ok, 'blob_count': int(blob.sum())})
    return {
        'pattern': pattern, 'variant': variant, 'fold': fold,
        'n_val': len(val_imgs), 'decoded': decoded,
        'decode_rate': decoded / len(val_imgs),
        'best_f1': None, 'curves': None,
        'per_image': per_img,
        'val_image_names': [names[i] for i in val_imgs],
        'n_params': n_params(model),
    }

def cv_split(n_img, n_folds=N_FOLDS, shuffle_seed=CV_SHUFFLE_SEED):
    rng = np.random.RandomState(shuffle_seed)
    order = np.arange(n_img); rng.shuffle(order)
    folds = np.array_split(order, n_folds)
    splits = []
    for k in range(n_folds):
        val = list(folds[k])
        train = [i for j, f in enumerate(folds) if j != k for i in f]
        splits.append((train, val))
    return splits

def run_one(pattern, variant, fold, X, y, recs, names, save_weights=True):
    n_img = len(names)
    by_img = [[] for _ in range(n_img)]
    for i, r in enumerate(recs): by_img[r['image_idx']].append(i)
    splits = cv_split(n_img)
    tr_imgs, val_imgs = splits[fold]
    tr_idx = [i for j in tr_imgs for i in by_img[j]]
    val_idx = [i for j in val_imgs for i in by_img[j]]

    torch.manual_seed(fold); np.random.seed(fold)
    tr_ds = DS(X, y, tr_idx, True, pattern); val_ds = DS(X, y, val_idx, False, pattern)
    tr_dl = DataLoader(tr_ds, BATCH, shuffle=True, num_workers=NUM_WORKERS, persistent_workers=NUM_WORKERS>0)
    val_dl = DataLoader(val_ds, BATCH, shuffle=False, num_workers=NUM_WORKERS, persistent_workers=NUM_WORKERS>0)

    model = VARIANTS[variant](in_size=MODULE_SIZE_PX).to(DEVICE)
    pos_rate = y[tr_idx].mean()
    pos_w = torch.tensor([(1-pos_rate)/max(pos_rate,1e-6)]).to(DEVICE)
    crit = nn.BCEWithLogitsLoss(pos_weight=pos_w)
    opt = torch.optim.AdamW(model.parameters(), lr=LR, weight_decay=WD)
    sch = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=EPOCHS)

    curves = {'train_loss': [], 'val_loss': [], 'val_f1': [], 'val_decode': []}
    best_f1 = -1; best_state = None
    for ep in range(EPOCHS):
        model.train(); tl = 0
        for xb, yb in tr_dl:
            xb, yb = xb.to(DEVICE), yb.to(DEVICE)
            l = crit(model(xb), yb); opt.zero_grad(); l.backward(); opt.step()
            tl += l.item()
        sch.step()
        model.eval(); ps, ls, vl = [], [], 0
        with torch.no_grad():
            for xb, yb in val_dl:
                xb = xb.to(DEVICE); yb_d = yb.to(DEVICE)
                logits = model(xb)
                vl += crit(logits, yb_d).item()
                ps.extend((logits.cpu().numpy() > 0).astype(int))
                ls.extend(yb.numpy().astype(int))
        ps, ls = np.array(ps), np.array(ls)
        tp = int(((ps==1)&(ls==1)).sum()); fp = int(((ps==1)&(ls==0)).sum()); fn = int(((ps==0)&(ls==1)).sum())
        prec = tp/max(tp+fp,1); rec = tp/max(tp+fn,1)
        f1 = 2*prec*rec/max(prec+rec, 1e-9)
        dc = 0
        for ii in val_imgs:
            blob = predict_blob(model, X, recs, ii)
            sig = try_decode(blob)
            if sig and sig.hex() == EXPECTED: dc += 1
        curves['train_loss'].append(tl/len(tr_dl)); curves['val_loss'].append(vl/len(val_dl))
        curves['val_f1'].append(f1); curves['val_decode'].append(dc / len(val_imgs))
        if f1 > best_f1:
            best_f1 = f1
            best_state = {k: v.clone().cpu() for k,v in model.state_dict().items()}

    model.load_state_dict(best_state)
    per_img = []
    decoded = 0
    for ii in val_imgs:
        blob = predict_blob(model, X, recs, ii)
        be = byte_err(blob)
        sig = try_decode(blob)
        ok = bool(sig and sig.hex() == EXPECTED)
        if ok: decoded += 1
        per_img.append({'image': names[ii], 'byte_err': be, 'decoded': ok, 'blob_count': int(blob.sum())})
    if save_weights:
        torch.save(best_state, WEIGHTS_DIR / f'{variant}_{pattern}_f{fold}.pt')
    return {
        'pattern': pattern, 'variant': variant, 'fold': fold,
        'n_val': len(val_imgs), 'decoded': decoded,
        'decode_rate': decoded / len(val_imgs),
        'best_f1': float(best_f1),
        'curves': curves,
        'per_image': per_img,
        'val_image_names': [names[i] for i in val_imgs],
        'n_params': n_params(model),
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--variants', nargs='+', default=list(VARIANTS.keys()))
    ap.add_argument('--patterns', nargs='+', default=PATTERNS)
    ap.add_argument('--folds', nargs='+', type=int, default=list(range(N_FOLDS)))
    args = ap.parse_args()

    print(f'device={DEVICE}  | 5-fold CV (shuffle seed={CV_SHUFFLE_SEED})', flush=True)
    print('=== building datasets ===', flush=True)
    data = {}
    for pat in args.patterns:
        t0 = time.time()
        X, y, meta = build_dataset(pat)
        data[pat] = (X, y, meta['records'], meta['image_names'])
        print(f'  {pat}: N_img={len(meta["image_names"])} N_mod={len(X)} pos_rate={y.mean():.3f}  ({time.time()-t0:.0f}s)', flush=True)

    runs = []
    if RES_FILE.exists():
        runs = json.loads(RES_FILE.read_text()).get('runs', [])
    done = {(r['pattern'], r['variant'], r['fold']) for r in runs}

    total = len(args.variants)*len(args.patterns)*len(args.folds)
    cnt = 0
    for variant in args.variants:
        for pat in args.patterns:
            for fold in args.folds:
                cnt += 1
                key = (pat, variant, fold)
                if key in done:
                    print(f'[{cnt}/{total}] {variant}/{pat}/fold{fold} cached (json)', flush=True); continue
                wpath = WEIGHTS_DIR / f'{variant}_{pat}_f{fold}.pt'
                if wpath.exists():
                    print(f'[{cnt}/{total}] {variant}/{pat}/fold{fold} eval-only from .pt', flush=True)
                    t0 = time.time()
                    X, y, recs, names = data[pat]
                    res = eval_only(pat, variant, fold, X, y, recs, names, wpath)
                    res['time_s'] = round(time.time()-t0, 1); res['resumed'] = True
                    runs.append(res)
                    RES_FILE.write_text(json.dumps({'runs': runs}, indent=1, default=str))
                    print(f'  → decoded {res["decoded"]}/{res["n_val"]} = {res["decode_rate"]:.1%}  ({res["time_s"]:.0f}s)', flush=True)
                    continue
                print(f'\n[{cnt}/{total}] {variant}/{pat}/fold{fold}', flush=True)
                t0 = time.time()
                X, y, recs, names = data[pat]
                res = run_one(pat, variant, fold, X, y, recs, names)
                res['time_s'] = round(time.time()-t0, 1)
                runs.append(res)
                RES_FILE.write_text(json.dumps({'runs': runs}, indent=1, default=str))
                print(f'  → decoded {res["decoded"]}/{res["n_val"]} = {res["decode_rate"]:.1%}  f1={res["best_f1"]:.3f}  ({res["time_s"]:.0f}s)', flush=True)

    print('\n\n=== SUMMARY (5-fold CV) ===')
    print(f'{"variant":<10} {"pattern":<10} {"folds":<6} {"decode_rate":<18} {"params":<8}')
    agg = defaultdict(list)
    for r in runs: agg[(r['variant'], r['pattern'])].append(r['decode_rate'])
    for variant in args.variants:
        for pat in args.patterns:
            v = agg.get((variant, pat), [])
            if not v: continue
            n_p = next((r['n_params'] for r in runs if r['variant']==variant), '?')
            print(f'{variant:<10} {pat:<10} {len(v):<6} {np.mean(v):>5.1%} ± {np.std(v):>4.1%}     {n_p:>6,}')

if __name__ == '__main__':
    main()
