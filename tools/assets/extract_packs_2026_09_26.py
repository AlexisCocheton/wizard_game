# -*- coding: utf-8 -*-
"""Extrait les silhouettes de monstres et les effets des 47 archives du 2026-09-26.

POURQUOI seulement celles-la
----------------------------
Les 47 archives pesent 1,6 Go et contiennent ~3 400 PNG. Chaque PNG depose dans
`res://` est reimporte a CHAQUE run du harnais (etape `--import`, 10 s aujourd hui) :
tout extraire multiplierait ce temps pour des fichiers jamais joues. On ne prend
donc qu une feuille par ANIMATION UTILE d une creature qui apporte une silhouette
ABSENTE du jeu.

Ce qui est ECARTE, et pourquoi (le detail complet est dans docs/assets_index.md) :

  Lords Of Pain (539 PNG)  isometrique, 16 directions de boussole par animation
      (E / NE / NEE / NNE / N ...). Le jeu est en vue de cote : il faudrait choisir
      UNE direction et jeter 15/16 du pack, pour un style 3D pre-rendu qui ne
      raccorde avec aucune autre unite. Ecarte en entier.

  Barbarian / EarthMage / FireMage / Warlock / Aeromancer / NightElf / MAGE ICONS
      (690 PNG)  ce sont des ICONES de sorts, pas des unites. Un autre chantier
      les traite : on n y touche pas pour ne pas ecraser son travail.

  ttrpg_legend x5 + cogabushi + Wood Elves  portraits et decors de dialogue,
      traites par le chantier des personnages de l histoire.

  Essentials Pre-Render.zip  sous-ensemble strict de Essentials.zip (les 29 PNG de
      `Pre-Render/` y sont deja, a l identique). Doublon.

  Free Sprites (28 PNG)  battlers RPG Maker vus de face, immobiles, resolution
      inegale (un berger allemand photo-realiste a cote d un gobelin 32 px). Rien
      d animé exploitable.

  Fairy.zip  trois feuilles 32x32 de 8 frames : une seule pose de vol, pas
      d attaque ni de mort. Insuffisant pour une entree d AnimCatalog.

DEUX PIEGES MESURES SUR CES ARCHIVES (pas des precautions theoriques)
---------------------------------------------------------------------
1. Les feuilles luizmelo (Monsters_Creatures, Evil Wizard) ont des cases de
   150x150 dont le personnage n occupe que 21 a 45 % de la HAUTEUR. Mises a
   l echelle sur la case, ces creatures sortiraient minuscules. On RECADRE donc
   chaque feuille sur la bbox opaque commune a toutes ses animations, ce qui
   remonte l occupation au-dessus de 0,85 et reduit le poids des fichiers.
   Le recadrage est COMMUN a toutes les animations d une creature, sinon les
   poses ne s alignent plus entre elles et le monstre sautille en changeant d etat.

2. Blue Witch et Small Monster empilent leurs frames VERTICALEMENT (32x288 =
   9 frames de 32x32 les unes sous les autres). Le reste de `assets/units/` est
   en bandes HORIZONTALES d une seule ligne. On les transpose.

Sortie : `assets/units/<id>_<anim>.png`, bande horizontale d une ligne, cases
carrees, comme les feuilles deja en place (blood_walk, chaosknight_walk...).
Les geometries reelles sont imprimees a la fin : c est ce qu il faut reporter
dans AnimCatalog (hors perimetre de ce script).
"""
import os
import zipfile

import numpy as np
from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")
Image.MAX_IMAGE_PIXELS = None

PACKS = "raw_assets/packs_2026_09_26"
OUT_UNITS = "assets/units"
OUT_FX = "assets/fx"

