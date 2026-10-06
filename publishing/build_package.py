from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw, ImageFont
import hashlib

root = Path(__file__).resolve().parent.parent
addon = root / 'LawkhsTalentMerger'
out = root / 'dist'
out.mkdir(exist_ok=True)
version = next(line.split(':', 1)[1].strip() for line in (addon / 'LawkhsTalentMerger.toc').read_text(encoding='utf-8').splitlines() if line.startswith('## Version:'))
zip_path = out / f'LawkhsTalentMerger-{version}.zip'
files = [addon / name for name in ['Localization.lua', 'Core.lua', 'UI.lua', 'Restore.lua', 'Dashboard.lua', 'LawkhsTalentMerger.toc']]
with ZipFile(zip_path, 'w', ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, 'LawkhsTalentMerger/' + path.name)
    archive.write(root / 'LICENSE', 'LawkhsTalentMerger/LICENSE')
    archive.write(root / 'publishing' / 'curseforge-description.md', 'LawkhsTalentMerger/README.md')
with ZipFile(zip_path) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == 8
    for path in files:
        assert archive.read('LawkhsTalentMerger/' + path.name) == path.read_bytes()

# Original geometric artwork; no Blizzard images or trademarks.
image = Image.new('RGB', (400, 400), '#101725')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((12, 12, 387, 387), radius=52, outline='#39516c', width=5)
colors = ['#66ccff', '#e699ff', '#99e699']
for x, color in zip([90, 200, 310], colors):
    draw.line([(x, 90), (x, 150), (200, 212)], fill=color, width=10)
    draw.ellipse((x - 24, 56, x + 24, 104), fill='#18273b', outline=color, width=7)
draw.ellipse((154, 187, 246, 279), fill='#20364d', outline='#ffcf70', width=9)
draw.line([(180, 233), (194, 248), (222, 216)], fill='#ffcf70', width=9)
font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 55)
draw.text((200, 336), 'LM', font=font, fill='#e4edf7', anchor='mm')
icon_path = root / 'publishing' / 'curseforge-icon.png'
image.save(icon_path)
print(zip_path)
print('SHA256:', hashlib.sha256(zip_path.read_bytes()).hexdigest())
print('ZIP verified: 8 files, one addon folder, no development dependencies.')
print(icon_path)
