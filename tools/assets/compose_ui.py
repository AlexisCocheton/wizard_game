# -*- coding: utf-8 -*-
"""Recompose les planches 9-tranches de Tiny Swords en textures contigues.
Les planches originales rangent les 9 morceaux dans des cellules espacees ;
on decoupe chaque morceau a ses pixels opaques et on les colle bord a bord."""
from PIL import Image
import numpy as np, io, os, json
os.chdir(r'C:\Users\Lenovo\Desktop\wizard_game')

def bands(v):
    out=[]; start=None
    for i,x in enumerate(v):
        if x and start is None: start=i
        if not x and start is not None: out.append((start,i-1)); start=None
    if start is not None: out.append((start,len(v)-1))
    return out

def analyse(path):
    im = Image.open(path).convert("RGBA"); a = np.array(im)[:,:,3] > 8
    return im, bands(a.any(axis=0)), bands(a.any(axis=1))

margins = {}

def compose9(name, out_name=None):
    im, cb, rb = analyse("assets/ui/%s.png" % name)
    out_name = out_name or (name + "9")
    if len(cb) == 3 and len(rb) == 3:
        ws = [b[1]-b[0]+1 for b in cb]; hs = [b[1]-b[0]+1 for b in rb]
        out = Image.new("RGBA", (sum(ws), sum(hs)), (0,0,0,0))
        y = 0
        for r,(r0,r1) in enumerate(rb):
            x = 0
            for c,(c0,c1) in enumerate(cb):
                out.paste(im.crop((c0, r0, c1+1, r1+1)), (x, y))
                x += ws[c]
            y += hs[r]
        margins[out_name] = [ws[0], hs[0], ws[2], hs[2]]
    elif len(cb) == 3 and len(rb) == 1:
        # barre horizontale : 3 colonnes, une seule ligne
        r0, r1 = rb[0]
        ws = [b[1]-b[0]+1 for b in cb]
        out = Image.new("RGBA", (sum(ws), r1-r0+1), (0,0,0,0))
        x = 0
        for c,(c0,c1) in enumerate(cb):
            out.paste(im.crop((c0, r0, c1+1, r1+1)), (x, 0)); x += ws[c]
        margins[out_name] = [ws[0], 0, ws[2], 0]
    else:
        c0,c1 = cb[0]; r0,r1 = rb[0]
        out = im.crop((c0, r0, c1+1, r1+1))
        margins[out_name] = [0,0,0,0]
    out.save("assets/ui/%s.png" % out_name)
    print("  %-20s -> %s  %s  marges %s" % (name, out_name, out.size, margins[out_name]))
    return out

for n in ["paper","paper_special","btn_blue","btn_blue_pressed","btn_red","btn_red_pressed","btn_small","btn_small_pressed","btn_round_red","banner","wood","bar_base","smallbar_base"]:
    compose9(n)

# Remplissages : image de la taille de la base, tuile de remplissage posee dans l interieur.
def compose_fill(base_name, fill_name, out_name):
    base = Image.open("assets/ui/%s9.png" % base_name)
    bim, cb, rb = analyse("assets/ui/%s.png" % base_name)
    fim, fcb, frb = analyse("assets/ui/%s.png" % fill_name)
    tile = fim.crop((fcb[0][0], frb[0][0], fcb[0][1]+1, frb[0][1]+1))
    m = margins[base_name + "9"]
    out = Image.new("RGBA", base.size, (0,0,0,0))
    # bande verticale du remplissage relative au haut de la base
    y0 = frb[0][0] - rb[0][0]; h = tile.size[1]
    x = m[0]
    while x < base.size[0] - m[2]:
        w = min(tile.size[0], base.size[0] - m[2] - x)
        out.paste(tile.crop((0,0,w,h)), (x, y0)); x += w
    out.save("assets/ui/%s.png" % out_name)
    margins[out_name] = list(m)
    print("  %-20s -> %s  %s  bande y=%d h=%d" % (fill_name, out_name, out.size, y0, h))
compose_fill("bar_base", "bar_fill", "bar_fill9")
compose_fill("smallbar_base", "smallbar_fill", "smallbar_fill9")

