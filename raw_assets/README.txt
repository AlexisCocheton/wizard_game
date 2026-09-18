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

--- Ajouts du 2026-09-18 (fonds de bataille et effets) ---
11 archives deposees a la racine du projet, rangees ici. Inventaire complet
ci-dessous, avec CE QUI EN EST PRIS et CE QUI EST ECARTE (et pourquoi).
Licence des packs craftpix : https://craftpix.net/file-licenses/ — gratuits pour
un usage commercial, redistribution des fichiers sources interdite. C est
precisement pour cela que ces zips restent ici, hors du depot.

RETENU
------
craftpix-net-593685-free-4-nature-backgrounds-for-rpg-battle.zip (194 Mo)
    4 saisons, chacune en couches separees + un PNG complet 3840x2160.
    PRIS : PNG/spring/6.png  -> assets/backdrops/act1_sky.png
           PNG/autumn/6.png  -> assets/backdrops/act4_origin.png
    L automne rejoue la composition du printemps dans une autre teinte : c est
    exactement l effet voulu par docs/histoire.md pour l acte final, ou le joueur
    doit reconnaitre le decor du niveau 1 « en faux ».

craftpix-net-889507-free-vampires-locations-battle-background-pack.zip (170 Mo)
    4 lieux (terrasse, salle du trone, chateau, foret morte).
    PRIS : PNG/4/dead forest.png  -> assets/backdrops/act2_graveyard.png
           PNG/2/throne room.png  -> assets/backdrops/act3_demon.png
    La foret morte EST un cimetiere (grilles, croix, tombes, ciel rouge).

VFX Free Pack.zip (90 Mo, 2084 PNG)
    22 effets, chacun en frames 30 et 60 fps + spritesheet + gif.
    PRIS : Effect_TheVortex -> assets/fx/vortex_hd.png
           Effect_Explosion -> assets/fx/boom_hd.png

Pipoya VFX HEXShield.zip (16 Mo)
    5 boucliers hexagonaux, grilles de 192 px (et 480 px).
    PRIS : pipo-btleffect206 -> assets/fx/shield_hex.png

ECARTE (et pourquoi)
--------------------
craftpix-net-298993-free-rpg-battleground-asset-pack.zip (137 Mo)
    4 ponts (bambou, foret, ciel, chateau). Beaux, mais tous batis autour d une
    PASSERELLE horizontale : le decor raconte qu on traverse de gauche a droite,
    alors que le jeu se lit de haut en bas. Le fond contredirait le mouvement.

free-demon-characters-pixel-art.zip
    8 demons en PORTRAITS STATIQUES (une pose, 4 visages). Aucune animation de
    marche : inutilisable comme monstre, et le jeu n a pas d ecran de dialogue
    ou un portrait servirait.

craftpix-net-809047-free-animated-magic-book-pixel-art-asset-pack.zip
    Livre de sorts anime + 40 icones. Joli, mais le deck du jeu est deja dessine
    (papiers recomposes, icones derivees du nom de carte) : remplacer l UI n est
    pas une amelioration, c est un autre parti pris.

free-pixel-magic-sprite-effects-pack.zip
    15 bandes de 72 px. Trop petites et trop pauvres (3 a 8 frames) face aux
    grilles de 100 px deja en place.

Pixel Holy Spell Effect 32x32 Pack 3.rar
    2 planches de 32 px. Meme raison : bien en dessous de l existant.
    NOTE OUTIL : ni unrar ni le module python rarfile sur ce poste, mais
    "C:\Program Files\7-Zip\7z.exe" lit le .rar (l x -o<dossier> fonctionne).

PIPOYA FREE VFX Mysterious Object.zip (63 Mo)
Pipoya VFX WarpPortal.zip
    Objets flottants et portails. Aucun crochet de jeu : pas de sort de
    teleportation, pas d objet ramassable. Beaux mais sans emploi.

--- Ajout du 2026-09-18 (effets et sons PROPRES a chaque sort) ---
Effect and FX Pixel All Free.zip (28 Mo, 180 PNG en 15 dossiers "Part N")
    FORMAT VERIFIE : chaque PNG est une grille de cases 64x64, 9 LIGNES x 5 a
    23 COLONNES. Une LIGNE = une animation complete ; les 9 lignes = 9 TEINTES
    du meme effet (0 rouge-orange, 1 violet, 2 bleu, 3 vert, 4 orange/brun,
    5 blanc, 6 brun-mauve terne, 7 rouge, 8 bleu-violet sombre).
    PIEGE : la premiere case de chaque ligne est une amorce presque vide, les
    images grossissent au fil de la ligne. Le GIF d apercu tourne a 60 ms/image
    (16 fps).
    PRIS : 45 effets (une ligne chacun) -> assets/fx/<nom>.png, par
    tools/assets/extract_fxpack.py (TABLE nom -> (part, fichier, ligne)).
    Chaque carte non passive a SA feuille (AUDIT _check_card_fx). Planches-
    contact des 180 effets : relancer le script de contact du scratchpad ou
    ouvrir les "Preview Free N.gif".
    LICENCE : aucun fichier de licence dans le zip. A verifier sur la page du
    pack avant publication.
FreeSFX.zip, 400 Sounds Pack.zip (deja presents)
    PRIS EN PLUS : 21 sons de sorts -> assets/sfx/<cle>.wav (table SOUNDS du
    meme script) : Retro Magic 06/11/34/54, Retro Magic Electric 03, Retro
    Magic Protection 01/25, Retro Charge Magic 11, Retro Electric 02/21, Retro
    Explosion Short 01/15, Retro Explosion Long 02, Retro Impact 20, Retro
    Weapon Laser 03, Retro Water Drop 01, Retro Cinematic Wind 02,
    fire_lighting, whoosh_1, whoosh_2, stone_push_short.
