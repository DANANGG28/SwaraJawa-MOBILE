import os
from PIL import Image

def generate_icons():
    logo_path = 'asset/logo/Logo_TP.png'
    if not os.path.exists(logo_path):
        print(f"File {logo_path} not found")
        return

    logo = Image.open(logo_path).convert('RGBA')
    bg_color = (117, 81, 255, 255)  # #7551FF (AppColors.primary600)

    # Legacy launcher icons (square icon with purple background & centered logo)
    sizes = {
        'android/app/src/main/res/mipmap-mdpi': 48,
        'android/app/src/main/res/mipmap-hdpi': 72,
        'android/app/src/main/res/mipmap-xhdpi': 96,
        'android/app/src/main/res/mipmap-xxhdpi': 144,
        'android/app/src/main/res/mipmap-xxxhdpi': 192,
    }

    for dir_path, size in sizes.items():
        os.makedirs(dir_path, exist_ok=True)
        # Create purple background canvas
        canvas = Image.new('RGBA', (size, size), bg_color)

        # Scale logo to 72% of canvas for balanced padding
        inner_size = int(size * 0.72)
        scaled_logo = logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)

        offset = ((size - inner_size) // 2, (size - inner_size) // 2)
        canvas.paste(scaled_logo, offset, scaled_logo)

        out_file = os.path.join(dir_path, 'ic_launcher.png')
        canvas.save(out_file, 'PNG')
        print(f"Saved {out_file} ({size}x{size})")

    # Adaptive icon foregrounds (108dp base canvas, safe zone center 66dp)
    fg_sizes = {
        'android/app/src/main/res/mipmap-mdpi': 108,
        'android/app/src/main/res/mipmap-hdpi': 162,
        'android/app/src/main/res/mipmap-xhdpi': 216,
        'android/app/src/main/res/mipmap-xxhdpi': 324,
        'android/app/src/main/res/mipmap-xxxhdpi': 432,
    }

    for dir_path, size in fg_sizes.items():
        os.makedirs(dir_path, exist_ok=True)
        # Transparent canvas
        fg_canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))

        # Scale logo within adaptive safe zone (~52% of canvas)
        inner_size = int(size * 0.52)
        scaled_logo = logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)

        offset = ((size - inner_size) // 2, (size - inner_size) // 2)
        fg_canvas.paste(scaled_logo, offset, scaled_logo)

        out_file = os.path.join(dir_path, 'ic_launcher_foreground.png')
        fg_canvas.save(out_file, 'PNG')
        print(f"Saved {out_file} ({size}x{size})")

if __name__ == '__main__':
    generate_icons()