# ---------------------------------------------------------------------------
# Creatures a bandes HORIZONTALES deja decoupees par animation.
#   id: (archive, {anim: chemin interne}, taille de case)
# La case est VERIFIEE par probe_sheets.py, jamais devinee.
# ---------------------------------------------------------------------------
HORIZONTAL = {
    # luizmelo — Monsters_Creatures_Fantasy : 4 creatures, cases 150x150,
    # occupation 0,21-0,38 -> recadrage indispensable.
    "flyingeye": ("Monsters_Creatures_Fantasy.zip", {
        "walk": "Monsters_Creatures_Fantasy/Flying eye/Flight.png",
        "attack": "Monsters_Creatures_Fantasy/Flying eye/Attack.png",
        "hurt": "Monsters_Creatures_Fantasy/Flying eye/Take Hit.png",
        "death": "Monsters_Creatures_Fantasy/Flying eye/Death.png",
    }, 150),
    "goblin2": ("Monsters_Creatures_Fantasy.zip", {
        "idle": "Monsters_Creatures_Fantasy/Goblin/Idle.png",
        "walk": "Monsters_Creatures_Fantasy/Goblin/Run.png",
        "attack": "Monsters_Creatures_Fantasy/Goblin/Attack.png",
        "hurt": "Monsters_Creatures_Fantasy/Goblin/Take Hit.png",
        "death": "Monsters_Creatures_Fantasy/Goblin/Death.png",
    }, 150),
    "mushroom": ("Monsters_Creatures_Fantasy.zip", {
        "idle": "Monsters_Creatures_Fantasy/Mushroom/Idle.png",
        "walk": "Monsters_Creatures_Fantasy/Mushroom/Run.png",
        "attack": "Monsters_Creatures_Fantasy/Mushroom/Attack.png",
        "hurt": "Monsters_Creatures_Fantasy/Mushroom/Take Hit.png",
        "death": "Monsters_Creatures_Fantasy/Mushroom/Death.png",
    }, 150),
    "skeleton2": ("Monsters_Creatures_Fantasy.zip", {
        "idle": "Monsters_Creatures_Fantasy/Skeleton/Idle.png",
        "walk": "Monsters_Creatures_Fantasy/Skeleton/Walk.png",
        "attack": "Monsters_Creatures_Fantasy/Skeleton/Attack.png",
        "hurt": "Monsters_Creatures_Fantasy/Skeleton/Take Hit.png",
        "death": "Monsters_Creatures_Fantasy/Skeleton/Death.png",
        # 'Shield' est une parade : elle sert au comportement 'bouclier'.
        "shield": "Monsters_Creatures_Fantasy/Skeleton/Shield.png",
    }, 150),

    # luizmelo — Evil Wizard : le seul ENNEMI lanceur de sorts humanoide du lot.
    "evilwizard": ("Evil Wizard.zip", {
        "idle": "Evil Wizard/Sprites/Idle.png",
        "walk": "Evil Wizard/Sprites/Move.png",
        "attack": "Evil Wizard/Sprites/Attack.png",
        "hurt": "Evil Wizard/Sprites/Take Hit.png",
        "death": "Evil Wizard/Sprites/Death.png",
    }, 150),

    # luizmelo — Fire Worm : cases 90x90 deja bien remplies (0,48-0,60).
    "fireworm": ("Fire Worm.zip", {
        "idle": "Fire Worm/Sprites/Worm/Idle.png",
        "walk": "Fire Worm/Sprites/Worm/Walk.png",
        "attack": "Fire Worm/Sprites/Worm/Attack.png",
        "hurt": "Fire Worm/Sprites/Worm/Get Hit.png",
        "death": "Fire Worm/Sprites/Worm/Death.png",
    }, 90),

    # elesrech — Ghoul : cases 80x80, occupation 0,24-0,31 -> recadrage.
    "ghoul": ("Ghoul_Enemy_Pixel_Monsters_Vol_4.zip", {
        "idle": "Ghoul_Enemy_Pixel_Monsters_Vol_4/spritesheets/idle.png",
        "walk": "Ghoul_Enemy_Pixel_Monsters_Vol_4/spritesheets/walk.png",
        "attack": "Ghoul_Enemy_Pixel_Monsters_Vol_4/spritesheets/attack.png",
        "hurt": "Ghoul_Enemy_Pixel_Monsters_Vol_4/spritesheets/hurt.png",
        "death": "Ghoul_Enemy_Pixel_Monsters_Vol_4/spritesheets/death.png",
    }, 80),

    # craftpix — Gorgon : 3 variantes de teinte, cases 128x128 bien remplies.
    # On ne prend que Gorgon_1 : les deux autres sont la MEME silhouette
    # recoloree, et EnemyDef sait deja teinter un sprite.
    "gorgon": ("free-gorgon-pixel-art-character-sprite-sheets.zip", {
        "idle": "Gorgon_1/Idle.png",
        "walk": "Gorgon_1/Walk.png",
        "attack": "Gorgon_1/Attack_1.png",
        "hurt": "Gorgon_1/Hurt.png",
        "death": "Gorgon_1/Dead.png",
    }, 128),

    # creativekind — Mage Guardian : 14 frames de 64x64 sur UNE ligne, toutes
    # animations confondues. Traite a part (voir GUARDIAN_SLICES).

    # darkpixel — Undead executioner : traite dans FLAT_GRIDS, ses feuilles
    # sont des grilles de 100x100 sur PLUSIEURS lignes (400x200, 600x200,
    # 1000x200...). Lues comme une ligne unique de 200 px, deux poses
    # differentes se retrouvaient empilees dans la meme case.
}

