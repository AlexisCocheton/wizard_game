"""Icones des seize PASSIFS ELEMENTAIRES (vague 8) : assets/icons/pass_<id>.png.

Une icone dediee par passif, comme toute carte (test_card_icons : chaque carte
a son image, et deux cartes ne la partagent jamais). Toutes viennent des packs
craftpix deja autorises (commercial oui, credit non, redistribution des sources
non) ; AUCUNE du pack Batareya (licence inconnue, voir docs/assets_index.md).

Choix fait sur planches de contact (packs entiers, icones deja prises par une
carte ou un logo barrees), deux par element, d une image qui DIT l element :

  feu      pass_fire_fury      FireMage 21     coeur de braise
           pass_fire_embers    FireMage 12     goutte de feu couvant
  eau      pass_water_spring   Warlock 16      serpent d eau
           pass_water_flood    Warlock 14      vague
  nature   pass_nature_roots   EarthMage 32    racines
           pass_nature_sap     EarthMage 30    baton de bois vivant
  vent     pass_wind_tailwind  Aeromancer 16   aile
           pass_wind_gale      Aeromancer 10   tornade
  foudre   pass_storm_surge    Night Elf 14    eclairs
           pass_storm_reflex   Night Elf 19    elfe dans l orage
  glace    pass_ice_winter     Night Elf 20    elfe aux cristaux
           pass_ice_bite       Warlock 18      main de givre
  arcane   pass_arcane_mind    Night Elf 7     lune II
           pass_arcane_lore    Night Elf 44    pierre runique
  poison   pass_poison_linger  Warlock 37      crane dans un nuage
           pass_poison_corrode Warlock 50      crane rongeur

Usage : python tools/assets/extract_element_passives.py  (racine du projet)
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
    "nightelf": "Free-RPG-Night-Elf-Skill-Icons.zip",
    "warlock": "Free Warlock Skills.zip",
    "earth": "EarthMage_Free.zip",
    "fire": "FireMage_Free.zip",
    "aero": "Free 50 Aeromancer Skills.zip",
}

ICONS = {
    "pass_fire_fury": ("fire", 21),
    "pass_fire_embers": ("fire", 12),
    "pass_water_spring": ("warlock", 16),
    "pass_water_flood": ("warlock", 14),
    "pass_nature_roots": ("earth", 32),
    "pass_nature_sap": ("earth", 30),
    "pass_wind_tailwind": ("aero", 16),
    "pass_wind_gale": ("aero", 10),
    "pass_storm_surge": ("nightelf", 14),
    "pass_storm_reflex": ("nightelf", 19),
    "pass_ice_winter": ("nightelf", 20),
    "pass_ice_bite": ("warlock", 18),
    "pass_arcane_mind": ("nightelf", 7),
    "pass_arcane_lore": ("nightelf", 44),
    "pass_poison_linger": ("warlock", 37),
    "pass_poison_corrode": ("warlock", 50),
}


def _image(pack, num):
    zf = zipfile.ZipFile(os.path.join(RAW, PACKS[pack]))
    for n in zf.namelist():
        if re.search(r"(^|/|_)%d\.png$" % num, n):
            return Image.open(io.BytesIO(zf.read(n))).convert("RGBA")
    sys.exit("introuvable : %s %d" % (pack, num))


def main():
    dest = os.path.join(PROJ, "assets", "icons")
    os.makedirs(dest, exist_ok=True)
    vus = set()
    for cle, (pack, num) in ICONS.items():
        if (pack, num) in vus:
            sys.exit("icone en double : %s %d" % (pack, num))
        vus.add((pack, num))
        _image(pack, num).resize((SIZE, SIZE), Image.LANCZOS).save(
            os.path.join(dest, cle + ".png"), optimize=True)
        print("icone", cle)


if __name__ == "__main__":
    main()
