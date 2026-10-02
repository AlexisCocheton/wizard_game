# -*- coding: utf-8 -*-
"""Couvre-chefs du mage DESSINES en pixel art (aucun pack n en fournit).

Chaque chapeau est peint dans une case de CELL_W x CELL_H pixels, a la
RESOLUTION DU MOINE de Tiny Swords (case de 192 px) : un pixel de chapeau vaut un
pixel de mage, donc la meme echelle a l ecran et le meme grain.

LE PIVOT (PIVOT_X, PIVOT_Y) est le point de la case qui se pose sur le SOMMET DE
LA TETE mesure image par image (voir make_wardrobe.py, mesure_tetes). Les
reperes ci-dessous en decoulent, mesures sur monk_blue_idle (case 0) :
  - la tonsure (le disque clair du crane) commence 3 px sous le sommet ;
  - l anneau de cheveux est le plus large ~15 px sous le sommet (51 px) ;
  - le front, donc le haut du visage, est a ~28 px sous le sommet.
D ou BRIM_Y = PIVOT_Y + 15 : un bord de chapeau a cette hauteur cache la
tonsure et le haut des cheveux, et laisse le visage libre.

LE STYLE DE TINY SWORDS, reproduit par construction :
  - contour sombre (22, 28, 46) de 2 px a l exterieur (1 px de piece + 1 px
    global), 1 px entre deux pieces ;
  - lumiere en haut a gauche, ombre en bas a droite, en bandes de 2 a 3 px ;
  - trois tons par materiau, pas de degrade.
"""
import numpy as np
from PIL import Image, ImageDraw

CELL_W = 96
CELL_H = 104
PIVOT_X = 48
PIVOT_Y = 64
BRIM_Y = PIVOT_Y + 15

OUTLINE = (22, 28, 46, 255)


def _rgba(c):
    return tuple(c) + (255,) if len(c) == 3 else tuple(c)


# --- masques ---------------------------------------------------------------

def m_poly(points):
    img = Image.new("L", (CELL_W, CELL_H), 0)
    ImageDraw.Draw(img).polygon(points, fill=255)
    return np.array(img) > 0


def m_ell(cx, cy, rx, ry):
    img = Image.new("L", (CELL_W, CELL_H), 0)
    ImageDraw.Draw(img).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return np.array(img) > 0


def m_rect(x0, y0, x1, y1):
    m = np.zeros((CELL_H, CELL_W), bool)
    m[y0:y1 + 1, x0:x1 + 1] = True
    return m


def rows(y0, y1):
    m = np.zeros((CELL_H, CELL_W), bool)
    m[y0:y1 + 1, :] = True
    return m


