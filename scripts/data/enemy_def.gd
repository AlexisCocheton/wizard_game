class_name EnemyDef
extends Resource
## Definition d un type de monstre.
##
## `power` est la brique de la hierarchie : une vague de puissance 8 est une
## combinaison de monstres dont les puissances totalisent 8 (voir WaveBudget).

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: GameEnums.EnemyKind = GameEnums.EnemyKind.NORMAL
## Niveau de puissance 1..4 (boss et mini-boss au-dela, hors budget).
@export_range(1, 12) var power: int = 1
@export var max_hp: float = 10.0
## Vitesse de descente en pixels/seconde A x1.
@export var base_speed: float = 60.0
## XP de base ; multipliee par le multiplicateur de vitesse a la mort.
@export var base_xp: int = 1
## Degats infliges au mage au contact, EN POINTS DE POURCENTAGE DE VITESSE :
## depuis le 26 septembre la vitesse est la seule reserve du mage, et 24 de
## contact lui coutent 24 points de vitesse (voir speed_gauge.gd).
## 0 = deduit de la puissance (voir GameConfig.CONTACT_DAMAGE_BY_POWER).
## Une valeur explicite l emporte, pour un monstre volontairement hors bareme.
@export var contact_damage: int = 0

@export_group("Apparence")
## Cle dans AnimCatalog (feuille animee des packs). Vide = forme dessinee de secours.
@export var anim_key: StringName = &""
## Multiplicateur d echelle du sprite par rapport au rayon logique.
@export var sprite_scale: float = 1.0
@export var shape: GameEnums.Shape = GameEnums.Shape.SQUARE
@export var color: Color = Color(0.75, 0.30, 0.35)
## Rayon logique en pixels : portee de gobage, taille des barres, echelle du sprite.
@export var base_radius: float = 32.0
## Texture fixe optionnelle (prioritaire sur la forme, pas sur anim_key).
@export var sprite: Texture2D

@export_group("Comportements de base")
## RESISTANCES EN POURCENTAGE — DamageTag -> multiplicateur de degats subis.
## 0.0 = immunite totale, 0.5 = moitie des degats, 1.0 = normal (valeur par
## defaut quand le tag est absent), 1.5 = degats majores de moitie.
##
## C est la table qui remplace l immunite BINAIRE : avec deux etats seulement,
## un golem de pierre et une gelee encaissaient le feu exactement pareil, et
## changer de deck ne servait a rien. Ce sont les ECARTS entre monstres qui
## donnent une raison de recomposer son deck pour un niveau.
@export var resistances: Dictionary = {}
## DEPRECIE — remplace par `resistances` (une immunite = resistance 0.0).
## Conserve parce que les .tres deja sur les telephones le portent encore et
## qu un chargement ne doit pas perdre l information : `resistance_to()` le lit
## en repli. Tout contenu NEUF passe par `resistances`.
@export var immune_tags: Array[GameEnums.DamageTag] = []
## Probabilite d esquiver un sort (0..1), pour les EVASIVE.
@export var dodge_chance: float = 0.0
## Nombre d unites apparaissant ensemble, pour les SWARM.
@export var swarm_count: int = 1
## Entre par le cote de l ecran au lieu du haut.
@export var entry_side: bool = false
## VOLANT — ignore la grille de navigation et descend TOUT DROIT : un mur pose
## par le joueur ne l arrete pas et ne le detourne pas. C est la reponse a
## "capacite volante qui passe au-dessus des murs" : un volant ne se gere pas
## avec du decor, il se gere en le tuant.
@export var flying: bool = false
## PROJECTILE — n est pas une creature : ni bestiaire, ni XP, ni statistiques.
## Une boule de poison tiree par un Planogo reste un monstre du terrain (donc
## ciblable et destructible par tous les sorts existants, sans code neuf), mais
## le joueur ne doit pas la trouver dans son bestiaire ni la farmer pour monter
## de niveau.
@export var projectile: bool = false
## Intervalle de disparition temporaire en secondes, pour les PHASER. 0 = jamais.
@export var phase_interval: float = 0.0
## Bonus de vitesse (%) accorde aux autres monstres, pour les BUFFER.
@export var buff_speed_pct: float = 0.0

