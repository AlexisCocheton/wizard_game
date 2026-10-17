# -*- coding: utf-8 -*-
"""Portraits des trois apprentis pour les scenes d histoire (vague 10, chantier C6).

    python tools/assets/make_apprentice_portraits.py      (depuis la racine du projet)

-> `assets/portraits/apprentice_cast.png` : UNE ligne de trois cases carrees de
`UiTheme.CAST_PX` (512 px), dans l ordre de `StoryScene.CAST` :
colonne 1 l ecuyer (`soldier`), 2 la fee (`fairy`), 3 l apprentie d azur
(`bluewitch`).

POURQUOI LES FEUILLES DU JEU ET PAS UN PACK
-------------------------------------------
Le joueur a deja vu ces trois personnages : ils combattent a la place du mage
(garde-robe, vague 8). Leur portrait doit etre EXACTEMENT celui qu il connait,
comme `SHEET_FACES` le fait pour les monstres. On lit donc les feuilles deja dans
`assets/units/` — aucun pack n est ouvert, aucune licence nouvelle n entre : le
portrait a la licence du sprite qu il recadre. Corollaire utile : le jour ou la
fee est remplacee (licence a confirmer, voir docs/assets_index.md), relancer ce
script suffit a remplacer son portrait.

POURQUOI PAS LE CODE DE `SHEET_FACES`
-------------------------------------
Il affiche la premiere case d idle entiere, recadree a ses pixels opaques : un
corps entier au milieu de la boite, de la taille que lui donne
KEEP_ASPECT_CENTERED. Le casting a ete fait precisement contre ca (un visage
perdu en haut d une silhouette, un personnage qui flotte a cote d un voisin qui
remplit sa case). Ici chaque apprenti passe par le MEME cadre que les bustes
peints : une case de 512, centree, posee sur la meme ligne de base.

TROIS REGLES DE PIXEL ART
-------------------------
1. Agrandissement au plus proche voisin, d un facteur ENTIER : chaque pixel du
   sprite devient un carre plein. Le LANCZOS de `tools/story/build_cast.py`
   convient a une peinture, il transforme un sprite en bouillie. Verifie en fin
   de script (assertion `_blocs_nets`) : une seule valeur par bloc.
2. UN FACTEUR PAR BUSTE : le plus grand entier qui fait tenir CE buste dans la
   marge des bustes peints (88 % de la case). Une premiere version prenait un
   facteur commun aux trois (19, borne par les ailes de la fee) : l ecuyer, le
   plus petit sprite (15 x 17), tenait alors dans 56 % de sa case et paraissait
   minuscule a cote du buste du mage. Au telephone c est le CADRAGE qui se voit ;
   la difference de taille des pixels entre deux apprentis, jamais a l ecran
   ensemble, se voit a peine (choix de l orchestrateur sur maquette, C6).
3. Le bas du buste se dissout en TRAMAGE ordonne (un pixel sur deux, puis un sur
   quatre), pas en fondu d alpha. Le fondu des bustes peints, applique a des
   blocs de 19 a 26 px, donnait des bandes translucides qui se lisaient comme une
   image mal effacee ; le tramage est la facon pixel art de faire la meme chose
   et garde chaque bloc net.

CADRAGE
-------
Les bustes peints sont cales en haut a 4 % et mis a l echelle dans 88 % de la
case : leur bas tombe vers 92 % de la case, juste au-dessus de la boite de
texte. Les apprentis sont POSES sur cette ligne de base plutot que cales en
haut : un buste plus large que haut (la fee) est moins haut que sa case, et cale
en haut il flotterait au milieu de la boite, le defaut meme que la planche du
casting devait empecher.
"""
import os
import re
import sys

from PIL import Image

# Racine du depot = deux dossiers au-dessus de ce script (fonctionne aussi
# depuis un worktree, qui n a pas de raw_assets/ : on n en a pas besoin).
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNITS = os.path.join(ROOT, "assets", "units")
OUT = os.path.join(ROOT, "assets", "portraits", "apprentice_cast.png")
CATALOG = os.path.join(ROOT, "scripts", "game", "anim_catalog.gd")
UI_THEME = os.path.join(ROOT, "scripts", "ui", "ui_theme.gd")

# Meme marge et meme ligne de base que tools/story/build_cast.py.
UTIL = 0.88
HAUT = 0.04
# Lignes de SPRITE (pas d ecran) qui se dissolvent en bas du buste.
LIGNES_TRAMEES = 3
BAYER = ((0, 2), (3, 1))

# cle de casting -> (cle AnimCatalog, case d idle, derniere ligne EXCLUE du buste)
#
# La cle de casting EST le `texture_name` de la fiche de compte de l apprenti
# (`side_quest_character` de son annexe) : test_story le verifie.
#
# - l ecuyer : case 0, la seule pose ou l arc et le visage sont tous deux de
#   profil ; ligne 38 = au-dessus de l ombre portee (elle commence a 38).
# - la fee : case 7, les deux ailes levees encadrent la tete et le visage est de
#   face ; aux cases 2, 5 et 6 il est cache par les cheveux. Coupee a la taille
#   (ligne 22) : les jambes pendantes ne disent rien de plus.
# - l apprentie d azur : case 3, la pointe du chapeau penchee (les autres cases
#   la tiennent droite, moins sorciere) et les deux yeux visibles. Coupee sous le
#   menton (ligne 27) : la robe est un aplat sombre sans detail.
APPRENTIS = (
    ("soldier", "soldier", 0, 38),
    ("fairy", "fairy", 7, 22),
    ("bluewitch", "bluewitch", 3, 27),
)


