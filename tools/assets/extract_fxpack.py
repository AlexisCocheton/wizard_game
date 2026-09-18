# -*- coding: utf-8 -*-
"""Extrait, effet par effet, les feuilles retenues du pack "Effect and FX Pixel
All Free" (raw_assets/), plus les sons de sorts (FreeSFX, 400 Sounds Pack), et
regenere les entrees correspondantes de Fx.STRIPS et Fx.OCC.

POURQUOI ce script
------------------
Retour du testeur : "beaucoup trop de sorts utilisent les memes animations et les
memes icones". Les effets etaient choisis par ELEMENT : tous les sorts de feu
explosaient pareil, et l icone derive de la feuille. L AUDIT exige desormais UNE
feuille PROPRE par carte non passive (jamais partagee). Il faut donc ~45 feuilles
distinctes : ce pack en offre 180.

FORMAT DU PACK (verifie sur les 180 PNG)
----------------------------------------
Chaque PNG est une grille de cases de 64x64, 9 LIGNES x 5 a 23 COLONNES
(largeur 320 a 1472 px, hauteur toujours 576). Chaque LIGNE est l animation
complete ; les 9 lignes sont 9 TEINTES du meme effet :

    0 rouge-orange   3 vert            6 brun-mauve (terne)
    1 violet         4 orange/brun     7 rouge
    2 bleu           5 blanc/gris      8 bleu-violet (sombre)

On n extrait qu UNE ligne par effet, la teinte de l element du sort : les
feuilles sont livrees deja colorees, Fx.sprite() ne les teinte plus.

PIEGES
------
- La PREMIERE image de chaque ligne est une amorce presque vide (4 a 200 pixels
  opaques) : l effet grossit au fil de la ligne. Une icone prise sur la case 0
  serait un point. CardIcons prend la case du MILIEU ; ici on garde toute la
  ligne pour que l animation demarre en douceur.
- Tout extraire (180 PNG) ferait grossir l etape --import du harnais pour des
  fichiers jamais joues : la TABLE ci-dessous est la seule source, et chaque
  entree sert a une carte (ou est un rechange nomme).
- Le GIF d apercu du pack tourne a 60 ms/image : 16 fps est la vitesse voulue
  par l auteur, on la garde pour toutes les bandes.
- Aucun fichier de licence dans le zip : verifier les conditions du pack
  (itch.io) avant publication.

SORTIE
------
assets/fx/<nom>.png : BANDE horizontale d une seule ligne (cases 64x64, colonnes
vides de fin retirees), lisible par Fx.STRIPS sans cas particulier. Les entrees
STRIPS sont ecrites entre deux marqueurs dans scripts/game/fx.gd ; OCC est
regenere par tools/assets/measure_occupancy.py (seule source de verite pour
l occupation, on ne la recalcule pas ici).

Usage : python tools/assets/extract_fxpack.py
"""
import io
import os
import re
import sys
import zipfile

import numpy as np
from PIL import Image

os.chdir(r"C:\Users\Lenovo\Desktop\wizard_game")
sys.path.insert(0, "tools/assets")
import measure_occupancy  # noqa: E402  (OCC est a lui)

PACK = "raw_assets/Effect and FX Pixel All Free.zip"
OUT_FX = "assets/fx"
OUT_SFX = "assets/sfx"
FX_GD = "scripts/game/fx.gd"
CELL = 64
FPS = 16
MARK_BEGIN = '\t## --- Pack "Effect and FX Pixel All Free" : genere par tools/assets/extract_fxpack.py ---\n'
MARK_END = "\t## --- fin du pack Effect and FX ---\n"