@export_group("Comportements speciaux")
## Gobe les monstres plus faibles qu il croise et grossit.
@export var devours: bool = false
## Gain de vitesse (%) a chaque coup recu, et plafond total.
@export var enrage_speed_pct: float = 0.0
@export var enrage_cap: float = 1.5
## Rayon de l aura qui protege les AUTRES monstres des degats. 0 = aucune.
@export var aura_shield_radius: float = 0.0
## Avance par a-coups : fonce puis marque une pause.
@export var burst_move: bool = false
@export var burst_dash_time: float = 0.6
@export var burst_pause_time: float = 0.7
## Ondulation laterale : amplitude en px et frequence en Hz. 0 = tout droit.
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 0.5
## A la mort, engendre `split_count` exemplaires de `split_into` (recursif).
@export var split_into: EnemyDef
@export var split_count: int = 0
## Encaisse le premier coup sans degat (halo visible tant qu il tient). Une zone
## ou un poison le brisent aussi, une seule fois : ce n est pas un compteur.
@export var first_hit_shield: bool = false
## Soigne tous les autres monstres de N PV par seconde tant qu il est en vie.
@export var heal_per_second: float = 0.0
## Tire un projectile sur le mage toutes les N secondes. 0 = ne tire pas.
@export var shoot_interval: float = 0.0
## Les tirs font PEU de degats : ils harcelent, ils ne tuent pas. Un archer qui
## fait aussi mal qu une charge rend la distance plus dangereuse que le contact.
@export var shot_damage: int = 2

## REGARD PETRIFIANT — tant qu il est vivant, `blocks_cards` cartes de la MAIN
## du joueur deviennent injouables. 0 = aucune.
##
## Ce que la mecanique change : la MAIN. Toutes les autres mecaniques de monstre
## agissent sur le TERRAIN — ou frapper (morcele), quand (renvoi), quoi d abord
## (invocateur), avec quel element (resistances). Celle-ci est la premiere a
## toucher les cartes elles-memes, donc la premiere ou la reponse n est pas
## « choisis mieux ta cible » mais « tue CELUI-LA pour recuperer ton deck ».
##
## La petrification se LEVE a sa mort : c est ce qui en fait une decision et non
## une punition. Un blocage definitif transformerait le monstre en taxe.
##
## TROIS PALIERS, comme demande : 1 pour un monstre commun, 2 pour un mini-boss,
## 3 pour un boss. Au-dela, un seul monstre viderait la main a lui tout seul.
##
## LE PLAFOND vit dans RunState (GameConfig.MAX_BLOCKED_CARDS) et non ici : il
## porte sur la MAIN, pas sur le monstre. Deux gorgones de boss totalisent six
## regards pour une main de six cartes ; sans plafond global le joueur regarderait
## son ecran sans pouvoir rien lancer, ce qui n est plus un jeu. Le testeur l a
## demande en ces termes : « pas plus de 5 carte sur 6 bloquer ».
@export_range(0, 3) var blocks_cards: int = 0

## ONDE DE CHOC — toutes les `shockwave_interval` secondes il frappe le sol et
## un cercle de `shockwave_radius` px inflige `shockwave_damage`. 0 = jamais.
##
## Ce que la mecanique change par rapport au tir du canonnier : un tir VISE le
## mage, une onde BALAIE un rayon. Le joueur ne peut plus se contenter de sortir
## d une ligne — il doit tenir ses invocations, ses murs et ses arbres hors du
## cercle. Couplee a un boss qui n avance pas, elle cree une zone interdite
## FIXE : la premiere du jeu.
##
## Un boss a onde doit rester EN PLACE (`base_speed` nulle ou `keeps_distance_at`
## pose) : une zone interdite qui se deplace en frappant ne laisse aucun endroit
## sur, il suffirait d attendre et le combat n aurait plus de decision.
@export var shockwave_interval: float = 0.0
@export var shockwave_radius: float = 0.0
@export var shockwave_damage: int = 0

@export_group("Comportements v3")
## PLUSIEURS VIES — a zero PV il revient `extra_lives` fois, a chaque fois DEPUIS
## LE HAUT DU TERRAIN (meme colonne) avec `extra_life_hp_pct` % de ses PV. 0 = une
## seule vie.
##
## DISTINCT de `revive_hp_pct`, qui le releve une fois SUR PLACE : ici le monstre
## est renvoye au depart et doit refaire tout le chemin. Ce que la mecanique
## change : le joueur a gagne du TEMPS en le tuant, pas la bataille. Les deux
## peuvent se cumuler, le releve sur place passe alors en premier.
##
## Il ne compte qu UNE mort (XP, objectifs, bestiaire) : la definitive. Sinon un
## monstre a trois vies serait la meilleure ferme d XP du jeu.
@export_range(0, 5) var extra_lives: int = 0
@export_range(1.0, 100.0) var extra_life_hp_pct: float = 100.0
## Vitesse gagnee (%) a CHAQUE vie perdue, cumulee : a 35, la troisieme vie
## descend a +105 %. C est ce qui fait que le laisser revenir coute de plus en
## plus cher, et que le tuer loin du mage reste la bonne reponse.
@export var extra_life_speed_pct: float = 35.0

