"""Logos d element et de type de sort : assets/icons/element_*.png (128 px).

UN LOGO = UNE FORME + UNE COULEUR + UNE IMAGE. Les trois portent la meme
information, et c est voulu : a 28 px sur une carte de main, l image du pack ne
se lit plus, la couleur ne se lit pas pour un joueur daltonien, mais la FORME du
cadre se lit toujours. Deux elements ne partagent jamais une forme.

  element    forme              couleur du cadre     image (pack craftpix)
  feu        triangle (pointe   orange               flamme        FireMage 6
             en haut)
  eau        goutte (pointe     bleu profond         trombe d eau  Aeromancer 47 (recoloree en bleu)
             en haut)
  nature     carre              ocre                 arbre-rune    EarthMage 18
  vent       capsule couchee    blanc menthe         tornade       Aeromancer 19 (recoloree menthe)
  glace      hexagone           cyan                 eclat blanc   Aeromancer 46 (recolore en givre)
  arcane     losange            violet               croissant     Night Elf 48
  poison     cercle             vert                 fiole         Warlock 45 (recoloree en vert)
  foudre     etoile a 4 pointes jaune                eclair        FireMage 8 (fond passe au nuit)

VAGUE 8 (huit elements) : le physique disparait, la GLACE reprend le logo du
givre (meme element, fichier renomme), la NATURE prend le carre du physique
(la pierre, le bloc de terre), l EAU une goutte, le VENT une capsule couchee
(une rafale). Les deux formes neuves ne ressemblent a aucune autre a 28 px :
la goutte a une pointe que le cercle n a pas, la capsule est la seule forme
plus large que haute.
  ralentis.  sablier            argent               main qui      Night Elf 11
                                                     arrete

Les TYPES NON ELEMENTAIRES (invocation, terrain, grimoire, passif) partagent un
seul cadre, l ECU dore : ils ne se confondent jamais avec un element, et le
joueur apprend une regle au lieu de douze formes. Leur image les distingue.

  invocation   ecu dore   silhouette invoquee   Warlock 34
  terrain      ecu dore   pilier de roche       EarthMage 20
  grimoire     ecu dore   rune d or             EarthMage 16
  passif       ecu dore   aura blanche          Aeromancer 40

Les quatre images de type ont des VALEURS differentes (bleu vif, roche
sombre, or sur noir, blanc) : sous le meme cadre, c est ce qui les separe
encore a 28 px, verifie sur planche en niveaux de gris.

AUCUNE image deja portee par une carte (verifie par comparaison a 32 px avec
assets/icons/*.png) : le logo d un element ne doit pas ressembler a un sort.
En particulier la chaine du Night Elf (18), ideale pour le ralentissement, est
DEJA l icone de Brise-chaine.

POURQUOI DES RECOLORATIONS et pas des teintes : une teinte MULTIPLIE (voir
gotchas), elle noircit un fond deja colore. Le givre, le poison et la foudre
n ont pas d image a la bonne couleur dans les packs autorises ; on remappe
donc la LUMINANCE sur un degrade de l element, ce qui garde le dessin intact.

Sources (raw_assets/packs_2026_09_26, licences dans docs/assets_index.md) :
craftpix (Free-RPG-Night-Elf-Skill-Icons, Free Warlock Skills, FireMage_Free,
EarthMage_Free, Free 50 Aeromancer Skills) : commercial oui, credit non,
redistribution des sources non. PAS le pack Batareya (licence inconnue).

Usage : python tools/assets/extract_elements.py   (depuis la racine du projet)
Le chemin des packs se regle par WIZARD_RAW (defaut : raw_assets/ du depot
principal, les worktrees n en ont pas de copie).
"""
import io
import math
import os
import re
import sys
import zipfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.environ.get("WIZARD_RAW") or os.path.join(PROJ, "raw_assets", "packs_2026_09_26")
if not os.path.isdir(RAW) or not os.listdir(RAW):
    RAW = r"C:\Users\Lenovo\Desktop\wizard_game\raw_assets\packs_2026_09_26"

