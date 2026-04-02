"""
DevCleaner logo generator — uses 8× supersampling for crisp, alias-free edges.
Output: assets/logo.png (512×512 RGBA) + app_icon.ico (6-size Windows ICO).
Requires: Pillow, numpy
"""
from __future__ import annotations
import io, math, os, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# ── Constants ─────────────────────────────────────────────────────────────────
OUT_SIZE   = 512          # final PNG size
SCALE      = 8            # supersampling factor → render at 4096×4096
S          = OUT_SIZE * SCALE

CORNER_R   = 110          # rounded-rect corner radius (at OUT_SIZE scale)

# Palette
C_BG_TOP   = np.array([12,  27,  44, 255], dtype=np.uint8)   # deep navy
C_BG_BOT   = np.array([ 5,  16,  28, 255], dtype=np.uint8)   # deeper navy
C_TEAL     = np.array([ 0, 150, 136, 255], dtype=np.uint8)   # #009688
C_TEAL_L   = np.array([38,  198, 182, 255], dtype=np.uint8)  # highlight
C_WHITE    = np.array([255, 255, 255, 255], dtype=np.uint8)


# ── Gradient background ────────────────────────────────────────────────────────

def _make_gradient_bg(size: int) -> np.ndarray:
    """Vertical gradient from C_BG_TOP to C_BG_BOT, RGBA."""
    t = np.linspace(0, 1, size, dtype=np.float32).reshape(size, 1, 1)
    bg = (C_BG_TOP * (1 - t) + C_BG_BOT * t).astype(np.uint8)
    return np.broadcast_to(bg, (size, size, 4)).copy()


# ── Rounded-rectangle mask ────────────────────────────────────────────────────

def _make_rr_mask(size: int, radius: int) -> Image.Image:
    """White rounded-rect on black, single channel."""
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


# ── Draw helper (on a PIL RGBA image at full scale) ──────────────────────────

def _draw_logo(size: int) -> Image.Image:
    """Return a PIL RGBA image of size×size with the broom art (no background)."""
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad  = int(size * 0.10)       # padding inside the square
    bw   = size - 2 * pad
    bh   = size - 2 * pad

    def p(fx: float, fy: float) -> tuple[float, float]:
        return (pad + fx * bw, pad + fy * bh)

    # ── Teal glow behind the broom ────────────────────────────────────────────
    cx, cy = p(0.42, 0.50)
    for r in range(int(size * 0.38), 0, -1):
        alpha = int(55 * (1 - r / (size * 0.38)) ** 1.6)
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(C_TEAL[0], C_TEAL[1], C_TEAL[2], alpha),
        )

    # ── Handle ────────────────────────────────────────────────────────────────
    sw = max(2, int(size * 0.060))          # stroke width
    x0, y0 = p(0.71, 0.08)
    x1, y1 = p(0.34, 0.56)
    draw.line([(x0, y0), (x1, y1)],
              fill=(255, 255, 255, 255), width=sw)
    # Rounded cap at grip end
    draw.ellipse([x0 - sw // 2, y0 - sw // 2,
                  x0 + sw // 2, y0 + sw // 2],
                 fill=(255, 255, 255, 255))
    draw.ellipse([x1 - sw // 2, y1 - sw // 2,
                  x1 + sw // 2, y1 + sw // 2],
                 fill=(255, 255, 255, 255))

    # ── Broom head ────────────────────────────────────────────────────────────
    head = [p(0.06, 0.60), p(0.49, 0.48),
            p(0.56, 0.63), p(0.52, 0.84), p(0.06, 0.84)]
    draw.polygon(head, fill=(255, 255, 255, 255))

    # Subtle top stripe (makes bristle region feel lighter)
    stripe = [p(0.08, 0.61), p(0.49, 0.50),
              p(0.49, 0.57), p(0.08, 0.68)]
    draw.polygon(stripe, fill=(C_TEAL_L[0], C_TEAL_L[1], C_TEAL_L[2], 70))

    # ── Debris dots (teal highlight) ──────────────────────────────────────────
    def dot(fx: float, fy: float, fr: float, alpha: int = 220) -> None:
        dr = max(2, int(fr * bw))
        cx2, cy2 = p(fx, fy)
        draw.ellipse(
            [cx2 - dr, cy2 - dr, cx2 + dr, cy2 + dr],
            fill=(C_TEAL_L[0], C_TEAL_L[1], C_TEAL_L[2], alpha),
        )

    dot(0.73, 0.73, 0.068)
    dot(0.85, 0.57, 0.050)
    dot(0.91, 0.80, 0.058)
    dot(0.80, 0.88, 0.036, 160)

    return img


# ── Compose final image ────────────────────────────────────────────────────────

def _compose(size: int) -> Image.Image:
    radius = int(CORNER_R * size / OUT_SIZE)

    # 1. Gradient background as numpy array
    bg_arr  = _make_gradient_bg(size)
    bg_img  = Image.fromarray(bg_arr, "RGBA")

    # 2. Rounded-rect alpha mask
    rr_mask = _make_rr_mask(size, radius)
    bg_img.putalpha(rr_mask)

    # 3. Broom art layer
    art = _draw_logo(size)

    # 4. Composite art over background
    result = Image.alpha_composite(bg_img, art)
    return result


# ── Public entry-point ────────────────────────────────────────────────────────

def make_logo(out_size: int = OUT_SIZE) -> Image.Image:
    """Render logo at SCALE× then downsample for crisp SSAA output."""
    big = _compose(out_size * SCALE)
    # LANCZOS gives the best quality anti-aliasing on downsample
    return big.resize((out_size, out_size), Image.LANCZOS)


# ── ICO packing ───────────────────────────────────────────────────────────────

def _write_ico(frames: list[tuple[int, Image.Image]], path: str) -> None:
    """Write a proper multi-size ICO with PNG-compressed frames."""
    n = len(frames)
    header = struct.pack("<HHH", 0, 1, n)

    blobs: list[bytes] = []
    for _, img in frames:
        buf = io.BytesIO()
        img.convert("RGBA").save(buf, "PNG")
        blobs.append(buf.getvalue())

    dir_offset = 6 + 16 * n
    offsets, cur = [], dir_offset
    for blob in blobs:
        offsets.append(cur)
        cur += len(blob)

    directory = b""
    for (sz, _), blob, off in zip(frames, blobs, offsets):
        w = sz if sz < 256 else 0
        h = sz if sz < 256 else 0
        directory += struct.pack("<BBBBHHII",
            w, h, 0, 0, 1, 32, len(blob), off)

    with open(path, "wb") as f:
        f.write(header + directory)
        for blob in blobs:
            f.write(blob)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Full-size PNG for README
    print("Rendering 512x512 logo (8x SSAA) ...")
    logo = make_logo(512)
    logo_path = os.path.join(repo, "assets", "logo.png")
    os.makedirs(os.path.dirname(logo_path), exist_ok=True)
    logo.save(logo_path, "PNG")
    print(f"  OK {logo_path}")

    # Multi-size ICO
    ico_sizes = [16, 32, 48, 64, 128, 256]
    frames: list[tuple[int, Image.Image]] = []
    for sz in ico_sizes:
        print(f"  rendering {sz}x{sz} ...", end="\r")
        frames.append((sz, make_logo(sz)))
    print(" " * 40, end="\r")

    ico_path = os.path.join(
        repo, "flutter_app", "windows", "runner", "resources", "app_icon.ico"
    )
    _write_ico(frames, ico_path)
    print(f"  OK {ico_path}  ({len(ico_sizes)} sizes)")
    print("Done.")


if __name__ == "__main__":
    main()
