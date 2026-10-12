"""logo-mark.svg dan: app-icon.svg (yumaloq kvadrat fon), maskable (to'liq fon) — belgi ichiga joylanadi."""
import re, sys
from pathlib import Path
d = Path(sys.argv[1])
mark = (d / "logo-mark.svg").read_text()
inner = re.search(r"<svg[^>]*>(.*)</svg>", mark, re.S).group(1)
BG = '''<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1f6e3c"/><stop offset="1" stop-color="#0a2a17"/></linearGradient>
    <radialGradient id="glow" cx=".6" cy=".52" r=".55"><stop offset="0" stop-color="#f6b72c" stop-opacity=".2"/><stop offset="1" stop-color="#f6b72c" stop-opacity="0"/></radialGradient>'''
def icon(rx, scale, name, note):
    off = (512 - 512 * scale) / 2
    (d / name).write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <!-- {note} (deploy: assets/brand/README.md) -->
  <defs>{BG}</defs>
  <rect width="512" height="512" rx="{rx}" fill="url(#bg)"/>
  <rect width="512" height="512" rx="{rx}" fill="url(#glow)"/>
  <g transform="translate({off:.1f} {off - 4:.1f}) scale({512 * scale / 100:.3f})">{inner}</g>
</svg>
''')
icon(112, 0.80, "app-icon.svg", "Ilova belgisi: yumaloq kvadrat")
icon(0, 0.64, "app-icon-maskable.svg", "Android/PWA maskable: to'liq fon, belgi xavfsiz zonada")
print("ok")
