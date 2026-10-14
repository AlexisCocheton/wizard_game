# -*- coding: utf-8 -*-
"""Sons et musiques de la vague 10 (revue globale, chantier A4).

POURQUOI
--------
La revue de la vague 10 a releve que le son etait reste au niveau du premier
prototype alors que l image avait ete refaite deux fois :
  - toute mort de monstre faisait le meme `enemy_die`, tout coup le meme `hit` ;
  - les objets de terrain sonnaient tous `wall` ;
  - les mecaniques de boss reutilisaient `shield_break` cinq fois (et
    `shield_break` est le MEME fichier que `ward_deep`) ;
  - 21 sons pour 53 sorts, dont des sorts de glace sur un gresillement
    electrique (`zap_short`) ;
  - une seule musique de combat pour 21 niveaux.

Ce script n ecrit que des fichiers NEUFS dans assets/sfx et assets/music, tous
tires des packs deja audites (docs/assets_index.md) : 400 Sounds Pack (Chequered
Ink), FreeSFX, 28 High Quality 16-bit RPG Music (HydroGene, credit non
obligatoire), xDeviruchi (credit OBLIGATOIRE, deja a l ecran). Rien de Batareya.

TRAITEMENT DES SONS (une passe par fichier)
--------------------------------------------
- mono 16 bits a 44,1 kHz : un bruitage n a pas besoin de stereo, et le poids
  est divise par deux ;
- silence de tete retire (un son qui demarre 80 ms apres le coup sonne en
  retard) ;
- duree BORNEE avec un fondu de sortie : plusieurs sources durent 3 a 7 s, ce
  qui, repete a chaque mort, devient une nappe continue — exactement le « rien
  d agressif en boucle » demande ;
- certains sons sont INVERSES (le retour dans le temps de l Horloger est une
  horloge jouee a l envers) ou MELANGES (un tic d horloge sous une montee
  magique pour les sorts de temps) ;
- crete ramenee a -1 dBFS. Le volume PERCU, lui, se regle a la lecture : voir
  plus bas.

VOLUMES COHERENTS
-----------------
Les fichiers du jeu allaient de -5,6 dB (zap_long) a -23,5 dB (victory) de
niveau moyen : 18 dB d ecart, soit un son huit fois plus fort qu un autre a
reglage egal. Le script MESURE chaque son (niveau RMS des passages actifs) et
ecrit dans scripts/autoload/audio_bus.gd une table de gains qui ramene chaque
categorie a sa cible. Les sons FREQUENTS (coups, morts) visent plus bas que les
sorts : on en entend dix par seconde a 400 % de vitesse.

MUSIQUES
--------
Re-encodees en Vorbis q3 (~112 kbit/s) depuis les WAV des packs : les .ogg
livres sont a 324-430 kbit/s, trois fois le necessaire sur un telephone.

Usage : python tools/assets/extract_w10_audio.py   (racine du projet)
Le chemin des packs se regle par WIZARD_RAW (defaut : raw_assets/ du depot
principal, les worktrees n en ont pas).
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
import zipfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.environ.get("WIZARD_RAW") or os.path.join(PROJ, "raw_assets")
# Un worktree peut avoir un dossier raw_assets/ qui ne contient que son
# .gdignore : on teste la presence d un PACK, pas celle du dossier.
if not os.path.isfile(os.path.join(RAW, "FreeSFX.zip")):
    RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets"

OUT_SFX = os.path.join(PROJ, "assets", "sfx")
OUT_MUSIC = os.path.join(PROJ, "assets", "music")
AUDIO_BUS = os.path.join(PROJ, "scripts", "autoload", "audio_bus.gd")

PACKS = {
    "S": "400 Sounds Pack.zip",
    "F": "FreeSFX.zip",
    "H": "28 High Quality 16-bit RPG Music.zip",
    "X": "xDeviruchi - 16 bit Fantasy & Adventure (2025).zip",
}
XD = "xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/wav/"

RATE = 44100

# cle -> (source, options). Source = "P:chemin dans le zip".
# Options : max (s), start (s), rev (inverse), mix [(source, decalage s, gain)].
SFX = {
    # --- Monstres : un son de COUP et un son de MORT par famille ---
    "hit_slime": ("S:Combat and Gore/squelching_3.wav", {"max": 0.35}),
    "die_slime": ("S:Combat and Gore/crunch_splat.wav", {"max": 0.6}),
    "hit_bone": ("S:Combat and Gore/crunch_quick.wav", {"max": 0.3}),
    "die_bone": ("S:Combat and Gore/bone_snap.wav", {"max": 0.7}),
    "hit_stone": ("F:FreeSFX/GameSFX/Impact/Retro Impact LoFi 09.wav", {"max": 0.4}),
    "die_stone": ("S:Materials/concrete_scrape.wav", {"max": 0.8}),
    "hit_metal": ("S:Weapons/sword_clash_2.wav", {"max": 0.27}),
    "die_metal": ("S:Weapons/sword_drop.wav", {"max": 0.8}),
    "die_beast": ("F:FreeSFX/GameSFX/Roar/Retro Roar LoFi 01.wav", {"max": 0.7}),
    "die_bird": ("F:FreeSFX/GameSFX/Animal Insects/Retro Crow 01.wav", {"max": 0.8}),
    "die_insect": ("S:Combat and Gore/splat_double_quick.wav", {"max": 0.45}),
    "die_human": ("S:Human/man_3.wav", {"max": 0.5}),
    "die_human_2": ("S:Human/man_0.wav", {"max": 0.55}),
    "die_human_3": ("S:Human/man_6.wav", {"max": 0.6}),
    "die_arcane": ("S:Retro/power_down.wav", {"max": 0.5}),
    "die_demon": ("F:FreeSFX/GameSFX/Roar/Retro Roar Krushed 01.wav", {"max": 1.0}),
    "hit_ghost": ("S:Environment/air_burst.wav", {"max": 0.3}),
    "die_ghost": ("S:Retro/ghost.wav", {"max": 0.66}),
    "hit_wood": ("S:Materials/wood_small_hollow.wav", {"max": 0.35}),
    "die_plant": ("S:Combat and Gore/crunch.wav", {"max": 0.7}),
    "hit_glass": ("S:Materials/glass_ping_small.wav", {"max": 0.4}),
    "die_glass": ("S:Materials/glass_ping_big.wav", {"max": 1.0}),
    # --- Mecaniques de monstres (fini le shield_break a tout faire) ---
    "seal_tick": ("S:Materials/metal_blunt_tap.wav", {"max": 0.4}),
    "armor_break": ("S:Materials/pottery_clang.wav", {"max": 0.56}),
    "revive": ("F:FreeSFX/GameSFX/PowerUp/Retro PowerUP StereoUP 05.wav", {"max": 1.0}),
    "summon_call": ("F:FreeSFX/GameSFX/Charge/Retro Charge StereoUP 12.wav", {"max": 1.2}),
    "time_rewind": ("S:Environment/clock_ticking.wav", {"max": 1.1, "rev": True}),
    "twin_fall": ("S:Retro/fall_quick.wav", {"max": 0.43}),
    "chameleon_shift": ("F:FreeSFX/GameSFX/Weird/Retro Weird 15.wav", {"max": 1.0}),
    "card_steal": ("S:Card and Board/card_fan.wav", {"max": 0.4}),
    "devour": ("S:Other/munching_food.wav", {"max": 0.9}),
    "aura_break": ("F:FreeSFX/GameSFX/Charge/Retro Charge Off 11.wav", {"max": 1.0}),
    "quake": ("S:Retro/explosion_large.wav", {"max": 1.2}),
    "laser_beam": ("F:FreeSFX/GameSFX/Weapon/laser/Retro Weapon Laser 36.wav", {"max": 0.8}),
    "spell_shot": ("F:FreeSFX/GameSFX/Weapon/laser/Retro Gun Laser SingleShot 01.wav", {"max": 0.6}),
    "throw": ("S:Retro/throw.wav", {"max": 0.35}),
    "magic_silence": ("F:FreeSFX/GameSFX/Descending/Retro Descending Short 20.wav", {"max": 1.2}),
    "reanimate": ("S:Other/ghost_long.wav", {"max": 1.4}),
    # --- Objets de terrain et murs ---
    "wood_creak": ("S:Environment/creaky_door_short.wav", {"max": 0.84}),
    "wood_break": ("S:Materials/wood_small_drop.wav", {"max": 0.53}),
    "wall_break": ("S:Materials/stone_push_medium.wav", {"max": 1.0}),
    "earth_dig": ("S:Items/shovel_dig.wav", {"max": 0.6}),
    "bramble_rustle": ("S:Items/broom_sweep_1.wav", {"max": 0.59}),
    "altar_hum": ("S:Musical Effects/8_bit_mystery.wav", {"max": 1.21}),
    # --- Sorts : un son par sort ou presque, de la famille de son element ---
    "fire_forge": ("F:FreeSFX/GameSFX/Impact/Retro Impact Metal 05.wav", {"max": 1.2}),
    "fire_swoosh": ("F:FreeSFX/GameSFX/Explosion/Retro Explosion Swoshes 04.wav", {"max": 1.4}),
    "ice_chime": ("S:Materials/glass_ping_small.wav", {"max": 0.67,
        "mix": [("S:Environment/water_drop_medium.wav", 0.05, 0.5)]}),
    "ice_crack": ("S:Environment/ice_in_water.wav", {"max": 0.49}),
    "ice_wall": ("S:Materials/glass_ping_big.wav", {"max": 1.0,
        "mix": [("S:Materials/stone_push_short.wav", 0.0, 0.6)]}),
    "curse_mark": ("F:FreeSFX/GameSFX/Weird/Retro Weird Psych 18.wav", {"max": 1.0}),
    "time_rift": ("F:FreeSFX/GameSFX/Weird/Retro Weird 07.wav", {"max": 1.4,
        "mix": [("S:Environment/clock_tock_only.wav", 0.0, 0.9)]}),
    "time_haste": ("F:FreeSFX/GameSFX/Ascending/Retro Ascending Short 20.wav", {"max": 1.2,
        "mix": [("S:Environment/clock_tick_only.wav", 0.0, 0.9)]}),
    "time_slow": ("F:FreeSFX/GameSFX/Descending/Retro Descending Long 04.wav", {"max": 1.3,
        "mix": [("S:Environment/clock_tock_only.wav", 0.0, 0.9)]}),
    "void_pull": ("F:FreeSFX/GameSFX/Charge/Retro Charge Off StereoUP 05.wav", {"max": 1.2}),
    "poison_dart": ("S:Retro/throw.wav", {"max": 0.6,
        "mix": [("S:Combat and Gore/splat_double_quick.wav", 0.12, 0.8)]}),
    "poison_bubble": ("S:Environment/gurgling.wav", {"max": 1.4}),
    "bone_rattle": ("S:Combat and Gore/crunch.wav", {"start": 0.0, "max": 0.9,
        "mix": [("S:Combat and Gore/bone_snap.wav", 0.15, 0.5)]}),
    "card_tear": ("S:Materials/paper_tear_1.wav", {"max": 0.87}),
    "zap_spark": ("F:FreeSFX/GameSFX/Electric/Retro Electric Sparks 01.wav", {"max": 0.9}),
    "water_splash": ("S:Environment/water_splashing.wav", {"max": 1.15}),
    "water_drop": ("S:Environment/water_drop_medium.wav", {"max": 0.68}),
    "water_flow": ("F:FreeSFX/GameSFX/Water/Retro Falling Water 07.wav", {"max": 1.6}),
    "stone_heavy": ("S:Materials/stone_push_long.wav", {"max": 1.4}),
    "wood_knock": ("S:Materials/wood_small_hollow.wav", {"max": 0.45,
        "mix": [("S:Materials/wood_small_drop.wav", 0.08, 0.6)]}),
    "wind_arrow": ("F:FreeSFX/GameSFX/Swoosh/Retro Swooosh 07.wav", {"max": 1.0}),
    "air_burst": ("S:Environment/air_burst.wav", {"max": 0.3,
        "mix": [("F:FreeSFX/GameSFX/Swoosh/Retro Swooosh 02.wav", 0.0, 0.7)]}),
    "wind_swirl": ("F:FreeSFX/GameSFX/Swoosh/Retro Swooosh 16.wav", {"max": 1.6}),
}

# cle -> source WAV (encodee en Vorbis q3).
MUSIC = {
    # Acte II, les Sky Lands : le theme du ciel du pack HydroGene (136 bpm, le
    # plus clair du lot : centroide spectral 1,8 kHz).
    "battle_act2": "H:wav/14. Traveling the Sky.wav",
    # Acte III, le cimetiere de Tombol : le deuxieme theme de combat, plus lent.
    "battle_act3": "H:wav/09. Battle Theme II (loop).wav",
    # Acte IV, le monde demoniaque : le troisieme, le plus dense en attaques.
    "battle_act4": "H:wav/16. Battle Theme III (loop).wav",
    # Acte V, l espace divin : xDeviruchi, « Decisive Battle 2 - The Calamity ».
    "battle_act5": "X:" + XD + "17 - Decisive Battle 2 - The Calamity.wav",
    # Le boss final (L Enfant) : xDeviruchi, « Final Battle - For Love ».
    "boss_final": "X:" + XD + "21 - Final Battle - For Love.wav",
    # Le Massacre : aucun monde, tous les monstres — le quatrieme theme de combat.
    "massacre": "H:wav/24. Battle Theme IV (loop).wav",
}

# Categorie de chaque son, et niveau RMS vise par categorie (dBFS). Une cle
# absente est un son de SORT.
TARGET_DB = {"frequent": -25.0, "spell": -18.0, "event": -17.0, "ui": -20.0,
             "mechanic": -19.0, "music": -18.0}
CATEGORY = {}
for k in ("hit", "enemy_die", "card_draw", "arrow", "throw", "spell_shot") + tuple(
        k for k in SFX if k.startswith("hit_") or k.startswith("die_")):
    CATEGORY[k] = "frequent"
for k in ("ui_tap", "card_pick"):
    CATEGORY[k] = "ui"
for k in ("boss", "wave_start", "victory", "defeat", "level_up", "speed_up", "explosion",
          "hp_lost"):
    CATEGORY[k] = "event"
for k in ("shield_break", "seal_tick", "armor_break", "revive", "summon_call", "time_rewind",
          "twin_fall", "chameleon_shift", "card_steal", "devour", "aura_break", "quake",
          "laser_beam", "magic_silence", "reanimate", "wood_creak", "wood_break", "wall_break",
          "wall", "grow", "heal", "cast_start", "cast_done", "cast_zone"):
    CATEGORY[k] = "mechanic"
GAIN_MIN, GAIN_MAX = -14.0, 8.0


def zip_of(code, cache={}):
    if code not in cache:
        cache[code] = zipfile.ZipFile(os.path.join(RAW, PACKS[code]))
    return cache[code]


def read_entry(src):
    code, name = src.split(":", 1)
    return zip_of(code).read(name)


def decode_wav(data):
    w = wave.open(io.BytesIO(data))
    n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        a = v.astype(np.float64) / float(1 << 23)
    elif sw == 1:
        a = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype="<i4").astype(np.float64) / float(1 << 31)
    else:
        raise SystemExit("largeur d echantillon inconnue : %d" % sw)
    mono = a.reshape(-1, ch).mean(axis=1)
    if sr != RATE:
        t = np.arange(int(len(mono) * RATE / sr)) * (sr / RATE)
        mono = np.interp(t, np.arange(len(mono)), mono)
    return mono


def trim_head(x, rel_db=-45.0):
    peak = np.abs(x).max() + 1e-12
    seuil = peak * (10 ** (rel_db / 20.0))
    idx = np.argmax(np.abs(x) > seuil)
    # 3 ms de marge : couper pile sur l attaque fait un clic.
    return x[max(0, idx - int(0.003 * RATE)):]


def fade(x, fin_s, debut_s=0.004):
    x = x.copy()
    a = min(len(x), int(debut_s * RATE))
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    b = min(len(x), int(fin_s * RATE))
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def build(src, opt):
    x = trim_head(decode_wav(read_entry(src))[int(opt.get("start", 0.0) * RATE):])
    for (src2, decal, gain) in opt.get("mix", []):
        y = trim_head(decode_wav(read_entry(src2))) * gain
        d = int(decal * RATE)
        n = max(len(x), d + len(y))
        z = np.zeros(n)
        z[:len(x)] += x
        z[d:d + len(y)] += y
        x = z
    if "max" in opt:
        x = x[:int(opt["max"] * RATE)]
    if opt.get("rev"):
        x = x[::-1]
    x = fade(x, min(0.08, len(x) / RATE * 0.3))
    peak = np.abs(x).max() + 1e-12
    return x * (10 ** (-1.0 / 20.0) / peak)


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def active_rms_db(x):
    """Niveau RMS des passages ACTIFS (au-dessus de -40 dB de la crete) : un
    son court suivi d une longue queue n est pas plus doux pour autant."""
    peak = np.abs(x).max() + 1e-12
    win = RATE // 50
    k = len(x) // win
    if k == 0:
        return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
    r = np.sqrt((x[:k * win].reshape(k, win) ** 2).mean(axis=1))
    act = r[r > peak * 0.01]
    v = np.sqrt((act ** 2).mean()) if len(act) else r.max()
    return 20 * np.log10(v + 1e-12)


def ffmpeg():
    exe = shutil.which("ffmpeg")
    if exe is None:
        raise SystemExit("ffmpeg introuvable : il encode les musiques")
    return exe


def encode_music(key, src, tmp):
    wav = os.path.join(tmp, key + ".wav")
    with open(wav, "wb") as f:
        f.write(read_entry(src))
    out = os.path.join(OUT_MUSIC, key + ".ogg")
    subprocess.run([ffmpeg(), "-v", "error", "-y", "-i", wav, "-ac", "2", "-ar", "44100",
                    "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    return out


def decode_music_mono(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", path, "-ac", "1", "-ar", "11025",
                          "-f", "s16le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def read_project_wav(path):
    with open(path, "rb") as f:
        return decode_wav(f.read())


def clamp_gain(g, x):
    """Borne le gain, et surtout ne le laisse JAMAIS pousser la crete au-dessus
    de -0,5 dBFS : un son tres « pointu » (glouglou, gresillement) a un niveau
    moyen bas pour une crete haute, et le remonter a sa cible le ferait saturer
    a la lecture. Mieux vaut un son un peu en retrait qu un son qui craque."""
    crete = 20 * np.log10(np.abs(x).max() + 1e-12)
    return max(GAIN_MIN, min(GAIN_MAX, g, -0.5 - crete))


def gains_block():
    sfx_lines, music_lines = [], []
    for name in sorted(os.listdir(OUT_SFX)):
        if not name.endswith(".wav"):
            continue
        key = name[:-4]
        cat = CATEGORY.get(key, "spell")
        x = read_project_wav(os.path.join(OUT_SFX, name))
        g = clamp_gain(TARGET_DB[cat] - active_rms_db(x), x)
        sfx_lines.append('\t"%s": %.1f,' % (key, g))
    for name in sorted(os.listdir(OUT_MUSIC)):
        if not name.endswith(".ogg"):
            continue
        x = decode_music_mono(os.path.join(OUT_MUSIC, name))
        g = clamp_gain(TARGET_DB["music"] - 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12), x)
        music_lines.append('\t"%s": %.1f,' % (name[:-4], g))
    return ("const SFX_GAIN_DB: Dictionary = {\n" + "\n".join(sfx_lines) + "\n}\n"
            + "const MUSIC_GAIN_DB: Dictionary = {\n" + "\n".join(music_lines) + "\n}\n")


DEBUT = "## --- GAINS : genere par tools/assets/extract_w10_audio.py ---\n"
FIN = "## --- fin des gains ---\n"


def write_gains():
    with open(AUDIO_BUS, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    i, j = text.find(DEBUT), text.find(FIN)
    if i < 0 or j < i:
        raise SystemExit("marqueurs des gains absents de audio_bus.gd")
    text = text[:i + len(DEBUT)] + gains_block() + text[j:]
    # newline="" : sous Windows, le mode texte ecrirait des CRLF (gotchas.md).
    with open(AUDIO_BUS, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT_SFX, exist_ok=True)
    os.makedirs(OUT_MUSIC, exist_ok=True)
    print("sons :")
    for key, (src, opt) in SFX.items():
        if only and key not in only:
            continue
        x = build(src, opt)
        write_wav(os.path.join(OUT_SFX, key + ".wav"), x)
        print("  %-16s %5.2f s  <- %s" % (key, len(x) / RATE, src.split("/")[-1]))
    if not only or "music" in only:
        print("musiques :")
        tmp = tempfile.mkdtemp(prefix="w10_music_")
        try:
            for key, src in MUSIC.items():
                out = encode_music(key, src, tmp)
                print("  %-14s %6d ko  <- %s" % (key, os.path.getsize(out) // 1024, src.split("/")[-1]))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print("gains :")
    write_gains()
    print("  table ecrite dans scripts/autoload/audio_bus.gd")


if __name__ == "__main__":
    main()
