# -*- coding: utf-8 -*-
"""Extrait des unites du pack Duelyst (.unitypackage) vers assets/units/.

Le .unitypackage est une archive tar.gz de dossiers <guid>/{asset,pathname}.
Chaque unite est un ATLAS irregulier decrit par un .plist : les cases y sont
nommees <unite>_<animation>_<NNN>.png avec leur rectangle dans l atlas.
On recompose une bande horizontale par animation, ce que SheetLib sait decouper.

Usage : python tools/assets/extract_duelyst.py
"""
import tarfile, io, re, os, sys
from PIL import Image
import numpy as np

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PKG = "raw_assets/monsters_2026_09/Duelyst-Unit-Animations.unitypackage"

# unite Duelyst -> (cle de catalogue, {animation Duelyst: animation du jeu})
# "run" est la boucle de deplacement, "breathing" le repos.
WANTED = {
    "boss_borealjuggernaut": ("juggernaut", {"run": "walk", "breathing": "idle",
                                             "hit": "hurt", "attack": "attack", "death": "death"}),
    "boss_chaosknight":      ("chaosknight", {"run": "walk", "breathing": "idle",
                                              "hit": "hurt", "attack": "attack", "death": "death"}),
}


def load_package(path):
    """Rend (chemin_unity -> octets) pour les seuls fichiers qui nous interessent."""
    t = tarfile.open(path, "r:gz")
    names, assets = {}, {}
    for m in t:
        guid = m.name.split("/")[0]
        if m.name.endswith("/pathname"):
            names[guid] = t.extractfile(m).read().decode("utf-8", "replace").split("\n")[0]
        elif m.name.endswith("/asset"):
            assets[guid] = m.name
    return t, names, assets


def frames_of(plist_text, unit, anim):
    """Rectangles des cases d une animation, dans l ordre des numeros."""
    pat = (r'<key>%s_%s_(\d+)\.png</key>\s*<dict>\s*<key>frame</key>\s*'
           r'<string>\{\{(\d+),(\d+)\},\{(\d+),(\d+)\}\}' % (re.escape(unit), re.escape(anim)))
    out = []
    for m in re.finditer(pat, plist_text):
        n, x, y, w, h = map(int, m.groups())
        out.append((n, x, y, w, h))
    out.sort()
    return out


def main():
    if not os.path.exists(PKG):
        sys.exit("paquet introuvable : %s" % PKG)
    t, names, assets = load_package(PKG)
    by_png = {names[g].split("/")[-1][:-4]: g for g in names
              if names[g].endswith(".png") and "/Spritesheets/Units/" in names[g]}
    by_plist = {names[g].split("/")[-1][:-6]: g for g in names if names[g].endswith(".plist")}

    for unit, (key, anims) in WANTED.items():
        if unit not in by_png or unit not in by_plist:
            print("  ABSENT du paquet : %s" % unit)
            continue
        atlas = Image.open(io.BytesIO(t.extractfile(assets[by_png[unit]]).read())).convert("RGBA")
        plist = t.extractfile(assets[by_plist[unit]]).read().decode("utf-8", "replace")
        walk_occ = 0.0
        for src_anim, dst_anim in anims.items():
            fr = frames_of(plist, unit, src_anim)
            if not fr:
                print("  %s : pas de cases pour %s" % (unit, src_anim))
                continue
            cw = max(f[3] for f in fr)
            ch = max(f[4] for f in fr)
            sheet = Image.new("RGBA", (cw * len(fr), ch), (0, 0, 0, 0))
            for i, (_, x, y, w, h) in enumerate(fr):
                # case centree horizontalement, posee sur le bas : les cases d une
                # meme unite n ont pas toutes la meme taille dans l atlas.
                sheet.paste(atlas.crop((x, y, x + w, y + h)),
                            (i * cw + (cw - w) // 2, ch - h))
            out = "assets/units/%s_%s.png" % (key, dst_anim)
            sheet.save(out)
            a = np.array(sheet)[:, :, 3] > 24
            bw = bh = 0
            for c in range(len(fr)):
                cell = a[:, c * cw:(c + 1) * cw]
                ys, xs = np.where(cell)
                if len(xs) == 0:
                    continue
                bw = max(bw, xs.max() - xs.min() + 1)
                bh = max(bh, ys.max() - ys.min() + 1)
            if dst_anim == "walk":
                walk_occ = max(bw, bh) / float(ch)
            print("  %-12s %-6s -> %2d cases de %dx%d, perso %dx%d" % (key, dst_anim, len(fr), cw, ch, bw, bh))
        # L echelle se calcule sur la MARCHE (etat permanent) et la hauteur de case.
        print('  => "%s": {"frame": %d, "frame_h": %d, "occupancy": %.2f, ...}\n'
              % (key, cw, ch, walk_occ))


if __name__ == "__main__":
    main()
