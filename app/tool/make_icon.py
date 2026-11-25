"""Genera el ícono de la app (assets/icon/*.png) y los íconos web con Pillow.

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


def tally_layer(bar_w=60, shadow=True):
    """Marcas de conteo sobre fondo transparente (con sombra).

    Todo queda dentro de la zona segura del ícono adaptable de Android (~66 %).
    """
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    top, bottom = 292, 732
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
    if shadow:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        draw_marks(ImageDraw.Draw(sh), dy=20, flat=(20, 22, 90, 110))
        sh = sh.filter(ImageFilter.GaussianBlur(s(18)))
        layer = Image.alpha_composite(layer, sh)

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

# --- Web: favicon y los íconos de la PWA/pestaña -----------------------------
# El favicon es un recorte del ícono con las rayitas más gruesas y sin sombra,
# para que se lea a 16-32 px. Las esquinas van redondeadas.
def rounded(img, radius_ratio=0.22):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], radius=int(img.size[0] * radius_ratio), fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


fav_src = Image.alpha_composite(bg, tally_layer(bar_w=92, shadow=False)).convert("RGBA")
fav_src = fav_src.resize((SIZE, SIZE), Image.LANCZOS).crop((150, 150, 874, 874))
for px in (16, 32, 48, 64):
    fav = rounded(fav_src.resize((px, px), Image.LANCZOS))
    fav.save(f"web/favicon-{px}.png")
rounded(fav_src.resize((48, 48), Image.LANCZOS)).save("web/favicon.png")
rounded(fav_src.resize((256, 256), Image.LANCZOS)).save(
    "web/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)]
)

# Íconos de la PWA (192/512) con el diseño completo; los "maskable" llevan el
# contenido dentro de la zona segura (el diseño ya la respeta).
full = to_size(icon, "RGB")
for px in (192, 512):
    full.resize((px, px), Image.LANCZOS).save(f"web/icons/Icon-{px}.png")
    full.resize((px, px), Image.LANCZOS).save(f"web/icons/Icon-maskable-{px}.png")
print("ok")
