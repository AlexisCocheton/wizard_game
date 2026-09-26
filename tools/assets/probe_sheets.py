# -*- coding: utf-8 -*-
"""Mesure la geometrie REELLE d une feuille avant de l extraire.

POURQUOI ce script existe
-------------------------
Les autres scripts de `tools/assets/` extraient des feuilles dont on connait deja
la decoupe. Pour les 47 archives arrivees le 2026-09-26, on ne la connait pas : le
nom de fichier ne dit ni la largeur de case, ni s il y a des marges entre les cases,
ni quelle part de la case le personnage occupe reellement.

Les trois erreurs que ce script evite, toutes payees sur les packs precedents :

1. SUPPOSER la largeur de case d apres la hauteur. Faux des que la feuille est
   rectangulaire (golems 90x64, chien 33x26). On la DEDUIT ici : on cherche le
   diviseur de la largeur qui aligne les colonnes vides sur une grille reguliere.

2. SUPPOSER qu il n y a pas d espacement. Certaines feuilles laissent 1 a 4 px
   entre les cases ; decoupees a pas regulier sans marge, tous les frames glissent.
   On detecte les colonnes entierement transparentes et on regarde si leur pas est
   constant.

3. SUPPOSER que la case est pleine. Blood Monster tient dans 31 % de sa case.
   On mesure ici la bbox opaque max, comme `measure_occupancy.py` le fait plus tard
   sur le catalogue — mais AVANT d avoir ecrit quoi que ce soit.

Ce script ne MODIFIE rien : il imprime. Il sert a decider, pas a produire.

Usage :
    python tools/assets/probe_sheets.py <png> [<png> ...]
    python tools/assets/probe_sheets.py --zip <archive> <motif-interne>
"""
import os
import sys
import zipfile

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None


def empty_columns(alpha):
    """Indices des colonnes entierement transparentes."""
    return [x for x in range(alpha.shape[1]) if not alpha[:, x].any()]


def guess_frame_width(alpha):
    """Largeur de case la plus plausible.

    On teste chaque nombre de frames de 1 a 40. Un decoupage est bon si chaque
    frontiere tombe dans une colonne vide (ou a 1 px d une), et si aucune case
    n est entierement vide.
    """
    height, width = alpha.shape
    empties = set(empty_columns(alpha))
    best = None
    for n in range(1, 41):
        if width % n:
            continue
        w = width // n
        if w < 8:
            continue
        boundaries_ok = 0
        for i in range(1, n):
            x = i * w
            if x in empties or (x - 1) in empties or x + 1 in empties:
                boundaries_ok += 1
        filled = 0
        for i in range(n):
            if alpha[:, i * w:(i + 1) * w].any():
                filled += 1
        if filled != n:
            continue
        score = (boundaries_ok / max(1, n - 1), -abs(w - height))
        if best is None or score > best[0]:
            best = (score, n, w)
    if best is None:
        return width, 1, 0.0
    (ratio, _), n, w = best
    return w, n, ratio


def bbox_max(alpha, cell_w, cell_h):
    """Plus grande bbox opaque parmi les cases."""
    height, width = alpha.shape
    bw = bh = 0
    for row in range(max(1, height // cell_h)):
        for col in range(max(1, width // cell_w)):
            cell = alpha[row * cell_h:(row + 1) * cell_h, col * cell_w:(col + 1) * cell_w]
            ys, xs = np.where(cell)
            if not len(xs):
                continue
            bw = max(bw, xs.max() - xs.min() + 1)
            bh = max(bh, ys.max() - ys.min() + 1)
    return bw, bh


def probe(name, fp):
    img = Image.open(fp).convert("RGBA")
    alpha = np.array(img)[:, :, 3] > 24
    h, w = alpha.shape
    cw, n, ratio = guess_frame_width(alpha)
    bw, bh = bbox_max(alpha, cw, h)
    occ = round(bh / h, 3) if h else 0.0
    gaps = empty_columns(alpha)
    print("%-58s %4dx%-4d  frame=%3dx%-4d n=%-3d conf=%.2f  bbox=%dx%d occ_h=%.2f%s"
          % (name, w, h, cw, h, n, ratio, bw, bh, occ,
             "  (colonnes vides: %d)" % len(gaps) if gaps else ""))


def main(argv):
    if argv[:1] == ["--zip"]:
        archive, pattern = argv[1], argv[2]
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                if info.is_dir() or "__MACOSX" in info.filename:
                    continue
                if not info.filename.lower().endswith(".png"):
                    continue
                if pattern.lower() not in info.filename.lower():
                    continue
                with z.open(info) as fp:
                    probe(os.path.basename(info.filename), fp)
        return 0
    for path in argv:
        probe(os.path.basename(path), path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