## RENAISSANCE DIFFEREE — a sa mort definitive, il laisse une MARQUE au sol et,
## `rebirth_delay` secondes plus tard, `rebirth_count` exemplaires de
## `rebirth_def` naissent a cet endroit. Null ou 0 = rien.
##
## Distinct de la division (`split_into`), qui fait naitre TOUT DE SUITE : ici le
## joueur voit le danger arriver et peut preparer un sort de zone sur la marque.
## La vague ne se termine pas tant qu une marque est au sol.
@export var rebirth_def: EnemyDef
@export_range(0, 6) var rebirth_count: int = 0
@export var rebirth_delay: float = 3.0

## REANIMATEUR — toutes les `reanimate_interval` s, il releve UN monstre mort
## recemment dans un rayon de `reanimate_radius` px, `reanimate_max` fois au
## total. 0 = ne reanime pas.
##
## LE PLAFOND EST LA MECANIQUE : sans lui, un reanimateur au fond du terrain
## rendrait toute vague interminable. Le releve ne rapporte ni XP ni compteur
## (la creature a deja ete comptee a sa premiere mort).
@export var reanimate_radius: float = 0.0
@export var reanimate_interval: float = 4.0
@export_range(0, 20) var reanimate_max: int = 0

## LASER DE RIPOSTE — chaque fois qu il ENCAISSE des degats (un coup qui mord,
## pas une esquive ni un bouclier), il tire un rayon sur le mage qui coute
## `laser_damage` points de vitesse. 0 = pas de laser.
##
## `laser_cooldown` est le delai MINIMAL entre deux tirs. Sans lui, une pluie
## qui frappe dix fois par seconde declencherait dix lasers : la punition des
## sorts a coups multiples deviendrait une execution. Le moteur impose de toute
## facon un plancher (Enemy.LASER_MIN_COOLDOWN). Une zone ou un poison ne font
## PAS riposter (vague 9) : un degat continu n est pas un coup (voir
## Enemy.CONTINUOUS_FEEDBACK_INTERVAL).
@export var laser_damage: int = 0
@export var laser_cooldown: float = 1.5

## SOMMEIL QUI COUPE LA MAGIE — toutes les `sleep_interval` s d eveil, il
## s arrete et dort `sleep_duration` s. PENDANT SON SOMMEIL LE JOUEUR NE PEUT
## LANCER AUCUN SORT. 0 = ne dort jamais.
##
## Le tuer pendant qu il dort rend la magie aussitot : c est la reponse, et elle
## se prepare pendant qu il est eveille. Un plafond de duree et une fenetre de
## magie garantie entre deux sommeils, TOUS monstres confondus, vivent dans
## Battlefield : trois dormeurs ne doivent pas verrouiller le joueur.
@export var sleep_interval: float = 0.0
@export var sleep_duration: float = 2.0

## MOTIF DE DEPLACEMENT — autre chose que la ligne droite. Ajouter les valeurs A
## LA FIN : les .tres stockent l entier.
##   STRAIGHT : tout droit (defaut)
##   ZIGZAG   : va-et-vient lateral sur `pattern_width` px
##   BOUNCE   : diagonale qui rebondit sur les bords du terrain
##   HOP      : saute d une colonne de `pattern_width` px toutes les
##              `pattern_interval` s
##   SPIRAL   : descend en TOURNANT : il parcourt un cercle de `pattern_width`
##              px de diametre pendant que sa colonne descend. Le cercle part
##              vers le centre du terrain, se pose SOUS sa position de depart
##              (jamais au-dessus de la ligne d apparition) et oscille autour de
##              sa colonne. Vitesse sur le cercle : `pattern_lateral_speed`. Plus
##              rapide que `base_speed`, il fait des boucles et REMONTE un
##              instant ; egale (defaut), une roue qui roule, sans recul.
## Pour un monstre AU SOL, le motif ne s applique qu en descente libre : des
## qu un mur impose un chemin A*, le chemin prime, et un ecart (lateral, ou
## vertical pour la spirale) qui entrerait dans une cellule bloquee est refuse.
## Les volants l appliquent toujours. `wave_amplitude` et `burst_move` restent
## independants et cumulables.
enum MovePattern { STRAIGHT, ZIGZAG, BOUNCE, HOP, SPIRAL }
@export var move_pattern: MovePattern = MovePattern.STRAIGHT
## Vitesse laterale en px/s a x1 (ZIGZAG, BOUNCE ; vitesse sur le cercle pour
## SPIRAL). 0 = egale a `base_speed`, donc une diagonale a 45 degres.
@export var pattern_lateral_speed: float = 0.0
@export var pattern_width: float = 240.0
@export var pattern_interval: float = 1.5