SIZE = 128
# Sur-echantillonnage du masque : sans lui, le bord d un triangle ou d une
# etoile se crenele a 128 px et bave une fois reduit a 28.
SS = 4

PACKS = {
    "nightelf": "Free-RPG-Night-Elf-Skill-Icons.zip",
    "warlock": "Free Warlock Skills.zip",
    "earth": "EarthMage_Free.zip",
    "fire": "FireMage_Free.zip",
    "aero": "Free 50 Aeromancer Skills.zip",
}

BRONZE = (205, 172, 110)
BLEU = (64, 128, 242)
OCRE = (176, 132, 64)
MENTHE = (204, 242, 230)
ORANGE = (242, 115, 51)
CYAN = (115, 204, 242)
VIOLET = (158, 115, 242)
VERT = (140, 230, 77)
JAUNE = (242, 230, 89)
ARGENT = (235, 238, 245)
OR = (242, 199, 77)

# cle -> (pack, numero, forme, couleur du cadre, recoloration ou None)
LOGOS = {
    "feu": ("fire", 6, "triangle", ORANGE, None),
    "eau": ("aero", 47, "goutte", BLEU, ((6, 18, 64), (150, 205, 255))),
    "nature": ("earth", 18, "carre", OCRE, None),
    "vent": ("aero", 19, "capsule", MENTHE, ((14, 44, 40), (225, 255, 240))),
    "glace": ("aero", 46, "hexagone", CYAN, ((8, 26, 58), (200, 240, 255))),
    "arcane": ("nightelf", 48, "losange", VIOLET, None),
    "poison": ("warlock", 45, "cercle", VERT, ((10, 36, 10), (205, 255, 130))),
    "foudre": ("fire", 8, "etoile", JAUNE, ((20, 16, 64), (255, 245, 110))),
    "ralentissement": ("nightelf", 11, "sablier", ARGENT, None),
    "invocation": ("warlock", 34, "ecu", OR, None),
    "terrain": ("earth", 20, "ecu", OR, None),
    "grimoire": ("earth", 16, "ecu", OR, None),
    "passif": ("aero", 40, "ecu", OR, None),
}


def _forme(nom):
    """Polygone de la forme, en coordonnees unitaires centrees (-1..1)."""
    if nom == "carre":
        return [(-0.84, -0.84), (0.84, -0.84), (0.84, 0.84), (-0.84, 0.84)]
    if nom == "triangle":
        return [(0.0, -1.0), (1.0, 0.78), (-1.0, 0.78)]
    if nom == "hexagone":
        return [(math.cos(math.radians(-90 + 60 * k)), math.sin(math.radians(-90 + 60 * k)))
                for k in range(6)]
    if nom == "losange":
        return [(0.0, -1.0), (0.92, 0.0), (0.0, 1.0), (-0.92, 0.0)]
    if nom == "cercle":
        return [(0.94 * math.cos(math.radians(a)), 0.94 * math.sin(math.radians(a)))
                for a in range(0, 360, 6)]
    if nom == "etoile":
        # Rayon interieur large : une etoile trop creusee ne laisse plus voir
        # l image, et a 28 px ses branches deviennent des traits.
        pts = []
        for k in range(8):
            r = 1.0 if k % 2 == 0 else 0.52
            a = math.radians(-90 + 45 * k)
            pts.append((r * math.cos(a), r * math.sin(a)))
        return pts
    if nom == "sablier":
        return [(-0.86, -0.96), (0.86, -0.96), (0.26, 0.0),
                (0.86, 0.96), (-0.86, 0.96), (-0.26, 0.0)]
    if nom == "goutte":
        # Un cercle bas surmonte d une pointe : la pointe est ce qui la separe
        # du cercle du poison, meme en niveaux de gris.
        pts = [(0.0, -1.0)]
        for a in range(-60, 241, 6):
            r = math.radians(a)
            pts.append((0.68 * math.cos(r), 0.30 + 0.68 * math.sin(r)))
        return pts
    if nom == "capsule":
        # Plus large que haute : la seule forme couchee du jeu.
        pts = []
        for a in range(-90, 91, 6):
            r = math.radians(a)
            pts.append((0.40 + 0.56 * math.cos(r), 0.56 * math.sin(r)))
        for a in range(90, 271, 6):
            r = math.radians(a)
            pts.append((-0.40 + 0.56 * math.cos(r), 0.56 * math.sin(r)))
        return pts
    if nom == "ecu":
        return [(-0.86, -0.92), (0.86, -0.92), (0.86, 0.12), (0.62, 0.58),
                (0.0, 1.0), (-0.62, 0.58), (-0.86, 0.12)]
    sys.exit("forme inconnue : " + nom)


