# -*- coding: utf-8 -*-
"""Extrait les portraits de PNJ du pack craftpix "Free Demon Characters".

POURQUOI ces fichiers
---------------------
Le pack contient 8 personnages en POSE STATIQUE (aucune marche : inutilisables en
monstre) avec 4 expressions de visage chacun. C est exactement la matiere d un
visual novel (chantier D) : un buste par replique, l expression qui change.

CE QUI EST PRIS, ET SOUS QUELLE FORME
-------------------------------------
- `assets/portraits/demon<N>_<M>.png` : le personnage entier, TAILLE D ORIGINE
  (100 a 200 px de large, ~290 px de haut), N = personnage 1..8, M = expression
  1..4. Le chantier D les mettra a l echelle lui-meme (pixel art : x3 a x4 sur
  un ecran de 1080 px).
- `assets/portraits/demon_heads.png` : les 32 tetes de 64 px (dossier
  "faces_transperent", fond transparent) rangees en UNE grille de 8 lignes x 4
  colonnes (une ligne par personnage, une colonne par expression). Un seul PNG
  au lieu de 32 : l etape `--import` du harnais paie chaque fichier.

Le dossier "Demon_warriors_faces" (tetes sur fond de brique) est ecarte : le fond
est un decor de preview, pas un element de jeu.

Licence : craftpix (https://craftpix.net/file-licenses/), usage commercial libre,
credit non requis, redistribution des sources interdite (zip hors depot).
"""
import os
import zipfile

from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")

ARCHIVE = "raw_assets/free-demon-characters-pixel-art.zip"
OUT_DIR = "assets/portraits"
CHARACTERS = 8
FACES = 4
HEAD = 64


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    heads = Image.new("RGBA", (FACES * HEAD, CHARACTERS * HEAD), (0, 0, 0, 0))
    with zipfile.ZipFile(ARCHIVE) as z:
        for n in range(1, CHARACTERS + 1):
            for m in range(1, FACES + 1):
                name = "Character%d_face%d.png" % (n, m)
                with z.open("PNG/Demon_warriors/" + name) as h:
                    body = Image.open(h).convert("RGBA")
                    body.load()
                path = os.path.join(OUT_DIR, "demon%d_%d.png" % (n, m))
                body.save(path, optimize=True)
                with z.open("PNG/Demon_warriors_faces_transperent/" + name) as h:
                    head = Image.open(h).convert("RGBA")
                    head.load()
                if head.size != (HEAD, HEAD):
                    raise SystemExit("tete %s : %s au lieu de %dx%d" % (name, head.size, HEAD, HEAD))
                heads.paste(head, ((m - 1) * HEAD, (n - 1) * HEAD))
            print("demon%d : %dx%d" % (n, body.size[0], body.size[1]))
    heads.save(os.path.join(OUT_DIR, "demon_heads.png"), optimize=True)
    print("demon_heads.png : grille %d x %d de %d px" % (FACES, CHARACTERS, HEAD))


if __name__ == "__main__":
    main()
