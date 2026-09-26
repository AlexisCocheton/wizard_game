"""Copie les decors des scenes de dialogue depuis le pack `Wood Elves` vers
`assets/backdrops/`, sous des noms prefixes `talk_`.

POURQUOI DES DECORS DEDIES. Les scenes de dialogue nommaient `act1_sky`, le fond
de COMBAT de l acte, et le code l assombrissait de moitie pour qu il ne mange pas
les portraits. Resultat : neuf dialogues devant la meme pelouse verte delavee, et
un joueur incapable de dire ou il se trouvait. Le lieu fait la moitie du travail
d une scene de visual novel.

Le choix a ete fait sur planche de contact, en regardant les 41 decors du pack,
puis relu a la taille reelle : chaque decor doit encore se lire une fois rogne en
portrait 1080 x 1920 par un STRETCH_KEEP_ASPECT_COVERED.

Les noms produits ici doivent correspondre a ceux que `tools/make_story.gd`
passe a `_scene()`.

    python tools/story/build_backdrops.py
"""
import os
import tempfile
import zipfile

from PIL import Image

ZIPS = "raw_assets/packs_2026_09_26"
OUT = "assets/backdrops"

# nom dans le jeu -> fichier du pack, et pourquoi celui-la
SCENES = [
    # Le prologue raconte ce que le mage a deja perdu : un sanctuaire en ruine
    # sous la lune, sans personne dedans.
    ("talk_shrine", "Moon Shrine 2.png"),
    # lvl_01, "une clairiere au petit matin, tres calme, presque jolie" : la
    # lumiere tombe entre les racines d un arbre geant.
    ("talk_glade", "Tree Shrine.png"),
    # lvl_02, le village de l enfant : des maisons de bois eclairees dans les
    # arbres. C est la que le joueur voit "la ligne" des monstres avancer.
    ("talk_village", "Tree City 1.png"),
    # lvl_03, la route du maire : une maison isolee au bord du sentier — la
    # grange ou il se cache depuis trois jours.
    ("talk_path", "Tree Cottage 1.png"),
    # lvl_04, le Gardien de la foret : l arbre qu il protege, et sous lequel il
    # tombe en tas de bois mort.
    ("talk_greattree", "Giant Tree.png"),
]


def unpack(nom: str) -> str:
    """Extrait une archive dans un dossier temporaire et rend son chemin.

    On lit le .zip DIRECTEMENT plutot qu un dossier deja extrait : ce script
    doit tourner sur un depot neuf, ou `raw_assets/` ne contient que les
    archives."""
    d = os.path.join(tempfile.gettempdir(), "wizard_cast", nom)
    if not os.path.isdir(d):
        with zipfile.ZipFile(os.path.join(ZIPS, nom + ".zip")) as z:
            z.extractall(d)
    return d


def main() -> None:
    src = os.path.join(unpack("Wood Elves"), "Wood Elves")
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SCENES:
        # RGB et pas RGBA : un decor n a pas de transparence a transporter, et
        # le .import de Godot pese moins sans canal alpha inutile.
        im = Image.open(os.path.join(src, fn)).convert("RGB")
        im.save(os.path.join(OUT, name + ".png"))
        print("%-16s <- %-22s %s" % (name, fn, im.size))


if __name__ == "__main__":
    main()