# ---------------------------------------------------------------------------
# Feuilles a lire comme une GRILLE de cases uniformes, aplaties en une bande
# dans l ordre de lecture (gauche a droite, ligne par ligne).
#   id: (archive, {anim: chemin}, case)
# ---------------------------------------------------------------------------
FLAT_GRIDS = {
    # darkpixel — Undead executioner : toutes ses feuilles sont en 100x100.
    # 'idle.png' (500x100) est ecartee au profit de 'idle2.png', plus ample ;
    # 'attacking.png' l est aussi, sa 3e ligne n est remplie qu a 1 case sur 6
    # (reste d un montage), ce qui donnerait des frames vides en fin d animation.
    "executioner": ("Undead executioner.zip", {
        "idle": "Undead executioner puppet/png/idle2.png",
        "attack": "Undead executioner puppet/png/skill1.png",
        "death": "Undead executioner puppet/png/death.png",
        "summon": "Undead executioner puppet/png/summon.png",
    }, 100),
}

# ---------------------------------------------------------------------------
# Feuilles empilees VERTICALEMENT : a transposer en bande horizontale.
#   id: (archive, {anim: (chemin, hauteur de frame, decalage du premier frame)})
#
# Le DECALAGE n est pas un detail : sur Small Monster, le pas est bien de 39 px
# mais la premiere frame commence a la ligne 6. Decoupe a partir de 0, chaque
# creature se retrouvait coupee en deux — une tete volante au-dessus d un corps
# appartenant a la frame suivante. Le decalage est LU sur les blocs de lignes
# occupees, jamais suppose.
# ---------------------------------------------------------------------------
VERTICAL = {
    # 9e0 — Blue Witch : 32 px de large, frames de 48 px empilees (le pas est
    # LU sur les bandes de lignes entierement transparentes : 42-52, 90-102,
    # 138-149... soit une periode de 48). 'B_witch_attack.png' est ECARTEE :
    # elle fait 104 px de large, donc 2 colonnes, et ne suit pas la meme regle.
    # 'charge' sert d attaque : c est la pose d incantation de la sorciere.
    "bluewitch": ("Blue Witch.zip", {
        "idle": ("Blue_witch/B_witch_idle.png", 48),
        "walk": ("Blue_witch/B_witch_run.png", 48),
        "attack": ("Blue_witch/B_witch_charge.png", 48),
        "hurt": ("Blue_witch/B_witch_take_damage.png", 48),
        "death": ("Blue_witch/B_witch_death.png", 48),
    }),
    # Small Monster : 82 px de large, frames de 39 px empilees (pas lu de la
    # meme facon : bandes vides a 37-45, 76-83, 115-120...). 234/39 = 6 frames.
    "smallmonster": ("Small Monster.zip", {
        "idle": ("Small Monster/small moidle.png", 39),
        "walk": ("Small Monster/small morun.png", 39),
        "attack": ("Small Monster/attack.png", 39),
        "death": ("Small Monster/small modeath and damagedt.png", 39),
    }),
}

