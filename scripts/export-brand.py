"""Export the shared logo geometry as SVG and antialiased PNGs (requires Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
spec = json.loads((root / 'branding/logo.json').read_text())
out = root / 'build/branding'
out.mkdir(parents=True, exist_ok=True)

def svg(mark_only=False):
    shapes = []
    if not mark_only:
        shapes.append(f'<rect x="0.5" y="0.5" width="63" height="63" rx="{spec["radius"]}" fill="{spec["background"]}" stroke="{spec["border"]}"/>')
    for stroke in spec['strokes']:
        a, b = stroke['from'], stroke['to']
        shapes.append(f'<path d="M{a[0]} {a[1]}L{b[0]} {b[1]}" fill="none" stroke="{spec[stroke["color"]]}" stroke-width="{spec["strokeWidth"]}" stroke-linecap="round"/>')
    d = spec['diamond']; x, y = d['center']; r = d['radius']
    shapes.append(f'<path d="M{x} {y-r}L{x+r} {y}L{x} {y+r}L{x-r} {y}Z" fill="{spec[d["color"]]}"/>')
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Keynova logo">' + ''.join(shapes) + '</svg>\n'

for mark_only in (False, True):
    name = 'keynova-mark' if mark_only else 'keynova-logo'
    (out / f'{name}.svg').write_text(svg(mark_only))
    for size in (32, 128, 512):
        supersample = 4
        factor = size * supersample / spec['size']
        im = Image.new('RGBA', (size * supersample,) * 2)
        draw = ImageDraw.Draw(im)
        if not mark_only:
            draw.rounded_rectangle((0.5*factor,0.5*factor,63.5*factor,63.5*factor),radius=spec['radius']*factor,fill=spec['background'],outline=spec['border'],width=max(1,round(factor)))
        for stroke in spec['strokes']:
            a, b = [tuple(v*factor for v in point) for point in (stroke['from'],stroke['to'])]
            width = spec['strokeWidth'] * factor
            color = spec[stroke['color']]
            draw.line((a,b),fill=color,width=round(width))
            for x,y in (a,b): draw.ellipse((x-width/2,y-width/2,x+width/2,y+width/2),fill=color)
        d = spec['diamond']; x,y = d['center']; r = d['radius']
        draw.polygon([(a*factor,b*factor) for a,b in [(x,y-r),(x+r,y),(x,y+r),(x-r,y)]],fill=spec[d['color']])
        im.resize((size,size),Image.Resampling.LANCZOS).save(out / f'{name}-{size}.png')
print(out)
