"""Sorts de terrain permanents : icones de cartes et visuels d objets.

Ecrit UNIQUEMENT des fichiers neufs prefixes `terrain_` :
  assets/icons/terrain_*.png   icones de cartes (128 px, lues a 118 px en main)
  assets/props/terrain_*.png   corps des objets poses sur le champ de bataille

Sources (raw_assets/packs_2026_09_26, licences dans docs/assets_index.md) :
  - EPIC RPG World Pack - Ancient Ruins (rafaelmatos, itch : commercial oui,
    redistribution des sources non) -> eau animee, berge, dalles, autel, ronces,
    galets.
  - Free-RPG-Night-Elf-Skill-Icons, Free Warlock Skills, EarthMage_Free
    (craftpix : commercial oui, redistribution non) -> icones.

Le pack craftpix "undead tileset" demande pour ces sorts n est PAS sur le disque :
Ancient Ruins le remplace en attendant. Un seul endroit a changer le jour ou il
arrive : la table PROPS ci-dessous.

Pourquoi PAS le pack Batareya (MAGE ICONS BIG PACK), dont viennent 42 des 60
icones actuelles : il est arrive SANS licence (assets_index.md 1.5). Ajouter des
icones qui en dependent aggraverait une dette deja signalee.

Usage : python tools/assets/extract_terrain.py   (depuis la racine du projet)
Le chemin des packs se regle par WIZARD_RAW (defaut : raw_assets/ du depot
principal, les worktrees n en ont pas de copie).
"""
import io
import os
import sys
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.environ.get("WIZARD_RAW") or os.path.join(PROJ, "raw_assets", "packs_2026_09_26")
if not os.path.isdir(RAW):
    # Worktree : raw_assets n est pas versionne, on lit celui du depot principal.
    RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets\packs_2026_09_26"

RUINS = "EPIC RPG World Pack - [FREE Demo]Ancient Ruins.zip"
ICON_SIZE = 128

# Icone de carte -> (archive, fichier dans l archive). Choisies sur planche de
# contact, a la taille de la main : une idee par image, lisible sans le nom.
ICONS = {
    # Un ruisseau traverse par des empreintes : « on ne passe qu a un endroit ».
    "terrain_river": ("Free-RPG-Night-Elf-Skill-Icons.zip", "PNG/12.png"),
    # Un enchevetrement d epines noires : ronces, sans ambiguite.
    "terrain_brambles": ("Free Warlock Skills.zip", "PNG/46.png"),
    # Un trou creuse dans la pierre, lueur au fond : la fosse.
    "terrain_pit": ("EarthMage_Free.zip", "EarthMage_Free/EarthMage_37.png"),
    # Un socle de pierre qui rougeoie : l autel d ou sortent les allies.
    "terrain_altar": ("EarthMage_Free.zip", "EarthMage_Free/EarthMage_29.png"),
}

# Visuel d objet -> (fichier dans Ancient Ruins, boite de recadrage en pixels).
# Les boites viennent de la lecture des planches ; `trim` rogne ensuite au
# contenu opaque pour que Fx mette a l echelle ce qui se voit, pas la case.
PROPS = {
    # 8 images de 32 px d eau animee, cote a cote.
    "terrain_river_water": ("Tileset-Animated Terrains-8 frames- transparency.png",
                            (0, 32, 256, 64), False),
    # Berge rocheuse, 7 tuiles de 32 px raccordees : posee en haut de la
    # riviere, et retournee en bas.
    "terrain_river_bank": ("Tileset-Animated Terrains-8 frames- transparency.png",
                           (672, 169, 896, 192), True),
    # Dalle de pierre unie : le tablier du pont.
    "terrain_bridge": ("Tileset-Terrain2.png", (736, 384, 800, 448), False),
    # Arbre mort a branches nues : la ronce, repetee en touffe.
    "terrain_bramble": ("Atlas-Props.png", (316, 8, 354, 66), True),
    # Deux galets : la margelle de la fosse.
    "terrain_pebble_a": ("Atlas-Props.png", (38, 196, 62, 214), True),
    "terrain_pebble_b": ("Atlas-Props.png", (68, 196, 90, 212), True),
}

# L autel est une animation de 39 images de 224x288 (8,7 Mo de large en brut).
# Une image sur trois suffit a lire l eclair et la colonne de lumiere, et divise
# le poids par trois : chaque PNG de res:// est reimporte a chaque run du harnais.
ALTAR = ("altar 224x288 - standard.png", 224, 288, 3)


def _zip_image(zip_name, inner):
    zf = zipfile.ZipFile(os.path.join(RAW, zip_name))
    names = [n for n in zf.namelist() if n.endswith(inner)]
    if not names:
        sys.exit("introuvable dans %s : %s" % (zip_name, inner))
    return Image.open(io.BytesIO(zf.read(names[0]))).convert("RGBA")


def _trim(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def main():
    icons_dir = os.path.join(PROJ, "assets", "icons")
    props_dir = os.path.join(PROJ, "assets", "props")
    os.makedirs(props_dir, exist_ok=True)

    for name, (zip_name, inner) in ICONS.items():
        im = _zip_image(zip_name, inner).resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
        im.save(os.path.join(icons_dir, name + ".png"), optimize=True)
        print("icone", name)

    for name, (inner, box, trim) in PROPS.items():
        im = _zip_image(RUINS, inner).crop(box)
        if trim:
            im = _trim(im)
        assert im.getbbox() is not None, name + " : recadrage vide"
        im.save(os.path.join(props_dir, name + ".png"), optimize=True)
        print("objet", name, im.size)

    inner, fw, fh, pas = ALTAR
    sheet = _zip_image(RUINS, inner)
    n = sheet.width // fw
    garde = list(range(0, n, pas))
    out = Image.new("RGBA", (fw * len(garde), fh), (0, 0, 0, 0))
    for i, f in enumerate(garde):
        out.alpha_composite(sheet.crop((f * fw, 0, f * fw + fw, fh)), (i * fw, 0))
    out.save(os.path.join(props_dir, "terrain_altar.png"), optimize=True)
    print("objet terrain_altar", len(garde), "images")


if __name__ == "__main__":
    main()