# ---------------------------------------------------------------------------
# Grandes planches a decouper en LIGNES, une ligne par animation.
#   id: (archive, chemin, case_w, case_h, [(anim, ligne, nb_frames)])
# ---------------------------------------------------------------------------
GRIDS = {
    # chierit — boss_demon_slime : 6336x800 = 22 colonnes x 5 lignes de 288x160
    # (la taille de case est ECRITE dans le nom du fichier, et le comptage des
    # cases pleines par ligne redonne exactement les dossiers 01..05 du pack :
    # 6 idle, 12 walk, 15 cleave, 5 take_hit, 22 death).
    "demonslime": ("boss_demon_slime_FREE_v1.0.zip",
                   "boss_demon_slime_FREE_v1.0/spritesheets/"
                   "demon_slime_FREE_v1.0_288x160_spritesheet.png",
                   288, 160,
                   [("idle", 0, 6), ("walk", 1, 12), ("attack", 2, 15),
                    ("hurt", 3, 5), ("death", 4, 22)]),

    # creativekind — NightBorne : 1840x400 = 23 colonnes x 5 lignes de 80x80.
    # Les GIF du pack donnent l ordre des lignes : idle, run, attack, hurt, death.
    # Le comptage des cases pleines colle (9 / 6 / 12 / 5 / 23).
    "nightborne": ("NightBorne.zip", "NightBorne.png", 80, 80,
                   [("idle", 0, 9), ("walk", 1, 6), ("attack", 2, 12),
                    ("hurt", 3, 5), ("death", 4, 23)]),
}

# creativekind — Mage Guardian : une seule bande de 14 frames de 64x64 qui
# enchaine toutes les poses. Les bornes viennent du visionnage frame par frame
# de la GIF fournie dans le pack.
GUARDIAN_SLICES = [("idle", 0, 4), ("attack", 4, 6), ("death", 10, 4)]

# ---------------------------------------------------------------------------
# Effets. Le jeu n a pas d effet SOMBRE : les sorts d ombre reutilisent
# aujourd hui une teinte violette d un effet de feu. Dark VFX comble ce trou.
#
# ATTENTION : ces sources sont des GRILLES multi-lignes (Pipoya : 5 colonnes x
# 3 lignes de 192 px, lues ligne par ligne). `Fx.STRIPS` ne lit qu UNE ligne :
# on APLATIT donc la grille en une seule bande horizontale, dans l ordre de
# lecture. Extraire la premiere ligne seule donnerait un effet tronque au tiers.
#   nom: (archive, chemin, case_w, case_h)
# ---------------------------------------------------------------------------
FX_SHEETS = {
    "dark_swirl": ("Dark VFX 01 - 02.rar",
                   "Dark VFX 2/Dark VFX 2 (48x64).png", 48, 64),
    "timemagic": ("Pipoya VFX TimeMagic.zip",
                  "Pipoya VFX TimeMagic/192x192/pipo-btleffect209_192.png", 192, 192),
    "lightpillar": ("Pipoya VFX LightPillar.zip",
                    "Pipoya VFX LightPillar/192x192/pipo-mapeffect013a.png", 192, 192),
    "bell": ("PIPOYA FREE VFX Bell.zip",
             "PIPOYA FREE VFX Bell/192x192/pipo-btleffect217_192.png", 192, 192),
}

# `Dark VFX 1` (400x64) n est PAS une animation de 16 frames : ses DEUX lignes
# sont deux effets differents, vu a la relecture de la planche de contact — une
# ame volante violette en haut (10 frames), un fantome blanc qui se dissout en
# bas (6 frames). Aplaties ensemble, le sort changeait de sujet en cours de
# route. On les separe donc explicitement, une ligne = un effet.
#   nom: (archive, chemin, case_w, case_h, ligne, nb_frames)
FX_ROWS = {
    "dark_soul": ("Dark VFX 01 - 02.rar",
                  "Dark VFX 1/Dark VFX 1 (40x32).png", 40, 32, 0, 10),
    "dark_vanish": ("Dark VFX 01 - 02.rar",
                    "Dark VFX 1/Dark VFX 1 (40x32).png", 40, 32, 1, 6),
}


# ---------------------------------------------------------------------------


def read_member(archive, member):
    """Lit un membre d archive (zip ou rar via 7-Zip) en Image RGBA."""
    path = os.path.join(PACKS, archive)
    if archive.lower().endswith(".rar"):
        import io
        import subprocess
        seven = r"C:\Program Files\7-Zip\7z.exe"
        out = subprocess.run([seven, "x", "-so", path, member],
                             capture_output=True, check=True)
        return Image.open(io.BytesIO(out.stdout)).convert("RGBA")
    with zipfile.ZipFile(path) as z:
        names = {n.replace("\\", "/"): n for n in z.namelist()}
        key = member.replace("\\", "/")
        if key not in names:
            raise KeyError("%s absent de %s" % (member, archive))
        with z.open(names[key]) as fp:
            return Image.open(fp).convert("RGBA")