@export_group("Mecaniques de boss")
## MORCELE — le boss porte `parts_count` parties a detruire separement. Tant
## qu une partie tient, le coeur n encaisse RIEN : le joueur doit changer de
## cible au lieu d empiler ses degats sur la masse centrale.
@export var parts_count: int = 0
## PV de CHAQUE partie. Le surplus d un coup ne coule pas sur la partie suivante :
## sinon un gros sort balaierait toutes les parties d un coup et la mecanique
## redeviendrait « plus de PV ».
@export var part_hp: float = 0.0
## Ralentissement (%) inflige au boss par partie detruite. C est la recompense
## immediate : sans elle, le joueur tape dans le vide pendant la moitie du combat.
@export var part_slow_pct: float = 0.0

## CANONNIER — distance au mage (px) a laquelle le boss s arrete pour tirer.
## 0 = il descend jusqu au contact comme tout le monde. Un boss qui campe ne
## peut pas etre attendu sur la ligne de defense : il faut aller le chercher.
@export var keeps_distance_at: float = 0.0

## INVOCATEUR — engendre `summon_count` exemplaires de `summon_def` toutes les
## `summon_interval` secondes, tant qu il est en vie. Tuer la source coupe le
## flux : c est la reponse que ce boss exige.
@export var summon_interval: float = 0.0
@export var summon_def: EnemyDef
@export var summon_count: int = 1
## Plafond de sbires VIVANTS issus de ce boss. Sans plafond, un joueur qui traine
## perd par accumulation mecanique, ce qui n est plus une decision de jeu.
@export var summon_max_alive: int = 6

## RESSUSCITE — a zero PV il ne meurt pas : il se releve UNE fois avec ce
## pourcentage de ses PV d origine. 0 = il meurt normalement.
##
## Ce que la mecanique change : le sens du mot « tuer ». Toutes les autres
## mecaniques de boss modifient OU frapper ou QUAND ; celle-ci modifie la
## condition de victoire elle-meme. Le joueur voit la barre se vider, entend la
## mort, se retourne vers la vague — et le boss se releve derriere lui. C est la
## seule vague du jeu ou garder une carte en reserve APRES avoir cru gagner est
## la bonne decision.
##
## Strictement sous 100 : revenir a PV pleins ne serait pas un releve, ce serait
## deux combats colles, donc deux fois plus de PV sous un nom different.
## UNE seule fois : sans plafond, un joueur sans le bon deck ne finirait jamais.
@export_range(0.0, 95.0) var revive_hp_pct: float = 0.0

## IMMUNISE AUX N PREMIERS COUPS — les `hits_immune` premiers coups recus ne lui
## font RIEN, quelle que soit leur puissance. 0 = aucune immunite.
##
## Ce que la mecanique change : la MONNAIE des degats. Partout ailleurs le joueur
## paie en points de degats ; ici il paie en NOMBRE DE COUPS. Le spam de petites
## cartes, qui est le reflexe encourage par tout le reste du jeu, devient le pire
## choix possible, et le gros sort charge le meilleur.
##
## DISTINCT de `first_hit_shield`, qui absorbe UN coup et sert de decor a un
## monstre ordinaire : ici le compteur EST le combat, et la fiche du bestiaire le
## dit en toutes lettres — sinon le joueur croit que ses sorts ne fonctionnent pas.
##
## Le compteur ne mange QUE des COUPS : un etourdissement ou un ralentissement
## n en consomme aucun, un degat continu (zone, poison) non plus, et il bute sur
## le compteur tant que celui-ci n est pas vide (vague 9 : un dard le videait en
## dix images). Sinon la mecanique cesserait d etre « depense tes coups »
## pour devenir « N secondes d invulnerabilite totale », ce qui ne se joue pas.
@export_range(0, 12) var hits_immune: int = 0

