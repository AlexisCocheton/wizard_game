"""Extraction des bandes du Paon (Oiseau mirage) depuis monsters_2026_09.

POURQUOI ce script existe
-------------------------
Retour du testeur : "Oiseau mirage : son sprite tourne en se deplacant, il doit
se deplacer normalement."

La cause n est PAS une rotation appliquee par le code. Les deux planches du pack
sont des grilles 4 DIRECTIONS x N poses :

    Peacock-walk-Sheet.png        128 x 96   -> 4 colonnes x 3 lignes de 32x32
    Peacock-folded-tail-Sheet.png 144 x 152  -> 4 colonnes x 4 lignes de 36x38

Une COLONNE = une direction (droite, face, dos, gauche), une LIGNE = une pose de
cette direction. La premiere extraction avait decoupe une LIGNE : les 4 cases de
la bande etaient donc quatre ORIENTATIONS differentes du meme oiseau, qui
semblait pivoter sur lui meme a chaque case. Les largeurs le montrent :
31 / 25 / 25 / 31 px — une vue de cote est plus large qu une vue de face.

Correctif : on decoupe une COLONNE et on la depose a l horizontale, format
attendu par SheetLib.strip(). Les monstres descendent vers le mage, donc on
prend la vue de FACE.

    marche : colonne 1 (vue de face, 3 poses)
    repos  : colonne 0 de la planche a queue repliee (vue de face, 4 poses)

Verrouille par tests/unit/test_enemy_behaviors.gd
(_test_l_oiseau_mirage_ne_tourne_plus) : toutes les cases de marche doivent
avoir la MEME largeur a 4 px pres, ce qui est impossible si l on melange une vue
de face et une vue de cote.

Usage : python tools/assets/extract_peacock.py
"""

from pathlib import Path

from PIL import Image

RACINE = Path(__file__).resolve().parents[2]
SOURCE = RACINE / "raw_assets" / "monsters_2026_09"
SORTIE = RACINE / "assets" / "units"

# (planche, largeur de case, hauteur de case, colonne a extraire, nb de poses, nom)
# La colonne est choisie sur la VUE DE FACE : voir l en-tete.
BANDES = [
    ("Peacock-walk-Sheet.png", 32, 32, 1, 3, "peacock_front_walk.png"),
    ("Peacock-folded-tail-Sheet.png", 36, 38, 0, 4, "peacock_front_idle.png"),
]

# AnimCatalog ne connait QU UNE taille de case par cle ("frame"/"frame_h"), et
# SheetLib decoupe toutes les animations d une cle avec. Les deux planches du
# paon n ont pas le meme pas (32x32 et 36x38) : on recadre donc la bande de
# repos sur la meme case 32x32 que la marche, en centrant la silhouette. Sans
# cela le decoupage du repos glisserait d une case a l autre.
CASE_COMMUNE = (32, 32)


def extraire(planche: str, fw: int, fh: int, colonne: int, poses: int, nom: str) -> None:
    src = Image.open(SOURCE / planche).convert("RGBA")
    cw, ch = CASE_COMMUNE
    bande = Image.new("RGBA", (cw * poses, ch), (0, 0, 0, 0))
    largeurs = []
    for i in range(poses):
        case = src.crop((colonne * fw, i * fh, (colonne + 1) * fw, (i + 1) * fh))
        # Recadrage sur la case commune : centre en largeur, cale en BAS (les
        # pattes touchent le sol, c est le bord qui doit rester fixe d une pose
        # a l autre, sinon l oiseau sautille sur place).
        dx = (cw - fw) // 2
        dy = ch - fh
        bande.paste(case, (i * cw + dx, dy), case)
        bb = case.getbbox()
        largeurs.append(bb[2] - bb[0] if bb else 0)
    bande.save(SORTIE / nom)
    ecart = max(largeurs) - min(largeurs)
    # Un ecart large signalerait qu on a repris une ligne (des directions
    # melangees) au lieu d une colonne : c est exactement le bug d origine.
    etat = "OK" if ecart <= 4 else "SUSPECT (directions melangees ?)"
    print(f"{nom:28} {poses} cases de {fw}x{fh}  largeurs={largeurs}  ecart={ecart}  {etat}")


def main() -> None:
    SORTIE.mkdir(parents=True, exist_ok=True)
    for args in BANDES:
        extraire(*args)


if __name__ == "__main__":
    main()
