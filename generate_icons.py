from PIL import Image, ImageDraw
import os

sizes = {
    'drawable-mdpi': 24,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 48,
    'drawable-xxhdpi': 72,
    'drawable-xxxhdpi': 96
}

base_path = 'android/app/src/main/res'

for folder, size in sizes.items():
    path = os.path.join(base_path, folder)
    os.makedirs(path, exist_ok=True)
    
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw X
    # Thickness relative to size
    thickness = max(2, int(size * 0.1))
    padding = int(size * 0.2)
    
    # Line 1
    draw.line((padding, padding, size - padding, size - padding), fill='white', width=thickness)
    # Line 2
    draw.line((padding, size - padding, size - padding, padding), fill='white', width=thickness)
    
    img.save(os.path.join(path, 'audio_service_stop.png'))
    print(f'Saved {size}x{size} to {folder}')