## GARDE DE RENVOI — toutes les `reflect_interval` secondes il leve une garde
## de `reflect_window` secondes, pendant laquelle `reflect_pct` % des degats
## recus repartent sur le MAGE. 0 = pas de renvoi.
##
## Ce que la mecanique change : le MOMENT du lancement. Tout le reste du jeu
## recompense le joueur qui lance des qu une carte est prete ; ici lancer au
## mauvais moment lui coute ses propres PV. C est la seule mecanique du jeu ou
## regarder le BOSS vaut mieux que regarder sa main.
##
## Le boss encaisse quand meme pendant sa garde : le renvoi est un PRIX, pas un
## mur. Un mur transformerait la mecanique en attente passive, et on peut tuer le
## boss pendant sa garde en acceptant de payer — c est le choix qu on veut offrir.
##
## `reflect_window` doit rester STRICTEMENT sous `reflect_interval`, sinon la
## garde ne retombe jamais et le joueur n a plus de fenetre pour jouer.
@export var reflect_interval: float = 0.0
@export var reflect_window: float = 0.0
@export_range(0.0, 100.0) var reflect_pct: float = 0.0

@export_group("Mecaniques de boss v3")
## Six mecaniques de boss (27 septembre). Chacune pose au joueur une question
## qu aucune autre ne pose ; tous les champs valent 0 / vide par defaut, donc un
## monstre qui ne les declare pas se comporte exactement comme avant.

## L HORLOGER — toutes les `rewind_interval` secondes il REVIENT `rewind_seconds`
## secondes en arriere : a la position ET aux PV qu il avait alors. 0 = jamais.
##
## Ce que la mecanique change : le MOMENT ou frapper, mais a l envers du renvoi.
## Les degats portes pendant les `rewind_seconds` qui precedent un retour sont
## effaces ; ceux portes JUSTE APRES un retour restent. Le joueur apprend a
## garder son gros sort pour l instant qui suit le retour.
##
## LA GARANTIE DE FIN est structurelle : l intervalle est toujours force au-dessus
## de la duree du retour (voir Enemy), donc il existe a chaque cycle une fenetre
## ou les degats tiennent. `rewind_max` ajoute un plafond dur par-dessus.
@export var rewind_interval: float = 0.0
@export var rewind_seconds: float = 3.0
## Nombre maximal de retours sur tout le combat. 0 = pas de plafond (la fenetre
## suffit a garantir la fin, le plafond ne sert qu a raccourcir le combat).
@export var rewind_max: int = 0

## LES JUMEAUX — deux monstres (ou plus) portant le MEME `twin_group` sont lies :
## si l un tombe pendant qu un autre tient debout, il reste A TERRE (intouchable,
## immobile) et se RELEVE apres `twin_revive_delay` secondes avec
## `twin_revive_hp_pct` % de ses PV. Si le dernier debout tombe pendant ce temps,
## tous meurent pour de bon. Vide = monstre ordinaire.
##
## Ce que la mecanique change : la CIBLE n est plus un monstre mais une paire.
## La bonne reponse est un sort de zone, ou deux frappes rapprochees.
## Plafond `twin_max_returns` par jumeau : sans lui, un joueur sans zone ne
## finirait jamais le combat.
@export var twin_group: StringName = &""
@export var twin_revive_delay: float = 4.0
@export_range(1.0, 100.0) var twin_revive_hp_pct: float = 60.0
@export var twin_max_returns: int = 2

## LE CAMELEON — toutes les `chameleon_interval` secondes il change d element
## faible et d element resiste, en parcourant `chameleon_elements` dans l ordre
## (vide = les huit elements). L element resiste est celui qui se trouve a
## l oppose du cycle, jamais le meme que le faible. 0 = jamais.
##
## Meme semantique que `resistances` (multiplicateur de degats subis), et meme
## regle multi-element : un sort qui porte plusieurs elements retient le PLUS
## FAIBLE. Le Cameleon ne doit donc pas declarer ces elements dans `resistances`,
## sinon les deux tables se multiplient.
##
## `chameleon_resist_mult` est borne au-dessus de 0 : une immunite tournante
## obligerait le joueur a attendre, ce qui n est pas une decision.
@export var chameleon_interval: float = 0.0
@export var chameleon_elements: Array[int] = []
@export_range(1.0, 3.0) var chameleon_weak_mult: float = 1.5
@export_range(0.1, 1.0) var chameleon_resist_mult: float = 0.5

## LE VOLEUR DE SORTS — toutes les `steal_interval` secondes il petrifie UNE
## carte de la main (la plus longue a incanter), puis `steal_cast_delay` secondes
## plus tard la LANCE CONTRE LE MAGE. 0 = jamais.
##
## LA REGLE DES DEGATS, simple et lisible : chaque seconde d incantation de la
## carte volee coute `steal_damage_per_cast_second` points de vitesse. Un gros
## sort vole fait mal, un petit presque rien : le joueur comprend d un coup
## d oeil ce qu il risque.
##
## CE QUE DEVIENT LA CARTE : lancee par le voleur, elle part a la DEFAUSSE comme
## si le joueur l avait jouee — il la reverra au prochain melange. Tue avant son
## lancement, le voleur la rend : elle redevient jouable en main.
@export var steal_interval: float = 0.0
@export var steal_cast_delay: float = 4.0
@export var steal_damage_per_cast_second: float = 6.0

