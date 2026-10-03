"""Icone du Mur de glace (chantier W9) : assets/icons/ice_wall.png.

Une icone dediee par carte (test_card_icons : chaque carte a son image, jamais
partagee). Pack craftpix deja autorise (commercial oui, credit non,
redistribution des sources non) ; AUCUNE du pack Batareya (licence inconnue,
voir docs/assets_index.md).

Choix fait sur planches de contact des packs craftpix entiers (EarthMage,
Night Elf, Warlock, Aeromancer, FireMage), icones deja livrees reperees par
empreinte et ecartees :

  ice_wall   EarthMage 33   un pan de blocs maconnes fendu par un eclat de
                            lumiere. Recolore en GLACE (bleu nuit -> bleu de
                            givre -> blanc, sur la luminance) : les blocs se
                            lisent comme de la glace taillee. Le Mur de pierre
                            (EarthMage 40) et le Bastion (39) restent dans leurs
                            ocres de nature : trois murs, trois images.

Usage : python tools/assets/extract_w9_sorts.py  (racine du projet)
Le chemin des packs se regle par WIZARD_RAW (defaut : raw_assets/ du depot
principal, les worktrees n en ont pas forcement de copie).
"""
import io
import os
import re
import sys
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.environ.get("WIZARD_RAW") or os.path.join(PROJ, "raw_assets", "packs_2026_09_26")
if not os.path.isdir(RAW) or not os.listdir(RAW):
    RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets\packs_2026_09_26"

SIZE = 128
PACKS = {
    "earth": "EarthMage_Free.zip",
}

# Degrade de la glace, du plus sombre au plus clair (trois arrets : un degrade a
# deux arrets rendait une image terne, sans le bleu franc du givre au milieu).
GLACE = [(0.0, (4, 16, 48)), (0.5, (70, 160, 230)), (1.0, (240, 252, 255))]

# id -> (pack, numero, degrade ou None)
ICONS = {
    "ice_wall": ("earth", 33, GLACE),
}


def _image(pack, num):
    zf = zipfile.ZipFile(os.path.join(RAW, PACKS[pack]))
    for n in zf.namelist():
        if "__MACOSX" in n:
            continue
        if re.search(r"(^|/|_)%d\.png$" % num, n):
            return Image.open(io.BytesIO(zf.read(n))).convert("RGBA")
    sys.exit("introuvable : %s %d" % (pack, num))


def _recolore(im, arrets):
    """Remappe la luminance (contraste releve) sur le degrade de l element."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            t = min(1.0, max(0.0, (t - 0.08) / 0.8))
            c = arrets[-1][1]
            for i in range(len(arrets) - 1):
                t0, c0 = arrets[i]
                t1, c1 = arrets[i + 1]
                if t <= t1:
                    u = (t - t0) / (t1 - t0)
                    c = tuple(int(c0[k] + (c1[k] - c0[k]) * u) for k in range(3))
                    break
            px[x, y] = c + (a,)
    return out


def main():
    dest = os.path.join(PROJ, "assets", "icons")
    os.makedirs(dest, exist_ok=True)
    for cle, (pack, num, degrade) in ICONS.items():
        im = _image(pack, num).resize((SIZE, SIZE), Image.LANCZOS)
        if degrade is not None:
            im = _recolore(im, degrade)
        im.save(os.path.join(dest, cle + ".png"), optimize=True)
        print("icone", cle)


if __name__ == "__main__":
    main()
