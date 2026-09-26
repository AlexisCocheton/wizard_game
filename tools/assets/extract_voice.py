# -*- coding: utf-8 -*-
"""Extrait les repliques du mage (John Carroll, Mage Voice Pack).

CE QUI EST PRIS, ET POURQUOI PAS TOUT
-------------------------------------
Le pack compte 130 clips ranges par SITUATION (attack1..3, hit1..5, death1..3,
fire, freeze, thunder, summoning...). Le jeu n a pas 44 situations : il en a une
douzaine. On ne prend donc que les familles qui correspondent a un moment REEL
du jeu, et on les range sous le nom de ce moment, pas sous celui du pack.

Les variantes numerotees sont CONSERVEES (voice_cast_1, _2, _3) : une voix qui
dit exactement la meme chose a chaque sort devient vite insupportable. C est
`AudioBus.play_voice()` qui tire au hasard parmi les variantes.

Licence : l auteur (johncarroll.itch.io) demande seulement a etre prevenu de
l usage. A faire avant publication — voir docs/assets_index.md.

Usage : python tools/assets/extract_voice.py
"""
import os
import zipfile

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ZIP = os.path.join(RACINE, "raw_assets", "packs_2026_09_26", "Mage Voice Pack.zip")
OUT = os.path.join(RACINE, "assets", "voice")

# famille du pack -> moment du jeu. Une famille non citee n est PAS extraite :
# un fichier qui ne sera jamais joue est du poids mort que l AUDIT ne voit pas.
FAMILLES = {
    "casting":   "cast",       # on commence une incantation
    "attack":    "attack",     # un sort de degats part
    "magicattack": "spell",    # un sort arcanique part
    "fire":      "fire",       # element FEU
    "freeze":    "frost",      # element GIVRE
    "thunder":   "lightning",  # element FOUDRE
    "summoning": "summon",     # invocation d un allie
    "shield":    "shield",     # le bouclier de vitesse encaisse
    "hit":       "hurt",       # le mage encaisse des PV
    "death":     "death",      # PV a zero
    "laugh":     "victory",    # niveau termine
    "tired":     "defeat",     # defaite
    "hello":     "level_start",
    "haste":     "haste",      # la vitesse monte haut
}


def main() -> None:
    if not os.path.exists(ZIP):
        raise SystemExit("archive absente : %s" % ZIP)
    os.makedirs(OUT, exist_ok=True)
    z = zipfile.ZipFile(ZIP)
    pris = 0
    for nom in z.namelist():
        if not nom.lower().endswith(".wav"):
            continue
        base = nom.split("/")[-1][:-4]          # "attack2"
        famille = base.rstrip("0123456789")      # "attack"
        num = base[len(famille):] or "1"
        if famille not in FAMILLES:
            continue
        cible = os.path.join(OUT, "voice_%s_%s.wav" % (FAMILLES[famille], num))
        with open(cible, "wb") as f:
            f.write(z.read(nom))
        pris += 1
    print("%d repliques extraites dans assets/voice/" % pris)


if __name__ == "__main__":
    main()