## LE DEVOREUR-INVOCATEUR — `devour_heal_pct` : a chaque proie avalee, le
## devoreur se SOIGNE de ce pourcentage des PV restants de la proie, sans
## depasser son maximum. 0 = comportement historique du Glouton (il grossit :
## +50 % des PV max de la proie en PV max et en PV, et +18 % de taille).
##
## Avec un soin, il ne grossit plus : un invocateur qui grossirait a chaque sbire
## avale deviendrait un mur de PV sans fin.
@export_range(0.0, 200.0) var devour_heal_pct: float = 0.0
## Age minimal (s) d un de SES sbires avant qu il puisse l avaler. Sans ce delai
## le sbire, qui nait colle a lui, etait gobe l image suivante : l invocation etait
## invisible et le joueur ne voyait qu une regeneration. Une fois murs, il les
## RAPPELLE ou qu ils soient. Ne s applique qu a ses propres invocations.
@export var devour_delay: float = 3.0

## LE MIROIR DU MAGE — sa vitesse suit celle du mage : a `mirror_speed_ref` %
## de vitesse du mage il avance a sa vitesse de base, au double il va deux fois
## plus vite, borne dans [`mirror_speed_min`, `mirror_speed_max`]. 0 = inactif.
##
## Ce que la mecanique change : elle met a l epreuve « la vitesse est la vie ».
## Contre lui, etre rapide le rend rapide, et encaisser un coup le ralentit plus
## que le reste du monde. Le facteur s ajoute a l horloge du monde, il ne la
## remplace pas.
@export var mirror_speed_ref: int = 0
@export var mirror_speed_min: float = 0.5
@export var mirror_speed_max: float = 2.0

@export_group("Briseur de terrain")
## LE BRISEUR DE TERRAIN — toutes les `terrain_break_interval` secondes (temps du
## MONDE), il choisit l objet de terrain le plus proche a moins de
## `terrain_break_reach` px, s arrete, prepare son coup pendant
## `terrain_break_windup` secondes, puis le DETRUIT. 0 = jamais.
##
## Ce que la mecanique change : le decor n est plus une reponse definitive. Tous
## les sorts de terrain (murs, arbres, ronces, fosse, autel) sont payes une fois
## et tiennent le combat ; devant lui, ils ne tiennent que tant qu il vit. La
## question posee au joueur est « le tuer d abord, ou reposer derriere lui ».
##
## LE GESTE EST LA MOITIE DE LA MECANIQUE. Pendant la preparation il est plante,
## une marque rougit sur l objet vise et sa legende dit ce qu il va briser : le
## joueur doit comprendre POURQUOI son mur a disparu, et il a le temps d y
## repondre. Le tuer ou l etourdir pendant la preparation ANNULE le coup — c est
## la reponse de controle, et elle doit exister.
##
## L EAU N EST PAS UN OBJET QU ON CASSE : la nappe et la Riviere sont epargnees
## (voir Battlefield.BREAKER_SPARED_KINDS). La Riviere est une legendaire tres
## chere et unique par combat ; la briser d un geste ferait de ce monstre un
## contre absolu de la carte la plus rare du jeu, et on ne fend pas de l eau.
@export var terrain_break_interval: float = 0.0
@export var terrain_break_reach: float = 520.0
@export var terrain_break_windup: float = 1.5

@export_group("Anciens boss")
## ANCIEN BOSS PROMU EN VERMINE — l id du boss (ou mini-boss) dont ce monstre est
## la version ALLEGEE. Vide = monstre d origine.
##
## POURQUOI UN CHAMP et pas une convention d id (`<boss>_echo`) : l acte 5 raconte
## que « les anciens boss redeviennent des monstres ordinaires », et ce propos est
## TESTE (test_campaign_acts). Une convention d id se casse au premier renommage
## sans que rien ne rougisse ; un champ se lit, et le garde-fou de test_bosses
## peut comparer la vermine a son boss d origine : moins de PV, jamais un boss.
@export var demoted_from: StringName = &""


## Multiplicateur de degats subis pour UN tag. 1.0 si rien n est declare.
func resistance_to(tag: int) -> float:
	if resistances.has(tag):
		return maxf(float(resistances[tag]), 0.0)
	# Repli sur l ancien champ : une immunite heritee vaut resistance 0.
	if tag in immune_tags:
		return 0.0
	return 1.0


