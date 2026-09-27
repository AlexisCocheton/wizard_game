# -*- coding: utf-8 -*-
"""Extrait les silhouettes demandees le 2026-09-27 : trio de mages, golem laser,
quatre slimes, renard, cacodemon, et une vraie boule de poison.

Meme regles que extract_packs_2026_09_26.py, dont on reprend les outils
(lecture d archive, recadrage COMMUN a toutes les poses d une creature, bandes
a cases carrees) : une feuille par animation UTILE, jamais un pack entier.

Toutes les geometries ci-dessous ont ete LUES sur les planches (planche-contact
agrandie, comptage des cases non vides), pas reprises d une page de pack.

Sortie : assets/units/<cle>_<anim>.png et assets/fx/<nom>.png. Les occupations
imprimees a la fin sont indicatives : c est measure_occupancy.py qui les ecrit
dans AnimCatalog / Fx.OCC.

Usage : python tools/assets/extract_bestiaire_2026_09_27.py
"""
import io
import os
import sys
import zipfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_packs_2026_09_26 as P  # noqa: E402  (fait aussi le chdir)

PACKS = P.PACKS
report = []


def note(path, w, n):
    report.append((os.path.basename(path), w, n, P.occupancy(path, w)))


def grid_rows(sheet, cw, ch, rows):
    """{anim: [frames]} pour une planche ou une LIGNE est une animation.
    rows = [(anim, ligne, nb)] ; nb None = toutes les cases non vides."""
    out = {}
    for anim, row, count in rows:
        frames = P.slice_row(sheet, cw, ch, row=row)
        frames = [f for f in frames if P.opaque_bbox(f) is not None]
        out[anim] = frames[:count] if count else frames
    return out


def write_unit(key, per_anim):
    """Recadrage commun a toutes les poses, puis une bande par animation."""
    allframes = [f for fr in per_anim.values() for f in fr]
    w, h = allframes[0].size
    crop = P.common_crop(allframes, w, h)
    for anim, frames in per_anim.items():
        path, cw, n = P.write_strip("%s_%s" % (key, anim), frames, crop)
        note(path, cw, n)


def open_loose(name):
    """PNG livre NU dans packs_2026_09_26 (pas d archive)."""
    return Image.open(os.path.join(PACKS, name)).convert("RGBA")


# ---------------------------------------------------------------------------
# 1. MAGES creativekind : rouge et magenta.
# Les trois couleurs ont EXACTEMENT la meme planche (896x64, 14 cases de 64,
# memes poses case a case, seul le joyau et la fumee changent). On reprend donc
# le decoupage deja etabli pour le bleu (GUARDIAN_SLICES, lu sur la GIF).
# ---------------------------------------------------------------------------
def mages():
    for color in ("red", "magenta"):
        sheet = P.read_member("mage_guardian_free_creativekind.zip",
                              "mage_guardian-%s.png" % color)
        frames = P.slice_row(sheet, 64, 64)
        write_unit("mageguardian_%s" % color,
                   {a: frames[s:s + n] for a, s, n in P.GUARDIAN_SLICES})


# ---------------------------------------------------------------------------
# 2. MECHA-STONE GOLEM (darkpixel-kronovi).
# Character_sheet.png = grille 10x10 de 100 px. L ordre des lignes est celui des
# ETIQUETTES du fichier flatten_character.aseprite du pack (lues dans le bloc
# 0x2018 du format) : idle 0-3, glow 4-11, shoot 12-20, immune 21-28,
# melee 29-35, laser_cast 36-42, sheild_cast 43-52, death 53-66 ; 100 ms par
# image, donc 10 fps. La mort deborde sur la ligne suivante (10 + 4 cases).
# PAS de marche ni de degats dans le pack : le golem respire sur place
# (Enemy.resting_anim retombe sur idle), comme le Bourreau.
# ---------------------------------------------------------------------------
GOLEM = "Mecha-stone Golem 0.1.zip"
GOLEM_DIR = "Mecha-stone Golem 0.1/"


def golem():
    sheet = P.read_member(GOLEM, GOLEM_DIR + "PNG sheet/Character_sheet.png")
    per = grid_rows(sheet, 100, 100, [
        ("idle", 0, 4), ("glow", 1, 8), ("shoot", 2, 9), ("guard", 3, 8),
        ("attack", 4, 7), ("laser", 5, 7), ("shield", 6, 10), ("death", 7, 10)])
    per["death"] += grid_rows(sheet, 100, 100, [("d", 8, 4)])["d"]
    write_unit("mechagolem", per)

    # Rayon : 15 cases de 300x100 EMPILEES ; la premiere est vide (le .ase n a
    # que 14 images). 8 images de charge (point lumineux), puis 6 de rayon
    # plein. Le rayon part de x=50 et file jusqu au bord DROIT de la case :
    # l origine n est pas au centre, a compenser par qui le joue.
    laser = P.read_member(GOLEM, GOLEM_DIR + "weapon PNG/Laser_sheet.png")
    frames = [laser.crop((0, i * 100, 300, (i + 1) * 100)) for i in range(15)]
    frames = [f for f in frames if P.opaque_bbox(f) is not None]
    path, w, n = P.write_strip("@mecha_laser", frames, square=False)
    note(path, w, n)

    # Poing projete : grille 3x3 de 100 px, 6 cases pleines, pointe vers la DROITE.
    arm = P.read_member(GOLEM, GOLEM_DIR + "weapon PNG/arm_projectile_glowing.png")
    frames = []
    for row in range(3):
        frames += [f for f in P.slice_row(arm, 100, 100, row=row)
                   if P.opaque_bbox(f) is not None]
    path, w, n = P.write_strip("@mecha_fist", frames, square=False)
    note(path, w, n)


