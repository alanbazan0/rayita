"""Genera el ícono de la app (assets/icon/*.png) con Pillow.

Uso: python3 tool/make_icon.py
Diseño: marcas de conteo (4 rayas + la tachada del 5.º) sobre el degradado índigo.
También regenera las imágenes de la pantalla de arranque de iOS.
"""
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 3  # supersampling para bordes suaves
S = SIZE * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_bg():
    top, bottom = (0x7A, 0x90, 0xE8), (0x4A, 0x4C, 0xC9)
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * (S - 1))  # diagonal
            px[x, y] = lerp(top, bottom, t)
    # Brillo suave arriba a la izquierda.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([-S * 0.2, -S * 0.3, S * 0.75, S * 0.55], fill=38)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.18))
    return Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), img, glow)


def s(v):
    return int(v * SS)


def tally_layer():
    """Marcas de conteo sobre fondo transparente (con sombra).

    Todo queda dentro de la zona segura del ícono adaptable de Android (~66 %).
    """
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    bar_w, top, bottom = 60, 292, 732
    xs = [344, 456, 568, 680]
    white = (255, 255, 255, 255)
    amber = (255, 209, 102, 255)
    slash = ((262, 660), (762, 364))

    def draw_marks(d, dy=0, flat=None):
        for x in xs:
            d.rounded_rectangle(
                [s(x - bar_w / 2), s(top + dy), s(x + bar_w / 2), s(bottom + dy)],
                radius=s(bar_w / 2), fill=flat or white,
            )
        p0, p1 = slash
        d.line([(s(p0[0]), s(p0[1] + dy)), (s(p1[0]), s(p1[1] + dy))], fill=flat or amber, width=s(bar_w))
        for p in (p0, p1):
            r = bar_w / 2
            d.ellipse([s(p[0] - r), s(p[1] + dy - r), s(p[0] + r), s(p[1] + dy + r)], fill=flat or amber)

    # Sombra suave.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_marks(ImageDraw.Draw(shadow), dy=20, flat=(20, 22, 90, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(s(18)))
    layer = Image.alpha_composite(layer, shadow)

    draw_marks(ImageDraw.Draw(layer))
    return layer


def to_size(img, mode):
    return img.resize((SIZE, SIZE), Image.LANCZOS).convert(mode)


fg = tally_layer()
bg = gradient_bg().convert("RGBA")

icon = Image.alpha_composite(bg, fg)
to_size(icon, "RGB").save("assets/icon/app_icon.png")
to_size(fg, "RGBA").save("assets/icon/app_icon_foreground.png")

# Pantalla de arranque de iOS: las marcas centradas (el fondo lo pone el storyboard).
crop = to_size(fg, "RGBA").crop((212, 212, 812, 812))
for name, scale in (("LaunchImage.png", 1), ("LaunchImage@2x.png", 2), ("LaunchImage@3x.png", 3)):
    w, h = 168 * scale, 185 * scale
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    side = 168 * scale
    canvas.paste(crop.resize((side, side), Image.LANCZOS), (0, (h - side) // 2))
    canvas.save(f"ios/Runner/Assets.xcassets/LaunchImage.imageset/{name}")
print("ok")