# nom -> (part, fichier, ligne). La ligne est la TEINTE (voir tableau en tete).
# Un nom par carte non passive, plus trois rechanges nommes (slash_arc,
# lightning_fork, flame_gust) pour la prochaine carte sans avoir a rouvrir le pack.
# CRITERE DE CHOIX : l icone de la carte est l image du MILIEU de la bande
# (CardIcons). Un effet dont le milieu est deja dissous (arcs fins, eclats
# epars) donne une icone illisible en main : on prefere un effet dense a
# mi-course, meme s il est moins spectaculaire sur le terrain.
TABLE = {
    # --- Communes ---
    "orb_burst": (9, "427", 1),      # arcane_bolt : orbe qui eclate, violet
    "pin_thrust": (5, "231", 5),     # piercing_arrow : estoc qui file, blanc
    "rune_square": (13, "623", 2),   # frost_field : rune carree qui tourne, bleu
    "ember_flames": (11, "527", 4),  # ember_pool : rangee de flammes basses, orange
    "fireball_hit": (8, "388", 0),   # fireball : trait, boule, anneau, rouge-orange
    "spark_burst": (2, "63", 1),     # spark : eclat bref, violet
    "crystal_field": (8, "398", 2),  # frost_rain : cristaux qui poussent au sol, bleu
    # --- Rares ---
    "ray_wheel": (14, "652", 1),     # quickening : roue de rayons, violet
    "clock_spiral": (15, "711", 2),  # temporal_drag : anneaux qui convergent, bleu
    "cycle_swirl": (4, "174", 1),    # cycle_of_thought : tourbillon a cinq bras, violet
    "wisp_rise": (13, "614", 8),     # mana_flow : volute qui monte, bleu-violet
    "stone_peak": (14, "665", 4),    # stone_wall : pic de pierre, brun
    "flame_pillar": (10, "464", 0),  # brazier : colonne de flamme en boucle
    "meteor_streak": (12, "578", 4), # meteor : comete en diagonale, orange
    "pinwheel_turn": (1, "13", 1),   # about_face : moulinet qui pivote, violet
    "star_focus": (5, "230", 1),     # focus : etoile a pointes, violet
    "spiral_salt": (12, "567", 5),   # salt_spiral : spirale, BLANCHE comme le sel
    "bone_shards": (14, "653", 5),   # bone_recall : eclats anguleux (os), blanc
    "shatter_burst": (3, "125", 5),  # chain_break : eclatement en fissures, blanc
    "ring_expand": (4, "187", 5),    # repulsion_wave : anneau qui s eloigne, blanc
    "halo_ring": (12, "586", 5),     # purifying_light : halo a rayons, blanc
    "sun_burst": (9, "436", 1),      # arcane_insight : soleil a tentacules, violet
    # --- Epiques ---
    "lotus_bloom": (14, "655", 3),   # mirror_apprentice : lotus qui s ouvre, vert
    "hex_sigil": (14, "674", 5),     # deep_focus : sceau hexagonal, blanc
    "lightning_web": (4, "195", 7),  # reckless_bargain : toile d eclairs, rouge
    "orb_shatter": (13, "612", 1),   # deck_purge : orbe qui se disloque, violet
    "frost_spikes": (3, "116", 2),   # deep_freeze : pointes de glace en croix, bleu
    "diamond_mark": (15, "703", 7),  # weakness_mark : losanges-sceaux, rouge
    "pulse_ring": (10, "475", 1),    # resonance : anneau a rayons qui s ouvre, violet
    "void_mandala": (4, "186", 8),   # void_grip : mandala qui se resorbe, sombre
    "spiral_pull": (6, "296", 1),    # maelstrom : huit lames en spirale, violet
    "dome_bastion": (11, "528", 5),  # bastion : dome qui se pose, blanc
    # --- Legendaires ---
    "orbit_cross": (15, "720", 1),   # time_rift : ellipses croisees, violet
    "glass_shards": (15, "700", 1),  # hourglass_shard : eclats de verre, violet
    "tide_waves": (3, "134", 2),     # tide_ledger : vagues qui roulent, bleu
    "hex_summon": (15, "712", 3),    # summoners_key : hexagones d appel, vert
    "fire_bloom": (2, "77", 4),      # forge_dial : boule qui s ouvre en anneau, orange
    "weave_bloom": (4, "185", 1),    # world_loom : petales tisses, violet
    "echo_rings": (1, "26", 1),      # echo_of_the_hand : anneaux en echo, violet
    "twin_flames": (2, "64", 1),     # twin_channeling : deux flammes jumelles, violet
    "magma_burst": (2, "79", 0),     # meteor_storm : masse en fusion qui eclate, rouge
    "skull_burst": (13, "633", 3),   # venom_mire : crane qui s eleve, vert poison
    # --- Rechanges (aucune carte) ---
    "slash_arc": (3, "123", 5),      # entaille en croissant
    "lightning_fork": (4, "196", 8), # eclair vertical
    "flame_gust": (1, "04", 4),       # souffle de flamme
}