# ---------------------------------------------------------------------------
# 3. SLIMES.
#
# Slime.zip : feuille + dossier "Individual Sprites" nommes slime-<anim>-<n>.png,
# exactement la convention des packs rvros ("Animated Pixel Slime"). Aucun
# fichier de licence dans l archive. On lit les images UNITAIRES, qui donnent
# l ordre et le nombre sans ambiguite (idle 4, move 4, attack 5, hurt 4, die 4).
#
# free-slime-mobs (craftpix, License.txt = licence craftpix) : 3 slimes vus de
# dessus, chaque planche = 4 LIGNES de directions x N cases de 64 px. La ligne
# 0 est la FACE (les yeux sont visibles), celle d un monstre qui descend vers
# le mage — meme choix que pour le paon. Slime1 = gelee verte, Slime2 = gelee
# bleue a tete de mort et os en travers (un vrai SQUELETTE de slime), Slime3 =
# boule de lave dont l attaque fait jaillir des geysers.
# ---------------------------------------------------------------------------
MOBS = "free-slime-mobs-pixel-art-top-down-sprite-pack.zip"
MOB_ANIMS = [("idle", "Idle"), ("walk", "Walk"), ("attack", "Attack"),
             ("hurt", "Hurt"), ("death", "Death")]


def mob_front(n, layer="full"):
    per = {}
    for anim, folder in MOB_ANIMS:
        sheet = P.read_member(MOBS, "PNG/Slime%d/%s/Slime%d_%s_%s.png"
                              % (n, folder, n, folder, layer))
        per[anim] = grid_rows(sheet, 64, 64, [("x", 0, None)])["x"]
    return per


