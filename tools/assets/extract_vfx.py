# -*- coding: utf-8 -*-
"""Extrait, feuille par feuille, les effets retenus des packs VFX / Pipoya.

POURQUOI seulement quelques feuilles
------------------------------------
Le VFX Free Pack contient 2084 PNG (22 effets x frames x 30/60 fps x gifs). Les
packs Pipoya en ajoutent 60 de 192 a 480 px. Tout extraire ferait exploser l etape
`--import` du harnais pour des fichiers jamais joues. On ne prend donc que les
feuilles qui remplacent un effet MOINS BON, plus celles qui manquaient.

Ce qui est repris, et pourquoi c est mieux que l existant :

  shield_hex  (Pipoya HEXShield)  remplace `protectioncircle` comme HALO.
      L ancien n occupait que 34 % de sa case : agrandi au rayon protege, il
      devenait une bouillie (deja constate, d ou le contournement `ZoneRing`
      qui TRACE l anneau au lieu de l afficher). L hexagone Pipoya remplit 92 %
      de sa case et reste net a n importe quelle taille.

  vortex_hd   (VFX Free Pack / TheVortex)  remplace `vortex`.
      L ancien est une grille 100 px de 76 % : correct mais mou. Celui-ci est
      une spirale de 427 px qui tourne vraiment, et sert le sort d aspiration
      (Spirale de sel) autant que l effet plein ecran.

  boom_hd     (VFX Free Pack / Explosion)  s ajoute pour la mort des GROS
      monstres. `explosion_e` culmine a 192 px ; au-dela il pixelise. Celui-ci
      part de 517 px : un boss meurt enfin a la taille de sa silhouette.

Tout le reste des packs est ECARTE : effets monochromes trop fins pour du mobile
(Impact, Charged), texte anglais incruste (Kabooms : "KABOOM"), objets flottants
decoratifs sans crochet de jeu (Pipoya nazoobj / mapeffect), portails (aucun sort
de teleportation dans le jeu).

Format de sortie : une BANDE horizontale d une seule ligne, comme les autres
feuilles de `assets/fx/`, pour que `Fx.STRIPS` la lise sans cas particulier.
"""
import os
import zipfile

from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")
Image.MAX_IMAGE_PIXELS = None

OUT_DIR = "assets/fx"

# (sortie, archive, entree, largeur de case, hauteur de case, nb de cases gardees,
#  cote de la case rendue)
#
# On REDUIT les cases a un cote raisonnable : une bande de 30 cases de 517 px
# ferait 15 000 px de large, que Godot importerait en texture geante pour un effet
# affiche a 200 px. On descend a 160 px, au-dessus de la taille d affichage
# courante, et le poids disque redevient normal.
SHEETS = [
    ("shield_hex", "raw_assets/Pipoya VFX HEXShield.zip",
     "Pipoya VFX HEXShield/192x192/pipo-btleffect206_192.png", 192, 192, 20, 160),
    ("vortex_hd", "raw_assets/VFX Free Pack.zip",
     "Effect_TheVortex/30fps/Spritesheets/Effect_TheVortex_1_427x431.png", 427, 431, 30, 160),
    ("boom_hd", "raw_assets/VFX Free Pack.zip",
     "Effect_Explosion/30fps/Spritesheets/Effect_Explosion_1_517x517.png", 517, 517, 30, 160),
]


def cells_of(image, cell_w, cell_h, limit):
    """Cases d une grille, lues ligne par ligne, cases vides ignorees.

    Les feuilles du VFX Free Pack sont des grilles 6x5 dont la derniere ligne est
    partiellement vide : garder ces cases ferait clignoter l effet sur du vide en
    fin d animation.
    """
    out = []
    for row in range(image.size[1] // cell_h):
        for col in range(image.size[0] // cell_w):
            cell = image.crop((col * cell_w, row * cell_h,
                               (col + 1) * cell_w, (row + 1) * cell_h))
            if cell.getbbox() is None:
                continue
            out.append(cell)
            if len(out) >= limit:
                return out
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for key, archive, entry, cw, ch, limit, side in SHEETS:
        with zipfile.ZipFile(archive) as z, z.open(entry) as handle:
            src = Image.open(handle)
            src.load()
        src = src.convert("RGBA")
        cells = cells_of(src, cw, ch, limit)
        if not cells:
            raise SystemExit("aucune case opaque dans %s" % entry)
        strip = Image.new("RGBA", (side * len(cells), side), (0, 0, 0, 0))
        for i, cell in enumerate(cells):
            strip.paste(cell.resize((side, side), Image.LANCZOS), (i * side, 0))
        path = os.path.join(OUT_DIR, key + ".png")
        strip.save(path, optimize=True)
        print("%-12s %2d cases de %d px  (%d ko)"
              % (key, len(cells), side, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
