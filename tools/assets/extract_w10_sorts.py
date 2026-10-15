"""Feuilles d effet et icones des cinq sorts neufs de la vague 10 (chantier B1a).

Une feuille PROPRE par carte (l AUDIT refuse un partage) et une icone DEDIEE
par carte (test_card_icons). Rien n est pris au pack Batareya (licence
inconnue, voir docs/assets_index.md).

FEUILLES : pack « Effect and FX Pixel All Free » (le meme que extract_fxpack.py,
9 lignes = 9 teintes, cases de 64 px). On n extrait qu UNE ligne, la teinte de
l element du sort ; aucun des cinq effets n etait deja pris par une carte (ni
dans le meme fichier sous une autre teinte) :

  gust_streak    Part 3/136 ligne 5 (blanc)   south_wind : rafales en virgules
                 qui filent ; c est la tuile que la meteo du vent fait glisser sur
                 tout le terrain (Fx.w10_weather).
  bolt_cross     Part 7/324 ligne 5 (blanc)   electric_mark : deux eclairs en
                 croix, une MARQUE ; le blanc est la teinte la plus proche du
                 jaune de la foudre (le pack n a pas de ligne jaune).
  rain_streaks   Part 9/447 ligne 2 (bleu)    heavy_rain : stries de pluie en
                 diagonale, la tuile de la meteo de la pluie.
  water_geyser   Part 11/529 ligne 2 (bleu)   water_jet : un jet qui monte en
                 cone puis retombe en anneaux, la colonne du jet en I.
  sand_ring      Part 4/184 ligne 4 (ocre)    quicksand : un anneau de grains qui
                 tourne et se resserre, le sable qui avale.

ICONES : packs craftpix deja autorises (commercial oui, credit non,
redistribution des sources non), choisies sur planches de contact des packs
entiers, icones deja livrees reperees par empreinte et ecartees :

  south_wind     Aeromancer 25   un tourbillon de vent qui emporte des feuilles.
  electric_mark  FireMage 25     un eclair qui se ramifie, recolore au degrade de
                 la FOUDRE (celui du logo, extract_elements.py) : rouge, il se
                 lisait comme un sort de feu.
  heavy_rain     Night Elf 49    des stries qui tombent en diagonale, recolorees
                 au degrade de l EAU (violettes, elles se lisaient comme de
                 l arcane).
  water_jet      Aeromancer 32   une colonne bleue qui s eleve.
  quicksand      EarthMage 36    un sol ocre qui se fend et s effondre.

Usage : python tools/assets/extract_w10_sorts.py  (racine du projet)
Le chemin des packs se regle par WIZARD_RAW (defaut : raw_assets/ du depot
principal, les worktrees n en ont pas de copie). Les entrees Fx.STRIPS et
Fx.OCC des cinq feuilles sont ECRITES a la main dans scripts/game/fx.gd (bloc
« vague 10 ») : ce script les affiche, il ne reecrit pas fx.gd —
measure_occupancy.py reecrirait tout le catalogue (voir assets.md).
"""
import io
import os
import re
import sys
import zipfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.environ.get("WIZARD_RAW") or os.path.join(PROJ, "raw_assets")
if not os.path.isfile(os.path.join(RAW, "Effect and FX Pixel All Free.zip")):
    RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets"
PACK_FX = os.path.join(RAW, "Effect and FX Pixel All Free.zip")
PACKS_ICONES = os.path.join(RAW, "packs_2026_09_26")

CELL = 64
SIZE = 128

# nom -> (part, fichier, ligne de teinte)
FEUILLES = {
    "gust_streak": (3, "136", 5),
    "bolt_cross": (7, "324", 5),
    "rain_streaks": (9, "447", 2),
    "water_geyser": (11, "529", 2),
    "sand_ring": (4, "184", 4),
}

