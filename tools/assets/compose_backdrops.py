# -*- coding: utf-8 -*-
"""Compose les fonds de bataille par ACTE depuis les packs craftpix.

POURQUOI ce script existe
-------------------------
Les packs craftpix sont des fonds de combat HORIZONTAUX 3840x2160 (16:9), livres
en couches separees. Le jeu est PORTRAIT 1080x1920. On ne peut ni les poser tels
quels (ratio inverse : on perdrait 80 % de la hauteur), ni embarquer leurs couches
(17 a 25 PNG de 3840 px par pack, reimportes a chaque run du harnais).

On pre-compose donc UN SEUL PNG 1080x1920 par acte, hors de res://, et on n ajoute
que ce fichier-la. 4 fichiers au lieu de 60, et aucun travail au runtime.

COMMENT le portrait est obtenu
------------------------------
Ces fonds ont tous la meme structure : une bande DECOREE en haut (horizon, arbres,
grilles, murs), un grand SOL vide au milieu, une bande de PREMIER PLAN en bas.
C est exactement la disposition du champ de bataille : les monstres arrivent en
haut, le mage tient le bas, le combat a lieu au milieu.

On garde donc le haut et le bas intacts, et on etire VERTICALEMENT le sol du
milieu. Le sol est une texture quasi uniforme : l etirement ne s y voit pas, alors
qu un etirement global deformerait les arbres et les tombes.

Verifie a l oeil sur les 4 fonds (captures de l etage visual).
"""
import os
import zipfile

from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")
Image.MAX_IMAGE_PIXELS = None  # ces sources font 8 Mpx, au-dessus du garde-fou PIL

OUT_DIR = "assets/backdrops"
TARGET_W, TARGET_H = 1080, 1920

# Un fond par acte de docs/histoire.md. On prend le PNG le plus complet de chaque
# dossier (toutes les couches deja aplaties par l auteur), pas les couches separees.
#
# (cle, archive, entree, part haute decoree, part basse de premier plan, eclaircissement)
#
# Les deux ratios sont regles a l oeil sur chaque image : ils disent ou s arrete le
# decor et ou commence le sol etirable. Trop haut, on etire un arbre ; trop bas, on
# jette du decor.
#
# L ECLAIRCISSEMENT (dernier nombre) ne sert pas au gout : il sert a LIRE. Les
# monstres Duelyst (Chevalier du vide, Behemoth) sont sombres et desatures ; poses
# sur le dallage sombre du cimetiere ou de la salle du trone, ils disparaissaient —
# verifie sur les captures bg_02 et bg_03 avant correction. On eclaircit donc le SOL
# (jamais les bandes decorees, qui doivent garder leur noir) jusqu a ce que la
# silhouette se detache. 1.0 = intact.
BACKDROPS = [
    # Acte I — Le Monde volant : iles suspendues, herbe, ciel. Le printemps craftpix
    # donne l ile-jardin du debut ; c est aussi le decor que l acte final imitera.
    ("act1_sky", "raw_assets/craftpix-net-593685-free-4-nature-backgrounds-for-rpg-battle.zip",
     "PNG/spring/6.png", 0.42, 0.12, 1.00),
    # Acte II — Le Grand Cimetiere : la foret morte du pack vampires EST un cimetiere
    # (grilles, croix, tombes, ciel rouge). Exactement l Ossuaire des Marees.
    ("act2_graveyard", "raw_assets/craftpix-net-889507-free-vampires-locations-battle-background-pack.zip",
     "PNG/4/dead forest.png", 0.40, 0.14, 1.45),
    # Acte III — Le Monde demoniaque : la salle du trone, pierre et braises rouges.
    # Pas un chateau de conte : une forge eclairee par en dessous.
    ("act3_demon", "raw_assets/craftpix-net-889507-free-vampires-locations-battle-background-pack.zip",
     "PNG/2/throne room.png", 0.38, 0.10, 1.55),
    # Acte final — Le Monde d origine : l herbe y est FAUSSE (docs/histoire.md).
    # L automne rejoue le vert de l acte I dans une teinte qui sonne faux : le joueur
    # reconnait le decor du premier niveau sans pouvoir dire ce qui cloche.
    ("act4_origin", "raw_assets/craftpix-net-593685-free-4-nature-backgrounds-for-rpg-battle.zip",
     "PNG/autumn/6.png", 0.42, 0.12, 1.00),
]


def lighten_ground(img, factor):
    """Eclaircit et desature le sol pour que les sprites sombres s y detachent.

    On melange vers un gris clair plutot que de multiplier : multiplier saturerait
    les rouges de la salle du trone en rose fluo. Le melange garde la teinte et ne
    fait que reduire le CONTRASTE du fond, ce qui est exactement le but — le fond
    doit reculer derriere les monstres.
    """
    if factor <= 1.0:
        return img
    # part de gris injectee : 1.45 -> 0.31, 1.55 -> 0.35
    blend = min(0.45, (factor - 1.0) / 1.45)
    grey = Image.new("RGB", img.size, (170, 165, 170))
    lit = Image.blend(img, grey, blend)
    # Le passage doit etre PROGRESSIF : applique d un coup, il dessinait une ligne
    # horizontale nette sous la bande decoree (visible sur bg_02 et bg_03). On
    # monte donc l eclaircissement sur le premier cinquieme de la hauteur, via un
    # masque en degrade — le raccord avec le decor devient invisible.
    w, h = img.size
    fade = max(1, h // 5)
    mask = Image.new("L", (w, h), 255)
    ramp = Image.new("L", (1, fade))
    ramp.putdata([int(255 * i / max(1, fade - 1)) for i in range(fade)])
    mask.paste(ramp.resize((w, fade)), (0, 0))
    return Image.composite(lit, img, mask)


def compose(entry_image, top_ratio, bottom_ratio, lift):
    """Portrait 1080x1920 : haut et bas intacts, sol du milieu etire et eclairci."""
    src = entry_image.convert("RGB")
    # 1) mise a la largeur cible. La source fait 3840 de large pour 1080 voulus :
    #    on reduit, donc aucune interpolation inventee.
    scaled = src.resize((TARGET_W, int(src.size[1] * TARGET_W / src.size[0])), Image.LANCZOS)
    sw, sh = scaled.size

    top_h = int(sh * top_ratio)
    bot_h = int(sh * bottom_ratio)
    middle_h = TARGET_H - top_h - bot_h
    if middle_h <= 0:
        raise SystemExit("ratios trop grands : il ne reste pas de sol a etirer")

    middle = scaled.crop((0, top_h, sw, sh - bot_h)).resize((sw, middle_h), Image.LANCZOS)
    middle = lighten_ground(middle, lift)

    out = Image.new("RGB", (TARGET_W, TARGET_H))
    out.paste(scaled.crop((0, 0, sw, top_h)), (0, 0))
    out.paste(middle, (0, top_h))
    out.paste(scaled.crop((0, sh - bot_h, sw, sh)), (0, TARGET_H - bot_h))
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for key, archive, entry, top_ratio, bot_ratio, lift in BACKDROPS:
        with zipfile.ZipFile(archive) as z, z.open(entry) as handle:
            src = Image.open(handle)
            src.load()
        out = compose(src, top_ratio, bot_ratio, lift)
        # Le fond est opaque et photographique : le JPEG serait 10x plus leger, mais
        # Godot reimporte mieux le PNG et 4 fichiers ne pesent pas.
        path = os.path.join(OUT_DIR, key + ".png")
        out.save(path, optimize=True)
        print("%-18s %s  (%d ko)" % (key, out.size, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
