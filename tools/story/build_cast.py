"""Fabrique `assets/portraits/story_cast.png`, la planche du casting des scenes
de dialogue, a partir des packs bruts de `raw_assets/packs_2026_09_26/`.

POURQUOI UN GENERATEUR. Chaque personnage doit etre cadre EXACTEMENT comme les
autres : detoure, mis a l echelle dans une case carree de 512 px, cale en haut.
Fait a la main, un personnage remplit la boite et son voisin flotte au milieu.
Le cadrage est donc decide une fois, ici, et pas a chaque affichage.

A relancer si un personnage change de visage. Les cases produites doivent
correspondre a `CAST` dans `scripts/ui/story_scene.gd` (ligne, colonne).

    python tools/story/build_cast.py

Sources : TTRPG LEGEND [TOO MANY CHARACTERS] (Ddant1100, itch.io) pour les
bustes — commercial autorise, credit demande — et `free_character_1_20`
(cogabushi) pour le rat, le seul vrai rat de tous les packs fournis.
"""
import os
import tempfile
import zipfile

from PIL import Image

ZIPS = "raw_assets/packs_2026_09_26"
OUT = "assets/portraits"

CELL = 512
COLS = 4


def unpack(nom: str) -> str:
    """Extrait une archive dans un dossier temporaire et rend son chemin.

    On lit les .zip DIRECTEMENT plutot qu un dossier deja extrait : ce script
    doit tourner sur un depot neuf, ou `raw_assets/` ne contient que les
    archives. Rien n est laisse dans le depot : seule la planche est un
    livrable."""
    d = os.path.join(tempfile.gettempdir(), "wizard_cast", nom)
    if not os.path.isdir(d):
        with zipfile.ZipFile(os.path.join(ZIPS, nom + ".zip")) as z:
            z.extractall(d)
    return d


def fade_bottom(im: Image.Image, frac: float = 0.18) -> Image.Image:
    """Degrade l alpha sur le bas de l image.

    POURQUOI. Les bustes du pack sont coupes NET en bas par le cadre de leur
    source. Poses sur un decor peint, ce bord droit se lit comme une image mal
    detouree, pas comme un personnage. On fait donc disparaitre les epaules en
    fondu, comme le fait n importe quel visual novel.

    PIEGE PIL : `im.split()[3]` rend une COPIE du canal alpha ; ecrire dedans
    ne change PAS l image, et le fondu passe silencieusement a la trappe (perdu
    une fois ici). Il faut reinjecter le canal avec `putalpha`."""
    alpha = im.getchannel("A")
    px = alpha.load()
    start = int(im.height * (1.0 - frac))
    span = float(max(1, im.height - start))
    for y in range(start, im.height):
        k = 1.0 - (y - start) / span
        k = k * k                      # chute douce au debut, franche a la fin
        for x in range(im.width):
            v = px[x, y]
            if v:
                px[x, y] = int(v * k)
    im.putalpha(alpha)
    return im


def main() -> None:
    tt = os.path.join(unpack("ttrpg_legend_too-many-charaters_1.0"), "Faceset")
    cog = os.path.join(unpack("free_character_1_20_cogabushi"),
                       "character", "normal")

    # cle -> (dossier, fichier, fenetre de recadrage)
    # La fenetre est (largeur, hauteur) en fraction de la silhouette detouree,
    # prise depuis le coin HAUT-GAUCHE. (1.0, 1.0) = la source est deja un
    # buste et on la garde entiere.
    cast = [
        ("mage",          tt,  "avatar_wizard_human_man_04.png",    (1.00, 1.00)),
        ("child",         tt,  "avatar_unknow_darkelve_boy_01.png", (1.00, 1.00)),
        ("child_god",     tt,  "avatar_deity_man_01.png",           (1.00, 1.00)),
        # Le rat est le seul CORPS ENTIER du casting, et son barda de
        # mecanicien deborde loin sur la droite : un simple recadrage en
        # hauteur donnait une bande deux fois plus large que haute, ou le rat
        # se perdait a cote de ses bagages. On prend donc une fenetre : les
        # 62 % de gauche et la moitie du haut, c est-a-dire LUI.
        ("rat",           cog, "A_18.png",                          (0.62, 0.52)),
        ("mayor",         tt,  "avatar_noble_human_man_02.png",     (1.00, 1.00)),
        ("skeleton_king", tt,  "avatar_demon_human_man_01.png",     (1.00, 1.00)),
        ("guardian",      tt,  "avatar_knight_raceless_man_01.png", (1.00, 1.00)),
        ("demon",         tt,  "avatar_demon_elve_man_01.png",      (1.00, 1.00)),
    ]

    rows = (len(cast) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    print("cle,ligne,colonne,source")
    for i, (key, src, fn, window) in enumerate(cast):
        im = Image.open(os.path.join(src, fn)).convert("RGBA")
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
        fw, fh = window
        if fw < 1.0 or fh < 1.0:
            im = im.crop((0, 0, int(im.width * fw), int(im.height * fh)))
            bb = im.getbbox()
            if bb:
                im = im.crop(bb)
        # MARGE DE 6 %, et ce n est pas de la coquetterie : mis a l echelle sur
        # la case ENTIERE, un buste large touche les deux bords et se lit comme
        # une image COUPEE — c est exactement ce qu on voyait du mage et du
        # demon, epaules tranchees net au ras du cadre. La marge leur rend leur
        # silhouette.
        util = CELL * 0.88
        s = min(util / im.width, util / im.height)
        im = im.resize((max(1, int(im.width * s)),
                        max(1, int(im.height * s))), Image.LANCZOS)
        im = fade_bottom(im)
        col, row = i % COLS, i // COLS
        # Cale en HAUT de la case : le visage est en haut de chaque source, et
        # c est lui qu on veut lire en premier si la case est rognee a l ecran.
        sheet.alpha_composite(im, (col * CELL + (CELL - im.width) // 2,
                                   row * CELL + int(CELL * 0.04)))
        print("%s,%d,%d,%s" % (key, row + 1, col + 1, fn))

    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "story_cast.png"))
    print("-> story_cast.png", sheet.size)


if __name__ == "__main__":
    main()
