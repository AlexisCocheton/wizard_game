# -*- coding: utf-8 -*-
"""GARDE-ROBE DU PROFIL : robes, apprentis et leurs teintes, chapeaux dessines,
tours, portraits. Chantier cosmetiques de la vague 8 (02/10).

Usage :
    python tools/assets/make_wardrobe.py [CHEMIN_DE_raw_assets]

Le chemin des packs se donne en argument (ou par WIZARD_RAW_ROOT) : un worktree
n a pas `raw_assets/`, qui reste hors du depot (licences craftpix et autres :
redistribution des sources interdite). Par defaut, le depot principal.

Tout est extrait FEUILLE PAR FEUILLE, jamais un pack entier.

Ce que le script ecrit
----------------------
assets/units/      monk_{red,yellow}_*        robes Tiny Swords (Red/Yellow Monk)
                   monk_{dawn,forest}_*       robes remappees de monk_blue
                   bluewitch_{ember,frost,moss}_*   teintes de l Apprentie d azur
                   soldier_*, soldier_{azure,royal}_*  Ecuyer (Tiny RPG 01) et teintes
                   fairy_*, fairy_{sun,moss}_*      Fee (Fairy.zip, 3 couleurs d origine)
assets/terrain/    tower_{red,black,yellow,purple}  vraies tours Tiny Swords
                   tower_tree, tower_ruins, tower_monastery
assets/cosmetics/  hats.png      12 chapeaux dessines (tools/assets/hat_painter.py)
                   avatars.png   portraits Tiny Swords (Human Avatars), en grille
scripts/game/wardrobe_data.gd    GENERE : ancrage des chapeaux image par image,
                                 geometrie des tours, ordre des atlas.

POURQUOI UN REMPLACEMENT DE PALETTE (comme make_cosmetics.py) : un `modulate`
multiplie tous les pixels, peau et contour compris. Les cinq moines de Tiny
Swords ne different QUE par deux couleurs (verifie ici par assertion) : le
remplacement exact est la methode de l auteur du pack.
"""
import io
import os
import sys
import zipfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hat_painter  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNITS = os.path.join(ROOT, "assets", "units")
TERRAIN = os.path.join(ROOT, "assets", "terrain")
COSM = os.path.join(ROOT, "assets", "cosmetics")
DATA_GD = os.path.join(ROOT, "scripts", "game", "wardrobe_data.gd")

DEFAULT_RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets"

TS_ZIP = "Tiny Swords (Free Pack).zip"
TS = "Tiny Swords (Free Pack)/"


def raw_root():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.environ.get("WIZARD_RAW_ROOT") or DEFAULT_RAW


def read_member(raw, archive, member):
    with zipfile.ZipFile(os.path.join(raw, archive)) as z:
        return Image.open(io.BytesIO(z.read(member))).convert("RGBA")


def save(img, path):
    img.save(path, optimize=True)
    print("  %s  %dx%d" % (os.path.relpath(path, ROOT), img.width, img.height))


def remap(img, mapping):
    """Remplace des couleurs RGB EXACTES (alpha conserve)."""
    a = np.array(img.convert("RGBA"))
    out = a.copy()
    for src, dst in mapping.items():
        m = (a[..., 0] == src[0]) & (a[..., 1] == src[1]) & (a[..., 2] == src[2]) & (a[..., 3] > 0)
        out[m, 0:3] = dst
    return Image.fromarray(out, "RGBA")