def opaque_bbox(img):
    """(x0, y0, x1, y1) de la zone non transparente, ou None."""
    alpha = np.array(img)[:, :, 3] > 24
    ys, xs = np.where(alpha)
    if not len(xs):
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def common_crop(frames, cell_w, cell_h):
    """Marges a retirer, COMMUNES a toutes les frames de la creature.

    Un recadrage par animation desalignerait les poses entre elles (le monstre
    sauterait en passant de marche a attaque). On prend donc l enveloppe de
    toutes les bbox, exprimee en marges depuis le bord de la case.
    """
    left = top = 10 ** 9
    right = bottom = 10 ** 9
    for img in frames:
        box = opaque_bbox(img)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        left = min(left, x0)
        top = min(top, y0)
        right = min(right, cell_w - x1)
        bottom = min(bottom, cell_h - y1)
    if left > 10 ** 8:
        return 0, 0, 0, 0
    return max(0, left), max(0, top), max(0, right), max(0, bottom)


def slice_row(sheet, cell_w, cell_h, row=0, start=0, count=None, step_x=None):
    """Frames d une ligne de la planche."""
    step_x = step_x or cell_w
    if count is None:
        count = sheet.width // step_x
    out = []
    for i in range(start, start + count):
        x = i * step_x
        if x + cell_w > sheet.width:
            break
        out.append(sheet.crop((x, row * cell_h, x + cell_w, (row + 1) * cell_h)))
    return out


