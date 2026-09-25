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
## Degats infliges au mage au contact (passe par le bouclier avant les PV).
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
## Encaisse le premier coup sans degat (halo visible tant qu il tient).
@export var first_hit_shield: bool = false
## Soigne tous les autres monstres de N PV par seconde tant qu il est en vie.
@export var heal_per_second: float = 0.0
## Tire un projectile sur le mage toutes les N secondes. 0 = ne tire pas.
@export var shoot_interval: float = 0.0
## Les tirs font PEU de degats : ils harcelent, ils ne tuent pas. Un archer qui
## fait aussi mal qu une charge rend la distance plus dangereuse que le contact.
@export var shot_damage: int = 2

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
## Le compteur ne mange QUE des degats : un etourdissement ou un ralentissement
## n en consomme aucun. Sinon la mecanique cesserait d etre « depense tes coups »
## pour devenir « N secondes d invulnerabilite totale », ce qui ne se joue pas.
@export_range(0, 12) var hits_immune: int = 0

## BOUCLIER DE RENVOI — toutes les `reflect_interval` secondes il leve une garde
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


## Multiplicateur de degats subis pour UN tag. 1.0 si rien n est declare.
func resistance_to(tag: int) -> float:
	if resistances.has(tag):
		return maxf(float(resistances[tag]), 0.0)
	# Repli sur l ancien champ : une immunite heritee vaut resistance 0.
	if tag in immune_tags:
		return 0.0
	return 1.0


## Multiplicateur pour un SORT, qui peut porter plusieurs elements (le Meteore
## est feu + physique). On retient le PLUS FAIBLE, donc le meilleur pour le
## monstre : sinon ajouter un second element a une carte serait un bonus gratuit
## et toute carte finirait bi-element pour contourner les resistances.
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
func slow_factor(factor: float) -> float:
	var r: float = resistance_to(GameEnums.DamageTag.SLOW)
	if r <= 0.0:
		return 1.0
	# `factor` = 0.5 signifie « moitie de vitesse », soit 50 % de perte.
	# On attenue la PERTE, pas la vitesse.
	return clampf(1.0 - (1.0 - factor) * r, 0.05, 1.0)


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