def strip(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def cells(img, w, h):
    return [img.crop((i * w, 0, (i + 1) * w, h)) for i in range(img.width // w)]


# ---------------------------------------------------------------------------
# 1. ROBES DU MAGE
# ---------------------------------------------------------------------------
# Les deux couleurs de robe de monk_blue (mesurees par difference avec les quatre
# autres moines du pack : 2536 + 1599 pixels sur la pose d attente, rien d autre).
ROBE_DARK = (72, 88, 132)
ROBE_LIGHT = (70, 151, 172)

MONK_ANIMS = {"idle": "Idle", "walk": "Run", "cast": "Heal"}

# Robes du pack : meme planche, deux couleurs changees par l auteur.
PACK_ROBES = {"monk_red": "Red", "monk_yellow": "Yellow"}

# Robes REMAPPEES (sombre, clair). Teintes choisies pour rester lisibles sur
# l herbe claire du premier acte comme sur le dallage sombre du troisieme.
REMAP_ROBES = {
    "monk_dawn": ((178, 152, 196), (246, 236, 206)),    # ivoire et lilas : la robe d aube
    "monk_forest": ((52, 104, 70), (112, 182, 98)),     # vert de mousse
}


def make_robes(raw):
    print("Robes du mage :")
    for key, color in PACK_ROBES.items():
        for anim, src in MONK_ANIMS.items():
            img = read_member(raw, TS_ZIP, "%sUnits/%s Units/Monk/%s.png" % (TS, color, src))
            ref = Image.open(os.path.join(UNITS, "monk_blue_%s.png" % anim)).convert("RGBA")
            # Meme silhouette que la robe bleue, pixel pour pixel : c est ce qui
            # permet aux chapeaux de reprendre l ancrage mesure sur monk_blue.
            assert (np.array(img)[..., 3] == np.array(ref)[..., 3]).all(), (key, anim)
            save(img, os.path.join(UNITS, "%s_%s.png" % (key, anim)))
    for key, (dark, light) in REMAP_ROBES.items():
        for anim in MONK_ANIMS:
            ref = Image.open(os.path.join(UNITS, "monk_blue_%s.png" % anim)).convert("RGBA")
            save(remap(ref, {ROBE_DARK: dark, ROBE_LIGHT: light}),
                 os.path.join(UNITS, "%s_%s.png" % (key, anim)))


# ---------------------------------------------------------------------------
# 2. APPRENTIS ET LEURS TEINTES
# ---------------------------------------------------------------------------
# Blue Witch (deja extraite par extract_packs_2026_09_26.py, cases de 48 px).
# Familles de couleurs MESUREES sur les 5 feuilles bluewitch_* :
#   violet de nuit (robe et chapeau) : 4 tons ; turquoise (cheveux, ruban,
#   etincelles du sort) : 3 tons. Le reste (peau, creme de la poussiere, ombre)
#   ne bouge pas.
WITCH_NIGHT = [(35, 30, 43), (41, 35, 51), (50, 43, 63), (59, 50, 74)]
WITCH_TEAL = [(55, 113, 114), (61, 127, 128), (79, 164, 165)]
WITCH_VARIANTS = {
    # (4 tons de robe, 3 tons de cheveux et de magie)
    "bluewitch_ember": ([(54, 22, 28), (68, 26, 34), (84, 32, 42), (104, 40, 50)],
                        [(176, 72, 40), (200, 92, 48), (240, 140, 66)]),
    "bluewitch_frost": ([(92, 106, 140), (112, 128, 164), (138, 154, 190), (170, 186, 214)],
                        [(150, 188, 220), (176, 210, 236), (226, 244, 252)]),
    "bluewitch_moss": ([(26, 44, 32), (32, 54, 38), (40, 68, 46), (50, 84, 56)],
                       [(176, 140, 50), (204, 166, 62), (240, 206, 96)]),
}
WITCH_ANIMS = ["idle", "walk", "attack"]

# Soldier, Tiny RPG Character Asset Pack 01 (Zerie) : cases de 100 px ou le
# soldat n occupe que 17 x 21 px. Recadrage COMMUN a toutes les poses (sinon il
# sautille en changeant d etat) : x 22..78, y 18..62, mesure sur les bbox de
# toutes les cases (corps 41..58, fleche de l arc jusqu a 77, ombre jusqu a 60).
SOLDIER_ZIP = "packs_2026_09_26/Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc.zip"
SOLDIER_DIR = ("Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc/"
               "Characters(100x100 split)/Soldier/Soldier/")
SOLDIER_CROP = (22, 18, 78, 62)
SOLDIER_ANIMS = {
    "idle": "Soldier_Idle.png",
    "walk": "Soldier_Walk.png",
    # L arc (Attack03) : le seul geste qui PROJETTE quelque chose, donc celui qui
    # se lit comme un sort lance. Les deux coups d epee sont des corps a corps.
    "attack": "Soldier_Attack03.png",
    "hurt": "Soldier_Hurt.png",
    "death": "Soldier_Death.png",
}
# Tunique rouge, 3 tons mesures sur Soldier_Idle.
SOLDIER_RED = [(76, 26, 26), (103, 32, 32), (143, 56, 56)]
# Acier du casque et des epaulieres, 5 tons.
SOLDIER_STEEL = [(66, 92, 107), (96, 117, 129), (111, 130, 141), (155, 173, 183), (197, 208, 213)]
SOLDIER_VARIANTS = {
    "soldier_azure": {"red": [(26, 40, 86), (36, 58, 122), (62, 96, 170)]},
    "soldier_royal": {"red": [(58, 30, 86), (84, 42, 120), (124, 72, 168)],
                      "steel": [(150, 104, 36), (196, 146, 52), (214, 168, 66),
                                (242, 206, 104), (252, 236, 160)]},
}

# Fairy.zip : trois fees de 8 cases de 32 px, UNE animation (le vol). Les trois
# fichiers sont les trois couleurs de l auteur : pas de remplacement a faire.
FAIRY_ZIP = "packs_2026_09_26/Fairy.zip"
FAIRIES = {"fairy": "Fairy/Fairy 1.png", "fairy_sun": "Fairy/Fairy 2.png",
           "fairy_moss": "Fairy/Fairy 3.png"}


def make_apprentices(raw):
    print("Apprentis et teintes :")
    mapping_src = WITCH_NIGHT + WITCH_TEAL
    for key, (night, teal) in WITCH_VARIANTS.items():
        mapping = dict(zip(mapping_src, night + teal))
        for anim in WITCH_ANIMS:
            ref = Image.open(os.path.join(UNITS, "bluewitch_%s.png" % anim)).convert("RGBA")
            save(remap(ref, mapping), os.path.join(UNITS, "%s_%s.png" % (key, anim)))

    base = {}
    for anim, member in SOLDIER_ANIMS.items():
        sheet = read_member(raw, SOLDIER_ZIP, SOLDIER_DIR + member)
        frames = [c.crop(SOLDIER_CROP) for c in cells(sheet, 100, 100)]
        for f in frames:
            bb = f.getbbox()
            assert bb is not None, ("case vide", anim)
        base[anim] = strip(frames)
        save(base[anim], os.path.join(UNITS, "soldier_%s.png" % anim))
    for key, parts in SOLDIER_VARIANTS.items():
        mapping = dict(zip(SOLDIER_RED, parts["red"]))
        if "steel" in parts:
            mapping.update(dict(zip(SOLDIER_STEEL, parts["steel"])))
        for anim in ("idle", "walk", "attack"):
            save(remap(base[anim], mapping), os.path.join(UNITS, "%s_%s.png" % (key, anim)))

    for key, member in FAIRIES.items():
        img = read_member(raw, FAIRY_ZIP, member)
        assert img.size == (256, 32), img.size
        save(img, os.path.join(UNITS, "%s_idle.png" % key))


# ---------------------------------------------------------------------------
# 3. TOURS
# ---------------------------------------------------------------------------
# "feet" = le point de la texture (en px) ou se posent les PIEDS du personnage.
# La tour d origine est posee depuis toujours a MAGE_LINE_Y + 40, echelle 1,6 :
# les pieds du mage (MAGE_Y + (bas de MAGE_CROP - 96) x 1,35 = +32,65 px sous la
# ligne) tombent donc a y = 128 + (32,65 - 40) / 1,6 = 123,4 dans la tour, soit
# sur le plancher de bois au milieu des creneaux. On garde ce point pour les
# cinq tours Tiny Swords (meme planche, couleurs changees) : rien ne bouge pour
# qui garde la tour bleue.
TOWER_FEET = (64.0, 123.4)
TS_TOWERS = {"tower_red": "Red", "tower_black": "Black", "tower_yellow": "Yellow",
             "tower_purple": "Purple"}

RUINS_ZIP = "packs_2026_09_26/EPIC RPG World Pack - [FREE Demo]Ancient Ruins.zip"
RUINS_MEMBER = ("EPIC RPG World Pack - [FREE Demo]Ancient Ruins - Copia/Props/"
                "generic_estructure1-1-on grass.png")


def top_face_center(img, light_min=150):
    """Centre du DESSUS plat d un edifice : la plus grande plage claire de la
    moitie haute. Sert de point de pose des pieds."""
    a = np.array(img).astype(int)
    lum = a[..., :3].mean(-1)
    mask = (a[..., 3] > 200) & (lum > light_min)
    h = a.shape[0]
    mask[h // 2:] = False
    ys, xs = np.nonzero(mask)
    return float(xs.mean()), float(ys.mean())


def make_towers(raw):
    print("Tours :")
    specs = {}
    for key, color in TS_TOWERS.items():
        img = read_member(raw, TS_ZIP, "%sBuildings/%s Buildings/Tower.png" % (TS, color))
        assert img.size == (128, 256)
        save(img, os.path.join(TERRAIN, "%s.png" % key))
    for key in ["tower_blue", "tower_sand", "tower_obsidian", "tower_ember"] + list(TS_TOWERS):
        specs[key] = {"frame": [128, 256], "frames": 1, "feet": list(TOWER_FEET), "scale": 1.6}

    # L ARBRE : Tree3 de Tiny Swords, 8 cases de 192 px qui se balancent. Le
    # personnage est PERCHE dans le feuillage : pieds au centre du houppier,
    # mesure comme le centre de la plus grande masse opaque au-dessus du tronc.
    tree = read_member(raw, TS_ZIP, TS + "Terrain/Resources/Wood/Trees/Tree3.png")
    save(tree, os.path.join(TERRAIN, "tower_tree.png"))
    f0 = np.array(tree.crop((0, 0, 192, 192)))
    ys, xs = np.nonzero(f0[..., 3] > 200)
    # Le houppier = les lignes au-dessus du tronc. Le tronc commence la ou la
    # largeur opaque tombe sous le quart de la largeur maximale.
    larg = [(f0[y, :, 3] > 200).sum() for y in range(192)]
    maxw = max(larg)
    bas_houppier = max(y for y in range(192) if larg[y] >= maxw * 0.5)
    haut = int(ys.min())
    feet_y = haut + (bas_houppier - haut) * 0.62
    # Echelle 2,2 et non 1,6 : a 1,6 le bouleau (~70 px de houppier dans sa case
    # de 192) se lisait comme un BUISSON sous le personnage (vu en capture).
    specs["tower_tree"] = {"frame": [192, 192], "frames": tree.width // 192,
                           "feet": [float(xs.mean()), round(feet_y, 1)], "scale": 2.2, "fps": 6}

    # LE SANCTUAIRE DES RUINES : edifice de brique a toit plat (Ancient Ruins,
    # rafaelmatos). Les pieds au centre du toit, mesure sur ses pixels clairs.
    ruins = read_member(raw, RUINS_ZIP, RUINS_MEMBER)
    bb = ruins.getbbox()
    ruins = ruins.crop(bb)
    save(ruins, os.path.join(TERRAIN, "tower_ruins.png"))
    cx, cy = top_face_center(ruins)
    specs["tower_ruins"] = {"frame": [ruins.width, ruins.height], "frames": 1,
                            "feet": [round(cx, 1), round(cy, 1)], "scale": 1.4}

    # LE MONASTERE (Tiny Swords, bleu) : on ne grimpe pas sur un clocher. Le
    # personnage se tient DEVANT la porte, pieds sur le seuil : bas de la porte,
    # mesure comme la derniere ligne opaque de la colonne centrale.
    mona = read_member(raw, TS_ZIP, TS + "Buildings/Blue Buildings/Monastery.png")
    save(mona, os.path.join(TERRAIN, "tower_monastery.png"))
    a = np.array(mona)
    col = np.nonzero(a[:, mona.width // 2, 3] > 200)[0]
    specs["tower_monastery"] = {"frame": [mona.width, mona.height], "frames": 1,
                                "feet": [mona.width / 2.0, float(col.max()) - 4.0], "scale": 1.1}
    # VIGNETTE : la region opaque de la premiere case, mesuree. Une tour de
    # 128x256 n en occupe que 120x184 (vide au-dessus des creneaux et sous
    # l ombre) : la case entiere donnait une tour minuscule dans son bouton.
    for key, spec in specs.items():
        img = Image.open(os.path.join(TERRAIN, "%s.png" % key)).convert("RGBA")
        fw, fh = spec["frame"]
        bb = img.crop((0, 0, fw, fh)).getbbox()
        spec["crop"] = [bb[0], bb[1], bb[2] - bb[0], bb[3] - bb[1]]
    return specs


# ---------------------------------------------------------------------------
# 4. PORTRAITS
# ---------------------------------------------------------------------------
# Tiny Swords, UI Elements/Human Avatars : 25 portraits = 5 tetes x 5 couleurs
# (ligne 1 bleu, 2 rouge, 3 jaune, 4 violet, 5 noir ; colonnes chevalier,
# guerrier, lancier, MOINE, paysanne). Le 7 est l avatar.png affiche aujourd hui.
AVATARS = [
    ("avatar_warrior_red", 7),
    ("avatar_monk_blue", 4),
    ("avatar_pawn_blue", 5),
    ("avatar_knight_blue", 1),
    ("avatar_monk_red", 9),
    ("avatar_lancer_yellow", 13),
    ("avatar_monk_yellow", 14),
    ("avatar_knight_purple", 16),
    ("avatar_monk_purple", 19),
    ("avatar_monk_black", 24),
]
AVATAR_CELL = 256
AVATAR_COLS = 5


def make_avatars(raw):
    print("Portraits :")
    rows = (len(AVATARS) + AVATAR_COLS - 1) // AVATAR_COLS
    out = Image.new("RGBA", (AVATAR_CELL * AVATAR_COLS, AVATAR_CELL * rows), (0, 0, 0, 0))
    boites = []
    for i, (_key, n) in enumerate(AVATARS):
        img = read_member(raw, TS_ZIP, "%sUI Elements/UI Elements/Human Avatars/Avatars_%02d.png" % (TS, n))
        assert img.size == (AVATAR_CELL, AVATAR_CELL)
        out.alpha_composite(img, ((i % AVATAR_COLS) * AVATAR_CELL, (i // AVATAR_COLS) * AVATAR_CELL))
        bb = img.getbbox()
        boites.append(bb)
    save(out, os.path.join(COSM, "avatars.png"))
    # Recadrage COMMUN (union des boites opaques) : les portraits occupent
    # ~145 px sur 256 ; la case entiere les montrait perdus dans le vide. Commun
    # pour que tous les portraits aient la meme taille de tete.
    x0 = min(b[0] for b in boites)
    y0 = min(b[1] for b in boites)
    x1 = max(b[2] for b in boites)
    y1 = max(b[3] for b in boites)
    return [x0, y0, x1 - x0, y1 - y0]


# ---------------------------------------------------------------------------
# 5. CHAPEAUX : dessin et ancrage image par image
# ---------------------------------------------------------------------------
# Le disque clair de la tonsure : couleur propre a la tete du moine (peau du
# crane eclairee), absente du reste du sprite. Son centre donne l axe de la tete
# sur chaque image, y compris tete renversee pendant l incantation.
SCALP = (239, 225, 171)


def measure_monk_anchors(prefix):
    """{anim: [[x, y], ...]} : SOMMET DE LA TETE, image par image, en px de case.

    x = centre de la tonsure ; y = premier pixel opaque au-dessus d elle, cherche
    dans les colonnes de la tete seulement (les mains levees de l incantation
    passent au-dessus de la tete sur certaines images, a cote)."""
    out = {}
    for anim in MONK_ANIMS:
        a = np.array(Image.open("%s_%s.png" % (prefix, anim)).convert("RGBA")).astype(int)
        n = a.shape[1] // 192
        pts = []
        for i in range(n):
            c = a[:, i * 192:(i + 1) * 192]
            m = (c[..., 0] == SCALP[0]) & (c[..., 1] == SCALP[1]) & (c[..., 2] == SCALP[2])
            ys, xs = np.nonzero(m)
            assert len(xs) > 10, ("tonsure introuvable", anim, i)
            x0, x1 = xs.min(), xs.max()
            cx = (x0 + x1) / 2.0
            band = c[:, max(0, x0 - 4):x1 + 5, 3] > 200
            top = int(np.nonzero(band.any(1))[0].min())
            pts.append([round(cx, 1), top])
        out[anim] = pts
    return out


def make_hats():
    print("Chapeaux :")
    save(hat_painter.atlas(), os.path.join(COSM, "hats.png"))
    anchors = measure_monk_anchors(os.path.join(UNITS, "monk_blue"))
    # Toutes les robes partagent la silhouette de monk_blue (assertion faite a
    # l extraction pour les robes du pack, vraie par construction pour les
    # remappees) : un seul jeu d ancrages, nomme "monk".
    return anchors


# ---------------------------------------------------------------------------
# 6. OCCUPATION des nouvelles cles (meme regle que measure_occupancy.py : pose
#    de MARCHE, a defaut d attente ; plus grande dimension / hauteur de case).
#    On ne lance PAS measure_occupancy.py : il reecrit tout le catalogue (piege
#    documente, ~45 valeurs deja jouees changeraient).
# ---------------------------------------------------------------------------

def occupancy(path, cw, ch):
    a = np.array(Image.open(path).convert("RGBA"))[..., 3] > 24
    bw = bh = 0
    for i in range(a.shape[1] // cw):
        ys, xs = np.nonzero(a[:ch, i * cw:(i + 1) * cw])
        if len(xs):
            bw = max(bw, xs.max() - xs.min() + 1)
            bh = max(bh, ys.max() - ys.min() + 1)
    return min(1.0, max(bw, bh) / float(ch))


def report_occupancy():
    print("Occupation (a reporter dans AnimCatalog) :")
    for key, cw, ch, pose in [
        ("monk_red", 192, 192, "walk"), ("monk_yellow", 192, 192, "walk"),
        ("monk_dawn", 192, 192, "walk"), ("monk_forest", 192, 192, "walk"),
        ("bluewitch_ember", 48, 48, "walk"), ("bluewitch_frost", 48, 48, "walk"),
        ("bluewitch_moss", 48, 48, "walk"),
        ("soldier", 56, 44, "walk"), ("soldier_azure", 56, 44, "walk"),
        ("soldier_royal", 56, 44, "walk"),
        ("fairy", 32, 32, "idle"), ("fairy_sun", 32, 32, "idle"), ("fairy_moss", 32, 32, "idle"),
    ]:
        print("  %-18s %.2f" % (key, occupancy(os.path.join(UNITS, "%s_%s.png" % (key, pose)), cw, ch)))


# ---------------------------------------------------------------------------
# 7. Donnees generees
# ---------------------------------------------------------------------------

def gd_value(v):
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, gd_value(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(gd_value(x) for x in v) + "]"
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, float):
        return ("%.1f" % v)
    return str(v)


def write_data(anchors, towers, avatar_crop):
    lines = [
        "class_name WardrobeData",
        "extends RefCounted",
        "## GENERE par tools/assets/make_wardrobe.py -- NE PAS EDITER A LA MAIN.",
        "## Relancer le script apres tout changement de feuille de robe, de chapeau ou",
        "## de tour : les nombres ci-dessous sont MESURES sur les PNG.",
        "",
        "## --- CHAPEAUX (assets/cosmetics/hats.png, une case par chapeau) ---",
        "const HAT_SHEET: String = \"res://assets/cosmetics/hats.png\"",
        "const HAT_CELL: Vector2i = Vector2i(%d, %d)" % (hat_painter.CELL_W, hat_painter.CELL_H),
        "## Point de la case pose sur le SOMMET DE LA TETE.",
        "const HAT_PIVOT: Vector2 = Vector2(%d, %d)" % (hat_painter.PIVOT_X, hat_painter.PIVOT_Y),
        "const HATS: Array[String] = %s" % gd_value([k for k, _ in hat_painter.HATS]),
        "",
        "## Sommet de la tete IMAGE PAR IMAGE, en px de la case de la feuille (192 px",
        "## pour le moine). Cle = gabarit ; HAT_RIGS dit quelle feuille utilise lequel.",
        "## Mesure : centre de la tonsure, premier pixel opaque au-dessus dans les",
        "## colonnes de la tete (les mains levees de l incantation sont a cote).",
        "const HAT_ANCHORS: Dictionary = {",
        "\t\"monk\": {",
    ]
    for anim, pts in anchors.items():
        lines.append("\t\t\"%s\": %s," % (anim, gd_value([[float(x), float(y)] for x, y in pts])))
    lines += [
        "\t},",
        "}",
        "## Feuille jouee -> gabarit de tete. Les sept robes du mage sont la MEME",
        "## silhouette (assertion alpha dans le script) ; les apprentis n en ont pas :",
        "## chacun porte deja son couvre-chef dessine (chapeau de sorciere, casque,",
        "## antennes de fee), un second chapeau par-dessus serait un non-sens.",
        "const HAT_RIGS: Dictionary = %s" % gd_value({k: "monk" for k in [
            "monk_blue", "monk_black", "monk_purple", "monk_red", "monk_yellow",
            "monk_dawn", "monk_forest"]}),
        "const HAT_RIG_CELL: Dictionary = {\"monk\": 192}",
        "",
        "## --- TOURS (assets/terrain/<cle>.png) ---",
        "## frame = taille d une case ; frames > 1 = bande animee ; feet = point de la",
        "## case ou se posent les PIEDS du personnage ; scale = echelle a l ecran ;",
        "## crop = region opaque de la premiere case (vignette de l onglet).",
        "const TOWERS: Dictionary = {",
    ]
    for key, spec in towers.items():
        lines.append("\t\"%s\": %s," % (key, gd_value(spec)))
    lines += [
        "}",
        "",
        "## --- PORTRAITS (assets/cosmetics/avatars.png, grille) ---",
        "const AVATAR_SHEET: String = \"res://assets/cosmetics/avatars.png\"",
        "const AVATAR_CELL: int = %d" % AVATAR_CELL,
        "const AVATAR_COLS: int = %d" % AVATAR_COLS,
        "## Region utile commune a tous les portraits (union des boites opaques).",
        "const AVATAR_CROP: Rect2i = Rect2i(%d, %d, %d, %d)" % tuple(avatar_crop),
        "const AVATARS: Array[String] = %s" % gd_value([k for k, _ in AVATARS]),
        "",
    ]
    with io.open(DATA_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("  %s" % os.path.relpath(DATA_GD, ROOT))


def main():
    raw = raw_root()
    assert os.path.isdir(raw), "raw_assets introuvable : %s" % raw
    os.makedirs(COSM, exist_ok=True)
    make_robes(raw)
    make_apprentices(raw)
    towers = make_towers(raw)
    avatar_crop = make_avatars(raw)
    anchors = make_hats()
    report_occupancy()
    write_data(anchors, towers, avatar_crop)


if __name__ == "__main__":
    main()
