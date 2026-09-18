# -*- coding: utf-8 -*-
"""Mesure la part reellement occupee par le personnage / l effet dans sa case, et
l ecrit dans AnimCatalog.UNITS[*].occupancy et Fx.OCC.

POURQUOI ce script existe
-------------------------
Les cases des feuilles sont loin d etre pleines : Blood Monster tient dans 31 % de
sa case de 100 px, le cercle de protection dans 34 %. Mettre a l echelle la CASE au
lieu du PERSONNAGE donnait des boss minuscules et des auras trois fois trop petites.

DEUX REGLES QUI ONT COUTE CHER
------------------------------
1. La geometrie des cases se lit dans `AnimCatalog`, JAMAIS devinee d apres le nom
   du fichier. Une version precedente de ce script supposait 192 px (ou 320 pour
   les lanciers, 100 pour blood/demon) et ignorait `frame_h` : sur les feuilles
   RECTANGULAIRES ajoutees depuis (golems 90x64, peacock 32x32, chien 33x26, boss
   Duelyst 120x120), elle decoupait de travers et ecrivait des occupancies fausses
   — golem a 1.00 au lieu de 0.66, paon a 0.05 au lieu de 1.00. Le catalogue est
   la seule source de verite.

2. L occupation se mesure sur la pose de MARCHE, l etat permanent du monstre.
   La mesurer sur l attaque ou la mort — poses ponctuelles et etirees — retrecirait
   le monstre EN CONTINU pour tenir compte d un balayage d epee de deux frames.
   A defaut de marche, on prend l inactivite ; jamais attack/hurt/death.
"""
import io
import os
import re

import numpy as np
from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")

CATALOG = "scripts/game/anim_catalog.gd"
FX = "scripts/game/fx.gd"

# Animations acceptees pour la mesure, par ordre de preference. Voir regle 2.
POSE_ORDER = ("walk", "idle")


