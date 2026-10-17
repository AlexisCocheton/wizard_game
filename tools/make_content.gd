extends Node
## Generateur de contenu de depart. Ecrit les .tres via ResourceSaver pour garantir
## un format valide. A relancer apres modification du schema des Resources.

func _ready() -> void:
	await get_tree().process_frame
	_enemies()
	_cards()
	_majeures()  # VAGUE 10 B1b : deux ameliorations majeures par sort (fin du fichier)
	_waves_and_level()
	load("res://tools/make_side_quests.gd").new().generer(self)  # B3 : annexes et boss dores
	print("CONTENT_OK")
	CleanExit.quit(0)


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		printerr("Echec ecriture %s (err %d)" % [path, err])
	else:
		print("  ecrit ", path)


func _enemy(id: String, dname: String, kind: GameEnums.EnemyKind, power: int,
		hp: float, speed: float, xp: int, shape: GameEnums.Shape, color: Color,
		radius: float = 28.0) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = StringName(id)
	e.display_name = dname
	e.kind = kind
	e.power = power
	e.max_hp = hp
	e.base_speed = speed
	e.base_xp = xp
	e.shape = shape
	e.color = color
	e.base_radius = radius
	return e


## RESISTANCES — chaque monstre oppose un pourcentage a chaque element.
##
## Une table par monstre, jamais une table commune : ce sont les ECARTS qui
## donnent une raison de changer de deck. Un golem de pierre encaisse le
## physique et se fend a l arcane ; une gelee fond au feu mais baigne dans le
## poison ; un mort-vivant ne sent pas le venin. Le joueur qui lit le bestiaire
## doit pouvoir en deduire quoi emporter.
##
## PLAFOND DES ECARTS : +/- 35 % au plus, et +15 % seulement quand le niveau ou
## le monstre apparait fournit deja un deck de cet element. Mesure au banc :
## l Ossuaire (deck a 43 % de feu, vagues de gelees et de goules toutes
## vulnerables au feu a +30 %) montait a 100 % de victoires, au-dessus du
## plafond de 95 %. Un niveau dont le deck fourni EST la reponse doit rester
## avantageux sans se jouer tout seul.
##
## REGLE D EQUILIBRAGE : la somme des ecarts d un monstre reste proche de zero
## (autant de resistance que de vulnerabilite, ponderee). Sans cette regle, la
## table serait un reglage de difficulte deguise et decalerait les sept niveaux
## deja mesures au banc. Ici elle deplace la difficulte d un DECK a l autre, pas
## le niveau global.
##
## Cles : 0.0 = immunite, 0.5 = moitie des degats, 1.5 = degats majores.
##
## ACCENTUATION (vague 5) : les tables ci-dessous sont ECRITES dans l ancienne
## echelle (+/- 35 %) et JOUEES apres `EnemyDef.accentuate()`, la regle unique
## qui creuse les ecarts (0,5 -> 0,30 ; 1,2 -> 1,58 ; plafond x2 ; immunites
## gardees). Une seule regle plutot que 82 retouches : l intention de chaque
## table (le golem craint l arcane, le colosse le givre) reste lisible telle
## qu elle a ete pensee, et le prochain reglage ne touchera qu une constante.
##
## LES HUIT ELEMENTS (vague 8) — LA REGLE DE PASSAGE, pas 86 decisions.
##
## Les tables ci-dessous sont restees ECRITES dans les mots d avant (« phys »,
## « givre ») : elles disent l intention de chaque monstre telle qu elle a ete
## pensee et mesuree. `_resist` les traduit en huit elements par une regle
## unique :
##
##   glace  = givre (le meme element, renomme)
##   feu, arcane, poison, foudre, ralentissement : inchanges
##   VENT   = phys  : l ancienne ligne physique disait la DURETE du corps, ce qui
##            arrete une fleche ou une onde. Ces sorts sont devenus de vent :
##            leur effet sur chaque monstre ne bouge pas.
##   NATURE = phys  : pierre, ronce, racine, bois — des coups de MATIERE, que la
##            meme durete arrete. Le golem resiste aux deux, le squelette fragile
##            craint les deux.
##   sauf les VOLANTS : le vent est leur milieu, ils y sont au moins faibles
##            (vent >= 1,2) ; la terre ne les atteint pas, ils resistent a la
##            nature (nature <= 0,65).
##   EAU    = 2 - feu, borne a [0,65 ; 1,35] : l eau eteint ce que le feu nourrit.
##            Un ver de feu immunise au feu craint l eau ; une plante qui brule
##            boit l eau ; un monstre neutre au feu est neutre a l eau.
##
## Une valeur ECRITE sous le nouveau nom (« vent », « nature », « eau »,
## « glace ») l emporte sur la regle : c est la porte des exceptions voulues,
## et il n y en avait aucune au 02/10. Les valeurs neutres (1,0) ne sont pas
## stockees : la fiche n affiche que les ecarts.
##
## LES ANCRES AU SOL (chantier W9) — la premiere exception, et la seule : le
## second exemple du co-auteur, « un monstre IMMUNISE au VENT n est pas attire par
## une attraction de vent », n existait que dans les tests (le vent le plus bas
## du bestiaire etait 0,3). Vharn l Enclume et son Echo sont des ENCLUMES de
## fonte : aucun souffle ne les deplace, aucune fleche ne les entame. Ecrit
## « vent » = 0 dans leur table ; la nature (pierre, ronce) garde la regle, elle
## frappe la matiere et l enclume en est. Pourquoi eux et pas le Golem ou le
## Behemoth : ils sont aussi lourds, mais l un ou l autre descend dans HUIT
## niveaux, des le tutoriel dont le deck porte trois Fleches percantes (vent) :
## l immunite y aurait annule une carte du deck de depart et deplace huit niveaux
## mesures pour un seul exemple. Vharn ferme lvl_07, dont le deck porte la
## Spirale de sel (une attraction de vent : l exemple exact) et la Rupture de
## chaine ; son Echo descend dans lvl_13 et lvl_16, ou le joueur porte au
## moins les Fleches percantes gagnees en route (hors campagne) et la regle se
## lit au bestiaire. test_eight_elements exige qu un niveau montre l exemple.
## test_elements lit cette liste : une autre exception rougit.
## VAGUE 10 B2 : l Echo de Vharn est retire (un boss de l acte 4 ne revient
## nulle part sous la regle des promotions, voir _promus_w10) ; Vharn reste.
const ANCRES_AU_SOL: Array[String] = ["demon_anvil"]
const WIND_FLYER_MIN: float = 1.2
const NATURE_FLYER_MAX: float = 0.65
const WATER_FROM_FIRE_MIN: float = 0.65
const WATER_FROM_FIRE_MAX: float = 1.35

## REEQUILIBRAGE DE LA VAGUE 10 (co-auteur, 14/10 : « rends-les un peu plus
## equilibrees : trop de monstres immunises au poison »). Mesure sur les 86
## tables jouees avant ce chantier : 32 immunises au POISON et 37 resistants,
## pour 5 faibles ; 56 resistants a la NATURE pour 23 faibles. Deux regles de
## passage, et non 86 retouches : l INTENTION de chaque table (qui resiste a
## quoi, et plus ou moins fort) reste celle qui a ete ecrite.
##
## LE POISON n est plus un element de niche : le Dard venimeux est une commune
## depuis la vague 8. L immunite n est gardee QUE pour ce qui n a ni chair ni
## sang a ronger — la boule de poison (elle EST du venin), la pierre (Golem), la
## machine (Golem mecanique), le verre (Miroir de verre, Eclat de miroir), le
## sceau (Sceau de Tombol). Ailleurs, une immunite ecrite compte comme une
## resistance de moitie (0,5 : « le venin les ronge mal », les morts-vivants),
## et TOUTE resistance au poison ecrite garde la moitie de son ecart
## (POISON_ECART) : 0,8 -> 0,9, 0,5 -> 0,75. Une faiblesse au poison est
## gardee telle quelle. test_resist_tiers lit cette liste : une immunite au
## poison hors liste rougit.
const IMMUNISES_AU_POISON: Array[String] = ["poison_ball", "golem", "mecha_golem",
	"glass_mirror", "mirror_shard", "tombol_seal"]
const POISON_IMMUNITE_HORS_LISTE: float = 0.5
const POISON_ECART: float = 0.5
## LA NATURE ne nait plus de TOUTE la durete : la moitie de son ecart
## (NATURE_ECART). La regle de la vague 8 (nature = vent = l ancien « phys »)
## donnait a la nature, element des murs, des arbres et du sable, la meme
## distribution que la fleche : 56 monstres sur 86 la resistaient, et chaque
## objet de nature (Totem, Bastion, Mur de pierre) etait frappe plus fort par
## les deux tiers du bestiaire. La durete GARDE son sens (le golem resiste aux
## deux, le squelette fragile craint les deux), en plus doux pour la nature. Le
## VENT, lui, garde tout l ecart : il porte la Fleche percante du deck de
## depart, le deplacer aurait deplace les huit niveaux mesures qui la portent.
## Les volants gardent leur regle (nature <= NATURE_FLYER_MAX).
const NATURE_ECART: float = 0.5


func _resist(e: EnemyDef, table: Dictionary) -> EnemyDef:
	var T := GameEnums.DamageTag
	var ecrit: Dictionary = {}
	for nom in table.keys():
		ecrit[String(nom)] = float(table[nom])
	for nom in ecrit.keys():
		if not nom in ["phys", "feu", "givre", "glace", "arcane", "poison", "foudre",
				"lent", "vent", "nature", "eau"]:
			printerr("element inconnu dans une table de resistances : ", nom)
	var dur: float = float(ecrit.get("phys", 1.0))
	var vent: float = float(ecrit.get("vent", dur))
	var nature: float = float(ecrit.get("nature", 1.0 + (dur - 1.0) * NATURE_ECART))
	if e.flying and not ecrit.has("vent"):
		vent = maxf(vent, WIND_FLYER_MIN)
	if e.flying and not ecrit.has("nature"):
		nature = minf(nature, NATURE_FLYER_MAX)
	var feu: float = float(ecrit.get("feu", 1.0))
	var eau: float = float(ecrit.get("eau",
		clampf(2.0 - feu, WATER_FROM_FIRE_MIN, WATER_FROM_FIRE_MAX)))
	var poison: float = float(ecrit.get("poison", 1.0))
	if poison <= 0.0 and not String(e.id) in IMMUNISES_AU_POISON:
		poison = POISON_IMMUNITE_HORS_LISTE
	if poison > 0.0 and poison < 1.0:
		poison = 1.0 - (1.0 - poison) * POISON_ECART
	var joue: Dictionary = {
		T.FIRE: feu,
		T.WATER: eau,
		T.NATURE: nature,
		T.WIND: vent,
		T.LIGHTNING: float(ecrit.get("foudre", 1.0)),
		T.ICE: float(ecrit.get("glace", ecrit.get("givre", 1.0))),
		T.ARCANE: float(ecrit.get("arcane", 1.0)),
		T.POISON: poison,
		T.SLOW: float(ecrit.get("lent", 1.0)),
	}
	var accentue: Dictionary = {}
	for tag in joue.keys():
		accentue[tag] = EnemyDef.accentuate(float(joue[tag]))
	# Le CAMELEON ne declare pas les elements de son cycle (EnemyDef : les deux
	# tables se multiplieraient). La regle ci-dessus pourrait en deriver un (le
	# vent et la nature naissent de « phys ») : on les retire AVANT les paliers,
	# pour qu ils ne pesent pas sur les groupes des autres elements.
	for t in e.chameleon_elements:
		accentue.erase(int(t))
	# Vague 10 : la table jouee est mise aux PALIERS (EnemyDef.tiered_table) —
	# huit valeurs rondes, les ecarts voisins d un meme monstre alignes, les
	# ecarts trop proches de zero effaces.
	var out: Dictionary = EnemyDef.tiered_table(accentue)
	e.resistances = out
	# L ancien champ est vide desormais : la table est la seule source de verite.
	# Le laisser rempli ferait exister DEUX endroits ou lire une immunite, et
	# c est toujours le second qu on oublie de mettre a jour.
	e.immune_tags = []
	return e


## Hierarchie : puissance 1 (chair a canon) -> 4 (menace), boss hors budget.
## Chaque famille a SA forme et SA couleur pour etre reconnue immediatement.
func _enemies() -> void:
	var K := GameEnums.EnemyKind
	var S := GameEnums.Shape
	var E := "res://resources/enemies/"

	# --- Puissance 1 ---
	var gnome := _enemy("gnome", "Gnome", K.NORMAL, 1, 12.0, 70.0, 1, S.SQUARE, Color(0.62, 0.42, 0.28), 26.0)
	gnome.anim_key = &"pawn_red"
	# Petite brute en cuir bouilli : le coup qui porte lui glisse un peu dessus,
	# la flamme prend tout de suite. Son ecart est volontairement FAIBLE : c est
	# le monstre de reference, celui sur lequel le joueur juge tous les autres.
	_resist(gnome, {&"phys": 0.9, &"feu": 1.15})
	_save(gnome, E + "gnome.tres")

	var sprite := _enemy("sprite", "Lutin fileur", K.FAST, 1, 6.0, 150.0, 1, S.TRIANGLE, Color(0.98, 0.82, 0.30), 18.0)
	sprite.anim_key = &"beetle"
	# VAGUE 10 B2 — « DETALE » (revue A4, §1.1) : un lutin qui file tout droit
	# n etait qu un PV rapide. Il saute de colonne en colonne (le motif de
	# l Adepte des arcanes, plus court) : la zone posee a l avance le rate une fois
	# sur deux, la Fleche percante qui couvre la colonne le trouve.
	sprite.move_pattern = EnemyDef.MovePattern.HOP
	sprite.pattern_width = 100.0
	sprite.pattern_interval = 1.2
	# Fileur : il va si vite que le froid ne le prend pas et que la foudre le
	# traverse sans l arreter. Mais 6 PV et aucune armure : le moindre coup
	# physique le coupe en deux.
	_resist(sprite, {&"phys": 1.2, &"givre": 0.85, &"foudre": 0.8})
	_save(sprite, E + "sprite.tres")

	var jelly_small := _enemy("jelly_small", "Gelee (petite)", K.SPLITTER, 1, 6.0, 85.0, 1, S.CIRCLE, Color(0.55, 0.92, 0.45), 12.0)
	jelly_small.anim_key = &"slimer"
	# Gelee : masse molle et acide. Les coups s y enfoncent sans rien trancher,
	# le poison s y dissout, le froid la durcit sans la tuer. Le feu la fait
	# bouillir — c est la reponse, et le joueur doit la trouver.
	_resist(jelly_small, {&"phys": 0.8, &"feu": 1.15, &"givre": 0.8, &"poison": 0.55})
	_save(jelly_small, E + "jelly_small.tres")

	var jelly_mid := _enemy("jelly_mid", "Gelee (moyenne)", K.SPLITTER, 1, 14.0, 65.0, 1, S.CIRCLE, Color(0.50, 0.88, 0.42), 20.0)
	jelly_mid.anim_key = &"slimer"
	jelly_mid.split_into = jelly_small
	jelly_mid.split_count = 2
	# Meme chair que la petite : une division ne change pas ce dont on est fait.
	_resist(jelly_mid, {&"phys": 0.8, &"feu": 1.15, &"givre": 0.8, &"poison": 0.55})
	_save(jelly_mid, E + "jelly_mid.tres")

	# --- Puissance 2 ---
	# Renomme "Oiseau mirage" (demande du testeur). L id reste `rat_swarm` : il
	# est grave dans toutes les vagues, les pools de niveau et les sauvegardes de
	# bestiaire deja sur les telephones. Renommer l id casserait ces references
	# pour un simple changement d etiquette.
	var swarm := _enemy("rat_swarm", "Oiseau mirage", K.SWARM, 2, 4.0, 110.0, 1, S.CIRCLE, Color(0.85, 0.52, 0.62), 13.0)
	swarm.anim_key = &"peacock"
	swarm.swarm_count = 4
	# Oiseau mirage : nuee de plumes. Le feu et la foudre balayent un groupe
	# serre ; l arcane, qui vise une cible, se perd dans le mirage.
	_resist(swarm, {&"phys": 1.1, &"feu": 1.3, &"arcane": 0.85, &"foudre": 1.2})
	_save(swarm, E + "rat_swarm.tres")

	# BOULE DE POISON — la munition du Planogo. C est un EnemyDef et non un
	# projectile a part : tout le ciblage, les zones et les degats existants s y
	# appliquent donc sans une ligne de code neuve, et le testeur obtient ce
	# qu il demandait — "qui a 10 PV", donc DESTRUCTIBLE.
	# `projectile` la tient hors du bestiaire et hors de l XP : on ne farme pas
	# des munitions, on tue la source.
	var poison_ball := _enemy("poison_ball", "Boule de poison", K.FAST, 1, 10.0, 120.0, 0, S.CIRCLE, Color(0.45, 1.00, 0.30), 16.0)
	poison_ball.anim_key = &"poison_ball"
	poison_ball.projectile = true
	# Volante : elle survole les murs comme celui qui la tire. Un mur qui
	# arreterait la boule mais pas le Planogo serait incomprehensible.
	poison_ball.flying = true
	# 8 : elle pique nettement moins qu un contact de Planogo (15 en P2), donc
	# l ignorer coute, mais ne punit pas comme de laisser passer le tireur.
	poison_ball.contact_damage = 8
	# Munition de venin : elle EST du poison, en arroser une n a aucun sens. La
	# bruler la fait eclater en vol. Le froid la fige sans la percer.
	_resist(poison_ball, {&"feu": 1.35, &"givre": 0.7, &"arcane": 1.15, &"poison": 0})
	_save(poison_ball, E + "poison_ball.tres")

	# PLANOGO (ex "Feu follet"). Vole par-dessus les murs et tire des boules de
	# poison : il ne se gere ni par le decor ni en l ignorant.
	var wisp := _enemy("wisp", "Planogo", K.EVASIVE, 2, 10.0, 90.0, 2, S.CIRCLE, Color(0.45, 0.90, 0.88), 22.0)
	wisp.anim_key = &"flyer"
	wisp.dodge_chance = 0.35
	wisp.flying = true
	# Les boules passent par le mecanisme d INVOCATION existant plutot que par
	# `shoot_interval` : un tir traverse le terrain et frappe le mage sans qu on
	# puisse rien y faire, alors qu une invocation est un corps sur le terrain,
	# que le joueur voit arriver et peut abattre.
	wisp.summon_def = poison_ball
	wisp.summon_interval = 5.0
	wisp.summon_count = 1
	# Deux boules en l air au plus : au-dela, un groupe de Planogos noierait
	# l ecran sous des munitions et la vague ne se lirait plus.
	wisp.summon_max_alive = 2
	# Planogo : corps a peine materiel. Une fleche le traverse ; l arcane et la
	# foudre, elles, frappent la chose et non la forme. C est le monstre qui
	# punit un deck tout physique.
	_resist(wisp, {&"phys": 0.65, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.3, &"foudre": 1.2})
	_save(wisp, E + "wisp.tres")

	var shade := _enemy("shade", "Ombre", K.PHASER, 2, 16.0, 80.0, 3, S.DIAMOND, Color(0.42, 0.40, 0.80), 26.0)
	shade.anim_key = &"vulture"
	shade.phase_interval = 2.5
	# Ombre : rien de solide a percer ni a empoisonner. L arcane l atteint parce
	# qu elle agit sur ce qui la tient ensemble, pas sur sa chair.
	_resist(shade, {&"phys": 0.65, &"feu": 0.9, &"arcane": 1.3, &"poison": 0, &"foudre": 1.1})
	_save(shade, E + "shade.tres")

	var archer := _enemy("imp_archer", "Lutin archer", K.SHOOTER, 2, 14.0, 48.0, 3, S.DIAMOND, Color(0.90, 0.32, 0.28), 24.0)
	archer.anim_key = &"archer_red"
	archer.shoot_interval = 3.5
	# L archer harcele : sa fleche pique, elle ne perce pas. Un contact de gnome
	# (4 PV) doit rester plus grave qu une fleche.
	archer.shot_damage = 2
	# Lutin des braises : il vit dans le feu, il ne le craint pas. Le givre lui
	# fige les doigts — et un archer qui ne tire plus n est plus une menace.
	_resist(archer, {&"phys": 1.1, &"feu": 0.8, &"givre": 1.2})
	_save(archer, E + "imp_archer.tres")

	var serpent := _enemy("sand_serpent", "Serpent des sables", K.WAVER, 2, 20.0, 75.0, 2, S.CAPSULE, Color(0.32, 0.72, 0.68), 24.0)
	serpent.anim_key = &"lancer_yellow"
	serpent.wave_amplitude = 170.0
	serpent.wave_frequency = 0.55
	# Creature des sables, ecailleuse et a sang froid : la chaleur est son
	# element, le gel l engourdit. Ondulant ET resistant au feu, il oblige a
	# changer d element ET a mieux viser.
	_resist(serpent, {&"phys": 0.9, &"feu": 0.8, &"givre": 1.3, &"poison": 0.85})
	_save(serpent, E + "sand_serpent.tres")

	var hopper := _enemy("hopper", "Sauterelle", K.BURSTER, 2, 10.0, 95.0, 2, S.TRIANGLE, Color(0.55, 0.85, 0.30), 20.0)
	hopper.anim_key = &"dog"
	hopper.burst_move = true
	hopper.burst_dash_time = 0.5
	hopper.burst_pause_time = 0.8
	# Sauterelle : carapace et nerfs. La foudre coupe les nerfs en plein bond ;
	# le venin ne mord pas sur une chitine, et le froid la ralentit a peine.
	_resist(hopper, {&"phys": 1.1, &"givre": 0.9, &"poison": 0.8, &"foudre": 1.3})
	_save(hopper, E + "hopper.tres")

	# --- Puissance 3 ---
	var horn := _enemy("hornblower", "Corniste", K.BUFFER, 3, 18.0, 55.0, 3, S.HEXAGON, Color(0.92, 0.60, 0.25), 28.0)
	horn.anim_key = &"monk_purple"
	horn.entry_side = true
	horn.buff_speed_pct = 20.0
	# Corniste : il porte des protections rituelles contre la magie savante,
	# pas contre un orage. Le faire taire vite vaut mieux que le taper fort.
	_resist(horn, {&"phys": 0.95, &"feu": 1.1, &"arcane": 0.8, &"foudre": 1.2})
	_save(horn, E + "hornblower.tres")

	var golem := _enemy("golem", "Golem de pierre", K.TANK, 3, 55.0, 32.0, 4, S.SQUARE, Color(0.50, 0.50, 0.56), 40.0)
	golem.anim_key = &"golem_blue"
	# GOLEM DE PIERRE — l exemple que le testeur a nomme. De la roche : les
	# coups s y ebrechent, le feu et le gel n y mordent pas, le venin n a rien a
	# empoisonner. Mais il tient par une RUNE, et l arcane la defait. Il reste
	# insensible au ralentissement : une masse lancee ne se retient pas.
	_resist(golem, {&"phys": 0.65, &"feu": 0.85, &"givre": 0.9, &"arcane": 1.35, &"poison": 0, &"foudre": 1.1, &"lent": 0})
	_save(golem, E + "golem.tres")

	var berserker := _enemy("berserker", "Berserker", K.ENRAGER, 3, 30.0, 58.0, 4, S.SQUARE, Color(0.70, 0.15, 0.18), 30.0)
	berserker.anim_key = &"warrior_red"
	berserker.enrage_speed_pct = 12.0
	berserker.enrage_cap = 1.5
	# Berserker : sa peau tannee encaisse, et le sang qui bout brule le venin. Le
	# feu et l arcane, eux, passent sous la fureur.
	#
	# Il RESISTAIT AU GIVRE (0,8, « la rage le rechauffe ») jusqu a la vague 5.
	# Depuis que la resistance freine aussi les RALENTISSEMENTS, resister au givre
	# coute double au joueur : moins de degats ET moins de controle. Sur le
	# monstre le plus courant du jeu (21 vagues), c etait un mur contre tout deck
	# de givre — l Arene de Kaltek, deck de givre face a des berserkers a chaque
	# vague, tombait de ~63 % a ~40 % de victoires au banc (sonde : ~69 % en
	# retirant la seule regle des effets). La resistance est reportee sur le
	# poison, qu aucun deck de ces niveaux ne porte en masse.
	_resist(berserker, {&"phys": 0.9, &"feu": 1.15, &"givre": 1.0, &"arcane": 1.1, &"poison": 0.75})
	_save(berserker, E + "berserker.tres")

	var knight := _enemy("void_knight", "Chevalier du vide", K.SHIELDED, 3, 34.0, 55.0, 4, S.HEXAGON, Color(0.55, 0.35, 0.85), 30.0)
	knight.anim_key = &"lancer_purple"
	knight.first_hit_shield = true
	# Chevalier du vide : armure faite pour AVALER la magie. Contre lui, la
	# reponse est le metal et l orage, pas un deck de sorts arcaniques — c est
	# le retournement le plus net du bestiaire.
	_resist(knight, {&"phys": 1.15, &"givre": 1.1, &"arcane": 0.65, &"poison": 0.7, &"foudre": 1.15})
	_save(knight, E + "void_knight.tres")

	var jelly := _enemy("jelly", "Gelee", K.SPLITTER, 3, 36.0, 50.0, 3, S.CIRCLE, Color(0.45, 0.85, 0.40), 32.0)
	jelly.anim_key = &"slimer"
	jelly.split_into = jelly_mid
	jelly.split_count = 2
	# GELEE — l autre exemple nomme par le testeur. Meme table que ses enfants :
	# ce qui se divise garde sa nature.
	_resist(jelly, {&"phys": 0.8, &"feu": 1.15, &"givre": 0.8, &"poison": 0.55})
	_save(jelly, E + "jelly.tres")

	var priest := _enemy("ghoul_priest", "Pretre goule", K.HEALER, 3, 24.0, 45.0, 5, S.STAR, Color(0.78, 0.95, 0.72), 28.0)
	priest.anim_key = &"monk_black"
	priest.heal_per_second = 3.0
	# PRETRE GOULE — le mort-vivant du testeur. Rien a empoisonner dans un corps
	# deja mort, et le froid ne raidit pas ce qui est deja raide. Le feu, lui,
	# consume la charogne : c est ainsi qu on arrete un soigneur.
	_resist(priest, {&"phys": 0.8, &"feu": 1.15, &"givre": 0.8, &"arcane": 1.1, &"poison": 0})
	_save(priest, E + "ghoul_priest.tres")

	var hive := _enemy("hive", "Ruche", K.BOMBER, 3, 40.0, 40.0, 4, S.HEXAGON, Color(0.95, 0.72, 0.20), 34.0)
	hive.anim_key = &"warrior_yellow"
	hive.split_into = sprite
	hive.split_count = 4
	# Ruche : nid de cire et de larves. Bruler un nid le vide d un coup ; le
	# frapper ne fait que sortir ce qu il y a dedans.
	_resist(hive, {&"phys": 0.9, &"feu": 1.35, &"givre": 1.1, &"poison": 0.65})
	_save(hive, E + "hive.tres")

	# --- Puissance 4 ---
	var totem := _enemy("totem_guardian", "Gardien-totem", K.GUARDIAN, 4, 60.0, 30.0, 8, S.STAR, Color(0.85, 0.70, 0.35), 36.0)
	totem.anim_key = &"totem_tower"
	totem.aura_shield_radius = 240.0
	# Gardien-totem : bois grave et pierre. L aura vient de la gravure, donc
	# l arcane la brise, et le bois brule. Il attire la foudre au lieu de la
	# subir. Le tuer VITE est tout l enjeu : ses resistances disent comment.
	_resist(totem, {&"phys": 0.7, &"feu": 1.15, &"givre": 0.9, &"arcane": 1.3, &"poison": 0, &"foudre": 0.85})
	_save(totem, E + "totem_guardian.tres")

	var glutton := _enemy("glutton", "Glouton", K.DEVOURER, 4, 70.0, 42.0, 8, S.CIRCLE, Color(0.60, 0.25, 0.60), 38.0)
	glutton.anim_key = &"dino"
	glutton.devours = true
	# Glouton : il gobe tout, y compris ce qu il ne faut pas. L empoisonner de
	# l interieur est le seul moyen rapide — ses bourrelets absorbent le reste.
	# C est la carte de venin qui trouve enfin sa cible.
	_resist(glutton, {&"phys": 0.85, &"feu": 1.1, &"givre": 0.85, &"arcane": 0.9, &"poison": 1.35})
	_save(glutton, E + "glutton.tres")

	var behemoth := _enemy("behemoth", "Behemoth", K.TANK, 4, 130.0, 26.0, 9, S.SQUARE, Color(0.36, 0.34, 0.40), 52.0)
	behemoth.anim_key = &"golem_orange"
	# Behemoth : 130 PV de cuir et d os. Rien de physique ne l entame vraiment ;
	# sa masse conduit la foudre et l arcane atteint ce qui l anime. Trop lourd
	# pour etre ralenti.
	_resist(behemoth, {&"phys": 0.7, &"feu": 0.85, &"givre": 0.85, &"arcane": 1.2, &"poison": 0.8, &"foudre": 1.15, &"lent": 0})
	_save(behemoth, E + "behemoth.tres")

	# --- Boss (hors budget) ---
	# VAGUE 10 B2 — LE GARDIEN DEVIENT UN VRAI BOSS, celui qui ferme l acte 1
	# (`lvl_09`, le seul niveau ou il descend depuis que le tutoriel a son propre
	# mini-boss). 165 PV au lieu de 140 : il porte l acte, et son Echo (56 PV)
	# reste sous la moitie (190 PV : abattu 5 fois sur 50 au banc, le premier
	# jet). Son armure lourde existait dans les textes, pas dans le jeu : L ARMURE
	# QUI SE REFERME. Le premier coup glisse ; six secondes sans etre touche et
	# elle se referme. La reponse : enchainer les coups
	# (l Etincelle du deck), poser une zone, ou dissiper (Vide d emprise).
	var warden := _enemy("warden", "Gardien", K.BOSS, 10, 165.0, 40.0, 30, S.HEXAGON, Color(0.90, 0.40, 0.25), 62.0)
	warden.anim_key = &"chaosknight"
	warden.first_hit_shield = true
	warden.shield_regen = 6.0
	# Armure lourde et bouclier. Un boss doit avoir une REPONSE, pas une armure
	# uniforme : la sienne est la magie savante.
	_resist(warden, {&"phys": 0.8, &"feu": 0.85, &"givre": 0.95, &"arcane": 1.2, &"foudre": 1.15})
	_save(warden, E + "warden.tres")

	# QUATRE MINI-BOSS DE PLUS, un par monde du mode infini.
	#
	# POURQUOI. Le Massacre pose un mini-boss toutes les 3 vagues et traverse
	# CINQ mondes, mais le jeu n avait qu UN SEUL monstre de type MINIBOSS : le
	# Gardien revenait a chaque palier, dans chaque monde. C est exactement le
	# defaut corrige pour la campagne (onze adversaires au lieu de deux), et il
	# restait entier cote mode infini.
	#
	# Chacun oppose une REPONSE differente, jamais une armure uniforme : c est
	# ce qui fait qu on change de deck plutot que de lancer plus de sorts. Les
	# silhouettes viennent des trois feuilles du catalogue qu aucun monstre
	# n utilisait, plus une promotion — rien n est dessine.

	# MONDE VOLANT. Leger et rapide la ou les autres mini-boss sont lourds : il
	# n encaisse pas, il ARRIVE. La reponse est la zone posee en avance, pas le
	# tir tendu.
	var skyreaver := _enemy("skyreaver", "Ecumeur du ciel", K.MINIBOSS, 6,
		96.0, 62.0, 12, S.TRIANGLE, Color(0.55, 0.80, 0.95), 54.0)
	skyreaver.anim_key = &"pawn_yellow"
	skyreaver.flying = true
	# VAGUE 10 B2 — LE MINI-BOSS DU TUTORIEL (`lvl_01`, a la place du Gardien, qui
	# meurt au lvl_09 apres y avoir ete presente en allie). « PIQUE » : il fonce
	# 0,6 s puis plane 1,2 s, et sa pause montre ou poser la Boule de feu. La
	# lecon du tutoriel : viser ou il SERA, pas ou il est. Il vole : les murs ne
	# l arretent pas, la Fleche percante (vent) le cueille.
	skyreaver.burst_move = true
	skyreaver.burst_dash_time = 0.6
	skyreaver.burst_pause_time = 1.2
	_resist(skyreaver, {&"phys": 1.2, &"feu": 0.9, &"givre": 0.7, &"arcane": 1.0, &"foudre": 1.25})
	_save(skyreaver, E + "skyreaver.tres")

	# GRAND CIMETIERE. L inverse du precedent : lent, lourd, immunise au poison
	# comme tout mort-vivant. Le givre le fige, le feu le consume.
	var bonewarden := _enemy("bonewarden", "Gardien d ossements", K.MINIBOSS, 6,
		165.0, 30.0, 13, S.HEXAGON, Color(0.80, 0.78, 0.70), 64.0)
	bonewarden.anim_key = &"warrior_black"
	# VAGUE 10 B2 — « GARDE LEVEE » : toutes les 6 s il leve son bouclier 2,5 s
	# (la pose `guard` de warrior_black, jamais jouee jusqu ici) et les COUPS n y
	# font que 15 % ; les zones et les poisons passent en entier. Il prepare le
	# Reliquaire, boss du meme niveau, qui lui aussi compte les coups : ici on
	# apprend que le RYTHME compte, et qu un degat continu ne se pare pas.
	bonewarden.reflect_interval = 6.0
	bonewarden.reflect_window = 2.5
	bonewarden.reflect_pct = 0.0
	bonewarden.guard_block_pct = 85.0
	_resist(bonewarden, {&"phys": 0.75, &"feu": 1.25, &"givre": 1.15, &"arcane": 0.9, &"poison": 0})
	_save(bonewarden, E + "bonewarden.tres")

	# MONDE DEMONIAQUE. Il rend les coups : resistant au feu de son propre
	# monde, il craint le givre — le choc thermique, comme le Colosse.
	var emberlord := _enemy("emberlord", "Seigneur de braise", K.MINIBOSS, 6,
		150.0, 38.0, 13, S.DIAMOND, Color(0.95, 0.45, 0.20), 62.0)
	emberlord.anim_key = &"pawn_purple"
	# VAGUE 10 B2 — « RIPOSTE DE BRAISE » : son commentaire promettait « il rend
	# les coups », rien ne le faisait. Le laser de riposte du Golem a noyau, en
	# braise : chaque COUP qui mord renvoie 3 degats au mage (2 s au plus souvent) ;
	# ni zone ni poison ne la declenchent (DEC-054). La reponse : peu de gros
	# coups, des zones, le givre qu il craint.
	emberlord.laser_damage = 3
	emberlord.laser_cooldown = 2.0
	_resist(emberlord, {&"phys": 0.9, &"feu": 0.55, &"givre": 1.35, &"arcane": 1.0, &"poison": 0.8, &"foudre": 1.1})
	_save(emberlord, E + "emberlord.tres")

	# MONDE D ORIGINE. Promotion du Gardien-totem, deja dans le jeu : le testeur
	# demandait qu un boss d acte redevienne un monstre courant ; ici c est le
	# chemin inverse, un monstre courant qui prend du galon. Sa silhouette est
	# donc deja connue du joueur, ce qui rend la promotion lisible.
	var totem_elder := _enemy("totem_elder", "Totem ancien", K.MINIBOSS, 6,
		175.0, 26.0, 14, S.SQUARE, Color(0.60, 0.85, 0.55), 66.0)
	totem_elder.anim_key = &"totem_tower"
	# VAGUE 10 B2 — « AURA ANCIENNE » (revue A4, priorite n° 1) : la silhouette
	# mentait, le grand totem faisait moins que le petit. Il protege maintenant
	# les monstres a 180 px autour de lui, comme le Gardien-totem (240) en plus
	# serre. La dissipation garantie (DEC-057) vaut aussi pour lui : son niveau
	# (`lvl_20`) a la Lumiere purifiante au deck.
	totem_elder.aura_shield_radius = 180.0
	_resist(totem_elder, {&"phys": 0.7, &"feu": 1.2, &"givre": 0.95, &"arcane": 1.3, &"poison": 0, &"lent": 0.5})
	_save(totem_elder, E + "totem_elder.tres")

	var chronos := _enemy("chronos", "Chronos", K.BOSS, 10, 320.0, 34.0, 30, S.STAR, Color(0.95, 0.20, 0.25), 84.0)
	chronos.anim_key = &"juggernaut"
	# VAGUE 10 B2 — « ECHEANCE », l huissier des delais (lvl_01_outro). Toutes les
	# 9 s il se plante 2 s sous un sablier : un COUP pendant ce temps et il reste
	# etourdi 1 s ; sinon le mage perd 6 points de vitesse. La seule mecanique du
	# jeu ou NE PAS frapper coute, l inverse exact du Miroir. Le tutoriel l y
	# prepare : trois Traits arcaniques au deck, une carte rapide a garder.
	chronos.deadline_interval = 9.0
	chronos.deadline_window = 2.0
	chronos.deadline_stun = 1.0
	chronos.deadline_penalty = 6
	# CHRONOS — il regne sur le temps : le gel, qui n est qu un ralentissement
	# deguise, glisse sur lui, et le ralentir est hors de question. En revanche
	# il n a aucune armure : l acier et la flamme, choses grossieres, le
	# touchent pleinement. Le boss qui recompense un deck SIMPLE.
	_resist(chronos, {&"phys": 1.15, &"feu": 1.15, &"givre": 0.7, &"arcane": 0.9, &"poison": 1.1, &"lent": 0})
	_save(chronos, E + "chronos.tres")

	# --- Boss a MECANIQUE, hors budget (docs/histoire.md) -------------------
	# Un boss doit demander une reponse DIFFERENTE, pas plus de sorts. Les trois
	# qui suivent changent chacun une question du jeu : ou frapper (morcele),
	# quand aller chercher (canonnier), quoi tuer en premier (invocateur).

	# Le sbire de l Ensevelisseur : une goule levee a la chaine. Volontairement
	# faible et lente — la menace est le FLUX, pas l unite. Puissance 1 pour que
	# le Glouton puisse les gober : un boss qui invoque doit nourrir le terrain.
	# VAGUE 10 B2 — « CHAROGNARD » (revue A4, §1.1) : une goule dessinee en
	# vautour qui contournait les murs. Il VOLE, et porte le nom de sa feuille :
	# le flux de l Ensevelisseur passe au-dessus des murs, la seule reponse
	# redevient « tuer la source ».
	var risen := _enemy("risen_ghoul", "Charognard leve", K.NORMAL, 1, 9.0, 62.0, 1,
		S.DIAMOND, Color(0.55, 0.65, 0.45), 20.0)
	risen.anim_key = &"vulture"
	risen.flying = true
	# Goule levee : meme chair morte que le Pretre. Une nuee de mort-vivants se
	# nettoie au feu, jamais au venin — et c est exactement la lecon du niveau.
	_resist(risen, {&"phys": 0.85, &"feu": 1.1, &"givre": 0.85, &"arcane": 1.05, &"poison": 0})
	_save(risen, E + "risen_ghoul.tres")

	# INVOCATEUR — lvl_04, Le Grand Appel. Le Pretre goule qui mene le rituel :
	# il ne se bat pas, il REMPLIT l ecran. Ses PV sont volontairement bas pour
	# un boss (220 contre 320 a Chronos) parce que la vraie difficulte est le
	# flux : si le joueur coupe la source vite, il gagne le combat. C est
	# exactement la decision qu on veut lui faire prendre.
	var gravecaller := _enemy("gravecaller", "L Ensevelisseur", K.BOSS, 10, 220.0, 30.0, 30,
		S.STAR, Color(0.55, 0.85, 0.55), 76.0)
	gravecaller.anim_key = &"unhallowed"
	gravecaller.summon_def = load(E + "risen_ghoul.tres")
	gravecaller.summon_interval = 5.0
	gravecaller.summon_count = 2
	# Plafond serre : au-dela, le joueur perd par accumulation mecanique et non
	# par erreur de jeu. Six goules a l ecran suffisent a l etouffer.
	gravecaller.summon_max_alive = 6
	# L Ensevelisseur : le plus grand des morts-vivants. Sa table est celle de
	# ses goules, en plus dur : le joueur qui a compris le niveau sait deja quoi
	# lancer quand le boss arrive.
	_resist(gravecaller, {&"phys": 0.9, &"feu": 1.2, &"givre": 0.8, &"arcane": 1.1, &"poison": 0, &"foudre": 1.05})
	_save(gravecaller, E + "gravecaller.tres")

	# MORCELE — lvl_05, Forges du Mauvais Temps. Les creatures des forges ne
	# sont pas nees, elles ont ete COULEES : celle-ci se demonte plaque par
	# plaque. Le coeur (150 PV) est plus tendre que les quatre plaques (200 PV
	# cumules) : le combat est donc un travail de DEMONTAGE, pas d usure.
	# Le surplus d un coup ne coule pas d une plaque a l autre, ce qui punit le
	# gros sort unique et recompense le tir soutenu.
	var forge_colossus := _enemy("forge_colossus", "Colosse des Forges", K.BOSS, 10, 150.0, 30.0, 30,
		S.HEXAGON, Color(0.80, 0.55, 0.25), 80.0)
	forge_colossus.anim_key = &"decepticle"
	# Le decepticle occupe 33 % de sa case : sans cette correction il entrerait
	# a la taille d un gnome (voir assets.md, « cases mal remplies »).
	forge_colossus.sprite_scale = 1.15
	forge_colossus.parts_count = 4
	forge_colossus.part_hp = 50.0
	# 18 % par plaque : les quatre tombees, il avance a 28 % de sa vitesse. Assez
	# lent pour se lire comme demantele, assez vivant pour rester une menace.
	forge_colossus.part_slow_pct = 18.0
	# Colosse des Forges : coule dans le metal en fusion. Le feu ne fait que le
	# rechauffer ; le choc thermique du givre, lui, fend les plaques. Un boss
	# morcele qu on attaque a l element exactement oppose a son decor.
	_resist(forge_colossus, {&"phys": 0.8, &"feu": 0.6, &"givre": 1.35, &"arcane": 1.1, &"poison": 0, &"foudre": 1.15, &"lent": 0})
	_save(forge_colossus, E + "forge_colossus.tres")

	# CANONNIER — lvl_06, La Cour brisee. Un seigneur demon qui ne daigne pas
	# descendre : il campe a 620 px du mage et harcele. Il ne peut donc JAMAIS
	# etre attendu sur la ligne de defense — c est le seul boss qu il faut aller
	# chercher. PV bas (170) : il est deja tres difficile a atteindre.
	var wraith_lord := _enemy("wraith_lord", "Seigneur Spectre", K.BOSS, 10, 170.0, 70.0, 30,
		S.DIAMOND, Color(0.55, 0.45, 0.85), 70.0)
	wraith_lord.anim_key = &"wraith"
	# Mesure au banc : a 620 px avec 20 % d esquive, le boss etait a la fois hors
	# de portee pratique et difficile a punir — il causait la moitie des degats du
	# niveau sans jamais rien risquer, et lvl_06 tombait a 20 % de victoires.
	# Il tient toujours ses distances, mais assez pres pour etre puni, et sans
	# esquive : sa protection est sa POSITION, pas un jet de des.
	wraith_lord.keeps_distance_at = 430.0
	wraith_lord.shoot_interval = 3.4
	# Tir de boss : plus lourd qu une fleche de lutin (2), loin du contact d un
	# boss (50). Il doit user le joueur, pas le tuer avant qu il l atteigne.
	wraith_lord.shot_damage = 5
	wraith_lord.dodge_chance = 0.0
	# Seigneur Spectre : il campe au loin et il n a pas de corps. Un deck de
	# fleches echoue deux fois contre lui — la distance ET la matiere. C est le
	# boss qui exige un deck magique, annonce par ses tables des la Cour brisee.
	_resist(wraith_lord, {&"phys": 0.6, &"feu": 0.95, &"givre": 1.05, &"arcane": 1.3, &"poison": 0, &"foudre": 1.15})
	_save(wraith_lord, E + "wraith_lord.tres")

	# --- CHANTIER I : trois boss de plus, trois QUESTIONS de plus -------------
	#
	# Les trois premiers boss a mecanique changeaient OU frapper (morcele), QUAND
	# aller le chercher (canonnier) et QUOI tuer d abord (invocateur). Les trois
	# qui suivent changent trois choses qu aucun boss du jeu ne touchait :
	#
	#   ce que « tuer » veut dire   -> il se releve une fois (Coagule)
	#   la MONNAIE des degats       -> il compte les coups, pas les points (Reliquaire)
	#   le MOMENT du lancement      -> il renvoie ce qu on lui envoie (Miroir)
	#
	# Aucune ne demande un asset absent : ce sont trois regles, pas trois dessins.
	# Les silhouettes sont des feuilles du catalogue qu AUCUN monstre n utilisait
	# (`blood`, `lancer_red`, `monk_blue`) — rien n est dessine par le code.

	# RESSUSCITE — le Coagule, BOSS de `lvl_08` (la route du maire) depuis la vague
	# 10 (il menait la vague de boss de lvl_02, que la Reine gorgone prend). Une
	# masse de sang tenue en forme. On peut l abattre, il se remet debout, une
	# fois. Le joueur voit la barre se vider, entend la mort, se retourne vers la
	# vague — et il se releve derriere lui.
	#
	# PV volontairement BAS pour un boss (185 contre 320 a Chronos) : la mecanique
	# ajoute deja 40 % de PV, et un boss a 320 PV qui ressuscite en pesserait 450,
	# ce qui aurait fait de lui le plus gros sac de PV du jeu au niveau 2 — donc
	# exactement ce qu un boss a mecanique NE doit pas etre. 185 + 74 = 259, sous
	# Chronos : le releve est une surprise, pas un mur.
	# LE NOM SUIT LE SPRITE, jamais l inverse. Premier jet : "Le Sablier", une
	# creature de sable pour La Tour des Sables. Verifie sur capture
	# (.testout/boss_04_sablier_intact) : la feuille `blood` montre une masse
	# rouge sombre et coagulee, qui ne se lit a aucun moment comme du sable — le
	# joueur aurait lu un nom et vu autre chose. On garde la feuille, qui est une
	# excellente silhouette de boss, et on nomme la creature pour ce qu elle
	# MONTRE : une chose qui se recoagule apres qu on l a defaite. Le lieu y
	# gagne meme — quelque chose de vivant enterre sous la tour.
	var coagule := _enemy("blood_coagulum", "Le Coagule", K.BOSS, 10, 185.0, 40.0, 30,
		S.DIAMOND, Color(0.72, 0.18, 0.22), 72.0)
	coagule.anim_key = &"blood"
	# Le blood monster n occupe que 20 % de sa case (voir assets.md) : sans
	# correction il entrerait a la taille d un lutin.
	coagule.sprite_scale = 1.25
	coagule.revive_hp_pct = 40.0
	# Le Coagule : une masse sans organes. Rien a trancher, rien a empoisonner ;
	# le givre la prend en bloc et le feu la cautérise. Ce sont les deux reponses,
	# et le joueur qui les trouve n a pas a lui rendre deux combats.
	_resist(coagule, {&"phys": 0.7, &"feu": 1.3, &"givre": 1.25, &"arcane": 1.0, &"poison": 0, &"foudre": 0.9})
	_save(coagule, E + "blood_coagulum.tres")

	# IMMUNISE AUX N PREMIERS COUPS — lvl_03, Ossuaire des Marees. Un reliquaire
	# scelle par six sceaux : chaque sort en brise UN, quelle que soit sa
	# puissance. Six fleches de lutin et six Meteores coutent exactement pareil.
	#
	# SIX et non dix : le joueur du niveau 3 tire une carte toutes les ~6 s et sa
	# main fait 5 cartes. Six coups, c est une main entiere depensee avant de
	# toucher le boss — assez pour que la lecon porte, pas assez pour que le boss
	# traverse l ecran pendant qu il paie.
	#
	# PV BAS (135) : la mecanique EST la difficulte. Un boss qui coute six cartes
	# ET 300 PV serait deux boss.
	var reliquary := _enemy("bone_reliquary", "Le Reliquaire", K.BOSS, 10, 135.0, 32.0, 30,
		S.HEXAGON, Color(0.85, 0.82, 0.72), 76.0)
	reliquary.anim_key = &"lancer_red"
	# SPRITE_SCALE 1,7 — mesure sur capture (.testout/boss_01_reliquaire_6_sceaux).
	# L occupancy 0,45 de la feuille `lancer_red` est calculee LANCE COMPRISE :
	# la hampe occupe la moitie de la case, donc le CORPS entre a la taille d un
	# monstre de puissance 3. C est sans consequence pour le Chevalier du vide
	# (P3, meme famille de feuille), mais un boss de puissance 10 qui se lit plus
	# petit que son escorte annule tout le travail de mise en scene.
	reliquary.sprite_scale = 1.7
	reliquary.hits_immune = 6
	# Le Reliquaire : ossements et metal sacre. Mort-vivant, donc insensible au
	# venin ; le feu consume l os et l arcane defait le sceau. Mais on ne le
	# ralentit pas : une procession ne s arrete pas.
	_resist(reliquary, {&"phys": 0.85, &"feu": 1.25, &"givre": 0.9, &"arcane": 1.2, &"poison": 0, &"lent": 0})
	_save(reliquary, E + "bone_reliquary.tres")

	# BOUCLIER DE RENVOI — lvl_05, Forges du Mauvais Temps (mini-boss). Une plaque
	# de verre coulee aux forges : toutes les 7 s elle leve sa face polie pendant
	# 2,5 s, et ce qu on lui envoie repart. Le joueur doit REGARDER le boss avant
	# de lancer, ce qu aucune autre vague du jeu ne lui demande.
	#
	# MINI-BOSS et non BOSS : la mecanique punit le lancement, donc elle doit etre
	# ENSEIGNEE avant d etre appliquee a un boss de fin de niveau. Un mini-boss
	# arrive au tiers du niveau, avec une escorte legere, et le joueur a le temps
	# de voir la garde se lever deux ou trois fois avant de la payer.
	#
	# 2,5 s de garde pour 7 s de cycle : la garde est levee un tiers du temps.
	# Assez pour attraper le joueur qui lance sans regarder, assez rare pour que
	# celui qui regarde ne soit jamais bloque plus de deux secondes et demie.
	var mirror := _enemy("glass_mirror", "Le Miroir de Forge", K.MINIBOSS, 6, 130.0, 34.0, 13,
		S.STAR, Color(0.70, 0.88, 0.95), 62.0)
	mirror.anim_key = &"monk_blue"
	mirror.reflect_interval = 7.0
	mirror.reflect_window = 2.5
	# 45 % : la moitie de ce que le joueur envoie, pas la totalite. A 100 % le
	# renvoi n est plus un prix, c est une interdiction — et le plafond par coup
	# (Battlefield.REFLECT_MAX_PER_HIT) fait le reste du travail.
	mirror.reflect_pct = 45.0
	# Le Miroir : du verre. Le physique le FEND (+30 %, la plus grosse faiblesse
	# physique du bestiaire) et c est voulu — le sort le plus banal du jeu est la
	# bonne reponse, a condition de le lancer au bon moment. Toute la difficulte
	# est dans le TIMING, jamais dans le choix de l element.
	_resist(mirror, {&"phys": 1.3, &"feu": 0.85, &"givre": 1.15, &"arcane": 0.75, &"poison": 0, &"foudre": 0.8})
	_save(mirror, E + "glass_mirror.tres")


	# --- CHANTIER I2 : les silhouettes du 26 septembre entrent en jeu --------
	#
	# Quatorze feuilles avaient ete extraites et inscrites dans AnimCatalog sans
	# qu AUCUN monstre ne les porte : du travail sur le disque, invisible en jeu.
	# Sept entrent ici, choisies parce qu elles debloquent une demande NOMMEE du
	# testeur, pas parce qu il restait des feuilles a caser.
	#
	# Ce qui est ECARTE et pourquoi, pour que le choix soit relisible :
	#   flyingeye, goblin2, skeleton2, evilwizard, fireworm, ghoul, bluewitch,
	#   nightborne, mageguardian — neuf silhouettes sans mecanique a servir. Le
	#   bestiaire compte deja 21 types et cinq familles de comportement par
	#   monde ; en ajouter neuf qui descendent tout droit avec d autres PV
	#   diluerait chaque monde sans rien apprendre au joueur, et le garde-fou de
	#   densite (build_membership) les repartirait au hasard des vagues ou on les
	#   aurait glissees. Une silhouette merite un monstre quand elle porte une
	#   REPONSE nouvelle, jamais quand elle est disponible.

	# LE REGARD, palier 1 — monstre COMMUN qui gele UNE carte.
	#
	# Demande du testeur, mot pour mot : « Creer un monstre normal qui en bloque
	# 1, un mini bosse qui en bloque 2 et un bosse qui en bloque 3. »
	#
	# P3 et non P2 : geler une carte de la main est plus cher pour le joueur que
	# n importe quel comportement de puissance 2 du bestiaire — il perd un sixieme
	# de ses options tant qu elle vit, quel que soit le reste de la vague. Les PV
	# sont en revanche VOLONTAIREMENT BAS pour un P3 (26 contre 55 au golem) : la
	# reponse est « tue-la vite », et un P3 blinde qui gele une carte serait une
	# taxe de vingt secondes au lieu d une cible prioritaire.
	#
	# LENTE (38 px/s) : il faut qu elle vive assez longtemps pour que le joueur
	# VOIE sa main se figer et comprenne d ou ca vient. Une gorgone rapide serait
	# morte ou au contact avant qu il ait lu la cause.
	var gorgon := _enemy("gorgon_gazer", "Gorgone", K.NORMAL, 3, 26.0, 38.0, 5,
		S.DIAMOND, Color(0.55, 0.80, 0.50), 30.0)
	gorgon.anim_key = &"gorgon"
	gorgon.blocks_cards = 1
	# Chair ecailleuse de serpent : le froid l engourdit, le venin ne mord pas sur
	# ce qui en est fait. Le physique la fend — la reponse est la carte la plus
	# banale du deck, et c est voulu : geler une carte ne doit pas geler la REPONSE.
	_resist(gorgon, {&"phys": 1.25, &"feu": 1.0, &"givre": 1.2, &"arcane": 0.85, &"poison": 0.6})
	_save(gorgon, E + "gorgon_gazer.tres")

	# LE REGARD, palier 2 — MINI-BOSS qui gele DEUX cartes.
	#
	# Elle prend la tete du mini-boss de `lvl_02`, ou descendait le Corniste : un
	# monstre ORDINAIRE de puissance 3 menait ce palier, ce qui n en faisait pas
	# un palier. Le Corniste reste dans la vague, comme escorte — son buff de
	# vitesse a enfin un sens sous une tete qui, elle, mutile la main.
	#
	# C est le palier PEDAGOGIQUE : deux cartes gelees au niveau 2, avec une main
	# de 5 ou 6 cartes, cout reel et lisible, sans jamais approcher le plafond.
	# Le joueur apprend la mecanique ici pour la payer a trois plus tard.
	var gorgon_mini := _enemy("gorgon_matron", "Matrone gorgone", K.MINIBOSS, 6,
		120.0, 32.0, 12, S.DIAMOND, Color(0.40, 0.70, 0.45), 56.0)
	gorgon_mini.anim_key = &"gorgon"
	gorgon_mini.blocks_cards = 2
	# 120 PV, le plus BAS des mini-boss du jeu (contre 165 au Gardien d ossements).
	# Deux cartes gelees valent deja des PV : un mini-boss qui gele la main ET
	# encaisse comme les autres serait deux mini-boss.
	_resist(gorgon_mini, {&"phys": 1.2, &"feu": 1.1, &"givre": 1.15, &"arcane": 0.8, &"poison": 0.55})
	_save(gorgon_mini, E + "gorgon_matron.tres")

	# LE REGARD, palier 3 — BOSS qui gele TROIS cartes.
	#
	# POURQUOI ELLE N A PAS DE NIVEAU DE CAMPAGNE. Les sept niveaux ont chacun
	# leur boss, et six portent une mecanique ecrite pour eux (morcele,
	# canonnier, invocateur, ressuscite, compteur de coups, renvoi). Lui faire de
	# la place voulait dire en deplacer un, donc casser le chantier I et la
	# narration de docs/histoire.md. Elle regne donc sur le MASSACRE : c est la
	# ou le joueur va chercher les combats que la campagne ne contient pas, et
	# `pick_boss()` tire au hasard parmi les boss du monde — elle sort vraiment,
	# la sonde de test_bosses le verifie sur 300 vagues.
	#
	# Elle descend AUSSI comme escorte d une vague de campagne (`w2_5`), ce qui
	# lui donne son monde et la rend rencontrable avant le Massacre.
	#
	# TROIS cartes, jamais plus : le plafond de la main (5 sur 6) la borne deja,
	# mais un seul monstre a 4 regards y arriverait tout seul, et la mecanique
	# cesserait d etre un cout pour devenir une interdiction de jouer.
	var gorgon_boss := _enemy("gorgon_queen", "Reine gorgone", K.BOSS, 10,
		230.0, 28.0, 30, S.DIAMOND, Color(0.30, 0.60, 0.38), 74.0)
	gorgon_boss.anim_key = &"gorgon"
	# La feuille gorgon occupe 60 % de sa case : correct pour un monstre commun,
	# trop petit pour une tete de Massacre a cote d un Behemoth.
	gorgon_boss.sprite_scale = 1.3
	gorgon_boss.blocks_cards = 3
	# 230 PV, sous Chronos (320) : la mecanique coute deja au joueur la moitie de
	# ses options. Le physique reste sa faille, comme chez ses filles : la reponse
	# a toute la lignee est la meme, et le joueur qui l a trouvee sur la Gorgone
	# commune la garde jusqu a la Reine.
	_resist(gorgon_boss, {&"phys": 1.2, &"feu": 1.05, &"givre": 1.1, &"arcane": 0.8, &"poison": 0.5, &"lent": 0.5})
	_save(gorgon_boss, E + "gorgon_queen.tres")

	# LE SLIME DEMONIAQUE. Demande du testeur : « toujours le meme concept de
	# slime mais dans le monde demon et immunise au feu ».
	#
	# CE QUE L IMMUNITE AU FEU CHANGE, et c est tout l interet de la demande : la
	# Gelee est LE monstre qu on brule, c est ecrit dans sa table (+15 % au feu)
	# et le joueur l apprend des le premier niveau. Le slime demoniaque a la meme
	# silhouette de masse molle, la meme division a la mort — et le reflexe
	# acquis ne fait RIEN. C est la meilleure facon d enseigner qu il faut lire le
	# bestiaire plutot que reconnaitre une forme.
	#
	# Il se divise en Gelees MOYENNES existantes plutot qu en enfants dedies :
	# deux raisons. Ses enfants n heritent PAS de son immunite, donc le joueur qui
	# a insiste au feu est recompense a la seconde moitie du combat — la mecanique
	# a une sortie. Et la silhouette des enfants est celle qu il connait deja, donc
	# il lit tout de suite ce qui vient de tomber.
	var demon_slime := _enemy("demon_slime", "Slime demoniaque", K.SPLITTER, 4,
		78.0, 44.0, 9, S.CIRCLE, Color(0.85, 0.25, 0.30), 42.0)
	demon_slime.anim_key = &"demonslime"
	# La feuille demonslime fait 210 px de case pour 50 % d occupation : c est la
	# plus grande du catalogue. Sans reduction il ecraserait un Behemoth alors
	# qu il n est qu un P4.
	demon_slime.sprite_scale = 0.85
	demon_slime.split_into = jelly_mid
	demon_slime.split_count = 2
	# IMMUNISE AU FEU (0.0), mot pour mot la demande. Le givre en revanche le
	# prend en bloc : le choc thermique est la reponse du monde demoniaque, deja
	# celle du Colosse des Forges et du Seigneur de braise — le joueur qui a
	# compris l acte III sait quoi emporter.
	_resist(demon_slime, {&"phys": 0.8, &"feu": 0.0, &"givre": 1.35, &"arcane": 1.1, &"poison": 0.6, &"foudre": 1.1})
	_save(demon_slime, E + "demon_slime.tres")

	# LE BOURREAU. Demande du testeur : « peut etre un bosse qui n avance pas qui
	# tape le sol pour faire une onde de choque qui fait des degats ».
	#
	# CE QUE LA MECANIQUE CHANGE. Le Seigneur Spectre campe deja, mais il TIRE :
	# le joueur sort de sa ligne et il est tranquille. Une onde BALAIE un cercle,
	# donc il n y a plus de ligne a quitter, il y a une DISTANCE a tenir — et son
	# decor (murs, arbres provocateurs, semis) doit la tenir aussi. C est la
	# premiere zone interdite FIXE du jeu.
	#
	# VITESSE NULLE, mot pour mot la demande. C est ce qui rend l onde jouable :
	# une zone interdite qui se deplacerait en frappant ne laisserait aucun
	# endroit sur, il suffirait d attendre et il n y aurait plus de decision.
	# Consequence a assumer : il ne peut pas atteindre le mage tout seul, donc son
	# escorte EST la moitie du combat.
	var executioner := _enemy("executioner", "Le Bourreau", K.MINIBOSS, 6,
		145.0, 0.0, 14, S.HEXAGON, Color(0.45, 0.30, 0.35), 60.0)
	executioner.anim_key = &"executioner"
	# 3,2 s entre deux coups : le temps de traverser son cercle, de lancer un sort
	# et de ressortir. A 2 s le joueur n avait plus le temps d incanter dedans,
	# donc plus de choix a prendre ; a 5 s l onde devenait un decor.
	executioner.shockwave_interval = 3.2
	# 340 px, soit moins d un tiers de la largeur du terrain (1080) : large assez
	# pour interdire un couloir, serre assez pour qu il reste de la place a cote.
	executioner.shockwave_radius = 340.0
	# 6 degats : entre la fleche du lutin (2) et le contact d un P4. Elle doit
	# USER le joueur qui reste dedans, jamais le tuer d un coup — sinon la seule
	# strategie serait de ne jamais entrer, et il n y aurait plus rien a decider.
	executioner.shockwave_damage = 6
	# Il porte aussi une feuille `summon` : il appelle ses condamnes. Deux raisons
	# de jeu — un boss qui n avance pas ne peut pas menacer le mage seul, et le
	# joueur doit avoir une raison de venir a lui plutot que d ignorer un pilier.
	executioner.summon_def = load(E + "risen_ghoul.tres")
	executioner.summon_interval = 6.0
	executioner.summon_count = 1
	executioner.summon_max_alive = 3
	# Bourreau de metier : cuir et acier, insensible au venin comme au
	# ralentissement (on ne retient pas une masse qui ne bouge deja pas). L arcane
	# et la foudre passent son tablier. C est un boss qu on tue a la magie, pas a
	# l usure.
	_resist(executioner, {&"phys": 0.7, &"feu": 0.9, &"givre": 0.95, &"arcane": 1.3, &"poison": 0.0, &"foudre": 1.25, &"lent": 0.0})
	_save(executioner, E + "executioner.tres")

	# LE CHAMPIGNON ET LA PLANTE. Le testeur a telecharge EXPRES `Free Tank_
	# Mushroom_Idle` et le pack de champignons : deux silhouettes demandees sans
	# mecanique attachee. Elles entrent donc comme ce qu elles sont — de la
	# BIOMASSE du monde d origine, la famille qui manquait a l acte IV.
	#
	# Elles ne portent pas de comportement neuf, et c est assume : un monde a
	# besoin de figurants qui se lisent au premier regard, sinon chaque vague est
	# une somme de cas particuliers et le joueur ne peut plus lire la menace. Ce
	# qu elles apportent est dans leur TABLE : ce sont les deux seuls monstres du
	# jeu franchement vulnerables au FEU sans etre ni gelee ni mort-vivant, donc
	# les premieres cibles ou le deck de feu du monde d origine sert a quelque chose.

	# Tank de bas etage : lent, trapu, il encaisse. Le mot du pack est « Tank » et
	# le monstre doit le tenir — 34 PV pour un P2, contre 10 a la Sauterelle.
	var mushroom := _enemy("mushroom", "Champignon cuirasse", K.TANK, 2, 34.0, 34.0, 3,
		S.CIRCLE, Color(0.80, 0.55, 0.45), 26.0)
	mushroom.anim_key = &"mushroom"
	# VAGUE 10 B2 — « CUIRASSE » : son nom le disait, rien ne le faisait. Son
	# chapeau encaisse le premier coup ; la zone ou le poison le percent aussi.
	mushroom.first_hit_shield = true
	# Chapeau spongieux : les coups s y enfoncent, le feu le racornit d un coup.
	# Il baigne dans ses propres spores, donc le venin ne lui fait rien.
	_resist(mushroom, {&"phys": 0.75, &"feu": 1.35, &"givre": 1.05, &"arcane": 1.0, &"poison": 0.6})
	_save(mushroom, E + "mushroom.tres")

	# La plante carnivore : l inverse du champignon. Elle ne tient rien, elle
	# MORD — 12 PV pour 88 px/s. VAGUE 10 B2 — « CRACHE-GRAINE » : la pose
	# `attack` de sa feuille est un CRACHAT (revue A4), elle tire donc une graine
	# toutes les 3,5 s (2 degats). Le Mur de pierre arrete ses graines.
	var carnivore := _enemy("carnivore_plant", "Plante carnivore", K.FAST, 2, 12.0, 88.0, 3,
		S.TRIANGLE, Color(0.35, 0.70, 0.35), 22.0)
	carnivore.anim_key = &"smallmonster"
	carnivore.shoot_interval = 3.5
	carnivore.shot_damage = 2
	# La feuille smallmonster n occupe que 35 % de sa case : sans correction elle
	# entrerait a la taille d un gnome alors qu elle doit se lire comme une gueule.
	carnivore.sprite_scale = 1.2
	# Tige et sap : le feu la consume, le givre la casse net. Rien a empoisonner
	# dans une plante, et le physique glisse sur des fibres souples.
	_resist(carnivore, {&"phys": 0.85, &"feu": 1.35, &"givre": 1.25, &"arcane": 0.9, &"poison": 0.5})
	_save(carnivore, E + "carnivore_plant.tres")

	# =================================================================
	# CHANTIER N2 — LES NEUF SILHOUETTES ORPHELINES
	#
	# `AnimCatalog.UNITS` portait neuf feuilles extraites que AUCUN monstre
	# n utilisait : `flyingeye`, `goblin2`, `skeleton2`, `evilwizard`,
	# `fireworm`, `ghoul`, `bluewitch`, `nightborne`, `mageguardian`. Du travail
	# d extraction qui ne servait a rien — exactement ce que
	# `test_bosses._test_les_silhouettes_du_26_septembre_portent_des_monstres`
	# refuse de laisser pourrir.
	#
	# Les actes 2 et 3 de docs/histoire.md leur donnent un lieu : les Sky Lands
	# demandent du VOLANT et des pillards humanoides, le cimetiere de Tombol
	# demande des morts-vivants et des gardiens. Chaque monstre ci-dessous est
	# une COMBINAISON de champs d `EnemyDef` deja existants — aucun script neuf,
	# aucune mecanique inventee : c est la regle du projet et c est aussi ce qui
	# garantit que le bestiaire sait deja les decrire.
	# =================================================================

	# --- ACTE 2, LES SKY LANDS ---------------------------------------

	# L OEIL DES COURANTS. Le doc (section 4) veut `lvl_05` « tout en vol,
	# plates-formes etroites ». Il manquait un volant qui ne soit ni esquiveur
	# (Planogo) ni phaseur (Ombre) : celui-ci se laisse PORTER par le courant
	# — il ondule largement et il vole, donc ni le mur ni le tir tendu ne le
	# tiennent. La reponse est la zone posee devant, la seule qui ne demande
	# pas de prevoir ou il sera.
	#
	# 14 PV pour un P2 : il est fragile parce qu il est difficile a toucher.
	# Un volant ondulant blinde serait une taxe de temps, pas une cible.
	var flying_eye := _enemy("current_eye", "Oeil des courants", K.EVASIVE, 2,
		14.0, 72.0, 3, S.CIRCLE, Color(0.70, 0.85, 0.95), 24.0)
	flying_eye.anim_key = &"flyingeye"
	flying_eye.flying = true
	# EN SPIRALE (chantier W9). Il ondulait (210 px) comme un Serpent des sables
	# qui vole ; MovePattern.SPIRAL etait code et teste sans qu aucun monstre ne
	# s en serve. L oeil des COURANTS est pris dans les tourbillons du niveau des
	# courants d air : il descend en tournant sur un cercle de 280 px, plus vite
	# sur son cercle qu a la descente (100 contre 72), donc il fait des boucles et
	# remonte un instant a chaque tour. Le propos ne change pas — il ne se vise
	# pas, la reponse reste la zone posee devant — mais il se lit autrement : il
	# tourne AUTOUR de sa colonne, et le centre du cercle est la ou poser la zone
	# (c est ce que dit sa ligne de bestiaire). Volant : ni mur ni chemin A* ne
	# coupent son motif. L ondulation est retiree : les deux cumules faisaient un
	# trace que personne ne lit.
	flying_eye.move_pattern = EnemyDef.MovePattern.SPIRAL
	flying_eye.pattern_width = 280.0
	flying_eye.pattern_lateral_speed = 100.0
	# Une pupille nue, sans chair ni carapace : le physique la creve, le froid
	# la trouble. Rien a empoisonner dans un oeil, et l air des courants la
	# rend indifferente a la foudre qui y tombe sans arret.
	_resist(flying_eye, {&"phys": 1.30, &"feu": 1.05, &"givre": 1.15, &"arcane": 0.90,
		&"poison": 0.35, &"foudre": 0.75})
	_save(flying_eye, E + "current_eye.tres")

	# LE GRAND OEIL — l Oeil des courants en grand (ecrit comme mini-boss de
	# `lvl_17`, il en devient le BOSS a la vague 10 : voir plus bas).
	#
	# ET C EST MIEUX AINSI, pour une raison de lecture : la lignee des gorgones a
	# montre que les paliers enseignent mieux qu un monstre isole. Le joueur a vu
	# trois vagues d Oeils lui filer entre les sorts ; la tete de vague est le meme
	# oeil en gros, qui fait exactement la meme chose en pire. Il sait deja quoi
	# faire, il doit juste le faire mieux.
	#
	# CE QU IL AJOUTE au petit : il TIRE. Un volant ondulant qu on ne peut pas
	# ignorer, c est la seule facon de forcer le joueur a couvrir le ciel au lieu
	# d attendre que ca descende.
	# VAGUE 10 B2 — LE GRAND OEIL DEVIENT LE BOSS DE `lvl_17` (le niveau n en avait
	# aucun, et la scene de fin le fait tomber sur la nacelle). 155 PV au lieu de
	# 105, la meme spirale, le meme tir ; la Mere Planogo prend le palier.
	var great_eye := _enemy("great_eye", "Grand Oeil des courants", K.BOSS, 10,
		155.0, 54.0, 30, S.CIRCLE, Color(0.55, 0.75, 0.95), 52.0)
	great_eye.anim_key = &"flyingeye"
	# 1,5 fois la case du petit : le joueur doit lire « le meme, en grand » d un
	# coup d oeil, sans avoir a comparer deux barres de vie.
	great_eye.sprite_scale = 1.5
	great_eye.flying = true
	# Il tourne comme le petit (chantier W9 : la lignee fait la MEME chose en
	# pire), mais sur un cercle plus serre (200 contre 280) et sans boucle : sa
	# vitesse sur le cercle est celle de sa descente (une roue qui roule, il ne
	# remonte jamais). Un mini-boss doit rester visable, sinon le combat se
	# gagne par chance. Ce qui le rend dur est sa portee, pas son imprevisibilite.
	great_eye.move_pattern = EnemyDef.MovePattern.SPIRAL
	great_eye.pattern_width = 200.0
	great_eye.shoot_interval = 3.2
	# 4 degats : au-dessus de la fleche du lutin (2), sous le trait du mage noir
	# (5) qui, lui, ne bouge pas. Un tireur mobile doit taper moins fort qu un
	# tireur qui campe.
	great_eye.shot_damage = 4
	# 105 PV, le deuxieme plus bas des mini-boss du jeu : il vole ET il ondule ET
	# il tire, donc le temps qu il coute au joueur est deja son armure.
	#
	# Meme table que le petit, en plus dur sur un seul point : le physique le
	# trouve un peu moins (1,15 contre 1,30). La reponse apprise sur les vagues
	# marche encore sur la tete, elle coute juste plus de sorts — c est ce qui
	# fait qu un palier est un palier et non un autre monstre.
	_resist(great_eye, {&"phys": 1.15, &"feu": 1.05, &"givre": 1.10, &"arcane": 0.90,
		&"poison": 0.35, &"foudre": 0.70})
	_save(great_eye, E + "great_eye.tres")

	# LE PILLARD DE HAUTE-NACELLE. Le doc veut « un port pille, quais de bois ».
	# Un pillard n arrive pas par le haut en rang : il SURGIT des quais, sur le
	# cote. `entry_side` existait et un seul monstre s en servait.
	#
	# Il est rapide et cartonne (18 PV pour 92 px/s) : le cout de son entree
	# laterale est qu il traverse moins de terrain avant d atteindre le mage,
	# donc il doit tomber au premier sort qui le trouve.
	var raider := _enemy("nacelle_raider", "Pillard de Haute-Nacelle", K.FAST, 2,
		18.0, 92.0, 3, S.TRIANGLE, Color(0.65, 0.75, 0.40), 26.0)
	raider.anim_key = &"goblin2"
	raider.entry_side = true
	# La feuille goblin2 n occupe que 41 % de sa case : sans correction le
	# pillard entre a la taille d un lutin alors qu il doit se lire comme un
	# homme arme.
	raider.sprite_scale = 1.15
	# Gobelin de quai : cuir graisseux et couteau. Le feu prend sur la graisse,
	# le givre le raidit ; il vit dans la vermine, donc le venin l effleure.
	_resist(raider, {&"phys": 0.85, &"feu": 1.25, &"givre": 1.20, &"arcane": 1.0,
		&"poison": 0.55})
	_save(raider, E + "nacelle_raider.tres")

	# LE MAGE NOIR DE HAUTE-NACELLE — MINI-BOSS de `lvl_18`.
	#
	# POURQUOI LUI ET PAS UN GROS TAS DE PV. docs/histoire.md fait de la plaque
	# de metal noir trouvee dans la poitrine du Gardien « du travail d en haut,
	# Sky Lands » : quelqu un, la-haut, SOUDE des monstres. Le premier visage
	# qu on met sur cette phrase doit etre un mage ennemi, pas un mur.
	#
	# Il TIRE ET IL RECULE : `keeps_distance_at` etait ecrit pour le Seigneur
	# Spectre et le doc de l acte 2 parle de « plates-formes etroites ». Un
	# mini-boss qui campe hors de portee oblige a percer jusqu a lui pendant que
	# son escorte descend — c est la meme question que le Bourreau pose a
	# l envers : lui, il faut le rattraper.
	# VAGUE 10 B2 — LE MAGE NOIR DEVIENT LE BOSS DE `lvl_18` (le port n en avait
	# aucun ; la scene de fin le fait s effondrer). 150 PV au lieu de 110, ses
	# tirs, sa distance et ses pillards ; le Capitaine pillard prend le palier.
	var dark_mage := _enemy("dark_mage", "Mage noir de Haute-Nacelle", K.BOSS, 10,
		150.0, 42.0, 30, S.STAR, Color(0.45, 0.35, 0.75), 54.0)
	dark_mage.anim_key = &"evilwizard"
	# 110 PV, sous la Matrone gorgone (120) : il est le plus fragile des
	# mini-boss du jeu, et c est le prix de sa distance. Un campeur blinde
	# serait une attente, pas un combat.
	dark_mage.keeps_distance_at = 380.0
	dark_mage.shoot_interval = 2.6
	# 4 degats par trait (5 avant la vague 10 : devenu boss, il tirait trop fort pour le port) : plus cher que la fleche du lutin (2), moins qu un
	# contact de P4. Il doit USER le joueur qui tarde a venir le chercher.
	dark_mage.shot_damage = 4
	# Il invoque ses soudures : les pillards qu il a retournes. C est la preuve
	# jouable de ce que l acte raconte — il FABRIQUE les monstres qu on combat.
	dark_mage.summon_def = load(E + "nacelle_raider.tres")
	dark_mage.summon_interval = 8.0
	dark_mage.summon_count = 1
	dark_mage.summon_max_alive = 3
	# Un mage : sa robe ne pare rien, sa magie pare la magie. L arcane et la
	# foudre glissent, l acier et le gel passent. Le deck de zones de l acte 2
	# n est PAS la reponse a lui — c est tout l interet de le mettre en tete.
	_resist(dark_mage, {&"phys": 1.25, &"feu": 1.0, &"givre": 1.20, &"arcane": 0.65,
		&"poison": 0.85, &"foudre": 0.70})
	_save(dark_mage, E + "dark_mage.tres")

	# --- ACTE 3, LE CIMETIERE DE TOMBOL ------------------------------

	# LA GOULE DES FOSSES. Le doc veut `lvl_09` « tombes ouvertes, on avance
	# dans l eau », avec `ghoul_priest` et `shade`. Il manquait la CHAIR : les
	# goules que le Pretre soigne. La Goule levee existe mais elle est le sbire
	# d un boss, puissance 1, faite pour etre gobee — un acte entier bati sur
	# elle n aurait aucune consistance.
	#
	# Celle-ci arrive en groupe de 3 (`swarm_count`) : les fosses basses se
	# vident par fournees, pas une tombe a la fois.
	var pit_ghoul := _enemy("pit_ghoul", "Goule des fosses", K.SWARM, 2,
		15.0, 58.0, 3, S.DIAMOND, Color(0.50, 0.58, 0.42), 24.0)
	pit_ghoul.anim_key = &"ghoul"
	pit_ghoul.swarm_count = 3
	# Chair morte et gorgee d eau : le feu a du mal a la prendre (0.95 et non
	# le 1.10 de la Goule levee, qui est seche), le givre la casse net puisqu
	# elle est pleine d eau. Immunisee au venin comme tout mort-vivant.
	_resist(pit_ghoul, {&"phys": 0.90, &"feu": 0.95, &"givre": 1.30, &"arcane": 1.05,
		&"poison": 0.0, &"foudre": 1.20})
	_save(pit_ghoul, E + "pit_ghoul.tres")

	# LE SQUELETTE PAREUR. Sa feuille porte une bande `shield` que personne
	# n utilisait — une PARADE dessinee, jamais jouee. `first_hit_shield` est
	# exactement cette animation en regle de jeu : le premier coup ne passe pas.
	#
	# CE QU IL PUNIT, et c est la raison de le mettre dans un acte de zones : le
	# joueur de l acte 2 a appris a poser une nappe qui fait beaucoup de petits
	# coups. Contre un pareur, le premier tic de la nappe est GRATUIT et il
	# continue d avancer. La reponse est un gros coup d abord, la nappe ensuite —
	# l inverse de l ordre acquis.
	var parry_skeleton := _enemy("parry_skeleton", "Squelette pareur", K.SHIELDED, 3,
		38.0, 50.0, 5, S.SQUARE, Color(0.85, 0.83, 0.72), 28.0)
	parry_skeleton.anim_key = &"skeleton2"
	parry_skeleton.first_hit_shield = true
	# Os secs : le feu les calcine, le choc les brise. Rien a empoisonner, et
	# l arcane qui tient les os ensemble les disperse.
	_resist(parry_skeleton, {&"phys": 1.15, &"feu": 1.25, &"givre": 0.75, &"arcane": 1.20,
		&"poison": 0.0})
	_save(parry_skeleton, E + "parry_skeleton.tres")

	# LE VER DE FEU. Le doc veut `lvl_12` « descente, lumiere rouge par en bas ».
	# Cette lumiere rouge doit avoir un corps : un ver qui remonte du puits et
	# qui TIRE, parce qu un puits se defend d en bas sans monter.
	#
	# Il ondule ET il tire : les deux champs existaient separement (Serpent,
	# Archer) et jamais ensemble. La combinaison est ce qui le rend penible au
	# bon endroit — on ne peut ni l ignorer (il tire) ni le viser vite
	# (il ondule).
	var fire_worm := _enemy("fire_worm", "Ver de feu", K.SHOOTER, 3,
		30.0, 46.0, 5, S.CAPSULE, Color(0.95, 0.50, 0.20), 28.0)
	fire_worm.anim_key = &"fireworm"
	fire_worm.wave_amplitude = 120.0
	fire_worm.wave_frequency = 0.60
	fire_worm.shoot_interval = 3.8
	fire_worm.shot_damage = 3
	# Il EST le feu : le bruler n a aucun sens, le geler l eteint. Le poison ne
	# mord pas sur de la braise. C est le monstre qui ferme la porte au deck de
	# feu juste avant le pentacle, ou le joueur croit avoir trouve sa reponse.
	_resist(fire_worm, {&"phys": 0.90, &"feu": 0.0, &"givre": 1.35, &"arcane": 1.10,
		&"poison": 0.0, &"foudre": 1.15})
	_save(fire_worm, E + "fire_worm.tres")

	# LA SORCIERE DES FOSSES — MINI-BOSS de `lvl_19`.
	#
	# POURQUOI UNE SOIGNEUSE EN TETE DE VAGUE. Le Pretre goule soigne deja, mais
	# il mene le mini-boss de `lvl_03` et un mini-boss ne se repete pas
	# (`test_bosses`). Surtout, le Pretre soigne en MARCHANT vers le mage : on
	# finit par le rencontrer. La Sorciere, elle, LEVE les mortes en plus de les
	# soigner — elle transforme une vague qu on nettoie en une vague qui se
	# remplit, et la seule sortie est de la trouver dans sa propre foule.
	var pit_witch := _enemy("pit_witch", "Sorciere des fosses", K.MINIBOSS, 6,
		125.0, 40.0, 12, S.DIAMOND, Color(0.35, 0.55, 0.85), 54.0)
	# La silhouette Duelyst "unhallowed" (cape noire, cheveux blancs, feu vert) et
	# non plus bluewitch : la sorciere bleue est devenue la premiere APPRENTIE du
	# mage, et l AUDIT refuse qu un apprenti partage sa feuille avec un monstre.
	# L Ensevelisseur de lvl_04 porte la meme, mais quinze niveaux plus tot ; aucun
	# voisin de lvl_19 a lvl_21 ne lui ressemble.
	pit_witch.anim_key = &"unhallowed"
	# Agrandie : sans cela elle serait plus petite que les goules qu elle commande.
	pit_witch.sprite_scale = 1.35
	# 2,5 PV/s, sous le Pretre goule : deux soins qui se cumulent dans la meme
	# vague rendraient les degats etales totalement inutiles, ce qui n est plus
	# une lecon mais une interdiction.
	pit_witch.heal_per_second = 2.5
	pit_witch.summon_def = load(E + "pit_ghoul.tres")
	pit_witch.summon_interval = 8.0
	pit_witch.summon_count = 1
	# Trois au plus, et chacune arrive en groupe de 3 : neuf corps de renfort a
	# l ecran au maximum, ce qui est deja le double de ce que l Ensevelisseur
	# tolere. Le plafond est bas exprès.
	pit_witch.summon_max_alive = 3
	# Sorciere d eau morte : elle a l habitude du froid des fosses, le feu la
	# trouve. La foudre passe par l eau ou elle marche — c est sa faille propre,
	# et elle est differente de celle de tous les morts-vivants de l acte.
	_resist(pit_witch, {&"phys": 1.10, &"feu": 1.25, &"givre": 0.60, &"arcane": 1.05,
		&"poison": 0.70, &"foudre": 1.30})
	_save(pit_witch, E + "pit_witch.tres")

	# L EPEISTE D OMBRE — MINI-BOSS de `lvl_20`, la cour des rois morts.
	#
	# Le doc dit « statues, arrieres-gardes laissees par le roi ». Une
	# arriere-garde n est pas un tank : c est quelqu un que le roi a laisse pour
	# GAGNER DU TEMPS, et qui sait qu il va mourir. D ou le seul mini-boss
	# rapide du cimetiere — il fonce par a-coups et il pare le premier coup.
	#
	# La combinaison `burst_move` + `first_hit_shield` n existait sur aucun
	# monstre : elle rend le tir reflexe doublement faux, puisque le sort lance
	# sur sa position d avant la pause est en plus absorbe.
	# VAGUE 10 B2 — L EPEISTE DEVIENT LE BOSS DE `lvl_20` (la cour des rois morts
	# n en avait aucun ; « la derniere arriere-garde tombe »). 185 PV, ses
	# a-coups, sa parade, et UNE VIE de plus : abattu, il revient par le haut a
	# 60 %, plus vite. Il retarde un poursuivant, il ne se laisse pas tuer une fois.
	# Le Totem ancien prend le palier.
	var nightborne := _enemy("shadow_bladesman", "Epeiste d ombre", K.BOSS, 10,
		185.0, 66.0, 30, S.TRIANGLE, Color(0.30, 0.25, 0.45), 52.0)
	nightborne.anim_key = &"nightborne"
	nightborne.extra_lives = 1
	nightborne.extra_life_hp_pct = 60.0
	nightborne.burst_move = true
	# Fonce une seconde, souffle un demi : un rythme plus long que celui de la
	# Sauterelle (0,5 / 0,8), parce qu un mini-boss doit etre LISIBLE — le
	# joueur doit pouvoir apprendre sa mesure et frapper dans la pause.
	nightborne.burst_dash_time = 1.0
	nightborne.burst_pause_time = 0.5
	nightborne.first_hit_shield = true
	# Chair d ombre sur une lame reelle : l acier le trouve, l arcane defait ce
	# qui le tient. Le froid, lui, ne mord pas sur ce qui n a pas de sang.
	_resist(nightborne, {&"phys": 1.15, &"feu": 0.95, &"givre": 0.70, &"arcane": 1.25,
		&"poison": 0.0, &"foudre": 1.05})
	_save(nightborne, E + "shadow_bladesman.tres")

	# LE SCEAU DE TOMBOL — BOSS de `lvl_21`, et il FERME L ACTE 3.
	#
	# POURQUOI LE PORTAIL EST LE BOSS. docs/histoire.md, `lvl_13` : « salle du
	# portail, le roi accule », « mixte + le portail ». Le Roi squelette ne se
	# bat pas — il a fui quatre niveaux et il finit par demander une place dans
	# le groupe. L adversaire de la salle est donc le PENTACLE lui-meme, et un
	# portail qui marcherait vers le mage serait un contresens.
	#
	# `mageguardian` est la seule feuille du catalogue SANS animation de marche :
	# un totem flottant, idle / attaque / mort. Elle a attendu six mois le seul
	# monstre qui n avance pas et qui n est pas le Bourreau.
	#
	# TROIS CHAMPS, TROIS PROBLEMES, et aucun n est de l usure :
	#   - il n avance jamais, donc c est au joueur d aller a lui ;
	#   - il rend INVULNERABLES les monstres autour de lui, donc il faut y aller
	#     PAR le mur qu il protege ;
	#   - il fait monter des demons du puits tant qu il vit.
	# La seule sortie est de le percer au travers de sa propre aura : c est la
	# question que le totem posait en petit a `lvl_08`, posee ici en grand.
	var tombol_seal := _enemy("tombol_seal", "Sceau de Tombol", K.BOSS, 10,
		205.0, 0.0, 30, S.HEXAGON, Color(0.85, 0.25, 0.45), 78.0)
	tombol_seal.anim_key = &"mageguardian"
	# La feuille occupe 97 % de sa case, la plus pleine du catalogue : sans
	# reduction il deborderait du terrain. 58 px de case seulement, donc on
	# agrandit tout de meme — mais moins qu un boss de Duelyst.
	tombol_seal.sprite_scale = 1.6
	# 205 PV, sous l Ensevelisseur (220) : il ne peut pas approcher le mage tout
	# seul, donc ses PV ne sont pas la menace. Son aura et son flux le sont.
	#
	# 300 px d aura, sous le Totem ancien : assez pour couvrir le couloir par
	# lequel ses invoques descendent, pas assez pour tenir tout le terrain. Il
	# reste toujours un cote par lequel entrer, et le trouver EST le combat.
	tombol_seal.aura_shield_radius = 300.0
	tombol_seal.summon_def = load(E + "parry_skeleton.tres")
	tombol_seal.summon_interval = 6.5
	tombol_seal.summon_count = 1
	# Quatre au plus, et chacun pare le premier coup : sous son aura ils sont
	# intouchables, hors de l aura ils coutent deux sorts. Le plafond est bas
	# pour cette raison — cinq suffiraient a fermer le terrain.
	tombol_seal.summon_max_alive = 4
	# Une pierre gravee, pas une creature : le physique s y emousse, le venin et
	# le ralentissement n ont rien a mordre. L arcane defait la gravure, la
	# foudre saute sur le metal du sceau. C est un boss qu on casse a la magie
	# pure — et l acte 3 fournit justement le deck pour ca.
	_resist(tombol_seal, {&"phys": 0.65, &"feu": 0.90, &"givre": 0.95, &"arcane": 1.30,
		&"poison": 0.0, &"foudre": 1.25, &"lent": 0.0})
	_save(tombol_seal, E + "tombol_seal.tres")

	# =================================================================
	# CHANTIER N3 — LES QUATRE GRANDS DEMONS ET LA DIVINITE
	#
	# `docs/histoire.md` sections 6 et 7. Sept niveaux a ecrire, et le catalogue
	# ne laissait plus qu UN boss libre (`gorgon_queen`) et DEUX mini-boss
	# (`executioner`, `skyreaver`) : `test_bosses` exige un adversaire propre par
	# niveau, donc il manquait quatre tetes d affiche.
	#
	# POURQUOI CES QUATRE PARTAGENT LA SILHOUETTE D UNE FAMILLE EXISTANTE, et
	# n ouvrent pas de nouvelle feuille. Deux raisons, et la premiere est
	# narrative.
	#
	#   1. LE DOCUMENT L EXIGE (section 10) : « Aucun nouveau type de monstre.
	#      Les 21 existants portent les 5 actes : la narration re-contextualise. »
	#      L acte 4 est justement l acte ou cette regle DIT quelque chose — le
	#      mage descend chercher un chef et trouve « quatre directeurs qui se
	#      detestent », chacun regnant sur une famille que le joueur combat
	#      depuis le premier acte. Vharn est l Enclume DES GOLEMS, Sesh la Faim
	#      DES GLOUTONS. Le seigneur porte la silhouette de ses sujets : c est ce
	#      qui fait comprendre, sans un mot, qui commandait ces monstres.
	#
	#   2. C EST LE PATRON DEJA EN PLACE. Le jeu compte trois lignees qui
	#      partagent une feuille (`gorgon` x3 du Regard a la Reine, `slimer` x3
	#      de la Gelee a ses enfants) et elles se lisent parfaitement : le rang se
	#      dit par la TAILLE et la COULEUR, pas par un dessin different. Les neuf
	#      silhouettes orphelines du catalogue sont par ailleurs prises par le
	#      chantier voisin (actes 2 et 3), qui en fait la vermine des Sky Lands et
	#      de Tombol.
	#
	# CHACUN CHANGE UNE QUESTION, et aucun ne repete un boss existant :
	#
	#   Vharn  — la monnaie des degats : il compte les COUPS  (hits_immune)
	#   Sesh   — la taille de la cible : il GROSSIT en mangeant (devours)
	#   Kaltek — l horloge du combat : il ACCELERE a chaque coup (enrage+invoc.)
	#   Ymoa   — qui l on peut toucher : il rend ses voisins intouchables (aura)
	#   L Enfant — les trois lecons de la campagne d un coup
	#
	# Les quatre demons ne se coordonnent pas (document, section 6) : leurs tables
	# de resistance sont donc VOLONTAIREMENT contradictoires. Aucun deck ne repond
	# aux quatre, et c est ce qui fait de l ordre libre de l acte 4 un vrai choix —
	# le joueur commence par celui que son deck sait battre.
	# =================================================================

	# VHARN, L ENCLUME — `lvl_07`, la forge. « tout est blinde » (document).
	#
	# Il compte les COUPS, pas les points : les six premiers ne lui font RIEN.
	# C est l inverse exact du reflexe que tout le reste du jeu encourage — le
	# spam de petites cartes devient le pire choix possible devant lui, et le gros
	# sort charge le meilleur.
	#
	# Silhouette du GOLEM (`golem_blue`), la famille blindee de l acte 4, en plus
	# grand et en teinte de fonte chauffee : le joueur reconnait ses sujets.
	var demon_anvil := _enemy("demon_anvil", "Vharn, l Enclume", K.BOSS, 10,
		195.0, 26.0, 30, S.SQUARE, Color(0.78, 0.52, 0.34), 80.0)
	demon_anvil.anim_key = &"golem_blue"
	# Le Golem commun entre a 1.0 : son seigneur doit se lire comme une masse a
	# cote de lui, sans quoi la vague de forge devient illisible.
	demon_anvil.sprite_scale = 1.45
	# SIX coups, pas douze : le plafond du champ est 12, mais le deck de son
	# niveau compte 15 cartes pour environ sept lancers avant qu il atteigne la
	# ligne. Douze coups voudraient dire qu on ne l entame jamais. Six laisse au
	# joueur le temps de comprendre la regle ET d y repondre dans le meme combat.
	demon_anvil.hits_immune = 6
	# Lent (26 px/s) : la mecanique demande du TEMPS pour etre lue. Un boss qui
	# compte les coups en arrivant vite serait juste un boss qu on ne touche pas.
	#
	# Blindage integral : l acier glisse, le givre fait eclater la fonte chaude.
	# Le venin ne mord pas sur du metal. C est la table la plus fermee du jeu, et
	# c est le propos du personnage — mais elle laisse DEUX portes ouvertes
	# (givre, arcane), sinon le niveau serait une impasse de deck et non une
	# question posee au joueur.
	#
	# IMMUNISE AU VENT (chantier W9, voir ANCRES_AU_SOL) : une enclume ne
	# s envole pas. La Spirale de sel et la Rupture de chaine de son niveau ne
	# l aspirent ni ne la repoussent, et ne l entament pas.
	_resist(demon_anvil, {&"phys": 0.55, &"vent": 0.0, &"feu": 0.6, &"givre": 1.35,
		&"arcane": 1.25, &"poison": 0, &"foudre": 1.1, &"lent": 0.5})
	_save(demon_anvil, E + "demon_anvil.tres")

	# SESH, LA FAIM — `lvl_10`, les fosses. « tout se mange » (document).
	#
	# Le seul BOSS devoreur du jeu. Le Glouton (P4) gobe deja, mais il est une
	# menace de vague ; ici la mecanique est la tete d affiche et elle change la
	# donnee la plus stable d un combat : la TAILLE de la cible. Le joueur qui
	# laisse vivre la vermine de Sesh se retrouve devant un boss qui a grossi sur
	# son dos — il a fabrique le probleme lui-meme, et c est la lecon du niveau.
	#
	# Silhouette du GLOUTON (`dino`), dont il est le seigneur, en plus gros.
	var demon_maw := _enemy("demon_maw", "Sesh, la Faim", K.BOSS, 10,
		205.0, 40.0, 30, S.CAPSULE, Color(0.88, 0.42, 0.18), 76.0)
	demon_maw.anim_key = &"dino"
	demon_maw.sprite_scale = 1.4
	demon_maw.devours = true
	# Gueule et panse : la flamme la nourrit, le givre la fige. Une masse molle
	# sans squelette laisse passer l acier, et ce qui avale tout digere le venin.
	_resist(demon_maw, {&"phys": 0.75, &"feu": 0.5, &"givre": 1.4, &"arcane": 1.1,
		&"poison": 0.6, &"foudre": 1.15})
	_save(demon_maw, E + "demon_maw.tres")

	# KALTEK, LA CHAINE — `lvl_11`, l arene. « rage et esclaves » (document).
	#
	# Il ACCELERE a chaque coup recu, ET il invoque ses esclaves. Les deux
	# mecaniques se mordent la queue, et c est tout le combat : couper le flux
	# demande de le frapper, le frapper le rend plus rapide. Le Berserker (P3)
	# porte deja l enrage, mais sans invocation il n a jamais pose ce dilemme.
	#
	# Silhouette du BERSERKER (`warrior_red`) : ses esclaves sont litteralement
	# ses semblables, et il descend au milieu d eux.
	var demon_chain := _enemy("demon_chain", "Kaltek, la Chaine", K.BOSS, 10,
		175.0, 44.0, 30, S.TRIANGLE, Color(0.62, 0.20, 0.45), 72.0)
	demon_chain.anim_key = &"warrior_red"
	demon_chain.sprite_scale = 1.45
	# +9 % par coup, plafonne a 1,7x. Au-dela du plafond il traverse le terrain
	# plus vite que le temps d incantation le plus court du jeu, et le combat
	# cesse d etre lisible — ce n est plus une montee de tension, c est une
	# course perdue d avance.
	demon_chain.enrage_speed_pct = 9.0
	demon_chain.enrage_cap = 1.7
	# Ses esclaves sont des BERSERKERS existants, pas un sbire dedie : le joueur
	# connait la silhouette et lit tout de suite ce qui vient de tomber. Ils
	# n heritent PAS de sa rage, donc couper la source a une vraie recompense.
	demon_chain.summon_def = load(E + "berserker.tres")
	demon_chain.summon_interval = 7.5
	demon_chain.summon_count = 1
	# Plafond serre : trois enrages simultanes suffisent a etouffer le mage, et
	# au-dela on perd par accumulation mecanique et non par erreur de jeu.
	demon_chain.summon_max_alive = 3
	# PV les plus bas des quatre (175) : il est le seul qui devienne plus dangereux
	# pendant qu on le tue. Chair a vif, aucune armure — tout le touche, et c est
	# precisement le piege : le deck qui le hache vite est aussi celui qui
	# l affole. Le RALENTIR est la vraie reponse, donc le givre porte pleinement
	# et le champ `lent` reste a 1.0 : c est le seul boss du jeu qu on peut
	# reellement freiner, et il faut que le joueur le decouvre.
	_resist(demon_chain, {&"phys": 1.15, &"feu": 1.05, &"givre": 1.3, &"arcane": 1.0,
		&"poison": 1.1, &"foudre": 0.85, &"lent": 1.0})
	_save(demon_chain, E + "demon_chain.tres")

	# YMOA, LE CERCLE — `lvl_12`, le temple. « auras et protections » (document).
	#
	# Il ne se bat pas : il PROTEGE. Tant qu il vit, tout ce qui l entoure est
	# invulnerable, et il campe au loin pour que son cercle couvre la vague plutot
	# que lui-meme. La question qu il pose est la plus simple a enoncer et la plus
	# dure a executer du jeu : aller chercher le protecteur au fond du terrain
	# pendant que le reste descend. L Ancien du totem (P6) porte deja l aura, mais
	# il marche au contact ; couplee a `keeps_distance_at`, elle devient une zone
	# interdite qu il faut traverser.
	#
	# Silhouette du TOTEM (`totem_tower`), la famille des porteurs d aura.
	var demon_circle := _enemy("demon_circle", "Ymoa, le Cercle", K.BOSS, 10,
		160.0, 22.0, 30, S.HEXAGON, Color(0.45, 0.75, 0.85), 78.0)
	demon_circle.anim_key = &"totem_tower"
	demon_circle.sprite_scale = 1.4
	demon_circle.aura_shield_radius = 210.0
	# Il campe a 480 px : assez loin pour que sa ligne de defense soit hors de
	# portee des sorts courts, assez pres pour etre puni par un sort de zone bien
	# place. Le Seigneur Spectre a montre au banc qu au-dela de 600 px un boss qui
	# campe cesse d etre une decision pour devenir une taxe (il est redescendu de
	# 620 a 430 pour cette raison) ; 480 tient compte de son aura, qui lui donne
	# une protection que le Spectre n avait pas.
	demon_circle.keeps_distance_at = 480.0
	demon_circle.shoot_interval = 4.2
	demon_circle.shot_damage = 4
	# PV les plus bas des quatre (160) : sa protection est sa POSITION et son
	# aura, pas sa masse. Un protecteur qui encaisserait aussi serait deux boss.
	# Cristal : l arcane le fend, le physique ricoche, rien a empoisonner.
	_resist(demon_circle, {&"phys": 0.6, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.35,
		&"poison": 0, &"foudre": 1.2, &"lent": 0.5})
	_save(demon_circle, E + "demon_circle.tres")

	# L ENFANT, DEVENU DIVINITE — `lvl_16`, le siege vide. LE BOSS FINAL DU JEU.
	#
	# Document section 7 : « Il ne grandit pas, il ne change pas de forme. Il
	# arrete simplement de faire semblant d avoir peur. » C est la derniere tete
	# de la campagne et elle doit valoir les quinze niveaux qui la precedent, sans
	# etre un mur de PV — le document dit « Fais-la belle », pas « fais-la longue ».
	#
	# IL CUMULE, ET C EST SON PROPOS. Les quatre grands demons ont chacun UNE
	# question ; lui en pose trois a la fois, parce que c est lui qui les a tous
	# envoyes. Mais chaque morceau est DEJA CONNU du joueur a ce stade :
	#
	#   il petrifie la main (3 cartes)   — appris sur la lignee des gorgones
	#   il renvoie ce qu on lui envoie   — appris sur le Miroir de verre
	#   il se releve une fois            — appris sur le Coagule
	#
	# Rien d inedit dans la derniere vague du jeu, et c est delibere : un boss
	# final qui enseigne une regle neuve l enseigne au pire moment possible.
	# Celui-ci demande au joueur de se souvenir de tout l acte 3 et de tout
	# l acte 4 en meme temps, ce qui est la seule chose qu une fin de campagne
	# peut legitimement demander.
	#
	# SILHOUETTE : celle de CHRONOS (`juggernaut`), et c est le dernier
	# retournement. Le joueur a affronte Chronos au premier niveau et a la fin de
	# l acte 4 en croyant combattre l huissier de la machine ; il decouvre au
	# siege vide que cette silhouette etait celle du COMMANDITAIRE depuis le
	# debut. Une feuille neuve aurait dit « voici un nouveau monstre » ; celle-ci
	# dit « tu l as toujours eu en face de toi », ce que la scene raconte en mots.
	# Teinte d or, la couleur des divinites du registre, et non le rouge de
	# Chronos : meme forme, autre regne.
	var child_god := _enemy("child_god", "L Enfant", K.BOSS, 10,
		300.0, 32.0, 40, S.STAR, Color(0.95, 0.85, 0.45), 82.0)
	child_god.anim_key = &"juggernaut"
	child_god.sprite_scale = 1.15
	# LE REGARD. Trois cartes de la main, le plafond du champ : c est un boss, et
	# `GameConfig.MAX_BLOCKED_CARDS` garde le dernier mot pour qu il reste
	# toujours une carte jouable (demande du testeur : « pas plus de 5 sur 6 »).
	child_god.blocks_cards = 3
	# LA GARDE DE RENVOI. La fenetre doit rester STRICTEMENT sous l intervalle,
	# sinon la garde ne retombe jamais et le joueur n a plus de moment pour
	# jouer : 2 s de garde toutes les 7 s, donc 5 s de fenetre libre. A 45 %,
	# frapper pendant la garde coute cher sans etre suicidaire — c est un prix,
	# pas un mur, et le joueur peut choisir de le payer.
	child_god.reflect_interval = 7.0
	child_god.reflect_window = 2.0
	child_god.reflect_pct = 45.0
	# IL SE RELEVE. « Je voulais voir la fin » : le joueur croit avoir gagne, et
	# le siege se reoccupe. 40 % des PV d origine — assez pour que la carte gardee
	# en reserve serve enfin, pas assez pour etre un second combat entier.
	child_god.revive_hp_pct = 40.0
	# 300 PV, LEGEREMENT SOUS CHRONOS (320), et c est volontaire. Trois mecaniques
	# cumulees coutent deja au joueur la moitie de ses options ; y ajouter le plus
	# gros sac de PV du jeu ferait de la derniere vague une corvee de dix minutes.
	# La difficulte de ce boss est dans ses REGLES, pas dans sa barre.
	#
	# UNE DIVINITE N A PAS DE MATIERE, donc rien de grossier ne la marque : acier,
	# venin et flamme glissent. Ce qui la touche est ce qu elle a elle-meme mis
	# dans le monde — l ARCANE. Le joueur termine la campagne avec le deck du
	# mage et non avec une arme, et le gel ne prend pas sur ce qui tient le temps,
	# exactement comme chez Chronos dont il partage la silhouette.
	_resist(child_god, {&"phys": 0.5, &"feu": 0.7, &"givre": 0.85, &"arcane": 1.4,
		&"poison": 0, &"foudre": 0.9, &"lent": 0})
	_save(child_god, E + "child_god.tres")

	_enemies_v3(E)


## =====================================================================
## CHANTIER W2 — LE BESTIAIRE DU 27 SEPTEMBRE ENTRE EN JEU
##
## La vague 1 a livre douze mecaniques (champs d EnemyDef, groupes « v3 ») et
## onze silhouettes (AnimCatalog, bestiaire du 27/09) sans qu AUCUN monstre ne
## s en serve : du moteur et du dessin que le joueur ne voyait jamais. Ce bloc
## les porte, et chaque monstre est une COMBINAISON de champs existants — pas
## une ligne de script neuve, c est la regle du projet.
##
## POURQUOI LES NOUVELLES TETES SONT LA OU ELLES SONT. Quatre niveaux n avaient
## pas de mini-boss (lvl_12 a lvl_15) et lvl_15 n avait pas de boss, faute de
## tetes. Ils passent en premier. Viennent ensuite trois vagues de « mini-boss »
## que menait un monstre ORDINAIRE (lvl_03 le Pretre goule, lvl_07 le Glouton,
## lvl_21 aucun palier) : une tete de palier doit poser une question que la
## vague ne pose pas, un P3 ou un P4 n en pose pas.
##
## LA REGLE DES LIGNEES, deja celle des gorgones et des gelees : une famille
## partage une feuille et se lit par la TAILLE. Le Slime colossal se brise en
## Slimes enormes qui se brisent en Slimes moyens ; le trio de mages revient en
## adeptes plus petits. Le joueur reconnait la silhouette et sait deja quoi faire.
## =====================================================================
func _enemies_v3(E: String) -> void:
	var K := GameEnums.EnemyKind
	var S := GameEnums.Shape
	var T := GameEnums.DamageTag

	# --- LA LIGNEE DES SLIMES D EAU (acte 2, puis acte 5) ------------------
	#
	# Trois tailles d une meme creature, sur la feuille `slime_big` (un slime bleu
	# vu de cote) : c est la division qui la fait lire, comme les gelees vertes de
	# l acte 1. Une masse d EAU : le venin s y dilue, le froid la fige a peine en
	# surface, et la FOUDRE la traverse de part en part. C est la reponse, et elle
	# est l inverse de celle de la croute de lave du Colosse (voir plus bas) : un
	# boss en deux phases dont la seconde demande un autre element que la premiere.
	var slime_mid := _enemy("slime_mid", "Slime moyen", K.NORMAL, 1, 12.0, 72.0, 1,
		S.CIRCLE, Color(0.35, 0.55, 0.92), 18.0)
	slime_mid.anim_key = &"slime_big"
	# VAGUE 10 B2 — « BOND » (revue A4, §1.1) : il avance par a-coups (0,4 s / 1 s),
	# la zone posee sur son point d arret le trouve. Le distingue de la Gelee.
	slime_mid.burst_move = true
	slime_mid.burst_dash_time = 0.4
	slime_mid.burst_pause_time = 1.0
	_resist(slime_mid, {&"phys": 0.85, &"feu": 1.0, &"givre": 0.85, &"arcane": 1.0,
		&"poison": 0.6, &"foudre": 1.3})
	_save(slime_mid, E + "slime_mid.tres")

	# SLIME ENORME — MINI-BOSS de `lvl_08` depuis la vague 10 (la route du maire :
	# « des gelees qui se coupent en deux ») ; il menait le palier de lvl_03, que le
	# Gardien d ossements prend. Le Slime gonfle est son retour en ordinaire.
	#
	# 90 PV + trois Slimes moyens a 12 = 126 PV de chaine, dans la bande des
	# mini-boss du jeu (96 a 175). Les PV sont BAS pour un mini-boss parce que sa
	# difficulte est ailleurs : le tuer au mauvais moment lache trois corps rapides
	# au milieu de la vague, et le sort de zone garde pour eux EST la bonne reponse.
	var slime_huge := _enemy("slime_huge", "Slime enorme", K.MINIBOSS, 6, 90.0, 36.0, 12,
		S.CIRCLE, Color(0.30, 0.50, 0.90), 50.0)
	slime_huge.anim_key = &"slime_big"
	# Par CHEMIN et non par objet : un enfant embarque dans le .tres du parent
	# serait une copie, et retoucher slime_mid.tres ne changerait plus rien aux
	# slimes qui sortent du Slime enorme.
	slime_huge.split_into = load(E + "slime_mid.tres")
	slime_huge.split_count = 3
	_resist(slime_huge, {&"phys": 0.85, &"feu": 1.0, &"givre": 0.85, &"arcane": 1.0,
		&"poison": 0.6, &"foudre": 1.3})
	_save(slime_huge, E + "slime_huge.tres")

	# SLIME COLOSSAL — BOSS de `lvl_14`, la galerie des saisons (melange des actes
	# 1 et 2 : tout ce qui a deja ete efface revient, et les gelees d abord).
	#
	# UNE CROUTE DE LAVE autour d un slime d eau. La feuille `slime_colossal` est un
	# slime de magma : il resiste au feu et le givre le fend (le choc thermique de
	# tout le monde demoniaque). Quand la croute cede, DEUX Slimes enormes bleus en
	# sortent, qui craignent la foudre et se brisent a leur tour. Le joueur qui a
	# vide son givre sur la croute doit changer d element au milieu du combat.
	#
	# LA CHAINE COMPTE, PAS LE CORPS. 150 PV de croute + 2 x 126 de Slimes enormes
	# = 402 PV, entre Chronos (320) et l Enfant releve (420). Un boss hors budget
	# qui se divise pese sa chaine entiere : c est ce que verifie la suite
	# test_bestiaire_w2 (`_pv_de_chaine`), faute de quoi le colosse passerait pour
	# plus leger que Chronos alors qu il envoie sept corps.
	#
	# TRES GRAND, ET ENTIER A L ECRAN. Rayon 118 et echelle 1,2 : 595 px de large
	# sur un terrain de 1080, le plus gros sprite du jeu (le Reliquaire en fait
	# 542, le Sceau de Tombol 524). Plus de la moitie du terrain, jamais tout : la
	# marge d apparition suit la taille affichee (WaveSpawner.spawn_margin), donc il
	# nait entierement dans le cadre et reste ciblable d un bord a l autre. Le
	# rayon logique grandit avec : un sprite de 600 px sur une hitbox de 100 se
	# ferait toucher bien avant de sembler au contact.
	var colossal := _enemy("slime_colossal", "Slime colossal", K.BOSS, 10, 150.0, 24.0, 30,
		S.CIRCLE, Color(0.85, 0.40, 0.15), 118.0)
	colossal.anim_key = &"slime_colossal"
	colossal.sprite_scale = 1.2
	colossal.split_into = load(E + "slime_huge.tres")
	colossal.split_count = 2
	# Lave : le feu le nourrit, le venin brule avant de mordre, le givre fend la
	# croute. On ne ralentit pas une coulee a moitie.
	_resist(colossal, {&"phys": 0.75, &"feu": 0.5, &"givre": 1.35, &"arcane": 1.0,
		&"poison": 0.5, &"foudre": 0.85, &"lent": 0.5})
	_save(colossal, E + "slime_colossal.tres")

	# --- LES SLIMES DES TOMBES (acte 3, les fosses de Tombol) -------------

	# SLIME SQUELETTE : ce qui reste d un slime fantome trois secondes apres sa
	# mort. Il descend AUSSI seul dans les fosses, pour que le joueur connaisse la
	# silhouette avant de la voir renaitre d une marque au sol.
	var slime_skel := _enemy("slime_skeleton", "Slime squelette", K.NORMAL, 2, 16.0, 60.0, 2,
		S.CIRCLE, Color(0.55, 0.65, 0.95), 22.0)
	slime_skel.anim_key = &"slime_skeleton"
	# VAGUE 10 B2 — « CRANE » : son crane encaisse le premier coup ; une zone posee
	# sur la marque de renaissance le brise a la premiere morsure.
	slime_skel.first_hit_shield = true
	# Os et gelee : mort-vivant, donc sans rien a empoisonner ; le feu calcine les
	# os et l arcane defait ce qui les tient. Le froid glisse sur une gelee morte.
	_resist(slime_skel, {&"phys": 1.0, &"feu": 1.25, &"givre": 0.85, &"arcane": 1.15,
		&"poison": 0.0})
	_save(slime_skel, E + "slime_skeleton.tres")

	# SLIME FANTOME — RENAISSANCE DIFFEREE. Tue, il laisse une marque au sol et un
	# Slime squelette en sort 3 s plus tard. Le joueur voit le danger ARRIVER : un
	# sort de zone pose sur la marque tue le squelette a sa naissance.
	#
	# Il ZIGZAGUE : un fantome ne marche pas, il derive. C est aussi ce qui le rend
	# penible a viser pour un sort cible et facile pour une zone — la meme reponse
	# que sa marque, donc une seule lecon.
	#
	# 10 PV + 16 de squelette = 26 PV de chaine, comme un Serpent des sables (P2).
	var slime_ghost := _enemy("slime_ghost", "Slime fantome", K.NORMAL, 2, 10.0, 66.0, 3,
		S.CIRCLE, Color(0.75, 0.80, 0.90), 22.0)
	slime_ghost.anim_key = &"slime_ghost"
	slime_ghost.rebirth_def = load(E + "slime_skeleton.tres")
	slime_ghost.rebirth_count = 1
	slime_ghost.rebirth_delay = 3.0
	slime_ghost.move_pattern = EnemyDef.MovePattern.ZIGZAG
	slime_ghost.pattern_width = 180.0
	# Rien de solide : le physique le traverse, l arcane defait ce qui le tient
	# ensemble. Comme l Ombre, et pour la meme raison.
	_resist(slime_ghost, {&"phys": 0.65, &"feu": 1.0, &"givre": 1.0, &"arcane": 1.3,
		&"poison": 0.0, &"foudre": 1.1})
	_save(slime_ghost, E + "slime_ghost.tres")

	# GROS SLIME FANTOME : la meme chose en plus gros, qui laisse DEUX squelettes.
	# 34 + 2 x 16 = 66 PV de chaine pour un P4, au niveau du Gardien-totem (60) et
	# du Glouton (70). Il ne zigzague pas : trop lourd pour deriver, et un P4 doit
	# rester une cible qu on choisit, pas qu on poursuit.
	var ghost_big := _enemy("slime_ghost_big", "Gros slime fantome", K.NORMAL, 4, 34.0, 44.0, 6,
		S.CIRCLE, Color(0.70, 0.75, 0.88), 34.0)
	ghost_big.anim_key = &"slime_ghost"
	ghost_big.rebirth_def = load(E + "slime_skeleton.tres")
	ghost_big.rebirth_count = 2
	ghost_big.rebirth_delay = 3.0
	_resist(ghost_big, {&"phys": 0.65, &"feu": 1.0, &"givre": 1.0, &"arcane": 1.3,
		&"poison": 0.0, &"foudre": 1.1})
	_save(ghost_big, E + "slime_ghost_big.tres")

	# --- LE RENARD DORMEUR (acte 1, la foret de Nuri) ----------------------
	#
	# Toutes les 6 s d eveil il s arrete et dort 2 s, et PENDANT SON SOMMEIL LE
	# JOUEUR NE PEUT LANCER AUCUN SORT. Le tuer rend la magie aussitot. La foret
	# de Nuri est l acte des betes qui ne se comportent pas comme des betes : un
	# renard qui endort le mage en est la meilleure preuve.
	#
	# FRAGILE (15 PV) : la reponse est de le tuer pendant qu il est eveille, avec
	# le sort qu on vient de charger. Un dormeur blinde verrouillerait la main
	# pendant tout le combat, ce qui n est plus une decision. Le plafond et la
	# fenetre de magie garantie entre deux sommeils vivent dans Battlefield.
	var fox := _enemy("sleepy_fox", "Renard dormeur", K.NORMAL, 2, 15.0, 78.0, 3,
		S.TRIANGLE, Color(0.90, 0.50, 0.20), 22.0)
	fox.anim_key = &"fox"
	fox.sleep_interval = 6.0
	fox.sleep_duration = 2.0
	# Une bete a fourrure : le feu la prend, le froid la laisse de marbre. Le
	# venin d un sous-bois, elle le connait.
	_resist(fox, {&"phys": 1.1, &"feu": 1.25, &"givre": 0.8, &"arcane": 0.95,
		&"poison": 0.8})
	_save(fox, E + "sleepy_fox.tres")

	# --- ACTE 4, LE MONDE DEMONIAQUE ---------------------------------------

	# CACODEMON — le volant de l acte 4. Il REBONDIT d un bord a l autre en
	# diagonale au lieu de descendre : ni le mur (il vole) ni le tir tendu (il ne
	# reste pas dans sa colonne) ne le tiennent. Il est aussi le sbire du Seigneur
	# demon, qui le mange pour se soigner.
	var caco := _enemy("cacodaemon", "Cacodemon", K.NORMAL, 3, 26.0, 56.0, 4,
		S.CIRCLE, Color(0.80, 0.20, 0.25), 30.0)
	caco.anim_key = &"cacodaemon"
	caco.flying = true
	caco.move_pattern = EnemyDef.MovePattern.BOUNCE
	# 45 px/s de travers pour 56 de descente : une diagonale franche qu on lit, pas
	# une toupie. A 0 (= vitesse de base) il traversait l ecran trop vite pour
	# qu un sort cible ait le temps de partir.
	caco.pattern_lateral_speed = 45.0
	# Une bouche de l enfer : le feu est chez lui, le givre le saisit. La foudre
	# passe par la gueule ouverte.
	_resist(caco, {&"phys": 0.95, &"feu": 0.6, &"givre": 1.3, &"arcane": 1.1,
		&"poison": 0.8, &"foudre": 1.1})
	_save(caco, E + "cacodaemon.tres")

	# GOLEM A NOYAU — MINI-BOSS de `lvl_07`, la forge de Vharn (« tout est
	# blinde »). Il remplace le Glouton, un P4 ordinaire, en tete du palier.
	#
	# LASER DE RIPOSTE : chaque coup qui MORD declenche un rayon sur le mage, au
	# plus une fois toutes les 1,8 s. Il punit exactement ce que Vharn punit a sa
	# facon : la pluie de petits coups (poison, pluie de givre, nappes). La reponse
	# est le gros sort unique — la meme lecon que le boss du niveau, posee avant lui.
	#
	# SON PACK N A NI MARCHE NI DEGATS : il avance sur sa pose d attente (le noyau
	# respire) et le coup recu se lit par l eclair blanc et le rayon rouge, deux
	# canaux que le moteur donne a tout monstre. Verifie en capture.
	var mecha := _enemy("mecha_golem", "Golem a noyau", K.MINIBOSS, 6, 135.0, 26.0, 13,
		S.SQUARE, Color(0.55, 0.60, 0.70), 56.0)
	mecha.anim_key = &"mechagolem"
	mecha.laser_damage = 6
	mecha.laser_cooldown = 1.8
	# Pierre et cristal : le physique s y ebreche, rien a empoisonner, on ne le
	# ralentit pas. Le cristal du noyau boit la magie savante mais CONDUIT la
	# foudre — c est sa faille, differente de celle du Golem de pierre (arcane).
	_resist(mecha, {&"phys": 0.65, &"feu": 0.9, &"givre": 1.0, &"arcane": 0.8,
		&"poison": 0.0, &"foudre": 1.35, &"lent": 0.0})
	_save(mecha, E + "mecha_golem.tres")

	# LES JUMEAUX DU CERCLE — MINI-BOSS de `lvl_12`, le temple d Ymoa (« auras et
	# protections »). Deux diablotins lies : si l un tombe pendant que l autre tient
	# debout, il se RELEVE 4 s plus tard a 60 % de ses PV. Ils se protegent l un
	# l autre, ce qui est tout le propos du temple.
	#
	# `swarm_count = 2` et non deux entrees : UNE definition, donc UN tirage en
	# Massacre, fait descendre la paire complete. Deux definitions auraient laisse
	# le mode infini tirer un jumeau seul, qui n est plus qu un monstre ordinaire.
	#
	# La reponse : un sort de zone, ou deux frappes rapprochees. Deux retours au plus
	# par jumeau (`twin_max_returns`), sinon un joueur sans zone ne finit jamais.
	var twins := _enemy("circle_twins", "Jumeaux du Cercle", K.MINIBOSS, 6, 70.0, 40.0, 7,
		S.DIAMOND, Color(0.85, 0.30, 0.30), 44.0)
	twins.anim_key = &"demon"
	# La feuille `demon` n occupe que 22 % de sa case : sans correction chaque
	# jumeau entrerait a la taille d un gnome.
	twins.sprite_scale = 1.3
	twins.swarm_count = 2
	twins.twin_group = &"circle_twins"
	twins.twin_revive_delay = 4.0
	twins.twin_revive_hp_pct = 60.0
	twins.twin_max_returns = 2
	# Diablotins : le feu est leur element, le givre leur faille. Le temple ne leur
	# donne aucune armure — leur protection est l AUTRE jumeau, pas leur peau.
	_resist(twins, {&"phys": 1.0, &"feu": 0.6, &"givre": 1.25, &"arcane": 1.0,
		&"poison": 0.8, &"foudre": 1.1})
	_save(twins, E + "circle_twins.tres")

	# MALYK, LE SEIGNEUR DEMON — BOSS de `lvl_13`, le pentacle brise.
	#
	# LE DOCUMENT LUI FAIT DEJA SA PLACE sans le nommer : « Aucun des quatre n a meme
	# lu l ordre. Ils l ont RECU. » Malyk est celui qui l a porte — le seigneur du
	# pentacle, que les quatre grands demons croyaient servir. La Reine gorgone,
	# qui tenait la place faute de tete (chantier N3), redescend mener le palier
	# de mini-boss du meme niveau, au milieu de ses Regards.
	#
	# DEVOREUR-INVOCATEUR : il appelle des Cacodemons et, une fois qu ils ont muri
	# trois secondes, il les RAPPELLE et les mange pour se soigner de 60 % de ce
	# qu il leur restait. Tuer ses sbires loin de lui lui coupe les vivres ; les
	# laisser vivre le rend plus dur a finir. La question est celle de l Ensevelisseur
	# retournee : il ne faut pas seulement couper la source, il faut affamer le boss.
	var demon_lord := _enemy("demon_lord", "Malyk, Seigneur demon", K.BOSS, 10, 210.0, 30.0, 32,
		S.STAR, Color(0.45, 0.25, 0.55), 80.0)
	demon_lord.anim_key = &"demonlord"
	demon_lord.devours = true
	demon_lord.devour_heal_pct = 60.0
	demon_lord.devour_delay = 3.0
	demon_lord.summon_def = load(E + "cacodaemon.tres")
	demon_lord.summon_interval = 6.0
	demon_lord.summon_count = 1
	# Trois au plus : chaque Cacodemon vaut jusqu a 16 PV de soin, et trois a
	# l ecran suffisent a rendre le combat long pour qui les ignore.
	demon_lord.summon_max_alive = 3
	# Le maitre du monde demoniaque : le feu lui appartient, le givre le fend comme
	# il fend toute sa lignee. L arcane atteint ce qui le lie au pentacle.
	_resist(demon_lord, {&"phys": 0.85, &"feu": 0.55, &"givre": 1.25, &"arcane": 1.2,
		&"poison": 0.7, &"foudre": 1.0})
	_save(demon_lord, E + "demon_lord.tres")

	# --- LE TRIO DE MAGES (acte 3) et SES ADEPTES (actes 4 et 5) ----------
	#
	# BOSS de `lvl_20`, la cour des rois morts : « statues, arrieres-gardes
	# laissees par le roi ». Trois gardiens de pierre flottants (la famille du Sceau
	# de Tombol) arrivent ENSEMBLE, chacun avec sa table et son pouvoir :
	#
	#   bleu    (givre)   — MIROIR DU MAGE : il avance au rythme du mage
	#   rouge   (braise)  — TROIS VIES : il revient du haut, de plus en plus vite
	#   magenta (arcanes) — DIX SCEAUX : ses dix premiers coups ne font rien
	#
	# Trois questions opposees en meme temps : ralentir (bleu), tuer loin (rouge),
	# depenser des petits coups (magenta). Aucun deck ne repond aux trois, le joueur
	# choisit l ordre — c est ce qui fait d un trio un combat et non trois PV.
	#
	# SEUL LE ROUGE EST UN BOSS, et il mene la vague : c est lui que la demande
	# decrit (« un boss qui revient a la vie trois fois depuis le haut »). Le bleu et
	# le magenta sont des MINI-BOSS : en Massacre un palier tire UNE tete, et trois
	# boss d un meme monde y auraient dilue les autres. Le rouge sort donc comme
	# boss du Grand Cimetiere, ses deux freres comme paliers de mini-boss, chacun
	# avec son pouvoir entier.
	#
	# Le rouge en tete a une seconde raison : la carte de campagne illustre chaque
	# niveau par sa tete de boss, une silhouette par niveau. La feuille bleue est
	# celle du Sceau de Tombol, qui ferme le meme acte ; en tete, le bleu lui volait
	# son medaillon.
	#
	# LEURS FEUILLES RESTENT PURES : les trois couleurs du pack font le trio. C est
	# le Sceau de Tombol, qui partageait la feuille bleue, qui prend une teinte
	# (AnimCatalog.MODULATE) — il est seul, eux vont par trois.
	#
	# Chaine : 100 (bleu) + 85 x (1 + 3 x 60 %) = 238 (rouge) + 85 (magenta) = 423
	# PV, le poids de l Enfant releve. Chacun est leger ; c est le cumul qui pese.
	var trio_frost := _enemy("trio_frost", "Mage du givre", K.MINIBOSS, 6, 100.0, 30.0, 12,
		S.STAR, Color(0.35, 0.65, 0.95), 52.0)
	trio_frost.anim_key = &"mageguardian"
	trio_frost.sprite_scale = 1.3
	# Reference = la vitesse de depart du mage : au premier instant il avance a sa
	# vitesse de base. Le mage qui accelere l accelere ; le mage touche le freine
	# plus que le reste du monde. Borne a x1,8 : au-dela il traverse l ecran plus
	# vite qu une incantation.
	trio_frost.mirror_speed_ref = GameConfig.SPEED_START_PERCENT
	trio_frost.mirror_speed_min = 0.6
	trio_frost.mirror_speed_max = 1.8
	_resist(trio_frost, {&"phys": 1.0, &"feu": 1.35, &"givre": 0.4, &"arcane": 1.0,
		&"poison": 0.8, &"foudre": 1.1})
	_save(trio_frost, E + "trio_frost.tres")

	var trio_ember := _enemy("trio_ember", "Mage de braise", K.BOSS, 10, 85.0, 34.0, 24,
		S.STAR, Color(0.95, 0.40, 0.25), 56.0)
	trio_ember.anim_key = &"mageguardian_red"
	trio_ember.sprite_scale = 1.3
	# TROIS VIES, mot pour mot la demande : il revient trois fois DEPUIS LE HAUT,
	# de plus en plus vite. 60 % des PV a chaque retour, +35 % de vitesse cumules.
	# Le tuer loin du mage lui fait refaire tout le chemin : c est la reponse.
	trio_ember.extra_lives = 3
	trio_ember.extra_life_hp_pct = 60.0
	trio_ember.extra_life_speed_pct = 35.0
	_resist(trio_ember, {&"phys": 1.0, &"feu": 0.4, &"givre": 1.35, &"arcane": 1.0,
		&"poison": 0.9, &"foudre": 1.0})
	_save(trio_ember, E + "trio_ember.tres")

	var trio_arcane := _enemy("trio_arcane", "Mage des arcanes", K.MINIBOSS, 6, 85.0, 32.0, 12,
		S.STAR, Color(0.80, 0.35, 0.90), 52.0)
	trio_arcane.anim_key = &"mageguardian_magenta"
	trio_arcane.sprite_scale = 1.3
	# DIX SCEAUX, mot pour mot la demande : ses dix premiers coups ne lui font rien.
	# Dix et non six (Reliquaire, Vharn) parce qu il n est pas seul : pendant que le
	# joueur depense ses coups sur lui, les deux autres avancent. Les petites cartes
	# rapides brisent les sceaux, le gros sort se garde pour apres.
	trio_arcane.hits_immune = 10
	_resist(trio_arcane, {&"phys": 1.35, &"feu": 1.0, &"givre": 1.0, &"arcane": 0.4,
		&"poison": 1.0, &"foudre": 0.85})
	_save(trio_arcane, E + "trio_arcane.tres")

	# LES ADEPTES — le trio revient en MONSTRES ORDINAIRES dans les actes de fin
	# (acte 5 : « les anciens boss redeviennent des monstres ordinaires »). Meme
	# feuille, plus petite, un tiers des PV, et la mecanique SIMPLIFIEE — jamais le
	# .tres du boss rejoue avec ses PV de boss.
	#
	# Chacun gagne un trajet non rectiligne a la place du pouvoir qu il perd : le
	# bleu zigzague, le magenta saute de colonne en colonne (il se teleporte), le
	# rouge garde UNE vie de rechange.
	var adept_frost := _enemy("adept_frost", "Adepte du givre", K.NORMAL, 3, 28.0, 44.0, 5,
		S.STAR, Color(0.35, 0.65, 0.95), 28.0)
	adept_frost.anim_key = &"mageguardian"
	adept_frost.move_pattern = EnemyDef.MovePattern.ZIGZAG
	adept_frost.pattern_width = 200.0
	_resist(adept_frost, {&"phys": 1.0, &"feu": 1.25, &"givre": 0.6, &"arcane": 1.0,
		&"poison": 0.85, &"foudre": 1.1})
	# La filiation est ECRITE (EnemyDef.demoted_from) : le garde-fou de test_bosses
	# compare chaque promu a sa tete d origine, sans deviner par la feuille.
	adept_frost.demoted_from = &"trio_frost"
	_save(adept_frost, E + "adept_frost.tres")

	var adept_ember := _enemy("adept_ember", "Adepte de braise", K.NORMAL, 3, 22.0, 48.0, 5,
		S.STAR, Color(0.95, 0.40, 0.25), 28.0)
	adept_ember.anim_key = &"mageguardian_red"
	adept_ember.extra_lives = 1
	adept_ember.extra_life_hp_pct = 60.0
	_resist(adept_ember, {&"phys": 1.0, &"feu": 0.6, &"givre": 1.25, &"arcane": 1.0,
		&"poison": 0.9, &"foudre": 1.0})
	adept_ember.demoted_from = &"trio_ember"
	_save(adept_ember, E + "adept_ember.tres")

	var adept_arcane := _enemy("adept_arcane", "Adepte des arcanes", K.NORMAL, 3, 26.0, 44.0, 5,
		S.STAR, Color(0.80, 0.35, 0.90), 28.0)
	adept_arcane.anim_key = &"mageguardian_magenta"
	adept_arcane.move_pattern = EnemyDef.MovePattern.HOP
	adept_arcane.pattern_width = 220.0
	adept_arcane.pattern_interval = 1.8
	# Deux sceaux au lieu de dix : la lecon du maitre, en rappel.
	adept_arcane.hits_immune = 2
	_resist(adept_arcane, {&"phys": 1.25, &"feu": 1.0, &"givre": 1.0, &"arcane": 0.6,
		&"poison": 1.0, &"foudre": 0.9})
	adept_arcane.demoted_from = &"trio_arcane"
	_save(adept_arcane, E + "adept_arcane.tres")

	# --- ACTE 3 : LE FOSSOYEUR ---------------------------------------------
	#
	# MINI-BOSS de `lvl_21`, le pentacle de Tombol, qui n avait aucun palier. Il
	# ENTRE PAR LE COTE — il sort des tombes du bord, pas du fond du terrain — et il
	# RELEVE les morts autour de lui : toutes les 4 s, un monstre tombe dans un
	# rayon de 300 px se remet debout, six fois au plus.
	#
	# CE QU IL CHANGE : l ordre des cibles. Partout ailleurs on nettoie la vague et
	# on finit par le gros ; ici chaque mort pres de lui est un corps a retuer, et
	# la seule sortie est de le chercher d abord, sur le cote ou il est entre.
	# LE PLAFOND (six releves) EST LA MECANIQUE : sans lui la vague ne finirait pas.
	var digger := _enemy("gravedigger", "Le Fossoyeur", K.MINIBOSS, 6, 120.0, 32.0, 13,
		S.SQUARE, Color(0.40, 0.40, 0.45), 54.0)
	digger.anim_key = &"pawn_black"
	# La feuille pawn_black occupe 40 % de sa case : agrandie pour qu il domine les
	# goules qu il releve.
	digger.sprite_scale = 1.4
	digger.entry_side = true
	digger.reanimate_radius = 300.0
	digger.reanimate_interval = 4.0
	digger.reanimate_max = 6
	# Un homme de pelle : chair vivante sous la capuche. Le feu le trouve, le venin
	# des fosses ne lui fait plus rien depuis longtemps.
	_resist(digger, {&"phys": 1.1, &"feu": 1.2, &"givre": 0.9, &"arcane": 1.1,
		&"poison": 0.6, &"foudre": 1.0})
	_save(digger, E + "gravedigger.tres")

	# --- ACTE 5 : L ESPACE DIVIN -------------------------------------------

	# LE CAMELEON DES SAISONS — MINI-BOSS de `lvl_14`, la galerie des saisons.
	# Toutes les 5 s il change d element faible, dans l ordre des saisons : feu
	# (l ete), vent (l automne), glace (l hiver), nature (le printemps). L element
	# resiste est a l oppose du cycle : la glace en ete, la nature en automne. Le
	# deck qui gagne est celui qui a DEUX elements et attend le bon moment.
	# Vague 8 : les saisons ont enfin leurs elements. L ancien cycle (feu, poison,
	# givre, foudre) n avait qu un element sur quatre dans le deck de lvl_14 ; le
	# nouveau en a deux (feu, et le vent de la Fleche percante).
	#
	# Il ne declare AUCUN de ces quatre elements dans `resistances` : les deux
	# tables se multiplieraient, et un feu resiste a 0,5 par la table et a 0,5 par
	# le cycle deviendrait une immunite de fait.
	var chameleon := _enemy("season_chameleon", "Cameleon des saisons", K.MINIBOSS, 6,
		125.0, 36.0, 13, S.STAR, Color(0.70, 0.85, 0.55), 54.0)
	chameleon.anim_key = &"wraith"
	chameleon.chameleon_interval = 5.0
	chameleon.chameleon_elements = [T.FIRE, T.WIND, T.ICE, T.NATURE]
	# Ses deux multiplicateurs tournants passent par la MEME accentuation que les
	# tables : sinon le Cameleon, dont la faiblesse EST la mecanique, deviendrait
	# le monstre aux ecarts les plus timides du bestiaire. Et par les memes
	# PALIERS (vague 10) : +100 % et -75 %, deux chiffres ronds a la fiche.
	chameleon.chameleon_weak_mult = EnemyDef.tiered_value(EnemyDef.accentuate(1.5))
	chameleon.chameleon_resist_mult = EnemyDef.tiered_value(EnemyDef.accentuate(0.5))
	_resist(chameleon, {&"phys": 0.9, &"arcane": 1.1})
	_save(chameleon, E + "season_chameleon.tres")

	# LE GREFFIER — MINI-BOSS de `lvl_15`, le registre. Le commis des dieux qui
	# tiennent les comptes : il RAYE une ligne de la main du joueur. Toutes les 7 s
	# il petrifie la carte la plus longue a incanter et, 4 s plus tard, la lance
	# CONTRE le mage : 5 points de vitesse par seconde d incantation. Tue avant, il
	# rend la carte.
	#
	# Le joueur apprend a jouer ses gros sorts VITE devant lui, ou a garder une
	# main de petites cartes — le contraire exact du Reliquaire.
	var clerk := _enemy("spell_clerk", "Le Greffier", K.MINIBOSS, 6, 115.0, 34.0, 13,
		S.DIAMOND, Color(0.55, 0.45, 0.80), 54.0)
	clerk.anim_key = &"evilwizard"
	clerk.steal_interval = 7.0
	clerk.steal_cast_delay = 4.0
	clerk.steal_damage_per_cast_second = 5.0
	# Un scribe : sa robe ne pare rien, sa plume pare la magie savante.
	_resist(clerk, {&"phys": 1.3, &"feu": 1.15, &"givre": 0.9, &"arcane": 0.6,
		&"poison": 0.85, &"foudre": 1.0})
	_save(clerk, E + "spell_clerk.tres")

	# L HORLOGER — BOSS de `lvl_15`, le registre, qui n avait pas de boss.
	#
	# Toutes les 7 s il REVIENT 3 s en arriere : a la position et aux PV qu il
	# avait alors. Les degats portes juste avant un retour sont effaces, ceux portes
	# juste APRES tiennent. C est le seul adversaire du jeu qui fait au mage ce que
	# le mage a fait au monde — il recule le temps — et les dieux du registre le
	# trouvent amusant pour cette raison exacte.
	#
	# Quatre retours au plus (`rewind_max`) : la fenetre garantit deja la fin, le
	# plafond empeche le combat de s etirer pour qui n a pas compris le rythme.
	var clock := _enemy("clockmaker", "L Horloger", K.BOSS, 10, 240.0, 30.0, 34,
		S.HEXAGON, Color(0.90, 0.72, 0.35), 78.0)
	clock.anim_key = &"decepticle"
	# Meme correction que le Colosse des Forges (33 % d occupation). La teinte
	# laiton (AnimCatalog.MODULATE) le distingue du Colosse, qui porte la feuille
	# nue.
	clock.sprite_scale = 1.15
	clock.rewind_interval = 7.0
	clock.rewind_seconds = 3.0
	clock.rewind_max = 4
	# Un automate de laiton : l acier ricoche, rien a empoisonner, et on ne ralentit
	# pas celui qui tient l heure. La foudre deregle son mecanisme.
	_resist(clock, {&"phys": 0.7, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.25,
		&"poison": 0.0, &"foudre": 1.3, &"lent": 0.0})
	_save(clock, E + "clockmaker.tres")

	# --- LES BOSS PROMUS EN VERMINE (acte 5) --------------------------------
	#
	# « Les anciens boss redeviennent des monstres ordinaires. » Chaque promu est un
	# .tres DERIVE : un tiers des PV environ, une mecanique simplifiee, la feuille
	# du boss plus petite. Rejouer le .tres du boss aurait envoye ses PV et son
	# contact de boss dans une vague de troupes.

	# LE CAILLOT — le Coagule (boss de `lvl_02`) en vermine. Il se releve encore une
	# fois, mais a 30 PV : la lecon du deuxieme niveau, rejouee sans le combat.
	var clot := _enemy("blood_clot", "Caillot", K.NORMAL, 3, 30.0, 44.0, 5,
		S.DIAMOND, Color(0.72, 0.18, 0.22), 30.0)
	clot.anim_key = &"blood"
	clot.sprite_scale = 1.1
	clot.revive_hp_pct = 40.0
	_resist(clot, {&"phys": 0.75, &"feu": 1.25, &"givre": 1.2, &"arcane": 1.0,
		&"poison": 0.0, &"foudre": 0.9})
	clot.demoted_from = &"blood_coagulum"
	_save(clot, E + "blood_clot.tres")

	# L ECLAT DE MIROIR — le Miroir de Forge (mini-boss de `lvl_05`) en vermine. Une
	# garde plus courte (1,5 s sur 6) et un renvoi de 30 % au lieu de 45 : il
	# rappelle qu il faut regarder avant de lancer, il ne l impose plus.
	var shard := _enemy("mirror_shard", "Eclat de miroir", K.NORMAL, 3, 24.0, 46.0, 5,
		S.STAR, Color(0.70, 0.88, 0.95), 28.0)
	shard.anim_key = &"monk_blue"
	shard.reflect_interval = 6.0
	shard.reflect_window = 1.5
	shard.reflect_pct = 30.0
	_resist(shard, {&"phys": 1.3, &"feu": 0.85, &"givre": 1.1, &"arcane": 0.8,
		&"poison": 0.0, &"foudre": 0.85})
	shard.demoted_from = &"glass_mirror"
	_save(shard, E + "mirror_shard.tres")

	# LES ECHOS DU GARDIEN ET DE CHRONOS (chantier W3). L acte 5 envoyait
	# `warden.tres` et `chronos.tres` EUX-MEMES dans ses vagues de troupes : deux ou
	# trois Gardiens a 140 PV et un Chronos a 320 PV par vague ordinaire, avec leur
	# contact de boss. `lvl_16` tombait a 5 victoires sur 30, le joueur mourant des
	# la premiere vague — un mur de PV la ou le document raconte une DECHEANCE.
	#
	# Des ECHOS : l espace divin rejoue les anciens combats du mage, en plus petit
	# et en plus pale (teinte spectrale, AnimCatalog.MODULATE). Pale aussi pour les
	# separer de l Enfant, qui porte la feuille de Chronos a pleine taille et ferme
	# la campagne : le joueur ne doit pas croire le boss final arrive en vague 1.
	#
	# ECHO DU GARDIEN — 40 % des PV, un P4. Sa mecanique simplifiee est son
	# BOUCLIER : l armure lourde du Gardien devient un premier coup encaisse, la
	# meme lecon (ne pas ouvrir sur le gros sort) en une seule fois.
	var warden_echo := _enemy("warden_echo", "Echo du Gardien", K.NORMAL, 4, 56.0, 42.0, 6,
		S.HEXAGON, Color(0.90, 0.40, 0.25), 36.0)
	warden_echo.anim_key = &"chaosknight"
	warden_echo.first_hit_shield = true
	warden_echo.demoted_from = &"warden"
	# La table du Gardien, ecarts resserres : la magie savante reste sa faille.
	_resist(warden_echo, {&"phys": 0.85, &"feu": 0.9, &"givre": 0.95, &"arcane": 1.15,
		&"foudre": 1.1})
	_save(warden_echo, E + "warden_echo.tres")

	# ECHO DE CHRONOS — 30 % des PV, un P4. Chronos ne se ralentissait PAS ; son
	# echo se ralentit a moitie (0,6 et non 0,5 : sous ce seuil un monstre devient
	# aussi insensible a l etourdissement, voir Enemy.STUN_RESIST_THRESHOLD, et la
	# decheance ne serait plus qu un nom).
	var chronos_echo := _enemy("chronos_echo", "Echo de Chronos", K.NORMAL, 4, 96.0, 36.0, 8,
		S.STAR, Color(0.95, 0.20, 0.25), 40.0)
	chronos_echo.anim_key = &"juggernaut"
	# VAGUE 10 B2 — l ECHEANCE SIMPLIFIEE : il se plante 2 s toutes les 10 s ; s il
	# n est pas frappe, c est LUI qui s accelere (+40 % pendant 3 s), le mage ne
	# perd rien. La lecon de Chronos sans sa punition.
	chronos_echo.deadline_interval = 10.0
	chronos_echo.deadline_window = 2.0
	chronos_echo.deadline_stun = 1.0
	chronos_echo.deadline_penalty = 0
	chronos_echo.deadline_haste_pct = 40.0
	chronos_echo.deadline_haste_time = 3.0
	chronos_echo.demoted_from = &"chronos"
	_resist(chronos_echo, {&"phys": 1.1, &"feu": 1.1, &"givre": 0.8, &"arcane": 0.95,
		&"poison": 1.05, &"lent": 0.6})
	_save(chronos_echo, E + "chronos_echo.tres")

	# LES ECHOS DES QUATRE SEIGNEURS DE L ACTE 4 (chantier W4) sont RETIRES a la
	# vague 10 (chantier B2) : des boss de l acte 4 ne peuvent revenir nulle part
	# sous la regle des promotions. Voir _promus_w10() plus bas.

	# --- LE BRISEUR DE TERTRES (chantier W3) -------------------------------
	#
	# MINI-BOSS de `lvl_04`, le Grand Appel. Le golem qui a creuse le Grand
	# Cimetiere : ce qui depasse du sol, il l aplanit. Toutes les 7 s il s arrete,
	# marque le mur, l arbre ou l autel le plus proche (560 px, la moitie du
	# terrain) et l abat 1,8 s plus tard d une frappe au sol. Il epargne l eau.
	#
	# POURQUOI `lvl_04` : c est le niveau dont le deck porte un objet de terrain
	# qu on a INTERET a garder (vague 10 : le Mur de pierre, sa commune nouvelle, qui
	# arrete les fleches des Lutins archers). Place ailleurs, sa mecanique ne se
	# verrait jamais — il marcherait vers un mage qui n a rien pose. Ici il apprend,
	# DEUX vagues avant le boss, que le decor tombe si on laisse vivre celui qui le
	# brise. Le Casseur de tertres est son retour en ordinaire (acte 3).
	#
	# Pierre de tombe : le physique s y ebreche, le venin n a rien a ronger, l arcane
	# defait ce qui l anime. Il ne resiste PAS au ralentissement : l etourdir pendant
	# son geste est l une des deux reponses, elle doit exister.
	var breaker := _enemy("terrain_breaker", "Le Briseur de tertres", K.MINIBOSS, 6, 150.0,
		30.0, 13, S.SQUARE, Color(0.55, 0.50, 0.40), 58.0)
	breaker.anim_key = &"golem_orange"
	breaker.terrain_break_interval = 7.0
	breaker.terrain_break_reach = 560.0
	breaker.terrain_break_windup = 1.8
	_resist(breaker, {&"phys": 0.75, &"feu": 0.9, &"givre": 1.15, &"arcane": 1.3,
		&"poison": 0.65, &"foudre": 1.0})
	_save(breaker, E + "terrain_breaker.tres")
	_promus_w10(E)  # VAGUE 10 B2 : les mini-boss et boss promus



## LES PROMUS DE LA VAGUE 10 (chantier B2, regle du co-auteur du 14/10) :
##   - un MINI-BOSS revient en monstre ORDINAIRE a l acte suivant ;
##   - un BOSS revient en MINI-BOSS deux actes plus tard, ou en ordinaire trois
##     actes plus tard.
## Chaque promu est un .tres DERIVE (DEC-025) : la feuille de l original, plus
## petite, des PV coupes (la moitie au plus pour un ordinaire, les deux tiers au
## plus pour un mini-boss), et UNE mecanique simplifiee de l original. Un
## personnage NOMME et mort revient en ECHO (teinte spectrale) ; une espece
## revient en plus petit, sous un nom d espece. test_campagne_w10 tient les
## delais (acte de l original + 1 / + 2 / + 3) et les PV.
##
## POURQUOI PAS LES ECHOS DES QUATRE SEIGNEURS : ce sont des boss de l acte 4. La
## regle les renverrait en mini-boss a l acte 6, qui n existe pas. Ils
## descendaient dans `lvl_13` (le meme acte) et `lvl_16` (l acte suivant) : les
## deux contredisaient la regle. Ils sont retires ; le siege vide (`lvl_16`)
## envoie a leur place ceux qui ont « ferme des actes entiers » et dont la regle
## permet le retour (le Gardien, l Ensevelisseur, le Sceau de Tombol).
func _promus_w10(E: String) -> void:
	var K := GameEnums.EnemyKind
	var S := GameEnums.Shape

	# --- ACTE 2 : les mini-boss de l acte 1, en ordinaires ---------------------

	# L ECUMEUR — l Ecumeur du ciel (mini-boss de lvl_01) en bande. Il pique
	# encore, plus court ; il vole, la Fleche percante le cueille.
	var ecumeur := _enemy("ecumeur", "Ecumeur", K.FAST, 3, 30.0, 66.0, 4,
		S.TRIANGLE, Color(0.55, 0.80, 0.95), 34.0)
	ecumeur.anim_key = &"pawn_yellow"
	ecumeur.flying = true
	ecumeur.burst_move = true
	ecumeur.burst_dash_time = 0.5
	ecumeur.burst_pause_time = 1.0
	ecumeur.demoted_from = &"skyreaver"
	_resist(ecumeur, {&"phys": 1.2, &"feu": 0.9, &"givre": 0.75, &"foudre": 1.2})
	_save(ecumeur, E + "ecumeur.tres")

	# LE SLIME GONFLE — le Slime enorme (mini-boss de lvl_08) en petit : il se
	# divise en DEUX Slimes moyens au lieu de trois. 36 + 2 x 12 = 60 PV de chaine.
	var swollen := _enemy("slime_swollen", "Slime gonfle", K.SPLITTER, 3, 36.0, 40.0, 4,
		S.CIRCLE, Color(0.35, 0.55, 0.92), 30.0)
	swollen.anim_key = &"slime_big"
	swollen.split_into = load(E + "slime_mid.tres")
	swollen.split_count = 2
	swollen.demoted_from = &"slime_huge"
	_resist(swollen, {&"phys": 0.85, &"givre": 0.85, &"poison": 0.6, &"foudre": 1.3})
	_save(swollen, E + "slime_swollen.tres")

	# LA GORGONE AINEE — la Matrone (mini-boss de lvl_02) revenue au rang commun :
	# son regard ne fige plus qu UNE carte, mais elle tient plus longtemps qu une
	# Gorgone (40 PV contre 26). Abattre d abord celle qui regarde.
	var elder := _enemy("gorgon_elder", "Gorgone ainee", K.NORMAL, 3, 40.0, 34.0, 5,
		S.DIAMOND, Color(0.55, 0.75, 0.45), 32.0)
	elder.anim_key = &"gorgon"
	elder.blocks_cards = 1
	elder.demoted_from = &"gorgon_matron"
	_resist(elder, {&"phys": 1.2, &"feu": 1.1, &"givre": 1.1, &"arcane": 0.8, &"poison": 0.55})
	_save(elder, E + "gorgon_elder.tres")

	# LE VASSAL DE BRAISE — le Seigneur de braise (mini-boss de lvl_09) en petit :
	# sa riposte ne fait plus que 2 degats, une fois toutes les 3 s.
	var vassal := _enemy("ember_vassal", "Vassal de braise", K.NORMAL, 3, 34.0, 44.0, 5,
		S.DIAMOND, Color(0.95, 0.45, 0.20), 30.0)
	vassal.anim_key = &"pawn_purple"
	vassal.laser_damage = 2
	vassal.laser_cooldown = 3.0
	vassal.demoted_from = &"emberlord"
	_resist(vassal, {&"phys": 0.9, &"feu": 0.55, &"givre": 1.35, &"poison": 0.8, &"foudre": 1.1})
	_save(vassal, E + "ember_vassal.tres")

	# --- ACTE 3 : les mini-boss de l acte 2, en ordinaires ---------------------

	# LA GARDE D OSSEMENTS — le Gardien d ossements (mini-boss de lvl_03) en
	# simple soldat : sa garde est plus courte (2 s sur 6) et laisse passer 30 %.
	var bone_guard := _enemy("bone_guard", "Garde d ossements", K.SHIELDED, 3, 40.0, 40.0, 5,
		S.HEXAGON, Color(0.80, 0.78, 0.70), 34.0)
	bone_guard.anim_key = &"warrior_black"
	bone_guard.reflect_interval = 6.0
	bone_guard.reflect_window = 2.0
	bone_guard.reflect_pct = 0.0
	bone_guard.guard_block_pct = 70.0
	bone_guard.demoted_from = &"bonewarden"
	_resist(bone_guard, {&"phys": 0.75, &"feu": 1.25, &"givre": 1.15, &"arcane": 0.9, &"poison": 0})
	_save(bone_guard, E + "bone_guard.tres")

	# LE CASSEUR DE TERTRES — le Briseur (mini-boss de lvl_04) en petit. Sa
	# mecanique simplifiee : il n abat plus le decor, il en a la peau — une
	# pierre tombale qui encaisse le premier coup.
	var casseur := _enemy("tomb_breaker", "Casseur de tertres", K.TANK, 3, 60.0, 30.0, 5,
		S.SQUARE, Color(0.55, 0.50, 0.40), 40.0)
	casseur.anim_key = &"golem_orange"
	casseur.first_hit_shield = true
	casseur.demoted_from = &"terrain_breaker"
	_resist(casseur, {&"phys": 0.75, &"feu": 0.9, &"givre": 1.15, &"arcane": 1.3,
		&"poison": 0.65})
	_save(casseur, E + "tomb_breaker.tres")

	# LE PILLARD DESERTEUR — le Capitaine pillard (mini-boss de lvl_18) sans sa
	# bande : il surgit encore du cote, plus solide qu un pillard, mais n appelle
	# plus personne.
	var deserter := _enemy("raider_deserter", "Pillard deserteur", K.FAST, 2, 24.0, 84.0, 3,
		S.TRIANGLE, Color(0.65, 0.75, 0.40), 28.0)
	deserter.anim_key = &"goblin2"
	deserter.sprite_scale = 1.15
	deserter.entry_side = true
	deserter.demoted_from = &"raider_captain"
	_resist(deserter, {&"phys": 0.85, &"feu": 1.25, &"givre": 1.2, &"poison": 0.55})
	_save(deserter, E + "raider_deserter.tres")

	# LE PLANOGO CENDRE — la Mere Planogo (mini-boss de lvl_17) en petit : elle
	# n appelle plus qu UN Planogo a la fois, toutes les 9 s.
	var ash := _enemy("planogo_ash", "Planogo cendre", K.EVASIVE, 3, 26.0, 70.0, 4,
		S.CIRCLE, Color(0.70, 0.75, 0.80), 28.0)
	ash.anim_key = &"flyer"
	ash.flying = true
	ash.summon_def = load(E + "wisp.tres")
	ash.summon_interval = 9.0
	ash.summon_count = 1
	ash.summon_max_alive = 1
	ash.demoted_from = &"planogo_mother"
	_resist(ash, {&"phys": 0.65, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.3, &"foudre": 1.2})
	_save(ash, E + "planogo_ash.tres")

	# --- ACTE 4 : les mini-boss de l acte 3, en ordinaires ---------------------

	# LA NOVICE DES FOSSES — la Sorciere des fosses (mini-boss de lvl_19) : elle
	# soigne encore (1,2 PV/s, la Sorciere 2,5), et n invoque plus.
	var novice := _enemy("pit_novice", "Novice des fosses", K.HEALER, 3, 30.0, 42.0, 5,
		S.STAR, Color(0.50, 0.72, 1.0), 30.0)
	novice.anim_key = &"unhallowed"
	novice.heal_per_second = 1.2
	novice.demoted_from = &"pit_witch"
	_resist(novice, {&"phys": 1.1, &"feu": 1.25, &"givre": 0.6, &"arcane": 1.05,
		&"poison": 0.7, &"foudre": 1.3})
	_save(novice, E + "pit_novice.tres")

	# LE CROQUE-MORT — le Fossoyeur (mini-boss de lvl_21) en petit : il releve
	# encore les morts, de plus pres (200 px au lieu de 300) et deux au plus.
	var mourner := _enemy("grave_mourner", "Croque-mort", K.NORMAL, 3, 34.0, 34.0, 5,
		S.SQUARE, Color(0.45, 0.45, 0.50), 30.0)
	mourner.anim_key = &"pawn_black"
	mourner.reanimate_radius = 200.0
	mourner.reanimate_max = 2
	mourner.demoted_from = &"gravedigger"
	_resist(mourner, {&"phys": 1.1, &"feu": 1.2, &"givre": 0.9, &"arcane": 1.1, &"poison": 0.6})
	_save(mourner, E + "grave_mourner.tres")

	# LE TOTEM FELE — le Totem ancien (mini-boss de lvl_20) fendu : son aura ne
	# couvre plus que 120 px. Celui qui protege reste celui qu on abat d abord.
	var cracked := _enemy("totem_cracked", "Totem fele", K.GUARDIAN, 3, 40.0, 30.0, 5,
		S.STAR, Color(0.60, 0.85, 0.55), 32.0)
	cracked.anim_key = &"totem_tower"
	cracked.aura_shield_radius = 120.0
	cracked.demoted_from = &"totem_elder"
	_resist(cracked, {&"phys": 0.7, &"feu": 1.2, &"arcane": 1.3, &"poison": 0, &"lent": 0.5})
	_save(cracked, E + "totem_cracked.tres")

	# L AIDE DU BOURREAU — le Bourreau (mini-boss de lvl_06) en petit : il ne
	# marche pas non plus, et son onde ne couvre que 220 px (3 degats).
	var aide := _enemy("executioner_aide", "Aide du Bourreau", K.NORMAL, 3, 40.0, 0.0, 5,
		S.SQUARE, Color(0.50, 0.30, 0.30), 32.0)
	aide.anim_key = &"executioner"
	aide.shockwave_interval = 5.0
	aide.shockwave_radius = 220.0
	aide.shockwave_damage = 3
	aide.demoted_from = &"executioner"
	_resist(aide, {&"phys": 0.7, &"feu": 0.9, &"arcane": 1.3, &"poison": 0.0, &"foudre": 1.25})
	_save(aide, E + "executioner_aide.tres")

	# --- ACTE 4 : les boss de l acte 1, trois actes plus tard, en ordinaires ---

	# LA REINE GORGONE RECOLLEE — « la Reine gorgone, recollee, en garde la porte »
	# (lvl_13). Brisee au village (acte 1), recollee : un seul regard (une carte),
	# 70 PV au lieu de 230.
	var mended := _enemy("gorgon_queen_mended", "Reine gorgone recollee", K.NORMAL, 4,
		70.0, 28.0, 7, S.DIAMOND, Color(0.75, 0.55, 0.85), 40.0)
	mended.anim_key = &"gorgon"
	mended.sprite_scale = 1.2
	mended.blocks_cards = 1
	mended.demoted_from = &"gorgon_queen"
	_resist(mended, {&"phys": 1.2, &"feu": 1.05, &"givre": 1.1, &"arcane": 0.8, &"poison": 0.5})
	_save(mended, E + "gorgon_queen_mended.tres")

	# --- ACTE 5 : les mini-boss de l acte 4, et un boss de l acte 2 -----------

	# LE NOYAU ERRANT — le Golem a noyau (mini-boss de lvl_07) en petit : sa
	# riposte ne fait plus que 3 degats, toutes les 2,5 s au plus.
	var drifter := _enemy("core_drifter", "Noyau errant", K.NORMAL, 3, 44.0, 28.0, 5,
		S.SQUARE, Color(0.55, 0.70, 0.85), 34.0)
	drifter.anim_key = &"mechagolem"
	drifter.laser_damage = 3
	drifter.laser_cooldown = 2.5
	drifter.demoted_from = &"mecha_golem"
	_resist(drifter, {&"phys": 0.65, &"feu": 0.9, &"arcane": 0.8, &"poison": 0.0,
		&"foudre": 1.35, &"lent": 0.5})
	_save(drifter, E + "core_drifter.tres")

	# LES JUMEAUX PALES — les Jumeaux du Cercle (mini-boss de lvl_12) en petit :
	# l un releve l autre UNE fois au lieu de deux.
	var pale := _enemy("twins_pale", "Jumeaux pales", K.NORMAL, 3, 30.0, 40.0, 4,
		S.TRIANGLE, Color(0.85, 0.70, 0.95), 30.0)
	pale.anim_key = &"demon"
	pale.swarm_count = 2
	pale.twin_group = &"twins_pale"
	pale.twin_max_returns = 1
	pale.twin_revive_hp_pct = 50.0
	pale.demoted_from = &"circle_twins"
	_resist(pale, {&"phys": 1.0, &"feu": 0.6, &"givre": 1.25, &"poison": 0.8, &"foudre": 1.1})
	_save(pale, E + "twins_pale.tres")

	# L ECHO DE L ENSEVELISSEUR — le boss de lvl_04 (acte 2), trois actes plus tard,
	# dans le siege vide : il appelle encore un Charognard, deux au plus.
	var grave_echo := _enemy("gravecaller_echo", "Echo de l Ensevelisseur", K.NORMAL, 4,
		70.0, 30.0, 7, S.STAR, Color(0.55, 0.85, 0.55), 40.0)
	grave_echo.anim_key = &"unhallowed"
	grave_echo.summon_def = load(E + "risen_ghoul.tres")
	grave_echo.summon_interval = 8.0
	grave_echo.summon_count = 1
	grave_echo.summon_max_alive = 2
	grave_echo.demoted_from = &"gravecaller"
	_resist(grave_echo, {&"phys": 0.9, &"feu": 1.2, &"givre": 0.8, &"arcane": 1.1, &"poison": 0})
	_save(grave_echo, E + "gravecaller_echo.tres")

	# --- LES BOSS DEVENUS MINI-BOSS, deux actes plus tard ----------------------

	# L ECHO DU RELIQUAIRE — le boss de lvl_03 (acte 2), mini-boss des fosses de
	# Sesh (acte 4) : trois coups ignores au lieu de six.
	var rel_echo := _enemy("reliquary_echo", "Echo du Reliquaire", K.MINIBOSS, 6,
		80.0, 32.0, 12, S.HEXAGON, Color(0.80, 0.78, 0.70), 60.0)
	rel_echo.anim_key = &"lancer_red"
	rel_echo.hits_immune = 3
	rel_echo.demoted_from = &"bone_reliquary"
	_resist(rel_echo, {&"phys": 0.85, &"feu": 1.25, &"givre": 0.9, &"arcane": 1.2, &"poison": 0})
	_save(rel_echo, E + "reliquary_echo.tres")

	# L ECHO DU GRAND OEIL — le boss de lvl_17 (acte 2), mini-boss de l arene de
	# Kaltek (acte 4) : la meme spirale, des tirs plus rares et plus faibles.
	var eye_echo := _enemy("great_eye_echo", "Echo du Grand Oeil", K.MINIBOSS, 6,
		100.0, 50.0, 12, S.CIRCLE, Color(0.55, 0.75, 0.95), 48.0)
	eye_echo.anim_key = &"flyingeye"
	eye_echo.sprite_scale = 1.3
	eye_echo.flying = true
	eye_echo.move_pattern = EnemyDef.MovePattern.SPIRAL
	eye_echo.pattern_width = 200.0
	eye_echo.shoot_interval = 4.0
	eye_echo.shot_damage = 3
	eye_echo.demoted_from = &"great_eye"
	_resist(eye_echo, {&"phys": 1.15, &"feu": 1.05, &"givre": 1.1, &"arcane": 0.9,
		&"poison": 0.35, &"foudre": 0.7})
	_save(eye_echo, E + "great_eye_echo.tres")

	# L ECHO DU MAGE NOIR — le boss de lvl_18 (acte 2), mini-boss du pentacle brise
	# (acte 4) : il tire et garde ses distances, il n appelle plus de pillards.
	var mage_echo := _enemy("dark_mage_echo", "Echo du Mage noir", K.MINIBOSS, 6,
		100.0, 42.0, 12, S.STAR, Color(0.45, 0.35, 0.75), 50.0)
	mage_echo.anim_key = &"evilwizard"
	mage_echo.keeps_distance_at = 380.0
	mage_echo.shoot_interval = 3.0
	mage_echo.shot_damage = 4
	mage_echo.demoted_from = &"dark_mage"
	_resist(mage_echo, {&"phys": 1.25, &"givre": 1.2, &"arcane": 0.65, &"poison": 0.85,
		&"foudre": 0.7})
	_save(mage_echo, E + "dark_mage_echo.tres")

	# L ECHO DU SCEAU — le boss de lvl_21 (acte 3, il ferme l acte), mini-boss du
	# siege vide (acte 5) : il campe toujours, son aura ne couvre plus que 200 px
	# et il n appelle qu un Squelette pareur a la fois, deux au plus.
	var seal_echo := _enemy("tombol_echo", "Echo du Sceau", K.MINIBOSS, 6,
		120.0, 0.0, 12, S.HEXAGON, Color(0.85, 0.25, 0.45), 60.0)
	seal_echo.anim_key = &"mageguardian"
	seal_echo.aura_shield_radius = 200.0
	seal_echo.summon_def = load(E + "parry_skeleton.tres")
	seal_echo.summon_interval = 8.0
	seal_echo.summon_count = 1
	seal_echo.summon_max_alive = 2
	seal_echo.demoted_from = &"tombol_seal"
	_resist(seal_echo, {&"phys": 0.65, &"feu": 0.9, &"givre": 0.95, &"arcane": 1.3,
		&"poison": 0.0, &"foudre": 1.25, &"lent": 0.0})
	_save(seal_echo, E + "tombol_echo.tres")

	# --- DEUX TETES NEUVES DE L ACTE 2 (aucune feuille neuve) -----------------

	# LA MERE PLANOGO — mini-boss de lvl_17 (« tout ce qui t y attend vole »). Un
	# grand Planogo qui en appelle d autres : 2 au plus, un toutes les 8 s. La
	# reponse : tuer la mere avant que le ciel se remplisse de boules de poison.
	var mother := _enemy("planogo_mother", "Mere Planogo", K.MINIBOSS, 6, 100.0, 50.0, 12,
		S.CIRCLE, Color(0.45, 0.90, 0.88), 48.0)
	mother.anim_key = &"flyer"
	mother.sprite_scale = 1.6
	mother.flying = true
	mother.summon_def = load(E + "wisp.tres")
	mother.summon_interval = 8.0
	mother.summon_count = 1
	mother.summon_max_alive = 2
	_resist(mother, {&"phys": 0.65, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.3, &"foudre": 1.2})
	_save(mother, E + "planogo_mother.tres")

	# LE CAPITAINE PILLARD — mini-boss de lvl_18 (« les Pillards n arrivent meme pas
	# par la ou tu regardes »). Il surgit du cote et appelle sa bande : un pillard
	# toutes les 6 s, 3 au plus.
	var captain := _enemy("raider_captain", "Capitaine pillard", K.MINIBOSS, 6, 110.0, 56.0, 12,
		S.TRIANGLE, Color(0.65, 0.75, 0.40), 46.0)
	captain.anim_key = &"goblin2"
	captain.sprite_scale = 1.5
	captain.entry_side = true
	captain.summon_def = load(E + "nacelle_raider.tres")
	captain.summon_interval = 6.0
	captain.summon_count = 1
	captain.summon_max_alive = 3
	_resist(captain, {&"phys": 0.85, &"feu": 1.25, &"givre": 1.2, &"poison": 0.55})
	_save(captain, E + "raider_captain.tres")


func _spec(key: String, magnitude: float, duration: float = 0.0,
		radius: float = 0.0, params: Dictionary = {}) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = StringName(key)
	s.magnitude = magnitude
	s.duration = duration
	s.radius = radius
	s.params = params
	return s


## L ELEMENT DE CHAQUE SORT (vague 8, demande du co-auteur) : « toutes les
## cartes doivent etre associees a un de ces elements ». UN element par carte,
## y compris pioche, temps et terrain, avec sa raison — c est la table de
## correspondance du chantier, a relire ici plutot que dans 50 appels a _card.
## `_card` la lit : une carte absente de la table rougit la generation
## (printerr) puis test_elements.
##
## Contrainte tenue en plus du sens : les objectifs « N sorts d arcane / de
## foudre / de glace / de feu » des niveaux 5, 6, 11, 15, 16, 19, 21 gardent le
## MEME ensemble de cartes comptees dans leur niveau (Precipitation et Flux de
## mana restent d arcane, la Clef de l Appel n y entre pas) : leurs taux mesures
## au banc des objectifs restent valables.
const ELEMENT_DES_SORTS: Dictionary = {
	# --- FEU : ce qui brule ---
	"ember_pool": [GameEnums.DamageTag.FIRE, "des braises"],
	"fireball": [GameEnums.DamageTag.FIRE, "une boule de feu"],
	"brazier": [GameEnums.DamageTag.FIRE, "un brasier"],
	"meteor": [GameEnums.DamageTag.FIRE, "une pierre en flammes ; l ancien « feu et physique » perd son second element"],
	"meteor_storm": [GameEnums.DamageTag.FIRE, "meme famille que le Meteore"],
	"forge_dial": [GameEnums.DamageTag.FIRE, "le cadran des FORGES, ses meteorites sont de feu"],
	# --- EAU : ce qui coule, revient, se renouvelle ---
	"tidal_pool": [GameEnums.DamageTag.WATER, "une nappe d eau et son courant (etait givre)"],
	"terrain_river": [GameEnums.DamageTag.WATER, "une riviere"],
	"tide_ledger": [GameEnums.DamageTag.WATER, "le registre des MAREES"],
	"cycle_of_thought": [GameEnums.DamageTag.WATER, "un cycle : la main se vide et se remplit comme une maree"],
	# --- NATURE : pierre, bois, ronce, racine, la terre qui appelle ---
	"stone_wall": [GameEnums.DamageTag.NATURE, "la pierre"],
	"bastion": [GameEnums.DamageTag.NATURE, "un dome de pierre (etait physique)"],
	"terrain_brambles": [GameEnums.DamageTag.NATURE, "des ronces (etait physique)"],
	"heartwood_totem": [GameEnums.DamageTag.NATURE, "un arbre de coeur-de-bois (etait physique)"],
	"blight_sapling": [GameEnums.DamageTag.NATURE, "un arbre qui fletrit : la plante d abord (etait poison)"],
	"terrain_pit": [GameEnums.DamageTag.NATURE, "une fosse creusee dans la terre"],
	"terrain_altar": [GameEnums.DamageTag.NATURE, "une pierre levee d ou la terre fait naitre des allies"],
	"summoners_key": [GameEnums.DamageTag.NATURE, "l Appel : des creatures sortent de la terre, comme a l Autel"],
	# --- VENT : ce qui souffle, pousse, aspire, porte ---
	"piercing_arrow": [GameEnums.DamageTag.WIND, "une fleche portee par le vent (etait physique)"],
	"chain_break": [GameEnums.DamageTag.WIND, "un souffle qui brise et repousse (etait physique)"],
	"repulsion_wave": [GameEnums.DamageTag.WIND, "une onde qui souffle (etait arcane et physique)"],
	"salt_spiral": [GameEnums.DamageTag.WIND, "un tourbillon qui aspire (etait arcane)"],
	"maelstrom": [GameEnums.DamageTag.WIND, "une spirale qui aspire (etait arcane)"],
	"about_face": [GameEnums.DamageTag.WIND, "une bourrasque qui retourne les monstres (etait arcane)"],
	# --- FOUDRE : l eclair, la secousse ---
	"spark": [GameEnums.DamageTag.LIGHTNING, "une etincelle"],
	"thunder_root": [GameEnums.DamageTag.LIGHTNING, "la racine du TONNERRE etourdit comme un eclair"],
	"reckless_bargain": [GameEnums.DamageTag.LIGHTNING, "un pacte qui electrise tout le terrain"],
	# --- GLACE : l ancien givre ---
	"frost_field": [GameEnums.DamageTag.ICE, "un champ de givre"],
	"frost_rain": [GameEnums.DamageTag.ICE, "une pluie de givre"],
	"deep_freeze": [GameEnums.DamageTag.ICE, "le gel"],
	"ice_wall": [GameEnums.DamageTag.ICE, "un mur de glace (chantier W9 : le premier OBJET de glace)"],
	# --- ARCANIQUE : la magie pure, le temps, l esprit du mage ---
	"arcane_bolt": [GameEnums.DamageTag.ARCANE, "un trait arcanique"],
	"arcane_insight": [GameEnums.DamageTag.ARCANE, "une intuition arcanique"],
	"focus": [GameEnums.DamageTag.ARCANE, "l esprit du mage se focalise"],
	"deep_focus": [GameEnums.DamageTag.ARCANE, "concentration : l esprit (etait sans element)"],
	"quickening": [GameEnums.DamageTag.ARCANE, "le temps s accelere : carte de temps"],
	"mana_flow": [GameEnums.DamageTag.ARCANE, "le mana"],
	"temporal_drag": [GameEnums.DamageTag.ARCANE, "le temps s alourdit : carte de temps (etait ralentissement seul)"],
	"hourglass_shard": [GameEnums.DamageTag.ARCANE, "un sablier : carte de temps"],
	"time_rift": [GameEnums.DamageTag.ARCANE, "une faille dans le temps"],
	"world_loom": [GameEnums.DamageTag.ARCANE, "le temps se retisse"],
	"twin_channeling": [GameEnums.DamageTag.ARCANE, "deux canaux de magie pure"],
	"echo_of_the_hand": [GameEnums.DamageTag.ARCANE, "un echo, magie de l esprit"],
	"purifying_light": [GameEnums.DamageTag.ARCANE, "une lumiere qui dissipe la magie"],
	"void_grip": [GameEnums.DamageTag.ARCANE, "le vide qui efface la magie"],
	"weakness_mark": [GameEnums.DamageTag.ARCANE, "une marque, un sceau"],
	"resonance": [GameEnums.DamageTag.ARCANE, "une resonance de magie pure"],
	"mirror_apprentice": [GameEnums.DamageTag.ARCANE, "un reflet magique du mage (etait invocation seule)"],
	# --- POISON : ce qui ronge, la mort, la pourriture ---
	"venom_mire": [GameEnums.DamageTag.POISON, "une mare de venin"],
	"bone_recall": [GameEnums.DamageTag.POISON, "les ossements : la mort et ce qui pourrit (etait sans element)"],
	"deck_purge": [GameEnums.DamageTag.POISON, "une purge : on rejette ce qui empoisonne le deck (etait sans element)"],
	"venom_dart": [GameEnums.DamageTag.POISON, "un dard venimeux (vague 8, demande du co-auteur)"],
	# Et une carte de temps de plus, comme la Precipitation :
	"time_surge": [GameEnums.DamageTag.ARCANE, "l elan du temps : la vitesse du mage (vague 8, demande du co-auteur)"],
	# --- Vague 10 (chantier B1a), les cinq sorts demandes par le co-auteur ---
	"south_wind": [GameEnums.DamageTag.WIND, "le vent du sud, qui souffle sur tout le terrain"],
	"electric_mark": [GameEnums.DamageTag.LIGHTNING, "une marque d eclair qui saute de mort en mort"],
	"heavy_rain": [GameEnums.DamageTag.WATER, "une pluie sur tout le terrain"],
	"quicksand": [GameEnums.DamageTag.NATURE, "le sable qui avale : la terre"],
	"water_jet": [GameEnums.DamageTag.WATER, "un jet d eau ; l eau, deja la commune de la pluie, garde le jet que le co-auteur lui donnait (le recul du vent a deja ses deux sorts, Rupture de chaine et Onde de repulsion)"],
}


func _card(id: String, dname: String, desc: String, rarity: GameEnums.Rarity,
		cast_time: float, targeting: GameEnums.Targeting,
		tags: Array[GameEnums.DamageTag], effects: Array[EffectSpec],
		copies: int = 0) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = dname
	c.description = desc
	c.rarity = rarity
	c.base_cast_time = cast_time
	c.targeting = targeting
	# Les tags ne portent plus que des MARQUEURS d effet (SLOW, SUMMON) : un
	# element ecrit dans la liste d un appel ne doit pas contredire la table.
	var marqueurs: Array[GameEnums.DamageTag] = []
	for t in tags:
		if not (int(t) in GameEnums.ELEMENTS):
			marqueurs.append(t)
	c.tags = marqueurs
	if ELEMENT_DES_SORTS.has(id):
		c.element = ELEMENT_DES_SORTS[id][0]
	else:
		printerr("sort sans element dans ELEMENT_DES_SORTS : ", id)
	c.effects = effects
	c.copies_in_starter = copies
	return c


## Chaque carte non passive porte SA feuille d effet (fx_key, unique : l AUDIT
## refuse un partage) et SON son (sfx_key, partage au plus entre 2-3 cartes d une
## meme famille). Les feuilles viennent du pack Effect and FX Pixel, extraites
## par tools/assets/extract_fxpack.py, deja teintees a l element du sort. Avant,
## l effet etait choisi par ELEMENT : tous les sorts de feu se ressemblaient, et
## l icone (derivee de la feuille) aussi.
##
## SONS (vague 10, dette de la phase A) : le chantier audio A4 avait donne a 28
## sorts un son de la famille de leur ELEMENT dans AudioBus.CARD_SFX, faute de
## pouvoir ecrire ici. Ces sons sont recopies dans les `sfx_key` ci-dessous et
## la table d AudioBus est videe : le son d un sort ne vit plus qu a un endroit.
## test_audio_w10 tient la regle (un son par element, deux sorts au plus).
##
## RARETES (vague 10, co-auteur : « il y a trop de rares » ; la campagne refaite
## demande environ une commune NOUVELLE par niveau, 21 niveaux). Huit communes
## avant ce chantier, cinq sorts neufs et la Lumiere purifiante demandes en
## commune : il en manquait sept. Passent en COMMUNE les rares les plus SIMPLES
## — un seul effet qui se lit sur la carte, ni objet permanent ni mecanique a
## apprendre — choisies pour que les communes couvrent les HUIT elements et les
## roles de base :
##   Mur de pierre (nature)      mur et bloque-projectiles, 20 s ;
##   Meteore (feu)               le gros coup lent, anti-blindage ;
##   Rupture de chaine (vent)    degats de zone et recul ; sa jumelle plus large
##                               et plus vive, l Onde de repulsion, reste rare ;
##   Spirale de sel (vent)       controle : rassemble (le Maelstrom epique fait
##                               la meme chose en plus grand) ;
##   Cycle de pensee (eau)       pioche ;
##   Precipitation (arcane)      rapidite d incantation ;
##   Rappel d ossements (poison) la main : le seul sort de poison simple apres le
##                               Dard (l Echo de la main, legendaire, garde deux
##                               sorts : la rarete se lit toujours dans le chiffre).
## Aucun chiffre n est reechelonne : chacun de ces sorts fait UNE chose, deja
## moins que sa version superieure (Onde de repulsion, Maelstrom, Echo de la
## main, Bastion), et une commune peut le porter. Le Meteore est le plus fort
## d entre eux, et c est aussi le plus LONG a lancer du jeu apres les
## legendaires (2,8 s de base) : il se paie en temps. Restent RARES les sorts a
## objet permanent (Mur de glace, Totem, Ronces), ceux qui changent la regle du
## temps ou de la main (Entrave temporelle, Elan du temps, Flux de mana,
## Focalisation, Volte-face), la Nappe montante (decision de la vague 8) et le
## Brasier, qui doublait le feu des communes : ils vont aux recompenses
## d objectif et aux quetes annexes.
func _cards() -> void:
	# --- Communes (deck de depart) ---
	var bolt := _card("arcane_bolt", "Trait arcanique",
		"Inflige 26 degats ARCANIQUES a une cible.", GameEnums.Rarity.COMMON, 1.1,
		GameEnums.Targeting.TARGET, [],
		[_spec("damage_single", 26.0)], 4)
	bolt.fx_key = &"orb_burst"
	bolt.sfx_key = &"spell_arcane"
	_save(bolt, "res://resources/cards/common/arcane_bolt.tres")

	var pierce := _card("piercing_arrow", "Fleche percante",
		"Traverse jusqu a 5 ennemis en ligne, 10 degats de VENT chacun.",
		GameEnums.Rarity.COMMON, 1.5, GameEnums.Targeting.DIRECTION,
		[],
		[_spec("pierce_line", 10.0, 0.0, 120.0, {&"max_targets": 5})], 3)
	pierce.fx_key = &"pin_thrust"
	pierce.sfx_key = &"wind_arrow"
	_save(pierce, "res://resources/cards/common/piercing_arrow.tres")

	var frost := _card("frost_field", "Champ de givre",
		"Zone qui inflige 1 degat de GLACE par seconde et ralentit de 50 pourcent "
		+ "pendant 5 s.", GameEnums.Rarity.COMMON, 0.6,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.SLOW],
		# Degats VOLONTAIREMENT minimes (1/s contre 8/s pour les Braises). Sans eux,
		# le givre n etait pas un element mais une simple etiquette : aucune carte
		# de degats ne le portait, donc « vulnerable au givre » etait une
		# recompense que le joueur ne pouvait jamais encaisser. Un point par
		# seconde suffit a rendre la resistance LISIBLE sans transformer une
		# carte de controle en carte de degats.
		[_spec("ground_zone", 1.0, 5.0, 180.0, {&"slow_pct": 50.0})], 3)
	frost.fx_key = &"rune_square"
	frost.sfx_key = &"drip_frost"
	_save(frost, "res://resources/cards/common/frost_field.tres")

	var ember := _card("ember_pool", "Braises",
		"Zone infligeant 8 degats de FEU par seconde pendant 4 s.", GameEnums.Rarity.COMMON, 1.7,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 8.0, 4.0, 160.0)], 2)
	ember.fx_key = &"ember_flames"
	ember.sfx_key = &"fire_swoosh"
	_save(ember, "res://resources/cards/common/ember_pool.tres")

	# LA DESCRIPTION DISAIT UN TOTAL, LE CODE LIT UN DEBIT.
	#
	# Pour la cle `ground_zone`, la magnitude est des degats PAR SECONDE :
	# `battlefield.gd` fait `_hit(e, z["dps"] * wd, ...)`. Sur 0,6 s, 26 par
	# seconde ne font donc que ~16 degats reels, alors que la carte annoncait
	# « Explosion de 26 degats ». Les six autres cartes de zone ecrivent bien
	# « par seconde » (voir `ember_pool` juste au-dessus) : la Boule de feu etait
	# la seule a annoncer un total sec, et c est une COMMUNE — l une des
	# premieres cartes que le joueur rencontre, donc celle sur laquelle il
	# apprend a evaluer ses sorts.
	#
	# ON CORRIGE LE TEXTE, PAS LE CHIFFRE. Porter la magnitude a 43 pour honorer
	# les 26 degats annonces aurait rendu la carte ~65 % plus forte dans les six
	# decks qui la portent : c est de l equilibrage, et le testeur l a
	# explicitement garde pour lui. Le texte, lui, peut dire la verite sans rien
	# deplacer. Si quelqu un veut ensuite faire de cette carte une vraie
	# explosion en coup unique, c est une decision d equilibrage a mesurer au
	# banc, pas une correction de libelle.
	var fireball := _card("fireball", "Boule de feu",
		"Zone infligeant 26 degats de FEU par seconde pendant 0.6 s.", GameEnums.Rarity.COMMON, 1.4,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 26.0, 0.6, 170.0)], 2)
	fireball.fx_key = &"fireball_hit"
	fireball.sfx_key = &"blast_short"
	_save(fireball, "res://resources/cards/common/fireball.tres")

	# --- Rares (Precipitation, Cycle de pensee, Mur de pierre : communes depuis
	# la vague 10, voir l en-tete) ---
	var haste := _card("quickening", "Precipitation",
		"Accelere l incantation de 60 pourcent pendant 6 s.", GameEnums.Rarity.COMMON, 0.8,
		GameEnums.Targeting.NONE, [],
		[_spec("self_haste", 60.0, 6.0)])
	haste.fx_key = &"ray_wheel"
	haste.sfx_key = &"spell_rise"
	_save(haste, "res://resources/cards/common/quickening.tres")

	var drag := _card("temporal_drag", "Entrave temporelle",
		"Ralentit tous les ennemis de 40 pourcent pendant 5 s.", GameEnums.Rarity.RARE, 1.4,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SLOW],
		[_spec("slow_enemy_gauge", 40.0, 5.0)])
	# L HORLOGE, sur le sort de temps le plus pur du jeu.
	#
	# `slow_enemy_gauge` passe par `screen_tint`, donc la feuille est etiree sur
	# 1400 px de large : c est LE plus gros effet du jeu, et il affichait jusqu ici
	# `midnight`, une grille de 100 px agrandie 25 fois. `timemagic` a des cases de
	# 192 px et tient l agrandissement — c est precisement la « grosse resolution »
	# que le testeur demandait pour les effets plein ecran.
	#
	# Pourquoi cette carte et pas une autre des cinq sorts de temps : l AUDIT
	# interdit de partager une feuille, il fallait donc choisir. Entrave temporelle
	# est la seule dont l effet est le ralentissement ET RIEN D AUTRE. Le Sablier et
	# le Metier du monde ralentissent aussi, mais melangent hate et double lancer :
	# l horloge y dirait la moitie du sort. Ici elle le dit en entier.
	drag.fx_key = &"timemagic"
	drag.sfx_key = &"time_slow"
	_save(drag, "res://resources/cards/rare/temporal_drag.tres")

	var cycle := _card("cycle_of_thought", "Cycle de pensee",
		"Defausse 2 cartes, en pioche 2.", GameEnums.Rarity.COMMON, 0.6,
		GameEnums.Targeting.NONE, [],
		[_spec("discard_draw", 0.0, 0.0, 0.0, {&"count": 2})])
	cycle.fx_key = &"cycle_swirl"
	cycle.sfx_key = &"water_drop"
	_save(cycle, "res://resources/cards/common/cycle_of_thought.tres")

	# Le cahier des charges promet une pioche "ameliorable" : voici la carte qui le fait.
	var flow := _card("mana_flow", "Flux de mana",
		"Pioche deux fois plus vite pendant 12 s.", GameEnums.Rarity.RARE, 0.8,
		GameEnums.Targeting.NONE, [],
		[_spec("draw_boost", 2.0, 12.0)])
	flow.fx_key = &"wisp_rise"
	flow.sfx_key = &"spell_rise"
	_save(flow, "res://resources/cards/rare/mana_flow.tres")

	var wall := _card("stone_wall", "Mur de pierre",
		"Mur de 20 s : les monstres le contournent et il arrete leurs projectiles.",
		GameEnums.Rarity.COMMON, 1.5, GameEnums.Targeting.POSITION, [],
		[_spec("build_wall", 0.0, 20.0, 200.0, {&"thickness": 60.0})])
	wall.fx_key = &"stone_peak"
	wall.sfx_key = &"stone_shove"
	_save(wall, "res://resources/cards/common/stone_wall.tres")

	# MUR DE GLACE (chantier W9) — l exemple du co-auteur sur les elements : « un mur
	# de GLACE subit moins de degats d un monstre faible a la glace ». La regle
	# existait (Battlefield.object_hit, EnemyDef.object_hit_factor) mais aucune carte
	# ne posait d objet de glace : tous les objets etaient de nature, la Riviere
	# d eau. Un mur qui ne prend pas de coups ne montre rien : celui-ci est CASSABLE
	# (des PV, comme le Bastion), donc les monstres qu il enferme le frappent, et
	# ceux qui craignent le froid le frappent moins fort (faible x2 -> coups x0,7).
	#
	# Chiffres tenus contre ses deux voisins de famille :
	#   Mur de pierre (rare) : 1,5 s, 200 px, 20 s, ni PV ni coups ;
	#   Bastion (epique)     : 2,0 s, 200 px, permanent, 120 PV ;
	#   Mur de glace (rare)  : 1,6 s, 180 px, permanent, 70 PV.
	# Rare comme le Mur de pierre, un peu plus long a lever ; il dure jusqu a ce
	# qu on le brise (la glace ne fond pas pendant un combat, c est le sort qui la
	# tient), mais il cede deux fois plus vite que le Bastion et barre moins large :
	# c est le Bastion du pauvre, pas son remplacant. Permanent, il n entre pas en
	# acte 1 (test_level_progression, cartes simples).
	var ice_wall := _card("ice_wall", "Mur de glace",
		"Mur de glace permanent de 70 PV : les monstres le contournent, et ceux qui craignent le froid le frappent moins fort.",
		GameEnums.Rarity.RARE, 1.6, GameEnums.Targeting.POSITION, [],
		[_spec("build_wall", 0.0, 0.0, 180.0,
			{&"thickness": 60.0, &"permanent": true, &"wall_hp": 70.0})])
	ice_wall.fx_key = &"freezing"
	ice_wall.sfx_key = &"ice_wall"
	_save(ice_wall, "res://resources/cards/rare/ice_wall.tres")

	# --- Epiques ---
	var ally := _card("mirror_apprentice", "Apprenti miroir",
		"Invoque un allie qui frappe pour 12 pendant 8 s.", GameEnums.Rarity.EPIC, 1.8,
		GameEnums.Targeting.NONE, [GameEnums.DamageTag.SUMMON],
		[_spec("summon_ally", 12.0, 8.0)])
	ally.fx_key = &"lotus_bloom"
	ally.sfx_key = &"whoosh_summon"
	_save(ally, "res://resources/cards/epic/mirror_apprentice.tres")

	# CONCENTRATION (vague 8) : le co-auteur la disait « ne fonctionne pas » —
	# defausser la main contre des secondes d incantation se lisait mal et vidait
	# la main au pire moment. Elle donne maintenant 1 XP de carte a chaque sort
	# de la main (cle `hand_card_xp`, RunState.grant_card_xp, la semantique de
	# MEDITER) : les sorts murissent plus tot, rien n est perdu. Ce n est pas un
	# lancer pour les objectifs.
	var focus := _card("deep_focus", "Concentration",
		"Chaque sort de ta main gagne 1 XP : ils murissent plus tot.",
		GameEnums.Rarity.EPIC, 0.7, GameEnums.Targeting.NONE, [],
		[_spec("hand_card_xp", 1.0)])
	focus.fx_key = &"hex_sigil"
	focus.sfx_key = &"charge_magic"
	_save(focus, "res://resources/cards/epic/deep_focus.tres")

	var bargain := _card("reckless_bargain", "Pacte imprudent",
		"Accelere les ennemis de 30 pourcent pendant 5 s, pioche 3 cartes.",
		GameEnums.Rarity.EPIC, 0.7, GameEnums.Targeting.NONE,
		# Aucun degat : l element n est ici qu une etiquette de FAMILLE, pour que
		# la carte s affiche avec la couleur de sa feuille d orage.
		[],
		[_spec("haste_enemies_boon", 30.0, 5.0, 0.0, {&"draw": 3})])
	bargain.fx_key = &"lightning_web"
	bargain.sfx_key = &"spell_crackle"
	_save(bargain, "res://resources/cards/epic/reckless_bargain.tres")

	# Vague 8 : le joueur CHOISIT les cartes (0, 1 ou 2) sur l ecran du deck ;
	# `count` est le plafond du choix (RunState.request_purge). Avant, les 2
	# cartes du dessus de la pioche partaient au hasard.
	var purge := _card("deck_purge", "Epuration",
		"Choisis jusqu a 2 cartes de ton deck : elles quittent la partie.",
		GameEnums.Rarity.EPIC, 1.0,
		GameEnums.Targeting.NONE, [],
		[_spec("remove_cards", 0.0, 0.0, 0.0, {&"count": 2})])
	# LE FANTOME QUI SE DISSOUT. La feuille part d une silhouette blanche nette et
	# la reduit en poussiere de pixels en six images. Epuration RETIRE deux cartes du
	# deck definitivement : c est une disparition, pas un eclat. `orb_shatter`
	# montrait une sphere qui se brise — une casse, donc un contresens pour une carte
	# qui efface.
	purge.fx_key = &"dark_vanish"
	purge.sfx_key = &"card_tear"
	_save(purge, "res://resources/cards/epic/deck_purge.tres")

	# --- Legendaire ---
	var rift := _card("time_rift", "Faille temporelle",
		"Reduit le cout des cartes de 1.5 s pendant 10 s et frappe en ligne.",
		GameEnums.Rarity.LEGENDARY, 2.0, GameEnums.Targeting.DIRECTION,
		[],
		[
			_spec("cost_reduction", 1.5, 10.0),
			_spec("pierce_line", 40.0, 0.0, 200.0, {&"max_targets": 99}),
		])
	rift.fx_key = &"orbit_cross"
	rift.sfx_key = &"time_rift"
	_save(rift, "res://resources/cards/legendary/time_rift.tres")

	# --- Variete : cast court/long, petite/grande zone, court/long effet ---
	# FOUDRE et non arcane : l Etincelle est un eclair, et ce nouvel element lui
	# donne enfin une raison d exister a cote du Trait arcanique, qui faisait la
	# meme chose avec le meme element pour deux fois plus de degats. Elle devient
	# le sort qui passe la ou l arcane est absorbee (Chevalier du vide).
	var spark := _card("spark", "Etincelle",
		"15 degats de FOUDRE sur une cible. Tres rapide a lancer.",
		GameEnums.Rarity.COMMON, 0.45,
		GameEnums.Targeting.TARGET, [],
		[_spec("damage_single", 15.0)], 2)
	spark.fx_key = &"spark_burst"
	spark.sfx_key = &"zap_spark"
	_save(spark, "res://resources/cards/common/spark.tres")

	var frost_rain := _card("frost_rain", "Pluie de givre",
		"Tres grande zone : 2 degats de GLACE par seconde et ralentissement de "
		+ "30 pourcent pendant 8 s.", GameEnums.Rarity.COMMON, 1.8,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 2.0, 8.0, 260.0, {&"slow_pct": 30.0})])
	frost_rain.fx_key = &"crystal_field"
	frost_rain.sfx_key = &"ice_chime"
	_save(frost_rain, "res://resources/cards/common/frost_rain.tres")

	var brazier := _card("brazier", "Brasier",
		"Zone de FEU : 14 degats par seconde pendant 6 s.", GameEnums.Rarity.RARE, 2.1,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 14.0, 6.0, 140.0)])
	brazier.fx_key = &"flame_pillar"
	brazier.sfx_key = &"fire_ignite"
	_save(brazier, "res://resources/cards/rare/brazier.tres")

	# COMMUNE depuis la vague 10 (voir l en-tete) : le gros coup lent.
	var meteor := _card("meteor", "Meteore",
		"Long a invoquer : 60 degats de FEU dans une petite zone.", GameEnums.Rarity.COMMON, 2.8,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 200.0, 0.3, 120.0)])
	meteor.fx_key = &"meteor_streak"
	meteor.sfx_key = &"blast_pop"
	_save(meteor, "res://resources/cards/common/meteor.tres")

	var about_face := _card("about_face", "Volte-face",
		"Tous les monstres font demi-tour pendant 3 s.", GameEnums.Rarity.RARE, 1.0,
		GameEnums.Targeting.NONE, [],
		[_spec("reverse_enemies", 0.0, 3.0)])
	about_face.fx_key = &"pinwheel_turn"
	about_face.sfx_key = &"whoosh_deep"
	_save(about_face, "res://resources/cards/rare/about_face.tres")

	var focalisation := _card("focus", "Focalisation",
		"Le prochain sort inflige le double de degats.", GameEnums.Rarity.RARE, 0.7,
		GameEnums.Targeting.NONE, [],
		[_spec("empower_next", 2.0)])
	focalisation.fx_key = &"star_focus"
	focalisation.sfx_key = &"spell_arcane"
	_save(focalisation, "res://resources/cards/rare/focus.tres")

	var deep_freeze := _card("deep_freeze", "Gel profond",
		"Zone qui ralentit de 85 pourcent et inflige 4 degats de GLACE par seconde "
		+ "pendant 4 s. Presque un arret.", GameEnums.Rarity.EPIC, 1.5,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 4.0, 4.0, 170.0, {&"slow_pct": 85.0})])
	deep_freeze.fx_key = &"frost_spikes"
	deep_freeze.sfx_key = &"ice_crack"
	_save(deep_freeze, "res://resources/cards/epic/deep_freeze.tres")

	# 8 s et non plus 6 (co-auteur, vague 8 : « duree un peu plus longue ») :
	# a la vitesse de depart, 6 s de monde laissaient a peine le temps d y poser
	# une seconde incantation depuis que les incantations sont plus longues.
	var weakness := _card("weakness_mark", "Marque de faiblesse",
		"Zone ou les monstres subissent le double de degats pendant 8 s.", GameEnums.Rarity.EPIC, 1.3,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 0.0, 8.0, 200.0, {&"vuln_mult": 2.0})])
	weakness.fx_key = &"diamond_mark"
	weakness.sfx_key = &"curse_mark"
	_save(weakness, "res://resources/cards/epic/weakness_mark.tres")

	var resonance := _card("resonance", "Resonance",
		"6 degats ARCANIQUES par monstre present dans la zone, a chacun d eux. Plus ils sont serres, plus ca frappe.",
		GameEnums.Rarity.EPIC, 1.7, GameEnums.Targeting.POSITION, [],
		[_spec("damage_per_enemy", 6.0, 0.0, 220.0)])
	resonance.fx_key = &"pulse_ring"
	resonance.sfx_key = &"spell_crackle"
	_save(resonance, "res://resources/cards/epic/resonance.tres")

	# --- Cartes d histoire : un monstre qui se rend apprend son sort au mage ---
	# Voir docs/histoire.md section 7. Chacune est placee dans le deck du niveau ou
	# elle se gagne, et chacune contre la famille du niveau SUIVANT : c est ce qui
	# fait que la progression narrative et la progression mecanique avancent ensemble.

	# Acte II / lvl_03 — enseignee par la Gelee liberee de l Ossuaire.
	# L Ossuaire envoie des nuees DISPERSEES : une zone seule y frappe un monstre a
	# la fois. Le vortex ne fait aucun degat, il rassemble pour qu un autre sort paie.
	# COMMUNE depuis la vague 10 (voir l en-tete).
	var salt := _card("salt_spiral", "Spirale de sel",
		"Aspire les monstres vers son centre pendant 3 s. Ne fait aucun degat : "
		+ "elle prepare le sort suivant.",
		GameEnums.Rarity.COMMON, 1.2, GameEnums.Targeting.POSITION,
		[],
		[_spec("vortex_pull", 150.0, 3.0, 220.0)])
	salt.fx_key = &"spiral_salt"
	salt.sfx_key = &"wind_swirl"
	_save(salt, "res://resources/cards/common/salt_spiral.tres")

	# Acte II / lvl_04 — enseignee par le Pretre goule repenti.
	# Le Grand Appel est le niveau le plus LONG : la penurie de cartes y tue plus que
	# les monstres. Garder ses deux prochains sorts, c est doubler sa main utile.
	# UN sort et non plus deux (co-auteur, vague 8) : a deux, la rare faisait le
	# travail de l Echo de la main, la legendaire du meme verbe.
	# COMMUNE depuis la vague 10 (voir l en-tete).
	var recall := _card("bone_recall", "Rappel d ossements",
		"Le prochain sort lance revient en main au lieu d etre defausse.",
		GameEnums.Rarity.COMMON, 0.9, GameEnums.Targeting.NONE, [],
		[_spec("retain_next", 1.0)])
	# L AME QUI S ENVOLE. La feuille montre un crane violet qui file en laissant une
	# trainee : une ame qu on rappelle. C est le verbe meme de la carte, qui fait
	# REVENIR les sorts en main au lieu de les laisser partir a la defausse.
	# Premiere des trois feuilles d OMBRE du jeu, et la carte vient de l Ossuaire :
	# l element colle au lieu autant qu a l effet.
	recall.fx_key = &"dark_soul"
	recall.sfx_key = &"bone_rattle"
	_save(recall, "res://resources/cards/common/bone_recall.tres")

	# Acte III / lvl_05 — enseignee par le Berserker libere.
	# Les Forges envoient du blindage lent. On ne le tue pas vite : on le REPOUSSE,
	# et le temps gagne vaut plus que les degats. D ou une magnitude modeste et un
	# recul important.
	# COMMUNE depuis la vague 10 (voir l en-tete) : plus petite et plus lente que
	# l Onde de repulsion (190 px et 1,4 s contre 220 px et 1,2 s), qui reste rare.
	var chain := _card("chain_break", "Rupture de chaine",
		"18 degats de VENT en zone, puis repousse violemment tout ce qui reste debout.",
		GameEnums.Rarity.COMMON, 1.4, GameEnums.Targeting.POSITION,
		[],
		[_spec("knockback", 18.0, 0.0, 190.0, {&"push": 260.0})])
	chain.fx_key = &"shatter_burst"
	chain.sfx_key = &"impact_heavy"
	_save(chain, "res://resources/cards/common/chain_break.tres")

	# Acte III / lvl_06 — enseignee par le Chevalier du vide qui se rend.
	# La Cour brisee empile les monstres A EFFETS : rage du Berserker, bouclier de
	# premier coup du Chevalier, aura d invulnerabilite du Gardien-totem. Sans
	# dissipation, ces trois-la se protegent mutuellement.
	# Zone volontairement petite (voir le handler) : large, elle effacerait aussi
	# les ralentissements du joueur.
	var void_grip := _card("void_grip", "Vide d emprise",
		"Efface rage, boucliers et auras des monstres d une petite zone.",
		GameEnums.Rarity.EPIC, 1.1, GameEnums.Targeting.POSITION,
		[],
		[_spec("dispel_zone", 0.0, 0.0, 150.0)])
	void_grip.fx_key = &"void_mandala"
	void_grip.sfx_key = &"void_pull"
	_save(void_grip, "res://resources/cards/epic/void_grip.tres")

	# --- Legendaires de campagne (une par niveau, voir docs/histoire.md) ---

	# lvl_03 : le registre des goules. Elles comptaient les ames ; le mage compte
	# les monstres. Piocher 3 d un coup repond au seul vrai probleme de l Ossuaire.
	# Incantation GRANDEMENT allongee (co-auteur, vague 8) : 1,6 -> 3,2 s de base.
	# Pioche de 3 ET double lancer pour une incantation de commune, c etait le
	# sort a lancer des qu il sortait ; il se merite maintenant.
	var ledger := _card("tide_ledger", "Registre des marees",
		"Pioche 3 cartes immediatement et lance deux sorts a la fois pendant 8 s.",
		GameEnums.Rarity.LEGENDARY, 3.2, GameEnums.Targeting.NONE, [],
		[
			_spec("draw_cards", 0.0, 0.0, 0.0, {&"count": 3}),
			_spec("double_cast", 0.0, 8.0),
		])
	ledger.fx_key = &"tide_waves"
	ledger.sfx_key = &"water_drop"
	_save(ledger, "res://resources/cards/legendary/tide_ledger.tres")

	# lvl_04 : la clef prise sur la porte du Grand Appel. Elle invoque a son tour.
	var key := _card("summoners_key", "Clef de l Appel",
		"Invoque deux allies frappant pour 14 pendant 10 s.",
		GameEnums.Rarity.LEGENDARY, 2.2, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.SUMMON],
		[
			_spec("summon_ally", 14.0, 10.0),
			_spec("summon_ally", 14.0, 10.0),
		])
	key.fx_key = &"hex_summon"
	key.sfx_key = &"whoosh_summon"
	_save(key, "res://resources/cards/legendary/summoners_key.tres")

	# lvl_05 / lvl_06 : le cadran vole aux forges. C est l outil des demons retourne
	# contre eux — une commande passee par le mage.
	var dial := _card("forge_dial", "Cadran des forges",
		"Pluie de meteorites sur toute l ile : 14 impacts sur 6 s.",
		GameEnums.Rarity.LEGENDARY, 2.4, GameEnums.Targeting.NONE,
		[],
		[_spec("meteor_storm", 30.0, 6.0, 110.0, {&"impacts": 14})])
	dial.fx_key = &"fire_bloom"
	dial.sfx_key = &"fire_forge"
	_save(dial, "res://resources/cards/legendary/forge_dial.tres")

	# lvl_07 : la machine elle-meme. Elle fait tout un peu, parce qu elle fait tout.
	var loom := _card("world_loom", "Metier du monde",
		"Le temps se retisse : ennemis ralentis de 50 pourcent, incantation doublee "
		+ "et deux sorts a la fois, pendant 8 s.",
		GameEnums.Rarity.LEGENDARY, 2.6, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.SLOW],
		[
			_spec("slow_enemy_gauge", 50.0, 8.0),
			_spec("self_haste", 100.0, 8.0),
			_spec("double_cast", 0.0, 8.0),
		])
	loom.fx_key = &"weave_bloom"
	loom.sfx_key = &"spell_grand"
	_save(loom, "res://resources/cards/legendary/world_loom.tres")

	var hourglass := _card("hourglass_shard", "Sablier fendu",
		"Le temps se fige pour eux et s emballe pour toi : ennemis -60 pourcent, "
		+ "incantation +100 pourcent, pendant 6 s.",
		GameEnums.Rarity.LEGENDARY, 2.1, GameEnums.Targeting.NONE,
		[GameEnums.DamageTag.SLOW],
		[
			_spec("slow_enemy_gauge", 60.0, 6.0),
			_spec("self_haste", 100.0, 6.0),
		])
	hourglass.fx_key = &"glass_shards"
	hourglass.sfx_key = &"spell_grand"
	_save(hourglass, "res://resources/cards/legendary/hourglass_shard.tres")

	# --- Sorts demandes par le testeur ---
	# Repousser, aspirer, dissiper, piocher, batir : cinq verbes qui manquaient.
	# Aucun ne fait de gros degats : ils achetent de la PLACE et du TEMPS, ce qui
	# etait le seul levier absent d un jeu ou tout se jouait sur les PV.

	# Le souffle ne tue pas : il rend au joueur la distance qu il a perdue quand
	# une vague arrive trop bas. D ou des degats modestes et une grosse poussee.
	var repulsion := _card("repulsion_wave", "Onde de repulsion",
		"Souffle une zone : 18 degats de VENT et les monstres sont violemment repousses.",
		GameEnums.Rarity.RARE, 1.2, GameEnums.Targeting.POSITION,
		[],
		[_spec("knockback", 18.0, 0.0, 220.0, {&"push": 260.0})])
	repulsion.fx_key = &"ring_expand"
	repulsion.sfx_key = &"air_burst"
	_save(repulsion, "res://resources/cards/rare/repulsion_wave.tres")

	# Le vortex ne fait AUCUN degat : c est une carte de mise en place. Elle vaut
	# une epique parce qu elle transforme n importe quelle zone en sort massif.
	var maelstrom := _card("maelstrom", "Maelstrom",
		"Spirale qui aspire les monstres vers son centre pendant 4 s. Aucun degat, "
		+ "mais tout ce qui tombe dedans est regroupe.",
		GameEnums.Rarity.EPIC, 1.6, GameEnums.Targeting.POSITION,
		[],
		[_spec("vortex_pull", 260.0, 4.0, 420.0)])
	maelstrom.fx_key = &"spiral_pull"
	maelstrom.sfx_key = &"wind_gust"
	_save(maelstrom, "res://resources/cards/epic/maelstrom.tres")

	# Zone volontairement PETITE : une dissipation large annulerait aussi les
	# ralentissements poses par le joueur et se retournerait contre lui.
	# VAGUE 10 (co-auteur) : COMMUNE, et 1,3 s d incantation de base au lieu de
	# 1,0. La dissipation devient une reponse de base, presente des le premier
	# acte contre les auras et les boucliers ; plus longue a lancer, elle se
	# prepare au lieu de partir en reflexe. Le Vide d emprise (epique) garde la
	# version vive (1,1 s), qui efface aussi rage et auras.
	var purify := _card("purifying_light", "Lumiere purifiante",
		"Petite zone : les monstres perdent rage, boucliers et effets en cours.",
		GameEnums.Rarity.COMMON, 1.3, GameEnums.Targeting.POSITION,
		[],
		[_spec("dispel_zone", 0.0, 0.0, 150.0)])
	# LA COLONNE DE LUMIERE, sur la carte qui s appelle Lumiere purifiante.
	# Cases de 192 px, et une forme VERTICALE qui tombe du ciel sur un point precis :
	# c est la lecture exacte d une dissipation ponctuelle. `halo_ring` etait un
	# anneau de 64 px, invisible au milieu du cercle de portee.
	purify.fx_key = &"lightpillar"
	purify.sfx_key = &"ward_light"
	_save(purify, "res://resources/cards/common/purifying_light.tres")

	# Piocher SANS defausser : Cycle de pensee echange, celle-ci ajoute. Cast tres
	# court, car son interet est de sortir d une main vide au pire moment.
	# Vague 8 (co-auteur) : EPIQUE, et 2 cartes au lieu de 3. Elle quitte donc les
	# cartes nouvelles de l acte 1 (lvl_02), qui n offre que communes et rares.
	var insight := _card("arcane_insight", "Intuition arcanique",
		"Pioche 2 cartes immediatement. Rien n est defausse.",
		GameEnums.Rarity.EPIC, 0.5, GameEnums.Targeting.NONE,
		[],
		[_spec("draw_cards", 0.0, 0.0, 0.0, {&"count": 2})])
	insight.fx_key = &"sun_burst"
	insight.sfx_key = &"spell_deep"
	_save(insight, "res://resources/cards/epic/arcane_insight.tres")

	# Mur PERMANENT : il ne compte pas les secondes, il compte les coups. Il
	# redessine le terrain pour toute la vague, et les monstres enfermes le
	# cassent — sinon la carte figerait la partie.
	var bastion := _card("bastion", "Bastion",
		"Mur permanent de 120 PV. Il ne disparait pas : les monstres doivent le briser.",
		GameEnums.Rarity.EPIC, 2.0, GameEnums.Targeting.POSITION,
		[],
		[_spec("build_wall", 0.0, 0.0, 200.0,
			{&"thickness": 60.0, &"permanent": true, &"wall_hp": 120.0})])
	bastion.fx_key = &"dome_bastion"
	bastion.sfx_key = &"stone_heavy"
	_save(bastion, "res://resources/cards/epic/bastion.tres")

	# --- Legendaires ---

	# Garder une carte, c est pouvoir rejouer sa meilleure carte deux fois. On en
	# garde DEUX et le cast est court : la legendaire doit changer le tour, pas
	# couter le tour.
	var echo := _card("echo_of_the_hand", "Echo de la main",
		"Les 2 prochaines cartes que tu joues reviennent en main au lieu de partir.",
		GameEnums.Rarity.LEGENDARY, 1.2, GameEnums.Targeting.NONE,
		[],
		[_spec("retain_next", 2.0)])
	echo.fx_key = &"echo_rings"
	echo.sfx_key = &"ward_deep"
	_save(echo, "res://resources/cards/legendary/echo_of_the_hand.tres")

	# Deux sorts a la fois change la FACON de jouer, pas la quantite de degats :
	# c est exactement ce qu on attend d une legendaire.
	var twin := _card("twin_channeling", "Canalisation jumelle",
		"Pendant 10 s, tu peux charger deux sorts en meme temps.",
		GameEnums.Rarity.LEGENDARY, 2.0, GameEnums.Targeting.NONE,
		[],
		[_spec("double_cast", 0.0, 10.0)])
	twin.fx_key = &"twin_flames"
	twin.sfx_key = &"charge_magic"
	_save(twin, "res://resources/cards/legendary/twin_channeling.tres")

	# Pluie sur TOUTE la carte : 16 impacts etales sur 5 s. Aucun ciblage — c est
	# le sort qu on lance quand on a deja perdu le controle du terrain.
	# Incantation GRANDEMENT allongee (co-auteur, vague 8) : 2,6 -> 4,4 s de base,
	# la plus longue du jeu. 18 x 70 degats sur tout le terrain nettoyait une
	# vague entiere pour le prix d un Meteore.
	var storm := _card("meteor_storm", "Pluie de meteorites",
		"18 meteores s abattent sur tout le terrain pendant 5 s, "
		+ "70 degats chacun.",
		GameEnums.Rarity.LEGENDARY, 4.4, GameEnums.Targeting.NONE,
		[],
		[_spec("meteor_storm", 70.0, 5.0, 290.0, {&"impacts": 18})])
	storm.fx_key = &"magma_burst"
	storm.sfx_key = &"blast_long"
	_save(storm, "res://resources/cards/legendary/meteor_storm.tres")

	# Enorme et TRES longue : elle ne nettoie pas une vague, elle interdit un
	# couloir pendant presque toute la vague suivante. Degats par seconde faibles
	# expres — c est la duree qui coute cher, pas la puissance.
	var venom := _card("venom_mire", "Mare de venin",
		"Enorme mare empoisonnee : 10 degats de POISON par seconde pendant 20 s, "
		+ "et les monstres y avancent 25 pourcent moins vite.",
		GameEnums.Rarity.LEGENDARY, 2.8, GameEnums.Targeting.POSITION,
		# Elle etait marquee FEU, ce qui etait un contresens : une mare de venin
		# ne brule pas. Passee en POISON, elle devient la reponse au Glouton (qui
		# gobe tout, y compris le venin) et reste inutile contre les morts-vivants
		# — exactement le genre d arbitrage que les resistances doivent creer.
		[GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 10.0, 20.0, 340.0, {&"slow_pct": 25.0})])
	# LES SPECTRES QUI MONTENT DU SOL. Quinze images de silhouettes sombres qui
	# s elevent d un nuage : jouee en BOUCLE au centre d une mare qui dure 20 s,
	# c est une zone qui respire au lieu d une image figee. La feuille est sombre et
	# la mare est un poison de mort-vivant : la teinte du pack sert le sort sans
	# qu on ait a la forcer.
	venom.fx_key = &"dark_swirl"
	venom.sfx_key = &"poison_bubble"
	_save(venom, "res://resources/cards/legendary/venom_mire.tres")


	# --- Sorts de TERRAIN (chantier H) ---
	#
	# Demande du testeur : « Arbre qui attire les ennemis ; sort de stun ; arbre a
	# zone de poison ; eau qui ralentit ». Quatre sorts qui POSENT quelque chose
	# sur le terrain au lieu de retirer des PV. Le jeu n en avait qu un, le Mur de
	# pierre, et il ne savait faire qu une chose : barrer un passage.
	#
	# Aucun des quatre n est une carte de degats. Ils repondent tous a la meme
	# question — « ils arrivent trop bas » — mais par quatre chemins qui ne se
	# remplacent pas : detourner, empoisonner sur pied, arreter net, faire reculer.

	# L ARBRE QUI ATTIRE. C est une provocation, donc un achat de temps : les
	# monstres a portee marchent sur l arbre au lieu de descendre et le tapent
	# jusqu a l abattre.
	#
	# PERMANENT tant qu il n est pas abattu (duree 0 = jusqu a la fin du combat),
	# et c est le SEUL arbre du jeu qui reste destructible par les monstres : un
	# appat eternel ET invulnerable tiendrait la vague loin du mage pour toujours.
	#
	# 3500 PV, MESURES et non devines. Sonde sur les 204 vagues normales des
	# niveaux 3 a 21 : une vague entiere au pied de l arbre frappe a ~670 PV/s
	# (mediane), ~1000 au 9e decile, ~1500 pour la pire. L ancien totem de 90 PV
	# tombait donc en 0,13 s — le testeur disait « il meurt en 1 s », c etait
	# encore genereux. A 3500 il tient ~5 s monde contre une vague mediane
	# (~3,5 s reelles a la vitesse de depart), ~2,3 s contre la pire : plusieurs
	# secondes pour poser deux sorts sur le paquet qu il a rassemble, jamais une
	# forteresse. La regle est verrouillee par test_terrain.gd contre
	# GameConfig.TERRAIN_TAUNT_MIN_HOLD / MAX_HOLD, pas contre ce nombre.
	#
	# Portee de 460 px : moins de la moitie de la largeur du terrain. Un arbre qui
	# provoquerait tout l ecran serait un bouton « plus personne n avance ».
	#
	# VAGUE 8 : 800 PV « pour voir » (co-auteur, 02/10). C est un ESSAI de design
	# et non une mesure : contre la vague mediane il tombe en un peu plus d une
	# seconde de monde. GameConfig.TERRAIN_TAUNT_MIN_HOLD a ete abaisse en
	# consequence ; si l essai est abandonne, revenir a 3500 et a 4 s.
	var totem := _card("heartwood_totem", "Totem de coeur-de-bois",
		"Plante un arbre de 800 PV qui reste jusqu a ce qu on l abatte. Les "
		+ "monstres a portee le prennent pour cible au lieu du mage et s acharnent "
		+ "dessus : une vague entiere le fait tomber vite.",
		GameEnums.Rarity.RARE, 1.6, GameEnums.Targeting.POSITION,
		[],
		[_spec("taunt_prop", 0.0, 0.0, 460.0,
			{&"prop_hp": 800.0, &"kind": "tree"})])
	totem.fx_key = &"spirit_gold"
	totem.sfx_key = &"wood_knock"
	_save(totem, "res://resources/cards/rare/heartwood_totem.tres")

	# L ARBRE A ZONE DE POISON. Meme verbe, deux parametres de plus : il porte une
	# mare qui vit et meurt AVEC lui. Abattre l arbre coupe le poison, ce qui donne
	# aux monstres une vraie raison de s en prendre a lui — et au joueur une raison
	# de le planter la ou ils ne l atteindront pas tout de suite.
	#
	# Element POISON : il subit donc la table de resistances du bestiaire. Les
	# morts-vivants (Pretre goule, Releve, Appeleur, Seigneur Spectre) y sont
	# immunises, les golems et totems aussi. C est voulu : c est l arbitrage que les
	# resistances existent pour creer, et la carte annonce sa faiblesse dans son
	# element.
	#
	# PERMANENT, et il n ATTIRE PLUS. Decision prise avec le co-auteur : un appat
	# qui ne partirait jamais tiendrait les monstres loin du mage pour toujours, et
	# sa mare les y empoisonnerait sans fin — la carte gagnerait la partie seule.
	# Il reste donc une mare de poison fixe, que la vague traverse au lieu de venir
	# s y placer. Cle `place_terrain` et non `taunt_prop` : la carte ne DIT plus
	# qu elle attire.
	#
	# Toujours destructible : un monstre qui passe au pied du tronc le frappe. 120
	# PV, parce qu il n attire plus personne — seuls ceux dont le couloir passe
	# dessus le cognent, et le joueur choisit ou le planter pour les eviter. Le
	# plafond de GameConfig.TERRAIN_PERMANENT_MAX borne le reste.
	var sapling := _card("blight_sapling", "Semis de fletrissure",
		"Plante un arbre empoisonne de 120 PV qui reste jusqu a la fin du combat : "
		+ "il repand 9 degats de POISON par seconde autour de lui. Il n attire pas "
		+ "les monstres, mais ceux qui passent a son pied le frappent.",
		GameEnums.Rarity.EPIC, 1.9, GameEnums.Targeting.POSITION,
		[],
		# Rayon 300 et non plus 230 (co-auteur, vague 8 : « zone plus grande ») :
		# a 230 un couloir sur deux longeait la mare sans y entrer.
		[_spec("place_terrain", 9.0, 0.0, 300.0,
			{&"prop_hp": 120.0, &"kind": "tree"})])
	sapling.fx_key = &"spirit_violet"
	# Un bois qui craque (sons de la vague 10, famille de la NATURE) : un arbre
	# qui perce le sol. Un son reste partage par deux sorts au plus — c est ce
	# qui evite que tous les sorts s entendent pareil.
	sapling.sfx_key = &"wood_creak"
	_save(sapling, "res://resources/cards/epic/blight_sapling.tres")

	# LE STUN. Immobiliser est la chose la plus forte qu on puisse faire dans un jeu
	# en temps reel : la carte est donc chere et breve.
	#
	# 1,1 s d arret pour 1,9 s d incantation : le rapport est verrouille par un test
	# (l etourdissement dure moins que l incantation qui le relance). Deux
	# exemplaires en main ne peuvent donc pas figer la partie — il reste toujours un
	# trou entre deux stuns, et le rapport tient a toutes les vitesses puisque la
	# jauge divise les deux termes.
	#
	# Zone de 200 px, plus petite que la Pluie de givre : elle attrape un groupe
	# serre, jamais la vague entiere.
	#
	# FOUDRE, et les monstres resistants au ralentissement (Golem, Behemoth, Colosse
	# des forges, Chronos) y echappent completement : c est le point que le brief
	# soulevait — un stun qui ignorerait cette immunite la viderait de son sens. Le
	# poids lourd garde donc une seule reponse : le tuer.
	var thunder := _card("thunder_root", "Racine de tonnerre",
		"Etourdit 1,1 s les monstres d une petite zone : vitesse nulle, ils ne "
		+ "tirent ni ne frappent. 14 degats de FOUDRE au passage. Sans effet sur "
		+ "ce qui resiste au ralentissement.",
		GameEnums.Rarity.EPIC, 1.9, GameEnums.Targeting.POSITION,
		[],
		[_spec("stun_zone", 14.0, 1.1, 200.0)])
	thunder.fx_key = &"lightning_fork"
	thunder.sfx_key = &"zap_short"
	_save(thunder, "res://resources/cards/epic/thunder_root.tres")

	# L EAU QUI RALENTIT — et la question que le brief posait : en quoi differe-t-elle
	# du Champ de givre ?
	#
	# Le givre est un FACTEUR de vitesse : il tend vers zero sans jamais renverser la
	# marche, un monstre gele avance toujours, juste moins vite. L eau est un
	# COURANT : elle s ajoute au deplacement avec le signe oppose, donc dans la nappe
	# le monstre RECULE. Le joueur ne gagne plus du temps, il regagne du terrain, et
	# c est la seule carte du jeu qui le fasse sur la duree — l Onde de repulsion
	# pousse une fois puis s arrete.
	#
	# 45 px/s de remontee contre les ~31 px/s d un gnome a x1 (60 x
	# ENEMY_SPEED_SCALE) : les petits monstres reculent vraiment, les gros freinent
	# sans repartir en arriere. La resistance au ralentissement s applique au
	# courant, donc le Golem la traverse comme si de rien n etait.
	#
	# AUCUN degat, expres : avec des degats elle serait strictement meilleure que le
	# Champ de givre, qui n aurait plus aucune raison d exister.
	# VAGUE 8 (co-auteur) : RARE et plus longue a lancer (1,3 -> 2,0 s de base).
	# Faire reculer toute une vague est plus fort que de la ralentir : commune et
	# rapide, elle rendait le Champ de givre inutile la ou elle etait.
	var tide := _card("tidal_pool", "Nappe montante",
		"Tres large nappe d eau pendant 7 s : le courant fait RECULER les monstres "
		+ "au lieu de les ralentir. Aucun degat.",
		GameEnums.Rarity.RARE, 2.0, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.SLOW],
		[_spec("water_flood", 45.0, 7.0, 300.0)])
	tide.fx_key = &"orb_cyan"
	tide.sfx_key = &"water_splash"
	_save(tide, "res://resources/cards/rare/tidal_pool.tres")

	# --- SORTS DEMANDES PAR LE CO-AUTEUR (vague 8) ---

	# LE DARD VENIMEUX : « un sort commun de poison mono-cible qui fait perdre
	# 2 PV par seconde au monstre jusqu a sa mort ». Le poison est PORTE par le
	# monstre (cle `poison_dot`, voir EffectHandlers.PoisonDot) : il le suit, se
	# voit au-dessus de lui (le crane vert de sa feuille) et ne s arrete qu a sa
	# mort. 2 PV/s de MONDE : la vitesse du mage l accelere comme le reste. C est
	# le sort des monstres qui durent (boss, colosses) ; deux dards s additionnent.
	# Incantation courte (0,7 s de base) : c est une commune qu on pose en passant.
	# POISON : les morts-vivants y sont immunises, la carte le dit par son element.
	var dart := _card("venom_dart", "Dard venimeux",
		"Empoisonne une cible : elle perd 2 PV de POISON par seconde jusqu a sa "
		+ "mort. Deux dards s additionnent.",
		GameEnums.Rarity.COMMON, 0.7, GameEnums.Targeting.TARGET, [],
		[_spec("poison_dot", 2.0)])
	dart.fx_key = &"skull_burst"
	# Un dard qui siffle (sons de la vague 10, famille du POISON).
	dart.sfx_key = &"poison_dart"
	_save(dart, "res://resources/cards/common/venom_dart.tres")

	# L ELAN DU TEMPS : « une carte qui augmente la vitesse du jeu ». La vitesse
	# du mage est sa vie ET l horloge du monde : +30 points d un coup (cle
	# `gain_speed`, le soin de SpeedGauge). 30 points = 15 s de montee naturelle
	# (GameConfig.SPEED_RISE_PER_SECOND), un peu plus qu un coup de monstre de
	# puissance 3. ARCANIQUE : c est une carte de temps, comme la Precipitation.
	# RARE : un soin est aussi une arme (incantations plus courtes, XP, passifs),
	# mais les monstres accelerent avec le mage — c est un pari, pas un bouclier.
	# Incantation moyenne (1,2 s de base) : elle se lance entre deux vagues ou
	# derriere un mur, pas au contact.
	var surge := _card("time_surge", "Elan du temps",
		"Rend 30 points de vitesse au mage. Le monde accelere avec lui.",
		GameEnums.Rarity.RARE, 1.2, GameEnums.Targeting.NONE, [],
		[_spec("gain_speed", 30.0)])
	surge.fx_key = &"orb_gold"
	surge.sfx_key = &"time_haste"
	_save(surge, "res://resources/cards/rare/time_surge.tres")

	# --- SORTS DE TERRAIN PERMANENTS ---
	#
	# Demande du co-auteur : des sorts PHYSIQUES qui modifient le terrain et
	# RESTENT toute la bataille, pour trois usages — changer le chemin des
	# monstres, les affaiblir, poser des generateurs d allies. Tous ont une duree
	# de 0 : « jusqu a la fin du combat » (voir TerrainProp.time_left). Leur
	# nombre est borne par GameConfig.TERRAIN_PERMANENT_MAX, le plus ancien etant
	# remplace : c est ce qui garde le Massacre (20 vagues et plus) jouable.
	#
	# Aucun n est range dans un deck de campagne : ils arrivent par les montees de
	# niveau et le Massacre. Les decks de campagne sont tenus par la regle des
	# six cartes differentes, ajoutee en parallele par un autre chantier.

	# LA RIVIERE. Le seul sort qui change le CHEMIN pour toute la bataille : une
	# ligne d eau sur toute la largeur, un seul pont tire au hasard. Les monstres
	# au sol font le detour par le pont, les volants et projectiles passent
	# au-dessus. Legendaire et LONGUE a lancer (2,6 s, dans le haut de la
	# hierarchie qui va de 0,45 a 2,8 s) : elle transforme la carte entiere.
	#
	# Aucun degat, aucun ralentissement : elle rassemble. Tout le paquet passe par
	# une seule case, et c est la que le joueur pose ses zones.
	var river := _card("terrain_river", "Riviere",
		"Fait couler une riviere sur toute la largeur du terrain, a la hauteur visee, "
		+ "jusqu a la fin du combat. Les monstres au sol doivent passer par son "
		+ "unique pont ; les volants et les projectiles passent au-dessus.",
		GameEnums.Rarity.LEGENDARY, 2.6, GameEnums.Targeting.POSITION,
		[],
		[_spec("terrain_river", 0.0, 0.0, 0.0)])
	river.fx_key = &"portal_blue"
	river.sfx_key = &"water_flow"
	_save(river, "res://resources/cards/legendary/terrain_river.tres")

	# LE GENERATEUR. Un autel qui fait naitre un allie toutes les 6 s, a cote de
	# lui. L allie est celui de l Apprenti miroir (meme mecanique, `spawn_ally`),
	# plus faible (8 par coup, 5 s de vie) : l autel en fait naitre sans fin.
	#
	# Destructible (140 PV) et il attire un peu (220 px) : sans cela, pose dans un
	# coin loin du passage, il invoquerait pour toujours et vaudrait une infinite
	# de sorts en Massacre. La petite provocation garantit qu une vague qui passe
	# a cote vient le casser.
	var altar := _card("terrain_altar", "Autel d appel",
		"Erige un autel de 140 PV qui reste jusqu a ce qu on l abatte. Toutes les "
		+ "6 s, il fait naitre un allie qui frappe pour 8 pendant 5 s. Les monstres "
		+ "qui passent pres de lui viennent le briser.",
		GameEnums.Rarity.EPIC, 2.2, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.SUMMON],
		[_spec("place_terrain", 0.0, 0.0, 0.0,
			{&"kind": "altar", &"prop_hp": 140.0, &"taunt_radius": 220.0,
				&"summon_every": 6.0, &"ally_damage": 8.0, &"ally_duration": 5.0})])
	altar.fx_key = &"portal_violet"
	altar.sfx_key = &"altar_hum"
	_save(altar, "res://resources/cards/epic/terrain_altar.tres")

	# LES RONCES. Un ralentissement qui ne s en va pas, et un peu de degats
	# PHYSIQUES pour que la resistance du bestiaire ait prise dessus. Plus faible
	# que le Champ de givre (35 % contre 50 %) : le givre achete beaucoup pendant
	# 5 s, les ronces un peu pendant tout le combat. Indestructibles (on ne frappe
	# pas un buisson d epines) : seul le plafond les remplace.
	var brambles := _card("terrain_brambles", "Ronces",
		"Fait pousser des ronces qui restent jusqu a la fin du combat : elles "
		+ "ralentissent de 35 pourcent et infligent 2 degats de NATURE par seconde.",
		GameEnums.Rarity.RARE, 1.4, GameEnums.Targeting.POSITION,
		[GameEnums.DamageTag.SLOW],
		[_spec("place_terrain", 2.0, 0.0, 170.0,
			{&"kind": "bramble", &"slow_pct": 35.0})])
	brambles.fx_key = &"slash_arc"
	brambles.sfx_key = &"bramble_rustle"
	_save(brambles, "res://resources/cards/rare/terrain_brambles.tres")

	# LA FOSSE. Une Marque de faiblesse qui ne s efface pas, en plus petit et en
	# moins fort (x1,3 contre la marque). Elle ne fait rien seule : elle designe
	# l endroit ou les autres sorts doivent tomber, ce qui se combine avec la
	# Riviere — une fosse au debouche du pont.
	var pit := _card("terrain_pit", "Fosse",
		"Creuse une fosse qui reste jusqu a la fin du combat : les monstres qui s y "
		+ "trouvent subissent 30 pourcent de degats en plus.",
		GameEnums.Rarity.EPIC, 1.7, GameEnums.Targeting.POSITION,
		[],
		[_spec("place_terrain", 0.0, 0.0, 150.0,
			{&"kind": "pit", &"vuln_mult": 1.3})])
	pit.fx_key = &"orb_magenta"
	pit.sfx_key = &"earth_dig"
	_save(pit, "res://resources/cards/epic/terrain_pit.tres")

	_cartes_vague_10()


## LES CINQ SORTS DEMANDES PAR LE CO-AUTEUR (vague 10, chantier B1a), tous
## COMMUNS : la campagne refaite donne une commune nouvelle par niveau. Ils
## composent les cles posees par le chantier A1 (handlers.gd, section VAGUE 10)
## et rien d autre. Les incantations ecrites sont les temps du co-auteur, en
## BASE : elles passent par GameConfig.CAST_TIME_SCALE comme toutes les autres.
## Les chiffres sont penses a x4, la ou un sort tourne le plus vite (une
## incantation de 3 s y part en 1,3 s).
func _cartes_vague_10() -> void:
	var T := GameEnums.Targeting

	# LE VENT DU SUD : « agit sur tout le terrain 6 s ; force les monstres rapides
	# a une vitesse normale, les deplacements etranges en ligne droite,
	# IMMOBILISE les volants ; incantation 3 s ». Aucun degat : c est le sort qui
	# REND LISIBLE une vague trop vive ou trop erratique (lutins fileurs, oiseaux
	# mirage, serpents, sauterelles, oeils en spirale) et qui cloue les volants
	# le temps d une zone. Chaque monstre le subit selon sa resistance au VENT
	# (une enclume immunisee n est pas touchee). Deux vents ne s empilent pas, le
	# second prolonge le premier (Battlefield.w10_apply_wind) : a x4, 6 s de
	# monde ne couvrent que 1,5 s reelle pour 1,3 s d incantation, il ne fige
	# donc jamais une partie entiere.
	var wind := _card("south_wind", "Vent du sud",
		"Pendant 6 s, sur tout le terrain : les monstres rapides reviennent a une "
		+ "vitesse normale, les trajets etranges filent droit et les volants restent "
		+ "sur place. Aucun degat.",
		GameEnums.Rarity.COMMON, 3.0, T.NONE, [],
		[_spec("global_wind", 0.0, 6.0)])
	wind.fx_key = &"gust_streak"
	wind.sfx_key = &"wind_gust"
	_save(wind, "res://resources/cards/common/south_wind.tres")

	# LA MARQUE ELECTRIQUE : « marque un monstre cible, 8 degats ; s il meurt, la
	# marque saute sur le plus proche avec 1 degat de moins, et ainsi de suite
	# jusqu a 0 ; incantation 2,3 s ». 8 + 7 + ... + 1 = 36 degats au plus, si
	# chaque marque tue : c est le sort des NUEES fragiles (oiseaux mirage,
	# gelees, lutins), presque rien contre un blinde qui ne meurt pas du premier
	# coup. La marque attend la mort, de quoi que ce soit : une zone qui acheve
	# un marque relance la chaine. Portee du saut : GameConfig.MARK_JUMP_RANGE.
	var mark := _card("electric_mark", "Marque electrique",
		"Marque une cible : 8 degats de FOUDRE. Quand elle meurt, la marque saute "
		+ "sur le monstre le plus proche avec 1 degat de moins, et ainsi de suite "
		+ "jusqu a 0.",
		GameEnums.Rarity.COMMON, 2.3, T.TARGET, [],
		[_spec("electric_mark", 8.0, 0.0, 0.0, {&"decay": 1.0})])
	mark.fx_key = &"bolt_cross"
	mark.sfx_key = &"zap_long"
	_save(mark, "res://resources/cards/common/electric_mark.tres")

	# LA PLUIE ABONDANTE : « pluie sur tout le terrain 10 s, 1 degat d eau toutes
	# les 2 s ; incantation 2,5 s ». Cinq gouttes de 1 a TOUS les monstres du
	# terrain, presents ou a venir pendant la pluie : peu sur un seul, beaucoup
	# sur une vague nombreuse, et le double sur ce qui craint l eau (vers et
	# seigneurs de feu, colosses). Degat CONTINU (DEC-054) : il ne fait ni
	# riposter ni compter un coup. Deux pluies s additionnent.
	var rain := _card("heavy_rain", "Pluie abondante",
		"Une pluie tombe sur tout le terrain pendant 10 s : 1 degat d EAU a chaque "
		+ "monstre toutes les 2 s.",
		GameEnums.Rarity.COMMON, 2.5, T.NONE, [],
		[_spec("global_rain", 1.0, 10.0, 0.0, {&"interval": 2.0})])
	rain.fx_key = &"rain_streaks"
	rain.sfx_key = &"drip_frost"
	_save(rain, "res://resources/cards/common/heavy_rain.tres")

	# LE SABLE MOUVANT : « -10 % de vitesse dans la zone ; les monstres encore
	# dedans a la fin subissent des degats ; duree assez longue, zone moyenne,
	# incantation moyenne ». 8 s, 180 px de rayon (la zone moyenne du jeu, entre
	# le Champ de givre et la Boule de feu), 1,6 s de base (la moyenne des
	# communes). 30 degats de NATURE a la fin : un gnome au pas traverse les
	# 360 px de la zone en un peu plus de 8 s, donc ce qui est entre dans la
	# seconde moitie de la vie du sable y est encore et paie ; ce qui a eu le
	# temps de passer s en tire. Ralentir de 10 % seulement, c est garder ce
	# choix : la zone retient un peu, elle n emprisonne pas.
	var sand := _card("quicksand", "Sable mouvant",
		"Zone de sable pendant 8 s : les monstres y avancent 10 pourcent moins vite, "
		+ "et ceux qui y sont encore a la fin encaissent 30 degats de NATURE.",
		GameEnums.Rarity.COMMON, 1.6, T.POSITION, [GameEnums.DamageTag.SLOW],
		[_spec("quicksand", 30.0, 8.0, 180.0, {&"slow_pct": 10.0})])
	sand.fx_key = &"sand_ring"
	sand.sfx_key = &"earth_dig"
	_save(sand, "res://resources/cards/common/quicksand.tres")

	# LE JET D EAU : « bande fine et haute (forme de I) qui repousse, degats selon
	# la distance parcourue ». 50 px de demi-largeur, 900 px de haut : une colonne,
	# qui demande de viser un COULOIR et non un point. Recul de 260 px (celui de la
	# Rupture de chaine), 4 degats par 100 px reellement parcourus : ~10 degats a
	# qui recule en plein, presque rien a qui est deja colle au haut du terrain ou
	# resiste a l eau. Element EAU : le recul du vent a deja ses deux sorts, et la
	# commune d eau de la Pluie ne frappe pas un point precis — le jet si.
	var jet := _card("water_jet", "Jet d eau",
		"Une colonne d eau fine et haute repousse les monstres de 260 px vers le "
		+ "haut : 4 degats d EAU par 100 px parcourus.",
		GameEnums.Rarity.COMMON, 1.5, T.POSITION, [],
		[_spec("water_jet", 4.0, 0.0, 50.0, {&"length": 900.0, &"push": 260.0})])
	jet.fx_key = &"water_geyser"
	jet.sfx_key = &"water_splash"
	_save(jet, "res://resources/cards/common/water_jet.tres")


func _entry(def_path: String, count: int, delay: float, offset: float = 0.0) -> WaveEntry:
	var w := WaveEntry.new()
	w.enemy = load(def_path)
	w.count = count
	w.spawn_delay = delay
	w.start_offset = offset
	return w


## =====================================================================
## LA CAMPAGNE DE LA VAGUE 10 (chantier B2, regles du co-auteur du 14/10).
##
## Les 21 niveaux sont decrits par UNE table (_niveau_w10, dans l ordre de jeu)
## et poses par UNE fonction (_poser_niveau). Les anciennes fonctions par acte
## (une par niveau, trois mille lignes de commentaires de reglage dont beaucoup
## parlaient d un contenu disparu : « la Reine sans niveau », « la fourche en
## lvl_04 », « Chronos au lvl_07 ») sont remplacees : chaque niveau dit ICI
## pourquoi il est fait ainsi, et seulement ce qui est vrai.
##
## LES REGLES, et ou elles sont tenues :
## 1. DECK DE BASE : trois communes x4 (LevelDef.base_commons). La premiere est
##    LA commune nouvelle du niveau, a sa premiere apparition dans l ordre de jeu ;
##    les deux autres font tourner des communes deja vues (au lvl_01 : le deck de
##    depart, Trait arcanique et Fleche percante). Jamais un deck sans degats.
##    21 communes pour 21 niveaux, mais le lvl_01 en porte TROIS : deux niveaux
##    ne peuvent pas avoir de commune fraiche. Ce sont les deux derniers de l acte
##    5, qui REPRENNENT les deux communes de depart (lvl_15 la Fleche, lvl_16 le
##    Trait : l Enfant ne craint que l arcane). `exploration_deck` recopie le deck
##    de base sans objectif (4/4/4) : c est le deck que joue un joueur qui n a
##    encore rien reussi, et les lecteurs anciens (briefing, testeur, smoke)
##    lisent le meme. `levelup_cards` reste VIDE : le pool de montee de niveau
##    est « cartes obtenues + communes de l acte » (RunState.levelup_pool) et ne
##    lit plus les cartes nouvelles d un niveau qui a son deck de base.
##    -> test_campagne_w10 (communes), test_campaign_deck (table du co-auteur).
## 2. RECOMPENSES : rang 1 rare, rang 2 epique, rang 3 legendaire, choisies
##    selon la table du co-auteur (faiblesse -> le bon element, tireur -> un mur,
##    nuee -> une zone, rapide -> un ralentissement, tank -> un doubleur,
##    deplacement bizarre -> un controle, lent -> des degats sur la duree,
##    invocateur -> de la duree, bloqueur de main -> de la pioche, boucliers ->
##    la dissipation, renard -> un sort rapide). Jamais la meme carte a deux
##    niveaux qui peuvent se suivre (les quatre demons se jouent dans n importe
##    quel ordre apres lvl_21). Les 11 legendaires sortent toutes une fois avant
##    la premiere reprise. -> _progression_de, test_level_progression.
## 3. TROIS OBJECTIFS par niveau, classes au banc des objectifs.
## 4. UN VRAI BOSS en derniere vague, UN MINI-BOSS dans une autre, chacun avec un
##    effet. -> test_campagne_w10.
## 5. ARRIVEE DES MONSTRES : chaque acte s ouvre sur 5 ordinaires neufs ; chaque
##    niveau suivant en ajoute 1 ou 2, qui restent dans la suite de l acte ;
##    quelques anciens reviennent a faible poids. L acte 4 s ouvre sur QUATRE
##    niveaux jouables dans n importe quel ordre : ils partagent un coeur de trois
##    especes et en ajoutent deux chacun (5 neuves pour celui qu on joue d abord,
##    2 pour les suivants). -> test_campagne_w10.
## 6. PROMOTIONS : un mini-boss revient en ordinaire a l acte suivant ; un boss
##    revient en mini-boss deux actes plus tard ou en ordinaire trois actes plus
##    tard (_promus_w10). -> test_campagne_w10, test_bosses.
## 7. PASSIFS : a partir de l acte 2, un passif par niveau (passive_unlocks),
##    lie au niveau ; le reste va aux quetes annexes.
## 8. lvl_13 ne s ouvre qu apres les QUATRE demons (requires_all_previous).
## 9. BUDGET : les PV d une vague comptent les boss et les chaines (divisions,
##    vies, releves) ; aucun saut de plus de x2 d une vague a la suivante.
##    -> test_campagne_w10.
## =====================================================================

## L ordre de jeu (next_levels le dit aussi, la table le suit pour se lire).
const NIVEAUX_W10: Array[StringName] = [
	&"lvl_01", &"lvl_02", &"lvl_08", &"lvl_09",
	&"lvl_17", &"lvl_18", &"lvl_03", &"lvl_04",
	&"lvl_19", &"lvl_20", &"lvl_05", &"lvl_06", &"lvl_21",
	&"lvl_07", &"lvl_10", &"lvl_11", &"lvl_12", &"lvl_13",
	&"lvl_14", &"lvl_15", &"lvl_16",
]


func _waves_and_level() -> void:
	_purger_vagues()
	# Chaque niveau porte SES trois objectifs, leurs cartes et son passif, poses
	# depuis la table de fin de fichier (_progression_de). Le dossier est vide
	# ici avant d etre rempli : un objectif retire ne doit pas survivre en .tres
	# orphelin que ContentDB continuerait d indexer.
	_purger_objectifs()
	for id: StringName in NIVEAUX_W10:
		_poser_niveau(id)


## Les vagues sont des .tres a part (ContentDB les indexe, l AUDIT les lit) : le
## dossier est purge avant d etre reecrit, comme celui des objectifs, pour
## qu une vague retiree ne survive pas en fichier orphelin.
func _purger_vagues() -> void:
	var dir := DirAccess.open("res://resources/waves")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			dir.remove(f)


func _poser_niveau(id: StringName) -> void:
	var E := "res://resources/enemies/"
	var t: Dictionary = _niveau_w10(id)
	var lvl := LevelDef.new()
	lvl.id = id
	lvl.display_name = t["nom"]
	lvl.act = int(t["acte"])
	lvl.subtitle = t["sous_titre"]
	lvl.intro_text = t["intro"]
	# Le texte de victoire n est affiche nulle part : la scene de fin (outro_story)
	# le dit. Il est vide plutot que faux (revue A4, §2.7 point 6).
	lvl.outro_text = ""
	lvl.intro_story = StringName(t["scene_avant"])
	lvl.outro_story = StringName(t["scene_apres"])
	lvl.backdrop = t["fond"]
	lvl.terrain = t.get("terrain", "grass")
	var suite: Array[StringName] = []
	for n in t["suite"]:
		suite.append(StringName(n))
	lvl.next_levels = suite
	lvl.requires_all_previous = bool(t.get("tous_les_precedents", false))
	var communes: Array[SpellCard] = []
	for c: String in t["communes"]:
		communes.append(_carte(c))
	lvl.base_commons = communes
	# Le deck sans objectif reussi : 4/4/4 (LevelDef.CAMPAIGN_DECK_TABLE[0]).
	var deck: Array[SpellCard] = []
	for c2: SpellCard in communes:
		for _k in 4:
			deck.append(c2)
	lvl.exploration_deck = deck
	var vagues: Array[WaveDef] = []
	var pool: Array[EnemyDef] = []
	for v: Array in t["vagues"]:
		var w := WaveDef.new()
		w.id = StringName(v[0])
		w.duration = float(v[1])
		w.difficulty = float(v[2])
		w.is_miniboss = v[3] == "MINI"
		w.is_boss = v[3] == "BOSS"
		var entrees: Array[WaveEntry] = []
		for en: Array in v[4]:
			var entree: WaveEntry = _entry(E + String(en[0]) + ".tres", int(en[1]),
				float(en[2]), float(en[3]))
			entrees.append(entree)
			# Le pool du Massacre et du bestiaire : les ORDINAIRES du niveau. Les
			# tetes viennent des paliers (WaveBudget.pick_boss), pas du budget.
			if entree.enemy != null and not entree.enemy.is_boss() and not pool.has(entree.enemy):
				pool.append(entree.enemy)
		w.entries = entrees
		_save(w, "res://resources/waves/%s.tres" % w.id)
		vagues.append(w)
	lvl.waves = vagues
	lvl.enemy_pool = pool
	_poser_progression(lvl)
	_save(lvl, "res://resources/levels/%s.tres" % id)


## LA TABLE DES 21 NIVEAUX. Une vague : [id, duree, difficulte, palier, entrees],
## palier "" (ordinaire), "MINI" ou "BOSS" ; une entree : [monstre, nombre,
## delai entre deux, depart dans la vague]. La TETE d un palier est sa premiere
## entree. Les textes (nom, intro, scenes) sont ceux du chantier B4.
func _niveau_w10(id: StringName) -> Dictionary:
	match id:
		# ================================ ACTE 1 ================================
		&"lvl_01":
			# LE TUTORIEL, trois vagues (le plus court des niveaux, test_balance) :
			# viser (gnomes, Planogos qui volent, une nuee d Oiseaux mirage), une
			# premiere grosse cible, puis Chronos. Cinq ordinaires neufs : Gnome,
			# Planogo, Oiseau mirage, Sauterelle, Lutin fileur.
			# COMMUNE NOUVELLE : la Boule de feu, la premiere zone (les nuees). Le
			# deck de depart : Trait arcanique (une cible, et l echeance de Chronos
			# demande un coup rapide) et Fleche percante (les volants craignent le
			# vent). MINI-BOSS : l Ecumeur du ciel, qui PIQUE puis plane (viser la
			# ou il sera) — le Gardien, qui meurt au lvl_09 apres y avoir ete
			# presente en allie, n y descend plus (revue A4, §2.7). BOSS : Chronos
			# et son ECHEANCE, a difficulte 0,6 (192 PV joues : sous la mediane des
			# boss, test_balance).
			return {"nom": "La lisiere de Nuri", "acte": 1, "sous_titre": "Le matin de la premiere attaque",
				"intro": _intro_existante(&"lvl_01"),
				"scene_avant": "lvl_01_intro", "scene_apres": "lvl_01_outro", "fond": "act1_sky",
				"suite": ["lvl_02"],
				"communes": ["fireball", "arcane_bolt", "piercing_arrow"],
				"vagues": [
					["w1", 26.0, 1.0, "", [["gnome", 5, 2.2, 0.0], ["wisp", 3, 2.0, 8.0], ["rat_swarm", 1, 1.0, 16.0]]],
					["w1_miniboss", 30.0, 0.9, "MINI", [["skyreaver", 1, 1.0, 0.0], ["gnome", 3, 2.5, 10.0],
						["hopper", 3, 1.6, 18.0], ["rat_swarm", 1, 1.0, 22.0]]],
					["w1_boss", 40.0, 0.6, "BOSS", [["chronos", 1, 1.0, 0.0], ["sprite", 6, 1.2, 6.0]]],
				]}
		&"lvl_02":
			# LE VILLAGE PETRIFIE. La lignee des gorgones (scenes de B4) : deux
			# ordinaires neufs, la Gorgone et le Corniste (« quelqu un leur bat la
			# mesure »). Il introduisait TREIZE especes d un coup : il n y a plus
			# que celles du lvl_01 et ces deux-la. COMMUNE NOUVELLE : le Cycle de
			# pensee — une main figee se renouvelle (bloqueur de main -> pioche).
			# MINI-BOSS : la Matrone (deux cartes figees). BOSS : la Reine gorgone
			# elle-meme (trois cartes), qui fermait la vague du Coagule : la scene
			# de fin la fait tomber, elle mene maintenant sa vague. Le Coagule
			# passe au boss du lvl_08.
			return {"nom": "Le village petrifie", "acte": 1, "sous_titre": "Le regard qui fige",
				"intro": _intro_existante(&"lvl_02"),
				"scene_avant": "lvl_02_intro", "scene_apres": "lvl_02_outro", "fond": "act1_sky",
				"suite": ["lvl_08"],
				"communes": ["cycle_of_thought", "arcane_bolt", "fireball"],
				"vagues": [
					["w2_1", 26.0, 1.1, "", [["gnome", 4, 2.0, 0.0], ["sprite", 3, 2.0, 8.0], ["gorgon_gazer", 1, 1.0, 16.0]]],
					["w2_2", 26.0, 1.2, "", [["rat_swarm", 2, 2.0, 0.0], ["wisp", 3, 2.0, 7.0],
						["hornblower", 1, 1.0, 14.0], ["hopper", 3, 1.6, 18.0]]],
					["w2_3_miniboss", 32.0, 1.2, "MINI", [["gorgon_matron", 1, 1.0, 0.0], ["hornblower", 1, 4.0, 5.0],
						["sprite", 5, 1.5, 9.0], ["hopper", 3, 1.6, 18.0]]],
					["w2_4", 28.0, 1.3, "", [["gorgon_gazer", 2, 3.0, 0.0], ["gnome", 4, 1.6, 6.0],
						["wisp", 2, 2.0, 14.0], ["rat_swarm", 1, 1.0, 20.0]]],
					["w2_5", 30.0, 1.4, "", [["hornblower", 1, 1.0, 0.0], ["gorgon_gazer", 2, 3.0, 4.0],
						["hopper", 4, 1.6, 12.0], ["sprite", 4, 1.5, 20.0]]],
					["w2_6_boss", 45.0, 1.0, "BOSS", [["gorgon_queen", 1, 1.0, 0.0], ["gnome", 4, 2.0, 8.0],
						["gorgon_gazer", 1, 1.0, 18.0], ["sprite", 3, 2.0, 26.0]]],
				]}
		&"lvl_08":
			# LA ROUTE DU MAIRE : « des gelees qui se coupent en deux, des ruches qui
			# eclatent. Frappe large ». Deux ordinaires neufs : la Gelee et la Ruche.
			# COMMUNE NOUVELLE : la Marque electrique, le sort des nuees fragiles
			# (elle saute de mort en mort). MINI-BOSS : le Slime enorme, qui se
			# divise en trois. BOSS : le Coagule, qui se releve une fois a 40 % —
			# garder une carte apres avoir cru gagner.
			return {"nom": "La route du maire", "acte": 1, "sous_titre": "Ce n est pas la foret qui est attaquee",
				"intro": _intro_existante(&"lvl_08"),
				"scene_avant": "lvl_08_intro", "scene_apres": "lvl_08_outro", "fond": "act1_sky",
				"suite": ["lvl_09"],
				"communes": ["electric_mark", "fireball", "piercing_arrow"],
				"vagues": [
					["w8_1", 24.0, 1.15, "", [["jelly", 2, 3.0, 0.0], ["rat_swarm", 2, 2.4, 8.0], ["gnome", 3, 1.8, 15.0]]],
					["w8_2", 26.0, 1.25, "", [["hive", 2, 4.0, 0.0], ["sprite", 3, 1.6, 7.0],
						["hopper", 2, 2.0, 16.0], ["wisp", 1, 1.0, 20.0]]],
					["w8_3_miniboss", 32.0, 1.1, "MINI", [["slime_huge", 1, 1.0, 0.0], ["jelly", 1, 2.5, 8.0],
						["gorgon_gazer", 1, 1.0, 14.0], ["sprite", 4, 1.6, 18.0]]],
					["w8_4", 27.0, 1.35, "", [["jelly", 2, 3.0, 0.0], ["rat_swarm", 2, 2.2, 7.0], ["hive", 1, 1.0, 15.0],
						["hornblower", 1, 1.0, 19.0], ["gnome", 3, 1.6, 22.0]]],
					["w8_5_boss", 42.0, 1.05, "BOSS", [["blood_coagulum", 1, 1.0, 0.0], ["jelly", 2, 3.0, 8.0],
						["hive", 1, 1.0, 20.0], ["rat_swarm", 1, 1.0, 28.0]]],
				]}
		&"lvl_09":
			# PROTEGER LE DIRIGEABLE, la fin de l acte. Deux ordinaires neufs : le
			# Renard dormeur (il coupe la magie pendant son sommeil) et le Chevalier
			# du vide (il avale le premier coup), qui revient au port (lvl_18).
			# Le Slime moyen, vu au lvl_08 (le Slime enorme s y divise), y descend
			# seul : ce n est pas une espece neuve. COMMUNE NOUVELLE : l Etincelle, le sort le plus rapide du jeu
			# (renard -> sort rapide), et les petits coups qui ouvrent une armure.
			# MINI-BOSS : le Seigneur de braise, qui RIPOSTE a chaque coup. BOSS :
			# le Gardien de la foret (la scene le nomme), devenu un vrai boss : son
			# armure se REFERME apres six secondes de calme.
			return {"nom": "Proteger le dirigeable", "acte": 1, "sous_titre": "On ne devient pas fou en six jours",
				"intro": _intro_existante(&"lvl_09"),
				"scene_avant": "lvl_09_intro", "scene_apres": "lvl_09_outro", "fond": "act1_sky",
				"suite": ["lvl_17"],
				"communes": ["spark", "arcane_bolt", "fireball"],
				"vagues": [
					["w9_1", 25.0, 1.25, "", [["gnome", 5, 1.8, 0.0], ["hopper", 3, 2.0, 11.0], ["sleepy_fox", 1, 1.0, 18.0],
						["slime_mid", 2, 1.5, 21.0]]],
					["w9_2", 27.0, 1.35, "", [["rat_swarm", 2, 2.2, 0.0], ["sprite", 4, 1.5, 7.0], ["hornblower", 1, 1.0, 14.0],
						["jelly", 1, 2.5, 18.0], ["void_knight", 1, 1.0, 22.0]]],
					["w9_3_miniboss", 30.0, 1.15, "MINI", [["emberlord", 1, 1.0, 0.0], ["hopper", 3, 2.0, 9.0],
						["gnome", 4, 1.6, 18.0], ["gorgon_gazer", 1, 1.0, 24.0]]],
					["w9_4", 28.0, 1.35, "", [["hive", 2, 3.0, 0.0], ["wisp", 2, 2.0, 8.0], ["sleepy_fox", 2, 2.4, 14.0],
						["void_knight", 1, 1.0, 20.0], ["rat_swarm", 1, 1.0, 24.0]]],
					["w9_5_boss", 42.0, 1.0, "BOSS", [["warden", 1, 1.0, 0.0], ["gnome", 5, 1.8, 7.0],
						["sprite", 5, 1.5, 20.0], ["gorgon_gazer", 1, 1.0, 30.0]]],
				]}
		# ================================ ACTE 2 ================================
		&"lvl_17":
			# LES COURANTS : « tout ce qui t y attend vole ». Cinq ordinaires neufs :
			# l Oeil des courants (spirale), le Lutin archer (« l Archer ne descend
			# pas »), le Serpent des sables, l Ombre et l Ecumeur (le mini-boss du
			# lvl_01 revenu en ordinaire). Les Planogos de l acte 1 reviennent.
			# COMMUNE NOUVELLE : le Vent du sud, qui fige les volants et redresse les
			# trajets etranges. MINI-BOSS : la Mere Planogo, qui en appelle d autres.
			# BOSS : le Grand Oeil des courants (la scene le fait tomber).
			return {"nom": "Les courants", "acte": 2, "sous_titre": "Tout ce qui t attend vole",
				"intro": _intro_existante(&"lvl_17"),
				"scene_avant": "lvl_17_intro", "scene_apres": "lvl_17_outro", "fond": "act1_sky",
				"suite": ["lvl_18"],
				"communes": ["south_wind", "piercing_arrow", "spark"],
				"vagues": [
					["w17_1", 24.0, 1.3, "", [["wisp", 3, 2.2, 0.0], ["current_eye", 2, 2.4, 9.0], ["imp_archer", 1, 1.0, 16.0]]],
					["w17_2", 26.0, 1.35, "", [["current_eye", 3, 2.0, 0.0], ["imp_archer", 2, 2.2, 8.0],
						["sand_serpent", 3, 1.8, 16.0]]],
					["w17_3_miniboss", 32.0, 1.1, "MINI", [["planogo_mother", 1, 1.0, 0.0], ["ecumeur", 2, 3.0, 8.0],
						["shade", 2, 2.0, 16.0], ["wisp", 2, 2.0, 22.0]]],
					["w17_4", 27.0, 1.4, "", [["ecumeur", 2, 3.0, 0.0], ["shade", 3, 2.0, 8.0],
						["current_eye", 3, 2.0, 15.0], ["sand_serpent", 2, 1.8, 21.0]]],
					["w17_5_boss", 44.0, 0.95, "BOSS", [["great_eye", 1, 1.0, 0.0], ["current_eye", 3, 2.0, 10.0],
						["imp_archer", 1, 1.0, 20.0], ["sand_serpent", 2, 2.0, 26.0], ["wisp", 2, 2.0, 34.0]]],
				]}
		&"lvl_18":
			# LE PORT DE HAUTE-NACELLE : « le Chevalier du vide avale ton premier
			# coup, le Berserker accelere, et les Pillards n arrivent meme pas par
			# la ou tu regardes ». Deux ordinaires neufs : le Berserker et le
			# Pillard ; le Chevalier revient de l acte 1. COMMUNE NOUVELLE : le Dard
			# venimeux, un seul lancer qui ronge (il ouvre le bouclier du Chevalier
			# et ne fait pas enrager le Berserker coup apres coup). MINI-BOSS : le
			# Capitaine pillard, qui surgit du cote et appelle sa bande. BOSS : le
			# Mage noir de Haute-Nacelle (la scene le fait tomber).
			return {"nom": "Port de Haute-Nacelle", "acte": 2, "sous_titre": "Un port vide par le haut",
				"intro": _intro_existante(&"lvl_18"),
				"scene_avant": "lvl_18_intro", "scene_apres": "lvl_18_outro", "fond": "act1_sky",
				"suite": ["lvl_03"],
				"communes": ["venom_dart", "south_wind", "fireball"],
				"vagues": [
					["w18_1", 25.0, 1.35, "", [["nacelle_raider", 4, 1.8, 0.0], ["shade", 2, 2.2, 10.0], ["current_eye", 1, 1.0, 18.0]]],
					["w18_2", 27.0, 1.4, "", [["void_knight", 2, 2.5, 0.0], ["berserker", 2, 2.5, 9.0],
						["nacelle_raider", 3, 1.8, 18.0], ["imp_archer", 1, 1.0, 24.0]]],
					["w18_3_miniboss", 32.0, 1.1, "MINI", [["raider_captain", 1, 1.0, 0.0], ["nacelle_raider", 2, 1.8, 8.0],
						["ecumeur", 1, 1.0, 16.0], ["sand_serpent", 2, 2.0, 22.0]]],
					["w18_4", 28.0, 1.45, "", [["berserker", 2, 2.5, 0.0], ["nacelle_raider", 3, 1.6, 8.0], ["shade", 2, 2.0, 15.0],
						["void_knight", 1, 2.5, 21.0], ["ecumeur", 1, 1.0, 25.0]]],
					["w18_5_boss", 44.0, 0.95, "BOSS", [["dark_mage", 1, 1.0, 0.0], ["nacelle_raider", 2, 1.8, 8.0],
						["void_knight", 1, 1.0, 18.0], ["imp_archer", 1, 1.0, 26.0], ["current_eye", 2, 2.0, 32.0]]],
				]}
		&"lvl_03":
			# L OSSUAIRE : les Pretres goules tiennent les registres. Deux ordinaires
			# neufs : le Pretre goule (il soigne) et le Slime gonfle (le Slime enorme
			# du lvl_08, en ordinaire) ; les Oiseaux mirage et la Gelee reviennent de
			# l acte 1. COMMUNE NOUVELLE : la Pluie de givre, la tres grande zone
			# (nuees, slimes, et tout ce que le Pretre soigne a la fois). MINI-BOSS :
			# le Gardien d ossements et sa GARDE LEVEE (les coups glissent, les zones
			# passent). BOSS : le Reliquaire (la scene le nomme), qui ignore ses six
			# premiers coups.
			return {"nom": "L ossuaire de bordure", "acte": 2, "sous_titre": "Une administration, pas un cimetiere",
				"intro": _intro_existante(&"lvl_03"),
				"scene_avant": "lvl_03_intro", "scene_apres": "lvl_03_outro", "fond": "act2_graveyard",
				"suite": ["lvl_04"],
				"communes": ["frost_rain", "venom_dart", "fireball"],
				"vagues": [
					["w3_1", 26.0, 1.15, "", [["rat_swarm", 2, 2.4, 0.0], ["slime_swollen", 2, 2.0, 7.0],
						["ghoul_priest", 1, 1.0, 15.0], ["shade", 1, 1.0, 20.0]]],
					["w3_2", 27.0, 1.25, "", [["jelly", 1, 2.5, 0.0], ["rat_swarm", 2, 2.0, 6.0], ["imp_archer", 1, 1.0, 12.0],
						["slime_swollen", 2, 1.6, 16.0], ["nacelle_raider", 2, 1.8, 22.0]]],
					["w3_3", 28.0, 1.3, "", [["ghoul_priest", 2, 3.0, 0.0], ["jelly", 1, 2.0, 8.0],
						["sand_serpent", 2, 2.0, 14.0], ["current_eye", 2, 2.0, 20.0]]],
					["w3_4_miniboss", 32.0, 1.05, "MINI", [["bonewarden", 1, 1.0, 0.0], ["ghoul_priest", 1, 1.0, 4.0],
						["rat_swarm", 2, 2.2, 8.0], ["berserker", 1, 1.0, 16.0], ["ecumeur", 1, 1.0, 22.0]]],
					["w3_5", 30.0, 1.35, "", [["slime_swollen", 2, 3.0, 0.0], ["ghoul_priest", 1, 1.0, 8.0],
						["rat_swarm", 2, 2.0, 14.0], ["shade", 2, 2.0, 20.0], ["imp_archer", 1, 1.0, 26.0]]],
					["w3_6_boss", 42.0, 1.1, "BOSS", [["bone_reliquary", 1, 1.0, 0.0], ["ghoul_priest", 2, 2.5, 8.0],
						["rat_swarm", 3, 2.0, 20.0], ["nacelle_raider", 1, 1.0, 30.0], ["current_eye", 1, 1.0, 34.0]]],
				]}
		&"lvl_04":
			# LE GRAND APPEL, la fin de l acte. Deux ordinaires neufs, les deux
			# derniers mini-boss de l acte 1 revenus en ordinaires : la Gorgone
			# ainee (la Matrone) et le Vassal de braise (le Seigneur de braise).
			# COMMUNE NOUVELLE : le Mur de pierre — il arrete les fleches des Lutins
			# archers (tireur -> un mur), et il donne au Briseur quelque chose a
			# abattre. MINI-BOSS : le Briseur de tertres. BOSS : l Ensevelisseur
			# (la scene le nomme), qui fait monter les Charognards sans fin.
			return {"nom": "Le Grand Appel", "acte": 2, "sous_titre": "Le rituel reussit",
				"intro": _intro_existante(&"lvl_04"),
				"scene_avant": "lvl_04_intro", "scene_apres": "lvl_04_outro", "fond": "act2_graveyard",
				"suite": ["lvl_19"],
				"communes": ["stone_wall", "venom_dart", "frost_rain"],
				"vagues": [
					["w4_1", 26.0, 1.2, "", [["slime_swollen", 2, 2.2, 0.0], ["imp_archer", 2, 2.0, 8.0],
						["gorgon_elder", 1, 1.0, 16.0], ["current_eye", 1, 1.0, 21.0]]],
					["w4_2", 28.0, 1.3, "", [["ghoul_priest", 2, 2.5, 0.0], ["ember_vassal", 2, 2.5, 9.0],
						["shade", 2, 2.0, 17.0], ["sand_serpent", 1, 1.0, 23.0]]],
					["w4_3_miniboss", 34.0, 1.1, "MINI", [["terrain_breaker", 1, 1.0, 0.0], ["ghoul_priest", 1, 2.0, 9.0],
						["nacelle_raider", 2, 1.8, 16.0], ["ecumeur", 1, 1.0, 24.0]]],
					["w4_4", 30.0, 1.35, "", [["berserker", 2, 2.5, 0.0], ["gorgon_elder", 1, 1.0, 8.0], ["ember_vassal", 1, 1.0, 14.0],
						["imp_archer", 2, 2.0, 19.0], ["slime_swollen", 1, 1.0, 25.0]]],
					["w4_5", 32.0, 1.35, "", [["ghoul_priest", 1, 1.0, 0.0], ["gorgon_elder", 1, 1.0, 6.0], ["shade", 2, 2.0, 12.0],
						["nacelle_raider", 2, 1.8, 18.0], ["current_eye", 2, 2.0, 24.0]]],
					["w4_6_boss", 45.0, 1.05, "BOSS", [["gravecaller", 1, 1.0, 0.0], ["imp_archer", 2, 2.5, 12.0],
						["ember_vassal", 1, 1.0, 24.0], ["sand_serpent", 1, 1.0, 30.0]]],
				]}
		# ================================ ACTE 3 ================================
		&"lvl_19":
			# LES FOSSES BASSES, l ouverture de Tombol. Cinq ordinaires neufs : la
			# Goule des fosses (par trois), le Squelette pareur, le Slime fantome (il
			# renait en Slime squelette, qui descend aussi seul), la Garde
			# d ossements (le mini-boss du lvl_03 en ordinaire). Les Pretres goules reviennent (la
			# scene les nomme). COMMUNE NOUVELLE : les Braises, une zone qui dure,
			# posee sur la marque de renaissance. MINI-BOSS : la Sorciere des fosses
			# (elle soigne et invoque). BOSS : le trio des mages des fosses.
			return {"nom": "Les fosses basses", "acte": 3, "sous_titre": "Tombol commence par le bas",
				"intro": _intro_existante(&"lvl_19"),
				"scene_avant": "lvl_19_intro", "scene_apres": "lvl_19_outro", "fond": "act2_graveyard",
				"suite": ["lvl_20"],
				"communes": ["ember_pool", "frost_rain", "arcane_bolt"],
				"vagues": [
					["w19_1", 26.0, 1.4, "", [["pit_ghoul", 2, 2.4, 0.0], ["ghoul_priest", 1, 2.0, 10.0], ["slime_ghost", 2, 2.2, 17.0]]],
					["w19_2", 27.0, 1.45, "", [["bone_guard", 2, 2.5, 0.0], ["pit_ghoul", 2, 2.2, 9.0],
						["parry_skeleton", 1, 1.0, 18.0], ["slime_ghost", 1, 1.0, 22.0]]],
					["w19_3", 28.0, 1.5, "", [["pit_ghoul", 2, 2.2, 0.0], ["parry_skeleton", 2, 2.2, 8.0],
						["ghoul_priest", 1, 2.0, 16.0], ["slime_skeleton", 2, 2.0, 22.0]]],
					["w19_4_miniboss", 34.0, 1.1, "MINI", [["pit_witch", 1, 1.0, 0.0], ["pit_ghoul", 2, 2.2, 8.0],
						["bone_guard", 1, 1.0, 16.0], ["slime_ghost", 2, 2.0, 22.0]]],
					["w19_5_boss", 45.0, 1.0, "BOSS", [["trio_ember", 1, 1.0, 0.0], ["trio_frost", 1, 1.0, 0.6],
						["trio_arcane", 1, 1.0, 1.2], ["pit_ghoul", 2, 3.0, 20.0], ["parry_skeleton", 1, 1.0, 28.0],
						["slime_skeleton", 1, 1.0, 34.0]]],
				]}
		&"lvl_20":
			# LA COUR DES ROIS MORTS : « sous chaque statue un Gardien-totem ». Deux
			# ordinaires neufs : le Gardien-totem et le Casseur de tertres (le
			# Briseur du lvl_04 en ordinaire) ; l Ombre, le Chevalier du vide et la
			# Ruche reviennent. COMMUNE NOUVELLE : la Lumiere purifiante (boucliers
			# -> dissipation) : elle eteint l aura. MINI-BOSS : le Totem ancien et
			# son AURA ANCIENNE. BOSS : l Epeiste d ombre, la derniere arriere-garde,
			# qui revient une fois par le haut.
			return {"nom": "La cour des rois morts", "acte": 3, "sous_titre": "Une cour de statues",
				"intro": _intro_existante(&"lvl_20"),
				"scene_avant": "lvl_20_intro", "scene_apres": "lvl_20_outro", "fond": "act2_graveyard",
				"suite": ["lvl_05", "lvl_06"],
				"communes": ["purifying_light", "ember_pool", "piercing_arrow"],
				"vagues": [
					["w20_1", 26.0, 1.45, "", [["totem_guardian", 1, 1.0, 0.0], ["parry_skeleton", 2, 2.2, 8.0],
						["pit_ghoul", 2, 2.2, 15.0], ["slime_ghost", 1, 1.0, 22.0]]],
					["w20_2", 28.0, 1.5, "", [["tomb_breaker", 1, 1.0, 0.0], ["hive", 2, 3.0, 4.0], ["void_knight", 1, 2.5, 12.0],
						["bone_guard", 1, 1.0, 18.0], ["shade", 2, 2.0, 22.0]]],
					["w20_3_miniboss", 33.0, 1.1, "MINI", [["totem_elder", 1, 1.0, 0.0], ["shade", 2, 2.0, 9.0],
						["parry_skeleton", 2, 2.2, 18.0], ["slime_skeleton", 1, 1.0, 26.0]]],
					["w20_4", 29.0, 1.55, "", [["totem_guardian", 1, 1.0, 0.0], ["tomb_breaker", 1, 1.0, 6.0], ["pit_ghoul", 2, 2.2, 11.0],
						["parry_skeleton", 2, 2.0, 17.0], ["bone_guard", 1, 1.0, 23.0]]],
					["w20_5_boss", 44.0, 1.05, "BOSS", [["shadow_bladesman", 1, 1.0, 0.0], ["parry_skeleton", 2, 2.2, 10.0],
						["totem_guardian", 1, 1.0, 20.0], ["pit_ghoul", 2, 2.0, 28.0]]],
				]}
		&"lvl_05":
			# LES FORGES SOUS TOMBOL (une branche de la fourche). Deux ordinaires
			# neufs : le Golem et le Behemoth, qui craignent l arcane ; le Berserker
			# revient (il brise sa chaine dans la scene). COMMUNE NOUVELLE : le Jet
			# d eau (le Colosse craint l eau, faiblesse -> le bon element) ; la
			# Lumiere purifiante tourne (le Gardien-totem descend encore). MINI-BOSS :
			# le Miroir de Forge et sa garde de renvoi. BOSS : le Colosse des Forges,
			# « le dernier colosse » de la scene, en quatre pieces.
			return {"nom": "Les forges sous Tombol", "acte": 3, "sous_titre": "Ils ne conquierent pas, ils fabriquent",
				"intro": _intro_existante(&"lvl_05"),
				"scene_avant": "lvl_05_intro", "scene_apres": "lvl_05_outro", "fond": "act3_demon",
				"suite": ["lvl_21"],
				"communes": ["water_jet", "purifying_light", "arcane_bolt"],
				"vagues": [
					["w5_1", 28.0, 1.2, "", [["golem", 2, 3.0, 0.0], ["pit_ghoul", 2, 2.0, 10.0], ["slime_ghost", 1, 1.0, 18.0]]],
					["w5_2", 28.0, 1.25, "", [["berserker", 2, 2.5, 0.0], ["bone_guard", 1, 1.0, 10.0],
						["parry_skeleton", 1, 1.0, 15.0], ["tomb_breaker", 1, 1.0, 20.0]]],
					["w5_3_miniboss", 34.0, 1.1, "MINI", [["glass_mirror", 1, 1.0, 0.0], ["golem", 2, 3.0, 10.0],
						["slime_ghost", 2, 1.8, 22.0]]],
					["w5_4", 30.0, 1.3, "", [["behemoth", 1, 1.0, 0.0], ["totem_guardian", 1, 1.0, 8.0], ["golem", 1, 1.0, 14.0],
						["pit_ghoul", 2, 2.2, 20.0], ["slime_skeleton", 1, 1.0, 26.0]]],
					["w5_5", 32.0, 1.3, "", [["behemoth", 1, 1.0, 0.0], ["golem", 2, 2.5, 9.0], ["berserker", 1, 1.0, 18.0],
						["bone_guard", 1, 1.0, 22.0], ["tomb_breaker", 1, 1.0, 26.0]]],
					["w5_6_boss", 48.0, 1.05, "BOSS", [["forge_colossus", 1, 1.0, 0.0], ["golem", 2, 3.0, 14.0],
						["parry_skeleton", 1, 1.0, 26.0], ["pit_ghoul", 2, 2.0, 34.0]]],
				]}
		&"lvl_06":
			# LA COUR BRISEE (l autre branche). Deux ordinaires neufs, les mini-boss
			# de l acte 2 revenus en ordinaires : le Pillard deserteur (le Capitaine)
			# et le Planogo cendre (la Mere Planogo) ; l Ombre, le Chevalier du vide
			# et la Sauterelle reviennent. COMMUNE NOUVELLE : le Sable mouvant, pour
			# une cour ou tout le monde passe : ce qui reste dedans paie. MINI-BOSS :
			# le Bourreau et son onde. BOSS : le Seigneur Spectre, « le dernier
			# seigneur de la cour ».
			return {"nom": "La cour brisee", "acte": 3, "sous_titre": "Une guerre civile ou tu n es qu un passant",
				"intro": _intro_existante(&"lvl_06"),
				"scene_avant": "lvl_06_intro", "scene_apres": "lvl_06_outro", "fond": "act3_demon",
				"suite": ["lvl_21"],
				"communes": ["quicksand", "ember_pool", "arcane_bolt"],
				"vagues": [
					["w6_1", 27.0, 1.2, "", [["void_knight", 1, 2.5, 0.0], ["raider_deserter", 3, 1.8, 8.0],
						["planogo_ash", 1, 1.0, 16.0], ["pit_ghoul", 1, 1.0, 21.0]]],
					["w6_2", 28.0, 1.25, "", [["shade", 3, 2.0, 0.0], ["hopper", 3, 1.8, 8.0],
						["parry_skeleton", 1, 1.0, 15.0], ["bone_guard", 1, 1.0, 20.0]]],
					["w6_3_miniboss", 34.0, 1.1, "MINI", [["executioner", 1, 1.0, 0.0], ["raider_deserter", 2, 1.8, 7.0],
						["slime_ghost", 2, 2.0, 14.0], ["tomb_breaker", 1, 1.0, 24.0]]],
					["w6_4", 30.0, 1.3, "", [["planogo_ash", 2, 2.5, 0.0], ["totem_guardian", 1, 1.0, 8.0],
						["pit_ghoul", 2, 2.2, 14.0], ["slime_skeleton", 2, 1.0, 22.0]]],
					["w6_5", 32.0, 1.3, "", [["raider_deserter", 3, 1.6, 0.0], ["void_knight", 1, 1.0, 8.0], ["parry_skeleton", 1, 1.0, 14.0],
						["shade", 2, 2.0, 20.0], ["tomb_breaker", 1, 1.0, 26.0]]],
					["w6_6_boss", 48.0, 1.05, "BOSS", [["wraith_lord", 1, 1.0, 0.0], ["void_knight", 2, 2.5, 12.0],
						["planogo_ash", 1, 1.0, 22.0], ["bone_guard", 1, 1.0, 30.0]]],
				]}
		&"lvl_21":
			# LE PENTACLE, la fin de l acte. Deux ordinaires neufs : le Ver de feu,
			# IMMUNISE au feu, et le Gros slime fantome (deux renaissances) ; tout
			# l acte 3 y descend (les deux branches de la fourche), l Oeil des
			# courants et le Berserker reviennent. COMMUNE
			# NOUVELLE : la Pluie abondante, l eau sur tout le terrain (les vers
			# craignent l eau). Les Braises restent au deck : gagner sans feu est un
			# objectif, il faut donc un sort de feu a laisser. MINI-BOSS : le
			# Fossoyeur, qui releve les morts. BOSS : le Sceau de Tombol.
			return {"nom": "Le pentacle", "acte": 3, "sous_titre": "Le roi ne fuit plus",
				"intro": _intro_existante(&"lvl_21"),
				"scene_avant": "lvl_21_intro", "scene_apres": "lvl_21_outro", "fond": "act2_graveyard",
				"suite": ["lvl_07", "lvl_10", "lvl_11", "lvl_12"],
				"communes": ["heavy_rain", "ember_pool", "arcane_bolt"],
				"vagues": [
					["w21_1", 27.0, 1.5, "", [["pit_ghoul", 2, 2.2, 0.0], ["current_eye", 2, 2.0, 9.0],
						["berserker", 1, 1.0, 16.0], ["golem", 1, 1.0, 21.0], ["slime_skeleton", 1, 1.0, 24.0]]],
					["w21_2_miniboss", 30.0, 1.1, "MINI", [["gravedigger", 1, 1.0, 0.0], ["fire_worm", 1, 2.2, 4.0],
						["parry_skeleton", 2, 2.0, 10.0], ["raider_deserter", 2, 1.8, 18.0]]],
					["w21_3", 34.0, 1.6, "", [["fire_worm", 2, 2.2, 0.0], ["totem_guardian", 1, 2.0, 8.0], ["slime_ghost", 2, 2.0, 14.0],
						["behemoth", 1, 1.0, 20.0], ["planogo_ash", 1, 1.0, 26.0]]],
					["w21_4", 32.0, 1.5, "", [["fire_worm", 2, 2.2, 0.0], ["bone_guard", 1, 1.0, 8.0], ["tomb_breaker", 1, 1.0, 12.0],
						["slime_ghost_big", 1, 1.0, 18.0], ["pit_ghoul", 2, 2.2, 24.0]]],
					["w21_5_boss", 45.0, 1.05, "BOSS", [["tombol_seal", 1, 1.0, 0.0], ["fire_worm", 2, 2.5, 12.0],
						["pit_ghoul", 2, 2.2, 28.0]]],
				]}
		# ================================ ACTE 4 ================================
		# Quatre demons jouables dans n importe quel ordre. LE COEUR COMMUN (5 neufs
		# pour celui qu on joue d abord, avec ses deux especes) : le Slime
		# demoniaque, le Champignon cuirasse, la Plante carnivore.
		&"lvl_07":
			# LA FORGE DE VHARN. Ses deux especes : l Eclat de miroir (le Miroir de
			# Forge du lvl_05 en ordinaire) et l Aide du Bourreau (le Bourreau du
			# lvl_06, qui ne marche toujours pas). COMMUNE NOUVELLE : la Spirale de
			# sel — l exemple du co-auteur : Vharn, immunise au vent, n est pas
			# aspire ; tout le reste l est. MINI-BOSS : le Golem a noyau et son
			# laser. BOSS : Vharn, qui ignore ses six premiers coups.
			return {"nom": "La forge de Vharn", "acte": 4, "sous_titre": "Une forge sans forgeron",
				"intro": _intro_existante(&"lvl_07"),
				"scene_avant": "lvl_07_intro", "scene_apres": "lvl_07_outro", "fond": "act3_demon",
				"suite": ["lvl_13"],
				"communes": ["salt_spiral", "fireball", "spark"],
				"vagues": [
					["w7_1", 28.0, 1.4, "", [["mushroom", 3, 2.2, 0.0], ["carnivore_plant", 3, 1.8, 8.0],
						["demon_slime", 1, 1.0, 16.0], ["golem", 1, 1.0, 22.0]]],
					["w7_2", 29.0, 1.45, "", [["mirror_shard", 2, 2.5, 0.0], ["executioner_aide", 1, 1.0, 8.0],
						["void_knight", 1, 1.0, 14.0], ["carnivore_plant", 2, 1.8, 20.0]]],
					["w7_3_miniboss", 36.0, 1.1, "MINI", [["mecha_golem", 1, 1.0, 0.0], ["berserker", 2, 2.5, 9.0],
						["mushroom", 2, 2.0, 20.0]]],
					["w7_4", 32.0, 1.45, "", [["demon_slime", 1, 1.0, 0.0], ["mirror_shard", 1, 1.0, 8.0], ["executioner_aide", 1, 1.0, 14.0],
						["mushroom", 2, 2.2, 20.0], ["carnivore_plant", 2, 1.8, 26.0]]],
					["w7_5_boss", 55.0, 1.05, "BOSS", [["demon_anvil", 1, 1.0, 0.0], ["void_knight", 2, 2.5, 10.0],
						["berserker", 1, 1.0, 24.0], ["demon_slime", 1, 1.0, 34.0], ["mushroom", 2, 2.0, 42.0]]],
				]}
		&"lvl_10":
			# LES FOSSES DE SESH : « ce que tu laisses derriere toi, il le nourrit ».
			# Ses deux especes : le Glouton (il gobe) et le Cacodemon (il rebondit
			# d un bord a l autre). COMMUNE NOUVELLE : la Rupture de chaine — tuer et
			# repousser d un coup ce qui ferait un repas. MINI-BOSS : l Echo du
			# Reliquaire (le boss du lvl_03, deux actes plus tard). BOSS : Sesh.
			return {"nom": "Les fosses de Sesh", "acte": 4, "sous_titre": "Des fosses tiedes ou le sol remue",
				"intro": _intro_existante(&"lvl_10"),
				"scene_avant": "lvl_10_intro", "scene_apres": "lvl_10_outro", "fond": "act3_demon",
				"suite": ["lvl_13"],
				"communes": ["chain_break", "frost_rain", "arcane_bolt"],
				"vagues": [
					["w10_1", 26.0, 1.3, "", [["demon_slime", 1, 1.0, 0.0], ["mushroom", 2, 2.2, 6.0],
						["jelly", 1, 1.0, 14.0], ["carnivore_plant", 2, 1.8, 20.0]]],
					["w10_2", 28.0, 1.35, "", [["glutton", 1, 1.0, 0.0], ["carnivore_plant", 3, 1.8, 6.0],
						["hive", 1, 1.0, 14.0], ["mushroom", 2, 2.2, 20.0]]],
					["w10_3_miniboss", 32.0, 1.05, "MINI", [["reliquary_echo", 1, 1.0, 0.0], ["demon_slime", 1, 1.0, 10.0],
						["carnivore_plant", 2, 1.8, 20.0]]],
					["w10_4", 30.0, 1.45, "", [["glutton", 1, 1.0, 0.0], ["cacodaemon", 2, 2.4, 8.0],
						["demon_slime", 1, 1.0, 16.0], ["mushroom", 2, 2.0, 22.0]]],
					["w10_5_boss", 44.0, 1.05, "BOSS", [["demon_maw", 1, 1.0, 0.0], ["mushroom", 3, 2.2, 10.0],
						["cacodaemon", 1, 1.0, 22.0], ["carnivore_plant", 3, 1.8, 32.0]]],
				]}
		&"lvl_11":
			# L ARENE DE KALTEK : « aller vite est une erreur ». Ses deux especes :
			# la Novice des fosses (la Sorciere du lvl_19 : elle soigne les
			# esclaves) et le Croque-mort (le Fossoyeur du lvl_21 : il les releve) ;
			# les Berserkers et le Chevalier du vide reviennent. COMMUNE NOUVELLE :
			# le Champ de givre (rapide -> un ralentissement). MINI-BOSS : l Echo du
			# Grand Oeil (le boss du lvl_17). BOSS : Kaltek, qui fabrique ses
			# esclaves et s enrage.
			return {"nom": "L arene de Kaltek", "acte": 4, "sous_titre": "Une arene de sable noir",
				"intro": _intro_existante(&"lvl_11"),
				"scene_avant": "lvl_11_intro", "scene_apres": "lvl_11_outro", "fond": "act3_demon",
				"suite": ["lvl_13"],
				"communes": ["frost_field", "arcane_bolt", "frost_rain"],
				"vagues": [
					["w11_1", 26.0, 1.3, "", [["berserker", 2, 2.5, 0.0], ["mushroom", 2, 2.0, 10.0], ["carnivore_plant", 2, 1.8, 18.0]]],
					["w11_2", 28.0, 1.35, "", [["void_knight", 2, 2.5, 0.0], ["pit_novice", 1, 1.0, 10.0],
						["berserker", 2, 2.5, 16.0], ["demon_slime", 1, 1.0, 24.0]]],
					["w11_3_miniboss", 32.0, 1.05, "MINI", [["great_eye_echo", 1, 1.0, 0.0], ["berserker", 2, 2.5, 10.0],
						["grave_mourner", 1, 1.0, 20.0], ["carnivore_plant", 2, 1.8, 24.0]]],
					["w11_4", 30.0, 1.35, "", [["grave_mourner", 1, 1.0, 0.0], ["berserker", 3, 2.2, 6.0], ["pit_novice", 1, 1.0, 14.0],
						["mushroom", 2, 2.0, 20.0]]],
					["w11_5_boss", 44.0, 1.05, "BOSS", [["demon_chain", 1, 1.0, 0.0], ["void_knight", 2, 2.5, 12.0],
						["pit_novice", 1, 1.0, 22.0], ["hopper", 3, 1.6, 28.0]]],
				]}
		&"lvl_12":
			# LE TEMPLE D YMOA : « tout est protege par autre chose ». Ses deux
			# especes : le Totem fele (le Totem ancien du lvl_20 : une aura courte)
			# et le Caillot (le Coagule du lvl_08, trois actes plus tard : il se
			# releve). L Ombre, le Golem et le Pretre goule reviennent. COMMUNE
			# NOUVELLE : le Rappel d ossements, qui garde en main la Lumiere
			# purifiante (au deck : elle eteint les auras). MINI-BOSS : les Jumeaux
			# du Cercle. BOSS : Ymoa, qui campe au fond et tient son cercle.
			return {"nom": "Le temple d Ymoa", "acte": 4, "sous_titre": "Un temple de cristal",
				"intro": _intro_existante(&"lvl_12"),
				"scene_avant": "lvl_12_intro", "scene_apres": "lvl_12_outro", "fond": "act3_demon",
				"suite": ["lvl_13"],
				"communes": ["bone_recall", "arcane_bolt", "purifying_light"],
				"vagues": [
					["w12_1", 26.0, 1.3, "", [["totem_cracked", 1, 1.0, 0.0], ["mushroom", 2, 2.0, 6.0],
						["carnivore_plant", 2, 1.8, 14.0], ["demon_slime", 1, 1.0, 20.0]]],
					["w12_2", 28.0, 1.35, "", [["ghoul_priest", 1, 1.0, 0.0], ["totem_cracked", 1, 1.0, 6.0],
						["blood_clot", 2, 2.5, 12.0], ["shade", 2, 2.0, 20.0]]],
					["w12_3_miniboss", 32.0, 1.1, "MINI", [["circle_twins", 1, 1.2, 0.0], ["totem_cracked", 1, 1.0, 6.0],
						["shade", 2, 2.0, 22.0]]],
					["w12_4", 32.0, 1.4, "", [["blood_clot", 2, 2.5, 0.0], ["demon_slime", 1, 1.0, 8.0], ["golem", 1, 1.0, 14.0],
						["carnivore_plant", 2, 1.8, 20.0], ["totem_cracked", 1, 1.0, 26.0]]],
					["w12_5_boss", 46.0, 1.05, "BOSS", [["demon_circle", 1, 1.0, 0.0], ["golem", 1, 1.0, 10.0],
						["blood_clot", 1, 1.0, 20.0], ["shade", 3, 2.0, 30.0], ["mushroom", 1, 1.0, 38.0]]],
				]}
		&"lvl_13":
			# LE PENTACLE BRISE, la fin de l acte : il ne s ouvre qu apres les
			# QUATRE demons (requires_all_previous, revue A4 §2.7 point 8). Un
			# ordinaire neuf : la Reine gorgone recollee (« elle en garde la porte »,
			# le boss du lvl_02, trois actes plus tard) ; tout l acte 4 y descend.
			# COMMUNE NOUVELLE : le Meteore, le gros coup charge. MINI-BOSS : l Echo
			# du Mage noir (le boss du lvl_18). BOSS : Malyk, qui porte les ordres
			# et mange ce qu il appelle.
			return {"nom": "Le pentacle brise", "acte": 4, "sous_titre": "Celui qui porte les ordres",
				"intro": _intro_existante(&"lvl_13"),
				"scene_avant": "lvl_13_intro", "scene_apres": "lvl_13_outro", "fond": "act3_demon",
				"suite": ["lvl_14"], "tous_les_precedents": true,
				"communes": ["meteor", "arcane_bolt", "spark"],
				"vagues": [
					["w13_1", 27.0, 1.35, "", [["demon_slime", 1, 1.0, 0.0], ["mirror_shard", 2, 2.5, 6.0],
						["mushroom", 2, 2.0, 14.0], ["carnivore_plant", 2, 1.8, 20.0]]],
					["w13_2", 28.0, 1.4, "", [["glutton", 1, 1.0, 0.0], ["cacodaemon", 2, 2.4, 6.0],
						["blood_clot", 1, 1.0, 14.0], ["executioner_aide", 1, 1.0, 20.0]]],
					["w13_3_miniboss", 36.0, 1.1, "MINI", [["dark_mage_echo", 1, 1.0, 0.0], ["gorgon_queen_mended", 1, 1.0, 8.0],
						["pit_novice", 1, 1.0, 16.0], ["grave_mourner", 1, 1.0, 24.0]]],
					["w13_4", 31.0, 1.2, "", [["totem_cracked", 1, 1.0, 0.0], ["gorgon_queen_mended", 1, 1.0, 6.0],
						["mirror_shard", 1, 1.0, 12.0], ["demon_slime", 1, 1.0, 18.0], ["carnivore_plant", 2, 1.8, 24.0]]],
					["w13_5_boss", 50.0, 1.05, "BOSS", [["demon_lord", 1, 1.0, 0.0], ["glutton", 1, 1.0, 12.0],
						["mushroom", 2, 2.2, 24.0], ["executioner_aide", 1, 1.0, 34.0]]],
				]}
		# ================================ ACTE 5 ================================
		&"lvl_14":
			# LA GALERIE DES SAISONS : « le Gardien de la foret est dans une vitrine,
			# il y en a un par saison ». Cinq ordinaires neufs, tous d anciennes
			# tetes : l Echo du Gardien et l Echo de Chronos (les boss de l acte 1),
			# le Noyau errant (le Golem a noyau du lvl_07), les Jumeaux pales (les
			# Jumeaux du lvl_12), l Adepte du givre (le trio du lvl_19). COMMUNE
			# NOUVELLE : la Precipitation. MINI-BOSS : le Cameleon des saisons.
			# BOSS : le Slime colossal, qui se divise en deux Slimes enormes.
			return {"nom": "La galerie des saisons", "acte": 5, "sous_titre": "Ce qui a deja ete efface, expose",
				"intro": _intro_existante(&"lvl_14"),
				"scene_avant": "lvl_14_intro", "scene_apres": "lvl_14_outro", "fond": "act5_divine",
				"suite": ["lvl_15"],
				"communes": ["quickening", "arcane_bolt", "fireball"],
				"vagues": [
					["w14_1", 27.0, 1.4, "", [["warden_echo", 1, 1.0, 0.0], ["adept_frost", 2, 2.5, 6.0],
						["chronos_echo", 1, 1.0, 14.0], ["core_drifter", 1, 1.0, 22.0]]],
					["w14_2", 29.0, 1.45, "", [["warden_echo", 2, 4.0, 0.0], ["twins_pale", 1, 1.0, 10.0],
						["rat_swarm", 2, 2.2, 16.0], ["adept_frost", 1, 1.0, 24.0]]],
					["w14_3_miniboss", 33.0, 1.1, "MINI", [["season_chameleon", 1, 1.0, 0.0], ["core_drifter", 1, 1.0, 6.0],
						["twins_pale", 1, 1.0, 14.0], ["sleepy_fox", 2, 2.4, 20.0]]],
					["w14_4", 33.0, 1.45, "", [["warden_echo", 3, 4.0, 0.0], ["chronos_echo", 1, 1.0, 14.0],
						["adept_frost", 1, 1.0, 20.0], ["core_drifter", 1, 1.0, 26.0]]],
					["w14_5_boss", 48.0, 1.0, "BOSS", [["slime_colossal", 1, 1.0, 0.0], ["twins_pale", 1, 1.0, 20.0],
						["adept_frost", 1, 1.0, 28.0], ["hopper", 2, 2.0, 34.0]]],
				]}
		&"lvl_15":
			# LE REGISTRE : « ta ligne est la, et la date a ete raturee une fois ».
			# Deux ordinaires neufs : l Adepte de braise et l Adepte des arcanes (le
			# trio du lvl_19) ; l Eclat de miroir revient. COMMUNE : PAS DE COMMUNE
			# FRAICHE (voir l en-tete) — la Fleche percante, le sort de la premiere
			# fois, reprise ici. MINI-BOSS : le Greffier, qui vole une carte et la
			# lance contre toi. BOSS : l Horloger (la scene le nomme), qui revient
			# trois secondes en arriere.
			return {"nom": "Le registre", "acte": 5, "sous_titre": "Ton nom y est, avec une date",
				"intro": _intro_existante(&"lvl_15"),
				"scene_avant": "lvl_15_intro", "scene_apres": "lvl_15_outro", "fond": "act5_divine",
				"suite": ["lvl_16"],
				"communes": ["piercing_arrow", "fireball", "quickening"],
				"vagues": [
					["w15_1", 28.0, 1.4, "", [["adept_frost", 2, 2.5, 0.0], ["adept_ember", 1, 1.0, 8.0],
						["warden_echo", 1, 1.0, 14.0], ["shade", 2, 2.0, 20.0]]],
					["w15_2", 30.0, 1.45, "", [["chronos_echo", 1, 1.0, 0.0], ["adept_arcane", 1, 1.0, 8.0],
						["twins_pale", 1, 1.0, 14.0], ["core_drifter", 1, 1.0, 20.0], ["mirror_shard", 1, 1.0, 26.0]]],
					["w15_3_miniboss", 36.0, 1.1, "MINI", [["spell_clerk", 1, 1.0, 0.0], ["adept_ember", 2, 2.5, 8.0],
						["warden_echo", 1, 1.0, 18.0], ["mirror_shard", 1, 1.0, 26.0]]],
					["w15_4", 32.0, 1.5, "", [["chronos_echo", 1, 1.0, 0.0], ["mirror_shard", 2, 2.5, 8.0],
						["adept_arcane", 1, 1.0, 16.0], ["adept_frost", 1, 1.0, 22.0], ["twins_pale", 1, 1.0, 26.0]]],
					["w15_5_boss", 48.0, 1.0, "BOSS", [["clockmaker", 1, 1.0, 0.0], ["adept_arcane", 1, 3.0, 14.0],
						["adept_ember", 1, 1.0, 22.0], ["core_drifter", 1, 1.0, 30.0]]],
				]}
		&"lvl_16":
			# LE SIEGE VIDE : « des adversaires qui ont ferme des actes entiers
			# arrivent par trois ». Ceux que la regle des promotions laisse revenir :
			# l Echo du Gardien (acte 1), l Echo de l Ensevelisseur (acte 2, le seul
			# ordinaire neuf) et l Echo du Sceau (acte 3, le mini-boss). COMMUNE :
			# PAS DE COMMUNE FRAICHE — le Trait arcanique, le premier sort : l Enfant
			# ne craint que l arcane. La Lumiere purifiante tourne (l Echo du Sceau
			# protege). BOSS : l Enfant.
			return {"nom": "Le siege vide", "acte": 5, "sous_titre": "Il est vide depuis toujours",
				"intro": _intro_existante(&"lvl_16"),
				"scene_avant": "lvl_16_intro", "scene_apres": "lvl_16_outro", "fond": "act5_divine",
				"suite": [],
				"communes": ["arcane_bolt", "purifying_light", "fireball"],
				"vagues": [
					["w16_1", 28.0, 1.45, "", [["warden_echo", 2, 4.0, 0.0], ["adept_frost", 1, 1.0, 8.0],
						["chronos_echo", 1, 1.0, 18.0], ["core_drifter", 1, 1.0, 24.0]]],
					["w16_2", 30.0, 1.5, "", [["gravecaller_echo", 1, 1.0, 0.0], ["adept_ember", 2, 2.5, 8.0],
						["twins_pale", 1, 1.0, 18.0], ["adept_arcane", 1, 1.0, 24.0]]],
					["w16_3_miniboss", 32.0, 1.1, "MINI", [["tombol_echo", 1, 1.0, 0.0], ["warden_echo", 1, 1.0, 10.0],
						["gravecaller_echo", 1, 1.0, 18.0], ["adept_frost", 1, 1.0, 24.0]]],
					["w16_4", 31.0, 1.5, "", [["chronos_echo", 1, 1.0, 0.0], ["warden_echo", 1, 1.0, 8.0],
						["gravecaller_echo", 1, 1.0, 14.0], ["core_drifter", 1, 1.0, 20.0], ["adept_arcane", 1, 1.0, 26.0]]],
					["w16_5_boss", 60.0, 1.0, "BOSS", [["child_god", 1, 1.0, 0.0]]],
				]}
	printerr("Niveau %s absent de la table des niveaux" % id)
	return {}


## L intro d un niveau telle que le chantier B4 l a ecrite, recopiee ici pour
## que la table se lise en entier.
func _intro_existante(id: StringName) -> String:
	return String(_INTROS_B4.get(id, ""))


## Les intros (briefing) du chantier B4, telles quelles.
const _INTROS_B4: Dictionary = {
	&"lvl_01": "La foret de Nuri, six jours avant sa fin. Tu as remonte le temps jusqu a ce matin-la pour trouver d ou vient le mal. Ce n est que de la vermine de foret, mais elle marche en colonne, et la vermine ne marche pas en colonne.",
	&"lvl_02": "Le village de l enfant est debout, et ses gens aussi : en pierre, figes au milieu d un geste. Des gorgones rodent encore. Tant qu une gorgone vit, son regard fige des sorts dans ta main : abats-la avant tout le reste.",
	&"lvl_03": "Passe le port, les iles ne portent plus que des tombes, rangees et numerotees. Ici les morts sont tries et comptes, et les Pretres goules tiennent les registres. On ne pleure pas les morts de l ossuaire : on les compte.",
	&"lvl_04": "Tu arrives trop tard : le cercle est deja trace et les Pretres goules chantent. Tu ne peux plus empecher la Grande Invocation. Tu peux seulement etre la quand le cercle s ouvrira, pour voir ce qui en sortira.",
	&"lvl_05": "Sous la cour des rois, l escalier ne mene pas a une crypte : il mene a une forge qui tourne a plein, rouge de ce qui remonte d en dessous. Tombol enterre ses morts, elle ne coule pas d armures. Ici, rien n est ne : tout a ete coule.",
	&"lvl_06": "La salle du trone de Tombol, deja rougie par ce qui remonte du puits. Le roi a fui sans dire a qui revenait le trone, et sa cour s entretue pour l avoir. Personne ne t attend. Tout le monde te tuera quand meme, en passant.",
	&"lvl_07": "Une forge sans forgeron, ou tout ce qui bouge porte une armure. Vharn ne parle pas et ne se presse pas : il encaisse. Tes premiers sorts ne lui feront rien du tout, et il faudra que tu le voies pour le croire.",
	&"lvl_08": "Le maire s est tu pendant des mois. Ce n est pas Nuri qui tombe, c est toute l ile, et ca vient d en haut. Entre la grange et la clairiere, la route grouille : des gelees qui se coupent en deux, des ruches qui eclatent. Frappe large ou ne frappe pas.",
	&"lvl_09": "Le rat pilote repare sous la carcasse et ne veut voir personne. Tiens la clairiere le temps qu il faut. Au fond, les arbres s ecartent d eux-memes : le Gardien de la foret vient, et il ne marche pas entre les arbres.",
	&"lvl_10": "Des fosses tiedes ou le sol remue. Sesh ne commande a rien : il a FAIM, et ses sujets sont ce qui n a pas encore ete avale. Ce que tu laisses derriere toi ne t attend pas, il le nourrit.",
	&"lvl_11": "Une arene de sable noir, et des chaines partout : Kaltek ne tient pas ses esclaves, il les FABRIQUE. Chaque coup que tu lui rends le rend plus rapide. Ici, aller vite est une erreur : c est le seul niveau qui te le dira.",
	&"lvl_12": "Un temple de cristal ou tout est protege par autre chose. Ymoa ne descendra pas : il reste au fond et tient son cercle. Tant qu il vit, ce que tu frappes ne sent rien. Va le chercher.",
	&"lvl_13": "Au centre du monde demoniaque, le pentacle. La Reine gorgone, recollee, en garde la porte ; derriere, Malyk porte les ordres que les seigneurs ont recus sans les lire. Le pentacle tient ce monde, et il n a jamais ete a eux.",
	&"lvl_14": "Il n y a pas de sol. Il y a une galerie, et dans la galerie tout ce que tu as deja tue, range par saison. Le Gardien de la foret est dans une vitrine, et il n est pas seul : il y en a un par saison.",
	&"lvl_15": "Des colonnes de noms qui montent plus haut que le regard. Ce n est pas une liste de morts : c est un CALENDRIER. L humanite n a pas ete attaquee, elle etait programmee pour s eteindre, a la date prevue. Ta ligne est la, et la date a ete raturee une fois.",
	&"lvl_16": "Au bout du registre, un siege. Il est vide depuis toujours, et personne ne le garde. Ce qui descend vers toi, l enfant l envoie sans y penser : des adversaires qui ont ferme des actes entiers arrivent par trois, sans un nom.",
	&"lvl_17": "Le dirigeable monte dans les courants et tout ce qui t y attend vole. Les Planogos passent au-dessus des murs, les Oeils se laissent porter et ne vont jamais droit, l Archer ne descend pas du tout. Couvre le ciel ou ne couvre rien.",
	&"lvl_18": "Haute-Nacelle a ete videe par le haut, pas par le bas. Sur les quais, trois facons de te tromper : le Chevalier du vide avale ton premier coup, le Berserker accelere a chaque coup recu, et les Pillards n arrivent meme pas par la ou tu regardes.",
	&"lvl_19": "Tombol commence par le bas : des fosses ouvertes ou l on avance dans l eau. Les Pretres goules y soignent tout ce qui marche, et ils se soignent entre eux. Contre eux, frapper fort et frapper juste sont deux choses differentes.",
	&"lvl_20": "Une cour de statues, et sous chaque statue un Gardien-totem qui rend ses voisins intouchables. Tu ne choisis plus ou frapper : il faut d abord abattre celui qui protege, et il se protege lui-meme derriere ceux qu il protege.",
	&"lvl_21": "Au fond de Tombol, une salle et un pentacle qui tourne. Le Roi squelette est accule contre lui et il ne se bat pas : il te dit qu il a signe pour SAUVER son royaume, et que ce qui monte de ce puits ne negocie pas. L adversaire de cette salle n est pas le roi. C est le sceau.",
}


## Un objectif par CONTROLE (cle + parametres) : deux niveaux qui demandent la
## meme chose partagent la meme ressource, et le meme identifiant.
var _objectifs_faits: Dictionary = {}

## Les trois objectifs historiques gardent leur identifiant : la sauvegarde
## range les etoiles par id d objectif, un joueur qui avait « sans degats »
## sur un niveau qui le porte encore le garde.
const _IDS_HISTORIQUES: Dictionary = {
	&"never_dropped_speed": &"obj_max_speed",
	&"no_legendary_used": &"obj_no_legendary",
	&"no_damage_taken": &"obj_untouched",
}


func _purger_objectifs() -> void:
	_objectifs_faits.clear()
	var dir := DirAccess.open("res://resources/objectives")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tres"):
			dir.remove(f)


## Identifiant DEDUIT du controle : "obj_multi_kill_5_2" dit ce qu il demande.
## Un reglage de seuil change donc l identifiant, et c est voulu : une etoile
## gagnee a 20 lancers ne doit pas valoir pour un objectif passe a 30.
func _id_objectif(key: StringName, params: Dictionary) -> StringName:
	if params.is_empty() and _IDS_HISTORIQUES.has(key):
		return _IDS_HISTORIQUES[key]
	var noms: Array = params.keys()
	noms.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var id: String = "obj_" + String(key)
	for n in noms:
		id += "_" + str(params[n]).to_lower().replace(".", "_")
	return StringName(id)


func _objectif(key: StringName, params: Dictionary = {}) -> ObjectiveDef:
	var id: StringName = _id_objectif(key, params)
	if _objectifs_faits.has(id):
		return _objectifs_faits[id]
	var o := ObjectiveDef.new()
	o.id = id
	o.check_key = key
	o.params = params.duplicate()
	# La description est le libelle GENERE : elle ne sert que de repli, et un
	# repli qui dirait autre chose que l ecran serait un second texte a tenir.
	o.description = ObjectiveChecker.label(o)
	for err in ObjectiveChecker.validate(o):
		printerr("Objectif %s invalide : %s" % [id, err])
	_save(o, "res://resources/objectives/%s.tres" % id)
	_objectifs_faits[id] = o
	return o


## Pose sur le niveau ce que LA table (_progression_de) dit de lui : ses trois
## objectifs, la carte que chacun debloque (meme position) et le passif que sa
## victoire debloque. `levelup_cards` reste vide (voir l en-tete de la campagne).
func _poser_progression(lvl: LevelDef) -> void:
	var t: Dictionary = _progression_de(lvl.id)
	var objectifs: Array[ObjectiveDef] = []
	var recompenses: Array[SpellCard] = []
	for ligne: Array in t.get("objectifs", []):
		objectifs.append(ligne[0])
		recompenses.append(_carte(ligne[1]))
	lvl.objectives = objectifs
	lvl.objective_rewards = recompenses
	lvl.levelup_cards = [] as Array[SpellCard]
	var passifs: Array[SpellCard] = []
	for id: String in t.get("passifs", []):
		passifs.append(_carte(id))
	lvl.passive_unlocks = passifs


## Une carte du catalogue par son id, quel que soit son dossier (passifs compris).
func _carte(id: String) -> SpellCard:
	for dossier in ["common", "rare", "epic", "legendary", "passive"]:
		var chemin: String = "res://resources/cards/%s/%s.tres" % [dossier, id]
		if ResourceLoader.exists(chemin):
			return load(chemin)
	printerr("Carte inconnue dans la table de progression : %s" % id)
	return null


## Une longueur de terrain en pixels (enemy_travel s ecrit en pixels, se lit en
## longueurs : voir ObjectiveChecker.terrain_length).
func _longueurs(n: float) -> float:
	return n * ObjectiveChecker.terrain_length()


## LA TABLE DE PROGRESSION, dans l ordre de jeu (vague 10, chantier B2).
##
## Pour chaque niveau : ses trois objectifs, CLASSES par le banc des objectifs
## (le plus facile d abord ; la position est le rang), la carte que chacun
## debloque (rang 1 rare, 2 epique, 3 legendaire), et le passif que sa victoire
## debloque a partir de l acte 2.
##
## LES OBJECTIFS. Deux sur trois au moins sont LIES au niveau : une des trois
## communes du deck (la jouer, s en passer, tuer avec), une espece de ses
## vagues, ses volants, sa garde ; le troisieme peut etre un pari de fin de
## combat. Les exemples du co-auteur sont gardes a la lettre (Fleche percante,
## sans Boule de feu, plus de 300 %, 4 Oiseaux mirage d un sort, 8 morts en
## moins d une seconde, ne pas etre touche par le Lutin archer, prendre le coup
## du Renard, sans perdre de vie, sans legendaire, le meme sort 30 fois, sous
## 120 %). Les taux mesures sont dans test_level_progression.MESURES.
##
## LE REGLAGE AU BANC (17/10). Un seuil de chrono ou de vitesse se lit sur les
## temps et les vitesses des victoires du bot tel quel (le banc des objectifs
## les ecrit avec --detail) ; le reste a ete joue en lots de candidats, plus de
## trois objectifs par niveau le temps d une mesure : une partie ne depend pas
## des AUTRES objectifs du niveau (memes empreintes, partie par partie, avec 3
## ou 9 objectifs). Le commentaire de chaque niveau dit ce qui a ete ecarte.
##
## LES RECOMPENSES suivent la table du co-auteur (voir l en-tete de la
## campagne) ; le commentaire de chaque niveau dit quel trait du niveau chaque
## carte repond. Les rares et les legendaires sont toutes donnees ; parmi les
## epiques, seule la Concentration ne l est pas (aucun niveau n en appelle la
## reponse : elle va aux quetes annexes).
##
## LES PASSIFS (un par niveau a partir de l acte 2, 17 sur les 24 qui ne sont
## pas de base) suivent l element de la commune nouvelle du niveau, ou sa
## mecanique. Les sept autres vont aux quetes annexes : Reaction en chaine,
## Glace mordante, Debordement, Venin corrosif, Reflexe de l eclair, Surtension,
## Verrou temporel.
func _progression_de(level_id: StringName) -> Dictionary:
	match level_id:
		&"lvl_01":
			# R : Entrave temporelle (les Lutins fileurs sautent vite -> un
			# ralentissement). E : Resonance (les nuees -> une zone). L : Faille
			# temporelle (l echeance de Chronos -> des sorts rapides).
			# Banc (17/10) : la Fleche 9 fois ne se ratait plus (60 / 60), 12 fois
			# (15 : 18 / 60) ; aucune victoire au-dessus de 250 % (le niveau dure
			# une minute), 240 %.
			return {"objectifs": [
				[_objectif(&"card_casts", {"card": "piercing_arrow", "count": 12}), "temporal_drag"],
				[_objectif(&"no_card", {"card": "fireball"}), "resonance"],
				[_objectif(&"win_above_speed", {"pct": 240}), "time_rift"],
			]}
		&"lvl_02":
			# Les gorgones figent la main -> la pioche aux trois rangs : Flux de
			# mana, Intuition arcanique, Registre des marees.
			return {"objectifs": [
				[_objectif(&"card_casts", {"card": "cycle_of_thought", "count": 6}), "mana_flow"],
				[_objectif(&"kill_type_with_card", {"enemy": "gorgon_gazer", "card": "arcane_bolt", "count": 3}), "arcane_insight"],
				[_objectif(&"win_above_speed", {"pct": 300}), "tide_ledger"],
			]}
		&"lvl_08":
			# Les gelees craignent le feu et les nuees veulent une zone : Brasier,
			# Marque de faiblesse, Pluie de meteorites.
			# Banc (17/10) : 8 petites gelees a la Boule de feu tombaient a 12 / 60,
			# sous les 4 Oiseaux mirage d un sort (22) ; 15 morts en une seconde,
			# jamais. Sans la Fleche (55), puis finir sous 130 %.
			return {"objectifs": [
				[_objectif(&"no_card", {"card": "piercing_arrow"}), "brazier"],
				[_objectif(&"kill_type_one_cast", {"enemy": "rat_swarm", "count": 4}), "weakness_mark"],
				[_objectif(&"win_below_speed", {"pct": 130}), "meteor_storm"],
			]}
		&"lvl_09":
			# Le Renard -> un sort rapide (Focalisation, 0,7 s) ; l armure du Gardien
			# -> la dissipation (Vide d emprise) ; Echo de la main (les sorts gardes
			# en main pendant le sommeil du Renard).
			# Banc (17/10) : le coup du Renard ne se ratait plus ici (60 / 60 ; il
			# reste au lvl_14) ; sans le Trait arcanique (56) a sa place.
			return {"objectifs": [
				[_objectif(&"no_card", {"card": "arcane_bolt"}), "focus"],
				[_objectif(&"kill_type_with_card", {"enemy": "gnome", "card": "spark", "count": 10}), "void_grip"],
				[_objectif(&"win_below_speed", {"pct": 200}), "echo_of_the_hand"],
			]}
		&"lvl_17":
			# Tout vole et rien ne va droit -> le controle : Onde de repulsion (vent,
			# que les volants craignent), Maelstrom, Metier du monde.
			# Banc (17/10) : ne pas etre touche par le Lutin archer ne se reussissait
			# jamais (0 / 60, il est au lvl_03) ; le Serpent des sables, que le vent
			# repousse, parcourt seul 5 longueurs (45 / 60) mais jamais 12. Le Vent du
			# sud 5 fois (46), 12 volants (37), finir sous 170 % (10).
			return {"objectifs": [
				[_objectif(&"card_casts", {"card": "south_wind", "count": 5}), "repulsion_wave"],
				[_objectif(&"kill_flying", {"count": 12}), "maelstrom"],
				[_objectif(&"win_below_speed", {"pct": 170}), "world_loom"],
			], "passifs": ["pass_wind_tailwind"]}
		&"lvl_18":
			# Le Mage noir et les archers tirent -> des murs (Mur de glace,
			# Bastion) ; les pillards arrivent de partout -> la Riviere, qui les
			# force a un pont.
			# Banc (17/10) : ne pas etre touche par le Mage noir (ni par le Lutin
			# archer) ne se reussissait jamais ; sans la Flechette (18 / 60) a sa
			# place, entre les pillards (29) et la vitesse basse (16).
			return {"objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "nacelle_raider", "card": "fireball", "count": 5}), "ice_wall"],
				[_objectif(&"no_card", {"card": "venom_dart"}), "bastion"],
				[_objectif(&"win_below_speed", {"pct": 190}), "terrain_river"],
			], "passifs": ["pass_poison_linger"]}
		&"lvl_03":
			# Le Reliquaire compte les COUPS -> l Apprenti miroir, qui en porte
			# beaucoup ; les nuees de l ossuaire -> le Totem (un appat) et la Mare
			# de venin (le poison passe la garde du Gardien d ossements).
			# Banc (17/10) : les deux exemples du co-auteur « 8 morts en moins d une
			# seconde » (16 / 60) et « ne pas se faire toucher par un Lutin archer »
			# (1 / 60 : ses deux archers tirent avant de tomber ; 0 / 60 aux
			# lvl_17 et lvl_18, ou ils sont plus nombreux) sont ici.
			return {"objectifs": [
				[_objectif(&"card_casts", {"card": "frost_rain", "count": 20}), "heartwood_totem"],
				[_objectif(&"multi_kill", {"count": 8, "window": 1}), "mirror_apprentice"],
				[_objectif(&"no_hit_from", {"enemy": "imp_archer"}), "venom_mire"],
			], "passifs": ["pass_ice_winter"]}
		&"lvl_04":
			# L Ensevelisseur invoque sans fin -> de la duree : Ronces, Autel
			# d appel, Clef de l Appel.
			# Banc (17/10) : le niveau dure plus de trois minutes (la plus rapide
			# des victoires : 136 s) ; le chrono passe de 140 s (2 / 60) a 195 s.
			# Le Serpent des sables sur 2,5 longueurs (9) : le defi du co-auteur,
			# ici ou le Mur de pierre fait marcher.
			return {"objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "risen_ghoul", "card": "frost_rain", "count": 4}), "terrain_brambles"],
				[_objectif(&"win_under_time", {"seconds": 195}), "terrain_altar"],
				[_objectif(&"enemy_travel", {"enemy": "sand_serpent", "distance": _longueurs(2.5)}), "summoners_key"],
			], "passifs": ["pass_nature_roots"]}
		&"lvl_19":
			# Les goules ressortent et les fantomes zigzaguent -> la Volte-face ; la
			# Sorciere invoque -> le Semis (de la duree) ; les nuees de goules -> le
			# Cadran des forges.
			# Banc (17/10) : 40 sorts de feu (7 / 60) etaient plus durs que ne pas
			# etre touche par une goule (60) et que le chrono de 130 s (58). Les
			# goules a la Mare de braises (14 : 58), 28 sorts de feu (49), et
			# l exemple du co-auteur « sans perdre de vie » (7) : mesure dans douze
			# niveaux, le bot ne le reussit qu ici (1 / 60 au lvl_05, 0 ailleurs).
			return {"objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "pit_ghoul", "card": "ember_pool", "count": 14}), "about_face"],
				[_objectif(&"element_casts", {"element": "FIRE", "count": 28}), "blight_sapling"],
				[_objectif(&"no_damage_taken"), "forge_dial"],
			], "passifs": ["pass_fire_embers"]}
		&"lvl_20":
			# L Epeiste fonce par a-coups -> le ralentissement aux trois rangs :
			# Entrave temporelle, Gel profond, Sablier fendu.
			# Banc (17/10) : sans la Lumiere et la Fleche 21 fois ne se rataient
			# jamais (60 / 60) ; sans la Mare de braises, le bot ne gagne plus (0).
			# 2 Squelettes a parade d un sort (53), la Fleche 34 fois (37 ; 26 :
			# 56), finir sous 250 % (7 ; sous 170 % : 1).
			return {"objectifs": [
				[_objectif(&"kill_type_one_cast", {"enemy": "parry_skeleton", "count": 2}), "temporal_drag"],
				[_objectif(&"card_casts", {"card": "piercing_arrow", "count": 34}), "deep_freeze"],
				[_objectif(&"win_below_speed", {"pct": 250}), "hourglass_shard"],
			], "passifs": ["pass_arcane_mind"]}
		&"lvl_05":
			# Le Colosse craint la glace -> le Mur de glace (l exemple du co-auteur :
			# enferme, il le frappe moins fort) ; les tanks -> les doubleurs : Fosse,
			# Canalisation jumelle.
			# Banc (17/10) : le bot finit presque toujours a 500 % ici (plus de
			# 310 % : 60 / 60) et 30 sorts arcaniques ne se rataient jamais ; 80
			# sorts arcaniques (56 ; 95 : 36), puis un chrono de 142 s (11).
			return {"objectifs": [
				[_objectif(&"element_casts", {"element": "ARCANE", "count": 80}), "ice_wall"],
				[_objectif(&"kill_type_one_cast", {"enemy": "golem", "count": 2}), "terrain_pit"],
				[_objectif(&"win_under_time", {"seconds": 142}), "twin_channeling"],
			], "passifs": ["pass_water_spring"]}
		&"lvl_06":
			# Les Sauterelles et les Ombres bougent mal -> le controle : Nappe
			# montante, Racine de tonnerre ; le Seigneur Spectre et sa cour -> la
			# Pluie de meteorites.
			return {"objectifs": [
				[_objectif(&"element_casts", {"element": "NATURE", "count": 8}), "tidal_pool"],
				[_objectif(&"kill_type_one_cast", {"enemy": "hopper", "count": 3}), "thunder_root"],
				[_objectif(&"win_under_time", {"seconds": 110}), "meteor_storm"],
			], "passifs": ["pass_nature_sap"]}
		&"lvl_21":
			# Le Sceau invoque -> les Ronces (de la duree) ; il protege -> le Vide
			# d emprise ; les vers craignent l eau -> la Riviere.
			# Banc (17/10) : aucune victoire en moins de 90 s (la plus rapide :
			# 104 s) ; 135 s.
			return {"objectifs": [
				[_objectif(&"no_card_tag", {"tag": "FIRE"}), "terrain_brambles"],
				[_objectif(&"kill_type_with_card", {"enemy": "fire_worm", "card": "arcane_bolt", "count": 5}), "void_grip"],
				[_objectif(&"win_under_time", {"seconds": 135}), "terrain_river"],
			], "passifs": ["pass_water_flood"]}
		&"lvl_07":
			# Vharn est un tank qui compte les coups -> les doubleurs : Focalisation,
			# Marque de faiblesse, Canalisation jumelle.
			# Banc (17/10) : la Spirale de sel ne se ratait jamais, meme 22 fois
			# (60 / 60), ni 2 champignons d un sort (59). Sans l Etincelle (59),
			# 3 champignons d un sort (19), plus de 380 % (9).
			return {"objectifs": [
				[_objectif(&"no_card", {"card": "spark"}), "focus"],
				[_objectif(&"kill_type_one_cast", {"enemy": "mushroom", "count": 3}), "weakness_mark"],
				[_objectif(&"win_above_speed", {"pct": 380}), "twin_channeling"],
			], "passifs": ["pass_wind_gale"]}
		&"lvl_10":
			# Les nuees qui nourrissent Sesh -> le Brasier ; les Cacodemons
			# rebondissent -> le Maelstrom ; Sesh est lent -> la Mare de venin.
			# Banc (17/10) : les trois Cacodemons tombent toujours (60 / 60), aucune
			# partie sans degats ni Cacodemon sur 1,5 longueur (0). Sans le Trait
			# arcanique (56), 4 champignons a la Pluie de givre (34), plus de 320 %
			# (10).
			return {"objectifs": [
				[_objectif(&"no_card", {"card": "arcane_bolt"}), "brazier"],
				[_objectif(&"kill_type_with_card", {"enemy": "mushroom", "card": "frost_rain", "count": 4}), "maelstrom"],
				[_objectif(&"win_above_speed", {"pct": 320}), "venom_mire"],
			], "passifs": ["pass_fireboom"]}
		&"lvl_11":
			# Kaltek et ses Berserkers accelerent -> le ralentissement aux trois
			# rangs : Entrave temporelle, Gel profond, Metier du monde.
			return {"objectifs": [
				[_objectif(&"element_casts", {"element": "ICE", "count": 32}), "temporal_drag"],
				[_objectif(&"kill_flying", {"count": 1}), "deep_freeze"],
				[_objectif(&"win_below_speed", {"pct": 120}), "world_loom"],
			], "passifs": ["pass_frostbite"]}
		&"lvl_12":
			# Ymoa campe et tire -> le Bastion ; tout est protege -> le Totem (un
			# appat qui les tire hors du cercle) ; Echo de la main (garder la Lumiere).
			# Banc (17/10) : ne pas etre touche par Ymoa est le plus dur (6 / 60),
			# il passe au rang 3 ; la Lumiere (59) et le meme sort (45) avant lui.
			return {"objectifs": [
				[_objectif(&"card_casts", {"card": "purifying_light", "count": 6}), "heartwood_totem"],
				[_objectif(&"same_card_casts", {"count": 30}), "bastion"],
				[_objectif(&"no_hit_from", {"enemy": "demon_circle"}), "echo_of_the_hand"],
			], "passifs": ["pass_echo"]}
		&"lvl_13":
			# La Reine recollee fige une carte -> la pioche : Flux de mana, Pacte
			# imprudent, Registre des marees.
			# Banc (17/10) : 3 plantes carnivores d un sort, jamais ; ne pas etre
			# touche par l Echo du Mage noir, 1 / 60. 22 sorts de feu (51), 2 plantes
			# carnivores d un sort (12).
			return {"objectifs": [
				[_objectif(&"no_legendary_used"), "mana_flow"],
				[_objectif(&"element_casts", {"element": "FIRE", "count": 22}), "reckless_bargain"],
				[_objectif(&"kill_type_one_cast", {"enemy": "carnivore_plant", "count": 2}), "tide_ledger"],
			], "passifs": ["pass_fire_fury"]}
		&"lvl_14":
			# Les Renards dormeurs -> un sort rapide (Focalisation) ; le Slime
			# colossal se divise -> des zones : Resonance, Cadran des forges.
			# Banc (17/10) : ne pas etre touche par l Echo du Gardien (ni par l Echo
			# de Chronos, ni par l Adepte du givre) ne se ratait jamais (60 / 60) ;
			# un chrono de 125 s (9) a sa place.
			return {"objectifs": [
				[_objectif(&"hit_from", {"enemy": "sleepy_fox"}), "focus"],
				[_objectif(&"kill_type_one_cast", {"enemy": "rat_swarm", "count": 3}), "resonance"],
				[_objectif(&"win_under_time", {"seconds": 125}), "forge_dial"],
			], "passifs": ["pass_arcane_lore"]}
		&"lvl_15":
			# L Horloger revient en arriere -> le controle (Volte-face) ; le Greffier
			# vole une carte -> la pioche (Intuition) ; Sablier fendu (le temps).
			# Banc (17/10) : 30 sorts de feu ne se rataient jamais, 40 (58 / 60 ; 50 :
			# 30) ; ne jamais frapper une garde de renvoi (21) est plus dur que
			# finir au-dessus de 380 % (37) : rangs 2 et 3 echanges.
			return {"objectifs": [
				[_objectif(&"element_casts", {"element": "FIRE", "count": 40}), "about_face"],
				[_objectif(&"win_above_speed", {"pct": 380}), "arcane_insight"],
				[_objectif(&"never_hit_reflect"), "hourglass_shard"],
			], "passifs": ["pass_dual"]}
		&"lvl_16":
			# L Enfant renvoie les coups -> l Elan du temps rend la vitesse perdue ;
			# il fige trois cartes -> l Epuration (moins de cartes inutiles) et le
			# Registre des marees (la pioche).
			# Banc (17/10) : ne pas etre touche par l Echo de l Ensevelisseur et 50
			# sorts arcaniques ne se rataient jamais (60 / 60) ; 70 sorts arcaniques
			# (56 ; 85 : 31) au rang 1, un chrono de 145 s (12) au rang 3.
			return {"objectifs": [
				[_objectif(&"element_casts", {"element": "ARCANE", "count": 70}), "time_surge"],
				[_objectif(&"boss_quick_after_revive", {"seconds": 9}), "deck_purge"],
				[_objectif(&"win_under_time", {"seconds": 145}), "tide_ledger"],
			], "passifs": ["pass_apotheosis"]}
	printerr("Niveau %s absent de la table de progression" % level_id)
	return {}


# =====================================================================
# VAGUE 10, CHANTIER B1b — DEUX AMELIORATIONS MAJEURES PAR SORT
#
# Demande du co-auteur (14/10) : « des options de montee de niveau enormes,
# deux par carte, qui modifient carrement la structure du sort mais en echange
# de grosses diminutions ». Le moteur (MajorUpgradeDef, RunState section
# MAJEURES, chantier A1) sait les appliquer ; ici, le CONTENU.
#
# REGLES TENUES PAR LA TABLE (verrouillees par test_majeures_contenu) :
#   - deux majeures par sort, d ids et de structures differentes ; un passif ne
#     murit pas, il n en a pas ;
#   - chaque majeure change la STRUCTURE : add_effect, duplicate, repeat, un set
#     d un param de COMPORTEMENT (angle, decalage, blocks_flyers, unbreakable,
#     grow, residu...) ou une incantation SOUS x0,3 (« quasi instantane »).
#     Jamais un simple chiffre : un set de magnitude ou de duree, une portee,
#     des PV ne font que ce que font deja les voies (C7b, vague 10 : cinq
#     majeures ne changeaient qu un chiffre et passaient le test) ;
#   - chaque PRIX est une op « axis » negative qui MORD sur ce sort (un axe que
#     le sort n a pas serait un prix affiche et jamais paye) : le texte rouge
#     s ecrit seul et le bot du banc le lit (AutoPick.major_acceptable) ;
#   - un effet ajoute porte l ELEMENT de la carte (combat_tags), meme quand il
#     emprunte le VERBE d un autre element (une aspiration sur un brasier, un
#     ralentissement sur une nappe) : le texte ne nomme JAMAIS un autre element
#     que celui de la carte. Les resistances en dependent ; C7b a retire neuf
#     « (effet de vent) », « (effet de glace) »... qui mentaient. Le moteur ne
#     sait pas donner a un effet un element a part (les handlers lisent les tags
#     de la CARTE) ;
#   - texte lisible en portrait sur l ecran de maturation : titre court, une
#     description de deux lignes au plus, sans accents comme le reste des cartes.
#
# POURQUOI APRES _cards() ET EN RECHARGEANT LE .tres : _cards() ecrit chaque
# carte au fil de l eau, et un autre chantier (B1a) y ajoute et deplace des
# cartes. Cette passe retrouve chaque sort PAR SON ID, quel que soit son dossier
# de rarete, et ne touche rien d autre que major_upgrades. Le rechargement
# IGNORE le cache : ContentDB (autoload) a deja charge l ANCIENNE version de
# chaque carte au demarrage, et load() rendrait cette version perimee — on
# re-sauverait alors la carte d avant la generation.
#
# Les copies d un effet (« trois foyers en ligne ») sont faites ICI, depuis
# l effet du .tres tout juste ecrit : elles suivent ses chiffres a chaque
# generation. (Une surcharge de l Atelier du testeur, DEC-043, ne touche que
# l effet d origine : elle ne suit pas dans les copies.)
#
# BANC (15/10, 21 niveaux x 60, sans reglage, base B1a : incantation x1,75) :
# 1159 -> 1169 victoires sur 1260 (x1,9 avant B1a : 1152 -> 1156). Le bot
# prend 83 majeures sur 116 ; en campagne, 534 prises (0,42 par partie),
# 15 majeures distinctes seulement : la deuxieme maturation (24 XP) n est
# atteinte que par les sorts les plus joues (Boule de feu, Trait, Fleche,
# Meteore...). Le reste se jouera en Libre et en Massacre.
#
# C7b (17/10) : la 2e maturation propose les DEUX majeures du sort (plus une
# voie), le joueur choisit ; huit majeures ont recu une vraie structure
# (coup_de_fouet, arret_du_temps, sablier_brise, autel_appat, foudre_tenace,
# puis napalm, fosse_aux_pieux, eclat_purifiant que le test durci a trouves) ;
# neuf textes ne nomment plus un element que l effet n a pas. Banc : rapport C7b.
# =====================================================================

## Les sorts qui recoivent leurs majeures, dans l ordre du catalogue.
const MAJEURES_SORTS: Array[String] = [
	# communes
	"arcane_bolt", "piercing_arrow", "frost_field", "ember_pool", "fireball",
	"frost_rain", "spark", "venom_dart",
	# rares
	"quickening", "temporal_drag", "cycle_of_thought", "mana_flow", "stone_wall",
	"ice_wall", "brazier", "meteor", "about_face", "focus", "salt_spiral",
	"bone_recall", "chain_break", "purifying_light", "repulsion_wave",
	"heartwood_totem", "tidal_pool", "time_surge", "terrain_brambles",
	# epiques
	"mirror_apprentice", "deep_focus", "reckless_bargain", "deck_purge",
	"deep_freeze", "weakness_mark", "resonance", "void_grip", "arcane_insight",
	"bastion", "maelstrom", "blight_sapling", "thunder_root", "terrain_altar",
	"terrain_pit",
	# legendaires
	"time_rift", "tide_ledger", "summoners_key", "forge_dial", "world_loom",
	"hourglass_shard", "echo_of_the_hand", "twin_channeling", "meteor_storm",
	"venom_mire", "terrain_river",
	# vague 10, cartes du chantier B1a
	"south_wind", "electric_mark", "heavy_rain", "quicksand", "water_jet",
]
## Cartes du chantier B1a, absentes tant qu il n est pas fusionne : leur absence
## est ignoree proprement (une ligne au journal). test_majeures_contenu exige
## leur presence des que B1A_FUSIONNE y passe a vrai.
const MAJEURES_ATTENDUES_B1A: Array[String] = [
	"south_wind", "electric_mark", "heavy_rain", "quicksand", "water_jet",
]


func _majeures() -> void:
	var poses: int = 0
	for id in MAJEURES_SORTS:
		var chemins: Array[String] = []
		for dossier in ["common", "rare", "epic", "legendary"]:
			var p: String = "res://resources/cards/%s/%s.tres" % [dossier, id]
			if FileAccess.file_exists(p):
				chemins.append(p)
		if chemins.is_empty():
			if MAJEURES_ATTENDUES_B1A.has(id):
				print("  majeures : %s absent (carte attendue du chantier B1a), ignore" % id)
			else:
				printerr("Majeures : sort introuvable %s" % id)
			continue
		for p in chemins:
			var c: SpellCard = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as SpellCard
			if c == null:
				printerr("Majeures : lecture impossible %s" % p)
				continue
			var typees: Array[MajorUpgradeDef] = []
			for m in _majeures_de(id, c):
				if m is MajorUpgradeDef:
					typees.append(m)
			if typees.size() != 2:
				printerr("Majeures : %s en a %d au lieu de 2" % [id, typees.size()])
			c.major_upgrades = typees
			_save(c, p)
			poses += 1
	print("  majeures posees sur %d sorts" % poses)


# --- Le langage, en court (format exact : MajorUpgradeDef) -------------------

func _mj(id: String, titre: String, texte: String, gains: Array, prix: Array) -> MajorUpgradeDef:
	return MajorUpgradeDef.make(StringName(id), titre, texte, gains, prix)


## Un PRIX : un axe, en part negative (-0.4 = « -40 % »). discard se compte en
## cartes (-1 = « -1 carte defaussee au lancement »).
func _mj_prix(axe: String, pct: float) -> Dictionary:
	return {"op": "axis", "axis": StringName(axe), "pct": pct}


## Le sort se resout de nouveau `delai` s plus tard (vague supplementaire).
func _mj_rejeu(delai: float, facteur: float = 1.0) -> Dictionary:
	return {"op": "repeat", "delay": delai, "factor": facteur}


## Temps d incantation multiplie (0.25 = quatre fois plus court).
func _mj_incant(facteur: float) -> Dictionary:
	return {"op": "cast_time", "factor": facteur}


## Remplace un PARAM des effets `cle` (cle vide = tous les effets).
func _mj_pose(cle: String, param: String, valeur: Variant) -> Dictionary:
	return {"op": "set", "key": StringName(cle), "param": StringName(param), "value": valeur}


## Remplace un CHAMP (magnitude, duration, radius) des effets `cle`.
func _mj_champ(cle: String, champ: String, valeur: float) -> Dictionary:
	return {"op": "set", "key": StringName(cle), "field": champ, "value": valeur}


func _mj_echelle(cle: String, champ: String, facteur: float) -> Dictionary:
	return {"op": "scale", "key": StringName(cle), "field": champ, "factor": facteur}


## Double CHAQUE effet `cle` ; la copie recoit `params` par-dessus les siens.
## Une seule fois par majeure : une seconde op doublerait aussi la premiere copie
## (deux copies identiques). Pour plusieurs copies distinctes : _mj_copie.
func _mj_double(cle: String, params: Dictionary) -> Dictionary:
	return {"op": "duplicate", "key": StringName(cle), "params": params}


## Ajoute un effet ecrit en entier.
func _mj_ajout(cle: String, magnitude: float, duree: float = 0.0, rayon: float = 0.0,
		params: Dictionary = {}) -> Dictionary:
	return {"op": "add_effect", "key": StringName(cle), "magnitude": magnitude,
		"duration": duree, "radius": rayon, "params": params}


## Ajoute une COPIE du premier effet `cle` de la carte, avec `params` en plus
## (decalage de visee, angle). Copie faite depuis le .tres que _cards() vient
## d ecrire : elle porte ses chiffres du moment.
func _mj_copie(c: SpellCard, cle: String, params: Dictionary) -> Dictionary:
	for s in c.effects:
		if s != null and s.key == StringName(cle):
			var copie: EffectSpec = s.duplicate() as EffectSpec
			copie.params = s.params.duplicate(true)
			for p in params:
				copie.params[StringName(str(p))] = params[p]
			return {"op": "add_effect", "spec": copie}
	printerr("Majeures : %s n a pas d effet %s a copier" % [c.id, cle])
	return {"op": "add_effect", "key": StringName(cle)}


## Le premier effet `cle` de la carte (pour lire sa duree, son rayon).
func _mj_effet(c: SpellCard, cle: String) -> EffectSpec:
	for s in c.effects:
		if s != null and s.key == StringName(cle):
			return s
	return null


# --- LA TABLE ----------------------------------------------------------------
#
# Une entree = deux majeures. En commentaire, la STRUCTURE qu elles changent et
# ce qu en fait le bot du banc (AutoPick.major_acceptable : il refuse de perdre
# plus de 30 % sur l axe d identite du sort). Les chiffres sont des points de
# depart : le co-auteur equilibre.

func _majeures_de(id: String, c: SpellCard) -> Array:
	match id:
		# ================= COMMUNES =================
		"arcane_bolt":
			# Cible unique -> eclat de zone ; un trait -> une salve de trois.
			return [
				_mj("eclat_arcanique", "Eclat arcanique",
					"Le trait eclate : 6 degats ARCANIQUES par monstre proche, a chacun d eux",
					[_mj_ajout("damage_per_enemy", 6.0, 0.0, 150.0)],
					[_mj_prix("cast", -0.4)]),
				_mj("salve_arcanique", "Salve arcanique",
					"Trois traits en 1 s ; si la cible tombe, le suivant vise le plus proche",
					[_mj_rejeu(0.5), _mj_rejeu(1.0)],
					[_mj_prix("damage", -0.55)]),
			]
		"piercing_arrow":
			# Les deux exemples du co-auteur : une seconde ligne A COTE de la
			# premiere (parallele, pas en eventail), ou une vague supplementaire.
			return [
				_mj("seconde_ligne", "Seconde ligne",
					"Une seconde ligne de fleches part a cote de la premiere, en parallele",
					[_mj_double("pierce_line", {&"offset_px": 130.0})],
					[_mj_prix("damage", -0.3), _mj_prix("cast", -0.3)]),
				_mj("vague_de_fleches", "Vague de fleches",
					"La volee repart 0,8 s plus tard, dans la meme direction",
					[_mj_rejeu(0.8)],
					[_mj_prix("cast", -0.5)]),
			]
		"frost_field":
			# Une zone -> une rangee de trois ; un controle -> un amplificateur.
			return [
				_mj("barriere_de_givre", "Barriere de givre",
					"Trois champs cote a cote : une barriere de givre sur toute une rangee",
					[_mj_copie(c, "ground_zone", {&"aim_offset": Vector2(-180.0, 0.0)}),
					 _mj_copie(c, "ground_zone", {&"aim_offset": Vector2(180.0, 0.0)})],
					[_mj_prix("area", -0.5), _mj_prix("duration", -0.3)]),
				_mj("engelures", "Engelures",
					"Le givre mord : degats subis x1,4 dedans, et 3 par seconde 4 s apres la sortie",
					[_mj_pose("ground_zone", "vuln_mult", 1.4),
					 _mj_pose("ground_zone", "residue_dps", 3.0),
					 _mj_pose("ground_zone", "residue_duration", 4.0)],
					[_mj_prix("slow", -0.5)]),
			]
		"ember_pool":
			# Un degat qui reste (residu) ; un foyer -> trois en triangle.
			return [
				_mj("braises_collantes", "Braises collantes",
					"Qui sort des braises continue de bruler : 4 degats par seconde pendant 4 s",
					[_mj_pose("ground_zone", "residue_dps", 4.0),
					 _mj_pose("ground_zone", "residue_duration", 4.0)],
					[_mj_prix("area", -0.4)]),
				_mj("semis_de_braises", "Semis de braises",
					"Trois foyers en triangle couvrent tout un carrefour",
					[_mj_copie(c, "ground_zone", {&"aim_offset": Vector2(-150.0, -130.0)}),
					 _mj_copie(c, "ground_zone", {&"aim_offset": Vector2(150.0, -130.0)})],
					[_mj_prix("damage", -0.35), _mj_prix("area", -0.3)]),
			]
		"fireball":
			# Une explosion -> une ligne de trois ; un coup sec -> une nappe.
			return [
				_mj("barrage", "Barrage",
					"Trois boules de feu explosent en ligne, sur toute la largeur visee",
					[_mj_copie(c, "ground_zone", {&"aim_offset": Vector2(-230.0, 0.0)}),
					 _mj_copie(c, "ground_zone", {&"aim_offset": Vector2(230.0, 0.0)})],
					[_mj_prix("area", -0.45), _mj_prix("damage", -0.2)]),
				# C7b : la nappe RESPIRE (grow), sinon la majeure ne changeait que
				# deux chiffres de la zone (refuse par test_majeures_contenu durci).
				_mj("napalm", "Napalm",
					"L explosion devient une nappe de feu qui s etale puis reflue : 8 par seconde, 4 s",
					[_mj_champ("ground_zone", "magnitude", 8.0),
					 _mj_champ("ground_zone", "duration", 4.0),
					 _mj_pose("ground_zone", "grow_start", 0.6),
					 _mj_pose("ground_zone", "grow_peak", 1.5)],
					[_mj_prix("cast", -0.4)]),
			]
		"frost_rain":
			# Une zone -> tout le terrain ; un controle -> des degats de grele.
			return [
				_mj("hiver", "Hiver",
					"Le froid gagne tout le terrain : monstres -20 % de vitesse 6 s",
					[_mj_ajout("slow_enemy_gauge", 20.0, 6.0)],
					[_mj_prix("area", -0.5)]),
				_mj("grelons", "Grelons",
					"Des grelons s abattent sur tout le terrain : 8 impacts de 14 degats de GLACE",
					[_mj_ajout("meteor_storm", 14.0, 4.0, 90.0, {&"impacts": 8})],
					[_mj_prix("slow", -0.4), _mj_prix("duration", -0.25)]),
			]
		"spark":
			# Une cible -> une marque qui saute ; un degat -> un etourdissement.
			return [
				_mj("arc_electrique", "Arc electrique",
					"La cible porte une marque de 6 : a sa mort elle saute au voisin, -1 par saut",
					[_mj_ajout("electric_mark", 6.0, 0.0, 0.0,
						{&"jump_range": 300.0, &"decay": 1.0})],
					[_mj_prix("damage", -0.3)]),
				_mj("choc", "Choc",
					"L etincelle etourdit 0,6 s la cible et ses voisins proches",
					[_mj_ajout("stun_zone", 0.0, 0.6, 110.0)],
					[_mj_prix("damage", -0.45), _mj_prix("cast", -0.25)]),
			]
		"venom_dart":
			# Le poison CONTAGIEUX (une marque qui saute, au poison) ; un dard ->
			# une nuee qui empoisonne tout le voisinage (residu d une zone breve).
			return [
				_mj("contagion", "Contagion",
					"A la mort de la cible, le venin saute au voisin (4 degats, -1 par saut)",
					[_mj_ajout("electric_mark", 4.0, 0.0, 0.0,
						{&"jump_range": 260.0, &"decay": 1.0})],
					[_mj_prix("cast", -0.5)]),
				_mj("nuee_de_dards", "Nuee de dards",
					"Les voisins de la cible sont empoisonnes aussi : 2 PV par seconde pendant 6 s",
					[_mj_ajout("ground_zone", 0.0, 0.3, 150.0,
						{&"residue_dps": 2.0, &"residue_duration": 6.0})],
					[_mj_prix("damage", -0.5)]),
			]
		# ================= RARES =================
		"quickening":
			# Une hate longue -> une FRENESIE breve : deux sorts charges a la fois
			# (C7b : avant, deux chiffres seulement) ; une hate -> une hate et un soin.
			return [
				_mj("coup_de_fouet", "Coup de fouet",
					"Frenesie de 1,5 s : incantation +300 % et deux sorts charges a la fois",
					[_mj_champ("self_haste", "magnitude", 300.0),
					 _mj_champ("self_haste", "duration", 1.5),
					 _mj_ajout("double_cast", 0.0, 1.5)],
					[_mj_prix("discard", -1.0)]),
				_mj("second_souffle", "Second souffle",
					"Rend aussi 20 points de vitesse au mage",
					[_mj_ajout("gain_speed", 20.0)],
					[_mj_prix("duration", -0.5)]),
			]
		"temporal_drag":
			# Un ralentissement -> trois ARRETS a contretemps (C7b : avant, un seul,
			# deux chiffres changes) ; un -> deux de suite. Un second ralentissement
			# AJOUTE au meme lancer ne servirait a rien : apply_global_enemy_slow
			# remplace le precedent, d ou le rythme par rejeux.
			return [
				_mj("arret_du_temps", "Arret du temps",
					"Trois arrets : les monstres sont quasi figes (-90 %) 1 s, toutes les 2,5 s",
					[_mj_champ("slow_enemy_gauge", "magnitude", 90.0),
					 _mj_champ("slow_enemy_gauge", "duration", 1.0),
					 _mj_rejeu(2.5), _mj_rejeu(5.0)],
					[_mj_prix("cast", -0.4)]),
				_mj("double_entrave", "Double entrave",
					"L entrave revient 6 s plus tard : deux ralentissements de suite",
					[_mj_rejeu(6.0)],
					[_mj_prix("slow", -0.4)]),
			]
		"cycle_of_thought":
			# Un echange de cartes -> un echange qui garde ; qui fait murir.
			return [
				_mj("maree_qui_rend", "Maree qui rend",
					"Et le prochain sort que tu lances revient en main",
					[_mj_ajout("retain_next", 1.0)],
					[_mj_prix("cast", -0.4)]),
				_mj("courant_de_pensee", "Courant de pensee",
					"La main renouvelee gagne 1 XP par sort distinct : ils murissent plus tot",
					[_mj_ajout("hand_card_xp", 1.0)],
					[_mj_prix("discard", -1.0)]),
			]
		"mana_flow":
			# Une pioche lente et longue -> une pioche immediate ; un flux qui repart.
			return [
				_mj("torrent_de_mana", "Torrent de mana",
					"Pioche 2 cartes tout de suite ; le flux ne dure plus que 4 s",
					[_mj_ajout("draw_cards", 0.0, 0.0, 0.0, {&"count": 2}),
					 _mj_champ("draw_boost", "duration", 4.0)],
					[_mj_prix("tempo", -0.25)]),
				_mj("flux_continu", "Flux continu",
					"Le flux repart des qu il s acheve : deux fois plus long",
					[_mj_rejeu(12.0)],
					[_mj_prix("cast", -0.5)]),
			]
		"stone_wall":
			# Le mur du co-auteur : immense et qui arrete les volants. Ou un mur qui
			# blesse ceux qui le longent.
			return [
				_mj("muraille_geante", "Muraille geante",
					"Mur presque deux fois plus large, que les volants ne franchissent plus",
					[_mj_echelle("build_wall", "radius", 1.8),
					 _mj_pose("build_wall", "blocks_flyers", true)],
					[_mj_prix("cast", -0.4), _mj_prix("duration", -0.25)]),
				_mj("mur_de_ronces", "Mur de ronces",
					"Des ronces le bordent : qui le longe est ralenti de 30 % et perd 5 PV par seconde",
					[_mj_ajout("ground_zone", 5.0, 20.0, 230.0, {&"slow_pct": 30.0})],
					[_mj_prix("duration", -0.5)]),
			]
		"ice_wall":
			# Un mur -> un mur qui gele ses abords ; un mur lent -> un mur eclair.
			return [
				_mj("mur_de_givre", "Mur de givre",
					"Le froid du mur ralentit de 50 % tout ce qui l approche pendant 8 s",
					[_mj_ajout("ground_zone", 0.0, 8.0, 230.0, {&"slow_pct": 50.0})],
					[_mj_prix("hp", -0.4)]),
				_mj("glaciation", "Glaciation",
					"Le mur de glace se dresse presque aussitot",
					[_mj_incant(0.2)],
					[_mj_prix("hp", -0.3), _mj_prix("discard", -1.0)]),
			]
		"brazier":
			# Une zone -> une colonne de trois ; un feu qui aspire (verbe du vent,
			# element du FEU : le texte ne nomme pas le vent, C7b).
			return [
				_mj("colonne_de_feu", "Colonne de feu",
					"Trois brasiers en colonne : un couloir de feu vers les monstres",
					[_mj_copie(c, "ground_zone", {&"aim_offset": Vector2(0.0, -210.0)}),
					 _mj_copie(c, "ground_zone", {&"aim_offset": Vector2(0.0, -420.0)})],
					[_mj_prix("area", -0.4), _mj_prix("damage", -0.25)]),
				_mj("appel_d_air", "Appel d air",
					"Le brasier aspire l air : les monstres sont attires vers son coeur pendant 6 s",
					[_mj_ajout("vortex_pull", 90.0, 6.0, 280.0)],
					[_mj_prix("damage", -0.4)]),
			]
		"meteor":
			# Une carte longue -> quasi instantanee ; un impact -> un cratere.
			return [
				_mj("meteore_eclair", "Meteore eclair",
					"Incantation quasi instantanee : il tombe quatre fois plus vite",
					[_mj_incant(0.25)],
					[_mj_prix("area", -0.55), _mj_prix("discard", -1.0)]),
				_mj("cratere", "Cratere",
					"Il laisse un cratere en fusion : 10 degats de FEU par seconde, 5 s",
					[_mj_ajout("ground_zone", 10.0, 5.0, 140.0)],
					[_mj_prix("cast", -0.4), _mj_prix("area", -0.2)]),
			]
		"about_face":
			# Un demi-tour -> un demi-tour sous le vent du sud ; deux demi-tours.
			return [
				_mj("contre_vent", "Contre-vent",
					"Le vent du sud souffle aussi : volants cloues sur place, trajets redresses",
					[_mj_ajout("global_wind", 0.0, 3.0)],
					[_mj_prix("discard", -1.0)]),
				_mj("ressac", "Ressac",
					"Les monstres font demi-tour une seconde fois, 4,5 s plus tard",
					[_mj_rejeu(4.5)],
					[_mj_prix("duration", -0.4)]),
			]
		"focus":
			# Un bonus -> un bonus et un double canal ; un bonus qui revient.
			return [
				_mj("canal_ouvert", "Canal ouvert",
					"Et pendant 4 s, tu peux charger deux sorts a la fois",
					[_mj_ajout("double_cast", 0.0, 4.0)],
					[_mj_prix("amplify", -0.5)]),
				_mj("lentille", "Lentille",
					"Le sort renforce revient en main au lieu d etre defausse",
					[_mj_ajout("retain_next", 1.0)],
					[_mj_prix("cast", -0.5)]),
			]
		"salt_spiral":
			# Une aspiration -> une aspiration qui ronge ; une -> trois en rangee.
			return [
				_mj("sel_brulant", "Sel brulant",
					"Le sel ronge le coeur de la spirale : 6 degats de VENT par seconde",
					[_mj_ajout("ground_zone", 6.0, 3.0, 110.0)],
					[_mj_prix("duration", -0.3)]),
				_mj("rideau_de_spirales", "Rideau de spirales",
					"Trois spirales cote a cote aspirent toute une rangee",
					[_mj_copie(c, "vortex_pull", {&"aim_offset": Vector2(-260.0, 0.0)}),
					 _mj_copie(c, "vortex_pull", {&"aim_offset": Vector2(260.0, 0.0)})],
					[_mj_prix("area", -0.5), _mj_prix("force", -0.35)]),
			]
		"bone_recall":
			# Un rappel -> un rappel qui renforce ; un rappel qui releve un mort.
			return [
				_mj("moelle", "Moelle",
					"Le sort rappele inflige aussi 50 % de degats en plus",
					[_mj_ajout("empower_next", 1.5)],
					[_mj_prix("cast", -0.5)]),
				_mj("ossuaire", "Ossuaire",
					"Un squelette se releve a tes cotes et frappe pour 10 pendant 6 s",
					[_mj_ajout("summon_ally", 10.0, 6.0)],
					[_mj_prix("discard", -1.0)]),
			]
		"chain_break":
			# Un coup -> des eclats qui restent ; un souffle -> un souffle qui alourdit.
			return [
				_mj("eclats", "Eclats",
					"Les eclats restent plantes : 4 degats de VENT par seconde pendant 4 s",
					[_mj_pose("knockback", "residue_dps", 4.0),
					 _mj_pose("knockback", "residue_duration", 4.0)],
					[_mj_prix("force", -0.4)]),
				_mj("chaines_pesantes", "Chaines pesantes",
					"Les chaines restent au sol : qui y passe est ralenti de 50 % pendant 3 s",
					[_mj_ajout("ground_zone", 0.0, 3.0, 190.0, {&"slow_pct": 50.0})],
					[_mj_prix("force", -0.5)]),
			]
		"purifying_light":
			# Une dissipation lente -> eclair ; une dissipation qui eblouit.
			return [
				# C7b : x0,25 et non plus x0,3. Une incantation ne compte comme
				# STRUCTURE que SOUS x0,3 (« quasi instantane », test durci).
				_mj("eclat_purifiant", "Eclat purifiant",
					"La lumiere tombe presque aussitot",
					[_mj_incant(0.25)],
					[_mj_prix("area", -0.3), _mj_prix("discard", -1.0)]),
				_mj("aube_eblouissante", "Aube eblouissante",
					"La lumiere eblouit : sa zone ralentit de 40 % pendant 4 s",
					[_mj_ajout("ground_zone", 0.0, 4.0, 150.0, {&"slow_pct": 40.0})],
					[_mj_prix("cast", -0.4)]),
			]
		"repulsion_wave":
			# Un souffle -> un courant qui dure (verbe de l eau, element du VENT :
			# le texte ne nomme pas l eau, C7b) ; deux ondes.
			return [
				_mj("souffle_continu", "Souffle continu",
					"Le souffle s attarde 4 s : un courant fait reculer qui y entre",
					[_mj_ajout("water_flood", 60.0, 4.0, 220.0)],
					[_mj_prix("force", -0.4)]),
				_mj("double_onde", "Double onde",
					"Une seconde onde part 1,5 s plus tard, au meme endroit",
					[_mj_rejeu(1.5)],
					[_mj_prix("damage", -0.35), _mj_prix("area", -0.2)]),
			]
		"heartwood_totem":
			# Un arbre qui tombe -> incassable mais bref ; un arbre qui mord.
			return [
				_mj("coeur_de_chene", "Coeur de chene",
					"L arbre ne tombe plus : il retient la vague 6 s, puis disparait",
					[_mj_pose("taunt_prop", "unbreakable", true),
					 _mj_champ("taunt_prop", "duration", 6.0)],
					[_mj_prix("area", -0.4)]),
				_mj("racines_voraces", "Racines voraces",
					"Ses racines mordent : 10 degats de NATURE par seconde autour de lui",
					[_mj_champ("taunt_prop", "magnitude", 10.0),
					 _mj_pose("taunt_prop", "zone_radius", 200.0)],
					[_mj_prix("hp", -0.5)]),
			]
		"tidal_pool":
			# Un courant -> une vague qui s abat d abord ; une eau qui englue (le
			# ralentissement est d EAU, l element de la carte : C7b retire le « glace »).
			return [
				_mj("raz_de_maree", "Raz-de-maree",
					"La nappe s abat d abord : 8 degats et un violent recul, puis le courant",
					[_mj_ajout("knockback", 8.0, 0.0, 300.0, {&"push": 220.0})],
					[_mj_prix("duration", -0.4)]),
				_mj("bourbier", "Bourbier",
					"L eau s epaissit : la nappe ralentit aussi de 40 %",
					[_mj_ajout("ground_zone", 0.0, 7.0, 300.0, {&"slow_pct": 40.0})],
					[_mj_prix("force", -0.4)]),
			]
		"time_surge":
			# Un soin -> deux soins ; un soin -> un soin et une hate.
			return [
				_mj("second_elan", "Second elan",
					"Un second elan suit 5 s plus tard, moitie moins fort",
					[_mj_rejeu(5.0, 0.5)],
					[_mj_prix("discard", -1.0)]),
				_mj("elan_foudroyant", "Elan foudroyant",
					"Et ton incantation s emballe : +50 % pendant 4 s",
					[_mj_ajout("self_haste", 50.0, 4.0)],
					[_mj_prix("cast", -0.4)]),
			]
		"terrain_brambles":
			# Le terrain du co-auteur : incassable mais limite dans le temps, avec
			# un effet en plus. Ou une haie sur toute une rangee.
			return [
				_mj("ronces_de_fer", "Ronces de fer",
					"Incassables, ralentissent de 70 % et mordent a 6 par seconde, mais fanent en 12 s",
					[_mj_pose("place_terrain", "unbreakable", true),
					 _mj_champ("place_terrain", "duration", 12.0),
					 _mj_pose("place_terrain", "slow_pct", 70.0),
					 _mj_champ("place_terrain", "magnitude", 6.0)],
					[_mj_prix("area", -0.3)]),
				_mj("haie_de_ronces", "Haie de ronces",
					"Trois buissons cote a cote : une haie sur toute une rangee",
					[_mj_copie(c, "place_terrain", {&"aim_offset": Vector2(-200.0, 0.0)}),
					 _mj_copie(c, "place_terrain", {&"aim_offset": Vector2(200.0, 0.0)})],
					[_mj_prix("area", -0.5), _mj_prix("slow", -0.3)]),
			]
		# ================= EPIQUES =================
		"mirror_apprentice":
			# Un reflet -> trois ; un reflet qui t aide a incanter.
			return [
				_mj("galerie_des_glaces", "Galerie des glaces",
					"Trois reflets au lieu d un, chacun plus fragile",
					[_mj_copie(c, "summon_ally", {}), _mj_copie(c, "summon_ally", {})],
					[_mj_prix("damage", -0.55), _mj_prix("duration", -0.3)]),
				_mj("reflet_complice", "Reflet complice",
					"Le reflet incante avec toi : +40 % d incantation tant qu il vit",
					[_mj_ajout("self_haste", 40.0, 8.0)],
					[_mj_prix("damage", -0.3)]),
			]
		"deep_focus":
			# La carte d XP du co-auteur : « fait monter une carte de ton choix de
			# ta main d un niveau a la place ». A la place : son XP passe a zero.
			return [
				_mj("maitrise", "Maitrise",
					"A la place : un sort de ta main, au choix, monte d un niveau",
					[_mj_champ("hand_card_xp", "magnitude", 0.0),
					 _mj_ajout("hand_card_level", 0.0, 0.0, 0.0, {&"count": 1})],
					[_mj_prix("discard", -1.0), _mj_prix("cast", -0.2)]),
				_mj("meditation", "Meditation",
					"La main regagne 1 XP par sort 5 s plus tard",
					[_mj_rejeu(5.0)],
					[_mj_prix("cast", -0.5)]),
			]
		"reckless_bargain":
			# Un pacte qui accelere -> un pacte INVERSE ; un pacte foudroyant.
			return [
				_mj("pacte_inverse", "Pacte inverse",
					"Le pacte s inverse : les monstres RALENTISSENT de 30 %, mais 1 carte piochee",
					[_mj_champ("haste_enemies_boon", "magnitude", -30.0),
					 _mj_pose("haste_enemies_boon", "draw", 1)],
					[_mj_prix("cast", -0.4)]),
				_mj("pacte_foudroyant", "Pacte foudroyant",
					"Pendant le pacte, la foudre frappe chaque monstre : 4 degats par seconde",
					[_mj_ajout("global_rain", 4.0, 5.0, 0.0, {&"interval": 1.0})],
					[_mj_prix("discard", -1.0)]),
			]
		"deck_purge":
			# Une purge -> une purge qui soigne ; une purge qui empoisonne le terrain.
			return [
				_mj("purge_vivifiante", "Purge vivifiante",
					"La purge rend aussi 20 points de vitesse au mage",
					[_mj_ajout("gain_speed", 20.0)],
					[_mj_prix("cast", -0.5)]),
				_mj("purge_toxique", "Purge toxique",
					"Le poison rejete se repand : 3 degats a tous les monstres toutes les 2 s, 8 s",
					[_mj_ajout("global_rain", 3.0, 8.0, 0.0, {&"interval": 2.0})],
					[_mj_prix("discard", -1.0)]),
			]
		"deep_freeze":
			# Un ralentissement -> un etourdissement (le gel fige) ; une onde de froid.
			return [
				_mj("prison_de_glace", "Prison de glace",
					"Le gel fige net : les monstres de la zone sont etourdis 1,5 s",
					[_mj_ajout("stun_zone", 0.0, 1.5, 170.0)],
					[_mj_prix("area", -0.4), _mj_prix("cast", -0.3)]),
				_mj("onde_de_froid", "Onde de froid",
					"Le froid se propage : la zone part a x0,3, s etend a x2 puis se replie",
					[_mj_pose("ground_zone", "grow_start", 0.3),
					 _mj_pose("ground_zone", "grow_peak", 2.0)],
					[_mj_prix("slow", -0.4)]),
			]
		"weakness_mark":
			# Une marque -> une sentence a la fin ; une marque qui s etend.
			return [
				_mj("sentence", "Sentence",
					"A la fin, qui est encore dans la marque encaisse 30 degats, doubles par elle",
					[_mj_ajout("quicksand", 30.0, 8.0, 200.0)],
					[_mj_prix("duration", -0.5)]),
				_mj("marque_devorante", "Marque devorante",
					"La marque s etend jusqu a x1,8 a mi-vie, puis se resserre",
					[_mj_pose("ground_zone", "grow_start", 0.4),
					 _mj_pose("ground_zone", "grow_peak", 1.8)],
					[_mj_prix("amplify", -0.3), _mj_prix("cast", -0.2)]),
			]
		"resonance":
			# Une onde -> deux ; une onde -> une zone qui continue de vibrer.
			return [
				_mj("echo_resonant", "Echo resonant",
					"Une seconde onde frappe 1 s plus tard, au meme endroit",
					[_mj_rejeu(1.0)],
					[_mj_prix("area", -0.35)]),
				_mj("harmonique", "Harmonique",
					"La zone vibre encore 3 s : les monstres y subissent x1,5 degats",
					[_mj_ajout("ground_zone", 0.0, 3.0, 220.0, {&"vuln_mult": 1.5})],
					[_mj_prix("damage", -0.4)]),
			]
		"void_grip":
			# Une dissipation -> une faiblesse qui reste ; aspirer puis dissiper.
			return [
				_mj("vide_beant", "Vide beant",
					"Les monstres depouilles restent vulnerables : x1,5 degats pendant 4 s",
					[_mj_ajout("ground_zone", 0.0, 4.0, 150.0, {&"vuln_mult": 1.5})],
					[_mj_prix("area", -0.3)]),
				_mj("gouffre_du_vide", "Gouffre du vide",
					"Aspire 1,5 s vers son centre, puis dissipe une seconde fois",
					[_mj_ajout("vortex_pull", 180.0, 1.5, 320.0), _mj_rejeu(1.5)],
					[_mj_prix("area", -0.4), _mj_prix("cast", -0.2)]),
			]
		"arcane_insight":
			# Une pioche -> une pioche et un temps de pose reduit ; deux pioches.
			return [
				_mj("vision", "Vision",
					"Et tes sorts coutent 0,5 s de moins pendant 5 s",
					[_mj_ajout("cost_reduction", 0.5, 5.0)],
					[_mj_prix("discard", -1.0)]),
				_mj("cascade", "Cascade",
					"Tu pioches de nouveau, 4 s plus tard",
					[_mj_rejeu(4.0)],
					[_mj_prix("cast", -0.6)]),
			]
		"bastion":
			# Le terrain du co-auteur : incassable, infranchissable meme en volant,
			# mais limite dans le temps. Ou deux murs a briser.
			return [
				_mj("forteresse", "Forteresse",
					"Incassable et infranchissable, meme en volant, mais il tombe en 15 s",
					[_mj_pose("build_wall", "permanent", false),
					 _mj_champ("build_wall", "duration", 15.0),
					 _mj_pose("build_wall", "unbreakable", true),
					 _mj_pose("build_wall", "blocks_flyers", true)],
					[_mj_prix("cast", -0.3)]),
				_mj("double_rempart", "Double rempart",
					"Un second mur se dresse devant le premier : il faut briser les deux",
					[_mj_copie(c, "build_wall", {&"aim_offset": Vector2(0.0, -150.0)})],
					[_mj_prix("hp", -0.5)]),
			]
		"maelstrom":
			# Une aspiration -> des lames au centre ; attirer avant d engloutir.
			return [
				_mj("oeil_du_cyclone", "Oeil du cyclone",
					"Au coeur, les lames du vent : 10 degats par seconde",
					[_mj_ajout("ground_zone", 10.0, 4.0, 110.0)],
					[_mj_prix("area", -0.3)]),
				_mj("siphon", "Siphon",
					"Au bout de 4 s, ce qui est au centre est englouti : 40 degats",
					[_mj_ajout("quicksand", 40.0, 4.0, 140.0)],
					[_mj_prix("force", -0.35)]),
			]
		"blight_sapling":
			# Incassable mais bref, deux fois plus toxique ; des spores qui
			# s etendent et laissent un poison apres la sortie (idee du co-auteur).
			return [
				_mj("arbre_maudit", "Arbre maudit",
					"Indestructible et deux fois plus toxique, mais il meurt en 15 s",
					[_mj_pose("place_terrain", "unbreakable", true),
					 _mj_champ("place_terrain", "duration", 15.0),
					 _mj_echelle("place_terrain", "magnitude", 2.0)],
					[_mj_prix("area", -0.3)]),
				_mj("spores", "Spores",
					"Des spores s etendent 10 s : qui les traverse perd 4 PV par seconde pendant 5 s",
					[_mj_ajout("ground_zone", 0.0, 10.0, 300.0,
						{&"grow_start": 0.3, &"grow_peak": 1.4,
						 &"residue_dps": 4.0, &"residue_duration": 5.0})],
					[_mj_prix("hp", -0.5)]),
			]
		"thunder_root":
			# Un etourdissement -> deux enchaines ; une racine -> une colonne.
			return [
				_mj("tonnerre_roulant", "Tonnerre roulant",
					"Le tonnerre gronde deux fois : nouvel etourdissement quand le premier cesse",
					[_mj_rejeu(1.1)],
					[_mj_prix("area", -0.4), _mj_prix("cast", -0.3)]),
				_mj("foudre_en_colonne", "Foudre en colonne",
					"Trois racines en colonne : le tonnerre frappe tout un couloir",
					[_mj_copie(c, "stun_zone", {&"aim_offset": Vector2(0.0, -220.0)}),
					 _mj_copie(c, "stun_zone", {&"aim_offset": Vector2(0.0, -440.0)})],
					[_mj_prix("area", -0.5), _mj_prix("damage", -0.4)]),
			]
		"terrain_altar":
			# Incassable mais bref et fervent ; un autel qui sert d APPAT : il aspire
			# les monstres a la pose puis les retient (C7b : avant, deux chiffres,
			# portee de provocation et PV ; l aspiration est de NATURE, sa carte).
			return [
				_mj("autel_sacre", "Autel sacre",
					"Incassable, un allie toutes les 2,5 s, mais il s eteint en 20 s",
					[_mj_pose("place_terrain", "unbreakable", true),
					 _mj_champ("place_terrain", "duration", 20.0),
					 _mj_pose("place_terrain", "summon_every", 2.5)],
					[_mj_prix("damage", -0.3)]),
				_mj("autel_appat", "Autel-appat",
					"A la pose, l autel aspire les monstres vers lui 3 s, puis les retient de loin",
					[_mj_ajout("vortex_pull", 120.0, 3.0, 320.0),
					 _mj_pose("place_terrain", "taunt_radius", 460.0),
					 _mj_pose("place_terrain", "prop_hp", 320.0)],
					[_mj_prix("damage", -0.4)]),
			]
		"terrain_pit":
			# Incassable mais comble en 12 s, et bien plus profonde ; des pieux qui
			# JAILLISSENT a la pose (C7b : avant, un seul chiffre, les degats de la
			# zone ; un residu ne marcherait pas ici, plant() ne le lit pas).
			return [
				_mj("gouffre", "Gouffre",
					"Incassable et plus profond (x2 degats, -40 % vitesse), mais comble en 12 s",
					[_mj_pose("place_terrain", "unbreakable", true),
					 _mj_champ("place_terrain", "duration", 12.0),
					 _mj_pose("place_terrain", "vuln_mult", 2.0),
					 _mj_pose("place_terrain", "slow_pct", 40.0)],
					[_mj_prix("area", -0.2)]),
				_mj("fosse_aux_pieux", "Fosse aux pieux",
					"Des pieux jaillissent : etourdi 1 s a la pose, puis 6 degats de NATURE par seconde",
					[_mj_champ("place_terrain", "magnitude", 6.0),
					 _mj_ajout("stun_zone", 0.0, 1.0, 150.0)],
					[_mj_prix("amplify", -0.5)]),
			]
		# ================= LEGENDAIRES =================
		"time_rift":
			# Une ligne -> une croix ; une baisse de cout -> un temps fige.
			return [
				_mj("faille_en_croix", "Faille en croix",
					"La faille s ouvre en croix : deux lignes de plus, a angle droit",
					[_mj_copie(c, "pierce_line", {&"angle_deg": 90.0}),
					 _mj_copie(c, "pierce_line", {&"angle_deg": -90.0})],
					[_mj_prix("damage", -0.3), _mj_prix("cast", -0.2)]),
				_mj("faille_figee", "Faille figee",
					"Le temps se fige autour d eux : tous les monstres -30 % pendant 5 s",
					[_mj_ajout("slow_enemy_gauge", 30.0, 5.0)],
					[_mj_prix("tempo", -0.4)]),
			]
		"tide_ledger":
			# Une carte longue -> quasi instantanee ; un registre qui fait murir.
			return [
				_mj("registre_eclair", "Registre eclair",
					"Le registre s ouvre presque aussitot",
					[_mj_incant(0.2)],
					[_mj_prix("duration", -0.5)]),
				_mj("grand_registre", "Grand registre",
					"Et chaque sort de ta main gagne 1 XP : ils murissent plus tot",
					[_mj_ajout("hand_card_xp", 1.0)],
					[_mj_prix("discard", -1.0), _mj_prix("duration", -0.3)]),
			]
		"summoners_key":
			# Deux allies -> quatre ; un appel long -> un appel eclair.
			return [
				_mj("legion", "Legion",
					"Quatre allies au lieu de deux, chacun plus faible",
					[_mj_double("summon_ally", {})],
					[_mj_prix("damage", -0.45)]),
				_mj("appel_eclair", "Appel eclair",
					"Les allies repondent presque aussitot",
					[_mj_incant(0.25)],
					[_mj_prix("duration", -0.5)]),
			]
		"forge_dial":
			# Des meteorites -> des meteorites et des cendres ; un cadran qui fige.
			return [
				_mj("pluie_de_cendres", "Pluie de cendres",
					"Des cendres tombent partout : 3 degats de FEU a chaque monstre par seconde",
					[_mj_ajout("global_rain", 3.0, 6.0, 0.0, {&"interval": 1.0})],
					[_mj_prix("damage", -0.3)]),
				_mj("cadran_fige", "Cadran fige",
					"Le cadran ralentit le temps : monstres -30 % pendant la pluie",
					[_mj_ajout("slow_enemy_gauge", 30.0, 6.0)],
					[_mj_prix("damage", -0.5)]),
			]
		"world_loom":
			# Une carte longue -> quasi instantanee ; une trame -> deux.
			return [
				_mj("metier_eclair", "Metier eclair",
					"Le metier se retisse presque aussitot",
					[_mj_incant(0.2)],
					[_mj_prix("duration", -0.5)]),
				_mj("seconde_trame", "Seconde trame",
					"Le temps se retisse une seconde fois, 10 s plus tard",
					[_mj_rejeu(10.0)],
					[_mj_prix("slow", -0.45), _mj_prix("tempo", -0.45)]),
			]
		"hourglass_shard":
			# Un ralentissement -> un arret QUASI INSTANTANE (C7b : avant, trois
			# chiffres seulement ; la plus longue incantation des sorts de temps,
			# 2,1 s de base, devient un bouton d urgence) ; le sable qui remonte
			# (verbe du vent, element ARCANIQUE : le texte ne nomme pas le vent).
			return [
				_mj("sablier_brise", "Sablier brise",
					"Quasi instantane : le temps s arrete presque (monstres -90 %, incantation +200 %), 2 s",
					[_mj_incant(0.2),
					 _mj_champ("slow_enemy_gauge", "magnitude", 90.0),
					 _mj_champ("self_haste", "magnitude", 200.0),
					 _mj_champ("", "duration", 2.0)],
					[_mj_prix("discard", -1.0)]),
				_mj("sablier_retourne", "Sablier retourne",
					"Le sable remonte : tous les monstres font demi-tour 2 s",
					[_mj_ajout("reverse_enemies", 0.0, 2.0)],
					[_mj_prix("tempo", -0.5)]),
			]
		"echo_of_the_hand":
			# Un echo -> un echo qui accelere ; un echo qui revient.
			return [
				_mj("echo_du_temps", "Echo du temps",
					"Et ton incantation s accelere de 50 % pendant 5 s",
					[_mj_ajout("self_haste", 50.0, 5.0)],
					[_mj_prix("cast", -0.4)]),
				_mj("echo_perpetuel", "Echo perpetuel",
					"L echo revient 8 s plus tard, pour de nouvelles cartes",
					[_mj_rejeu(8.0)],
					[_mj_prix("discard", -1.0)]),
			]
		"twin_channeling":
			# Deux canaux -> deux canaux brulants ; une carte longue -> eclair.
			return [
				_mj("canaux_brulants", "Canaux brulants",
					"Et tu incantes 40 % plus vite tant que les deux canaux sont ouverts",
					[_mj_ajout("self_haste", 40.0, 10.0)],
					[_mj_prix("discard", -1.0)]),
				_mj("canal_fulgurant", "Canal fulgurant",
					"Les deux canaux s ouvrent presque aussitot",
					[_mj_incant(0.15)],
					[_mj_prix("duration", -0.5)]),
			]
		"meteor_storm":
			# La plus longue incantation du jeu -> quasi instantanee ; deux averses.
			return [
				_mj("deluge_eclair", "Deluge eclair",
					"La pluie tombe quatre fois plus vite a invoquer",
					[_mj_incant(0.25)],
					[_mj_prix("area", -0.5), _mj_prix("discard", -1.0)]),
				_mj("seconde_averse", "Seconde averse",
					"Une seconde averse suit la premiere, 5 s plus tard",
					[_mj_rejeu(5.0)],
					[_mj_prix("damage", -0.55)]),
			]
		"venom_mire":
			# Les deux idees du co-auteur pour le poison : une mare plus grande qui
			# reflue (le moteur ne sait que respirer en triangle : voir le rapport
			# B1b, un param grow_end la rendrait monotone), et un poison qui reste
			# 5 s apres le contact.
			return [
				_mj("mare_deferlante", "Mare deferlante",
					"La mare deferle a x1,8 puis reflue a x0,6 a mi-vie, avant de remonter",
					[_mj_pose("ground_zone", "grow_start", 1.8),
					 _mj_pose("ground_zone", "grow_peak", 0.6)],
					[_mj_prix("duration", -0.4)]),
				_mj("venin_tenace", "Venin tenace",
					"Qui sort de la mare garde le poison 5 s : 5 PV de POISON par seconde",
					[_mj_pose("ground_zone", "residue_dps", 5.0),
					 _mj_pose("ground_zone", "residue_duration", 5.0)],
					[_mj_prix("area", -0.35), _mj_prix("damage", -0.25)]),
			]
		"terrain_river":
			# Une riviere -> une riviere qui jaillit (jet en I, meme element) ; qui
			# deborde (pluie abondante, meme element).
			return [
				_mj("torrent", "Torrent",
					"A la pose, un jet d eau repousse tout ce qui est sous le point vise",
					[_mj_ajout("water_jet", 3.0, 0.0, 70.0, {&"length": 900.0, &"push": 300.0})],
					[_mj_prix("discard", -1.0)]),
				_mj("crue", "Crue",
					"La riviere deborde : 4 degats d EAU a chaque monstre toutes les 2 s, 10 s",
					[_mj_ajout("global_rain", 4.0, 10.0, 0.0, {&"interval": 2.0})],
					[_mj_prix("cast", -0.5)]),
			]
		# ================= VAGUE 10 : CARTES DE B1a =================
		# Les six communes du co-auteur (_cartes_vague_10 ; la Lumiere purifiante
		# est plus haut). Les majeures ne visent que leur cle principale ; les
		# durees des effets ajoutes suivent celle du sort (lue dans le .tres).
		"south_wind":
			var vent: EffectSpec = _mj_effet(c, "global_wind")
			var dv: float = vent.duration if vent != null else 6.0
			return [
				_mj("vent_arriere", "Vent arriere",
					"Le vent te pousse : ton incantation +50 % tant qu il souffle",
					[_mj_ajout("self_haste", 50.0, dv)],
					[_mj_prix("discard", -1.0)]),
				# C7b : le ralentissement est de VENT, l element de la carte. Le titre
				# et le texte disaient « glacial » / « (glace) » : un monstre qui
				# craint le froid mais resiste au vent l aurait cru sans effet. L id
				# reste (identifiant stable de la partie), le texte ne ment plus.
				_mj("vent_glacial", "Vent contraire",
					"Le vent se retourne contre eux : tous les monstres -25 % tant qu il souffle",
					[_mj_ajout("slow_enemy_gauge", 25.0, dv)],
					[_mj_prix("duration", -0.3), _mj_prix("cast", -0.2)]),
			]
		"electric_mark":
			# L idee du co-auteur : « quand un ennemi meurt, transmet une marque
			# supplementaire ». Et une marque qui ne faiblit plus.
			return [
				_mj("orage_en_chaine", "Orage en chaine",
					"A chaque mort, la marque saute sur DEUX monstres au lieu d un",
					[_mj_pose("electric_mark", "marks_per_death", 2)],
					[_mj_prix("cast", -0.3), _mj_prix("discard", -1.0)]),
				# C7b : la foudre RETOMBE (rejeu, la cible morte est remplacee par
				# la plus proche) ; avant, deux chiffres seulement (decroissance,
				# portee). Le rejeu double les chaines : le prix en vitesse monte.
				_mj("foudre_tenace", "Foudre tenace",
					"La marque ne faiblit plus et la foudre retombe 1,5 s plus tard ; sauts plus courts",
					[_mj_pose("electric_mark", "decay", 0.0),
					 _mj_pose("electric_mark", "jump_range", 200.0),
					 _mj_rejeu(1.5)],
					[_mj_prix("discard", -1.0), _mj_prix("cast", -0.35)]),
			]
		"heavy_rain":
			return [
				_mj("averse_soudaine", "Averse soudaine",
					"La pluie tombe presque aussitot",
					[_mj_incant(0.25)],
					[_mj_prix("discard", -1.0)]),
				_mj("pluie_battante", "Pluie battante",
					"Le deluge repousse les monstres : ils font demi-tour 1,5 s",
					[_mj_ajout("reverse_enemies", 0.0, 1.5)],
					[_mj_prix("cast", -0.4)]),
			]
		"quicksand":
			var sable: EffectSpec = _mj_effet(c, "quicksand")
			var r: float = sable.radius if sable != null else 160.0
			var d: float = sable.duration if sable != null else 3.0
			return [
				_mj("sable_vorace", "Sable vorace",
					"Le sable s etend jusqu a x1,8 a mi-vie, puis se resserre",
					[_mj_pose("quicksand", "grow_start", 0.5),
					 _mj_pose("quicksand", "grow_peak", 1.8)],
					[_mj_prix("cast", -0.3), _mj_prix("duration", -0.25)]),
				_mj("tourbillon_de_sable", "Tourbillon de sable",
					"Le sable aspire vers son centre avant d engloutir",
					[_mj_ajout("vortex_pull", 120.0, d, r)],
					[_mj_prix("discard", -1.0)]),
			]
		"water_jet":
			return [
				_mj("triple_jet", "Triple jet",
					"Trois jets cote a cote balaient toute une rangee",
					[_mj_copie(c, "water_jet", {&"aim_offset": Vector2(-170.0, 0.0)}),
					 _mj_copie(c, "water_jet", {&"aim_offset": Vector2(170.0, 0.0)})],
					[_mj_prix("force", -0.3), _mj_prix("cast", -0.3)]),
				_mj("geyser", "Geyser",
					"Le jet rejaillit 0,8 s plus tard, au meme endroit",
					[_mj_rejeu(0.8)],
					[_mj_prix("discard", -1.0)]),
			]
	printerr("Majeures : aucune entree pour %s" % id)
	return []