def _cast_px() -> int:
    """La taille de case vient de UiTheme, la seule arithmetique du casting."""
    with open(UI_THEME, encoding="utf-8") as f:
        m = re.search(r"const CAST_PX: int = (\d+)", f.read())
    if m is None:
        raise SystemExit("CAST_PX introuvable dans ui_theme.gd")
    return int(m.group(1))


def _geometrie(cle: str):
    """(largeur, hauteur, feuille d idle) lus dans AnimCatalog, jamais devines
    (voir measure_occupancy.py, regle 1)."""
    with open(CATALOG, encoding="utf-8") as f:
        src = f.read()
    # Ancre sur la cle exacte et borne a la ligne de l entree, sans DOTALL (le
    # piege de measure_occupancy : une regex gourmande mordait sur la suivante).
    m = re.search(r'^\s*"%s":\s*\{"frame":\s*(\d+),\s*"frame_h":\s*(\d+)' % re.escape(cle),
                  src, re.M)
    if m is None:
        raise SystemExit("%s : geometrie introuvable dans AnimCatalog" % cle)
    # L entree tient sur une ou deux lignes : au plus UN saut de ligne permis, et
    # la premiere ligne d abord (`??`), sinon on lirait l idle de l entree suivante.
    idle = re.search(r'^\s*"%s":\s*\{(?:.*\n)??.*?"idle":\s*\["([a-z0-9_]+)"' % re.escape(cle),
                     src, re.M)
    if idle is None:
        raise SystemExit("%s : pas d animation idle dans AnimCatalog" % cle)
    return int(m.group(1)), int(m.group(2)), idle.group(1)


def _buste(cle: str, case: int, bas: int):
    """(buste detoure, nom de la feuille source)."""
    fw, fh, feuille = _geometrie(cle)
    planche = Image.open(os.path.join(UNITS, feuille + ".png")).convert("RGBA")
    if (case + 1) * fw > planche.width:
        raise SystemExit("%s : case %d hors de %s" % (cle, case, feuille))
    im = planche.crop((case * fw, 0, case * fw + fw, min(bas, fh)))
    bb = im.getbbox()
    if bb is None:
        raise SystemExit("%s : case %d vide" % (cle, case))
    return im.crop(bb), feuille


def _tramer(im: Image.Image) -> Image.Image:
    """Dissout les LIGNES_TRAMEES dernieres lignes : on garde 3/4, 2/4 puis 1/4
    des pixels selon une matrice de Bayer 2x2. Pas d alpha intermediaire."""
    im = im.copy()
    a = im.getchannel("A")
    px = a.load()
    debut = im.height - LIGNES_TRAMEES
    for y in range(max(0, debut), im.height):
        garde = 1.0 - (y - debut + 1) / float(LIGNES_TRAMEES + 1)
        for x in range(im.width):
            seuil = (BAYER[y % 2][x % 2] + 0.5) / 4.0
            if px[x, y] and seuil > garde:
                px[x, y] = 0
    im.putalpha(a)
    return im


def _blocs_nets(case: Image.Image, x0: int, y0: int, w: int, h: int, k: int) -> bool:
    """Vrai si la zone (x0, y0, w, h) est faite de blocs k x k d une seule valeur."""
    px = case.load()
    for by in range(0, h, k):
        for bx in range(0, w, k):
            ref = px[x0 + bx, y0 + by]
            for dy in range(k):
                for dx in range(k):
                    if px[x0 + bx + dx, y0 + by + dy] != ref:
                        return False
    return True


def main() -> None:
    cell = _cast_px()
    bustes = []
    for cle, anim_key, case, bas in APPRENTIS:
        b, feuille = _buste(anim_key, case, bas)
        bustes.append((cle, b, case, feuille))
    util = cell * UTIL
    base = int(cell * (HAUT + UTIL))

    planche = Image.new("RGBA", (cell * len(bustes), cell), (0, 0, 0, 0))
    print("cle,ligne,colonne,source,case,buste_px,facteur,portrait_px")
    for col, (cle, b, case, feuille) in enumerate(bustes):
        # Facteur PROPRE a ce buste (regle 2) : le plus grand entier qui le fait
        # tenir dans la marge des bustes peints, sur son plus grand cote.
        k = int(util / max(b.width, b.height))
        if k < 2:
            raise SystemExit("%s : facteur %d, buste trop grand pour la case" % (cle, k))
        grand = _tramer(b).resize((b.width * k, b.height * k), Image.NEAREST)
        x = col * cell + (cell - grand.width) // 2
        y = base - grand.height
        if y < 0 or grand.width > cell:
            raise SystemExit("%s deborde de sa case" % cle)
        planche.alpha_composite(grand, (x, y))
        if not _blocs_nets(planche, x, y, grand.width, grand.height, k):
            raise SystemExit("%s : blocs non uniformes, le portrait serait flou" % cle)
        print("%s,1,%d,%s,%d,%dx%d,%d,%dx%d" % (cle, col + 1, feuille, case, b.width,
                                                b.height, k, grand.width, grand.height))

    planche.save(OUT)
    print("-> %s %s" % (os.path.relpath(OUT, ROOT), planche.size))


if __name__ == "__main__":
    sys.exit(main())