def spectral(img):
    """Fantome : la gelee verte passee en bleu pale translucide.

    Remplacement de couleur par la LUMINANCE, pas un modulate (un modulate
    multiplie : sur du vert il donne un vert sombre, jamais un blanc bleute).
    Les ombres de la gelee restent plus sombres que ses reflets, donc le volume
    se lit toujours. Alpha a 62 % : on doit voir le sol a travers.
    Licence craftpix : la modification est permise, seule la revente des
    sources est interdite.
    """
    a = np.array(img).astype(np.float32)
    lum = (0.299 * a[:, :, 0] + 0.587 * a[:, :, 1] + 0.114 * a[:, :, 2]) / 255.0
    lum = np.clip((lum - 0.15) / 0.65, 0.0, 1.0)[:, :, None]
    dark = np.array([60, 78, 128], np.float32)
    light = np.array([228, 242, 255], np.float32)
    rgb = dark + (light - dark) * lum
    out = np.dstack([rgb, a[:, :, 3] * 0.62]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def slimes():
    # ENORME (mini-boss) : le slime rvros, vue de COTE, masse pleine.
    with zipfile.ZipFile(os.path.join(PACKS, "Slime.zip")) as z:
        def seq(name, count):
            return [Image.open(io.BytesIO(z.read(
                "Individual Sprites/slime-%s-%d.png" % (name, i)))).convert("RGBA")
                for i in range(count)]
        write_unit("slime_big", {
            "idle": seq("idle", 4), "walk": seq("move", 4),
            "attack": seq("attack", 5), "hurt": seq("hurt", 4),
            "death": seq("die", 4)})

    # COLOSSAL (boss) : la boule de lave craftpix.
    write_unit("slime_colossal", mob_front(3))
    # SQUELETTE : vrai sprite (Slime2).
    write_unit("slime_skeleton", mob_front(2))
    # FANTOME : Slime1 sans son ombre portee (un fantome flotte), recolore.
    ghost = mob_front(1, layer="body")
    write_unit("slime_ghost", {a: [spectral(f) for f in fr] for a, fr in ghost.items()})


# ---------------------------------------------------------------------------
# 4. elthen, PNG livres NUS (licence a confirmer, voir docs/assets_index.md).
# Renard : grille 14x7 de 32 px. Lignes lues sur la planche : 0 repos (5),
# 1 regarde autour (14), 2 course (8), 3 bond (11), 4 sursaut/degats (5),
# 5 SOMMEIL roule en boule (6, boucle), 6 mort (7).
# Cacodemon : grille 8x4 de 64 px : 0 vol (6), 1 morsure (6), 2 degats (4),
# 3 mort (8).
# ---------------------------------------------------------------------------
def elthen():
    fox = open_loose("Fox Sprite Sheet.png")
    write_unit("fox", grid_rows(fox, 32, 32, [
        ("idle", 0, 5), ("walk", 2, 8), ("attack", 3, 11), ("hurt", 4, 5),
        ("sleep", 5, 6), ("death", 6, 7)]))
    caco = open_loose("Cacodaemon Sprite Sheet.png")
    write_unit("cacodaemon", grid_rows(caco, 64, 64, [
        ("walk", 0, 6), ("attack", 1, 6), ("hurt", 2, 4), ("death", 3, 8)]))


# ---------------------------------------------------------------------------
# 5. BOULE DE POISON : planche 428 du pack "Effect and FX Pixel All Free",
# ligne 3 (la teinte VERTE du pack, cf. extract_fxpack.py). Cases 64 px, 10
# images : 0-3 une masse de venin dense qui ondule, 4-9 elle eclate en gouttes.
# Le vol est l aller-retour 0-1-2-3-2-1 (une boucle sans saut), la mort 4-9.
# Planche non utilisee par une carte (verifie dans extract_fxpack.TABLE).
# ---------------------------------------------------------------------------
def poison():
    with zipfile.ZipFile("raw_assets/Effect and FX Pixel All Free.zip") as z:
        member = [n for n in z.namelist()
                  if n.endswith("/428.png") and "__MACOSX" not in n][0]
        sheet = Image.open(io.BytesIO(z.read(member))).convert("RGBA")
    frames = P.slice_row(sheet, 64, 64, row=3)
    write_unit("poison_ball", {
        "walk": [frames[i] for i in (0, 1, 2, 3, 2, 1)],
        "death": frames[4:10]})


# ---------------------------------------------------------------------------
# 6. SEIGNEUR DEMON : Lords Of Pain est ECARTE, pour deux raisons verifiees.
#   - La demo NE CONTIENT PAS de seigneur demon : son "Asset Index (DEMO).txt"
#     liste un guerrier et un squelette ; le "Demonlord" n est que dans la
#     version payante (Asset Index (FULL).txt).
#   - Le style ne raccorde pas : rendu 3D pre-calcule, bords anti-crenneles
#     (254 niveaux d alpha), ombre portee cuite dans l image, personnage de
#     38 px dans une case de 256. Pose en capture a taille de boss a cote de
#     Chronos, le squelette de face devient une tache grise floue, presque
#     invisible sur le fond de l acte III.
# A la place : boss_malyk du pack Duelyst (CC0, deja utilise pour 5 boss),
# demon cornu en armure, main gauche en flamme — lu en capture comme un
# seigneur. On reprend les outils de extract_duelyst.py.
# ---------------------------------------------------------------------------
def demonlord():
    import extract_duelyst as D
    t, names, assets = D.load_package(D.PKG)
    by_png = {names[g].split("/")[-1][:-4]: g for g in names
              if names[g].endswith(".png") and "/Spritesheets/Units/" in names[g]}
    by_plist = {names[g].split("/")[-1][:-6]: g for g in names
                if names[g].endswith(".plist")}
    unit = "boss_malyk"
    atlas = Image.open(io.BytesIO(
        t.extractfile(assets[by_png[unit]]).read())).convert("RGBA")
    plist = t.extractfile(assets[by_plist[unit]]).read().decode("utf-8", "replace")
    for src, dst in (("run", "walk"), ("breathing", "idle"), ("hit", "hurt"),
                     ("attack", "attack"), ("death", "death")):
        fr = D.frames_of(plist, unit, src)
        cw = max(f[3] for f in fr)
        ch = max(f[4] for f in fr)
        sheet = Image.new("RGBA", (cw * len(fr), ch), (0, 0, 0, 0))
        for i, (_, x, y, w, h) in enumerate(fr):
            # Case centree, posee sur le bas, comme extract_duelyst.
            sheet.paste(atlas.crop((x, y, x + w, y + h)), (i * cw + (cw - w) // 2, ch - h))
        path = os.path.join(P.OUT_UNITS, "demonlord_%s.png" % dst)
        sheet.save(path)
        note(path, cw, len(fr))


def main():
    mages()
    golem()
    slimes()
    elthen()
    poison()
    demonlord()
    print("%-34s %6s %6s %6s" % ("feuille", "frame", "n", "occ_h"))
    for name, cw, n, occ in sorted(report):
        print("%-34s %6d %6d %6.2f" % (name, cw, n, occ))
    print("\n%d feuilles ecrites." % len(report))


if __name__ == "__main__":
    main()