# cle -> (archive, entree). Un son peut servir a 2 ou 3 cartes d une meme
# famille ; l AUDIT n exige l unicite que pour la feuille.
SOUNDS = {
    "spell_arcane": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic 06.wav"),
    "spell_deep": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic 11.wav"),
    "spell_rise": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic 34.wav"),
    "spell_grand": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic 54.wav"),
    "spell_crackle": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic Electric 03.wav"),
    "ward_light": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic Protection 01.wav"),
    "ward_deep": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Magic/Retro Magic Protection 25.wav"),
    "charge_magic": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Charge/Retro Charge Magic 11.wav"),
    "zap_short": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Electric/Retro Electric 02.wav"),
    "zap_long": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Electric/Retro Electric 21.wav"),
    "blast_short": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Explosion/Retro Explosion Short 01.wav"),
    "blast_pop": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Explosion/Retro Explosion Short 15.wav"),
    "blast_long": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Explosion/Retro Explosion Long 02.wav"),
    "impact_heavy": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Impact/Retro Impact 20.wav"),
    "arrow_laser": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Weapon/laser/Retro Weapon Laser 03.wav"),
    "drip_frost": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Water/Retro Water Drop 01.wav"),
    "wind_gust": ("raw_assets/FreeSFX.zip", "FreeSFX/GameSFX/Cinematic/Retro Cinematic Wind 02.wav"),
    "fire_ignite": ("raw_assets/400 Sounds Pack.zip", "Environment/fire_lighting.wav"),
    "whoosh_summon": ("raw_assets/400 Sounds Pack.zip", "Other/whoosh_1.wav"),
    "whoosh_deep": ("raw_assets/400 Sounds Pack.zip", "Other/whoosh_2.wav"),
    "stone_shove": ("raw_assets/400 Sounds Pack.zip", "Materials/stone_push_short.wav"),
}


def row_strip(image, row):
    """La ligne `row` de la grille, colonnes vides de FIN retirees.

    On ne retire que la fin : une case vide au milieu (ou l amorce du debut)
    fait partie du rythme de l animation.
    """
    alpha = np.array(image)[:, :, 3]
    cols = image.size[0] // CELL
    keep = 0
    for c in range(cols):
        cell = alpha[row * CELL:(row + 1) * CELL, c * CELL:(c + 1) * CELL]
        if (cell > 24).any():
            keep = c + 1
    if keep == 0:
        raise SystemExit("ligne %d entierement vide" % row)
    return image.crop((0, row * CELL, keep * CELL, (row + 1) * CELL)), keep


def extract_sheets():
    os.makedirs(OUT_FX, exist_ok=True)
    counts = {}
    with zipfile.ZipFile(PACK) as z:
        for name, (part, file, row) in TABLE.items():
            entry = "Free/Part %d/%s.png" % (part, file)
            with z.open(entry) as handle:
                src = Image.open(handle)
                src.load()
            src = src.convert("RGBA")
            if src.size[1] != 9 * CELL or src.size[0] % CELL:
                raise SystemExit("%s : geometrie inattendue %s" % (entry, src.size))
            strip, n = row_strip(src, row)
            path = os.path.join(OUT_FX, name + ".png")
            strip.save(path, optimize=True)
            counts[name] = n
            print("  %-16s Part %2d/%-3s ligne %d  %2d cases  (%d ko)"
                  % (name, part, file, row, n, os.path.getsize(path) // 1024))
    return counts


def write_strips(counts):
    """Reecrit le bloc entre marqueurs dans Fx.STRIPS (cree les marqueurs a la
    premiere execution, juste avant l accolade fermante de STRIPS)."""
    source = io.open(FX_GD, encoding="utf-8").read()
    block = MARK_BEGIN + "".join(
        '\t"%s": ["%s", %d, %d, %d],\n' % (name, name, CELL, CELL, FPS)
        for name in TABLE) + MARK_END
    if MARK_BEGIN in source:
        pattern = re.escape(MARK_BEGIN) + r".*?" + re.escape(MARK_END)
        source, n = re.subn(pattern, lambda _: block, source, count=1, flags=re.S)
        assert n == 1
    else:
        # Ancre : la fin du dictionnaire STRIPS, c est-a-dire le premier "\n}\n"
        # qui suit sa declaration. Borne, pas de DOTALL gourmand (voir assets.md).
        start = source.index("const STRIPS: Dictionary = {")
        end = source.index("\n}\n", start)
        source = source[:end + 1] + block + source[end + 1:]
    io.open(FX_GD, "w", encoding="utf-8", newline="\n").write(source)
    print("  Fx.STRIPS : %d entrees entre marqueurs" % len(counts))


def extract_sounds():
    os.makedirs(OUT_SFX, exist_ok=True)
    opened = {}
    for key, (archive, entry) in SOUNDS.items():
        if archive not in opened:
            opened[archive] = zipfile.ZipFile(archive)
        data = opened[archive].read(entry)
        path = os.path.join(OUT_SFX, key + ".wav")
        with open(path, "wb") as out:
            out.write(data)
        print("  %-14s <- %-45s (%d ko)" % (key, entry.split("/")[-1], len(data) // 1024))


def main():
    print("feuilles :")
    counts = extract_sheets()
    write_strips(counts)
    print("sons :")
    extract_sounds()
    print("occupation :")
    measure_occupancy.main()


if __name__ == "__main__":
    main()
