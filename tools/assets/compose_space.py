# -*- coding: utf-8 -*-
"""Compose les fonds etoiles 1080x1920 depuis le generateur deep-fold "PixelSpace".

POURQUOI ce script existe (et pourquoi ce n est PAS une extraction)
-------------------------------------------------------------------
`raw_assets/SpaceBackgroundSource.zip` ne contient AUCUNE image de fond. C est un
PROJET GODOT 3 qui *genere* ses fonds a l ecran : deux shaders de bruit
(`Nebulae.shader`, `StarStuff.shader`), un degrade de couleurs (`Colorscheme.tres`)
et des particules d etoiles. Les seuls PNG du zip sont trois vignettes de points
(`stars.png` fait 144x9 pour 36 pixels opaques) : des BROSSES, pas des decors.

Il n y avait donc rien a extraire feuille par feuille. Trois voies possibles :

1. embarquer le projet Godot 3 et le porter en 4.4 -> deux shaders et des
   particules qui tournent A CHAQUE IMAGE derriere les menus, sur mobile, pour un
   fond qui ne bouge pas. Refuse : on paie un cout permanent pour une image fixe.
2. lancer le generateur a la main et faire une capture -> non reproductible, et
   le poste n a pas Godot 3.
3. PORTER LE CALCUL ICI, hors de res://, et n ajouter que le PNG fini.

C est la voie 3, exactement la meme que `compose_backdrops.py` : tout le travail
est fait une fois sur le poste, le jeu ne recoit qu une image plate. Les fonctions
ci-dessous sont la transcription fidele des shaders du pack (meme `rand`, meme
`fbm`, meme `circleNoise`, meme tramage) : le resultat est bien l image du
generateur, pas un bruit maison qui lui ressemblerait.

Licence : deep-fold "PixelSpace", MIT (`SpaceBackground/LICENSE` dans le zip). Le
README du pack ajoute : "do not distribute or sell any generated images on their
own. Feel free to use them in your games" — nos fonds partent DANS le jeu, jamais
vendus seuls, ce qui est le cas autorise.

CE QUI EST PRODUIT
------------------
- `assets/backdrops/menu_space.png` : fond des menus. Teintes froides, nebuleuse
  discrete : c est un arriere-plan, il passe DERRIERE du texte et des panneaux, il
  ne doit pas se battre avec eux.
- `assets/backdrops/act5_divine.png` : acte final "espace divin". Teintes dorees
  et denses, nebuleuse large et lumineuse.

Les deux font 1080x1920 (portrait du jeu), comme les 4 fonds d acte existants.

CE SCRIPT NE BRANCHE RIEN. `battle_backdrop.gd` n est pas touche : les deux PNG
sont poses pour les chantiers C (menus) et D/J (acte final), qui les afficheront.
"""
import math
import os

import numpy as np
from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")

OUT_DIR = "assets/backdrops"
TARGET_W, TARGET_H = 1080, 1920

# Degrade du pack (`Colorscheme.tres`, 8 paliers) : c est lui que les shaders
# echantillonnent avec `col_value`. On garde ses 8 arrets pour que les couleurs
# soient celles du generateur et non une palette inventee.
SCHEME_EMBER = [
    (0.125490, 0.133333, 0.082353), (0.227451, 0.156863, 0.007843),
    (0.588235, 0.235294, 0.235294), (0.792157, 0.352941, 0.180392),
    (1.000000, 0.470588, 0.192157), (0.952941, 0.600000, 0.286275),
    (0.921569, 0.760784, 0.458824), (0.874510, 0.843137, 0.521569),
]
# Deux variantes de teinte, batie sur la meme rampe sombre->claire en 8 paliers.
SCHEME_COLD = [
    (0.055, 0.063, 0.110), (0.090, 0.110, 0.200),
    (0.145, 0.200, 0.360), (0.220, 0.310, 0.520),
    (0.310, 0.450, 0.680), (0.450, 0.600, 0.800),
    (0.640, 0.760, 0.900), (0.840, 0.900, 0.970),
]
SCHEME_DIVINE = [
    (0.090, 0.070, 0.130), (0.180, 0.120, 0.190),
    (0.340, 0.200, 0.240), (0.560, 0.330, 0.250),
    (0.780, 0.500, 0.260), (0.920, 0.680, 0.360),
    (0.970, 0.840, 0.550), (1.000, 0.960, 0.800),
]