PACKS = {
    "aero": "Free 50 Aeromancer Skills.zip",
    "fire": "FireMage_Free.zip",
    "elf": "Free-RPG-Night-Elf-Skill-Icons.zip",
    "earth": "EarthMage_Free.zip",
}
# Degrades (sombre, clair) des logos d element (tools/assets/extract_elements.py).
FOUDRE = ((20, 16, 64), (255, 245, 110))
EAU = ((6, 18, 64), (150, 205, 255))

# id -> (pack, numero, degrade ou None)
ICONES = {
    "south_wind": ("aero", 25, None),
    "electric_mark": ("fire", 25, FOUDRE),
    "heavy_rain": ("elf", 49, EAU),
    "water_jet": ("aero", 32, None),
    "quicksand": ("earth", 36, None),
}


def _ligne(image, row):
    """La ligne `row`, colonnes vides de FIN retirees (comme extract_fxpack)."""
    alpha = np.array(image)[:, :, 3]
    keep = 0
    for c in range(image.size[0] // CELL):
        if (alpha[row * CELL:(row + 1) * CELL, c * CELL:(c + 1) * CELL] > 24).any():
            keep = c + 1
    if keep == 0:
        sys.exit("ligne %d entierement vide" % row)
    return image.crop((0, row * CELL, keep * CELL, (row + 1) * CELL)), keep


def _occupation(path):
    """Plus grande boite opaque d une case, rapportee a la case (Fx.OCC)."""
    img = Image.open(path).convert("RGBA")
    alpha = np.array(img)[:, :, 3] > 24
    best = 0
    for c in range(img.size[0] // CELL):
        ys, xs = np.where(alpha[:, c * CELL:(c + 1) * CELL])
        if len(xs):
            best = max(best, xs.max() - xs.min() + 1, ys.max() - ys.min() + 1)
    return best / float(CELL)


def feuilles():
    dest = os.path.join(PROJ, "assets", "fx")
    with zipfile.ZipFile(PACK_FX) as z:
        for nom, (part, fichier, ligne) in FEUILLES.items():
            src = Image.open(io.BytesIO(z.read("Free/Part %d/%s.png" % (part, fichier))))
            src = src.convert("RGBA")
            if src.size[1] != 9 * CELL or src.size[0] % CELL:
                sys.exit("%s : geometrie inattendue %s" % (fichier, src.size))
            bande, n = _ligne(src, ligne)
            chemin = os.path.join(dest, nom + ".png")
            bande.save(chemin, optimize=True)
            print('feuille %-13s %2d cases  STRIPS: "%s": ["%s", 64, 64, 16],  OCC: "%s": %.2f,'
                  % (nom, n, nom, nom, nom, _occupation(chemin)))


def _icone(pack, num):
    zf = zipfile.ZipFile(os.path.join(PACKS_ICONES, PACKS[pack]))
    meilleure = None
    for n in zf.namelist():
        if "__MACOSX" in n:
            continue
        if re.search(r"(^|/|_)%d\.png$" % num, n):
            im = Image.open(io.BytesIO(zf.read(n))).convert("RGBA")
            if meilleure is None or im.size[0] > meilleure.size[0]:
                meilleure = im
    if meilleure is None:
        sys.exit("introuvable : %s %d" % (pack, num))
    return meilleure


def _recolore(im, sombre, clair):
    """Remappe la luminance sur le degrade sombre -> clair de l element."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            px[x, y] = tuple(int(sombre[k] + (clair[k] - sombre[k]) * t) for k in range(3)) + (a,)
    return out


def icones():
    dest = os.path.join(PROJ, "assets", "icons")
    for cle, (pack, num, degrade) in ICONES.items():
        im = _icone(pack, num).resize((SIZE, SIZE), Image.LANCZOS)
        if degrade is not None:
            im = _recolore(im, degrade[0], degrade[1])
        im.save(os.path.join(dest, cle + ".png"), optimize=True)
        print("icone", cle)


if __name__ == "__main__":
    feuilles()
    icones()