# Le papier porte des plis le long des frontieres entre ses 9 morceaux : etires par le
# 9-tranches, ils deviennent des traits baveux ; tuiles, une grille. On les "repasse" :
# l interieur devient uni (couleur mediane du papier) et, dans les bords, chaque ligne ou
# colonne opaque qui s ecarte de cette couleur est remplacee par la couleur unie.
def heal_paper(name):
    path = "assets/ui/%s.png" % name
    im = Image.open(path).convert("RGBA"); a = np.array(im); H, W = a.shape[:2]
    ml, mt, mr, mb = margins[name]
    inner = a[mt:H-mb, ml:W-mr, :3].reshape(-1, 3)
    paper = np.median(inner, axis=0).astype(np.uint8)
    def off(px): return np.abs(px.astype(int) - paper.astype(int)).sum(axis=-1)
    # interieur : uni
    a[mt:H-mb, ml:W-mr, :3] = paper
    # bords haut/bas : lignes ; bords gauche/droit : colonnes
    for y in list(range(0, mt)) + list(range(H-mb, H)):
        seg = a[y, ml:W-mr]
        if (seg[:, 3] == 255).all() and (off(seg[:, :3]) > 40).any():
            a[y, ml:W-mr, :3] = paper
    for x in list(range(0, ml)) + list(range(W-mr, W)):
        seg = a[mt:H-mb, x]
        if (seg[:, 3] == 255).all() and (off(seg[:, :3]) > 40).any():
            a[mt:H-mb, x, :3] = paper
    # Coins : les plis y survivent (ni ligne ni colonne entiere). Un pixel de pli est une
    # NUANCE du papier (meme teinte, autre luminosite) ; un decor du pack a sa propre teinte
    # (les volutes dorees du papier special). On n efface que les nuances.
    def is_crease(px):
        d = px.astype(int) - paper.astype(int)
        return abs(d.max() - d.min()) < 26  # ecart identique sur R, G, B => simple ombre
    for (ys, xs) in [(range(2, mt), range(2, ml)), (range(2, mt), range(W-mr, W-2)),
                     (range(H-mb, H-2), range(2, ml)), (range(H-mb, H-2), range(W-mr, W-2))]:
        for y in ys:
            for x in xs:
                if a[y, x, 3] != 255 or off(a[y, x, :3]) <= 40 or not is_crease(a[y, x, :3]):
                    continue
                ring = a[y-2:y+3, x-2:x+3]
                if (ring[:, :, 3] == 255).all():
                    a[y, x, :3] = paper
    Image.fromarray(a).save(path)
    print("  %-20s repasse, papier %s" % (name, tuple(int(c) for c in paper)))
heal_paper("paper9")
heal_paper("paper_special9")

# Tuile de bois (cellule centrale) pour les fonds
wim, wcb, wrb = analyse("assets/ui/wood.png")
wtile = wim.crop((wcb[1][0], wrb[1][0], wcb[1][1]+1, wrb[1][1]+1))
# La cellule centrale porte l ombre de la planche sur ses premieres lignes : repetee,
# elle dessine une rayure sombre tous les 64 px. On la retire (lignes nettement plus sombres
# que la mediane) puis on verifie que la tuile se raccorde a elle-meme.
wa = np.array(wtile.convert("RGB")).mean(axis=2); wmed = float(np.median(wa))
# une ligne appartient a l ombre des qu un seul de ses pixels est franchement sombre
wtop = 0
while wa[wtop].min() < wmed * 0.55: wtop += 1
wbot = wtile.size[1]
while wa[wbot - 1].min() < wmed * 0.55: wbot -= 1
wtile = wtile.crop((0, wtop, wtile.size[0], wbot))
wa = np.array(wtile.convert("RGB")).mean(axis=2)
assert wa.min() > wmed * 0.55 and abs(wa[0].mean() - wa[-1].mean()) < wmed * 0.15, "tuile de bois non raccordable"
wtile.save("assets/ui/wood_tile.png")
print("  wood_tile", wtile.size, "ombre retiree :", wtop, "lignes")