def cells_bbox(path, cell_w, cell_h=None):
    """Plus grande bbox opaque parmi les cases de la feuille."""
    img = Image.open(path).convert("RGBA")
    alpha = np.array(img)[:, :, 3] > 24
    height, width = alpha.shape
    cell_h = cell_h or height
    best_w = best_h = 0
    for row in range(max(1, height // cell_h)):
        for col in range(max(1, width // cell_w)):
            cell = alpha[row * cell_h:(row + 1) * cell_h, col * cell_w:(col + 1) * cell_w]
            ys, xs = np.where(cell)
            if len(xs) == 0:
                continue
            best_w = max(best_w, xs.max() - xs.min() + 1)
            best_h = max(best_h, ys.max() - ys.min() + 1)
    return best_w, best_h


def parse_catalog(source):
    """{cle: (frame_w, frame_h, {anim: fichier})} lu dans AnimCatalog.UNITS.

    On lit le fichier plutot que d embarquer une copie de la table : une feuille
    ajoutee au catalogue est mesuree sans toucher a ce script.
    """
    body = source.split("const UNITS: Dictionary = {", 1)[1]
    units = {}
    # Chaque entree tient sur une ou plusieurs lignes jusqu a l accolade fermante.
    for match in re.finditer(r'"([a-z0-9_]+)":\s*\{(.*?)\}\s*,\s*\n', body, re.S):
        key, fields = match.group(1), match.group(2)
        frame_w = re.search(r'"frame":\s*(\d+)', fields)
        if frame_w is None:
            continue
        frame_w = int(frame_w.group(1))
        frame_h = re.search(r'"frame_h":\s*(\d+)', fields)
        frame_h = int(frame_h.group(1)) if frame_h else frame_w
        anims = dict(re.findall(r'"(walk|idle|attack|guard|cast|hurt|death)":\s*\["([a-z0-9_]+)"', fields))
        units[key] = (frame_w, frame_h, anims)
    return units


def measure_units(units):
    out = {}
    for key, (frame_w, frame_h, anims) in units.items():
        pose = next((p for p in POSE_ORDER if p in anims), None)
        if pose is None:
            print("  (%s : ni marche ni inactivite, non mesure)" % key)
            continue
        path = "assets/units/%s.png" % anims[pose]
        if not os.path.exists(path):
            print("  (%s : %s absent)" % (key, path))
            continue
        w, h = cells_bbox(path, frame_w, frame_h)
        if w == 0:
            print("  (%s : feuille vide)" % key)
            continue
        # L echelle du sprite se calcule sur la HAUTEUR de la case : une case large
        # loge le balayage de l attaque, pas un monstre large. On rapporte donc la
        # plus grande dimension du personnage a la hauteur de la case.
        out[key] = min(1.0, max(w, h) / float(frame_h))
    return out


def measure_fx(source):
    """Grilles 100 px et bandes, lues dans Fx.GRIDS / Fx.STRIPS."""
    out = {}
    grids = re.search(r"const GRIDS: Dictionary = \{(.*?)\n\}", source, re.S).group(1)
    for name, file in re.findall(r'"([a-z0-9_]+)":\s*\["([a-z0-9_]+)"', grids):
        path = "assets/fx/%s.png" % file
        if not os.path.exists(path):
            continue
        w, h = cells_bbox(path, 100, 100)
        out[file] = max(w, h) / 100.0
    strips = re.search(r"const STRIPS: Dictionary = \{(.*?)\n\}", source, re.S).group(1)
    for name, file, cw, ch in re.findall(r'"([a-z0-9_]+)":\s*\["([a-z0-9_]+)",\s*(\d+),\s*(\d+)', strips):
        path = "assets/fx/%s.png" % file
        if not os.path.exists(path):
            continue
        w, h = cells_bbox(path, int(cw), int(ch))
        out[file] = max(w, h) / float(cw)
    return out


def main():
    catalog = io.open(CATALOG, encoding="utf-8").read()
    units = parse_catalog(catalog)
    print("occupancy unites (mesuree sur la pose de marche) :")
    measured = measure_units(units)
    for key in sorted(measured):
        print("  %-16s %.2f" % (key, measured[key]))

    for key, occ in measured.items():
        # Le motif s arrete au PREMIER "occupancy" qui suit la cle, et ne franchit
        # ni accolade ni saut de ligne de trop. Une version precedente utilisait
        # [^{}]*? avec re.DOTALL : elle mordait sur les entrees suivantes et en a
        # SUPPRIME trois. Un remplacement dans du code doit etre ancre.
        catalog, n = re.subn(
            r'("%s":\s*\{[^{}]*?"occupancy": )[0-9.]+' % re.escape(key),
            lambda m: m.group(1) + ("%.2f" % max(occ, 0.05)),
            catalog, count=1)
        if n == 0:
            print("  (pas de champ occupancy pour %s)" % key)
    io.open(CATALOG, "w", encoding="utf-8", newline="\n").write(catalog)
    print("  AnimCatalog mis a jour")

    source = io.open(FX, encoding="utf-8").read()
    fx = measure_fx(source)
    print("occupancy effets :")
    for key in sorted(fx):
        print("  %-18s %.2f" % (key, fx[key]))
    table = ("## Part de la case reellement occupee par l effet (mesuree sur les feuilles).\n"
             "const OCC: Dictionary = {\n"
             + "".join('\t"%s": %.2f,\n' % (k, v) for k, v in sorted(fx.items()))
             + "}\n")
    # RE-ecriture complete : une feuille ajoutee apres la premiere generation
    # n entrerait jamais dans la table si on ne l ecrivait que quand elle manque.
    source = re.sub(
        r"## Part de la case reellement occupee par l effet \(mesuree sur les feuilles\)\.\n"
        r"const OCC: Dictionary = \{.*?\n\}\n",
        lambda _: table, source, flags=re.S)
    io.open(FX, "w", encoding="utf-8", newline="\n").write(source)
    print("  Fx mis a jour")


if __name__ == "__main__":
    main()
