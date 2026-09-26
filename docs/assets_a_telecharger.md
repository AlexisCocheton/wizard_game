# Assets a telecharger a la main — itch.io

> **Mise a jour du 2026-09-26.** 47 archives sont arrivees dans
> `raw_assets/packs_2026_09_26/` (1,6 Go). L audit de licence et l inventaire
> sont dans `docs/assets_index.md`, sections 5 et 6. Ce qui suit ne liste plus
> que **ce qui manque encore**, plus les quatre points a regler.

## CE QUI DEMANDE UNE ACTION DE TA PART

### 1. Verifier une licence — MAGE ICONS BIG PACK (Batareya)

`MAGE ICONS BIG PACk (by Batareya).rar` contient **250 PNG et rien d autre** :
aucun fichier de licence. Or **42 des 60 icones de sorts du jeu en viennent**.

Ouvre https://batareya.itch.io/250-magical-icons-pixel-art-icons et lis la
section « License » sous le bouton de telechargement. Si elle dit
« non-commercial », il faut refaire les deux tiers des icones a partir des packs
craftpix, qui sont deja sur le disque et couverts. C est le point le plus
urgent du lot.

### 2. Retelecharger — Phoenixling

`Phoenixling Sprite Sheet.json` est arrive **seul**. Le .json decrit une image
`Phoenixling Sprite Sheet.png` de 1024x384 (96 frames de 64x64, 6 animations :
Idle, Movement, Attack, Damage, Death, Rebirth) qui **n a pas ete livree**.
Sans elle le .json ne sert a rien.

### 3. Prevenir un auteur — Mage Voice Pack

`Mage Voice Pack.zip` ne contient **aucun png** : ce sont **130 fichiers .wav**,
des repliques vocales de sorcier (attaque, incantation, degats, mort, feu, gel,
foudre, invocation, bouclier, rires, oui/non, bonjour/au revoir...). 44 d entre
elles sont extraites dans `assets/voice/`.

Son readme demande : « If you use any of these sound clips, please let me know! »
Un courriel a `itsjohncarroll@gmail.com` avant publication suffit.

### 4. Supprimer 920 Mo de doublons — ttrpg_legend

Les cinq archives `ttrpg_legend_too-many-charaters_1.0*.zip` sont **le meme
fichier** (meme CRC32 `10AFB580`). Tu voulais cinq packs ddant1100 differents ;
c est cinq fois le meme telechargement qui est arrive. Garde
`ttrpg_legend_too-many-charaters_1.0.zip`, les quatre suffixees `(1)` a `(4)`
peuvent partir.

Les quatre autres packs ddant1100 restent a telecharger si tu les veux :
- https://ddant1100.itch.io/ttrpg-legacy-characters-4
- https://ddant1100.itch.io/ttrpg-legacy-characters-5
- https://ddant1100.itch.io/ttrpg-legay-characters-3
- https://ddant1100.itch.io/ttrpg-legay-characters

---

## CE QUI MANQUE ENCORE

Ces packs de ta liste ne sont pas arrives. Ils restent utiles, mais aucun n est
bloquant : ce qui est arrive couvre deja les trois besoins principaux (icones,
portraits humains, silhouettes de monstres).

### Monstres et boss

- https://chierit.itch.io/boss-frost-guardian
- https://penusbmic.itch.io/sci-fi-character-pack-9
- https://kindeyegames.itch.io/c3-3dobject-alpha
- https://rvros.itch.io/pixel-art-animated-slime *(le zip `Slime.zip` arrive vient d une autre source)*

### Effets et decors

- https://pimen.itch.io/dark-spell-effect *(seul `Dark VFX 01 - 02.rar` est arrive)*
- https://seraphcircle.itch.io/sc-anime-essentials *(`Essentials.zip` est arrive SANS licence — voir §5.2)*
- https://codemanu.itch.io/pixelart-effect-pack *(deja sur le disque depuis le premier lot)*

### Interface

- https://oddsandents.itch.io/paper-texture-pack *(texture des cartes)*

### Skins du mage

- https://9e0.itch.io/witches-pack *(seule `Blue Witch.zip` est arrivee, soit une sorciere sur les six)*

### Deux fichiers a rapatrier proprement

`Cacodaemon Sprite Sheet.png` et `Fox Sprite Sheet.png` sont arrives **nus**,
sortis de leur archive, donc sans leur fichier de licence. Ils viennent
d elthen. Retelecharge les archives completes si tu veux les utiliser :
- https://elthen.itch.io/2d-pixel-art-cacodaemon-sprites
- https://elthen.itch.io/2d-pixel-art-fox-sprites

---

## CE QUI EST ARRIVE ET EXPLOITE

Extrait dans `assets/` par `tools/assets/extract_packs_2026_09_26.py` :
14 creatures animees dont **3 boss** (slime demoniaque, epeiste d ombre,
bourreau a faux) et 6 effets dont le **premier effet d ombre** du jeu et une
**horloge** pour le sort de vitesse.

Disponible, non extrait, laisse aux chantiers concernes : les 7 packs d icones
(520 icones 512x512), les ~200 avatars et 41 decors elfiques, les 29 boutons de
menu, le tileset Ancient Ruins. Detail en section 6 de `docs/assets_index.md`.

Ecarte : Lords Of Pain (isometrique 16 directions), Free Sprites, Fairy,
Essentials (doublon + licence inconnue), les 4 copies ttrpg. Raisons en
section 6.4.

---

## Note sur itch.io

itch.io refuse toute requete de l assistant (403 systematique, y compris avec un
en-tete de navigateur et avec l outil de recuperation dedie). Ce n est pas une
question de compte : le refus arrive **avant** toute authentification. Ces packs
doivent donc etre telecharges depuis ton navigateur.

**Craftpix, lui, est automatise** : `tools/assets/fetch_craftpix.py` les
recupere avec ta session.

Les archives vont **a la racine du projet**
(`C:\Users\Lenovo\Desktop\wizard_game\`). Je les range dans `raw_assets/`, je
verifie la licence, j extrais et je branche. Pas besoin de renommer quoi que ce
soit.
