from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "app_icon_moose.png"


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_master(path: Path):
    size = 1024
    img = Image.new("RGBA", (size, size), (18, 61, 52, 255))
    draw = ImageDraw.Draw(img)

    # Soft card-like app icon base.
    draw.rounded_rectangle((0, 0, size, size), radius=220, fill=(18, 61, 52, 255))
    draw.ellipse((130, 110, 894, 874), fill=(220, 234, 227, 255))
    draw.ellipse((178, 158, 846, 826), outline=(151, 91, 44, 255), width=22)

    antler = (18, 61, 52, 255)
    accent = (151, 91, 44, 255)

    # Antlers, mirrored with strong rounded strokes so small icons stay legible.
    left_points = [(512, 492), (402, 370), (322, 246), (266, 152)]
    right_points = [(512, 492), (622, 370), (702, 246), (758, 152)]
    draw.line(left_points, fill=antler, width=48, joint="curve")
    draw.line(right_points, fill=antler, width=48, joint="curve")

    for x, y, dx, dy in [
        (402, 370, -104, -14),
        (360, 306, -104, 34),
        (322, 246, -78, 74),
        (622, 370, 104, -14),
        (664, 306, 104, 34),
        (702, 246, 78, 74),
    ]:
        draw.line((x, y, x + dx, y + dy), fill=antler, width=42)

    # Rounded antler tips.
    for cx, cy in [
        (266, 152),
        (298, 356),
        (256, 340),
        (244, 320),
        (758, 152),
        (726, 356),
        (768, 340),
        (780, 320),
    ]:
        draw.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=antler)

    # Moose head mark.
    draw.polygon(
        [
            (512, 424),
            (636, 538),
            (604, 736),
            (512, 814),
            (420, 736),
            (388, 538),
        ],
        fill=antler,
    )
    draw.ellipse((426, 396, 486, 516), fill=accent)
    draw.ellipse((538, 396, 598, 516), fill=accent)
    draw.ellipse((468, 640, 500, 672), fill=(220, 234, 227, 255))
    draw.ellipse((524, 640, 556, 672), fill=(220, 234, 227, 255))
    draw.rounded_rectangle((454, 708, 570, 752), radius=22, fill=(220, 234, 227, 255))

    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return img


def resize(master: Image.Image, output: Path, size: int):
    output.parent.mkdir(parents=True, exist_ok=True)
    master.resize((size, size), Image.Resampling.LANCZOS).save(output)


def main():
    master = draw_master(MASTER)

    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in ios_sizes.items():
        resize(master, ios / name, px)

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for name, px in android_sizes.items():
        resize(master, android / name, px)

    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for px in [16, 32, 64, 128, 256, 512, 1024]:
        resize(master, macos / f"app_icon_{px}.png", px)

    web = ROOT / "web" / "icons"
    resize(master, web / "Icon-192.png", 192)
    resize(master, web / "Icon-512.png", 512)
    resize(master, web / "Icon-maskable-192.png", 192)
    resize(master, web / "Icon-maskable-512.png", 512)
    resize(master, ROOT / "web" / "favicon.png", 32)


if __name__ == "__main__":
    main()
