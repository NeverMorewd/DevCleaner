"""
Generate DevCleaner logo: logo.png (512x512 for README) and app_icon.ico (Windows).
Requires: Pillow
"""
from PIL import Image, ImageDraw
import math, os

# ── Palette ──────────────────────────────────────────────────────────────────
BG_TOP    = (13,  31,  46)   # dark navy
BG_BOT    = ( 7,  20,  31)   # deeper navy
TEAL      = ( 0, 150, 136)   # primary teal #009688
TEAL_DARK = ( 0, 105,  92)   # darker teal
TEAL_LITE = ( 38,198, 182)   # highlight
WHITE     = (255, 255, 255)
ALPHA0    = 0                # transparent

SIZE = 512
RADIUS = 90  # rounded corner radius


def make_logo(size: int) -> Image.Image:
    s = size
    r = max(8, int(RADIUS * s / SIZE))

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── 1. Background: vertical gradient rounded rect ────────────────────────
    for y in range(s):
        t = y / s
        r_c = int(BG_TOP[0] * (1 - t) + BG_BOT[0] * t)
        g_c = int(BG_TOP[1] * (1 - t) + BG_BOT[1] * t)
        b_c = int(BG_TOP[2] * (1 - t) + BG_BOT[2] * t)
        draw.line([(0, y), (s, y)], fill=(r_c, g_c, b_c, 255))

    # Mask to rounded rect
    mask = Image.new("L", (s, s), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=255)
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)

    # ── 2. Subtle teal glow at bottom-right ──────────────────────────────────
    cx, cy, gr = int(s * 0.72), int(s * 0.75), int(s * 0.42)
    for i in range(gr, 0, -1):
        alpha = int(38 * (1 - i / gr) ** 1.8)
        draw.ellipse(
            [cx - i, cy - i, cx + i, cy + i],
            fill=(TEAL[0], TEAL[1], TEAL[2], alpha)
        )

    # ── 3. Teal badge circle (soft) ──────────────────────────────────────────
    badge_r = int(s * 0.34)
    bx, by = int(s * 0.46), int(s * 0.47)
    for i in range(badge_r, 0, -1):
        alpha = int(70 * (1 - i / badge_r) ** 1.2)
        draw.ellipse(
            [bx - i, by - i, bx + i, by + i],
            fill=(TEAL[0], TEAL[1], TEAL[2], alpha)
        )

    # ── 4. Broom (scaled from Flutter's _BroomIconPainter) ───────────────────
    # Painter coords in [0,1] units:
    #   Handle: (0.73, 0.07) → (0.36, 0.56)
    #   Head polygon: (0.06,0.60) (0.50,0.48) (0.57,0.63) (0.52,0.83) (0.06,0.83)
    #   Dots at (0.73,0.73) r=0.07, (0.85,0.57) r=0.05, (0.91,0.80) r=0.06

    # We'll draw inside a [pad, pad, s-pad, s-pad] box
    pad = int(s * 0.12)
    bw = s - 2 * pad
    bh = s - 2 * pad

    def p(fx, fy):
        return (pad + fx * bw, pad + fy * bh)

    sw = max(2, int(s * 0.055))  # stroke width

    # Handle
    draw.line([p(0.73, 0.07), p(0.36, 0.56)],
              fill=WHITE + (255,), width=sw)

    # Draw rounded cap on handle ends
    ex, ey = p(0.73, 0.07)
    draw.ellipse([ex - sw//2, ey - sw//2, ex + sw//2, ey + sw//2],
                 fill=WHITE + (255,))
    ex2, ey2 = p(0.36, 0.56)
    draw.ellipse([ex2 - sw//2, ey2 - sw//2, ex2 + sw//2, ey2 + sw//2],
                 fill=WHITE + (255,))

    # Head
    head_pts = [p(0.06, 0.60), p(0.50, 0.48), p(0.57, 0.63),
                p(0.52, 0.83), p(0.06, 0.83)]
    draw.polygon(head_pts, fill=WHITE + (255,))

    # Highlight stripe on head
    stripe_pts = [p(0.08, 0.60), p(0.50, 0.49), p(0.50, 0.56),
                  p(0.08, 0.67)]
    draw.polygon(stripe_pts, fill=TEAL_LITE + (80,))

    # Debris dots (teal)
    def dot(fx, fy, fr):
        dr = max(2, int(fr * bw))
        cx2, cy2 = p(fx, fy)
        draw.ellipse([cx2 - dr, cy2 - dr, cx2 + dr, cy2 + dr],
                     fill=TEAL_LITE + (200,))

    dot(0.73, 0.73, 0.070)
    dot(0.85, 0.57, 0.050)
    dot(0.91, 0.80, 0.060)
    # Extra small dot
    dot(0.79, 0.88, 0.035)

    return img


def add_shadow(img: Image.Image) -> Image.Image:
    """Very light drop shadow under the rounded rect."""
    s = img.size[0]
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = max(2, s // 60)
    r2 = max(8, int(RADIUS * s / SIZE))
    sd.rounded_rectangle([off, off, s - 1, s - 1],
                          radius=r2, fill=(0, 0, 0, 90))
    # Simple blur by pasting several times with shift
    result = Image.alpha_composite(shadow, img)
    return result


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(out_dir)

    # ── Full-size PNG for README ──────────────────────────────────────────────
    logo = make_logo(512)
    logo_path = os.path.join(repo_root, "assets", "logo.png")
    os.makedirs(os.path.dirname(logo_path), exist_ok=True)
    logo.save(logo_path, "PNG")
    print(f"Saved: {logo_path}")

    # ── Windows ICO  (16, 32, 48, 64, 128, 256) ──────────────────────────────
    # PIL ICO: save a large source and specify sizes for automatic downsampling
    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_path = os.path.join(
        repo_root,
        "flutter_app", "windows", "runner", "resources", "app_icon.ico"
    )
    # Render each size explicitly for best quality, then pack manually
    import struct, io

    frames = []
    for sz in ico_sizes:
        frame = make_logo(sz).convert("RGBA")
        frames.append((sz, frame))

    def write_ico(frames_list, path):
        """Write a proper multi-size ICO file."""
        n = len(frames_list)
        # ICO header: reserved(2) + type(2) + count(2)
        header = struct.pack("<HHH", 0, 1, n)

        # Encode each frame as PNG inside ICO (supported since Vista)
        png_blobs = []
        for _, img in frames_list:
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            png_blobs.append(buf.getvalue())

        # Directory entries start at offset 6 + 16*n
        dir_offset = 6 + 16 * n
        offsets = []
        cur = dir_offset
        for blob in png_blobs:
            offsets.append(cur)
            cur += len(blob)

        directory = b""
        for (sz, _), blob, off in zip(frames_list, png_blobs, offsets):
            w = sz if sz < 256 else 0
            h = sz if sz < 256 else 0
            directory += struct.pack("<BBBBHHII",
                w, h,        # width, height (0 = 256)
                0,           # color count (0 = no palette)
                0,           # reserved
                1,           # color planes
                32,          # bits per pixel
                len(blob),   # size of image data
                off,         # offset of image data
            )

        with open(path, "wb") as f:
            f.write(header + directory)
            for blob in png_blobs:
                f.write(blob)

    write_ico(frames, ico_path)
    print(f"Saved: {ico_path}")

    print("Done!")


if __name__ == "__main__":
    main()
