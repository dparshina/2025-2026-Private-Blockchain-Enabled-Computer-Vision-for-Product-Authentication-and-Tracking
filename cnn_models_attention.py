import torch
import torch.nn as nn
import torch.nn.functional as F

class SEBlock(nn.Module):
    def __init__(self, ch, r=8):
        super().__init__()
        h = max(4, ch // r)
        self.fc = nn.Sequential(
            nn.Linear(ch, h, bias=False), nn.ReLU(inplace=True),
            nn.Linear(h, ch, bias=False), nn.Sigmoid(),
        )

    def forward(self, x):
        b, c, _, _ = x.shape
        s = F.adaptive_avg_pool2d(x, 1).view(b, c)
        s = self.fc(s).view(b, c, 1, 1)
        return x * s

class SpatialAttnPre(nn.Module):
    def __init__(self, k=7):
        super().__init__()
        self.conv = nn.Conv2d(2, 1, kernel_size=k, padding=k // 2, bias=False)

    def forward(self, x):
        avg = x.mean(dim=1, keepdim=True)
        mx, _ = x.max(dim=1, keepdim=True)
        m = torch.sigmoid(self.conv(torch.cat([avg, mx], dim=1)))
        return x * m

def _make_block(in_ch, out_ch, n_conv=2):
    layers = []
    c = in_ch
    for _ in range(n_conv):
        layers += [nn.Conv2d(c, out_ch, 3, padding=1),
                   nn.BatchNorm2d(out_ch), nn.ReLU(inplace=True)]
        c = out_ch
    return nn.Sequential(*layers)

class BlobCNN_Base(nn.Module):
    def __init__(self, in_size=48):
        super().__init__()
        self.b1 = _make_block(1, 16)
        self.p1 = nn.MaxPool2d(2)
        self.b2 = _make_block(16, 32)
        self.p2 = nn.MaxPool2d(2)
        self.b3 = _make_block(32, 64)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.head = nn.Sequential(
            nn.Flatten(), nn.Dropout(0.2),
            nn.Linear(64, 32), nn.ReLU(inplace=True),
            nn.Linear(32, 1),
        )

    def forward(self, x):
        x = self.p1(self.b1(x))
        x = self.p2(self.b2(x))
        x = self.gap(self.b3(x))
        return self.head(x).squeeze(-1)

class BlobCNN_SE(nn.Module):
    def __init__(self, in_size=48):
        super().__init__()
        self.b1 = _make_block(1, 16); self.se1 = SEBlock(16)
        self.p1 = nn.MaxPool2d(2)
        self.b2 = _make_block(16, 32); self.se2 = SEBlock(32)
        self.p2 = nn.MaxPool2d(2)
        self.b3 = _make_block(32, 64); self.se3 = SEBlock(64)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.head = nn.Sequential(
            nn.Flatten(), nn.Dropout(0.2),
            nn.Linear(64, 32), nn.ReLU(inplace=True),
            nn.Linear(32, 1),
        )

    def forward(self, x):
        x = self.p1(self.se1(self.b1(x)))
        x = self.p2(self.se2(self.b2(x)))
        x = self.gap(self.se3(self.b3(x)))
        return self.head(x).squeeze(-1)

class BlobCNN_SpatialPre(nn.Module):
    def __init__(self, in_size=48):
        super().__init__()
        self.b1a = nn.Sequential(nn.Conv2d(1, 16, 3, padding=1),
                                 nn.BatchNorm2d(16), nn.ReLU(inplace=True))
        self.sap = SpatialAttnPre(k=7)
        self.b1b = nn.Sequential(nn.Conv2d(16, 16, 3, padding=1),
                                 nn.BatchNorm2d(16), nn.ReLU(inplace=True))
        self.p1 = nn.MaxPool2d(2)
        self.b2 = _make_block(16, 32)
        self.p2 = nn.MaxPool2d(2)
        self.b3 = _make_block(32, 64)
        self.gap = nn.AdaptiveAvgPool2d(1)
        self.head = nn.Sequential(
            nn.Flatten(), nn.Dropout(0.2),
            nn.Linear(64, 32), nn.ReLU(inplace=True),
            nn.Linear(32, 1),
        )

    def forward(self, x, return_attn=False):
        x1 = self.b1a(x)
        avg = x1.mean(dim=1, keepdim=True)
        mx, _ = x1.max(dim=1, keepdim=True)
        m = torch.sigmoid(self.sap.conv(torch.cat([avg, mx], dim=1)))
        x1 = x1 * m
        x = self.p1(self.b1b(x1))
        x = self.p2(self.b2(x))
        x = self.gap(self.b3(x))
        logits = self.head(x).squeeze(-1)
        if return_attn:
            return logits, m
        return logits

VARIANTS = {
    'base':    BlobCNN_Base,
    'se':      BlobCNN_SE,
    'spatial': BlobCNN_SpatialPre,
}

def n_params(m):
    return sum(p.numel() for p in m.parameters() if p.requires_grad)

if __name__ == '__main__':
    for name, cls in VARIANTS.items():
        m = cls(in_size=48)
        x = torch.randn(2, 1, 48, 48)
        y = m(x)
        print(f'{name:<10} params={n_params(m):>6,}  out={tuple(y.shape)}')
