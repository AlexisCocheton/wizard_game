# -*- coding: utf-8 -*-
"""Extrait le livre magique (craftpix) et les icones d onglets du menu.

POURQUOI CE SCRIPT
------------------
L onglet Galerie devient un LIVRE a pages (demande du testeur). Le pack
"Free Animated Magic Book" fournit la planche du livre ouvert, les animations
de page qui tourne, et 20 icones de sorts elementaires.

LE PIEGE DU FORMAT
------------------
La planche du livre est une DOUBLE PAGE de 246x211 px, donc un rectangle
PAYSAGE (1.17:1). La zone de contenu du menu fait ~1020x1250, soit un rectangle
PORTRAIT de 0.8:1. Etirer la double page a cette forme :
  - ecrase la reliure centrale en une bande baveuse de 40 px de large ;
  - donne deux colonnes de 480 px pour un texte qui a besoin de 900.
On extrait donc **une seule page** (`book_page9.png`) : la page GAUCHE, dont le
bord droit (la reliure) est remplace par le miroir de son bord gauche. Le
resultat est une page a quatre bords identiques, donc utilisable en 9-tranches :
les coins gardent leur bois, le centre creme s etire sans motif visible.

`book_open.png` (la double page entiere) reste extrait : il sert de vignette de
couverture, jamais de fond etire.

Les 15 images des animations `Turning_pages_*` sont reduites a UNE image : la
6e, ou la page est levee a mi-course. Elle sert de FLECHE de changement de page,
a gauche et a droite de l ecran — on ne joue pas l animation, qui demanderait
un AnimatedSprite2D dans un menu pour un gain nul.

LES ICONES D ONGLETS
--------------------
Retour du testeur : "utilise les bonnes icones pour les menus, pas un steak pour
la campagne". Les icones de Tiny Swords (`icon_01..12`) sont un marteau, une
buche, une piece, un STEAK, une epee, un bouclier... : du materiel de jeu de
construction, sans rapport avec un menu de jeu de sorts. On compose donc les
icones a partir des packs qui parlent de magie :
  - `tab_gallery` : la couverture du livre magique (deja extraite) ;
  - `tab_campaign` / `tab_deck` : composees par `compose_ui.py` depuis Tiny Swords ;
  - `book_spells` / `book_passives` / `book_beasts` : trois icones du pack livre
    pour les trois sections Sorts / Passifs / Bestiaire.

Licence : craftpix (https://craftpix.net/file-licenses/), usage commercial
libre, redistribution des sources interdite (le zip reste dans `raw_assets/`).
"""
import io
import os
import zipfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "raw_assets")
OUT = os.path.join(ROOT, "assets", "ui")

BOOK_ZIP = "craftpix-net-809047-free-animated-magic-book-pixel-art-asset-pack.zip"

## Geometrie mesuree sur la planche (voir docstring) : le papier creme de la page
## gauche va de x=9 a la reliure, le bois du bas commence vers y=185.
PAGE_LEFT = 0
PAGE_RIGHT = 120   # juste avant la reliure centrale
MIRROR = 12        # largeur du bord recopie en miroir pour fermer la page a droite


def _open(zip_name, member):
    with zipfile.ZipFile(os.path.join(RAW, zip_name)) as z:
        return Image.open(io.BytesIO(z.read(member))).convert("RGBA")


def _save(img, name):
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    print("  %-22s %dx%d" % (name, img.width, img.height))


def book_page():
    """Une page unique, bords identiques a gauche et a droite -> 9-tranches sain."""
    sheet = _open(BOOK_ZIP, "PNG/Open_book.png")
    # Derniere image de la grille 4x3 : le livre grand ouvert, vu de face.
    fw, fh = sheet.width // 4, sheet.height // 3
    frame = sheet.crop((3 * fw, 2 * fh, 4 * fw, 3 * fh))
    # Recadre sur les pixels opaques (la case a des marges vides).
    frame = frame.crop(frame.getbbox())
    _save(frame, "book_open")

    page = frame.crop((PAGE_LEFT, 0, PAGE_RIGHT, frame.height))
    # Le bord droit de cette page est la reliure : on le remplace par le miroir
    # du bord gauche, sinon le 9-tranches etirerait la reliure sur toute la page.
    edge = page.crop((0, 0, MIRROR, page.height)).transpose(Image.FLIP_LEFT_RIGHT)
    page.paste(edge, (page.width - MIRROR, 0))
    _save(page, "book_page9")
    return page


def turn_arrows():
    """Une image de page levee, a gauche et a droite : les boutons de page."""
    for src, name in (("PNG/Turning_pages_left.png", "book_turn_left"),
                      ("PNG/Turning_pages_right.png", "book_turn_right")):
        sheet = _open(BOOK_ZIP, src)
        # Grille 4x4 de cases carrees (1088x1088), et non une bande : les
        # decouper en 15 colonnes donnait des tranches de 72 px de large sur
        # toute la hauteur, soit des rubans illisibles.
        fw, fh = sheet.width // 4, sheet.height // 4
        # Grille 4x4 de cases carrees (1088x1088), et non une bande : la
        # decouper en 15 colonnes donnait des tranches de 72 px de large sur
        # toute la hauteur, soit des rubans illisibles.
        #
        # Case 5 (ligne 1, colonne 1) : la page est DRESSEE au milieu du livre,
        # la seule image de la serie ou le mouvement se lit d un coup d oeil.
        # Les cases voisines montrent une page a peine soulevee, qu on prend
        # pour un livre au repos.
        frame = sheet.crop((fw, fh, 2 * fw, 2 * fh))
        bbox = frame.getbbox()
        if bbox:
            frame = frame.crop(bbox)
        # On garde le LIVRE ENTIER. Premiere version : la moitie vers laquelle
        # la page part. Lu sur capture a 170x130, cette moitie n etait qu une
        # surface creme unie : le bouton semblait vide. Le livre complet garde
        # sa reliure et sa page dressee, reconnaissables meme reduits.
        _save(frame, name)


def section_icons():
    """Trois icones elementaires du pack livre pour Sorts / Passifs / Bestiaire."""
    # Icon3 = comete (les sorts), Icon20 = aile (les passifs : un effet permanent
    # qui porte le mage), Icon4 = GRIFFE tenant une flamme (le bestiaire).
    # Icon11 avait ete essaye pour le bestiaire : c est un CAILLOU, illisible en
    # onglet de monstres — juge sur planche-contact des 20 icones.
    for num, name in ((3, "book_spells"), (20, "book_passives"), (4, "book_beasts")):
        _save(_open(BOOK_ZIP, "PNG/Icons/Icon%d_big.png" % num), name)


def main():
    print("Livre magique -> assets/ui/")
    book_page()
    turn_arrows()
    section_icons()


if __name__ == "__main__":
    main()
