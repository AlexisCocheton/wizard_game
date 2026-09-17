Packs bruts fournis par Alexis (17/09/2026). Dossier ignore par Godot (.gdignore).
Extraire UNIQUEMENT les feuilles utilisees dans assets/, jamais tout le pack :
chaque PNG dans res:// est importe a chaque run du harnais.

Contenu :
- Tiny Swords (Free Pack) : Units (243 png), UI Elements, Terrain, Buildings, Particle FX
- Tiny RPG Character Pack 02 : Demon_A, Blood Monster_A (spritesheets 100x100)
- Free Pixel Effects Pack : 20 spritesheets de sorts (magicspell, bluefire, freezing, felspell...)
- explosion pack 1 : 103 explosions
- SpaceBackgroundSource : projet Godot 3 de fond etoile (a convertir si utilise)
- godot-pixel-effect-windows : outil externe
- 400 Sounds Pack, FreeSFX : ~620 wav
- 28 High Quality 16-bit RPG Music, xDeviruchi : musiques (ogg/mp3/wav)

--- Ajouts du 2026-09-17 (monstres) ---
FlyingForestEnemies_FREE.zip  : insecte volant (Enemy3), bandes de 64x64.
Golems_Free_Version.zip       : Golem_1 en bleu et orange, cases de 90x64
                                (la case est large pour loger le balayage de
                                l attaque, le monstre ne fait que ~42 px).
Peacock-*-Sheet.png           : paon, grille 4 colonnes x 3 lignes de 32x32
                                (une ligne par direction ; on extrait la ligne 0).
Verifier les licences de ces trois packs avant publication.
Enemies Pack FIles.zip        : chien, scarabee, dino, slime, vautour. Les feuilles
                                assemblees de spritesheets/ ont des largeurs
                                irregulieres : composer les bandes depuis
                                Assets/Sprites/<Creature>/<nom><n>.png.
                                PIEGE : le dossier "Slimer" est l animation de MORT
                                (la gelee fond puis eclate), "Slimer-Idle" est la
                                boucle vivante.
Duelyst-Unit-Animations.unitypackage : 696 unites (51 boss), chacune avec course,
                                repos, attaque, coup recu et mort. Archive tar.gz
                                de dossiers <guid>/{asset,pathname} ; chaque unite
                                est un ATLAS irregulier decrit par un .plist.
                                Extraire avec tools/assets/extract_duelyst.py
                                (ajouter l unite voulue dans WANTED).
                                Style plus fin et sombre que Tiny Swords : reserve
                                aux boss, dont la silhouette doit trancher.
