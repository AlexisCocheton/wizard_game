#!/usr/bin/env python3
"""Fabrique les COSMETIQUES de compte : chapeaux du mage, tours, bannieres de titre.

POURQUOI un remplacement de palette et pas un simple `modulate` :
un `modulate` multiplie TOUS les pixels, y compris la peau, le bois et le
contour noir. Une robe rouge rendait donc un mage a la peau rouge et au contour
brun. Les feuilles de Tiny Swords sont des palettes indexees a la main : les
trois variantes fournies (monk_blue / monk_black / monk_purple) ne different
QUE par deux couleurs, ce qui prouve que le remplacement exact est la methode
voulue par l auteur du pack.

On ne touche donc que les couleurs NOMMEES ci-dessous, pixel par pixel. Tout le
reste — peau, contour, ombre — reste identique, et le mage reste lisible.

Usage : python tools/assets/make_cosmetics.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / "assets" / "units"
TERRAIN = ROOT / "assets" / "terrain"
UI = ROOT / "assets" / "ui"

# --- Chapeau du mage -------------------------------------------------------
# Les deux seules couleurs du chapeau de paille, mesurees sur la region de tete
# (y 60..101) de monk_blue_idle : 368 pixels a elles deux, et elles n
# apparaissent nulle part ailleurs sur le sprite.
HAT_LIGHT = (239, 225, 171, 255)
HAT_DARK = (200, 168, 118, 255)

# (cle, clair, sombre). "straw" est l original : il n est pas regenere, il sert
# de valeur par defaut pour un profil neuf.
HATS = {
    "crimson": ((236, 138, 132, 255), (168, 62, 66, 255)),
    "emerald": ((150, 226, 160, 255), (54, 140, 84, 255)),
    "violet": ((214, 166, 240, 255), (128, 72, 168, 255)),
    "gold": ((252, 232, 140, 255), (206, 158, 46, 255)),
}

# Les trois animations du mage, chacune sur sa propre feuille.
MONK_SHEETS = ["monk_blue_idle", "monk_blue_walk", "monk_blue_cast"]

# --- Tour du mage ----------------------------------------------------------
# Le bleu de tower_blue.png, en quatre tons (du plus sombre au plus clair).
# Ce sont les memes familles que la robe du moine : la tour et le mage sont
# dessines dans la meme palette, c est ce qui les fait aller ensemble.
TOWER_BLUES = [
    (76, 92, 139, 255),
    (71, 149, 167, 255),
    (99, 183, 186, 255),
    (139, 216, 200, 255),
]

TOWERS = {
    # Pierre chaude : la tour "par defaut" alternative, sable et ocre.
    "sand": [(122, 96, 80, 255), (176, 134, 84, 255), (208, 170, 112, 255), (238, 214, 160, 255)],
    # Obsidienne : violette sombre, pour un mage de fin de campagne.
    "obsidian": [(66, 54, 96, 255), (108, 76, 152, 255), (146, 110, 190, 255), (190, 160, 226, 255)],
    # Braise : rouge, la plus voyante, reservee au haut niveau.
    "ember": [(112, 52, 56, 255), (176, 68, 58, 255), (216, 110, 62, 255), (244, 178, 104, 255)],
}

# --- Banniere de titre -----------------------------------------------------
# ribbon_title9.png est une planche BOIS + CORDE. On la reteinte entierement,
# banniere comprise : ici le `modulate` par multiplication est legitime, car
# toute l image est un seul materiau (pas de peau ni de detail a preserver).
# Teintes choisies pour se lire sur le bois sombre du menu.
BANNERS = {
    "ribbon_title_silver": (0.82, 0.86, 0.94),
    "ribbon_title_gold": (1.10, 0.94, 0.52),
    "ribbon_title_crystal": (0.62, 0.92, 1.04),
}


def remap(src: Path, dst: Path, mapping: dict) -> None:
    """Remplace des couleurs EXACTES. Un pixel absent du dictionnaire est recopie."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    touched = 0
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c in mapping:
                px[x, y] = mapping[c]
                touched += 1
    im.save(dst)
    print(f"  {dst.name}  ({touched} pixels reteintes)")


def tint(src: Path, dst: Path, factor: tuple) -> None:
    """Multiplie les canaux de couleur, alpha intact (teinte d un materiau uni)."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                min(255, int(r * factor[0])),
                min(255, int(g * factor[1])),
                min(255, int(b * factor[2])),
                a,
            )
    im.save(dst)
    print(f"  {dst.name}")


def main() -> None:
    print("Chapeaux du mage :")
    for key, (light, dark) in HATS.items():
        mapping = {HAT_LIGHT: light, HAT_DARK: dark}
        for sheet in MONK_SHEETS:
            src = UNITS / f"{sheet}.png"
            if not src.exists():
                print(f"  ABSENT {src.name}")
                continue
            # monk_blue_idle -> monk_hat_crimson_idle : le prefixe dit que c est
            # une variante de CHAPEAU, la robe restant celle du monk_blue.
            anim = sheet.rsplit("_", 1)[1]
            remap(src, UNITS / f"monk_hat_{key}_{anim}.png", mapping)

    print("Tours :")
    base = TERRAIN / "tower_blue.png"
    if base.exists():
        for key, colors in TOWERS.items():
            mapping = dict(zip(TOWER_BLUES, colors))
            remap(base, TERRAIN / f"tower_{key}.png", mapping)
    else:
        print("  ABSENT tower_blue.png")

    print("Bannieres de titre :")
    ribbon = UI / "ribbon_title9.png"
    if ribbon.exists():
        for name, factor in BANNERS.items():
            # Le suffixe 9 est la convention que l AUDIT protege : une texture
            # recomposee se termine par 9, sinon le garde-fou des planches
            # brutes la prend pour une planche crue (piege documente).
            tint(ribbon, UI / f"{name}9.png", factor)
    else:
        print("  ABSENT ribbon_title9.png")


if __name__ == "__main__":
    main()
