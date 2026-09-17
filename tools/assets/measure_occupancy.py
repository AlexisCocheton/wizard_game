# -*- coding: utf-8 -*-
"""Mesure la part reellement occupee par le personnage / l effet dans chaque case
de spritesheet (bbox opaque max sur toutes les cases), et l ecrit dans le code."""
from PIL import Image
import numpy as np, io, os, re, json
os.chdir(r'C:\Users\Lenovo\Desktop\wizard_game')

def cells_bbox(path, cw, ch=None):
    im = Image.open(path).convert("RGBA"); a = np.array(im)[:, :, 3] > 24
    H, W = a.shape; ch = ch or H
    cols, rows = W // cw, H // ch
    best_w = best_h = 0
    for r in range(rows):
        for c in range(cols):
            cell = a[r*ch:(r+1)*ch, c*cw:(c+1)*cw]
            ys, xs = np.where(cell)
            if len(xs) == 0: continue
            best_w = max(best_w, xs.max() - xs.min() + 1)
            best_h = max(best_h, ys.max() - ys.min() + 1)
    return best_w, best_h

# --- unites : occupancy = plus grande dimension du personnage / taille de case ---
units = {}
for f in sorted(os.listdir("assets/units")):
    if not f.endswith(".png"): continue
    key = f[:-4]
    im = Image.open("assets/units/" + f)
    frame = 100 if key.startswith(("blood", "demon")) else (320 if key.startswith("lancer") else 192)
    if key == "totem_tower":
        a = np.array(im.convert("RGBA"))[:, :, 3] > 24
        ys, xs = np.where(a); units[key] = (xs.max()-xs.min()+1, ys.max()-ys.min()+1, im.size[1]); continue
    w, h = cells_bbox("assets/units/" + f, frame)
    units[key] = (w, h, frame)
by_key = {}
for key, (w, h, frame) in units.items():
    base = key.rsplit("_", 1)[0] if key.split("_")[0] in ("blood", "demon") else key.rsplit("_", 1)[0]
    # cle du catalogue = fichier sans le suffixe d animation
    for suffix in ("_walk", "_idle", "_attack", "_guard", "_cast", "_hurt", "_death"):
        if key.endswith(suffix): base = key[:-len(suffix)]
    if key == "totem_tower": base = "totem_tower"
    occ = max(w, h) / frame
    by_key[base] = max(by_key.get(base, 0), occ)
print("occupancy unites :")
for k in sorted(by_key): print("  %-16s %.2f" % (k, by_key[k]))

# --- effets : idem sur grilles 100 px et bandes ---
fx = {}
grids = ["magicspell","magic8","bluefire","casting","magickahit","firespin","protectioncircle","brightfire","fire","vortex","felspell","midnight","freezing","magicbubbles","weaponhit"]
strips = {"explosion_d": (128,128), "explosion_e": (192,192), "explosion_c": (128,80), "ts_dust_01": (64,64), "ts_explosion_01": (192,192), "ts_fire_02": (64,64), "heal_effect": (192,192)}
for g in grids:
    w, h = cells_bbox("assets/fx/%s.png" % g, 100, 100); fx[g] = max(w, h) / 100.0
for s, (cw, ch) in strips.items():
    w, h = cells_bbox("assets/fx/%s.png" % s, cw, ch); fx[s] = max(w, h) / cw
print("occupancy effets :")
for k in sorted(fx): print("  %-18s %.2f" % (k, fx[k]))

# --- ecrit dans AnimCatalog ---
p = 'scripts/game/anim_catalog.gd'
s = io.open(p, encoding='utf-8').read()
for k, occ in by_key.items():
    s, n = re.subn(r'("%s":\s*\{[^\n]*?"occupancy": )[0-9.]+' % re.escape(k), lambda m: m.group(1) + ("%.2f" % max(occ, 0.05)), s)
    if n == 0: print("  (pas de cle %s dans le catalogue)" % k)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("  AnimCatalog mis a jour")

# --- ecrit dans Fx : table OCC + utilisation dans sprite() ---
p = 'scripts/game/fx.gd'
s = io.open(p, encoding='utf-8').read()
table = "## Part de la case reellement occupee par l effet (mesuree sur les feuilles).\nconst OCC: Dictionary = {\n" + "".join('\t"%s": %.2f,\n' % (k, v) for k, v in sorted(fx.items())) + "}\n\n"
if "const OCC" not in s:
    s = s.replace("static func enabled() -> bool:", table + "\nstatic func enabled() -> bool:", 1)
old = """	var cell: float = 100.0
	if STRIPS.has(name):
		cell = float(STRIPS[name][1])
	sp.scale = Vector2.ONE * (size_px / cell)"""
new = """	var cell: float = 100.0
	var file: String = name
	if STRIPS.has(name):
		cell = float(STRIPS[name][1])
		file = str(STRIPS[name][0])
	# On met a l echelle la partie VISIBLE de la case, pas la case entiere.
	var occ: float = float(OCC.get(file, OCC.get(name, 1.0)))
	sp.scale = Vector2.ONE * (size_px / (cell * maxf(occ, 0.05)))"""
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("  Fx mis a jour")

# --- barres de vie : plus petites, juste au-dessus du sprite ---
p = 'scripts/game/enemy.gd'
s = io.open(p, encoding='utf-8').read()
old = """	var r: float = visual_radius()
	var sc: float = maxf(r * 2.0 / 112.0, 0.45)
	_hp_bar.scale = Vector2.ONE * sc
	_hp_bar.position = Vector2(-56.0 * sc, -r - 10.0 - 51.0 * sc)"""
new = """	var r: float = visual_radius()
	# Barre a peu pres aussi large que le monstre, mais jamais enorme.
	var sc: float = clampf(r * 2.0 / 112.0 * 0.6, 0.3, 0.75)
	_hp_bar.scale = Vector2.ONE * sc
	_hp_bar.position = Vector2(-56.0 * sc, -r * 0.95 - 51.0 * sc)"""
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("  barres de vie repositionnees")
print("MEASURE OK")