def _ramp(scheme):
    """Le degrade en 8 paliers -> table de 256 couleurs, interpolee comme le fait
    GradientTexture. `col_value` arrive en 0..1 et sert d abscisse."""
    stops = np.array(scheme, dtype=np.float64)
    xs = np.linspace(0.0, 1.0, len(stops))
    out = np.zeros((256, 3), dtype=np.float64)
    fine = np.linspace(0.0, 1.0, 256)
    for c in range(3):
        out[:, c] = np.interp(fine, xs, stops[:, c])
    return out


def _sample(ramp, col_value):
    """texture(colorscheme, vec2(col_value, 0.0)) : hors de 0..1, GLSL borne."""
    idx = np.clip(col_value, 0.0, 1.0) * 255.0
    return ramp[np.clip(idx.astype(np.int32), 0, 255)]


def _rand(ix, iy, seed):
    """`rand()` du shader : fract(sin(dot(coord, (12.9898, 78.233))) * (15.5453 + seed)).

    En float64 numpy le sinus est plus precis qu en float32 GPU ; l image garde la
    meme STRUCTURE (c est un bruit de hachage, pas une forme reconnaissable).
    """
    d = ix * 12.9898 + iy * 78.233
    v = np.sin(d) * (15.5453 + seed)
    return v - np.floor(v)


def _noise(x, y, seed):
    """Bruit de valeur a interpolation cubique (smoothstep), comme le shader."""
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    a = _rand(ix, iy, seed)
    b = _rand(ix + 1.0, iy, seed)
    c = _rand(ix, iy + 1.0, seed)
    d = _rand(ix + 1.0, iy + 1.0, seed)
    cx = fx * fx * (3.0 - 2.0 * fx)
    cy = fy * fy * (3.0 - 2.0 * fy)
    return a + (b - a) * cx + (c - a) * cy * (1.0 - cx) + (d - b) * cx * cy


def _fbm(x, y, seed, octaves):
    """Somme d octaves : chaque passe double la frequence et halve l amplitude."""
    value = np.zeros_like(x)
    scale = 0.5
    cx, cy = x.copy(), y.copy()
    for _ in range(octaves):
        value += _noise(cx, cy, seed) * scale
        cx = cx * 2.0
        cy = cy * 2.0
        scale *= 0.5
    return value


