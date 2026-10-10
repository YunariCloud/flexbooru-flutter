import os
from PIL import Image, ImageDraw

SOURCE_IMAGE_PATH = r"E:\Download\flexbooru-flex-preview.png"
PROJECT_ROOT = r"D:\Project\flexbooru"
BG_COLOR = (40, 62, 89, 255)  # #283E59

def ensure_dir(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)

def generate_icons():
    im = Image.open(SOURCE_IMAGE_PATH).convert("RGBA")
    print(f"Loaded source image: {im.size}, {im.mode}")

    # 1. In-app assets
    asset_dir = os.path.join(PROJECT_ROOT, "assets", "icons")
    os.makedirs(asset_dir, exist_ok=True)
    asset_path = os.path.join(asset_dir, "app_icon.png")
    im.save(asset_path, "PNG")
    print(f"Saved in-app asset: {asset_path}")

    # 2. Windows app_icon.ico
    win_ico_path = os.path.join(PROJECT_ROOT, "windows", "runner", "resources", "app_icon.ico")
    ensure_dir(win_ico_path)
    im.save(
        win_ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print(f"Saved Windows icon: {win_ico_path}")

    # 3. Android mipmap icons
    android_res = os.path.join(PROJECT_ROOT, "android", "app", "src", "main", "res")
    densities = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    for folder, (launcher_sz, fg_sz) in densities.items():
        folder_path = os.path.join(android_res, folder)
        ensure_dir(os.path.join(folder_path, "dummy.txt"))

        # ic_launcher.png
        launcher_img = im.resize((launcher_sz, launcher_sz), Image.Resampling.LANCZOS)
        launcher_img.save(os.path.join(folder_path, "ic_launcher.png"), "PNG")

        # ic_launcher_round.png
        round_canvas = Image.new("RGBA", (launcher_sz, launcher_sz), (0, 0, 0, 0))
        # Create circular background
        draw = ImageDraw.Draw(round_canvas)
        draw.ellipse((0, 0, launcher_sz - 1, launcher_sz - 1), fill=BG_COLOR)
        # Paste scaled icon into center
        content_sz = int(launcher_sz * 0.88)
        content_img = im.resize((content_sz, content_sz), Image.Resampling.LANCZOS)
        offset = (launcher_sz - content_sz) // 2
        round_canvas.paste(content_img, (offset, offset), content_img)
        # Apply circular mask
        mask = Image.new("L", (launcher_sz, launcher_sz), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse((0, 0, launcher_sz - 1, launcher_sz - 1), fill=255)
        final_round = Image.new("RGBA", (launcher_sz, launcher_sz), (0, 0, 0, 0))
        final_round.paste(round_canvas, (0, 0), mask)
        final_round.save(os.path.join(folder_path, "ic_launcher_round.png"), "PNG")

        # ic_launcher_foreground.png
        fg_canvas = Image.new("RGBA", (fg_sz, fg_sz), (0, 0, 0, 0))
        inner_sz = int(fg_sz * 0.72)
        scaled_icon = im.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
        fg_offset = (fg_sz - inner_sz) // 2
        fg_canvas.paste(scaled_icon, (fg_offset, fg_offset), scaled_icon)
        fg_canvas.save(os.path.join(folder_path, "ic_launcher_foreground.png"), "PNG")

    print("Saved all Android mipmap icons.")

    # 4. iOS icons
    ios_icon_dir = os.path.join(PROJECT_ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    ios_sizes = {
        "Icon-App-20x20@1x.png": (20, 20),
        "Icon-App-20x20@2x.png": (40, 40),
        "Icon-App-20x20@3x.png": (60, 60),
        "Icon-App-29x29@1x.png": (29, 29),
        "Icon-App-29x29@2x.png": (58, 58),
        "Icon-App-29x29@3x.png": (87, 87),
        "Icon-App-40x40@1x.png": (40, 40),
        "Icon-App-40x40@2x.png": (80, 80),
        "Icon-App-40x40@3x.png": (120, 120),
        "Icon-App-60x60@2x.png": (120, 120),
        "Icon-App-60x60@3x.png": (180, 180),
        "Icon-App-76x76@1x.png": (76, 76),
        "Icon-App-76x76@2x.png": (152, 152),
        "Icon-App-83.5x83.5@2x.png": (167, 167),
    }

    if os.path.exists(ios_icon_dir):
        for fname, (w, h) in ios_sizes.items():
            resized = im.resize((w, h), Image.Resampling.LANCZOS)
            resized.save(os.path.join(ios_icon_dir, fname), "PNG")

        # 1024x1024 store icon: must be RGB without alpha (iOS guidelines)
        ios_store_canvas = Image.new("RGB", (1024, 1024), (40, 62, 89))
        resized_1024 = im.resize((1024, 1024), Image.Resampling.LANCZOS)
        ios_store_canvas.paste(resized_1024, (0, 0), resized_1024)
        ios_store_canvas.save(os.path.join(ios_icon_dir, "Icon-App-1024x1024@1x.png"), "PNG")
        print("Saved iOS icons.")

    # 5. macOS icons
    macos_icon_dir = os.path.join(PROJECT_ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    macos_sizes = {
        "app_icon_16.png": (16, 16),
        "app_icon_32.png": (32, 32),
        "app_icon_64.png": (64, 64),
        "app_icon_128.png": (128, 128),
        "app_icon_256.png": (256, 256),
        "app_icon_512.png": (512, 512),
        "app_icon_1024.png": (1024, 1024),
    }

    if os.path.exists(macos_icon_dir):
        for fname, (w, h) in macos_sizes.items():
            resized = im.resize((w, h), Image.Resampling.LANCZOS)
            resized.save(os.path.join(macos_icon_dir, fname), "PNG")
        print("Saved macOS icons.")

    # 6. Web icons
    web_dir = os.path.join(PROJECT_ROOT, "web")
    if os.path.exists(web_dir):
        im.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
        icons_web_dir = os.path.join(web_dir, "icons")
        if os.path.exists(icons_web_dir):
            im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(icons_web_dir, "Icon-192.png"), "PNG")
            im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(icons_web_dir, "Icon-512.png"), "PNG")
            im.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(icons_web_dir, "Icon-maskable-192.png"), "PNG")
            im.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(icons_web_dir, "Icon-maskable-512.png"), "PNG")
        print("Saved Web icons.")

if __name__ == "__main__":
    generate_icons()
    print("All icons generated successfully!")