# --- Injecte la table des marges dans UiTheme ---
p = 'scripts/ui/ui_theme.gd'
s = io.open(p, encoding='utf-8').read()
table = "const NINE: Dictionary = {\n" + "".join('\t"%s": [%d, %d, %d, %d],\n' % (k, *v) for k,v in sorted(margins.items())) + "}\n"
old = 'const UI := "res://assets/ui/"\n'
assert old in s
s = s.replace(old, old + "\n## Marges 9-tranches des textures recomposees (gauche, haut, droite, bas).\n" + table, 1)
old = '''static func tex_box(name: String, margin: int = 48, content: float = 18.0,
		tint: Color = Color.WHITE) -> StyleBox:
	var t: Texture2D = tex(name)
	if t == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_LIGHT
		return sb
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	sb.modulate_color = tint
	return sb'''
new = '''static func tex_box(name: String, _margin: int = 48, content: float = 18.0,
		tint: Color = Color.WHITE) -> StyleBox:
	# On utilise la version recomposee (<nom>9.png) et ses marges mesurees.
	var key: String = name + "9" if NINE.has(name + "9") else name
	var t: Texture2D = tex(key)
	if t == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PANEL_LIGHT
		return sb
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = NINE.get(key, [0, 0, 0, 0])
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.set_content_margin_all(content)
	sb.modulate_color = tint
	return sb'''
assert old in s
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print("  ui_theme : table NINE + tex_box")

# --- Scenes : barres du HUD et des monstres ---
bm = margins["bar_base9"]
def fix_bars(path, scale_line=None):
    t = io.open(path, encoding='utf-8').read()
    t = t.replace('path="res://assets/ui/bar_base.png"', 'path="res://assets/ui/bar_base9.png"')
    t = t.replace('path="res://assets/ui/bar_fill.png"', 'path="res://assets/ui/bar_fill9.png"')
    t = t.replace('path="res://assets/ui/smallbar_base.png"', 'path="res://assets/ui/bar_base9.png"')
    t = t.replace('path="res://assets/ui/smallbar_fill.png"', 'path="res://assets/ui/bar_fill9.png"')
    t = t.replace("stretch_margin_left = 20", "stretch_margin_left = %d" % bm[0])
    t = t.replace("stretch_margin_right = 20", "stretch_margin_right = %d" % bm[2])
    t = t.replace("stretch_margin_top = 20", "stretch_margin_top = 0")
    t = t.replace("stretch_margin_bottom = 20", "stretch_margin_bottom = 0")
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)
    print("  barres :", path)
fix_bars('scenes/hud/HUD.tscn')
fix_bars('scenes/game/Enemy.tscn')

# Enemy.tscn : la barre fait la largeur du monstre, echelle calculee en code
t = io.open('scenes/game/Enemy.tscn', encoding='utf-8').read()
t = t.replace("""offset_left = -32.0
offset_top = -52.0
offset_right = 288.0
offset_bottom = 12.0
scale = Vector2(0.2, 0.2)""", """offset_right = 112.0
offset_bottom = 51.0
scale = Vector2(0.5, 0.5)""")
io.open('scenes/game/Enemy.tscn', 'w', encoding='utf-8', newline='\n').write(t)
e = io.open('scripts/game/enemy.gd', encoding='utf-8').read()
old = """	var r: float = radius()
	_hp_bar.position = Vector2(-r, -r - 16.0)
	_hp_bar.scale = Vector2.ONE * (r * 2.0 / 320.0)"""
new = """	var r: float = radius()
	var sc: float = maxf(r * 2.0 / 112.0, 0.4)
	_hp_bar.scale = Vector2.ONE * sc
	_hp_bar.position = Vector2(-56.0 * sc, -r - 16.0 - 51.0 * sc)"""
assert old in e
e = e.replace(old, new, 1)
io.open('scripts/game/enemy.gd', 'w', encoding='utf-8', newline='\n').write(e)
print("  enemy : barre a l echelle")

# Menu : fond en tuile de bois
m = io.open('scenes/main_menu/MainMenu.tscn', encoding='utf-8').read()
m = m.replace('path="res://assets/ui/wood.png"', 'path="res://assets/ui/wood_tile.png"')
io.open('scenes/main_menu/MainMenu.tscn', 'w', encoding='utf-8', newline='\n').write(m)
print("  menu : tuile de bois")
print("COMPOSE OK")