def _masque(poly, echelle):
    """Masque L de la forme reduite d `echelle` autour de son centre."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    big = SIZE * SS
    demi = big * 0.5
    pts = [(demi + ((x - cx) * echelle + cx) * demi * 0.97,
            demi + ((y - cy) * echelle + cy) * demi * 0.97) for x, y in poly]
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m.resize((SIZE, SIZE), Image.LANCZOS)


def _image(pack, num):
    zf = zipfile.ZipFile(os.path.join(RAW, PACKS[pack]))
    for n in zf.namelist():
        if re.search(r"(^|/|_)%d\.png$" % num, n):
            return Image.open(io.BytesIO(zf.read(n))).convert("RGBA")
    sys.exit("introuvable : %s %d" % (pack, num))


def _recolore(im, sombre, clair):
    """Remappe la luminance sur un degrade sombre -> clair de l element."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            px[x, y] = (int(sombre[0] + (clair[0] - sombre[0]) * t),
                        int(sombre[1] + (clair[1] - sombre[1]) * t),
                        int(sombre[2] + (clair[2] - sombre[2]) * t), a)
    return out


# Recul de l image dans son cadre, pour celles dont le sujet deborde la zone
# visible : la fiole du poison perdait son goulot, et une fiole sans goulot
# n est plus qu une tache verte.
RECUL = {"poison": 0.78}


def logo(cle):
    pack, num, forme, couleur, recol = LOGOS[cle]
    im = _image(pack, num).resize((SIZE, SIZE), Image.LANCZOS)
    recul = RECUL.get(cle, 1.0)
    if recul < 1.0:
        # Le fond est la couleur moyenne du bord de l image : les icones du pack
        # finissent en vignette sombre, la couture ne se voit donc pas.
        bord = im.crop((0, 0, SIZE, 6)).resize((1, 1), Image.LANCZOS).getpixel((0, 0))
        petit = im.resize((int(SIZE * recul), int(SIZE * recul)), Image.LANCZOS)
        im = Image.new("RGBA", (SIZE, SIZE), bord)
        im.paste(petit, ((SIZE - petit.width) // 2, (SIZE - petit.height) // 2), petit)
    if recol is not None:
        im = _recolore(im, recol[0], recol[1])
    poly = _forme(forme)
    # Trois couches : un lisere SOMBRE (lisible sur le papier creme du grimoire
    # comme sur l herbe du terrain), le cadre a la couleur de l element, puis
    # l image. Le cadre est EPAIS expres : a 28 px c est lui qui porte la forme.
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (SIZE, SIZE), (24, 18, 12, 255)), (0, 0), _masque(poly, 1.0))
    out.paste(Image.new("RGBA", (SIZE, SIZE), couleur + (255,)), (0, 0), _masque(poly, 0.91))
    out.paste(im, (0, 0), _masque(poly, 0.74))
    return out


def main():
    dest = os.path.join(PROJ, "assets", "icons")
    os.makedirs(dest, exist_ok=True)
    # Logos d elements RETIRES en vague 8 : un fichier orphelin serait encore
    # charge par un appel oublie et afficherait un element qui n existe plus.
    for ancien in ("physique", "givre"):
        for ext in (".png", ".png.import"):
            f = os.path.join(dest, "element_%s%s" % (ancien, ext))
            if os.path.exists(f):
                os.remove(f)
    for cle in LOGOS:
        logo(cle).save(os.path.join(dest, "element_%s.png" % cle), optimize=True)
        print("logo", cle)


if __name__ == "__main__":
    main()
