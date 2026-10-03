"""Icones des deux sorts demandes par le co-auteur (vague 8) : assets/icons/<id>.png.

Une icone dediee par carte (test_card_icons : chaque carte a son image, jamais
partagee). Packs craftpix deja autorises (commercial oui, credit non,
redistribution des sources non) ; AUCUNE du pack Batareya (licence inconnue,
voir docs/assets_index.md).

Choix fait sur planches de contact des packs entiers, icones deja livrees
reperees par empreinte et ecartees :

  venom_dart   Warlock 5   trois cranes lances comme des traits : un dard qui
                           vise. Recolore au VERT du poison (meme degrade que le
                           logo de l element, tools/assets/extract_elements.py) :
                           bleu, il se lisait comme un sort d eau.
  time_surge   Warlock 9   une botte qui s elance dans des flammes violettes :
                           la vitesse, a la couleur de l arcane (le temps).

Usage : python tools/assets/extract_w8_sorts.py  (racine du projet)
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
    "warlock": "Free Warlock Skills.zip",
}

# id -> (pack, numero, recoloration (sombre, clair) ou None)
ICONS = {
    "venom_dart": ("warlock", 5, ((10, 36, 10), (205, 255, 130))),
    "time_surge": ("warlock", 9, None),
}


def _image(pack, num):
    zf = zipfile.ZipFile(os.path.join(RAW, PACKS[pack]))
    for n in zf.namelist():
        if re.search(r"(^|/|_)%d\.png$" % num, n):
            return Image.open(io.BytesIO(zf.read(n))).convert("RGBA")
    sys.exit("introuvable : %s %d" % (pack, num))


def _recolore(im, sombre, clair):
    """Remappe la luminance sur un degrade sombre -> clair de l element."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            px[x, y] = (int(sombre[0] + (clair[0] - sombre[0]) * t),
                        int(sombre[1] + (clair[1] - sombre[1]) * t),
                        int(sombre[2] + (clair[2] - sombre[2]) * t), a)
    return out


def main():
    dest = os.path.join(PROJ, "assets", "icons")
    os.makedirs(dest, exist_ok=True)
    for cle, (pack, num, recol) in ICONS.items():
        im = _image(pack, num).resize((SIZE, SIZE), Image.LANCZOS)
        if recol is not None:
            im = _recolore(im, recol[0], recol[1])
        im.save(os.path.join(dest, cle + ".png"), optimize=True)
        print("icone", cle)


if __name__ == "__main__":
    main()