## Multiplicateur pour un SORT, lu sur `SpellCard.combat_tags()`. Depuis la
## vague 8 une carte n a qu UN element : la regle du PLUS FAIBLE ne joue plus
## que pour un tableau fabrique a la main (test, effet ancien). Elle reste,
## parce qu un second element ne doit jamais etre un contournement gratuit.
##
## Les tags non elementaires (SLOW, SUMMON) sont ignores ici : ils ne portent
## pas les degats, ils qualifient l effet.
func resistance_to_tags(tags: Array) -> float:
	var m: float = 1.0
	var vu: bool = false
	for t in tags:
		if not (t in GameEnums.ELEMENTS):
			continue
		var r: float = resistance_to(t)
		m = r if not vu else minf(m, r)
		vu = true
	return m


## Vrai quand RIEN ne passe. Garde le nom d origine : tout le code qui posait la
## question en binaire (ralentissement, retour visuel) continue de fonctionner,
## et la reponse vient maintenant de la table.
func is_immune_to(tag: GameEnums.DamageTag) -> bool:
	return resistance_to(tag) <= 0.0


## Facteur de vitesse effectif d un ralentissement, resistance comprise.
## Un monstre qui resiste a 50 % au ralentissement doit etre ralenti MOITIE
## MOINS, pas insensible : l immunite binaire ne laissait que tout ou rien, ce
## qui rendait les cartes de controle inutilisables contre la moitie du bestiaire.
##
## `tags` : l element du sort qui ralentit. Un Champ de givre sur un monstre qui
## resiste au GIVRE le ralentit moins, meme s il ne resiste pas au ralentissement
## en soi (voir control_factor). Vide = seule la ligne SLOW compte (passifs).
func slow_factor(factor: float, tags: Array = []) -> float:
	var r: float = control_factor(tags, true)
	if r <= 0.0:
		return 1.0
	# `factor` = 0.5 signifie « moitie de vitesse », soit 50 % de perte.
	# On attenue la PERTE, pas la vitesse.
	return clampf(1.0 - (1.0 - factor) * r, 0.05, 1.0)


## LA RESISTANCE S APPLIQUE AUX EFFETS, PAS SEULEMENT AUX DEGATS (vague 5).
##
## Demande du co-auteur : « un monstre qui resiste a la glace resistera a ses
## ralentissements ; un monstre qui resiste au vent sera moins attire ». Chaque
## effet NON DEGAT d un sort (ralentir, etourdir, repousser, aspirer, attirer,
## renverser la marche, rendre vulnerable, dissiper) est donc multiplie par ce
## facteur, lu sur l ELEMENT de la carte qui le porte :
##   - element du sort = resistance_to_tags (le PIRE element pour le joueur,
##     meme regle que les degats, sinon un second element serait un passe-droit) ;
##   - `slows` : l effet est un RALENTISSEMENT (zone, jauge, courant,
##     etourdissement) ; la ligne SLOW garde alors son sens et le facteur retient
##     le plus petit des deux. Un golem immunise au ralentissement n est donc
##     pas plus ralenti par un sort d arcane que par un sort de givre.
##
## L EFFET SUIT L ELEMENT DE LA CARTE (vague 8, huit elements) : Maelstrom,
## Spirale de sel, Onde de repulsion et Volte-face sont de VENT, le Totem et les
## Ronces de NATURE, la Nappe montante d EAU. Un monstre immunise au vent n est
## donc ni aspire, ni repousse, ni retourne par eux ; un monstre qui resiste a
## la nature ne sent l appel du Totem que de pres.
##
## PLAFOND A 1 : une faiblesse accelere la mort, elle ne rend pas le controle
## plus fort. Un monstre qui craint le givre a +100 % ne doit pas etre fige a
## 95 % par un simple Champ de givre, ni aspire deux fois plus loin : le
## controle est deja le levier le plus puissant du jeu (DEC etourdissement), et
## une faiblesse qui le doublerait rendrait certaines vagues triviales.
func control_factor(tags: Array, slows: bool = false) -> float:
	var f: float = minf(resistance_to_tags(tags), 1.0)
	if slows:
		f = minf(f, resistance_to(GameEnums.DamageTag.SLOW))
	return clampf(f, 0.0, 1.0)