def shift(m, dx, dy):
    """Valeur en p = m[p - (dx, dy)] (sans enroulement)."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    ys2 = slice(max(-dy, 0), h + min(-dy, 0))
    xs2 = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = m[ys2, xs2]
    return out


def erode4(m):
    return m & shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1) & shift(m, 0, -1)


def dilate8(m):
    out = m.copy()
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            out |= shift(m, dx, dy)
    return out


# --- peinture --------------------------------------------------------------

class Hat:
    def __init__(self, outline=OUTLINE):
        self.px = np.zeros((CELL_H, CELL_W, 4), np.uint8)
        self.outline = _rgba(outline)

    def part(self, mask, base, light, shadow, band=2, edge=True):
        """Une piece : ton de base, lumiere en haut a gauche, ombre en bas a
        droite, puis un liseré de 1 px qui la detache des pieces voisines."""
        if not mask.any():
            return
        self.px[mask] = _rgba(base)
        tl = mask & ~shift(mask, band, band)
        br = mask & ~shift(mask, -band, -band)
        self.px[tl & ~br] = _rgba(light)
        self.px[br] = _rgba(shadow)
        if edge:
            self.px[mask & ~erode4(mask)] = self.outline

    def flat(self, mask, color):
        self.px[mask] = _rgba(color)

    def dot(self, x, y, color):
        self.px[y, x] = _rgba(color)

    def finish(self):
        """Contour global de 1 px autour de tout ce qui est peint."""
        a = self.px[..., 3] > 0
        ring = dilate8(a) & ~a
        self.px[ring] = self.outline
        return Image.fromarray(self.px, "RGBA")


def star(h, x, y, c):
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        h.dot(x + dx, y + dy, c)


# --- les chapeaux ----------------------------------------------------------
# Coordonnees dans la case : PIVOT (48, 64) = sommet de la tete, BRIM_Y = 79.

GOLD = ((236, 186, 64), (252, 230, 130), (176, 120, 36))


def hat_wizard():
    """Chapeau pointu de mage, bleu nuit a etoiles d or, pointe pliee."""
    h = Hat()
    bleu = ((58, 76, 160), (96, 122, 210), (36, 46, 108))
    brim = m_ell(48, 80, 31, 7)
    cone = m_poly([(30, 79), (66, 79), (61, 60), (57, 46), (61, 33), (70, 22), (76, 17),
                   (65, 19), (53, 28), (45, 42), (38, 60)])
    h.part(brim, *bleu)
    h.part(cone, *bleu, band=3)
    h.part(cone & rows(70, 77), *GOLD)
    h.part(brim & rows(80, 90), *bleu)
    star(h, 47, 54, (252, 232, 140))
    star(h, 55, 39, (252, 232, 140))
    h.dot(64, 26, (252, 232, 140))
    return h.finish()


def hat_witch():
    """Chapeau de sorciere : large bord, cone tordu, boucle d or."""
    h = Hat()
    nuit = ((62, 46, 86), (98, 74, 130), (38, 28, 56))
    brim = m_ell(48, 80, 36, 7)
    cone = m_poly([(32, 79), (64, 79), (59, 58), (55, 40), (48, 26), (36, 14), (30, 12),
                   (38, 24), (40, 42), (37, 62)])
    h.part(brim, *nuit)
    h.part(cone, *nuit, band=3)
    h.part(cone & rows(69, 77), (150, 92, 196), (186, 132, 226), (104, 60, 144))
    boucle = m_rect(44, 69, 52, 77)
    h.part(boucle, *GOLD)
    h.flat(m_rect(47, 72, 49, 74), (150, 92, 196))
    h.part(brim & rows(80, 90), *nuit)
    return h.finish()


def hat_hood():
    """Capuche verte qui enveloppe la tete et laisse le visage libre."""
    h = Hat()
    vert = ((64, 122, 80), (104, 164, 100), (40, 82, 58))
    # Les pans descendent jusqu aux epaules (~36 px sous le sommet) : plus courte,
    # la capuche se lisait comme un beret pose sur les cheveux.
    dome = m_ell(48, 78, 32, 18) | m_rect(16, 78, 80, 97)
    bas = m_ell(48, 97, 32, 3)
    pointe = m_poly([(56, 64), (70, 56), (76, 54), (70, 64), (62, 70)])
    ouverture = m_ell(48, 100, 19, 17)
    forme = (dome | bas | pointe) & ~ouverture
    h.part(forme, *vert, band=3)
    # Le revers interieur, plus sombre, autour de l ouverture.
    revers = dilate8(dilate8(ouverture)) & forme & ~ouverture
    h.part(revers, (34, 64, 48), (48, 88, 62), (26, 48, 38))
    return h.finish()


def hat_crown():
    """Couronne d or a cinq pointes, gemmes rouge et bleues."""
    h = Hat()
    bande = m_rect(29, 69, 67, 80)
    pointes = np.zeros_like(bande)
    for cx, top in ((31, 60), (39, 56), (48, 52), (57, 56), (65, 60)):
        pointes |= m_poly([(cx - 5, 70), (cx + 5, 70), (cx, top)])
    h.part(bande | pointes, *GOLD, band=2)
    for cx, top in ((31, 60), (39, 56), (48, 52), (57, 56), (65, 60)):
        h.part(m_ell(cx, top - 1, 2, 2), *GOLD, edge=False)
        h.dot(cx, top - 2, (255, 246, 200))
    h.part(m_ell(48, 74, 3, 3), (210, 54, 70), (250, 120, 120), (140, 30, 50))
    h.part(m_ell(37, 74, 2, 2), (66, 140, 220), (140, 200, 250), (40, 86, 160))
    h.part(m_ell(59, 74, 2, 2), (66, 140, 220), (140, 200, 250), (40, 86, 160))
    return h.finish()


def hat_feather():
    """Chapeau a large bord, carmin, longue plume blanche rejetee en arriere."""
    h = Hat()
    carmin = ((170, 52, 62), (216, 90, 92), (112, 32, 46))
    plume = m_poly([(56, 72), (62, 60), (70, 48), (80, 38), (88, 33), (84, 42), (76, 54),
                    (68, 66), (62, 74)])
    brim = m_ell(48, 80, 34, 8)
    calotte = m_ell(48, 70, 18, 12) & rows(0, 79)
    h.part(plume, (238, 236, 226), (255, 255, 250), (182, 188, 204))
    for i in range(5):
        h.dot(66 + i * 4, 64 - i * 6, (182, 188, 204))
    h.part(brim, *carmin)
    h.part(calotte, *carmin, band=3)
    h.part(calotte & rows(74, 79), (60, 40, 46), (90, 60, 66), (40, 26, 32))
    h.part(brim & rows(81, 92), *carmin)
    return h.finish()


def hat_turban():
    """Turban creme a plis, joyau turquoise et petite aigrette."""
    h = Hat()
    creme = ((232, 222, 196), (252, 248, 232), (184, 168, 138))
    bas = m_ell(48, 76, 28, 10)
    haut = m_ell(48, 66, 22, 11)
    aigrette = m_poly([(46, 60), (50, 60), (54, 44), (50, 46), (48, 40), (46, 47)])
    h.part(aigrette, (236, 140, 60), (252, 196, 110), (180, 90, 40))
    h.part(haut, *creme, band=3)
    h.part(bas, *creme, band=3)
    # Plis : diagonales d ombre qui donnent l enroulement.
    for k in range(-3, 4):
        x0 = 48 + k * 8
        pli = m_poly([(x0 - 2, 84), (x0, 84), (x0 + 8, 64), (x0 + 6, 64)])
        h.flat(pli & erode4(bas | haut), (200, 186, 154))
    h.part(m_ell(48, 68, 4, 4), (54, 178, 170), (140, 230, 220), (30, 112, 112))
    h.dot(47, 66, (230, 255, 250))
    return h.finish()


def hat_helm():
    """Heaume d acier : calotte, protege-joues, cimier rouge."""
    h = Hat()
    acier = ((150, 160, 178), (206, 214, 226), (96, 104, 124))
    # Cimier vu DE FACE : une brosse etroite et haute. Un arc creux (premier
    # essai) se lisait comme l anse d un seau.
    cimier = m_ell(48, 56, 5, 12) & rows(0, 64)
    calotte = (m_ell(48, 78, 28, 19) & rows(0, 84)) | m_rect(20, 78, 30, 92) | m_rect(66, 78, 76, 92)
    h.part(cimier, (196, 52, 52), (238, 104, 92), (128, 30, 40))
    h.part(calotte, *acier, band=3)
    h.part(m_rect(20, 80, 76, 85), (120, 128, 146), (170, 178, 194), (80, 86, 104))
    for x in (26, 38, 48, 58, 70):
        h.dot(x, 82, (232, 238, 246))
    return h.finish()


def hat_beanie():
    """Bonnet de laine rouge, revers blanc, pompon."""
    h = Hat()
    laine = ((206, 72, 64), (238, 118, 98), (148, 44, 46))
    blanc = ((236, 236, 230), (255, 255, 252), (190, 192, 200))
    dome = m_ell(48, 78, 26, 18) & rows(0, 80)
    h.part(m_ell(48, 56, 6, 6), *blanc)
    h.part(dome, *laine, band=3)
    for y in range(66, 79, 4):
        for x in range(28, 70, 6):
            if dome[y, x] and erode4(dome)[y, x]:
                h.dot(x + (y // 4) % 2 * 3, y, (170, 54, 52))
    h.part(m_rect(21, 77, 75, 85) & m_ell(48, 81, 28, 7), *blanc)
    return h.finish()


def hat_halo():
    """Aureole d or qui flotte au-dessus de la tete, sans la toucher."""
    h = Hat(outline=(176, 120, 36))
    anneau = m_ell(48, 52, 22, 7) & ~m_ell(48, 52, 16, 3)
    h.part(anneau, (250, 220, 110), (255, 248, 196), (214, 164, 56), band=2)
    for x, y in ((30, 48), (66, 49), (48, 44)):
        h.dot(x, y, (255, 255, 230))
    return h.finish()


def hat_laurel():
    """Couronne de laurier : feuilles en eventail autour du crane."""
    h = Hat()
    vert = ((92, 168, 80), (150, 210, 112), (52, 110, 58))
    feuilles = np.zeros((CELL_H, CELL_W), bool)
    # Treize feuilles le long de la moitie AVANT d une ellipse autour du crane
    # (angle de pi a 2 pi : de l oreille gauche a l oreille droite par le front).
    for i in range(13):
        ang = np.pi + i * (np.pi / 12.0)
        cx = 48 + 27 * np.cos(ang)
        cy = 76 - 8 * np.sin(ang)
        feuilles |= m_ell(int(round(cx)), int(round(cy)) - 3, 3, 5)
    h.part(feuilles, *vert, band=2)
    for x, y in ((30, 70), (48, 64), (66, 70)):
        h.part(m_ell(x, y, 2, 2), *GOLD, edge=False)
    return h.finish()


def hat_horns():
    """Cornes recourbees, os clair et pointes sombres."""
    h = Hat()
    os_ = ((232, 220, 196), (252, 246, 230), (170, 150, 120))
    pointe = ((96, 70, 66), (140, 104, 96), (62, 44, 44))
    gauche = m_poly([(26, 82), (38, 74), (34, 64), (26, 56), (16, 50), (12, 48), (16, 58),
                     (20, 68)])
    droite = gauche[:, ::-1]
    for corne in (gauche, droite):
        h.part(corne, *os_, band=2)
        h.part(corne & rows(0, 58), *pointe, band=1)
    return h.finish()


def hat_tophat():
    """Haut-de-forme du gardien du temps : ruban turquoise et cadran."""
    h = Hat()
    noir = ((54, 54, 72), (90, 90, 116), (30, 30, 42))
    brim = m_ell(48, 80, 28, 6)
    cylindre = m_rect(34, 44, 62, 79)
    h.part(brim, *noir)
    h.part(cylindre, *noir, band=3)
    h.part(m_ell(48, 44, 14, 4), (110, 110, 138), (140, 140, 166), (70, 70, 92))
    h.part(cylindre & rows(69, 76), (70, 151, 172), (120, 200, 210), (46, 104, 120))
    h.part(m_ell(48, 57, 7, 7), (240, 234, 214), (255, 252, 240), (196, 186, 160))
    for y in range(52, 58):
        h.dot(48, y, OUTLINE)
    for x in range(48, 52):
        h.dot(x, 57, OUTLINE)
    h.part(brim & rows(81, 90), *noir)
    return h.finish()


# Ordre = ordre des cases dans l atlas. AJOUTER EN FIN : les cles sont stockees
# dans les profils, l index ne l est pas, mais un ordre stable garde les
# captures comparables d une generation a l autre.
HATS = [
    ("hat_feather", hat_feather),
    ("hat_wizard", hat_wizard),
    ("hat_beanie", hat_beanie),
    ("hat_hood", hat_hood),
    ("hat_turban", hat_turban),
    ("hat_witch", hat_witch),
    ("hat_helm", hat_helm),
    ("hat_laurel", hat_laurel),
    ("hat_horns", hat_horns),
    ("hat_crown", hat_crown),
    ("hat_halo", hat_halo),
    ("hat_tophat", hat_tophat),
]


def atlas():
    """Une seule bande : un PNG au lieu de douze, l etape --import paie chaque fichier."""
    out = Image.new("RGBA", (CELL_W * len(HATS), CELL_H), (0, 0, 0, 0))
    for i, (_key, fn) in enumerate(HATS):
        out.alpha_composite(fn(), (i * CELL_W, 0))
    return out
