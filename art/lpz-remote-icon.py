# Gera os ícones do app a partir de art/lpz-remote-original.png (arte do André, 13/nov/2026).
# Recorte quadrado centrado na cabeça da pantera; sem transparência (exigência do iOS).
import os, re
from PIL import Image
base = os.path.dirname(os.path.abspath(__file__))
src = Image.open(os.path.join(base, 'lpz-remote-original.png')).convert('RGB')
W, H = src.size
crop = src.crop((int(W*0.06), 0, int(W*0.94), int(H*0.88)))   # 880x880: cabeça maior no ícone
crop = crop.resize((1024, 1024), Image.LANCZOS)
crop.save(os.path.join(base, 'lpz-remote-icon-1024.png'))
d = os.path.join(base, '..', 'Limelight', 'Images.xcassets', 'AppIcon.appiconset')
for f in os.listdir(d):
    if not f.endswith('.png'): continue
    m = re.search(r'(\d+(?:\.\d+)?)x\1@(\d)x', f)
    px = 1024 if f.startswith('1024') else round(float(m.group(1)) * int(m.group(2)))
    crop.resize((px, px), Image.LANCZOS).save(os.path.join(d, f))
    print(f, px)
