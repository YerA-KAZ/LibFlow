"""Generate matching editable SVG and exportable PNG architecture diagrams."""
from html import escape
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
out = root / 'docs/final'
out.mkdir(parents=True, exist_ok=True)
canvas = Image.new('RGB', (1600, 1110), '#f3f6f3')
draw = ImageDraw.Draw(canvas)
font_path = 'C:/Windows/Fonts/arial.ttf'
bold_path = 'C:/Windows/Fonts/arialbd.ttf'
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1110" viewBox="0 0 1600 1110">',
       '<rect width="1600" height="1110" fill="#f3f6f3"/>',
       '<defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#62756b"/></marker></defs>']


def text(x, y, value, size=22, color='#183e30', bold=False):
    draw.text((x, y), value, font=ImageFont.truetype(bold_path if bold else font_path, size), fill=color)
    svg.append(f'<text x="{x}" y="{y+size}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{"700" if bold else "400"}">{escape(value)}</text>')


def rect(x, y, w, h, color, border='#cbd9d0'):
    draw.rounded_rectangle((x, y, x+w, y+h), radius=18, fill=color, outline=border, width=2)
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="18" fill="{color}" stroke="{border}" stroke-width="2"/>')


def box(x, y, w, title, lines, color='#ffffff'):
    rect(x, y, w, 130, color)
    text(x+22, y+18, title, 25, bold=True)
    for i, line in enumerate(lines):
        text(x+22, y+57+i*26, line, 19, '#52665b')


def arrow(points, label=None, label_at=None):
    draw.line(points, fill='#62756b', width=3)
    x, y = points[-1]
    px, py = points[-2]
    if x > px:
        tip = [(x, y), (x-10, y-6), (x-10, y+6)]
    elif x < px:
        tip = [(x, y), (x+10, y-6), (x+10, y+6)]
    elif y > py:
        tip = [(x, y), (x-6, y-10), (x+6, y-10)]
    else:
        tip = [(x, y), (x-6, y+10), (x+6, y+10)]
    draw.polygon(tip, fill='#62756b')
    svg.append('<polyline points="'+' '.join(f'{a},{b}' for a,b in points)+'" fill="none" stroke="#62756b" stroke-width="3" marker-end="url(#arrow)"/>')
    if label:
        text(*label_at, label, 17, '#52665b')


text(45, 30, 'LibFlow', 46, bold=True)
text(245, 44, 'APPLICATION ARCHITECTURE', 25, '#62756b')
text(45, 97, 'Flutter mobile app  /  local authentication  /  REST + WebSocket  /  PostgreSQL', 22)
rect(40, 150, 950, 870, '#e9f0eb')
rect(1040, 150, 520, 870, '#eef0f6', '#d2d8e6')
text(68, 164, 'ANDROID / iOS CLIENT', 18, bold=True)
text(1066, 164, 'SERVER / EXTERNAL SERVICES', 18, bold=True)
box(80, 210, 870, 'UI · Screens & navigation',
    ['Auth / Splash → Home / Catalogue / My Books / Profile',
     'Detail / Form / Reader / Card / Notifications / QR scanner'])
box(80, 410, 350, 'AuthProvider', ['Local account + session', 'Provider / ChangeNotifier'])
box(540, 410, 410, 'LibraryRepository', ['REST CRUD + realtime events', 'Loading / Success / Error + logs'])
box(80, 610, 350, 'Secure storage', ['Salted PBKDF2 password hash', '30-day local session'])
box(540, 610, 410, 'Offline JSON cache', ['Books + personal reading state', 'Application support directory'])
box(80, 835, 350, 'QR scanner', ['Permission handling', 'Local reservation validation'])
box(540, 835, 410, 'Device services', ['Camera / mobile_scanner', 'QR rendering / qr_flutter'])
box(1090, 210, 420, 'External book search', ['Google Books / Open Library', 'Search results → catalogue import'])
box(1090, 410, 420, 'FastAPI', ['REST /api/books · WS /ws/catalogue', 'Validation → commit → broadcast'])
box(1090, 610, 420, 'PostgreSQL', ['books: id / JSONB / updated_at', 'schema_migrations + seed once'])
box(1090, 835, 420, 'Test & diagnostics', ['Unit / Widget / API / Android', 'Analyzer · terminal logs · APK'])
arrow([(250,340),(250,410)])
arrow([(745,340),(745,410)])
arrow([(250,540),(250,610)])
arrow([(745,540),(745,610)])
arrow([(80,275),(62,275),(62,900),(80,900)])
arrow([(430,900),(540,900)], 'camera', (452,868))
arrow([(950,445),(1090,445)], 'REST', (990,414))
arrow([(1090,500),(950,500)], 'WS events', (982,510))
arrow([(1300,540),(1300,610)])
arrow([(950,260),(1090,260)], 'HTTPS', (984,229))
text(68, 1045, 'Auth stays on the device. The API has no token/RBAC layer. The notification hub uses one server process.', 19)
text(68, 1076, 'LibFlow 1.0.0+1  ·  Technical handoff  ·  2026-11-04', 17, '#62756b')
svg.append('</svg>')
(out / 'architecture.svg').write_text('\n'.join(svg), encoding='utf-8')
canvas.save(out / 'architecture.png')
print(out / 'architecture.png')