def _circle_noise(x, y, seed):
    """`circleNoise()` : des disques decales ligne par ligne. C est lui qui donne
    aux nuages leur grain arrondi plutot qu un flou uniforme."""
    uv_y = np.floor(y)
    x = x + uv_y * 0.31
    fx = x - np.floor(x)
    fy = y - np.floor(y)
    h = _rand(np.floor(x), uv_y, seed)
    m = np.sqrt((fx - 0.25 - h * 0.5) ** 2 + (fy - 0.25 - h * 0.5) ** 2)
    r = h * 0.25
    # smoothstep(0, r, m*0.75)
    t = np.clip(np.divide(m * 0.75, np.maximum(r, 1e-9)), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _cloud_alpha(x, y, seed, octaves):
    c_noise = np.zeros_like(x)
    for i in range(2):
        c_noise += _circle_noise(x * 0.5 + (i + 1) - 0.3, y * 0.5 + (i + 1), seed)
    return _fbm(x + c_noise, y + c_noise, seed, octaves)


def _uv_grid(pixels, aspect):
    """UV pixelisee comme le shader : floor(UV * pixels) / pixels.

    `pixels` est la RESOLUTION DU PIXEL ART (combien de gros pixels en largeur),
    pas la taille de l image. On calcule donc sur une petite grille, puis on
    agrandit au plus proche voisin : c est ce qui donne de vrais pixels carres au
    lieu d un bruit lisse agrandi.
    """
    w = int(pixels)
    h = int(round(pixels * aspect))
    # centre de chaque gros pixel
    us = (np.arange(w) + 0.0) / pixels
    vs = (np.arange(h) + 0.0) / pixels
    return np.meshgrid(us, vs)


def _dither(ux, vy, pixels):
    """`dither()` : mod(uv.y + uv.x, 2/pixels) <= 1/pixels — une trame en damier
    fin qui casse les aplats du degrade."""
    m = np.mod(vy + ux, 2.0 / pixels)
    return m <= (1.0 / pixels)


def nebulae(pixels, aspect, seed, octaves, size, scheme, background, reduce_bg):
    """Port de `Nebulae.shader`. Rend (rgb, alpha) sur la grille de gros pixels."""
    ux, vy = _uv_grid(pixels, aspect)
    ramp = _ramp(scheme)

    d = np.sqrt((ux - 0.5) ** 2 + (vy - 0.5) ** 2) * 0.4
    dith = _dither(ux, vy, pixels)

    n = _cloud_alpha(ux * size, vy * size, seed, octaves)
    n2 = _fbm(ux * size + 1.0, vy * size + 1.0, seed, octaves)
    n_lerp = n2 * n
    n_dust_lerp = n * n_lerp

    n_dust_lerp = np.where(dith, n_dust_lerp * 0.95, n_dust_lerp)
    d = np.where(dith, d * 0.98, d)

    a = (n2 <= (0.1 + d)).astype(np.float64)
    a2 = (n2 <= (0.115 + d)).astype(np.float64)

    if reduce_bg:
        n_dust_lerp = np.power(np.maximum(n_dust_lerp, 0.0), 1.2) * 0.7

    col_value = np.where(a2 > a,
                         np.floor(n_dust_lerp * 35.0) / 7.0,
                         np.floor(n_dust_lerp * 14.0) / 7.0)
    col = _sample(ramp, col_value)
    # `if (col_value < 0.1) col = background_color` : le fond du ciel.
    bg = np.array(background, dtype=np.float64)
    col = np.where((col_value < 0.1)[..., None], bg, col)
    return col, a2


def star_stuff(pixels, aspect, seed, octaves, size, scheme, reduce_bg):
    """Port de `StarStuff.shader` : la poussiere d etoiles, en surcouche."""
    ux, vy = _uv_grid(pixels, aspect)
    ramp = _ramp(scheme)
    dith = _dither(ux, vy, pixels)

    half = math.ceil(size * 0.5)
    n_alpha = _fbm(ux * half + 2.0, vy * half + 2.0, seed, octaves)
    n_dust = _cloud_alpha(ux * size, vy * size, seed, octaves)
    fifth = math.ceil(size * 0.2)
    n_dust2 = _fbm(ux * fifth - 2.0, vy * fifth - 2.0, seed, octaves)
    n_dust_lerp = n_dust2 * n_dust

    n_dust_lerp = np.where(dith, n_dust_lerp * 0.95, n_dust_lerp)
    a_dust = (n_alpha <= (n_dust_lerp * 1.8)).astype(np.float64)
    n_dust_lerp = np.power(np.maximum(n_dust_lerp, 0.0), 3.2) * 56.0
    n_dust_lerp = np.where(dith, n_dust_lerp * 1.1, n_dust_lerp)

    if reduce_bg:
        n_dust_lerp = np.power(np.maximum(n_dust_lerp, 0.0), 0.8) * 0.7

    col_value = np.floor(n_dust_lerp) / 7.0
    return _sample(ramp, col_value), a_dust


def stars(shape, seed, count, palette):
    """Les etoiles ponctuelles. Le pack les tire en particules (`StarParticles.tres`,
    `BigStar.tscn`) ; hors runtime on les pose directement, avec les memes tailles
    (1 px pour la masse, 2-3 px pour quelques grosses)."""
    h, w = shape
    # `seed` est un float (convention des shaders du pack) ; le RNG veut un entier.
    rng = np.random.default_rng(int(seed * 1000))
    layer = np.zeros((h, w, 4), dtype=np.float64)
    for _ in range(count):
        x = rng.integers(0, w)
        y = rng.integers(0, h)
        col = palette[rng.integers(0, len(palette))]
        bright = rng.uniform(0.45, 1.0)
        layer[y, x, :3] = col
        layer[y, x, 3] = bright
    # quelques etoiles plus grosses : une croix de 3 px, comme les BigStar du pack
    for _ in range(max(1, count // 60)):
        x = int(rng.integers(1, w - 1))
        y = int(rng.integers(1, h - 1))
        col = palette[rng.integers(0, len(palette))]
        for dx, dy, al in ((0, 0, 1.0), (1, 0, 0.55), (-1, 0, 0.55), (0, 1, 0.55), (0, -1, 0.55)):
            layer[y + dy, x + dx, :3] = col
            layer[y + dy, x + dx, 3] = max(layer[y + dy, x + dx, 3], al)
    return layer


def _over(dst, src_rgb, src_a):
    """Composition alpha classique (src par-dessus dst), en place."""
    a = src_a[..., None]
    return dst * (1.0 - a) + src_rgb * a


def compose(name, scheme, background, seed, size, octaves, pixels,
            star_count, star_palette, dust_scheme, reduce_bg):
    aspect = TARGET_H / TARGET_W
    out = np.zeros((int(round(pixels * aspect)), int(pixels), 3), dtype=np.float64)
    out[:, :] = np.array(background, dtype=np.float64)

    # 1. la poussiere d etoiles en premier : c est le voile le plus large
    dust_rgb, dust_a = star_stuff(pixels, aspect, seed + 3, octaves, size * 0.6,
                                  dust_scheme, reduce_bg)
    out = _over(out, dust_rgb, dust_a * 0.55)

    # 2. la nebuleuse par-dessus
    neb_rgb, neb_a = nebulae(pixels, aspect, seed, octaves, size, scheme,
                             background, reduce_bg)
    out = _over(out, neb_rgb, neb_a)

    # 3. les etoiles en dernier : elles doivent rester visibles sur la nebuleuse
    st = stars(out.shape[:2], seed + 7, star_count, star_palette)
    out = _over(out, st[..., :3], st[..., 3])

    img = Image.fromarray(np.clip(out * 255.0, 0, 255).astype(np.uint8), "RGB")
    # agrandissement au PLUS PROCHE VOISIN : on veut des pixels carres nets, pas
    # un degrade lisse (le pack est du pixel art).
    img = img.resize((TARGET_W, TARGET_H), Image.NEAREST)
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path, optimize=True)
    print("%-22s %dx%d  %d ko" % (name, img.width, img.height,
                                  os.path.getsize(path) // 1024))
    return path


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # Fond de MENUS : froid et sobre. `reduce_bg` attenue la poussiere, sinon le
    # fond monte en luminosite et le texte des menus ne se detache plus.
    compose("menu_space", SCHEME_COLD, (0.035, 0.040, 0.075),
            seed=3.0, size=5.0, octaves=5, pixels=270,
            star_count=420, star_palette=[(0.85, 0.90, 1.0), (0.70, 0.80, 1.0),
                                          (1.0, 0.96, 0.88)],
            dust_scheme=SCHEME_COLD, reduce_bg=True)

    # ACTE FINAL "espace divin" : dore et dense. Pas de `reduce_bg` : ici le fond
    # DOIT rayonner, c est le decor d un acte, pas un arriere-plan de menu.
    #
    # La poussiere prend la MEME rampe doree que la nebuleuse. Premier essai avec
    # `SCHEME_EMBER` (la rampe d origine du pack, qui part d un vert olive) : sous
    # la nebuleuse violette elle virait au brun boueux, plus "caverne" que "divin".
    # Vu sur la capture, corrige ici.
    compose("act5_divine", SCHEME_DIVINE, (0.055, 0.035, 0.065),
            seed=7.0, size=4.0, octaves=6, pixels=270,
            star_count=560, star_palette=[(1.0, 0.95, 0.80), (1.0, 0.86, 0.55),
                                          (0.95, 0.90, 1.0)],
            dust_scheme=SCHEME_DIVINE, reduce_bg=False)


if __name__ == "__main__":
    main()