def write_strip(name, frames, crop=(0, 0, 0, 0), square=True):
    """Ecrit une bande horizontale d une ligne, cases carrees si demande."""
    if not frames:
        raise ValueError("%s : aucune frame" % name)
    left, top, right, bottom = crop
    cw = frames[0].width - left - right
    ch = frames[0].height - top - bottom
    pad_x = pad_y = 0
    if square:
        # AnimCatalog raisonne mieux sur des cases carrees : on egalise sur le
        # plus grand cote, en AJOUTANT du vide autour du contenu deja recadre.
        # On ne reprend SURTOUT PAS de pixels dans la feuille source pour
        # combler : sur une feuille empilee verticalement (Small Monster, cases
        # de 82x39), elargir la case a 82 de haut ferait entrer la frame du
        # dessous, et le monstre apparaissait en double.
        side = max(cw, ch)
        pad_x = (side - cw) // 2
        pad_y = (side - ch) // 2
        out_w, out_h = side, side
    else:
        out_w, out_h = cw, ch
    out = Image.new("RGBA", (out_w * len(frames), out_h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        cut = fr.crop((left, top, fr.width - right, fr.height - bottom))
        out.paste(cut, (i * out_w + pad_x, pad_y))
    cw = out_w
    path = os.path.join(OUT_UNITS if name[0] != "@" else OUT_FX,
                        name.lstrip("@") + ".png")
    out.save(path)
    return path, cw, len(frames)


def occupancy(path, cell_w):
    """Part de la HAUTEUR de case reellement occupee (cf. measure_occupancy)."""
    img = Image.open(path).convert("RGBA")
    alpha = np.array(img)[:, :, 3] > 24
    h, w = alpha.shape
    best = 0
    for col in range(max(1, w // cell_w)):
        cell = alpha[:, col * cell_w:(col + 1) * cell_w]
        ys, _ = np.where(cell)
        if len(ys):
            best = max(best, ys.max() - ys.min() + 1)
    return round(best / h, 3) if h else 0.0


def main():
    os.makedirs(OUT_UNITS, exist_ok=True)
    os.makedirs(OUT_FX, exist_ok=True)
    report = []

    # --- bandes horizontales, recadrage commun ---------------------------
    for unit, (archive, anims, cell) in HORIZONTAL.items():
        sheets = {a: read_member(archive, p) for a, p in anims.items()}
        allframes = []
        per_anim = {}
        for anim, sheet in sheets.items():
            frames = slice_row(sheet, cell, sheet.height)
            per_anim[anim] = frames
            allframes.extend(frames)
        crop = common_crop(allframes, cell, sheets[list(sheets)[0]].height)
        for anim, frames in per_anim.items():
            path, cw, n = write_strip("%s_%s" % (unit, anim), frames, crop)
            report.append((os.path.basename(path), cw, n, occupancy(path, cw)))

    # --- feuilles verticales, transposees -------------------------------
    for unit, (archive, anims) in VERTICAL.items():
        sheets = {}
        for anim, (member, fh) in anims.items():
            img = read_member(archive, member)
            frames = [img.crop((0, i * fh, img.width, (i + 1) * fh))
                      for i in range(img.height // fh)]
            # Une frame entierement vide n est pas une pose : Blue Witch termine
            # certaines de ses bandes sur du vide.
            frames = [f for f in frames if opaque_bbox(f) is not None]
            sheets[anim] = frames
        flat = [f for frames in sheets.values() for f in frames]
        w = flat[0].width
        h = flat[0].height
        crop = common_crop(flat, w, h)
        for anim, frames in sheets.items():
            path, cw, n = write_strip("%s_%s" % (unit, anim), frames, crop)
            report.append((os.path.basename(path), cw, n, occupancy(path, cw)))

    # --- grilles uniformes, aplaties en une bande -----------------------
    for unit, (archive, anims, cell) in FLAT_GRIDS.items():
        per_anim = {}
        allframes = []
        for anim, member in anims.items():
            sheet = read_member(archive, member)
            frames = []
            for row in range(sheet.height // cell):
                for fr in slice_row(sheet, cell, cell, row=row):
                    if opaque_bbox(fr) is not None:
                        frames.append(fr)
            per_anim[anim] = frames
            allframes.extend(frames)
        crop = common_crop(allframes, cell, cell)
        for anim, frames in per_anim.items():
            path, w, n = write_strip("%s_%s" % (unit, anim), frames, crop)
            report.append((os.path.basename(path), w, n, occupancy(path, w)))

    # --- grandes planches, une ligne par animation ----------------------
    for unit, (archive, member, cw, ch, rows) in GRIDS.items():
        sheet = read_member(archive, member)
        per_anim = {}
        allframes = []
        for anim, row, count in rows:
            frames = slice_row(sheet, cw, ch, row=row, count=count)
            per_anim[anim] = frames
            allframes.extend(frames)
        crop = common_crop(allframes, cw, ch)
        for anim, frames in per_anim.items():
            path, w, n = write_strip("%s_%s" % (unit, anim), frames, crop)
            report.append((os.path.basename(path), w, n, occupancy(path, w)))

    # --- Mage Guardian : une bande, plusieurs poses ---------------------
    guard = read_member("mage_guardian_free_creativekind.zip",
                        "mage_guardian-blue.png")
    allframes = slice_row(guard, 64, 64)
    crop = common_crop(allframes, 64, 64)
    for anim, start, count in GUARDIAN_SLICES:
        path, w, n = write_strip("mageguardian_%s" % anim,
                                 allframes[start:start + count], crop)
        report.append((os.path.basename(path), w, n, occupancy(path, w)))

    # --- effets ----------------------------------------------------------
    for name, (archive, member, cw, ch) in FX_SHEETS.items():
        sheet = read_member(archive, member)
        frames = []
        for row in range(sheet.height // ch):
            for fr in slice_row(sheet, cw, ch, row=row):
                # Une case entierement vide est la fin de l animation, pas une
                # frame : Dark VFX 1 finit sur 4 cases vides de sa 2e ligne.
                if opaque_bbox(fr) is not None:
                    frames.append(fr)
        # Les effets NE SONT PAS recadres : Fx.OCC compense l espace vide, et
        # recadrer decalerait le centre de l effet par rapport au point de
        # lancement du sort.
        path, w, n = write_strip("@" + name, frames, square=False)
        report.append((os.path.basename(path), w, n, occupancy(path, w)))

    # --- effets dont on ne prend QU UNE ligne ---------------------------
    for name, (archive, member, cw, ch, row, count) in FX_ROWS.items():
        sheet = read_member(archive, member)
        frames = slice_row(sheet, cw, ch, row=row, count=count)
        path, w, n = write_strip("@" + name, frames, square=False)
        report.append((os.path.basename(path), w, n, occupancy(path, w)))

    print("%-34s %6s %6s %6s" % ("feuille", "frame", "n", "occ_h"))
    for name, cw, n, occ in sorted(report):
        print("%-34s %6d %6d %6.2f" % (name, cw, n, occ))
    print("\n%d feuilles ecrites." % len(report))


if __name__ == "__main__":
    main()
