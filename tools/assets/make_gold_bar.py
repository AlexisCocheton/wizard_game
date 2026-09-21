"""Reteinte la barre d avancement du pack, rouge, en or.

Pourquoi un script et pas un modulate : la texture du pack est la barre de VIE,
rouge vif. Multiplier du rouge par de l or donne du rouge orange, jamais de l or
— c est ce qui rendait l avancement du profil identique a une barre de vie. Les
quatre couleurs de la planche sont donc remplacees une a une, ce qui preserve
l ombrage d origine.

Usage : python tools/assets/make_gold_bar.py   (depuis la racine du projet)
"""
from PIL import Image

MAP = {
    (178, 34, 73, 255):  (150, 108, 24, 255),   # ombre
    (255, 62, 62, 255):  (240, 196, 72, 255),   # corps
    (255, 167, 98, 255): (255, 238, 170, 255),  # lumiere
    (191, 49, 88, 255):  (168, 124, 34, 255),   # bord
}

# Le suffixe 9 est OBLIGATOIRE cote sortie : l AUDIT prend toute texture d UI
# sans ce suffixe pour une planche brute non decoupee.
SORTIE = {"bar_fill9": "bar_fill_gold9", "bar_fill": "bar_fill_gold"}

for nom in ("bar_fill9", "bar_fill"):
    im = Image.open("assets/ui/%s.png" % nom).convert("RGBA")
    px = im.load()
    w, h = im.size
    inconnus = set()
    for x in range(w):
        for y in range(h):
            c = px[x, y]
            if c[3] < 128:
                continue
            if c in MAP:
                px[x, y] = MAP[c]
            else:
                inconnus.add(c)
    if inconnus:
        raise SystemExit("couleur non prevue dans %s : %s" % (nom, list(inconnus)[:5]))
    im.save("assets/ui/%s.png" % SORTIE[nom])
    print("ecrit assets/ui/%s.png" % SORTIE[nom])