## LES COUPS D UN MONSTRE SUR UN OBJET DE TERRAIN (vague 8, regle du co-auteur).
##
## « Un mur de glace subira moins de degats d un monstre faible a la glace. »
## Un objet pose par une carte (mur, totem, ronces, autel, semis...) porte
## l ELEMENT de cette carte, et ce qu un monstre lui inflige est multiplie par
## l INVERSE de sa relation a cet element :
##
##   r = multiplicateur de degats que le monstre SUBIT de cet element (table
##       jouee, apres accentuation, Cameleon compris)
##   facteur = r ^ -OBJECT_HIT_EXPONENT, borne a [OBJECT_HIT_MIN, OBJECT_HIT_MAX]
##
## Regle SYMETRIQUE (en ecart relatif) : faible x2 a la glace -> il frappe le
## mur de glace a x0,71 ; resistant x0,5 -> il le frappe a x1,41 ; neutre ->
## inchange. Une immunite (r = 0) vaut le plafond : la glace ne lui fait rien,
## il la brise sans retenue.
##
## LA MOITIE DE L ECART (exposant 0,5) et pas l inverse entier : depuis la
## vague 8 les objets de NATURE (Totem, Bastion, Autel, Semis) heritent de
## l ancienne ligne physique, que 53 monstres resistent. L inverse entier les
## aurait fait abattre jusqu a deux fois plus vite par la moitie du bestiaire —
## un objet est un investissement du joueur, la regle doit se SENTIR sans
## renverser les niveaux qui reposent sur lui (lvl_04 et son Totem).
##
## BORNEE aux memes bornes que les degats du joueur (WEAK_CAP = x2) : un objet
## ne doit jamais devenir increvable ni fondre au premier contact.
const OBJECT_HIT_EXPONENT: float = 0.5
const OBJECT_HIT_MIN: float = 0.5
const OBJECT_HIT_MAX: float = 2.0


static func object_hit_factor(r: float) -> float:
	if r <= 0.0:
		return OBJECT_HIT_MAX
	return clampf(pow(r, -OBJECT_HIT_EXPONENT), OBJECT_HIT_MIN, OBJECT_HIT_MAX)


## ACCENTUATION DES RESISTANCES (vague 5) — la regle UNIQUE qui transforme la
## table ecrite dans tools/make_content.gd (`_resist`) en table jouee.
##
##   resistance (r < 1) : r ^ RESIST_EXPONENT      0,5 -> 0,30 ; 0,85 -> 0,75
##   faiblesse  (r > 1) : r ^ WEAK_EXPONENT, plafonnee a WEAK_CAP
##                                                 1,2 -> 1,58 ; 1,35 -> 2,0
##   immunite (0) et neutre (1) inchanges.
##
## POURQUOI UNE PUISSANCE et pas un ecart multiplie : elle ne franchit jamais
## zero. Un ecart x1,4 aurait fait d une resistance de 0,25 une immunite, et
## une immunite est une decision de design, pas un effet de bord d un reglage.
##
## POURQUOI DEUX EXPOSANTS : la lecon du banc (catalog_enemies) — le joueur ne
## choisit pas l element qu il pioche, et resister coute plus de lancers que
## craindre n en fait gagner (1/r est convexe). Accentuer les deux cotes a la
## meme force aurait rendu le jeu plus dur a chaque niveau ; la faiblesse est
## donc accentuee plus fort, et pour les petits ecarts (+/- 15 %) le cout moyen
## en lancers reste celui d avant.
##
## LE PLAFOND x2 : au-dela, un sort de base tuerait un boss faible a son element
## en deux fois moins de lancers qu un sort legendaire neutre — la rarete ne
## voudrait plus rien dire. « Degats doubles » se lit aussi d un coup d oeil.
const RESIST_EXPONENT: float = 1.75
const WEAK_EXPONENT: float = 2.5
const WEAK_CAP: float = 2.0


static func accentuate(r: float) -> float:
	if r <= 0.0:
		return 0.0
	if r < 1.0:
		return snappedf(pow(r, RESIST_EXPONENT), 0.01)
	if r > 1.0:
		return minf(snappedf(pow(r, WEAK_EXPONENT), 0.01), WEAK_CAP)
	return 1.0


func is_boss() -> bool:
	return kind == GameEnums.EnemyKind.BOSS or kind == GameEnums.EnemyKind.MINIBOSS


## Degats infliges au mage au contact. Le bareme vit dans GameConfig pour qu un
## reglage d equilibrage ne demande pas de rouvrir 22 fichiers de contenu.
func contact_hit() -> int:
	if contact_damage > 0:
		return contact_damage
	if kind == GameEnums.EnemyKind.BOSS:
		return GameConfig.CONTACT_DAMAGE_BOSS
	if kind == GameEnums.EnemyKind.MINIBOSS:
		return GameConfig.CONTACT_DAMAGE_MINIBOSS
	return int(GameConfig.CONTACT_DAMAGE_BY_POWER.get(power, 5))
