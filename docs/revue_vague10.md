# Revue globale — vague 10 (chantier A4)

Revue du 14/10 : ce qui est resté en deçà des parties les plus avancées du jeu
(sprites, animations, sons, monstres, textes d'histoire). Ce document est l'entrée
des chantiers de contenu de la phase B : **B2** (mécaniques de monstres) et **B4**
(écriture). Les citations `fichier:ligne` renvoient à l'état de `main` au
3 octobre au soir (commit `a7cdcdc`). Pendant la revue, les chantiers écrans
(`97066f6`) et progression (`ca1308e` : modes Campagne / Libre, Infini retiré,
déblocages refaits) ont été fusionnés : les numéros de ligne de
`save_data.gd`, `campaign_panel.gd`, `loading_screen.gd` et `game_controller.gd`
ont pu bouger, et les constats de déblocage (§2.2 n° 2 et 6) sont à revérifier
sur le nouveau code. Les répliques proposées sont **sans accents**, comme toute
donnée affichée par le jeu (la police n'en a pas).

---

## 0. Ce que A4 a déjà corrigé (pour mémoire)

| Constat | Correction | Vérification |
|---|---|---|
| Les animations de mort n'étaient **jamais** jouées : toute mort était la même explosion (`battlefield.gd:541`, `fx.gd` `death`) alors que 37 feuilles du catalogue portent une pose `death` (57 monstres sur 86) | Un **cadavre** (copie du dessin, sous les vivants, sans effet de jeu) joue la pose ; un boss s'effondre **puis** explose ; une feuille sans pose s'affaisse sous l'explosion historique. La logique n'attend rien | `test_audio_w10` (plan de mort) ; vitrine `shot_*_mort_animee` (contrôle : chaque cadavre joue `death`, aucun ne reste à l'écran) |
| 45 monstres sur 86 (27 feuilles) sans pose `hurt` : seul un flash de 0,2 s disait le coup | Retour de coup **générique** : écrasement, recul vers le haut, bascule, flash chaud | vitrine `shot_*_retour_de_coup` (contrôle : retour exact à la taille, au décalage, à la teinte) |
| **Défaut trouvé en route** : deux coups à moins de 0,19 s (pluie de météores, Combustion, zone + projectile) laissaient le monstre **blanc incandescent pour tout le combat** (le second flash prenait le blanc du premier pour la teinte de repos) | Teinte de repos mémorisée le temps du flash | sabotage vérifié : ancien code → 8 échecs dans la vitrine (teinte figée à 3,0 / 3,6) |
| Ymoa, son Écho, Totem ancien, Gardien-totem : image fixe, aucune animation | La tour flotte, s'illumine, un anneau de runes pulse à son pied, l'aura respire et passe **derrière** la tour (elle la recouvrait en vert) | vitrines `shot_*_totem_anime_1/2` (contrôle : la tour bouge, l'anneau existe) |
| Son : une mort, un coup, un bruit pour tous les objets, `shield_break` à tout faire (et c'est le **même fichier** que `ward_deep`), 21 sons pour 53 sorts dont des sorts de glace sur un grésillement électrique, une musique de combat pour 21 niveaux, voix extraites jamais jouées, `cast_zone` et `speed_up` jamais joués | 15 familles sonores de monstres, un son par objet de terrain et par mécanique, un son par sort (2 sorts au plus par son, cohérent avec l'élément), musique **par acte** + boss final + Massacre, répliques par élément au lancement (repit 9 s, une chance sur deux), début de niveau, épuisement, vitesse au plafond ; gains **mesurés** (18 dB d'écart ramenés par catégorie), cadence plafonnée (50 ms, 3 exemplaires), hauteur variée des sons fréquents | `test_audio_w10` (1 649 vérifications ; sabotage : 5 échecs) |

Restent à faire ailleurs : voir §3 et §4.

---

## 1. Monstres fades — pour le chantier B2

Vérifié sur les 86 `.tres` comparés aux valeurs par défaut d'`enemy_def.gd`.
`kind` (TANK, FAST…) n'est qu'une étiquette : seuls BOSS et MINIBOSS changent
quelque chose (`enemy_def.gd:605-618`). Les `.tres` sortent de
`tools/make_content.gd` : c'est là qu'il faut écrire, puis **remesurer au banc**
les niveaux concernés. Les valeurs sont des ordres de grandeur.

Aucun des 16 monstres ci-dessous ne joue jamais son anim `attack` : les seuls
appels sont `battlefield.gd:170, 389` et `enemy.gd:1165, 1500, 2227, 2243, 2499`,
et un monstre au contact est libéré aussitôt (`battlefield.gd:655-659`).

### 1.1 Onze ordinaires sans aucun comportement (PV, vitesse, résistances seulement)

| id | nom | P / PV / vitesse | feuille, anims | où il sort |
|---|---|---|---|---|
| gnome | Gnome | 1 / 12 / 70 | pawn_red : walk, idle | 14 vagues, actes I à V |
| sprite | Lutin fileur | 1 / 6 / 150 | beetle (coccinelle) : walk | 26 vagues lvl_01 à lvl_16 ; 4 par Ruche |
| golem | Golem de pierre | 3 / 55 / 32 | golem_blue : walk, idle, hurt, attack, death | 10 vagues (lvl_02, 05, 07, 12, 13) |
| behemoth | Behemoth | 4 / 130 / 26 | golem_orange : idem | lvl_04, 05, 07, 13, 15 |
| mushroom | Champignon cuirassé | 2 / 34 / 34 | mushroom : walk, idle, attack, hurt, death | lvl_07, lvl_10 |
| carnivore_plant | Plante carnivore | 2 / 12 / 88 | smallmonster : walk, idle, attack (crachat), death | lvl_07, lvl_10 |
| chronos_echo | Écho de Chronos | 4 / 96 / 36 | juggernaut teinté | lvl_15, lvl_16 |
| jelly_small | Gelée (petite) | 1 / 6 / 85 | slimer : walk, idle, death | naît de la Gelée moyenne |
| slime_mid | Slime moyen | 1 / 12 / 72 | slime_big : 5 anims | lvl_03 ; 3 par Slime énorme |
| slime_skeleton | Slime squelette | 2 / 16 / 60 | slime_skeleton : 5 anims | lvl_19 ; renaissance des slimes fantômes |
| risen_ghoul | Goule levée | 1 / 9 / 62 | vulture (vautour brun) : walk, idle | lvl_15 ; sbire de l'Ensevelisseur et du Bourreau |

Propositions (une mécanique chacun ; « réutilise » = champ existant d'`EnemyDef`) :

1. **gnome — « En colonne »** : un gnome qui apparaît reprend l'abscisse (±16 px)
   du dernier gnome vivant apparu depuis moins de 3 s. Aucune stat ne change (il
   reste le monstre de référence, `make_content.gd:177-180`). Lisible : une file
   indienne. Contre-jeu : Flèche perçante (trois au deck de lvl_01, objectif « 9
   Flèches perçantes »). Justifié par l'intro de lvl_01 (« ils marchent en
   colonne », `lvl_01.tres:158`). Nouveau verbe léger au tirage de l'abscisse.
2. **sprite — « Détale »** : réutilise `move_pattern = HOP`, `pattern_width` ≈ 100,
   `pattern_interval` ≈ 1,2 (seul porteur actuel : adept_arcane). Risque : 26
   vagues dont la vague de boss du tutoriel (6 Lutins) → remesurer, ou un dérivé
   réservé aux Lutins des Ruches. `flying` collerait à la coccinelle mais
   annulerait les murs dans 26 vagues : déconseillé.
3. **golem — « Éboulis »** : à sa mort, un tas de pierres = mur temporaire d'une
   case pendant ~3 s, qui détourne ce qui marche derrière (les volants passent).
   La pose `death` de golem_blue (désormais jouée) le montre. Nouveau verbe sur
   les murs (`battlefield.gd:316-327`, `nav.block_cells`), en respectant DEC-021
   (un objet ne coupe jamais la route du mage). Pas `hits_immune` : il
   deviendrait indiscernable de l'Écho de Vharn (même feuille).
4. **behemoth — « Piétinement »** : réutilise l'onde de choc (seul porteur : le
   Bourreau) : `shockwave_interval` ≈ 4,5, `shockwave_radius` ≈ 170,
   `shockwave_damage` ≈ 3. L'onde frappe murs et arbres à ×6
   (`battlefield.gd:431`) et ne touche le mage qu'à moins de 170 px. Son `attack`
   (coup au sol) est déjà jouée par `enemy_shockwave`. Réserves :
   `enemy_def.gd:134-136` veut un porteur d'onde immobile (vrai pour les grands
   rayons) ; recoupe en partie le Briseur (même feuille, brise aussi le décor).
5. **mushroom — « Sporée »** : réutilise la renaissance (seuls porteurs : slimes
   fantômes) : `rebirth_def` = « Pousse » (feuille mushroom réduite, P1, 8 PV),
   `rebirth_count` = 2, `rebirth_delay` = 3. Contre-jeu : zone de feu sur la
   marque (×2 au feu). Son commentaire dit déjà « il baigne dans ses propres
   spores » (`make_content.gd:836-837`).
6. **carnivore_plant — « Crache-graine »** : réutilise `shoot_interval` ≈ 3,5,
   `shot_damage` = 2 (option `keeps_distance_at` ≈ 560). Sans pose de tir,
   `shot_anim` retombe sur `attack`, qui EST le crachat. Contre-jeu : Mur de
   pierre (arrête les tirs) ; ×2 au feu et au givre. Corrige le commentaire « la
   plus longue morsure » (`make_content.gd:841-843`) que le dessin contredit.
7. **chronos_echo** : version simplifiée de l'« Échéance » de Chronos (§1.2) :
   fenêtre de 2 s toutes les 10 s ; s'il n'est pas frappé, seul l'Écho gagne
   +40 % de vitesse 3 s. Dépend du verbe de Chronos (DEC-025 : l'écho simplifie).
8. **jelly_small — « Se rassemble »** : deux petites gelées à moins de 40 px
   pendant 2,5 s fusionnent en Gelée moyenne, une fois par lignée (l'outro de
   lvl_03 parle d'un corps qui « se sépare et se rassemble »). La moins
   prioritaire : une fin de chaîne sans rien se défend.
9. **slime_mid — « Bond »** : réutilise `burst_move` (élan ≈ 0,4 s, pause ≈ 1 s),
   jouer `attack` (le bond de slime_big) au départ. Contre-jeu : la zone sur son
   point d'arrêt. Le distingue de la Gelée qui marche droit.
10. **slime_skeleton — « Crâne »** : réutilise `first_hit_shield`. Une zone posée
    sur la marque de renaissance brise le bouclier à la première morsure
    (exception DEC-054, `enemy.gd:705-715`) : la mécanique récompense le geste que
    la renaissance enseigne.
11. **risen_ghoul — « Charognard »** : réutilise `flying` et renommer
    « Charognard levé » (ou passer à la feuille `ghoul` teintée). Le flux de
    l'Ensevelisseur et du Bourreau passe alors les murs, et la seule réponse
    redevient « tuer la source » (`make_content.gd:472-474`). Aujourd'hui : une
    « goule » dessinée en vautour qui contourne les murs.

### 1.2 Cinq têtes sans mécanique (+ deux cas limites)

`tools/make_content.gd:402-465` ne leur pose que `_resist`.

**Chronos** — boss P10 (320 PV, joué à 192 au lvl_01). Feuille juggernaut (bête
de cristal, attaque en tornade). Boss du **tutoriel** et des paliers du
Massacre ; « un huissier venu vérifier les délais » (`lvl_01.tres:159`).
Contrainte : « le boss qui récompense un deck SIMPLE » (`make_content.gd:463`),
`test_balance` le tient sous la médiane.
- **M1 « Échéance »** (nouveau verbe, calqué sur le cycle du renvoi
  `enemy.gd:1021-1077`) : toutes les ~9 s il se plante 2 s et joue `attack` ; un
  sablier et « ECHEANCE 2 s » dans `mech_caption`. Au moins un COUP pendant la
  fenêtre (un continu ne compte pas, DEC-054) : échéance honorée, étourdi 1 s.
  Sinon : le mage perd ~6 points de vitesse. L'inverse exact du Miroir : la seule
  mécanique où **ne pas** frapper coûte. Contre-jeu : garder une carte rapide
  (3 Traits arcaniques, 3 Flèches au deck de lvl_01).
- **M2 « Avance rapide »** (option, une fois à 50 % PV) : les monstres au-dessus
  de mi-écran avancent de 1,5 s de marche (≤ 100 px). À retirer si le banc de
  lvl_01 bouge (6 Lutins dans la vague de boss).

**Gardien (warden)** — mini-boss P6 (140 PV), feuille chaosknight (moulinet
d'attaque jamais joué). Palier de lvl_01 et **boss** de lvl_09 (fin de
l'acte I). « Retourné », plaque noire dans la poitrine. Incohérence : son Écho a
`first_hit_shield`, présenté comme version simplifiée de « l'armure lourde du
Gardien » (`make_content.gd:1951-1953`) — que le Gardien n'a pas.
- **M1 « Armure qui se referme »** : `first_hit_shield` + nouveau paramètre
  `shield_regen` ≈ 5 s (sans coup reçu pendant 5 s, le bouclier revient).
  Contre-jeu : enchaîner, une zone, une dissipation. L'Écho redevient cohérent.
- **M2 « Il se débat »** (une fois à 50 % PV) : s'arrête 2 s, remonte ~60 px,
  encaisse ×1,5 (pose `hurt` + plaque qui rougeoie). Contre-jeu : garder le
  Météore (deux au deck de lvl_09).

**Gardien d'ossements (bonewarden)** — mini-boss P6 (165 PV), feuille
warrior_black dont la pose `guard` (bouclier levé) n'est jamais jouée. Une seule
vague écrite (lvl_03 w3_5, tolérée par exception `test_bosses.gd:1043-1045`) et
le monde Grand Cimetière du Massacre.
- **M1 « Garde levée »** : toutes les ~6 s, garde de 2,5 s qui bloque ~85 % des
  **coups** (le continu passe). Étendre le cycle du renvoi d'un
  `reflect_block_pct` avec `reflect_pct = 0` : cycle, son et pose `guard` existent.
  Il lui faut un autre signe que le sigle ambre du renvoi. Contre-jeu : zones de
  feu (×1,75), le rythme, l'étourdissement. Prépare le Reliquaire, boss du même
  niveau, qui compte les coups.

**Seigneur de braise (emberlord)** — mini-boss P6, feuille **pawn_purple** (un
paysan au couteau, walk/idle seulement). lvl_05 w5_5 et palier de lvl_09. Son
commentaire promet « Il rend les coups » (`make_content.gd:440`) : rien ne le fait.
- **M1 « Riposte de braise »** : réutilise `laser_damage` ≈ 3, `laser_cooldown`
  ≈ 2 (seul porteur : Golem à noyau) : chaque coup qui mord renvoie une braise ;
  ni zone ni poison ne la déclenchent. Contre-jeu : peu de gros coups, des zones,
  le givre (×2).
- **M2 « Fonte »** (option) : toutes les 4 s, efface les ralentissements sur lui
  et ses voisins à 180 px.
- **Feuille à changer** (le paysan violet contredit le nom ; aucune feuille libre
  au catalogue) : passer par asset-pipeline.

**Totem ancien (totem_elder)** — mini-boss P6 (175 PV), image fixe (désormais
animée par A4). **La silhouette ment** : présenté comme une « promotion du
Gardien-totem » (`make_content.gd:448-456`), il n'a **pas d'aura**
(`totem_elder.tres:41`, `aura_shield_radius = 0.0`) alors que `test_bosses.gd:1049-1055`
justifie ses trois apparitions par « porteur d'aura ». Le grand totem fait moins
que le petit.
- **M1 « Aura ancienne »** : `aura_shield_radius` ≈ 180 (halo, dissipation et
  respiration A4 déjà en place). DEC-057 l'imposera à lvl_08, sans dissipation :
  y ajouter la Lumière purifiante. Remesurer w7_4, w8_4, w12_3, w13_4.
- **M2 « Ancrage »** (nouveau verbe) : sous son aura, aspiration, recul et
  volte-face sont ignorés. Contre-jeu : dissiper d'abord. Sans code :
  `summon_def` = totem_guardian, `summon_interval` = 12, `summon_max_alive` = 1.

**Cas limites** : l'**Écumeur du ciel** (skyreaver) n'a que `flying` sur une
feuille de paysan sans ailes (lvl_02 w2_6, palier de lvl_11) → **« Piqué »** :
`burst_move` (élan ≈ 0,6 s, pause ≈ 1,2 s), la pause montre où poser la zone
(`make_content.gd:422-424` l'annonce). **Sesh** (`demon_maw`), boss, n'a que
`devours`, le verbe du Glouton P4 → voir « L'outre » ci-dessous.

### 1.3 Autres constats

- **Doublons feuille + comportement** : Chronos et son Écho (rien des deux côtés,
  seules teinte et taille les séparent) ; Glouton, Sesh et l'Écho de Sesh (feuille
  `dino`, verbe unique `devours`). L'outro de lvl_10 (`lvl_10.tres:223`) dit « ce
  qu'il avait avalé ressort intact et vivant » alors que la proie est détruite
  (`battlefield.gd:191-194`, `enemy.gd:2280-2290`). **Proposition « L'outre »** :
  Sesh garde au plus 5 proies et les relâche à sa mort, avec une marque.
- **Presque fades** : pit_ghoul et rat_swarm n'ont que `swarm_count` ;
  nacelle_raider que `entry_side`.
- **Animations jamais jouées** (le code ne demande que walk, idle, hurt, attack,
  guard, sleep, shoot, laser — et `death` depuis A4) :
  - `guard` (warrior_black, lancer_purple, mechagolem) : seul chemin = garde de
    renvoi, dont aucun porteur n'a la pose. Gardien d'ossements (§1.2), Chevalier
    du vide (`guard` tant que son bouclier tient), Golem à noyau (`guard` pendant
    la recharge du laser).
  - `shield` : le Squelette pareur (`first_hit_shield`) ne pare jamais à l'écran.
    **Une ligne** : jouer `shield` au coup absorbé (`enemy.gd:705-715`).
  - `cast` (monk_black, monk_purple, monk_blue) : le soin du Prêtre goule appelle
    `play_attack` (`battlefield.gd:170`), que sa feuille n'a pas — aucun geste,
    alors que `monk_black_cast` montre des croix vertes de soin. `play_attack`
    devrait retomber sur `cast` (Prêtre, Corniste, Miroir).
  - `glow` (mechagolem) : à jouer quand le laser est rechargé.
  - `summon` (executioner) : invocation (`enemy.gd:1165`) et onde
    (`battlefield.gd:389`) jouent toutes deux `attack`. Jouer `summon` à l'invocation.
- **Dessin, nom et mécanique qui se contredisent** : la Ruche (chevalier jaune
  qui éclate en coccinelles), le Serpent des sables (un lancier), l'Écumeur (un
  paysan qui vole), le Seigneur de braise (un paysan violet), la Goule levée (un
  vautour), la Plante carnivore (« morsure » dans le commentaire, crachat dans le
  dessin), le Gardien d'ossements (un guerrier vivant, pas d'os), **Ymoa, le
  Cercle** (un seigneur démon dessiné en tour de Tiny Swords, la même que le
  Gardien-totem P4 : la tête de l'acte IV ressemble à un monstre ordinaire).
- **Mécaniques à un seul porteur** (vues une fois en campagne) : onde de choc
  (lvl_06), réanimation (lvl_21), laser (lvl_07), parties (lvl_05), retour
  arrière (lvl_15), jumeaux (lvl_12), caméléon (lvl_14), vol de carte (lvl_15),
  dévoreur qui se soigne (lvl_13), miroir de vitesse (lvl_19), briseur (lvl_04).
  Réemplois proposés ci-dessus : laser → Seigneur de braise ; onde → Behemoth ;
  sauts → Lutin ; renaissance → Champignon ; tir → Plante ; aura → Totem ancien ;
  à-coups → Slime moyen, Écumeur ; vol → Goule levée ; cycle du renvoi → Gardien
  d'ossements.

### 1.4 Priorités suggérées

1. L'aura du Totem ancien (c'est déjà la promesse écrite dans `test_bosses`).
2. Les poses en une ligne : `shield` du Squelette pareur, `cast` du Prêtre.
3. La garde du Gardien d'ossements (cycle et pose existent).
4. La riposte du Seigneur de braise (réemploi de champs).
5. Les nouveaux verbes de Chronos et du Gardien, avec remesure du tutoriel.
6. L'outre de Sesh.

---

## 2. Histoire — pour le chantier B4 (lecture seule, rien n'a été réécrit)

**Ce qui tient** : les 39 `.tres` de `resources/story/` sont identiques à
`tools/make_story.gd` ; aucun accent dans les scènes ; noms propres sans variante
(Ymoa, Vharn, Kaltek, Sesh, Malyk, Tombol, Nuri, Nox, Haute-Nacelle, Sky Lands) ;
une seule réplique dépasse 180 caractères (`lvl_03_outro`, `make_story.gd:318`) et
rien ne déborde de la boîte (~54 car. × 7 lignes).

**À savoir** : `LevelDef.intro_text` / `outro_text` ne sont affichés **nulle
part** (déclarés `level_def.gd:16-18`, jamais lus dans `scripts/`). Le joueur voit
le nom d'acte, `display_name`, `subtitle` (`campaign_panel.gd:213-220`), « Boss : »
(`campaign_panel.gd:253-270`) et le briefing (`loading_screen.gd:73-92`).

### 2.1 Niveau par niveau

Ordre de jeu : 01, 02, 08, 09 | 17, 18, 03, 04 | 19, 20, fourche 05 ou 06, 21 |
07, 10, 11, 12 dans l'ordre libre, puis 13 | 14, 15, 16.

| Niveau | Titre affiché | Acte | Fond / décor de scène | Mini-boss → boss | Scènes | Problème |
|---|---|---|---|---|---|---|
| lvl_01 | Les Marches du Temps | I | act1_sky / talk_glade | Gardien → Chronos | oui / oui | titre de l'ancienne histoire ; le Gardien meurt ici puis est présenté en allié au lvl_09 ; Chronos jamais nommé |
| lvl_02 | La Tour des Sables | I | act1_sky (sable) / talk_village | Matrone gorgone (+ Écumeur) → Coagulé (+ Reine gorgone) | oui / oui | titre et sous-titre de l'ancienne histoire, scènes au village ; « le corniste tombe en dernier » faux ; gorgones absentes du texte |
| lvl_03 | Ossuaire des Marees | II | act2_graveyard / talk_shrine | Slime énorme (+ G. d'ossements) → Reliquaire | oui / oui | boss jamais évoqué ; réplique de 182 car. |
| lvl_04 | Le Grand Appel | II | act2_graveyard / talk_greattree | Briseur → Ensevelisseur | oui / oui | « on regarde ce qui sort » sans réponse ; cimetière joué devant un arbre vert |
| lvl_05 | Forges du Mauvais Temps | III | act3_demon / — | Miroir de Forge → Colosse | **non / non** | monde démoniaque montré avant la révélation de lvl_21 ; titre de l'ancienne histoire |
| lvl_06 | La Cour brisee | III | act3_demon / — | Bourreau → Seigneur Spectre | **non / non** | « seigneurs démoniaques » avant de les rencontrer |
| lvl_07 | La forge de Vharn | IV | act3_demon | Golem à noyau (+ Totem ancien) → Vharn | **écrites, non branchées** | `lvl_07.tres:308-309` vides |
| lvl_08 | La route du maire | I | act1_sky / talk_path | Totem ancien → — | oui / oui | seule scène où le mage parle à droite |
| lvl_09 | Proteger le dirigeable | I | act1_sky / talk_greattree | Seigneur de braise → Gardien | oui / oui | Gardien déjà tué ; « tas de bois mort » pour un chevalier en armure |
| lvl_10 | Les fosses de Sesh | IV | act3_demon / talk_path | — → Sesh | oui / oui | « jamais rien signé » contre « quatre contrats » |
| lvl_11 | L arene de Kaltek | IV | act3_demon / talk_path | Écumeur → Kaltek | oui / oui | « arène de sable noir » devant une cabane ; locuteur « Un demon » |
| lvl_12 | Le temple d Ymoa | IV | act3_demon / talk_shrine | Jumeaux → Ymoa | oui / oui | l'outro suppose qu'Ymoa est le quatrième |
| lvl_13 | Le pentacle brise | IV | act3_demon / talk_shrine | Reine gorgone → Malyk | oui / oui | s'ouvre après UN démon ; Malyk et la Reine jamais nommés ; la Reine est déjà morte au lvl_02 |
| lvl_14 | La galerie des saisons | V | act5_divine / talk_shrine | Caméléon → Slime colossal | oui / oui | « personne n est venu defendre la galerie » après un combat de boss |
| lvl_15 | Le registre | V | act5_divine / talk_shrine | Greffier → Horloger | oui / oui | l'Horloger jamais évoqué ; « souligne » ×3 |
| lvl_16 | Le siege vide | V | act5_divine / shrine puis glade | — → L'Enfant | oui / oui | « MODE INFINI DEBLOQUE » faux ; ni le Rat ni le Roi n'ont d'adieu |
| lvl_17 | Les courants | II | act1_sky / talk_path | Grand Œil → — | oui / oui | l'outro fait tomber l'Écumeur, absent du niveau |
| lvl_18 | Port de Haute-Nacelle | II | act1_sky / talk_path | Mage noir → — | oui / oui | Mage noir jamais nommé ; « sur ses propres soudures » obscur |
| lvl_19 | Les fosses basses | III | act2_graveyard / talk_shrine | Sorcière des fosses → trio | oui / oui | « Pretres des fosses » n'existent pas ; trio non évoqué |
| lvl_20 | La cour des rois morts | III | act2_graveyard / talk_greattree | Épéiste d'ombre → — | oui / oui | « grave » ambigu sans accent |
| lvl_21 | Le pentacle | III | act2_graveyard / talk_shrine | Fossoyeur → Sceau de Tombol | oui / oui | « Encore toi » ; le sous-titre gâche le retournement ; « mon royaume » |

### 2.2 Incohérences

**Haute**

1. **Les scènes de Vharn ne se jouent jamais.** `lvl_07.tres:308-309` vides (depuis
   `b222082`) ; `make_content.gd:4387-4454` ne les pose pas alors que
   `lvl_07_intro/outro.tres` existent (`make_story.gd:480-495`, dont le
   commentaire 473-475 affirme le contraire). Aucun test ne détecte une scène
   orpheline (`test_story.gd:32-47` ne vérifie que niveau → scène).
   *Proposition* : poser `intro_story` / `outro_story` vers `make_content.gd:4453`
   et ajouter un test qui refuse une scène citée par aucun niveau.
2. **L'acte IV n'est pas commutatif et le pentacle s'ouvre après un seul démon.**
   Chaque démon porte `next_levels = [lvl_13]` (`make_content.gd:4451, 5691, 5812,
   5970`) et `save_data.gd:805-806` débloque dès la première victoire ; la promesse
   « le cinquième ne s'ouvre qu'après les quatre » (`histoire.md:416-417`,
   `test_campaign_acts.gd:319`) n'est pas tenue. Répliques qui supposent un ordre :
   `lvl_13_intro` « Quatre. Quatre seigneurs, quatre contrats » (:572),
   `lvl_12_outro` (:556, :558), `lvl_07_outro` « Il y en a trois autres » (:492).
   *Proposition* : débloquer lvl_13 quand TOUS les niveaux qui le citent sont
   finis (gdscript-dev) ; réécrire de façon commutative :
   `"Encore un seigneur. Encore un contrat, et il ne savait pas ce qu il signait."`,
   `"Un de moins devant le pentacle."`,
   `"Il y en a d autres. On peut les prendre dans n importe quel ordre."`
3. **Le Gardien meurt au tutoriel, puis l'enfant le présente comme un allié.**
   `warden` en mini-boss de lvl_01 (`make_content.gd:3105`) ; `lvl_09_intro`
   « C est le Gardien ! … il va nous aider ! » (`make_story.gd:214`). La feuille de
   route (`roadmap_v2.md:407-410`) l'avait retiré ailleurs pour cette raison.
   *Proposition* : un autre mini-boss au lvl_01 (à faire mesurer) ; en attendant
   `"C est le Gardien ! Le vrai, celui de l arbre. Il va nous aider !"`
4. **lvl_02 a deux identités** : « La Tour des Sables » / « L ile qui a commence a
   tomber » / terrain sable (`lvl_02.tres:299-306`), le Coagulé pensé « sous la
   tour » (`make_content.gd:564-581`) — mais les scènes se passent au village.
   « Le corniste tombe en dernier » (`make_story.gd:173`) alors que la dernière
   vague amène le Coagulé puis la Reine gorgone. *Proposition* :
   `display_name = "Le village fige"`, `subtitle = "Ils marchent au pas"`, outro
   réécrite (§2.4).
5. **La fourche lvl_05 / lvl_06 montre le monde démoniaque en plein acte III**
   (`lvl_05.tres:292-300`, `lvl_06.tres:262-270`, aucune scène) alors que le Roi
   révèle « ce qui monte de ce puits » au lvl_21. *Proposition* : « Les forges sous
   Tombol » (« Ce qui monte du puits a deja ses ateliers ») et « La cour des
   creanciers » (« Ils se disputent la signature du roi »), une scène courte par
   branche : `"Sous la cour des rois, l escalier ne mene pas a une crypte. Il mene a une forge, et la forge n est pas a Tombol."` /
   `"Ce n est pas un cimetiere qui fabrique ca. Ca remonte d en dessous."`
6. **La fin annonce un mode qui n'existe plus** : `lvl_16_outro`
   « MODE INFINI DEBLOQUE. » (`make_story.gd:702`). Au 3/10, l'Infini s'ouvrait
   déjà niveau par niveau (`save_data.gd:707-711`) ; depuis la fusion du chantier
   progression (`ca1308e`), **le mode Infini est retiré** (modes Campagne, Libre,
   Massacre). Le Massacre exigeait les 21 niveaux, fourche comprise
   (`save_data.gd:683-724`, à revérifier après `ca1308e`).
   *Proposition* : ouvrir le Massacre à la victoire du lvl_16, ou
   `"Le Massacre t attend : finis chaque niveau de la campagne pour l ouvrir."`
7. **Les mondes de `WaveBudget.WORLDS` portent les noms de l'ANCIENNE histoire en
   4 actes** (`wave_budget.gd:48-54` : « Le Monde volant », « Le Grand Cimetiere »,
   « Le Monde demoniaque », « Le Monde d origine »). Ils s'affichaient en Infini
   (`hud.gd:1121-1142`) ; le mode est retiré depuis `ca1308e` mais la descente
   reste dans `WaveSpawner` et le bandeau dans le HUD. *Proposition* : les noms de
   `CampaignMap.ACT_NAMES` si la descente revient, sinon retirer ces données.

**Moyenne**

8. **Un pentacle à quatre branches** (`make_story.gd:494`) contre « se fend en cinq
   morceaux » (:579). → `"Le pentacle a cinq branches. Quatre portent un nom. J ai compte."`
9. **lvl_17 fait tomber un monstre absent** (« L Ecumeur du ciel tombe »,
   `make_story.gd:272` ; tête réelle : Grand Œil). →
   `"Le Grand Oeil des courants s abat sur la nacelle et reste pris dans les cordages."`
10. **lvl_19 : « Les Pretres des fosses tombent »** (`make_story.gd:385`) : n'existent
    pas. → `"Les trois mages des fosses tombent l un apres l autre, et aucun ne demande grace."`
11. **Malyk et la Reine gorgone (lvl_13) jamais nommés** (`histoire.md:430-434`
    prétend le contraire). → `"Celui qui porte les ordres s appelle Malyk. Il mange ce qu il appelle."`
12. **Contrats contradictoires** : « Lui n a jamais rien signe » (:507) contre
    « quatre contrats » (:556, :572). → `"Il dit vrai, mage. Il a signe sans lire. Il etait deja a table."`
13. **Le Rat cite un événement qu'il n'a pas vu** (« la meme que le corniste, dans
    ta foret », :482 ; il arrive au lvl_09). Donner la réplique au mage :
    `"Cette cadence. C est celle du corniste, au village."`
14. **lvl_04 promet sans tenir** (« on regarde ce qui sort », :340-342). Outro :
    `"Ce qui sort du cercle s appelle l Ensevelisseur. Quand il tombe, les morts cessent de charger."`
15. **lvl_14 : « Personne n est venu defendre la galerie »** (:630) juste après le
    Caméléon et le Slime colossal. →
    `"Les gardiens de la galerie tombent sans bruit, comme des pieces qu on range. On laisse passer le mage en visiteur."`
16. **lvl_21 : « Encore toi. »** (:421) alors qu'on n'a jamais rencontré le Roi
    (:358-360). → `"Te voila enfin. Tu cours vite pour un homme qui n a plus rien."`
17. **Chronos jamais nommé** alors que ses échos reviennent aux lvl_15/16. Dans
    `lvl_01_outro` : `"Le dernier a tomber porte un cadran a la place du coeur."` puis
    le mage : `"Chronos. L huissier. Il etait deja la, la premiere fois."`
18. **La Reine gorgone meurt à l'acte I** (w2_7) **et revient à l'acte IV** sans
    explication → §2.4.
19. **Décors de scène** : tous des forêts vertes (Wood Elves) des actes II à V :
    le port et les courants devant `talk_path`, la forge devant `talk_greattree`,
    l'« arène de sable noir » devant une cabane. `test_story.gd:296-314` interdit
    les fonds `act*`. *Proposition* : de nouveaux `talk_*`, ou autoriser le fond de
    combat assombri à partir de l'acte III.
20. **Fiche et briefing ne nomment pas la même tête** : `loading_screen.gd:76-84`
    garde le DERNIER mini-boss/boss rencontré, `campaign_panel.gd:255-262` le
    premier monstre de la vague de boss (lvl_02 : « Mini-boss : Écumeur, Boss :
    Reine gorgone » contre « Boss : Le Coagulé » ; lvl_09 : « Mini-boss : Gardien »
    sans boss ; lvl_03, 07, 19 : mauvais mini-boss). *Proposition* : lire les vagues
    marquées mini-boss / boss. **Mise à jour** : le briefing a été refait par le
    chantier des écrans (`97066f6`, `loading_screen.gd` : toutes les têtes, triées
    par rôle puis par vague) ; reste à aligner la fiche de campagne
    (`campaign_panel.gd:255-262`) sur la même lecture.
21. **Le Rat et le Roi n'ont pas d'adieu** (le Rat disparaît après lvl_15, le Roi
    après `lvl_16_intro` ; le Rat « reste avec la nacelle », :379, puis revient à
    l'acte IV sans un mot). Dans `lvl_16_outro` :
    Rat `"Moi je repare. Meme une boucle, ca se repare."`,
    Roi `"Je reste. Plus de royaume, autant avoir une boucle."`

**Basse**

22. « Mon royaume » (:422, :550) : reste de l'ancienne histoire. →
    `"Tu as signe la fin de Nuri et de Nox."`
23. Le mage placé à droite au lvl_08 (:188-194), seule scène.
24. « Le Gardien s effondre en un tas de bois mort » (:218) pour un chevalier en
    armure noire. → `"Le Gardien s effondre. Son armure s ouvre comme une ecorce : dedans, du bois mort..."`
25. Sous-titres qui gâchent un retournement : lvl_21 « Il ne fuyait pas devant toi »
    (`lvl_21.tres:200`), lvl_13 « Quatre contrats, pas une signature en commun »
    (`lvl_13.tres:264`).
26. Styles mélangés : sous-titres tantôt conseils de jeu, tantôt récit ; majuscules
    irrégulières (« La Cour brisee » / « La cour des rois morts ») ; le bestiaire
    vouvoie (« de votre main ») quand tout le reste tutoie.

### 2.3 Textes peu clairs (réécritures sans accents)

- `make_story.gd:318` (182 car., abstrait), en deux :
  `"Les registres de l ossuaire sont intacts. Une colonne par ile, une ligne par annee."` /
  `"Les trois dernieres annees, on n a plus compte des morts. On les a COMMANDES."`
- :319 → `"Ils ne vont pas nous effacer par haine. Ils vont nous effacer pour faire du STOCK."`
- :321 (« a la ligne », jargon comptable) →
  `"On ne range pas des morts en colonnes si on ne compte pas s en servir tous ensemble."`
- :295 → `"Le Mage noir de Haute-Nacelle s effondre. Sous sa robe, la meme soudure noire."`
- :380 (« il » sans antécédent) → `"Combien de temps avant que le Roi squelette sache que nous sommes la ?"`
- :402 (« grave » lu « sérieux ») → `"Et ne touche a aucune inscription."`
- :491 → `"J ai travaille vingt ans dans un atelier comme ca, la-haut."`
- :632 (point d'interrogation manquant) → `"Le Gardien de la foret ne valait rien ?"`
- :654 → `"Un seul mot : inattendu. Souligne deux fois, comme on souligne ce qui fait rire."`
- :674 (« cinq actes » sort du récit) → `"Tu m as porte depuis la clairiere, mage. Merci. C etait tres long a pied."`
- :149 (« trois sorts » ; la main en tient six) → `"Et je suis vide. De quoi lancer quelques sorts et courir vite. Ca ira."`
- :153 → `"Tu les as tous fait tomber ! Meme le grand ! Comment on fait ca ?"`
- :167 (le décor n'a pas de maison bleue) → `"C est la ! La maison sous le grand arbre, c est chez moi !"`
- Locuteur « Un demon » (:504-555) alors que le mage dit « Sesh ! » : afficher
  « Sesh », « Kaltek », « Ymoa » (le portrait partagé peut rester).
- À couper si l'on veut : :311 (161 car.), :378 (168), :399 (170), :420 (167), :218 (156).
- :533 (« gueulait » casse le ton) → `"Il criait parce qu il ne pouvait pas regarder en l air."`

### 2.4 Gorgones et village pétrifié : ce qui manque

Aucune occurrence de « gorgone » ni de « pétrif » dans les 39 scènes, les titres
ou sous-titres. Les gorgones sont pourtant jouées (lvl_02 : Matrone qui fige 2
cartes, 2 Gorgones, Reine qui en fige 3 ; lvl_13 : la Reine en mini-boss ;
lvl_15 : une Gorgone), la carte touchée affiche « PETRIFIEE » (`hud.gd:517-518`)
et le bestiaire l'explique (`bestiary_lore.gd:194-195`). **Atout** : le boss final
`child_god` fige aussi 3 cartes (`blocks_cards = 3`) — la pétrification peut
annoncer l'Enfant.

`lvl_02_intro` (talk_village), après « C est la !… » :
1. Narrateur : `"Le village est debout. Ses gens aussi : en pierre, figes au milieu d un geste."`
2. L'Enfant : `"Ils ne repondent pas. Pourquoi ils ne repondent pas ?"`
3. Le Mage : `"Une gorgone est passee. Si elle croise mes sorts, ils se figeront aussi. Il faudra l abattre en premier."` (apprend la mécanique au moment où la Matrone arrive)

`lvl_02_outro`, à la place de « Le corniste tombe en dernier » :
4. Narrateur : `"La Reine des gorgones tombe la derniere. Les sorts du mage se degelent d un coup. Les gens du village restent en pierre."`
5. Le Mage (`mage_grave`) : `"Ce qu une gorgone fige, sa mort le libere. Pas eux. Quelqu un les a figes avant elle."`
6. L'Enfant : `"Ils sont bien comme ca. Ils n ont plus peur."` (indice du retournement)

Échos ensuite :
- `lvl_08_intro` (:195) : `"Mon village est en pierre derriere moi. Il n y a plus rien a garder. Je viens."`
- `lvl_13_intro` (explique le retour de la Reine) — Roi : `"La Reine des gorgones garde la porte. Malyk ramasse ce qui a deja servi."` ; Mage : `"Je l ai brisee dans le village de l enfant."` ; Roi : `"Ici, on recolle les statues."`
- `lvl_16_intro`, après « C etait propre. » — L'Enfant (`child_god`) : `"Les statues du village, c etait moi. Les gorgones n ont fait que signer en dessous."`

### 2.5 Données mortes et commentaires périmés (trompeurs pour qui maintient)

- `intro_text` / `outro_text` de lvl_01 à lvl_06 racontent l'ancienne histoire
  (« Le royaume est tombe », « Grand Cimetiere », « cadran ») ; ceux de lvl_03, 04,
  06 citent la carte donnée par le boss (mécanique retirée, DEC-029) ; lvl_17 parle
  des « Planogos », lvl_14 de « il y en a deux » (la scène en compte trois).
- Commentaires : `level_def.gd:9-10` (4 actes), :15-18 (« lu au briefing », faux),
  :28-30 (act5_divine absent) ; `campaign_map.gd:8`, :131-132 ;
  `wave_budget.gd:43-47` (« l acte 5 n a pas de niveau ») ; `make_story.gd:13-22`
  (« acte 1 seulement »), :444 (« sept niveaux » sous l'acte 4) ;
  `make_content.gd:3179` (« fourche en lvl_04 »), :3337-3347 (Chronos au lvl_07),
  :3361-3366 (« la Reine n a pas de niveau »), :4404-4407 ; `test_story.gd:80`,
  :241-242 ; `roadmap_v2.md:140` (« 9 scènes »).
- `docs/histoire.md` ne décrit plus le jeu : ids de scène attribués aux scènes du
  plan qui vivent en réalité dans d'autres niveaux (l.124-257, 294-310, 373-386,
  460-472, 545) ; « lvl_03_* et lvl_04_* supprimées » (l.691-694) ; « 21 monstres »
  (l.624-626) ; prologue « act1_sky » (l.76, c'est talk_shrine) ; acte V et fin
  « act4_origin » (l.493, 579) ; le Rat « rejoint a l acte 2 » (l.27) ; lvl_01
  « uniquement gnome, sprite, hopper » (l.118-119).

### 2.6 Suivi du chantier B4 (14/10) — ce qui a été fait de chaque constat

Le texte vit dans `tools/make_story.gd` (scènes) et, pour les niveaux, dans les
seuls champs `display_name`, `intro_text`, `intro_story`, `outro_story` de
`tools/make_content.gd` (périmètre de B4). Tout ce qui demande de toucher aux
vagues, aux boss, aux sous-titres ou au code est **renvoyé** (§2.7).
`docs/histoire.md` a été réécrit pour décrire l'état réel.

Trois gardes ajoutées à `tests/unit/test_story.gd` (sabotage vérifié : 4 échecs
pour 3 sabotages, puis vert) :
- **aucune scène orpheline** : toute scène du disque est citée par un niveau
  (ou est le prologue) — attrape le n° 1 ;
- **chaque niveau de la campagne a son intro et son outro** (les quêtes annexes
  n'y sont pas tenues) ;
- **le narrateur ne nomme que ce qui est joué** : une réplique SANS locuteur qui
  nomme un monstre exige ce monstre dans les vagues du niveau — attrape le n° 9,
  et rougira si B2 retire d'un niveau une tête qu'une scène fait tomber ;
- et `display_name` / `subtitle` / `intro_text` sans accents ni tiret long
  (trois `intro_text` en portaient un, affiché au briefing depuis la vague 10).

| N° | Constat | État | Détail |
|---|---|---|---|
| 1 | Scènes de Vharn non branchées | **corrigé** | `lvl_07.intro_story/outro_story` posés ; garde « scène orpheline » |
| 2 | Acte IV non commutatif, pentacle ouvert après un démon | **texte corrigé**, déblocage **renvoyé** | aucune scène ne compte ni ne suppose d'ordre (`lvl_07/11/12_outro`, `lvl_13_intro`, `lvl_13.intro_text`) ; le déblocage est du code (§2.7) |
| 3 | Gardien tué au tutoriel puis présenté en allié | **texte corrigé**, vague **renvoyée** | `lvl_09_intro` : « Le vrai, celui de l arbre » ; aucune scène de lvl_01 ne cite le mini-boss ; le remplacer est pour B2 |
| 4 | lvl_02 à deux identités | **corrigé** (sauf sous-titre) | « Le village petrifie », `intro_text` et scènes au village pétrifié ; sous-titre renvoyé |
| 5 | Fourche 05/06 sans scène, monde démoniaque trop tôt | **corrigé** | « Les forges sous Tombol » / « La cour brisee », 4 scènes, `intro_text` ; l'outro de lvl_20 annonce les deux escaliers ; le fond rouge devient un indice (« ce qui remonte d en dessous ») sans gâcher lvl_21 |
| 6 | « MODE INFINI DEBLOQUE » | **corrigé** | dernière ligne : le Massacre s'ouvre quand chaque niveau de la campagne est fini (vrai : `massacre_unlocked()` = `campaign_cleared()`, fourche comprise) |
| 7 | Noms de mondes de l'ancienne histoire (`WaveBudget.WORLDS`) | **renvoyé** | code ; ces noms ne sont plus affichés nulle part (`battle_backdrop` ignore `_world_name`) |
| 8 | Pentacle à 4 branches contre 5 | **corrigé** | « cinq branches, quatre portent un nom » (lvl_07) ; poinçon à cinq branches (lvl_05) |
| 9 | lvl_17 fait tomber l'Écumeur absent | **corrigé** | le Grand Œil ; garde « narrateur » |
| 10 | « Pretres des fosses » | **corrigé** | « les trois mages des fosses » |
| 11 | Malyk et la Reine jamais nommés | **corrigé** | `lvl_13_intro/outro`, `lvl_13.intro_text` |
| 12 | Contrats contradictoires | **corrigé** | Sesh « a signé sans lire » ; une seule logique : signature du roi + au-dessus une écriture « petite et soignée » (celle du registre, lvl_15) |
| 13 | Le Rat cite le corniste | **corrigé** | réplique donnée au mage, « au village » |
| 14 | lvl_04 promet sans tenir | **corrigé** | l'outro nomme l'Ensevelisseur |
| 15 | « Personne n est venu defendre la galerie » | **corrigé** | les gardiens tombent « sans bruit » ; `intro_text` « un par saison » |
| 16 | « Encore toi » | **corrigé** | « Te voila enfin » |
| 17 | Chronos jamais nommé | **corrigé** | lvl_01_outro (le mage le reconnaît) ; lvl_16_intro : le boss final a « la forme de Chronos » en or |
| 18 | La Reine morte à l'acte I revient à l'acte IV | **corrigé** | « Ici, on recolle les statues » |
| 19 | Décors de scène tous forestiers | **partiel**, **renvoyé** | choisis par ce que l'image montre : nuages pour les courants, sanctuaire de pierre pour tout le funéraire et le souterrain (lvl_03/04/19/20, actes III-IV) ; des décors dédiés restent à faire (asset-pipeline) |
| 20 | Fiche et briefing ne nomment pas la même tête | **renvoyé** | code (`campaign_panel.gd`) |
| 21 | Le Rat et le Roi sans adieu | **corrigé** | le rat revient dans `lvl_21_outro` ; adieux dans `lvl_16_outro` |
| 22 | « Mon royaume » | **corrigé** | Nuri et Nox (lvl_21, lvl_12) |
| 23 | Mage à droite au lvl_08 | **corrigé** | |
| 24 | « Tas de bois mort » pour un chevalier | **corrigé** | l'armure s'ouvre comme une écorce |
| 25 | Sous-titres qui gâchent | **renvoyé** | champ hors périmètre B4 (§2.7) |
| 26 | Styles mélangés | **partiel** | noms de niveaux harmonisés (minuscule après le premier mot : « La cour brisee », « L ossuaire de bordure »…) ; sous-titres et vouvoiement du bestiaire renvoyés |

§2.3 : toutes les réécritures proposées sont faites (réplique de 182 car. coupée
en deux, plus aucune au-delà de 145) ; locuteurs « Sesh », « Kaltek », « Ymoa ».
§2.4 : faite en entier, échos compris (lvl_08, lvl_13, lvl_16). §2.5 : les
`intro_text` de lvl_01 à lvl_06 (et lvl_11, 13, 14) sont réécrits ; les
`outro_text` et les commentaires hors `make_story.gd` sont renvoyés.

Captures relues (fenêtre réelle 540×960, scène temporaire supprimée) :
`lvl_02_intro` (narrateur, mage), `lvl_02_outro`, `lvl_05_intro`, `lvl_06_outro`,
`lvl_07_outro`, `lvl_10_intro` (locuteur « Sesh »), `lvl_13_intro` (réplique la
plus longue, 3 lignes), `lvl_16_intro`, `lvl_16_outro`, briefings lvl_02 et
lvl_05. Tout tient dans la boîte, le texte sombre se lit sur le papier.

### 2.7 Pour B2 (et ce qui n'est pas du texte)

**Vagues et têtes** — B2 refait les niveaux ; ces points dépendent de lui :

1. **lvl_01, `w1_miniboss`** : remplacer le Gardien (`warden`) par un autre
   mini-boss. Le Gardien est présenté comme un allié au lvl_09 puis y meurt ;
   tant qu'il meurt aussi au tutoriel, seule la réplique « Le vrai, celui de
   l arbre » sauve la cohérence. Garder **Chronos** en boss du lvl_01 : il est
   nommé dans `lvl_01_outro` et le boss final porte sa silhouette (`lvl_16_intro`).
2. **lvl_02** : garder la **lignée des gorgones** (Matrone en mini-boss, Gorgones,
   **Reine gorgone** dans la vague de boss : `lvl_02_outro` la fait tomber, et
   `lvl_13_intro` dit que le mage l'a brisée au village) et un **Corniste**
   (`lvl_02_intro` : « ils marchent au pas, quelqu un leur bat la mesure »,
   repris chez Vharn).
3. **Têtes nommées par les scènes** (à garder, ou prévenir l'écriture) : lvl_03
   le Reliquaire ; lvl_04 l'Ensevelisseur ; lvl_09 le Gardien (boss) ; lvl_13 la
   Reine gorgone et Malyk ; lvl_15 l'Horloger ; lvl_17 le Grand Œil des
   courants ; lvl_18 le Mage noir de Haute-Nacelle ; lvl_19 le trio des mages ;
   lvl_05 « le dernier colosse de la forge » ; lvl_06 « le dernier seigneur de la
   cour » ; lvl_07/10/11/12 les quatre démons. `test_story` vérifie ce que dit le
   narrateur ; les répliques des personnages, elles, ne sont pas vérifiées.
4. **Sesh** : `lvl_10_outro` ne dit plus que ses proies « ressortent intactes » ;
   la proposition « L'outre » (§1.3) reste compatible avec le texte.

**Champs de niveau hors périmètre B4** (`make_content.gd`) :

5. **Sous-titres** à changer :
   - lvl_02 « L ile qui a commence a tomber » (ancienne histoire) → par exemple
     « Ils marchent au pas » ou « Le regard qui fige » ;
   - lvl_13 « Quatre contrats, pas une signature en commun » (compte les démons,
     et c'est désormais l'inverse : la même écriture sur tous) → par exemple
     « Celui qui porte les ordres » ;
   - lvl_21 « Il ne fuyait pas devant toi » (gâche le retournement) → par
     exemple « Le roi ne fuit plus » ;
   - choisir une ligne pour tous : conseil de jeu (« L ordre des cibles ») ou
     récit (« Ton nom y est, avec une date »), pas les deux.
6. **`outro_text`** : affiché nulle part et faux presque partout (lvl_01 « Le
   Gardien a ri en mourant… Chronos n etait qu un huissier » ; lvl_02 « Sous la
   tour… Grand Cimetiere » ; lvl_03 « Une Gelee prisonniere… » ; lvl_04 « Les
   goules croyaient invoquer un allie » ; lvl_05 l'horloge et le cadran ; lvl_06
   « Le Chevalier du vide qui gardait le cadran » ; lvl_10 « ressort intact et
   vivant » ; lvl_14 « Personne n est venu » ; lvl_17 l'Écumeur ; lvl_16 et
   lvl_02 portent un tiret long). Le vider ou le recopier de l'outro jouée.
7. **Fonds** : lvl_05 et lvl_06 gardent `act3_demon`, que leurs textes
   expliquent désormais (« rouge de ce qui remonte d en dessous ») ; passer
   lvl_06 (salle du trône de Tombol) en `act2_graveyard` est possible, en
   retouchant alors son `intro_text`. `terrain = "sand"` de lvl_02 est inopérant
   (le fond prime) ; les commentaires de `make_content.gd` parlent encore de
   « la tour » (lvl_02), de « la Reine sans niveau », de la « fourche en lvl_04 ».

**Code et assets** (gdscript-dev, asset-pipeline) :

8. **Ouvrir lvl_13 après les QUATRE démons** (`SaveData.record_victory` ouvre
   tout `next_levels` dès la première victoire) : ouvrir un niveau quand tous les
   niveaux qui le citent sont finis. Les scènes tiennent dans les deux cas.
9. `WaveBudget.WORLDS` (noms de l'ancienne histoire, n° 7), `campaign_panel`
   (n° 20), commentaires de `level_def.gd` (4 actes, « lu au briefing »),
   `campaign_map.gd:8`, vouvoiement du bestiaire (`bestiary_lore.gd`).
10. **Décors de dialogue dédiés** (n° 19) : port, forge, fosses, arène, temple,
    galerie/registre. Les actes III à V jouent tous devant `talk_shrine`.
11. **Cartes** : régénérer `make_content.gd` réécrit les 53 `.tres` de cartes
    (le champ `major_upgrades` de la vague 10 n'y a jamais été écrit). B4 ne les
    a pas gardées ; c'est au chantier des cartes (B1a) de les régénérer.

---

## 3. Sprites, animations et sons : ce qui reste en deçà après A4

- **Le halo d'aura (`shield_hex`)** montre par moments une bande horizontale
  claire en travers du disque (capture `totem_anime_2`) : c'est une image de la
  feuille Pipoya, pas un défaut de code, mais à grande taille (aura de 210-240 px)
  elle se lit comme un artefact. Une feuille d'aura propre aux porteurs d'aura
  (distincte du bouclier) serait plus lisible.
- **La pose de mort de `nightborne`** finit par trois disques plein cadre
  (blanc, noir, blanc) dessinés par l'auteur : spectaculaire mais violent à 500 %.
  À juger en jeu ; au besoin, arrêter la pose à l'image 9 (`AnimCatalog`, `count`).
- **Feuilles en contradiction avec le nom** : voir §1.3 (Ymoa en tour, Seigneur de
  braise en paysan, Goule en vautour…). Ce sont les « sprites devenus médiocres face
  aux nouveaux » : les têtes de l'acte IV sur des feuilles Tiny Swords de P1-P4 à
  côté des boss Duelyst.
- **Ymoa et son Écho** restent la même tour que le Gardien-totem (P4), à la taille
  près : A4 les fait vivre, mais ne leur donne pas une silhouette de seigneur.
- **Sons** : les fichiers historiques en double (`cast_start` = `charge_magic`,
  `cast_zone` = `spell_rise`, `cast_done` = `spell_arcane`, `heal` = `ward_light`,
  `shield_break` = `ward_deep`) restent en place pour ne rien casser ; à
  dédoublonner quand un chantier reprendra l'interface sonore. Les sons d'interface
  (`ui_tap` partout) n'ont pas été touchés.
- **Voix** : le moment `shield` du pack (« le bouclier de vitesse encaisse ») n'a
  plus de sens depuis que la vitesse EST la vie (26/09) ; A4 l'a rebranché sur les
  sorts de protection (murs, objets, dissipation). Les familles du pack non
  extraites (`blizzard`, `protect`, `onfire`, `surprised`…) pourraient varier les
  répliques par élément (glace, protection) si le mage paraît répétitif.
- **Licence** : une partie des nouveaux sons vient de **FreeSFX**, dont l'origine
  n'est toujours pas prouvée (`docs/assets_index.md` §1.3) : la dette grandit d'une
  vingtaine de fichiers. Tous ont un équivalent possible dans 400 Sounds si la
  réponse est mauvaise.

---

## 4. Dette laissée par A4

- `AudioBus.CARD_SFX` donne aux sorts leur nouveau son **en dehors** de
  `SpellCard.sfx_key` : `tools/make_content.gd` était interdit en phase A. Le
  chantier qui reprendra `make_content.gd` doit recopier la table dans les
  `sfx_key` puis la vider ; `test_audio_w10` vérifie la règle sur la clé
  EFFECTIVE et continuera de passer. **Soldée par B1a** : table recopiée dans les
  `sfx_key`, `CARD_SFX` vide, `test_w10_cartes` vérifie que chaque sort joue son
  propre `sfx_key`.
- Un monstre ajouté avec une feuille neuve fera rougir `test_audio_w10` tant que
  sa feuille n'est pas classée dans `AudioBus.SHEET_FAMILY` (voulu : sinon il
  mourrait du vieux son générique sans que personne le remarque).
- Les gains se régénèrent avec `python tools/assets/extract_w10_audio.py` (ffmpeg
  requis) après tout ajout de son ; ne pas les éditer à la main.
