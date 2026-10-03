extends Node
## Generateur de contenu de depart. Ecrit les .tres via ResourceSaver pour garantir
## un format valide. A relancer apres modification du schema des Resources.

func _ready() -> void:
	await get_tree().process_frame
	_enemies()
	_cards()
	_waves_and_level()
	print("CONTENT_OK")
	get_tree().quit(0)


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
const ANCRES_AU_SOL: Array[String] = ["demon_anvil", "demon_anvil_echo"]
const WIND_FLYER_MIN: float = 1.2
const NATURE_FLYER_MAX: float = 0.65
const WATER_FROM_FIRE_MIN: float = 0.65
const WATER_FROM_FIRE_MAX: float = 1.35


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
	var nature: float = float(ecrit.get("nature", dur))
	if e.flying and not ecrit.has("vent"):
		vent = maxf(vent, WIND_FLYER_MIN)
	if e.flying and not ecrit.has("nature"):
		nature = minf(nature, NATURE_FLYER_MAX)
	var feu: float = float(ecrit.get("feu", 1.0))
	var eau: float = float(ecrit.get("eau",
		clampf(2.0 - feu, WATER_FROM_FIRE_MIN, WATER_FROM_FIRE_MAX)))
	var joue: Dictionary = {
		T.FIRE: feu,
		T.WATER: eau,
		T.NATURE: nature,
		T.WIND: vent,
		T.LIGHTNING: float(ecrit.get("foudre", 1.0)),
		T.ICE: float(ecrit.get("glace", ecrit.get("givre", 1.0))),
		T.ARCANE: float(ecrit.get("arcane", 1.0)),
		T.POISON: float(ecrit.get("poison", 1.0)),
		T.SLOW: float(ecrit.get("lent", 1.0)),
	}
	var out: Dictionary = {}
	for tag in joue.keys():
		var v: float = EnemyDef.accentuate(float(joue[tag]))
		if not is_equal_approx(v, 1.0):
			out[tag] = v
	# Le CAMELEON ne declare pas les elements de son cycle (EnemyDef : les deux
	# tables se multiplieraient). La regle ci-dessus pourrait en deriver un (le
	# vent et la nature naissent de « phys ») : on les retire.
	for t in e.chameleon_elements:
		out.erase(int(t))
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
	var warden := _enemy("warden", "Gardien", K.MINIBOSS, 6, 140.0, 40.0, 12, S.HEXAGON, Color(0.90, 0.40, 0.25), 62.0)
	warden.anim_key = &"chaosknight"
	# Gardien (mini-boss) : armure lourde et bouclier. Un mini-boss doit avoir
	# une REPONSE, pas une armure uniforme : la sienne est la magie savante.
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
	_resist(skyreaver, {&"phys": 1.2, &"feu": 0.9, &"givre": 0.7, &"arcane": 1.0, &"foudre": 1.25})
	_save(skyreaver, E + "skyreaver.tres")

	# GRAND CIMETIERE. L inverse du precedent : lent, lourd, immunise au poison
	# comme tout mort-vivant. Le givre le fige, le feu le consume.
	var bonewarden := _enemy("bonewarden", "Gardien d ossements", K.MINIBOSS, 6,
		165.0, 30.0, 13, S.HEXAGON, Color(0.80, 0.78, 0.70), 64.0)
	bonewarden.anim_key = &"warrior_black"
	_resist(bonewarden, {&"phys": 0.75, &"feu": 1.25, &"givre": 1.15, &"arcane": 0.9, &"poison": 0})
	_save(bonewarden, E + "bonewarden.tres")

	# MONDE DEMONIAQUE. Il rend les coups : resistant au feu de son propre
	# monde, il craint le givre — le choc thermique, comme le Colosse.
	var emberlord := _enemy("emberlord", "Seigneur de braise", K.MINIBOSS, 6,
		150.0, 38.0, 13, S.DIAMOND, Color(0.95, 0.45, 0.20), 62.0)
	emberlord.anim_key = &"pawn_purple"
	_resist(emberlord, {&"phys": 0.9, &"feu": 0.55, &"givre": 1.35, &"arcane": 1.0, &"poison": 0.8, &"foudre": 1.1})
	_save(emberlord, E + "emberlord.tres")

	# MONDE D ORIGINE. Promotion du Gardien-totem, deja dans le jeu : le testeur
	# demandait qu un boss d acte redevienne un monstre courant ; ici c est le
	# chemin inverse, un monstre courant qui prend du galon. Sa silhouette est
	# donc deja connue du joueur, ce qui rend la promotion lisible.
	var totem_elder := _enemy("totem_elder", "Totem ancien", K.MINIBOSS, 6,
		175.0, 26.0, 14, S.SQUARE, Color(0.60, 0.85, 0.55), 66.0)
	totem_elder.anim_key = &"totem_tower"
	_resist(totem_elder, {&"phys": 0.7, &"feu": 1.2, &"givre": 0.95, &"arcane": 1.3, &"poison": 0, &"lent": 0.5})
	_save(totem_elder, E + "totem_elder.tres")

	var chronos := _enemy("chronos", "Chronos", K.BOSS, 10, 320.0, 34.0, 30, S.STAR, Color(0.95, 0.20, 0.25), 84.0)
	chronos.anim_key = &"juggernaut"
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
	var risen := _enemy("risen_ghoul", "Goule levee", K.NORMAL, 1, 9.0, 62.0, 1,
		S.DIAMOND, Color(0.55, 0.65, 0.45), 20.0)
	risen.anim_key = &"vulture"
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

	# RESSUSCITE — lvl_02, La Tour des Sables. Le gardien de la tour n est pas une
	# creature : c est du SABLE tenu en forme. On peut l abattre, il se remet
	# debout, une fois. Le joueur voit la barre se vider, entend la mort, se
	# retourne vers la vague — et il se releve derriere lui.
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
	# Chapeau spongieux : les coups s y enfoncent, le feu le racornit d un coup.
	# Il baigne dans ses propres spores, donc le venin ne lui fait rien.
	_resist(mushroom, {&"phys": 0.75, &"feu": 1.35, &"givre": 1.05, &"arcane": 1.0, &"poison": 0.6})
	_save(mushroom, E + "mushroom.tres")

	# La plante carnivore : l inverse du champignon. Elle ne tient rien, elle
	# MORD — 12 PV pour 88 px/s. La feuille porte une attaque de 13 images, la
	# plus longue morsure du pack.
	var carnivore := _enemy("carnivore_plant", "Plante carnivore", K.FAST, 2, 12.0, 88.0, 3,
		S.TRIANGLE, Color(0.35, 0.70, 0.35), 22.0)
	carnivore.anim_key = &"smallmonster"
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

	# LE GRAND OEIL — MINI-BOSS de `lvl_17`, et un PALIER de l Oeil des courants.
	#
	# POURQUOI UN PALIER ET PAS L ECUMEUR DU CIEL. L Ecumeur etait le candidat
	# evident — il vole, il a ete ecrit pour le Monde volant — mais le chantier
	# des actes 4 et 5 lui a donne la tete du mini-boss de `lvl_11`, et
	# `test_bosses` interdit nommement qu un mini-boss mene deux niveaux. Plutot
	# que de se disputer une tete, on fabrique celle qui manquait.
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
	var great_eye := _enemy("great_eye", "Grand Oeil des courants", K.MINIBOSS, 6,
		105.0, 54.0, 12, S.CIRCLE, Color(0.55, 0.75, 0.95), 52.0)
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
	var dark_mage := _enemy("dark_mage", "Mage noir de Haute-Nacelle", K.MINIBOSS, 6,
		110.0, 42.0, 12, S.STAR, Color(0.45, 0.35, 0.75), 54.0)
	dark_mage.anim_key = &"evilwizard"
	# 110 PV, sous la Matrone gorgone (120) : il est le plus fragile des
	# mini-boss du jeu, et c est le prix de sa distance. Un campeur blinde
	# serait une attente, pas un combat.
	dark_mage.keeps_distance_at = 380.0
	dark_mage.shoot_interval = 2.6
	# 5 degats par trait : plus cher que la fleche du lutin (2), moins qu un
	# contact de P4. Il doit USER le joueur qui tarde a venir le chercher.
	dark_mage.shot_damage = 5
	# Il invoque ses soudures : les pillards qu il a retournes. C est la preuve
	# jouable de ce que l acte raconte — il FABRIQUE les monstres qu on combat.
	dark_mage.summon_def = load(E + "nacelle_raider.tres")
	dark_mage.summon_interval = 7.0
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
	var nightborne := _enemy("shadow_bladesman", "Epeiste d ombre", K.MINIBOSS, 6,
		130.0, 66.0, 13, S.TRIANGLE, Color(0.30, 0.25, 0.45), 52.0)
	nightborne.anim_key = &"nightborne"
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
	_resist(slime_mid, {&"phys": 0.85, &"feu": 1.0, &"givre": 0.85, &"arcane": 1.0,
		&"poison": 0.6, &"foudre": 1.3})
	_save(slime_mid, E + "slime_mid.tres")

	# SLIME ENORME — MINI-BOSS de `lvl_03` (l Ossuaire des Marees, bati sur des
	# monstres qui se multiplient). Il remplace le Pretre goule en tete du palier :
	# un P3 qui soigne n etait pas un palier, c etait une vague de plus.
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
	# le monstre aux ecarts les plus timides du bestiaire.
	chameleon.chameleon_weak_mult = EnemyDef.accentuate(1.5)
	chameleon.chameleon_resist_mult = EnemyDef.accentuate(0.5)
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
	chronos_echo.demoted_from = &"chronos"
	_resist(chronos_echo, {&"phys": 1.1, &"feu": 1.1, &"givre": 0.8, &"arcane": 0.95,
		&"poison": 1.05, &"lent": 0.6})
	_save(chronos_echo, E + "chronos_echo.tres")

	# LES ECHOS DES QUATRE SEIGNEURS DE L ACTE 4 (chantier W4). Meme defaut que le
	# Gardien et Chronos, un acte plus loin : `lvl_16` envoyait Vharn, Sesh, Kaltek
	# et Ymoa EUX-MEMES dans ses vagues ordinaires (195 + 205 PV dans w16_2, 175 +
	# 160 dans w16_3, contact de boss, a difficulte 1,5), et `lvl_13` en citait
	# trois vagues sur cinq. Au banc (90 parties, degats attribues a leur vraie
	# source) : lvl_16 a 48 % et lvl_13 a 44 %, les defaites tombant presque
	# toutes sur w16_3 et w13_4 — Ymoa qui campe, tire et rend son entourage
	# invulnerable, Kaltek qui fabrique des Berserkers, tous deux avec des PV de
	# boss. Pas le boss final : les vagues de troupes.
	#
	# Meme methode : un .tres derive par seigneur, un P4, la feuille du boss sans
	# son agrandissement, en teinte spectrale (AnimCatalog.MODULATE). Les tables de
	# resistances gardent le sens de celles des seigneurs, ecarts ramenes dans la
	# borne commune des monstres (+/- 35 %).
	#
	# REGLE PAR LA MESURE, pas a l estime (60 parties par variante, memes graines) :
	#   - un tiers des PV et les mecaniques retirees : 60/60 sur les deux niveaux.
	#     La fin de la campagne ne se jouait plus ;
	#   - PV pres du plafond du garde-fou (48 % du seigneur) et les mecaniques
	#     d Ymoa et de Kaltek rendues en plus petit : 54/60 et 58/60 ;
	#   - DEUX echos de chaque (x2) : 4/60 et 6/60, un mur de nouveau ;
	#   - retenu : ce reglage, et DEUX echos de Kaltek dans les vagues ou il
	#     descend (w13_4, w16_3) : 41/60 et 46/60. Des fins d acte dures, qui ne
	#     sont plus des murs, et le boss final retrouve des defaites a son nom.
	#
	# ECHO DE VHARN — deux coups ignores au lieu de six : la lecon « ouvre sur le
	# gros sort » tient en une seule decision.
	var anvil_echo := _enemy("demon_anvil_echo", "Echo de Vharn", K.SHIELDED, 4, 94.0, 28.0, 6,
		S.SQUARE, Color(0.78, 0.52, 0.34), 40.0)
	anvil_echo.anim_key = &"golem_blue"
	anvil_echo.hits_immune = 2
	anvil_echo.demoted_from = &"demon_anvil"
	# Immunise au vent comme son seigneur (ANCRES_AU_SOL) : l echo est la meme
	# enclume en petit, le joueur doit y lire la meme regle.
	_resist(anvil_echo, {&"phys": 0.7, &"vent": 0.0, &"feu": 0.75, &"givre": 1.25,
		&"arcane": 1.2, &"poison": 0, &"foudre": 1.05, &"lent": 0.6})
	_save(anvil_echo, E + "demon_anvil_echo.tres")

	# ECHO DE SESH — il gobe encore, comme le Glouton dont il porte la feuille :
	# laisser vivre la vermine autour de lui reste une erreur qui se paie.
	var maw_echo := _enemy("demon_maw_echo", "Echo de Sesh", K.DEVOURER, 4, 98.0, 40.0, 6,
		S.CAPSULE, Color(0.88, 0.42, 0.18), 40.0)
	maw_echo.anim_key = &"dino"
	maw_echo.devours = true
	maw_echo.demoted_from = &"demon_maw"
	_resist(maw_echo, {&"phys": 0.85, &"feu": 0.7, &"givre": 1.25, &"arcane": 1.05,
		&"poison": 0.75, &"foudre": 1.1})
	_save(maw_echo, E + "demon_maw_echo.tres")

	# ECHO DE KALTEK — la rage ET les esclaves, en plus petit : un Berserker toutes
	# les 9 s (7,5 pour Kaltek), deux vivants au plus (trois), une rage qui
	# plafonne a 1,35 (1,7). Sans les esclaves il n etait qu un Berserker de plus.
	var chain_echo := _enemy("demon_chain_echo", "Echo de Kaltek", K.ENRAGER, 4, 84.0, 44.0, 6,
		S.TRIANGLE, Color(0.62, 0.20, 0.45), 38.0)
	chain_echo.anim_key = &"warrior_red"
	chain_echo.enrage_speed_pct = 6.0
	chain_echo.enrage_cap = 1.35
	chain_echo.summon_def = load(E + "berserker.tres")
	chain_echo.summon_interval = 9.0
	chain_echo.summon_count = 1
	chain_echo.summon_max_alive = 2
	chain_echo.demoted_from = &"demon_chain"
	_resist(chain_echo, {&"phys": 1.1, &"feu": 1.05, &"givre": 1.2, &"arcane": 1.0,
		&"poison": 1.05, &"foudre": 0.9})
	_save(chain_echo, E + "demon_chain_echo.tres")

	# ECHO D YMOA — il campe au fond et tient son cercle, comme Ymoa, mais son
	# aura est plus courte (150 px contre 210) et ses tirs plus rares et plus
	# faibles (3 toutes les 5 s contre 4 toutes les 4,2 s). La question du temple,
	# aller chercher le protecteur, reste entiere. C est lui qui fait la vague :
	# deux echos d Ymoa dans la meme vague rendaient le niveau injouable (voir
	# plus haut), un seul la rend dure.
	var circle_echo := _enemy("demon_circle_echo", "Echo d Ymoa", K.GUARDIAN, 4, 77.0, 26.0, 6,
		S.HEXAGON, Color(0.45, 0.75, 0.85), 40.0)
	circle_echo.anim_key = &"totem_tower"
	circle_echo.aura_shield_radius = 150.0
	circle_echo.keeps_distance_at = 480.0
	circle_echo.shoot_interval = 5.0
	circle_echo.shot_damage = 3
	circle_echo.demoted_from = &"demon_circle"
	_resist(circle_echo, {&"phys": 0.7, &"feu": 0.9, &"givre": 1.1, &"arcane": 1.3,
		&"poison": 0, &"foudre": 1.15, &"lent": 0.6})
	_save(circle_echo, E + "demon_circle_echo.tres")

	# --- LE BRISEUR DE TERTRES (chantier W3) -------------------------------
	#
	# MINI-BOSS de `lvl_04`, le Grand Appel. Le golem qui a creuse le Grand
	# Cimetiere : ce qui depasse du sol, il l aplanit. Toutes les 7 s il s arrete,
	# marque le mur, l arbre ou l autel le plus proche (560 px, la moitie du
	# terrain) et l abat 1,8 s plus tard d une frappe au sol. Il epargne l eau.
	#
	# POURQUOI `lvl_04` : c est le premier niveau dont le deck porte un objet de
	# terrain qu on a INTERET a garder (le Totem de coeur-de-bois, deux exemplaires,
	# qui detourne le flux de l Ensevelisseur). Place ailleurs, sa mecanique ne se
	# verrait jamais — il marcherait vers un mage qui n a rien pose. Ici il apprend,
	# DEUX vagues avant le boss, que le decor tombe si on laisse vivre celui qui le
	# brise : la lecon sert immediatement contre l Ensevelisseur.
	#
	# Il remplace le Gardien d ossements en tete du palier (qui descend toujours en
	# `w3_5`, donc reste du monde 2) avec un poids voisin : 150 PV contre 165.
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
	pierce.sfx_key = &"arrow_laser"
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
	ember.sfx_key = &"fire_ignite"
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

	# --- Rares ---
	var haste := _card("quickening", "Precipitation",
		"Accelere l incantation de 60 pourcent pendant 6 s.", GameEnums.Rarity.RARE, 0.8,
		GameEnums.Targeting.NONE, [],
		[_spec("self_haste", 60.0, 6.0)])
	haste.fx_key = &"ray_wheel"
	haste.sfx_key = &"spell_rise"
	_save(haste, "res://resources/cards/rare/quickening.tres")

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
	drag.sfx_key = &"zap_long"
	_save(drag, "res://resources/cards/rare/temporal_drag.tres")

	var cycle := _card("cycle_of_thought", "Cycle de pensee",
		"Defausse 2 cartes, en pioche 2.", GameEnums.Rarity.RARE, 0.6,
		GameEnums.Targeting.NONE, [],
		[_spec("discard_draw", 0.0, 0.0, 0.0, {&"count": 2})])
	cycle.fx_key = &"cycle_swirl"
	cycle.sfx_key = &"spell_deep"
	_save(cycle, "res://resources/cards/rare/cycle_of_thought.tres")

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
		GameEnums.Rarity.RARE, 1.5, GameEnums.Targeting.POSITION, [],
		[_spec("build_wall", 0.0, 20.0, 200.0, {&"thickness": 60.0})])
	wall.fx_key = &"stone_peak"
	wall.sfx_key = &"stone_shove"
	_save(wall, "res://resources/cards/rare/stone_wall.tres")

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
	ice_wall.sfx_key = &"zap_short"
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
	purge.sfx_key = &"ward_light"
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
	rift.sfx_key = &"spell_grand"
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
	spark.sfx_key = &"spell_arcane"
	_save(spark, "res://resources/cards/common/spark.tres")

	var frost_rain := _card("frost_rain", "Pluie de givre",
		"Tres grande zone : 2 degats de GLACE par seconde et ralentissement de "
		+ "30 pourcent pendant 8 s.", GameEnums.Rarity.COMMON, 1.8,
		GameEnums.Targeting.POSITION, [GameEnums.DamageTag.SLOW],
		[_spec("ground_zone", 2.0, 8.0, 260.0, {&"slow_pct": 30.0})])
	frost_rain.fx_key = &"crystal_field"
	frost_rain.sfx_key = &"drip_frost"
	_save(frost_rain, "res://resources/cards/common/frost_rain.tres")

	var brazier := _card("brazier", "Brasier",
		"Zone de FEU : 14 degats par seconde pendant 6 s.", GameEnums.Rarity.RARE, 2.1,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 14.0, 6.0, 140.0)])
	brazier.fx_key = &"flame_pillar"
	brazier.sfx_key = &"fire_ignite"
	_save(brazier, "res://resources/cards/rare/brazier.tres")

	var meteor := _card("meteor", "Meteore",
		"Long a invoquer : 60 degats de FEU dans une petite zone.", GameEnums.Rarity.RARE, 2.8,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 200.0, 0.3, 120.0)])
	meteor.fx_key = &"meteor_streak"
	meteor.sfx_key = &"blast_pop"
	_save(meteor, "res://resources/cards/rare/meteor.tres")

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
	deep_freeze.sfx_key = &"zap_short"
	_save(deep_freeze, "res://resources/cards/epic/deep_freeze.tres")

	# 8 s et non plus 6 (co-auteur, vague 8 : « duree un peu plus longue ») :
	# a la vitesse de depart, 6 s de monde laissaient a peine le temps d y poser
	# une seconde incantation depuis que les incantations sont plus longues.
	var weakness := _card("weakness_mark", "Marque de faiblesse",
		"Zone ou les monstres subissent le double de degats pendant 8 s.", GameEnums.Rarity.EPIC, 1.3,
		GameEnums.Targeting.POSITION, [],
		[_spec("ground_zone", 0.0, 8.0, 200.0, {&"vuln_mult": 2.0})])
	weakness.fx_key = &"diamond_mark"
	weakness.sfx_key = &"charge_magic"
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
	var salt := _card("salt_spiral", "Spirale de sel",
		"Aspire les monstres vers son centre pendant 3 s. Ne fait aucun degat : "
		+ "elle prepare le sort suivant.",
		GameEnums.Rarity.RARE, 1.2, GameEnums.Targeting.POSITION,
		[],
		[_spec("vortex_pull", 150.0, 3.0, 220.0)])
	salt.fx_key = &"spiral_salt"
	salt.sfx_key = &"wind_gust"
	_save(salt, "res://resources/cards/rare/salt_spiral.tres")

	# Acte II / lvl_04 — enseignee par le Pretre goule repenti.
	# Le Grand Appel est le niveau le plus LONG : la penurie de cartes y tue plus que
	# les monstres. Garder ses deux prochains sorts, c est doubler sa main utile.
	# UN sort et non plus deux (co-auteur, vague 8) : a deux, la rare faisait le
	# travail de l Echo de la main, la legendaire du meme verbe.
	var recall := _card("bone_recall", "Rappel d ossements",
		"Le prochain sort lance revient en main au lieu d etre defausse.",
		GameEnums.Rarity.RARE, 0.9, GameEnums.Targeting.NONE, [],
		[_spec("retain_next", 1.0)])
	# L AME QUI S ENVOLE. La feuille montre un crane violet qui file en laissant une
	# trainee : une ame qu on rappelle. C est le verbe meme de la carte, qui fait
	# REVENIR les sorts en main au lieu de les laisser partir a la defausse.
	# Premiere des trois feuilles d OMBRE du jeu, et la carte vient de l Ossuaire :
	# l element colle au lieu autant qu a l effet.
	recall.fx_key = &"dark_soul"
	recall.sfx_key = &"ward_deep"
	_save(recall, "res://resources/cards/rare/bone_recall.tres")

	# Acte III / lvl_05 — enseignee par le Berserker libere.
	# Les Forges envoient du blindage lent. On ne le tue pas vite : on le REPOUSSE,
	# et le temps gagne vaut plus que les degats. D ou une magnitude modeste et un
	# recul important.
	var chain := _card("chain_break", "Rupture de chaine",
		"18 degats de VENT en zone, puis repousse violemment tout ce qui reste debout.",
		GameEnums.Rarity.RARE, 1.4, GameEnums.Targeting.POSITION,
		[],
		[_spec("knockback", 18.0, 0.0, 190.0, {&"push": 260.0})])
	chain.fx_key = &"shatter_burst"
	chain.sfx_key = &"impact_heavy"
	_save(chain, "res://resources/cards/rare/chain_break.tres")

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
	void_grip.sfx_key = &"ward_light"
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
	ledger.sfx_key = &"spell_deep"
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
	dial.sfx_key = &"blast_long"
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
	repulsion.sfx_key = &"impact_heavy"
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
	var purify := _card("purifying_light", "Lumiere purifiante",
		"Petite zone : les monstres perdent rage, boucliers et effets en cours.",
		GameEnums.Rarity.RARE, 1.0, GameEnums.Targeting.POSITION,
		[],
		[_spec("dispel_zone", 0.0, 0.0, 150.0)])
	# LA COLONNE DE LUMIERE, sur la carte qui s appelle Lumiere purifiante.
	# Cases de 192 px, et une forme VERTICALE qui tombe du ciel sur un point precis :
	# c est la lecture exacte d une dissipation ponctuelle. `halo_ring` etait un
	# anneau de 64 px, invisible au milieu du cercle de portee.
	purify.fx_key = &"lightpillar"
	purify.sfx_key = &"ward_light"
	_save(purify, "res://resources/cards/rare/purifying_light.tres")

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
	bastion.sfx_key = &"stone_shove"
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
	venom.sfx_key = &"spell_crackle"
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
	totem.sfx_key = &"stone_shove"
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
	# `whoosh_deep` et non `spell_crackle` : ce dernier portait deja trois cartes,
	# et le projet tient a ce qu un son soit partage entre deux ou trois au plus —
	# c est ce qui evite que tous les sorts s entendent pareil. Un souffle grave
	# convient de toute facon mieux a un arbre qui perce le sol qu un crepitement.
	sapling.sfx_key = &"whoosh_deep"
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
	tide.sfx_key = &"drip_frost"
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
	# Un trait qui part, comme la Fleche percante : `spell_crackle` porte deja
	# trois cartes.
	dart.sfx_key = &"arrow_laser"
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
	surge.sfx_key = &"spell_rise"
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
	river.sfx_key = &"wind_gust"
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
	altar.sfx_key = &"whoosh_summon"
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
	brambles.sfx_key = &"impact_heavy"
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
	pit.sfx_key = &"blast_pop"
	_save(pit, "res://resources/cards/epic/terrain_pit.tres")


## Deck pre-etabli EXPLICITE : [[chemin, exemplaires], ...] -> une entree par exemplaire.
## Ne depend pas de copies_in_starter, ce qui permet d y placer des rares.
func _deck(spec: Array) -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for pair in spec:
		var card: SpellCard = load(pair[0])
		for i in int(pair[1]):
			out.append(card)
	return out


func _entry(def_path: String, count: int, delay: float, offset: float = 0.0) -> WaveEntry:
	var w := WaveEntry.new()
	w.enemy = load(def_path)
	w.count = count
	w.spawn_delay = delay
	w.start_offset = offset
	return w


func _waves_and_level() -> void:
	var E := "res://resources/enemies/"

	# LE TUTORIEL EN TROIS VAGUES (chantier W4, demande du testeur, reste de la
	# v2). Deux essais precedents (quatre puis cinq vagues) RETIRAIENT des vagues
	# de l ancienne courbe et laissaient le boss a plus du double de ce qui le
	# precedait (« 356 PV apres 165 ») : un mur, refuse a juste titre par
	# test_balance. Ici la courbe est REFAITE entiere, trois paliers qui montent
	# chacun sous x2 : 106 -> 189 -> 356 PV.
	#
	# Chaque vague apprend UN geste, et porte ce que les objectifs du niveau
	# demandent (volants, serie de morts) :
	#   1. viser : gnomes espaces, puis trois feux follets qui VOLENT, puis une
	#      nuee de rats — la premiere cible faite pour une zone ;
	#   2. le Gardien, premiere grosse cible, escorte legere (difficulte 0,9) ;
	#   3. Chronos et ses lutins (difficulte 0,6 depuis le chantier W7, voir w3).
	# Mesure (60 parties, memes graines) : 59/60 et 257 % de vitesse a l arrivee,
	# contre 57/60 et 280 % pour les six vagues. Le niveau dure ~96 s au lieu de
	# ~173 s : c est le but.
	var w1 := WaveDef.new()
	w1.id = &"w1"
	# 26 s : a 24 s la vague serait la plus dense du niveau au-dessus du rythme
	# de pioche (garde-fou de test_balance.gd, neuf decisions dans la vague).
	w1.duration = 26.0
	w1.difficulty = 1.0
	w1.entries = [
		_entry(E + "gnome.tres", 5, 2.2),
		_entry(E + "wisp.tres", 3, 2.0, 8.0),
		_entry(E + "rat_swarm.tres", 1, 1.0, 16.0),
	]
	_save(w1, "res://resources/waves/w1.tres")

	var w2 := WaveDef.new()
	w2.id = &"w1_miniboss"
	w2.duration = 30.0
	# Le mini-boss EST le saut de difficulte : son escorte reste legere pour que
	# le joueur puisse se concentrer sur lui. Sa puissance (14) tient aussi la
	# regle du Massacre : sa vague 5 reste sous l avant-derniere du niveau 1.
	w2.difficulty = 0.9
	w2.is_miniboss = true
	w2.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "gnome.tres", 3, 2.5, 10.0),
		_entry(E + "sprite.tres", 3, 1.6, 18.0),
		_entry(E + "rat_swarm.tres", 1, 1.0, 22.0),
	]
	_save(w2, "res://resources/waves/w1_miniboss.tres")

	var w3 := WaveDef.new()
	w3.id = &"w1_boss"
	w3.duration = 40.0
	# CHRONOS ALLEGE (chantier W7, demande du co-auteur : « trop de vie pour un
	# tutoriel »). Mesure au banc avant, a difficulte 1,0 (320 PV) : 29 s pour
	# l abattre avec le bot qui choisit, le plus long combat de boss du jeu apres
	# le Sceau de Tombol (lvl_21) et la Sorciere des fosses (lvl_19), bien au-dela
	# du boss de lvl_02 (18 s). Avec l ancien bot (premiere option partout), il
	# n etait abattu que 8 fois sur 29 : le tutoriel se finissait sur un boss qui
	# traverse. La difficulte de SA vague porte ses PV sans toucher sa fiche (le
	# Massacre garde le Chronos entier) ; la courbe reste montante (189 -> 214 PV)
	# et le saut sous x2.
	w3.difficulty = 0.6
	w3.is_boss = true
	w3.entries = [
		_entry(E + "chronos.tres", 1, 1.0),
		_entry(E + "sprite.tres", 6, 1.2, 6.0),
	]
	_save(w3, "res://resources/waves/w1_boss.tres")

	# --- Objectifs ---
	# Chaque niveau porte SES trois objectifs, leurs cartes et ses cartes
	# nouvelles, poses par _poser_progression() depuis la table unique de fin de
	# fichier (_progression_de, dans l ordre de jeu). Le dossier est vide ici
	# avant d etre rempli : un objectif retire de la table ne doit pas survivre
	# en .tres orphelin que ContentDB continuerait d indexer.
	_purger_objectifs()

	# --- Niveau ---
	var lvl := LevelDef.new()
	lvl.id = &"lvl_01"
	lvl.display_name = "Les Marches du Temps"
	lvl.terrain = "grass"
	# Scenes de visual novel qui encadrent le niveau (docs/histoire.md,
	# acte 1). Generees par tools/make_story.gd.
	lvl.intro_story = &"lvl_01_intro"
	lvl.outro_story = &"lvl_01_outro"
	lvl.backdrop = "act1_sky"
	# TROIS vagues depuis le chantier W4 : voir la courbe plus haut. Le pool garde
	# les monstres des anciennes vagues 3 et 5 : il ne sert qu au Massacre et a la
	# vitrine, et l amputer changerait le tirage du mode infini.
	lvl.waves = [w1, w2, w3]
	lvl.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "golem.tres"),
		load(E + "wisp.tres"), load(E + "rat_swarm.tres"), load(E + "hopper.tres"),
		load(E + "imp_archer.tres"), load(E + "sand_serpent.tres"),
		load(E + "hornblower.tres"), load(E + "shade.tres"),
	]
	var C := "res://resources/cards/"
	# DECKS DE 12 CARTES (vague 8, co-auteur) : chaque deck de campagne garde ses
	# cartes differentes — les cartes nouvelles et les recompenses sont reglees
	# sur ce que ces decks font posseder, en retirer une en rendrait d autres
	# « deja possedees » ou jamais proposees — et perd trois exemplaires, pris la
	# ou l element du lieu mord le moins (facteur moyen des monstres du niveau,
	# pondere par leurs PV, celui du rapport du banc). Les cartes que comptent les
	# objectifs du niveau gardent leurs exemplaires. Ici : un Trait, un Champ de
	# givre (la glace mord a 0,75 aux Marches) et un Mur de moins. C est aussi le
	# deck par defaut (DeckRules.default_deck_ids).
	lvl.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/frost_field.tres", 1],
		[C + "common/ember_pool.tres", 2],
		[C + "common/fireball.tres", 2],
		[C + "rare/stone_wall.tres", 1],
	])
	# Le niveau 1 ne debloque qu UN niveau : la campagne doit rester lineaire au
	# demarrage. La premiere fourche est en lvl_04 (voir docs/histoire.md section 8).
	lvl.next_levels = [&"lvl_02"]
	lvl.act = 1
	lvl.subtitle = "Le matin de la premiere attaque"
	lvl.intro_text = "Le royaume est tombe. Tu as remonte le temps jusqu ici, le \
premier matin, pour trouver qui a donne l ordre. Ce ne sont que des gnomes et des \
lutins — mais ils marchent en colonne, et la vermine ne marche pas en colonne."
	lvl.outro_text = "Le Gardien a ri en mourant. Il n a jamais voulu de cette \
guerre : sa tribu a recu un ordre venu de sous la terre, et refuser coutait plus cher \
qu obeir. Chronos n etait qu un huissier venu verifier les delais."
	_poser_progression(lvl)
	_save(lvl, "res://resources/levels/lvl_01.tres")

	# --- Niveau 2 : plus dense, plus rapide, le boss escorte ---
	var v1 := WaveDef.new()
	v1.id = &"w2_1"
	v1.duration = 26.0
	# Le niveau 2 PROLONGE la courbe du niveau 1, il ne repart pas d un mur : sa
	# premiere vague se situait au-dessus de la cinquieme du niveau precedent.
	v1.difficulty = 1.1
	v1.entries = [
		_entry(E + "gnome.tres", 4, 2.0),
		_entry(E + "sprite.tres", 3, 2.0, 8.0),
		_entry(E + "jelly_mid.tres", 2, 2.0, 16.0),
	]
	_save(v1, "res://resources/waves/w2_1.tres")

	var v2 := WaveDef.new()
	v2.id = &"w2_2"
	v2.duration = 26.0
	v2.difficulty = 1.2
	# Mesure au banc : c est ICI que le niveau 2 se perdait. `rat_swarm, 3` fait
	# 12 rats a 110 px/s des la seconde 0 — plus de corps que n en envoie la
	# derniere vague du niveau 1 — et les trois feux follets qui suivent esquivent
	# 35 % des coups. Les traces de PV montraient la chute sur cette vague seule
	# (v2 a 0, 12 ou 18 PV). Deux nuees suffisent a poser la lecon.
	v2.entries = [
		_entry(E + "rat_swarm.tres", 2, 2.0),
		_entry(E + "wisp.tres", 3, 2.0, 7.0),
		_entry(E + "berserker.tres", 1, 2.5, 14.0),
		_entry(E + "hornblower.tres", 1, 1.0, 19.0),
	]
	_save(v2, "res://resources/waves/w2_2.tres")

	var v3 := WaveDef.new()
	v3.id = &"w2_3"
	v3.duration = 28.0
	# Chevalier du vide (annule le 1er coup) et Ombre (encaisse moins en phase)
	# demandent chacun plusieurs sorts. Les cumuler dans la meme vague rendait
	# celle-ci infranchissable : on les repartit.
	v3.difficulty = 1.3
	v3.entries = [
		_entry(E + "void_knight.tres", 1, 2.5),
		_entry(E + "shade.tres", 2, 2.5, 8.0),
		_entry(E + "ghoul_priest.tres", 1, 1.0, 15.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 20.0),
	]
	_save(v3, "res://resources/waves/w2_3.tres")

	var v4 := WaveDef.new()
	v4.id = &"w2_4_miniboss"
	v4.duration = 32.0
	v4.difficulty = 1.2
	v4.is_miniboss = true
	# LE CORNISTE, et non le Gardien. Le meme Gardien menait SIX mini-boss sur
	# sept, alors que docs/histoire.md le fait mourir en `lvl_04` — sa poitrine
	# ouverte revele la plaque de metal qui lance toute l intrigue. Le voir
	# revenir vivant ensuite contredisait la scene que le joueur venait de lire.
	# Le Corniste etait deja son escorte ici : il PRESSE les autres, donc en
	# faire la tete de vague change la nature du probleme, pas seulement sa
	# taille.
	#
	# CHANTIER I2 — LA MATRONE GORGONE PREND LA TETE, le Corniste redevient son
	# escorte. Pourquoi ce remplacement et pas une vague de plus :
	#
	# Le Corniste est un monstre ORDINAIRE de puissance 3 (18 PV). Il menait ce
	# palier par defaut, faute de mini-boss disponible au moment ou le Gardien a
	# ete retire — c etait le moins mauvais choix, pas un bon. Un mini-boss doit
	# poser une QUESTION que la vague normale ne pose pas, et « il presse les
	# autres » est une question d intensite, pas de nature.
	#
	# La Matrone, elle, gele DEUX cartes de la main : le joueur decouvre ici, au
	# niveau 2, que sa main peut etre mutilee et que la reponse est sur le
	# terrain. C est le palier pedagogique de la mecanique, avant la Reine a
	# trois cartes dans le Massacre.
	#
	# Le Corniste RESTE dans la vague et y gagne son role : son buff de vitesse
	# accelere l escorte pendant que le joueur a deux cartes en moins. Deux
	# problemes qui se multiplient, la ou ils s additionnaient.
	#
	# L escorte est ALLEGEE en consequence (six lutins au lieu de six plus deux
	# serpents) : la Matrone pese 120 PV la ou le Corniste en pesait 18, et le
	# garde-fou d equilibrage refuse qu une vague double la precedente. C est
	# exactement le trou inverse de celui mesure en septembre — il fallait alors
	# du nombre pour compenser une tete legere, il faut maintenant en retirer
	# pour compenser une tete lourde.
	v4.entries = [
		_entry(E + "gorgon_matron.tres", 1, 1.0),
		_entry(E + "hornblower.tres", 1, 4.0, 5.0),
		_entry(E + "sprite.tres", 5, 1.5, 9.0),
		_entry(E + "hopper.tres", 3, 1.6, 18.0),
	]
	_save(v4, "res://resources/waves/w2_4_miniboss.tres")

	var v5 := WaveDef.new()
	v5.id = &"w2_5"
	v5.duration = 28.0
	v5.difficulty = 1.4
	# L Ecumeur du ciel APPARAIT ICI, tard dans la vague. Ce n est pas un
	# habillage : `WaveSpawner.build_membership()` deduit le monde d un monstre
	# de sa DENSITE dans les vagues ECRITES. Un mini-boss qui n apparait dans
	# aucune vague n appartient a aucun monde, donc le mode infini ne le
	# proposera JAMAIS — verifie par sonde, les quatre nouveaux etaient
	# invisibles. Le creer ne suffisait pas, il faut le montrer une fois.
	# CHANTIER I2 — LA GORGONE COMMUNE descend ici, apres sa Matrone. L ordre est
	# volontairement INVERSE de l habitude : le joueur voit d abord la mecanique
	# sur une tete de vague annoncee, puis la retrouve sur un monstre ordinaire
	# qu il n attendait pas. C est ce second temps qui la lui apprend vraiment —
	# une carte gelee au milieu d une vague banale, et il sait deja quoi chercher
	# a l ecran.
	v5.entries = [
		_entry(E + "hive.tres", 1, 3.0),
		_entry(E + "gorgon_gazer.tres", 2, 3.0, 6.0),
		_entry(E + "golem.tres", 1, 2.5, 12.0),
		_entry(E + "sand_serpent.tres", 3, 2.0, 18.0),
	]
	_save(v5, "res://resources/waves/w2_5.tres")

	var v6 := WaveDef.new()
	v6.id = &"w2_6"
	v6.duration = 30.0
	v6.difficulty = 1.55
	# L Ecumeur du ciel APPARAIT ICI. Ce n est pas un habillage :
	# `WaveSpawner.build_membership()` deduit le monde d un monstre de sa
	# DENSITE dans les vagues ECRITES. Un mini-boss absent de toute vague
	# n appartient a aucun monde, donc le mode infini ne le proposera JAMAIS —
	# verifie par sonde, les quatre nouveaux etaient invisibles.
	#
	# En vague 6 et non 5 : le garde-fou d equilibrage a attrape le premier
	# essai ("428 PV apres 182"), ses 96 PV creant un saut de plus de x2 sur une
	# vague legere. La vague 6 porte deja le Gardien-totem, elle l absorbe.
	v6.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "skyreaver.tres", 1, 1.0, 20.0),
		_entry(E + "gnome.tres", 4, 1.6, 3.0),
		_entry(E + "glutton.tres", 1, 1.0, 11.0),
		_entry(E + "sprite.tres", 5, 1.5, 16.0),
	]
	_save(v6, "res://resources/waves/w2_6.tres")

	var v7 := WaveDef.new()
	v7.id = &"w2_7_boss"
	v7.duration = 45.0
	v7.difficulty = 1.25
	v7.is_boss = true
	# LE GOLEM DE PIERRE, et non Chronos. Chronos fermait QUATRE niveaux sur
	# sept, dont le premier et le dernier : le joueur affrontait deux adversaires
	# uniques sur toute la campagne. Son retour en `lvl_07` reste voulu — c est
	# la boucle narrative, "l huissier du niveau 1 revient" — mais il doit se
	# meriter, donc il ne ferme plus les niveaux du milieu.
	#
	# Pas le Seigneur Spectre non plus : il ferme deja `lvl_06`, ou sa portee de
	# 620 px EST la lecon du niveau. Pas le Golem non plus : il arrive DEJA par
	# deux a la vague 5 du meme niveau, en faire la tete de la vague 7 l aurait
	# banalise — et le garde-fou d equilibrage l a attrape (294 PV apres 94, le
	# saut depassait x2).
	#
	# LE SABLIER (chantier I), et non plus le Gardien-totem. Le Gardien-totem
	# tenait la place faute de mieux : il n a aucune mecanique de boss, il apparait
	# DEJA comme monstre ordinaire dans quatre niveaux, et mener une vague de boss
	# ne changeait rien a ce qu il demandait au joueur.
	#
	# Le Coagule, lui, change la condition de VICTOIRE : il se releve une fois avec
	# 40 % de ses PV. C est la bonne place pour l apprendre — au deuxieme niveau,
	# avec une escorte legere et sans autre mecanique a gerer en meme temps. Le
	# joueur qui a garde une carte en reserve gagne ; celui qui a tout vide au
	# moment ou la barre touchait zero paie sa lecon sans perdre la partie.
	#
	# L escorte est volontairement CLAIRSEMEE et arrive TOT : le releve doit tomber
	# dans un moment calme, sinon le joueur regarde ailleurs et ne voit rien.
	#
	# CHANTIER I2 — LA REINE GORGONE entre ici comme ESCORTE, tard dans la vague.
	# Ce n est pas un habillage, c est la condition de son existence : elle n a
	# pas de niveau de campagne (les sept boss sont pris), donc elle regne sur le
	# Massacre — et `build_membership()` deduit le monde d un monstre de sa
	# DENSITE dans les vagues ECRITES. Sans cette apparition, elle n appartient a
	# aucun monde, `pick_boss()` ne la considere jamais, et le joueur ne la
	# rencontre nulle part. Le piege exact mesure en septembre sur quatre
	# mini-boss : le .tres existait, le joueur ne les voyait pas.
	#
	# A 30 s, donc APRES le releve du Coagule (il tombe vers la 20e seconde) :
	# trois cartes gelees pendant le releve rendrait la scene illisible, alors que
	# trois cartes gelees APRES, quand le joueur croit la vague finie, est
	# exactement la surprise qu on veut. Une seule, et elle est lente (28 px/s) :
	# elle ferme la vague, elle ne la double pas.
	v7.entries = [
		_entry(E + "blood_coagulum.tres", 1, 1.0),
		_entry(E + "hopper.tres", 4, 2.0, 8.0),
		_entry(E + "sprite.tres", 3, 2.0, 18.0),
		_entry(E + "gorgon_queen.tres", 1, 1.0, 30.0),
	]
	_save(v7, "res://resources/waves/w2_7_boss.tres")

	var lvl2 := LevelDef.new()
	lvl2.id = &"lvl_02"
	lvl2.display_name = "La Tour des Sables"
	lvl2.terrain = "sand"
	# Scenes de visual novel qui encadrent le niveau (docs/histoire.md,
	# acte 1). Generees par tools/make_story.gd.
	lvl2.intro_story = &"lvl_02_intro"
	lvl2.outro_story = &"lvl_02_outro"
	lvl2.backdrop = "act1_sky"
	# SIX vagues et non sept. Le testeur demandait "niveau 2 en 4 vagues", mais
	# le garde-fou d equilibrage refuse d aller si bas : chaque vague retiree est
	# un palier en moins, et a cinq vagues le saut v4 -> v6 depassait le double
	# ("471 PV apres 182"). On retire v2 seule, dont les 86 PV faisaient doublon
	# avec v1 (94 PV) — deux vagues d ouverture de meme poids n apprennent pas
	# deux choses differentes.
	lvl2.waves = [v1, v3, v4, v5, v6, v7]
	lvl2.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "shade.tres"), load(E + "imp_archer.tres"),
		load(E + "sand_serpent.tres"), load(E + "hopper.tres"),
		load(E + "hornblower.tres"), load(E + "golem.tres"), load(E + "berserker.tres"),
		load(E + "void_knight.tres"), load(E + "jelly.tres"), load(E + "ghoul_priest.tres"),
		load(E + "hive.tres"), load(E + "totem_guardian.tres"), load(E + "glutton.tres"),
		load(E + "behemoth.tres"),
		# CHANTIER I2 — la lignee gorgone, rencontree dans ce niveau.
		load(E + "gorgon_gazer.tres"),
	]
	# Le niveau 2 envoie le DOUBLE de PV du niveau 1 : son deck doit suivre, sinon
	# le joueur affronte deux fois plus avec les memes outils. Plus de zones, qui
	# sont la seule facon de traiter plusieurs monstres par sort.
	# La Nappe montante entre ICI, au premier niveau qui envoie des groupes RAPIDES
	# (sprites, nuees) : contre un sprite qui descend vite, la nappe rend au joueur
	# les trois secondes qu il vient de perdre.
	#
	# UN exemplaire de Nappe et pas deux. Mesure au banc, 30 parties : a deux
	# exemplaires le niveau 2 montait a 30 victoires sur 30, hors de la bande
	# 60-95 %. Avec un exemplaire la carte se joue encore une fois par partie sans
	# transformer le niveau en promenade.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Meteore et Nappe. Sortent le Champ de givre, le Mur, l Entrave
	# et le Brasier (un exemplaire chacun) : leurs places vont aux zones de feu et
	# au Trait, pour que le deck garde le meme poids de degats.
	lvl2.exploration_deck = _deck([
		[C + "common/fireball.tres", 3],
		[C + "common/ember_pool.tres", 2],
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/arcane_bolt.tres", 1],
		[C + "rare/meteor.tres", 2],
		[C + "rare/tidal_pool.tres", 1],
	])
	_poser_progression(lvl2)
	# CHANTIER N — le village mene maintenant a LA ROUTE DU MAIRE (`lvl_08`), qui
	# est le troisieme niveau de l acte 1 dans docs/histoire.md. C est `lvl_09`,
	# fin de l acte, qui rendra la main a l acte 2 en `lvl_03`. Le numero ne suit
	# plus l ordre de jeu — c est le prix assume de ne pas renumeroter, et il se
	# paie ici, sur deux lignes, plutot que dans les sauvegardes des joueurs.
	lvl2.next_levels = [&"lvl_08"]
	lvl2.act = 1
	lvl2.subtitle = "L ile qui a commence a tomber"
	lvl2.intro_text = "La Tour des Sables se decroche : le temps y coule de travers, \
et des creatures qui n ont rien a faire sur une ile volante s y entassent. Ombres, \
Chevaliers du vide, Pretres goules. Ils ne t attaquent pas. Ils FUIENT."
	lvl2.outro_text = "Ils fuyaient le puits. Sous la tour s ouvre une descente vers \
le Grand Cimetiere — et c est de la-bas qu est venu l ordre."
	_save(lvl2, "res://resources/levels/lvl_02.tres")

	# CHANTIER N — l acte 1 compte QUATRE niveaux (docs/histoire.md section 3),
	# pas deux. `lvl_08` et `lvl_09` le completent ; ils portent `act = 1` et se
	# chainent derriere `lvl_02`, puis rendent la main a l acte 2 en `lvl_03`.
	_acte_1_suite(C, E)
	_acte_2(C, E)
	_acte_3(C, E)
	_acte_final(C, E)
	# CHANTIER N2 — les actes 2 et 3 comptent quatre et cinq niveaux
	# (docs/histoire.md sections 4 et 5). Ces deux fonctions les completent :
	# les Sky Lands (`lvl_17`, `lvl_18`) et la poursuite du Roi squelette dans
	# le cimetiere de Tombol (`lvl_19`, `lvl_20`, `lvl_21`).
	_acte_2_suite(C, E)
	_acte_3_suite(C, E)
	# CHANTIER N3 — LA FIN DU JEU. L acte 4 compte cinq niveaux et l acte 5 trois
	# (docs/histoire.md sections 6 et 7).
	#
	# `_acte_4_suite` ajoute les trois grands demons qui manquaient (`lvl_10`,
	# `lvl_11`, `lvl_12`) et le pentacle qui les clot (`lvl_13`) ; `lvl_07`, deja
	# la, devient le quatrieme demon. L acte est le SEUL NON LINEAIRE du jeu : ses
	# quatre demons s ouvrent d un coup et s affrontent dans l ordre qu on veut.
	#
	# `_acte_5` ouvre l espace divin (`lvl_14`, `lvl_15`, `lvl_16`), qui n avait
	# aucun niveau et dont le fond n avait jamais ete affiche. `lvl_16` est le
	# dernier niveau de la campagne : le finir ouvre le Massacre.
	_acte_4_suite(C, E)
	_acte_5(C, E)


## =====================================================================
## ACTE II — LE GRAND CIMETIERE  (voir docs/histoire.md sections 4 et 9)
##
## Intention commune aux deux niveaux : apres deux niveaux ou la menace etait la
## MASSE (golems, behemoths), l Acte II bascule sur le NOMBRE. C est un contraste
## volontaire : le joueur qui a appris a concentrer ses degats doit desapprendre.
## Les decks suivent — beaucoup de zones, peu de mono-cible.
## =====================================================================
func _acte_2(C: String, E: String) -> void:

	# ---------- lvl_03 : Ossuaire des Marees ----------
	# Les goules comptent les ames pendant que le mage traverse les fosses.
	# Toutes les vagues sont batie sur des monstres qui SE MULTIPLIENT (nuees,
	# gelees, ruches) : le nombre a l ecran grimpe sans que les PV explosent.
	# La courbe reprend au-dessus de la fin du niveau 2 sans jamais doubler.
	var a1 := WaveDef.new()
	a1.id = &"w3_1"
	a1.duration = 26.0
	a1.difficulty = 1.15
	# Premiere lecon de l acte : deux nuees valent 8 corps. On ouvre doucement.
	a1.entries = [
		_entry(E + "rat_swarm.tres", 2, 2.4),
		_entry(E + "gnome.tres", 4, 2.0, 7.0),
		_entry(E + "jelly_mid.tres", 2, 2.2, 15.0),
	]
	_save(a1, "res://resources/waves/w3_1.tres")

	var a2 := WaveDef.new()
	a2.id = &"w3_2"
	a2.duration = 27.0
	a2.difficulty = 1.25
	# La Gelee entiere entre en scene : 36 PV qui deviennent 6 corps si on la tue
	# mal. C est la vague qui apprend a poser une zone AVANT de frapper.
	# Mesure au banc : le niveau 3 ne tuait pas d un coup, il USAIT — 185 a 245 s
	# de partie, PV qui descendent vague apres vague avec une interception pourtant
	# saine (81 a 92 %). Cause : c est le niveau le plus long ET il portait DEUX
	# vagues a 12 rats (w3_2 et w3_4) en plus des gelees qui se scindent. On
	# ramene chacune a 8 rats : la lecon du nombre reste, l usure devient tenable.
	# CHANTIER W2 — deux Slimes moyens en fin de vague : le joueur voit la petite
	# forme bleue AVANT que le Slime enorme du palier n en lache trois d un coup.
	a2.entries = [
		_entry(E + "jelly.tres", 1, 2.5),
		_entry(E + "rat_swarm.tres", 2, 2.0, 6.0),
		_entry(E + "sprite.tres", 4, 1.6, 14.0),
		_entry(E + "slime_mid.tres", 2, 1.6, 20.0),
	]
	_save(a2, "res://resources/waves/w3_2.tres")

	var a3 := WaveDef.new()
	a3.id = &"w3_3"
	a3.duration = 28.0
	a3.difficulty = 1.3
	# Le Pretre goule soigne : tant qu il vit, les degats etales ne servent a rien.
	# Il force a choisir une cible prioritaire au milieu de la foule.
	a3.entries = [
		_entry(E + "ghoul_priest.tres", 2, 3.0),
		_entry(E + "jelly_mid.tres", 3, 2.0, 8.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 16.0),
	]
	_save(a3, "res://resources/waves/w3_3.tres")

	var a4 := WaveDef.new()
	a4.id = &"w3_4_miniboss"
	a4.duration = 32.0
	# Le mini-boss EST le saut : son escorte reste legere, comme au niveau 1.
	a4.difficulty = 1.05
	a4.is_miniboss = true
	# LE PRETRE GOULE, et non le Gardien (mort en `lvl_04`, voir lvl_02).
	# L Ossuaire est plein de morts-vivants : son immunite au poison y rend la
	# Mare de venin inutile, ce qui force a changer de sort au pire moment.
	#
	# CHANTIER W2 — LE SLIME ENORME prend la tete, le Pretre redevient escorte. Un
	# P3 qui soigne ne faisait pas un palier ; un mini-boss qui se brise en trois
	# Slimes moyens, dans le niveau des monstres qui se multiplient, en fait un. Le
	# Pretre y gagne son role : il SOIGNE le slime, donc le tuer d abord est la
	# decision que la vague demande. Une Sauterelle de moins pour garder le poids.
	a4.entries = [
		_entry(E + "slime_huge.tres", 1, 1.0),
		_entry(E + "ghoul_priest.tres", 1, 1.0, 4.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 8.0),
		_entry(E + "hopper.tres", 2, 1.8, 18.0),
	]
	_save(a4, "res://resources/waves/w3_4_miniboss.tres")

	var a5 := WaveDef.new()
	a5.id = &"w3_5"
	a5.duration = 30.0
	a5.difficulty = 1.35
	# La Ruche explose en 4 lutins : un seul monstre en vaut cinq. C est la vague
	# ou la Spirale de sel du deck paie enfin son temps d incantation.
	# Le Gardien d ossements : voir la note sur l Ecumeur (w2_5) — un mini-boss
	# absent des vagues ecrites n existe pas pour le mode infini.
	a5.entries = [
		_entry(E + "hive.tres", 2, 3.0),
		_entry(E + "bonewarden.tres", 1, 1.0, 22.0),
		_entry(E + "jelly.tres", 1, 2.0, 10.0),
		_entry(E + "wisp.tres", 3, 1.8, 18.0),
	]
	_save(a5, "res://resources/waves/w3_5.tres")

	var a6 := WaveDef.new()
	a6.id = &"w3_6_boss"
	a6.duration = 42.0
	# Difficulte basse sur la vague de boss : le boss apporte deja ses PV bruts,
	# le multiplier reviendrait a empiler deux sauts dans la meme vague.
	a6.difficulty = 1.1
	a6.is_boss = true
	# LE RELIQUAIRE (chantier I), et non plus le Behemoth. Le Behemoth tenait la
	# place sans rien demander de neuf : c est un TANK, donc "plus de PV", et il
	# descend DEJA comme monstre ordinaire dans lvl_04 et lvl_07 — le joueur ne
	# voyait pas la difference entre le boss et l escorte.
	#
	# Le Reliquaire change la MONNAIE : ses six sceaux avalent les six premiers
	# coups, quelle que soit leur puissance. Dans un ossuaire ou tout le reste se
	# nettoie a la petite carte rapide (les nuees, les Pretres), il est le SEUL
	# adversaire du niveau contre lequel ce reflexe est le pire choix possible —
	# c est exactement le contraste qu on veut dans une vague de boss.
	#
	# L escorte est maintenue : elle est le piege. Le joueur tente de nettoyer les
	# Pretres avec ses petites cartes pendant que les sceaux tiennent, et il doit
	# decider laquelle des deux menaces il paie d abord.
	a6.entries = [
		_entry(E + "bone_reliquary.tres", 1, 1.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 8.0),
		_entry(E + "rat_swarm.tres", 3, 2.0, 20.0),
	]
	_save(a6, "res://resources/waves/w3_6_boss.tres")

	var lvl3 := LevelDef.new()
	lvl3.id = &"lvl_03"
	lvl3.display_name = "Ossuaire des Marees"
	lvl3.terrain = "sand"
	# CHANTIER N2 — LES SCENES REVIENNENT, et ce sont enfin les bonnes.
	#
	# Le chantier N avait retire `lvl_03_intro` / `lvl_03_outro` de ce niveau
	# parce qu elles racontaient l ACTE 1 : le maire y parlait du dirigeable
	# devant un ossuaire de l acte 2. Elles sont parties chez `lvl_08` /
	# `lvl_09`, qui sont bien la route et le dirigeable, et ce niveau est reste
	# MUET — jouable, mais muet au milieu d une campagne qui raconte.
	#
	# Les scenes reecrites sous les memes identifiants portent maintenant le
	# texte de docs/histoire.md section 4 : le cimetiere de bordure, ses tombes
	# numerotees et ses registres qui comptent des quantites et non des noms.
	# Voir `tools/make_story.gd`, `_acte2()`.
	lvl3.intro_story = &"lvl_03_intro"
	lvl3.outro_story = &"lvl_03_outro"
	lvl3.backdrop = "act2_graveyard"
	lvl3.waves = [a1, a2, a3, a4, a5, a6]
	lvl3.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "hopper.tres"), load(E + "imp_archer.tres"),
		load(E + "jelly.tres"), load(E + "ghoul_priest.tres"), load(E + "hive.tres"),
		load(E + "shade.tres"), load(E + "slime_mid.tres"), load(E + "slime_huge.tres"),
	]
	# DECK ANTI-NOMBRE. Le contenu du niveau est fait de monstres qui se divisent et
	# qui pullulent : le mono-cible y est un piege (tuer une Gelee au Trait, c est
	# creer deux Gelees). D ou des cartes de zone et la Spirale de sel, la carte
	# d histoire de l Ossuaire, qui rassemble avant la frappe.
	#
	# PEU DE FEU, ET C EST MESURE. lvl_03 gagnait 29 fois sur 30 : CINQ des dix
	# monstres du niveau craignent le feu (Nuee x1.30, Feu follet x1.35, Gelee,
	# Gnome et Pretre x1.15) et un TIERS du deck etait du feu. Le joueur ne pouvait
	# pas se tromper d element. La Resonance (arcane) frappe d AUTRES monstres :
	# l Ombre resiste au feu mais craint l arcane, l Archer aussi.
	# Le Semis de fletrissure entre ICI parce que l Ossuaire envoie des nuees
	# DISPERSEES : l arbre les rassemble a son pied et son poison les use. Les
	# goules y sont immunisees au venin : la carte vaut plus au niveau suivant.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Spirale de sel et Semis. Sortent les Braises, le Trait, la
	# Lumiere purifiante et le Mur : le feu tombe a deux Boules, et la Pluie de
	# givre et la Fleche prennent le fond du deck.
	lvl3.exploration_deck = _deck([
		[C + "common/frost_rain.tres", 4],
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/salt_spiral.tres", 1],
		[C + "epic/resonance.tres", 1],
		[C + "epic/blight_sapling.tres", 1],
	])
	_poser_progression(lvl3)
	lvl3.next_levels = [&"lvl_04"]
	lvl3.act = 2
	lvl3.subtitle = "Une administration, pas un cimetiere"
	lvl3.intro_text = "Ici les morts sont tries, comptes, reaffectes. Les Pretres \
goules tiennent les registres et leur ile se vide : les ames partent ailleurs. Ils \
n ont pas efface ton royaume par haine. Ils l ont fait pour le STOCK."
	lvl3.outro_text = "Une Gelee prisonniere d un cercle de sel t a regarde la \
liberer, puis t a montre comment un corps se separe et se rassemble. Les registres, \
eux, sont clairs : l extinction humaine devait alimenter une Grande Invocation."
	_save(lvl3, "res://resources/levels/lvl_03.tres")

	# ---------- lvl_04 : Le Grand Appel ----------
	# Le rituel a lieu et IL REUSSIT. Le joueur ne l empeche pas — c est le
	# rebondissement. Traduction mecanique : la vague 5 change brutalement de
	# nature (les demons franchissent la porte) au milieu du niveau, pas a la fin.
	var b1 := WaveDef.new()
	b1.id = &"w4_1"
	b1.duration = 26.0
	b1.difficulty = 1.2
	# Mesure au banc : cette vague D OUVERTURE etait la plus dense de toute la
	# campagne. Une nuee compte pour 4 corps, donc `rat_swarm, 2` faisait 8 rats,
	# et chaque gelee moyenne se scinde en 2 : 19 corps la ou le niveau 3 en
	# ouvrait 16 et le niveau 6 seulement 8. Le taux d interception tombait a
	# 40 % et le joueur mourait AVANT la fin de la premiere vague.
	# Une seule nuee et deux gelees : 13 corps, juste au-dessus du niveau 3.
	b1.entries = [
		_entry(E + "jelly_mid.tres", 2, 2.2),
		_entry(E + "rat_swarm.tres", 1, 2.2, 8.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 16.0),
	]
	_save(b1, "res://resources/waves/w4_1.tres")

	var b2 := WaveDef.new()
	b2.id = &"w4_2"
	b2.duration = 28.0
	b2.difficulty = 1.3
	# Deux Pretres qui se soignent l un l autre : le premier vrai probleme
	# d ordre de cibles du jeu.
	b2.entries = [
		_entry(E + "ghoul_priest.tres", 2, 2.5),
		_entry(E + "hive.tres", 1, 2.0, 9.0),
		_entry(E + "shade.tres", 3, 2.0, 17.0),
	]
	_save(b2, "res://resources/waves/w4_2.tres")

	var b3 := WaveDef.new()
	b3.id = &"w4_3_miniboss"
	b3.duration = 34.0
	b3.difficulty = 1.1
	b3.is_miniboss = true
	# LE GARDIEN D OSSEMENTS, et non le Pretre goule (qui mene deja le mini-boss
	# de `lvl_03`) ni le Gardien de la foret : docs/histoire.md le fait mourir a
	# la fin de CE niveau, "il s effondre en un tas de bois mort", et la plaque
	# de metal dans sa poitrine lance toute l intrigue. Le montrer en mini-boss
	# avant de le tuer en boss affaiblirait la scene.
	#
	# Premier essai : l Ombre. Mesure au banc, le niveau est tombe a 57-63 % de
	# victoires, sous la cible. Cause : 16 PV la ou le Gardien en pesait 140,
	# donc la vague 3 devenait plus LEGERE que la vague 2 et la vague 4 remontait
	# d un coup. Une Ombre qui disparait la moitie du temps allonge en plus la
	# vague sans rien apprendre.
	#
	# Le Gardien d ossements pese 165 PV, immunise au poison comme tout
	# mort-vivant : dans un niveau plein de goules, il ferme la porte a la Mare
	# de venin au pire moment. Il rattache aussi le monde 2 du mode infini.
	#
	# CHANTIER W3 — LE BRISEUR DE TERTRES prend la tete (voir `_enemies_v3`) : le
	# deck de ce niveau est le premier a porter un arbre qu on a interet a garder,
	# et un Briseur ailleurs n aurait rien a briser. Le Gardien d ossements garde sa
	# place en `w3_5`, qui suffit a le rattacher au monde 2. Poids voisin : 150 PV
	# contre 165. Les notes ci-dessus datent de son choix.
	b3.entries = [
		_entry(E + "terrain_breaker.tres", 1, 1.0),
		_entry(E + "ghoul_priest.tres", 2, 2.0, 9.0),
		_entry(E + "sprite.tres", 4, 1.6, 22.0),
	]
	_save(b3, "res://resources/waves/w4_3_miniboss.tres")

	var b4 := WaveDef.new()
	b4.id = &"w4_4"
	b4.duration = 30.0
	b4.difficulty = 1.35
	# 15 corps : le PIC du niveau tombait ici et non sur le boss. La nuee arrivait
	# a 24 s, par-dessus des monstres deja en place. On la ramene a 4 rats.
	b4.entries = [
		_entry(E + "jelly.tres", 2, 2.5),
		_entry(E + "berserker.tres", 2, 2.5, 10.0),
		_entry(E + "wisp.tres", 3, 1.8, 19.0),
		_entry(E + "rat_swarm.tres", 1, 2.2, 24.0),
	]
	_save(b4, "res://resources/waves/w4_4.tres")

	var b5 := WaveDef.new()
	b5.id = &"w4_5"
	b5.duration = 32.0
	b5.difficulty = 1.35
	# LA PORTE S OUVRE. Behemoth et Gardien-totem franchissent le seuil : ce ne
	# sont plus des goules. Le changement doit se VOIR — deux P4 d un coup, mais
	# sans escorte lourde pour que le saut de PV reste sous le double.
	b5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "behemoth.tres", 1, 1.0, 10.0),
		_entry(E + "gnome.tres", 4, 2.0, 18.0),
		_entry(E + "sprite.tres", 4, 1.5, 24.0),
	]
	_save(b5, "res://resources/waves/w4_5.tres")

	var b6 := WaveDef.new()
	b6.id = &"w4_6_boss"
	b6.duration = 45.0
	b6.difficulty = 1.05
	b6.is_boss = true
	# L ENSEVELISSEUR. Le Pretre qui mene la Grande Invocation : il ne vient pas
	# se battre, il vient FINIR SON RITUEL. Il leve deux goules toutes les 5 s
	# tant qu il vit, ce qui rend la vague ingagnable en nettoyant les sbires.
	# La seule reponse est de percer jusqu a lui — c est la lecon du niveau.
	# L escorte est volontairement LEGERE : le flux d invocation fournit deja
	# tous les corps, en ajouter transformerait la pression en noyade.
	b6.entries = [
		_entry(E + "gravecaller.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 1, 2.5, 12.0),
	]
	_save(b6, "res://resources/waves/w4_6_boss.tres")

	var lvl4 := LevelDef.new()
	lvl4.id = &"lvl_04"
	lvl4.display_name = "Le Grand Appel"
	lvl4.terrain = "sand"
	# CHANTIER N2 — memes scenes rendues, meme raison (voir `lvl_03`). Celles-ci
	# portent LA FIN DE L ACTE 2 : les morts du cimetiere de bordure s arretent
	# tous en meme temps et lachent le nom de Tombol. C est le dialogue le plus
	# important de l acte et il n etait joue nulle part.
	lvl4.intro_story = &"lvl_04_intro"
	lvl4.outro_story = &"lvl_04_outro"
	lvl4.backdrop = "act2_graveyard"
	lvl4.waves = [b1, b2, b3, b4, b5, b6]
	lvl4.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "rat_swarm.tres"),
		load(E + "wisp.tres"), load(E + "shade.tres"), load(E + "imp_archer.tres"),
		load(E + "jelly.tres"), load(E + "ghoul_priest.tres"), load(E + "hive.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "totem_guardian.tres"), load(E + "behemoth.tres"),
		load(E + "risen_ghoul.tres"), load(E + "terrain_breaker.tres"),
	]
	# DECK CHARNIERE. Le niveau commence en registre "nombre" et finit en registre
	# "masse" : le deck doit tenir les deux moities. Braises pour les goules,
	# Meteore et Marque de faiblesse pour les deux P4 de la vague 5. Le Rappel
	# d ossements, carte d histoire du niveau, repond au vrai probleme : c est le
	# plus long de la campagne, on y manque de cartes avant d y manquer de PV.
	# Le Totem de coeur-de-bois entre ICI, au niveau du GRAND APPEL : son boss
	# INVOQUE sans arret, et contre un flux on gagne en donnant au flux autre chose
	# a faire. L arbre est la seule carte du jeu qui le permette.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Totem et Rappel. Sortent la Boule de feu, la Fleche, la Spirale
	# et le Mur ; le Trait monte a 4 pour achever ce que les zones entament.
	lvl4.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/ember_pool.tres", 2],
		[C + "rare/meteor.tres", 2],
		[C + "rare/heartwood_totem.tres", 1],
		[C + "epic/weakness_mark.tres", 2],
		[C + "rare/bone_recall.tres", 1],
	])
	_poser_progression(lvl4)
	# PREMIERE FOURCHE de la campagne : la porte s ouvre sur deux entrees du monde
	# demoniaque, equivalentes en difficulte mais opposees en nature.
	# CHANTIER N2 — l acte 2 rend la main a `lvl_19`, LES FOSSES BASSES : le
	# document (section 5) commence Tombol par le bas. La fourche `lvl_05` /
	# `lvl_06` existe toujours, elle est seulement DEPLACEE au milieu de
	# l acte 3, derriere la cour des rois morts.
	lvl4.next_levels = [&"lvl_19"]
	lvl4.act = 2
	lvl4.subtitle = "Le rituel reussit"
	lvl4.intro_text = "Tu arrives trop tard : le cercle est deja trace et les \
Pretres chantent. Tu ne peux plus empecher la Grande Invocation. Tu peux seulement \
etre la quand la porte s ouvrira, pour voir ce qui en sortira."
	lvl4.outro_text = "Les goules croyaient invoquer un allie. Elles ont invoque un \
PROPRIETAIRE. Le Grand Cimetiere a ete annexe en une nuit. Le Pretre qui dirigeait le \
rituel, ecrase par ce qu il a fait venir, t a appris a rappeler ce qui est deja parti \
— puis t a montre la porte, encore ouverte."
	_save(lvl4, "res://resources/levels/lvl_04.tres")


## =====================================================================
## ACTE III — LE MONDE DEMONIAQUE  (docs/histoire.md sections 5 et 8)
##
## Les deux niveaux sont une FOURCHE : meme place dans la courbe, exigences
## opposees. lvl_05 = peu de monstres tres blindes (mono-cible lourd).
## lvl_06 = beaucoup de monstres varies a effets (zones + dissipation).
## Le joueur choisit son epreuve ; les deux menent au final.
## =====================================================================
func _acte_3(C: String, E: String) -> void:

	# ---------- lvl_05 : Forges du Mauvais Temps ----------
	# Peu de corps, enormement de PV. Les vagues sont COURTES en nombre : c est ce
	# qui permet de monter les PV sans que l ecran devienne illisible, et ce qui
	# rend le mono-cible lourd (Meteore, Focalisation) enfin superieur aux zones.
	var c1 := WaveDef.new()
	c1.id = &"w5_1"
	c1.duration = 28.0
	c1.difficulty = 1.2
	c1.entries = [
		_entry(E + "golem.tres", 2, 3.0),
		_entry(E + "gnome.tres", 4, 2.0, 10.0),
		_entry(E + "hopper.tres", 3, 1.8, 16.0),
	]
	_save(c1, "res://resources/waves/w5_1.tres")

	var c2 := WaveDef.new()
	c2.id = &"w5_2"
	c2.duration = 28.0
	c2.difficulty = 1.25
	# Le Berserker accelere a chaque coup recu : l arroser de petits degats le rend
	# plus dangereux. Premiere vague qui punit le reflexe acquis a l Acte II.
	c2.entries = [
		_entry(E + "berserker.tres", 3, 2.5),
		_entry(E + "void_knight.tres", 1, 2.0, 12.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 18.0),
	]
	_save(c2, "res://resources/waves/w5_2.tres")

	var c3 := WaveDef.new()
	c3.id = &"w5_3_miniboss"
	c3.duration = 34.0
	c3.difficulty = 1.1
	c3.is_miniboss = true
	# LE MIROIR DE FORGE (chantier I), et non plus le Gardien-totem. Le
	# Gardien-totem menait ce palier sans rien demander de neuf (il resistait au
	# physique, comme la moitie du bestiaire) et il descend DEJA comme monstre
	# ordinaire dans les vagues 4 et 5 du meme niveau : le mini-boss ressemblait a
	# son escorte.
	#
	# Le Miroir change le MOMENT du lancement : toutes les 7 s il leve sa face
	# polie pendant 2,5 s, et 45 % de ce qu on lui envoie repart sur le mage.
	#
	# POURQUOI EN MINI-BOSS ET POURQUOI ICI. La mecanique punit le joueur qui
	# lance ; elle doit donc etre ENSEIGNEE dans un moment ou une erreur ne coute
	# pas le niveau. Un mini-boss arrive au tiers de la vague, avec une escorte
	# legere, et laisse voir la garde se lever deux ou trois fois avant de la
	# payer. Aux Forges elle est de plus a sa place : lvl_05 est le niveau du deck
	# MONO-CIBLE lourd (Meteore, Trait), donc celui ou lancer un gros sort au
	# mauvais moment coute le plus cher — la lecon mord immediatement.
	#
	# L escorte est ALLEGEE (deux golems, plus de nuee de lutins) : apprendre a
	# regarder le boss demande de pouvoir le regarder.
	c3.entries = [
		_entry(E + "glass_mirror.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 3.0, 10.0),
		_entry(E + "sprite.tres", 3, 1.8, 22.0),
	]
	_save(c3, "res://resources/waves/w5_3_miniboss.tres")

	var c4 := WaveDef.new()
	c4.id = &"w5_4"
	c4.duration = 30.0
	c4.difficulty = 1.3
	# Premier Behemoth seul : 130 PV qui avancent a 26 px/s et frappent pour 2.
	# Lent, donc traitable ; mais il faut y consacrer plusieurs sorts d affilee.
	# Meme cause : 6 corps, tous mono-cible. Une nuee oblige a sortir une zone au
	# milieu du duel contre le behemoth.
	# CHANTIER I2 — LE SLIME DEMONIAQUE entre ici, dans le monde demoniaque comme
	# le testeur l a demande. Place juste apres le Behemoth, et c est le point :
	# les Forges sont LE niveau du deck mono-cible lourd, et le joueur y a appris
	# a bruler ce qui est mou. Le slime a la silhouette d une gelee, la division
	# d une gelee — et il est IMMUNISE au feu. Son reflexe ne fait rien, et ses
	# enfants, eux, brulent : la lecon a une sortie dans le meme combat.
	#
	# Un seul exemplaire : il pese 78 PV plus deux Gelees moyennes a la mort
	# (28 PV), soit 106 PV a traiter avec le mauvais element. En mettre deux
	# aurait fait sauter le garde-fou d equilibrage sur une vague deja lourde.
	c4.entries = [
		_entry(E + "behemoth.tres", 1, 1.0),
		_entry(E + "demon_slime.tres", 1, 1.0, 6.0),
		_entry(E + "void_knight.tres", 2, 2.5, 12.0),
		_entry(E + "berserker.tres", 1, 2.5, 19.0),
		_entry(E + "rat_swarm.tres", 1, 2.4, 22.0),
		_entry(E + "hornblower.tres", 1, 1.0, 26.0),
	]
	_save(c4, "res://resources/waves/w5_4.tres")

	var c5 := WaveDef.new()
	c5.id = &"w5_5"
	c5.duration = 32.0
	c5.difficulty = 1.3
	# Le Gardien-totem rend les autres invulnerables dans 240 px : avec deux
	# Behemoths sous son aura, il DOIT tomber en premier. La vague enseigne la
	# priorite de cible que le boss exigera.
	# Mesure au banc : le niveau 5 etait a 100 % de victoires alors que le niveau 4
	# qui le PRECEDE etait a 63 %. Cause : c est le seul niveau sans aucune nuee ni
	# aucun scindeur — que de grosses cibles uniques, exactement ce que le joueur
	# (et l IA du banc) traite le mieux avec un deck mono-cible. Il n y avait pas
	# trop peu de PV, il y avait trop peu de CIBLES SIMULTANEES.
	# La gelee force a gerer deux fronts pendant que le behemoth avance.
	# Le Seigneur de braise : voir la note sur l Ecumeur (w2_5).
	c5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "emberlord.tres", 1, 1.0, 24.0),
		_entry(E + "behemoth.tres", 1, 1.0, 9.0),
		_entry(E + "golem.tres", 2, 2.5, 18.0),
		_entry(E + "jelly.tres", 1, 2.0, 22.0),
		_entry(E + "sprite.tres", 4, 1.5, 25.0),
	]
	_save(c5, "res://resources/waves/w5_5.tres")

	var c6 := WaveDef.new()
	c6.id = &"w5_6_boss"
	c6.duration = 48.0
	c6.difficulty = 1.05
	c6.is_boss = true
	# LE COLOSSE DES FORGES. Quatre plaques de 50 PV devant un coeur de 150 : le
	# joueur ne peut pas l user, il doit le DEMONTER, et le surplus d un coup ne
	# passe pas d une plaque a l autre. Le deck mono-cible du niveau (Meteore,
	# Trait) est exactement l outil qu il faut — c est le paiement du niveau.
	# Escorte reduite : demonter demande de rester concentre sur une cible, une
	# foule autour annulerait toute la mecanique.
	c6.entries = [
		_entry(E + "forge_colossus.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 3.0, 14.0),
		_entry(E + "hopper.tres", 3, 1.8, 34.0),
	]
	_save(c6, "res://resources/waves/w5_6_boss.tres")

	var lvl5 := LevelDef.new()
	lvl5.id = &"lvl_05"
	lvl5.display_name = "Forges du Mauvais Temps"
	lvl5.terrain = "sand"
	lvl5.backdrop = "act3_demon"
	lvl5.waves = [c1, c2, c3, c4, c5, c6]
	lvl5.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "golem.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "behemoth.tres"), load(E + "totem_guardian.tres"),
		load(E + "hornblower.tres"), load(E + "imp_archer.tres"),
		# CHANTIER I2 — le slime demoniaque, la gelee du monde demon.
		load(E + "demon_slime.tres"),
	]
	# DECK ANTI-BLINDAGE. Contre 55 a 130 PV par corps, une zone a 8 degats/s est
	# du gaspillage : il faut des paquets de degats. Meteore (60 d un coup),
	# Focalisation (x2 sur le sort suivant) et Marque de faiblesse (x2 en zone) se
	# combinent : c est la combo que le niveau veut enseigner. La Rupture de chaine,
	# carte d histoire du niveau, est la reponse d urgence : elle repousse ce qu on
	# n a pas fini.
	# Aux Forges, Golem, Colosse et Behemoth sont IMMUNISES au ralentissement : le
	# controle n y sert a rien. La Pluie de givre reste pour ses DEGATS de givre,
	# que le Colosse craint. Mesure : a une Focalisation et un Meteore de moins, le
	# niveau tombait a 53-63 %. On garde donc leurs exemplaires entiers.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Rupture de chaine. Sortent la Lumiere, la Fleche et le Mur (un
	# exemplaire chacun) : le Trait monte a 4, l arcane etant ce que les Forges
	# craignent le plus (x1.11 en moyenne ponderee par les PV).
	#
	# DISSIPATION (chantier W9) : un Gardien-totem descend dans w5_5 et son aura
	# rend la vague intouchable ; le deck n avait plus de reponse depuis que la
	# Lumiere purifiante en etait sortie (regle des 6). La Lumiere et le Vide
	# d emprise sont deja au livre a ce stade (decks de lvl_19, lvl_06, lvl_20) :
	# seul le deck les met dans le pool de montee d un niveau de campagne. La
	# Rupture de chaine reste : c est la carte que ce niveau fait decouvrir. Il
	# fallait donc sortir un autre id (regle des 6). Banc, 60 parties : deck
	# d avant 44 victoires ; Lumiere a la place du Meteore 39 ; Lumiere a la
	# place des deux Pluies de givre, Meteore monte a 2 : 52. La Pluie sort :
	# hors le Colosse, tout ici resiste au givre ou l ignore (lenteur nulle), et
	# le Meteore est le paquet de degats que la combo du niveau veut.
	# Paragraphe ci-dessus : « la Pluie reste pour ses degats » ne vaut plus.
	lvl5.exploration_deck = _deck([
		[C + "rare/purifying_light.tres", 1],
		[C + "common/arcane_bolt.tres", 4],
		[C + "rare/focus.tres", 2],
		[C + "epic/weakness_mark.tres", 2],
		[C + "rare/chain_break.tres", 1],
		[C + "rare/meteor.tres", 2],
	])
	_poser_progression(lvl5)
	# CHANTIER N2 — la fourche retombe dans `lvl_21`, LE PENTACLE, qui ferme
	# l acte 3 et ouvre seul les quatre grands demons de l acte 4. Elle sautait
	# auparavant directement a `lvl_07`, ce qui donnait DEUX entrees dans
	# l acte suivant la ou le document n en veut qu une.
	lvl5.next_levels = [&"lvl_21"]
	lvl5.act = 3
	lvl5.subtitle = "Ils ne conquierent pas, ils fabriquent"
	lvl5.intro_text = "De l autre cote de la porte : pas de chateau, pas de trone. \
Des ateliers. Les demons fabriquent du temps, et ces creatures blindees ne sont pas \
nees — elles ont ete coulees."
	lvl5.outro_text = "Un Berserker a brise sa chaine devant toi au lieu de charger. \
Les demons ne choisissent rien : une horloge bat au centre de leur monde et les \
reveille. Elle n est pas a eux. Chaque extinction est une COMMANDE qui arrive par le \
cadran, et ils ignorent qui la passe."
	_save(lvl5, "res://resources/levels/lvl_05.tres")

	# ---------- lvl_06 : La Cour brisee ----------
	# Meme niveau de difficulte que lvl_05, nature inverse : beaucoup de corps,
	# toutes les familles melangees, et surtout des monstres A EFFETS qui se
	# protegent mutuellement (rage, bouclier de premier coup, aura d invulnerabilite).
	# C est une guerre civile ou le mage n est qu un passant.
	var d1 := WaveDef.new()
	d1.id = &"w6_1"
	d1.duration = 27.0
	d1.difficulty = 1.2
	# Mesure au banc : a 2 chevaliers du vide des la premiere vague, le niveau
	# tombait a 37 % de victoires. Le chevalier annule le premier coup recu : en
	# ouvrir la porte a deux exemplaires coutait quatre sorts avant le moindre degat.
	d1.entries = [
		_entry(E + "void_knight.tres", 1, 2.5),
		_entry(E + "sprite.tres", 4, 1.8, 8.0),
		_entry(E + "wisp.tres", 3, 2.0, 16.0),
	]
	_save(d1, "res://resources/waves/w6_1.tres")

	var d2 := WaveDef.new()
	d2.id = &"w6_2"
	d2.duration = 28.0
	d2.difficulty = 1.25
	# Le Corniste accelere tout le monde de 20 % : il transforme une vague lisible
	# en debordement. Il entre par le cote, donc il faut le chercher.
	d2.entries = [
		_entry(E + "hornblower.tres", 1, 2.5),
		_entry(E + "shade.tres", 3, 2.0, 7.0),
		_entry(E + "hopper.tres", 4, 1.8, 15.0),
	]
	_save(d2, "res://resources/waves/w6_2.tres")

	var d3 := WaveDef.new()
	d3.id = &"w6_3_miniboss"
	d3.duration = 34.0
	d3.difficulty = 1.1
	d3.is_miniboss = true
	# Mesure au banc : les nuees de rats causaient la moitie des coups recus. Une
	# nuee compte pour PLUSIEURS corps (swarm_count) et arrivait pendant que le
	# mini-boss monopolisait l attention. Deux entrees, plus espacees.
	# CHANTIER I2 — LE BOURREAU prend la tete, le Chevalier du vide redevient son
	# escorte. Meme raison que pour la Matrone en `lvl_02` : le Chevalier est un
	# monstre ORDINAIRE de puissance 3 et il menait ce palier faute de mini-boss
	# disponible. Son armure qui avale la magie est une bonne QUESTION D ELEMENT,
	# mais elle ne change pas la facon de se placer, et c est ce qu un palier doit
	# faire.
	#
	# Le Bourreau, lui, N AVANCE PAS et frappe le sol : la premiere zone interdite
	# FIXE du jeu. La Cour brisee est le bon endroit — c est deja le niveau ou le
	# Seigneur Spectre campe a 430 px, donc celui ou le joueur apprend que tout ne
	# vient pas a lui. Le mini-boss lui enseigne le cercle, le boss la distance :
	# deux facons de refuser le contact, dans l ordre.
	#
	# Il invoque une Goule levee toutes les 6 s (plafond 3) : un boss immobile ne
	# peut pas menacer le mage seul, et sans ce flux le joueur pourrait simplement
	# l ignorer jusqu a la fin de la vague. C est ce qui l oblige a entrer dans le
	# cercle.
	#
	# Escorte allegee : le Bourreau pese 145 PV la ou le Chevalier en pesait 34,
	# plus ses goules. Le garde-fou d equilibrage refuse le doublement.
	d3.entries = [
		_entry(E + "executioner.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 1, 1.0, 7.0),
		_entry(E + "berserker.tres", 1, 2.5, 14.0),
		_entry(E + "rat_swarm.tres", 1, 3.0, 24.0),
	]
	_save(d3, "res://resources/waves/w6_3_miniboss.tres")

	var d4 := WaveDef.new()
	d4.id = &"w6_4"
	d4.duration = 30.0
	d4.difficulty = 1.3
	# Le Glouton gobe les faibles et grossit : le laisser vivre au milieu d une
	# nuee, c est fabriquer soi-meme le monstre qui tuera le mage.
	d4.entries = [
		_entry(E + "glutton.tres", 1, 1.0),
		_entry(E + "hive.tres", 1, 2.0, 8.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 16.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 24.0),
	]
	_save(d4, "res://resources/waves/w6_4.tres")

	var d5 := WaveDef.new()
	d5.id = &"w6_5"
	d5.duration = 32.0
	d5.difficulty = 1.3
	# Le trio qui justifie le Vide d emprise : totem (aura), berserkers (rage),
	# chevaliers (bouclier). Sans dissipation, chacun couvre les deux autres.
	d5.entries = [
		# Mesure au banc : cumuler le Gardien-totem (aura d invulnerabilite), deux
		# Berserkers (rage) et un Chevalier du vide (annule le premier coup) rendait
		# la vague infranchissable — quatre monstres dont aucun ne meurt au premier
		# sort, pendant que la Ruche libere ses lutins.
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "berserker.tres", 1, 2.5, 10.0),
		_entry(E + "sprite.tres", 3, 1.8, 22.0),
	]
	_save(d5, "res://resources/waves/w6_5.tres")

	var d6 := WaveDef.new()
	d6.id = &"w6_6_boss"
	d6.duration = 48.0
	d6.difficulty = 1.05
	d6.is_boss = true
	# LE SEIGNEUR SPECTRE. Il s arrete a 620 px du mage et harcele de loin : il
	# n arrivera jamais au contact, donc la ligne de defense ne sert a rien
	# contre lui. Le joueur doit le viser DERRIERE son escorte pendant que
	# celle-ci descend — c est la seule vague du jeu ou l ordre naturel des
	# cibles (le plus proche d abord) est le mauvais choix.
	d6.entries = [
		_entry(E + "wraith_lord.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 12.0),
		_entry(E + "shade.tres", 3, 2.0, 26.0),
	]
	_save(d6, "res://resources/waves/w6_6_boss.tres")

	var lvl6 := LevelDef.new()
	lvl6.id = &"lvl_06"
	lvl6.display_name = "La Cour brisee"
	lvl6.terrain = "sand"
	lvl6.backdrop = "act3_demon"
	lvl6.waves = [d1, d2, d3, d4, d5, d6]
	lvl6.enemy_pool = [
		load(E + "sprite.tres"), load(E + "wisp.tres"), load(E + "shade.tres"),
		load(E + "hopper.tres"), load(E + "rat_swarm.tres"),
		load(E + "imp_archer.tres"), load(E + "hornblower.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "hive.tres"), load(E + "glutton.tres"),
		load(E + "totem_guardian.tres"),
		# CHANTIER I2 — le Bourreau, mini-boss de la Cour brisee.
		load(E + "executioner.tres"),
	]
	# DECK DE DEGATS + DISSIPATION. Deux hypotheses testees au banc et rejetees :
	#  - "il faut du cast court" (Etincelle + Givre) -> 13 % de victoires. Une
	#    Etincelle ne tue aucun corps de la Cour (30 a 60 PV).
	#  - "il faut moins de monstres" -> sans effet.
	# Ce qui marche : de la densite de degats par sort. La Boule de feu frappe un
	# groupe, le Brasier tient un couloir, et le Vide d emprise, carte d histoire
	# du niveau, reste la seule reponse au trio totem/berserker/chevalier qui se
	# protege mutuellement.
	# La Racine de tonnerre entre ICI et pas aux Forges : les Forges alignent des
	# monstres IMMUNISES au ralentissement, donc a l etourdissement, et la carte y
	# aurait menti au joueur. La Cour, elle, empile des monstres a effets qui
	# craignent tous d etre arretes une seconde.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Racine de tonnerre et Brasier. Sortent la Resonance, la Nappe,
	# le Totem, la Rupture et le Mur ; la Fleche monte a 4 parce que le Chevalier
	# du vide AVALE l arcane (0,65) et que le physique le traverse.
	lvl6.exploration_deck = _deck([
		[C + "common/fireball.tres", 3],
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/arcane_bolt.tres", 4],
		[C + "rare/brazier.tres", 1],
		[C + "epic/void_grip.tres", 1],
		[C + "epic/thunder_root.tres", 1],
	])
	_poser_progression(lvl6)
	# Meme raison que pour `lvl_05` : les deux branches de la fourche se
	# rejoignent devant le pentacle.
	lvl6.next_levels = [&"lvl_21"]
	lvl6.act = 3
	lvl6.subtitle = "Une guerre civile ou tu n es qu un passant"
	lvl6.intro_text = "Les seigneurs demoniaques s entretuent pour savoir qui \
portera la faute du Grand Appel rate. Personne ne t attend. Tout le monde te tuera \
quand meme, en passant."
	lvl6.outro_text = "Le Chevalier du vide qui gardait le cadran s est rendu. Il t a \
enseigne le geste des gardiens : effacer ce qui a ete inscrit sur une creature. Sur \
le cadran, tu as lu une adresse."
	_save(lvl6, "res://resources/levels/lvl_06.tres")


## =====================================================================
## ACTE FINAL — LE MONDE D ORIGINE  (docs/histoire.md section 6)
##
## Terrain `grass` a dessein : le joueur reconnait le decor du niveau 1, en faux.
## L histoire est circulaire, donc le premier ennemi est aussi le dernier.
## =====================================================================
func _acte_final(C: String, E: String) -> void:

	var f1 := WaveDef.new()
	# DERNIER NIVEAU DE LA CAMPAGNE, et il se gagnait 93 fois sur 100 — le plus
	# facile des sept. Mesure du poids brut : la courbe n est pas monotone, elle
	# recule de 33 % au niveau 3 et de 43 % au niveau 6, et le multiplicateur de
	# difficulte etait quasi plat partout (1,20 a 1,29), donc il ne compensait
	# rien. Un dernier niveau qui se donne ne cloture pas une campagne.
	#
	# On monte la PRESSION des vagues normales (1,25-1,30 -> 1,40-1,45) plutot
	# que d ajouter des corps : la composition du niveau est deja celle qu on
	# veut, c est son exigence qui manquait. Les vagues de mini-boss et de boss
	# gardent leur reglage bas, leur tete apportant deja le saut.
	f1.id = &"w7_1"
	f1.duration = 28.0
	f1.difficulty = 1.40
	# Ouverture en citation du niveau 1 : gnomes et lutins, le motif que la
	# machine repete. Sauf qu ils arrivent deux fois plus vite et accompagnes.
	# CHANTIER I2 — LE CHAMPIGNON ET LA PLANTE, la biomasse du monde d origine.
	# Deux silhouettes que le testeur avait telechargees expres.
	#
	# Elles entrent au PREMIER contact de l acte final, et ce n est pas un hasard :
	# le niveau 7 rejoue le decor du niveau 1 en teinte fausse, et le joueur doit
	# sentir que quelque chose cloche. De la vegetation qui marche dans l herbe du
	# premier matin dit cela mieux qu un dialogue.
	#
	# La paire se lit en opposition, ce qui est toute leur utilite en vague : le
	# champignon encaisse et n avance pas vite (34 PV, 34 px/s), la plante ne tient
	# rien et fonce (12 PV, 88 px/s). Le joueur doit arbitrer dans la meme vague
	# entre une cible qui demande du temps et une qui n en laisse pas.
	f1.entries = [
		_entry(E + "gnome.tres", 4, 1.8),
		_entry(E + "mushroom.tres", 3, 2.2, 5.0),
		_entry(E + "carnivore_plant.tres", 3, 1.8, 12.0),
		_entry(E + "sprite.tres", 4, 1.5, 18.0),
		_entry(E + "golem.tres", 1, 2.5, 24.0),
	]
	_save(f1, "res://resources/waves/w7_1.tres")

	var f2 := WaveDef.new()
	f2.id = &"w7_2"
	f2.duration = 29.0
	f2.difficulty = 1.45
	f2.entries = [
		_entry(E + "void_knight.tres", 2, 2.5),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 9.0),
		_entry(E + "wisp.tres", 4, 1.8, 18.0),
	]
	_save(f2, "res://resources/waves/w7_2.tres")

	var f3 := WaveDef.new()
	f3.id = &"w7_3_miniboss"
	f3.duration = 36.0
	f3.difficulty = 1.1
	f3.is_miniboss = true
	# LE GLOUTON, pas le Gardien (mort en `lvl_04`). Il craint le poison a
	# +35 % : c est le seul mini-boss de la campagne contre lequel la Mare de
	# venin et le Semis de fletrissure sont le bon choix, ce qui donne enfin une
	# cible a cette famille de cartes.
	#
	# CHANTIER W2 — LE GOLEM A NOYAU remplace le Glouton, un P4 ordinaire qui menait
	# le palier faute de mini-boss. Il retourne la lecon ci-dessus : chaque coup qui
	# mord lui arrache un laser, donc la Mare de venin qui tique dix fois devient le
	# PIRE choix. Dans la forge de Vharn, qui compte les coups, le palier annonce le
	# boss : un gros sort vaut mieux que dix petits. Le Glouton sort de la vague
	# (70 PV de moins pour 135 de plus) et une Sauterelle avec lui.
	f3.entries = [
		_entry(E + "mecha_golem.tres", 1, 1.0),
		_entry(E + "berserker.tres", 2, 2.5, 9.0),
		_entry(E + "hopper.tres", 3, 1.8, 20.0),
	]
	_save(f3, "res://resources/waves/w7_3_miniboss.tres")

	var f4 := WaveDef.new()
	f4.id = &"w7_4"
	f4.duration = 32.0
	f4.difficulty = 1.45
	# Les deux registres du jeu dans la meme vague : le blindage (Behemoth) et le
	# nombre (Ruche qui eclate en 4). Le final ne laisse plus choisir son deck.
	# Mesure au banc : cette vague videeait la barre de vie d un coup (95 -> 2 PV,
	# 53 -> 29). Elle cumulait TROIS multiplicateurs invisibles a l ecriture : la
	# ruche eclate en 4 lutins (x2 ruches = 8 corps) et la nuee vaut 4 rats
	# (x3 = 12), soit 23 corps en 32 s — le pic de toute la campagne, sur la vague
	# 4 d un niveau de 6. Une ruche et deux nuees : 14 corps, le finale reste dur
	# sans etre un mur.
	# Le Totem ancien : voir la note sur l Ecumeur (w2_5).
	f4.entries = [
		_entry(E + "behemoth.tres", 1, 1.0),
		_entry(E + "totem_elder.tres", 1, 1.0, 26.0),
		_entry(E + "hive.tres", 1, 2.5, 9.0),
		_entry(E + "rat_swarm.tres", 2, 2.0, 20.0),
	]
	_save(f4, "res://resources/waves/w7_4.tres")

	var f5 := WaveDef.new()
	f5.id = &"w7_5"
	f5.duration = 34.0
	f5.difficulty = 1.45
	# Avant-derniere vague : totem + glouton + jelly, les trois monstres qui
	# fabriquent du probleme si on les laisse vivre.
	# CHANTIER I2 — la biomasse revient, et le Glouton la GOBE : le champignon est
	# un P2, donc une proie valide. Le joueur voit le devoreur grossir sur le
	# decor vegetal du niveau, ce qui est la meilleure demonstration possible de ce
	# que fait ce monstre.
	f5.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "glutton.tres", 1, 1.0, 9.0),
		_entry(E + "mushroom.tres", 2, 2.2, 14.0),
		_entry(E + "jelly.tres", 1, 2.5, 20.0),
		_entry(E + "carnivore_plant.tres", 2, 1.8, 26.0),
		_entry(E + "sprite.tres", 3, 1.5, 30.0),
	]
	_save(f5, "res://resources/waves/w7_5.tres")

	var f6 := WaveDef.new()
	f6.id = &"w7_6_boss"
	f6.duration = 55.0
	f6.difficulty = 1.05
	f6.is_boss = true
	# VHARN, L ENCLUME — CHANTIER N3.
	#
	# Cette vague portait CHRONOS, du temps ou `lvl_07` etait le dernier niveau du
	# jeu et ou l acte 4 s appelait « Le Metier du Monde ». Le document en fait
	# desormais le monde DEMONIAQUE, dont `lvl_07` est l une des quatre portes :
	# Chronos n y a plus sa place (il ferme le registre de l acte 5, ou il est
	# devenu un employe parmi d autres), et un grand demon doit tenir sa forge.
	#
	# CE QUE LA SUBSTITUTION CHANGE DANS LE COMBAT, et pourquoi elle va dans le
	# bon sens : Chronos est un boss SANS mecanique (320 PV, il avance), donc la
	# derniere vague de ce niveau se jouait exactement comme les cinq precedentes,
	# en plus long. Vharn compte les COUPS : le niveau de la forge se termine
	# enfin sur une question de forge, et 195 PV au lieu de 320 compensent le fait
	# que les six premiers coups ne comptent pas.
	#
	# L ESCORTE NE CHANGE PAS : elle etait deja composee de blindes (Chevaliers du
	# vide qui absorbent le premier coup, Berserkers), ce qui convient mieux a
	# Vharn qu a Chronos. C est la seule modification faite a ce niveau deja
	# mesure au banc — on remplace une tete, on ne retouche pas sa courbe.
	f6.entries = [
		_entry(E + "demon_anvil.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 10.0),
		_entry(E + "berserker.tres", 2, 2.5, 24.0),
		_entry(E + "sprite.tres", 4, 1.5, 38.0),
	]
	_save(f6, "res://resources/waves/w7_6_boss.tres")

	var lvl7 := LevelDef.new()
	lvl7.id = &"lvl_07"
	# CHANTIER N3 — LA FORGE DE VHARN, l un des quatre grands demons.
	#
	# Ce niveau s appelait « Le Metier du Monde » et se jouait devant
	# `act4_origin` : c etait le DERNIER niveau du jeu, quand la campagne en
	# comptait sept et que l acte 4 etait le monde des divinites. Le document en
	# fait maintenant le monde DEMONIAQUE (section 6), et l espace divin est
	# l acte 5, qui a desormais ses propres niveaux et son propre fond.
	#
	# On garde donc l identifiant et les vagues — ce niveau est mesure au banc —
	# et on change ce qui le situe : son nom, son lieu, son fond et sa tete.
	# C est exactement la promesse du chantier N : « c est `LevelDef.act` qui
	# porte le plan », et ici c est le CONTENU de l acte qui se met a jour sous un
	# identifiant qui ne bouge pas.
	lvl7.display_name = "La forge de Vharn"
	lvl7.terrain = "grass"
	# LE MONDE DEMONIAQUE, comme les quatre autres niveaux de l acte. Il montrait
	# `act4_origin`, le fond des divinites, qui appartient desormais a l acte 5 —
	# un joueur qui descend en enfer et voit le ciel du registre ne comprend plus
	# ou il est.
	lvl7.backdrop = "act3_demon"
	lvl7.waves = [f1, f2, f3, f4, f5, f6]
	lvl7.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "wisp.tres"),
		load(E + "rat_swarm.tres"), load(E + "hopper.tres"), load(E + "golem.tres"),
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "ghoul_priest.tres"), load(E + "hive.tres"), load(E + "jelly.tres"),
		load(E + "glutton.tres"), load(E + "totem_guardian.tres"),
		load(E + "behemoth.tres"), load(E + "shade.tres"),
		# CHANTIER I2 — la biomasse du monde d origine.
		load(E + "mushroom.tres"), load(E + "carnivore_plant.tres"),
		load(E + "mecha_golem.tres"),
		# CHANTIER N3 — Vharn, qui mene desormais ce niveau. Un boss absent du
		# pool n a pas de monde en Massacre (`build_membership`) et le tirage ne
		# le proposerait jamais.
		load(E + "demon_anvil.tres"),
	]
	# DECK DE SYNTHESE. Le final envoie les DEUX registres, donc le deck porte les
	# deux : Meteore pour le blindage, Boule de feu pour le nombre.
	# Les quatre cartes d histoire ne tiennent plus ensemble avec la regle des 6 :
	# on garde les trois qui COMBATTENT (Spirale, Rupture, Vide d emprise) et le
	# Rappel d ossements sort — c est la seule des quatre qui ne touche aucun
	# monstre. L Apprenti miroir entre ICI : le mage entre dans la matrice avec
	# ses allies, et c est le premier allie qu il invoque lui-meme.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Apprenti miroir. Sortent le Trait, la Resonance, la Marque, le
	# Rappel, la Fleche et le Mur.
	lvl7.exploration_deck = _deck([
		[C + "common/fireball.tres", 4],
		[C + "rare/meteor.tres", 2],
		[C + "rare/salt_spiral.tres", 1],
		[C + "rare/chain_break.tres", 1],
		[C + "epic/void_grip.tres", 2],
		[C + "epic/mirror_apprentice.tres", 2],
	])
	_poser_progression(lvl7)
	# IL MENE AU PENTACLE, comme les trois autres grands demons, et a rien
	# d autre. Ce niveau etait le cul-de-sac de la campagne ; il est desormais
	# l une de ses quatre portes ouvertes en meme temps.
	lvl7.next_levels = [&"lvl_13"]
	lvl7.act = 4
	lvl7.subtitle = "Six coups pour rien, et il est toujours debout"
	lvl7.intro_text = "Une forge sans forgeron, ou tout ce qui bouge porte une \
armure. Vharn ne parle pas et ne se presse pas : il encaisse. Tes premiers sorts ne \
lui feront rien du tout, et il faudra que tu le voies pour le croire."
	lvl7.outro_text = "L Enclume se fend enfin, et dedans il n y a pas de coeur : il \
y a un contrat, grave dans la fonte, signe par quelqu un qu il n a jamais rencontre. \
Vharn se croyait le commanditaire. Il etait un outil de plus dans son propre atelier."
	_save(lvl7, "res://resources/levels/lvl_07.tres")


## =====================================================================
## ACTE I, SUITE — LA FORET DE NURI  (chantier N)
##
## `docs/histoire.md` section 3 decrit QUATRE niveaux pour l acte 1. Le jeu n en
## avait que deux : une compression, pas un plan. Ces deux niveaux la completent
## et ferment l acte sur la mort du Gardien, comme le document l exige.
##
## POURQUOI `lvl_08` ET `lvl_09` ET NON `lvl_03` / `lvl_04` : les identifiants
## `lvl_01..lvl_07` sont graves dans les sauvegardes des joueurs
## (`levels_done`, `current_level`, `stories_seen`). Renumeroter pour coller aux
## LIEUX du document aurait casse la progression de quiconque a deja joue, pour
## un gain purement cosmetique — le joueur ne lit jamais l identifiant, il lit
## le NOM du niveau et l ACTE qui le porte. Les niveaux neufs s ajoutent donc a
## la suite, et c est `LevelDef.act` qui raconte le plan. Voir
## `tests/unit/test_campaign_acts.gd` pour l argumentaire complet.
##
## POURQUOI PAS DE VAGUE `is_boss` SUR `lvl_08` : `test_bosses` exige que chaque
## niveau ait SON adversaire, et le catalogue ne compte que 7 boss et 8
## mini-boss pour 21 niveaux vises. Un boss de campagne n est PAS obligatoire
## (`LevelDef.boss_wave()` rend null sans broncher, et le panneau de campagne
## l affiche « ? »). On reserve donc `is_boss` aux FINS D ACTE — ce que le
## document decrit deja : l acte 1 se ferme sur le Gardien, pas sur quatre boss
## d affilee. `lvl_08` culmine sur un mini-boss, `lvl_09` porte le boss d acte.
## =====================================================================
func _acte_1_suite(C: String, E: String) -> void:

	# ---------- lvl_08 : La route du maire ----------
	#
	# Document, section 3 : « La pression est le NOMBRE : premiere vraie lecon de
	# zone. » Tout le niveau est construit sur ce seul enonce — la Gelee qui se
	# divise, la Ruche qui explose en lutins, les nuees de rats. Aucun gros
	# monstre : un joueur qui repond au mono-cible perd du temps a chaque corps,
	# et c est exactement la lecon.
	#
	# La difficulte reprend la courbe LA OU LE NIVEAU 2 LA LAISSE. Le garde-fou
	# `test_balance` ne surveille que lvl_01 et lvl_02, mais le principe vaut
	# partout : aucune vague ne double la precedente.

	var n1 := WaveDef.new()
	n1.id = &"w8_1"
	n1.duration = 24.0
	n1.difficulty = 1.15
	# Ouverture douce et DEJA divisible : la premiere Gelee tombe seule, pour que
	# le joueur voie la division se produire sans rien d autre a l ecran.
	n1.entries = [
		_entry(E + "jelly.tres", 2, 3.0),
		_entry(E + "rat_swarm.tres", 2, 2.4, 8.0),
	]
	_save(n1, "res://resources/waves/w8_1.tres")

	var n2 := WaveDef.new()
	n2.id = &"w8_2"
	n2.duration = 26.0
	n2.difficulty = 1.25
	# La Ruche entre ici : elle EXPLOSE en lutins a la mort. Le joueur qui la tue
	# de loin voit apparaitre le probleme qu il croyait resoudre.
	n2.entries = [
		_entry(E + "hive.tres", 2, 4.0),
		_entry(E + "sprite.tres", 4, 1.6, 7.0),
		_entry(E + "hopper.tres", 2, 2.0, 16.0),
	]
	_save(n2, "res://resources/waves/w8_2.tres")

	var n3 := WaveDef.new()
	n3.id = &"w8_3"
	n3.duration = 27.0
	n3.difficulty = 1.35
	# Les trois sources de nombre EN MEME TEMPS. C est le pic de la lecon, et
	# c est volontairement avant le mini-boss : la vague suivante change de
	# nature, elle ne surencherit pas.
	n3.entries = [
		_entry(E + "jelly.tres", 2, 3.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 7.0),
		_entry(E + "hive.tres", 1, 1.0, 15.0),
		_entry(E + "gnome.tres", 4, 1.6, 19.0),
	]
	_save(n3, "res://resources/waves/w8_3.tres")

	var n4 := WaveDef.new()
	n4.id = &"w8_4_miniboss"
	n4.duration = 32.0
	n4.difficulty = 1.1
	n4.is_miniboss = true
	# L ANCIEN DU TOTEM ferme le niveau. C est le seul mini-boss encore libre qui
	# reponde a la lecon du niveau par son CONTRAIRE : il porte une aura qui rend
	# ses voisins invulnerables. Apres trois vagues ou il fallait frapper large,
	# le joueur doit soudain frapper PRECIS, sur le porteur d aura, avant de
	# pouvoir toucher quoi que ce soit d autre.
	#
	# `emberlord` et `skyreaver` etaient les deux autres candidats libres :
	# l Ecumeur appartient deja aux vagues du niveau 2 (il y gagne son monde pour
	# le Massacre) et le Seigneur des braises ferme le niveau suivant.
	#
	# Escorte LEGERE et divisible : elle donne a l aura quelque chose a proteger
	# sans doubler les PV de la vague precedente.
	n4.entries = [
		_entry(E + "totem_elder.tres", 1, 1.0),
		_entry(E + "jelly_mid.tres", 3, 2.0, 8.0),
		_entry(E + "sprite.tres", 4, 1.6, 17.0),
	]
	_save(n4, "res://resources/waves/w8_4_miniboss.tres")

	var lvl8 := LevelDef.new()
	lvl8.id = &"lvl_08"
	lvl8.display_name = "La route du maire"
	lvl8.terrain = "grass"
	lvl8.backdrop = "act1_sky"
	lvl8.intro_story = &"lvl_08_intro"
	lvl8.outro_story = &"lvl_08_outro"
	lvl8.waves = [n1, n2, n3, n4]
	# Le pool sert la generation procedurale ET `build_membership()` : tout ce
	# qui descend dans les vagues ecrites doit s y retrouver, sinon le monstre
	# n appartient a aucun monde du Massacre.
	lvl8.enemy_pool = [
		load(E + "jelly.tres"), load(E + "jelly_mid.tres"), load(E + "jelly_small.tres"),
		load(E + "hive.tres"), load(E + "rat_swarm.tres"), load(E + "sprite.tres"),
		load(E + "hopper.tres"), load(E + "gnome.tres"),
		load(E + "totem_elder.tres"),
	]
	# Le deck du niveau du NOMBRE est un deck de ZONES, et 0 legendaire : la
	# legendaire se GAGNE aux objectifs, elle n est pas offerte au depart.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Pluie de givre et Maelstrom. Sortent le Trait et le Brasier ;
	# le Champ de givre monte a 3 pour que le feu ne passe pas la moitie du deck
	# (feu x1.15 ici : la lecon de lvl_03).
	lvl8.exploration_deck = _deck([
		[C + "common/fireball.tres", 4],
		[C + "common/ember_pool.tres", 2],
		[C + "common/frost_field.tres", 1],
		[C + "common/frost_rain.tres", 2],
		[C + "rare/meteor.tres", 2],
		[C + "epic/maelstrom.tres", 1],
	])
	_poser_progression(lvl8)
	lvl8.next_levels = [&"lvl_09"]
	lvl8.act = 1
	lvl8.subtitle = "Ce n est pas la foret qui est attaquee"
	lvl8.intro_text = "Le maire s est tu pendant des mois. Ce n est pas Nuri qui \
tombe, c est toute l ile, et ca vient d en haut. Entre la grange et la clairiere, la \
route grouille : des gelees qui se coupent en deux, des ruches qui eclatent. Frappe \
large ou ne frappe pas."
	lvl8.outro_text = "Au bout de la route, une carcasse de dirigeable coincee dans \
les arbres. Elle fume encore, et quelque chose tape dedans avec un outil. Loin \
derriere, dans la foret, quelque chose de tres grand se met debout."
	_save(lvl8, "res://resources/levels/lvl_08.tres")

	# ---------- lvl_09 : Proteger le dirigeable ----------
	#
	# Document, section 3 : « Le joueur TIENT UNE POSITION pendant un compte a
	# rebours narratif », puis le Gardien de la foret arrive. C est la fin de
	# l acte 1 et la premiere preuve dure de l intrigue : on ne devient pas fou
	# en six jours, on est RETOURNE.
	#
	# LE GARDIEN REVIENT ICI, ET C EST SA SEULE PLACE. `test_bosses` interdit
	# nommement qu il reapparaisse APRES `lvl_04` — la regle etait ecrite quand
	# `lvl_04` fermait l acte 1. Ce niveau EST desormais cette fin : l assertion
	# est mise a jour dans le meme changement, et le Gardien ne figure dans aucun
	# niveau d un acte ulterieur.

	var m1 := WaveDef.new()
	m1.id = &"w9_1"
	m1.duration = 25.0
	m1.difficulty = 1.25
	# On tient une position : les vagues arrivent en PAQUETS espaces, pas en
	# flux continu. Chaque paquet laisse au rat le temps de « reparer ».
	m1.entries = [
		_entry(E + "gnome.tres", 5, 1.8),
		_entry(E + "hopper.tres", 3, 2.0, 11.0),
	]
	_save(m1, "res://resources/waves/w9_1.tres")

	var m2 := WaveDef.new()
	m2.id = &"w9_2"
	m2.duration = 27.0
	m2.difficulty = 1.35
	# Le Corniste revient PRESSER : c est le rappel de la lecon du niveau 2, au
	# moment ou le joueur a autre chose a surveiller.
	m2.entries = [
		_entry(E + "rat_swarm.tres", 2, 2.2),
		_entry(E + "sprite.tres", 4, 1.5, 7.0),
		_entry(E + "hornblower.tres", 1, 1.0, 14.0),
		_entry(E + "jelly.tres", 2, 2.5, 18.0),
	]
	_save(m2, "res://resources/waves/w9_2.tres")

	var m3 := WaveDef.new()
	m3.id = &"w9_3_miniboss"
	m3.duration = 30.0
	m3.difficulty = 1.15
	m3.is_miniboss = true
	# LE SEIGNEUR DES BRAISES. Dernier mini-boss libre du catalogue, et le seul
	# qui annonce le Gardien sans le doubler : il BRULE le terrain, donc il prive
	# le joueur de la position qu on lui demande justement de tenir. C est la
	# meme question que le boss posera en plus gros.
	m3.entries = [
		_entry(E + "emberlord.tres", 1, 1.0),
		_entry(E + "hopper.tres", 3, 2.0, 9.0),
		_entry(E + "gnome.tres", 4, 1.6, 18.0),
	]
	_save(m3, "res://resources/waves/w9_3_miniboss.tres")

	var m4 := WaveDef.new()
	m4.id = &"w9_4"
	m4.duration = 28.0
	m4.difficulty = 1.45
	# Le dernier palier avant le Gardien. Il monte SANS doubler : le boss est
	# deja un saut, il ne faut pas deux sauts d affilee.
	#
	# CHANTIER W2 — DEUX RENARDS DORMEURS a la place de deux Sauterelles. On tient
	# une position pendant que le rat repare : un renard qui s arrete et coupe la
	# magie deux secondes est la pire chose a laisser vivre devant le dirigeable,
	# et le tuer eveille est la decision que la vague demande. Meme puissance (P2),
	# cinq PV de plus chacun.
	m4.entries = [
		_entry(E + "hive.tres", 2, 3.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 8.0),
		_entry(E + "hornblower.tres", 1, 1.0, 15.0),
		_entry(E + "sleepy_fox.tres", 2, 2.4, 18.0),
		_entry(E + "hopper.tres", 1, 1.8, 22.0),
	]
	_save(m4, "res://resources/waves/w9_4.tres")

	var m5 := WaveDef.new()
	m5.id = &"w9_5_boss"
	m5.duration = 42.0
	m5.difficulty = 1.1
	m5.is_boss = true
	# LE GARDIEN DE LA FORET ferme l acte 1, comme le document l ecrit. Il ne
	# menait plus aucune vague depuis qu on l avait retire des six mini-boss ou
	# il faisait doublon : il retrouve ici la SEULE apparition que l histoire lui
	# accorde, et il y meurt.
	#
	# Escorte de gnomes et de lutins, c est-a-dire la vermine du tout premier
	# niveau : l acte se referme sur ce par quoi il a commence, et le contraste
	# de taille fait tout le travail de mise en scene.
	m5.entries = [
		_entry(E + "warden.tres", 1, 1.0),
		_entry(E + "gnome.tres", 5, 1.8, 7.0),
		_entry(E + "sprite.tres", 5, 1.5, 20.0),
	]
	_save(m5, "res://resources/waves/w9_5_boss.tres")

	var lvl9 := LevelDef.new()
	lvl9.id = &"lvl_09"
	lvl9.display_name = "Proteger le dirigeable"
	lvl9.terrain = "grass"
	lvl9.backdrop = "act1_sky"
	lvl9.intro_story = &"lvl_09_intro"
	lvl9.outro_story = &"lvl_09_outro"
	lvl9.waves = [m1, m2, m3, m4, m5]
	lvl9.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "hopper.tres"),
		load(E + "rat_swarm.tres"), load(E + "jelly.tres"), load(E + "hive.tres"),
		load(E + "hornblower.tres"), load(E + "sleepy_fox.tres"),
		load(E + "emberlord.tres"), load(E + "warden.tres"),
	]
	# Le deck de la fin d acte : il garde des zones mais rend du MONO-CIBLE lourd,
	# parce qu un boss de 140 PV ne tombe pas a la nappe de givre.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Concentration et Sablier fendu. Sortent les Braises, le Mur et
	# la Focalisation (un exemplaire chacun) : le Meteore monte a 3, c est lui qui
	# abat le boss.
	lvl9.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/meteor.tres", 2],
		[C + "epic/deep_focus.tres", 1],
		[C + "legendary/hourglass_shard.tres", 1],
	])
	_poser_progression(lvl9)
	# L acte 1 debouche sur l acte 2, qui commence a `lvl_03` (Ossuaire des
	# Marees). Le chainage suit les ACTES, pas les numeros : c est exactement le
	# prix de la decision de ne pas renumeroter, et il est paye ici, en un
	# endroit, plutot que dans toutes les sauvegardes des joueurs.
	# CHANTIER N2 — l acte 1 rend la main a `lvl_17`, LES COURANTS, et non plus
	# directement a `lvl_03`. Le document (section 4) fait monter le groupe dans
	# les courants d air AVANT d atteindre le cimetiere de bordure : `lvl_03` et
	# `lvl_04` sont les deux DERNIERES etapes de l acte 2, pas les premieres.
	lvl9.next_levels = [&"lvl_17"]
	lvl9.act = 1
	lvl9.subtitle = "On ne devient pas fou en six jours"
	lvl9.intro_text = "Le rat pilote repare sous la carcasse et ne veut voir \
personne. Tiens la clairiere le temps qu il faut. Au fond, les arbres s ecartent \
d eux-memes : le Gardien de la foret vient, et il ne marche pas entre les arbres."
	lvl9.outro_text = "Le Gardien s effondre en un tas de bois mort. Dans sa poitrine \
ouverte, plantee comme une echarde, une plaque de metal noir que personne n a taillee \
ici. Il n est pas devenu fou : on lui a mis quelque chose dedans, et la soudure vient \
d en haut."
	_save(lvl9, "res://resources/levels/lvl_09.tres")


## =====================================================================
## ACTE 2, SUITE — LES SKY LANDS  (chantier N2, docs/histoire.md section 4)
##
## Le document donne QUATRE niveaux a l acte 2 ; le jeu n en avait que deux
## (`lvl_03` l Ossuaire, `lvl_04` le Grand Appel), et surtout il n avait AUCUN
## niveau en vol : l acte s appelle « Les Sky Lands » et on n y montait jamais.
## Ces deux niveaux sont la montee elle-meme — les courants d air, puis le port
## pille de Haute-Nacelle.
##
## POURQUOI `lvl_17` ET `lvl_18` ET NON `lvl_05` / `lvl_06` : meme raison qu au
## chantier N pour `lvl_08` / `lvl_09`, et elle n a pas change — les
## identifiants `lvl_01..lvl_09` sont graves dans les sauvegardes des joueurs
## (`levels_done`, `current_level`, `stories_seen`) et dans les scenes de
## `resources/story/`. On EMPILE, et c est `LevelDef.act` qui porte le plan.
## Les numeros `lvl_10` a `lvl_16` sont pris par les actes 4 et 5, ecrits en
## parallele : d ou le saut a 17.
##
## ORDRE DE JEU DE L ACTE 2, tel que le chainage le realise :
##   lvl_09 (fin acte 1) -> lvl_17 (les courants) -> lvl_18 (le port)
##   -> lvl_03 (l ossuaire de bordure) -> lvl_04 (le Grand Appel, boss d acte)
##
## POURQUOI PAS DE VAGUE `is_boss` ICI : `test_bosses` exige un adversaire
## UNIQUE par niveau et le catalogue ne porte pas 21 boss. Les deux niveaux
## culminent donc sur un mini-boss et l acte garde son seul boss, l Ensevelisseur
## de `lvl_04`. `LevelDef.boss_wave()` rend `null` sans broncher.
## =====================================================================
func _acte_2_suite(C: String, E: String) -> void:

	# ---------- lvl_17 : Les courants ----------
	#
	# Document : « tout en vol, plates-formes etroites ». Traduction mecanique
	# en une phrase : LE MUR DE PIERRE NE SERT A RIEN. Cinq des six monstres du
	# niveau volent ou ondulent, donc le decor ne les arrete pas et la
	# trajectoire droite ne se predit pas. Le joueur qui s est construit une
	# ligne de defense a l acte 1 doit apprendre a couvrir une SURFACE.
	#
	# C est la seule lecon du niveau et elle est enseignee sans mini-boss
	# exotique : l Ecumeur du ciel qui le ferme vole, lui aussi.

	var p1 := WaveDef.new()
	p1.id = &"w17_1"
	p1.duration = 24.0
	p1.difficulty = 1.30
	# Ouverture en VOL PUR, et volontairement legere : trois Planogos et deux
	# Oeils suffisent a faire rater le premier Mur de pierre, ce qui est tout ce
	# qu on demande a une premiere vague.
	p1.entries = [
		_entry(E + "wisp.tres", 3, 2.2),
		_entry(E + "current_eye.tres", 2, 2.4, 9.0),
	]
	_save(p1, "res://resources/waves/w17_1.tres")

	var p2 := WaveDef.new()
	p2.id = &"w17_2"
	p2.duration = 26.0
	p2.difficulty = 1.35
	# L Archer entre : il ne vole pas, mais il TIRE de loin, donc il ne vient pas
	# non plus se poser sur la ligne. Le Serpent ondule. Trois facons differentes
	# de ne pas etre la ou on visait.
	p2.entries = [
		_entry(E + "current_eye.tres", 3, 2.0),
		_entry(E + "imp_archer.tres", 2, 2.2, 8.0),
		_entry(E + "sand_serpent.tres", 3, 1.8, 16.0),
	]
	_save(p2, "res://resources/waves/w17_2.tres")

	var p3 := WaveDef.new()
	p3.id = &"w17_3"
	p3.duration = 27.0
	p3.difficulty = 1.40
	# LE PIC DU NIVEAU, et il tombe AVANT le mini-boss : la vague suivante change
	# de nature, elle ne surencherit pas. L Ombre disparait la moitie du temps,
	# ce qui ajoute la derniere facon de manquer une cible.
	p3.entries = [
		_entry(E + "wisp.tres", 3, 2.0),
		_entry(E + "shade.tres", 3, 2.0, 8.0),
		_entry(E + "current_eye.tres", 3, 2.0, 15.0),
		_entry(E + "sand_serpent.tres", 2, 1.8, 21.0),
	]
	_save(p3, "res://resources/waves/w17_3.tres")

	var p4 := WaveDef.new()
	p4.id = &"w17_4_miniboss"
	p4.duration = 32.0
	p4.difficulty = 1.10
	p4.is_miniboss = true
	# LE GRAND OEIL DES COURANTS, palier 2 de l Oeil que les trois vagues
	# precedentes ont appris au joueur. Il vole, il ondule et il TIRE : la seule
	# tete de vague de la campagne qu on ne puisse ni bloquer au mur ni ignorer
	# au fond du terrain.
	#
	# L Ecumeur du ciel etait le candidat evident et il est pris : il mene le
	# mini-boss de `lvl_11` (acte 4). Voir la note de `great_eye` dans
	# `_enemies()` pour ce que le palier gagne a exister quand meme.
	#
	# Escorte legere et volante : elle doit PARTAGER sa nature, sinon le joueur
	# pose une zone au sol et regle la moitie du probleme par accident.
	#
	p4.entries = [
		_entry(E + "great_eye.tres", 1, 1.0),
		_entry(E + "wisp.tres", 3, 2.0, 9.0),
		_entry(E + "current_eye.tres", 3, 2.0, 19.0),
	]
	_save(p4, "res://resources/waves/w17_4_miniboss.tres")

	var lvl17 := LevelDef.new()
	lvl17.id = &"lvl_17"
	lvl17.display_name = "Les courants"
	lvl17.terrain = "grass"
	# `act1_sky` et non `act2_graveyard` : docs/histoire.md, section 4, dit
	# « Fond : act1_sky PUIS act2_graveyard ». L acte 2 monte depuis le ciel de
	# l acte 1 et ne touche le cimetiere qu a sa fin. Les deux niveaux d ici
	# gardent donc le ciel, `lvl_03` et `lvl_04` gardent le cimetiere.
	lvl17.backdrop = "act1_sky"
	lvl17.intro_story = &"lvl_17_intro"
	lvl17.outro_story = &"lvl_17_outro"
	lvl17.waves = [p1, p2, p3, p4]
	lvl17.enemy_pool = [
		load(E + "current_eye.tres"), load(E + "wisp.tres"),
		load(E + "imp_archer.tres"), load(E + "sand_serpent.tres"),
		load(E + "shade.tres"), load(E + "great_eye.tres"),
	]
	# DECK ANTI-VOL, 0 legendaire (elle se GAGNE aux objectifs). Pas UN Mur de
	# pierre, et c est le message : contre du vol le decor ne repond pas. A la
	# place, des zones larges qui couvrent le ciel ou les cibles vont passer, et
	# des Traits pour achever l Archer qui campe au fond.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Resonance et Onde de repulsion. Sortent la Spirale de sel (elle
	# reste la carte d histoire de l Ossuaire, qui se joue plus tard et doit
	# pouvoir la faire DECOUVRIR) et la Precipitation.
	lvl17.exploration_deck = _deck([
		[C + "common/frost_rain.tres", 4],
		[C + "common/arcane_bolt.tres", 2],
		[C + "common/fireball.tres", 1],
		[C + "common/frost_field.tres", 1],
		[C + "epic/resonance.tres", 2],
		[C + "rare/repulsion_wave.tres", 2],
	])
	_poser_progression(lvl17)
	lvl17.next_levels = [&"lvl_18"]
	lvl17.act = 2
	lvl17.subtitle = "Le mur ne sert plus a rien"
	lvl17.intro_text = "Le dirigeable monte dans les courants et tout ce qui t y \
attend vole. Les Planogos passent au-dessus des murs, les Oeils se laissent porter et \
ne vont jamais droit, l Archer ne descend pas du tout. Couvre le ciel ou ne couvre \
rien."
	lvl17.outro_text = "L Ecumeur du ciel tombe a cote de la nacelle. Le rat le \
retourne du pied et ne dit rien pendant un moment : sous l aile, la meme soudure noire \
que dans la poitrine du Gardien. Les Sky Lands ne sont pas sauvages. Elles sont un \
atelier."
	_save(lvl17, "res://resources/levels/lvl_17.tres")


	# ---------- lvl_18 : Port de Haute-Nacelle ----------
	#
	# Document : « un port pille, quais de bois », `void_knight`, `berserker`,
	# `shade`. Apres un niveau ou rien ne touchait le sol, le port le remet : ce
	# sont des HUMANOIDES, ils marchent, mais chacun punit une facon de frapper.
	#
	# La lecon est l ORDRE DES CIBLES, et elle est posee par trois monstres qui
	# se contredisent : le Chevalier du vide avale le premier coup (donc les
	# petites cartes sont du gaspillage), le Berserker accelere a chaque coup
	# recu (donc les petites cartes le rendent pire), et le Pillard arrive PAR LE
	# COTE pendant qu on regarde le haut de l ecran.

	var q1 := WaveDef.new()
	q1.id = &"w18_1"
	q1.duration = 25.0
	q1.difficulty = 1.35
	# Les Pillards ouvrent, seuls : la premiere fois qu un monstre entre par le
	# cote doit etre lisible, sans rien d autre pour la masquer.
	q1.entries = [
		_entry(E + "nacelle_raider.tres", 4, 1.8),
		_entry(E + "shade.tres", 2, 2.2, 10.0),
	]
	_save(q1, "res://resources/waves/w18_1.tres")

	var q2 := WaveDef.new()
	q2.id = &"w18_2"
	q2.duration = 27.0
	q2.difficulty = 1.40
	# Chevalier du vide ET Berserker dans la meme vague : les deux erreurs
	# opposees sont disponibles en meme temps, c est la vraie lecon du port.
	q2.entries = [
		_entry(E + "void_knight.tres", 2, 2.5),
		_entry(E + "berserker.tres", 2, 2.5, 9.0),
		_entry(E + "nacelle_raider.tres", 3, 1.8, 18.0),
	]
	_save(q2, "res://resources/waves/w18_2.tres")

	var q3 := WaveDef.new()
	q3.id = &"w18_3"
	q3.duration = 28.0
	q3.difficulty = 1.45
	# Le pic. On ajoute des corps, pas des PV : la vague precedente portait deja
	# les deux gros, celle-ci ajoute du nombre autour d eux.
	q3.entries = [
		_entry(E + "berserker.tres", 2, 2.5),
		_entry(E + "nacelle_raider.tres", 4, 1.6, 8.0),
		_entry(E + "shade.tres", 3, 2.0, 15.0),
		_entry(E + "void_knight.tres", 1, 2.5, 21.0),
	]
	_save(q3, "res://resources/waves/w18_3.tres")

	var q4 := WaveDef.new()
	q4.id = &"w18_4_miniboss"
	q4.duration = 34.0
	q4.difficulty = 1.10
	q4.is_miniboss = true
	# LE MAGE NOIR DE HAUTE-NACELLE. Il CAMPE a 380 px du mage et il tire : pour
	# la premiere fois de la campagne, l adversaire ne vient pas. Le joueur doit
	# percer jusqu a lui a travers les pillards que le mage noir fabrique pendant
	# ce temps-la — et il ne peut pas attendre, parce que les traits, eux,
	# arrivent.
	q4.entries = [
		_entry(E + "dark_mage.tres", 1, 1.0),
		_entry(E + "nacelle_raider.tres", 3, 1.8, 8.0),
		_entry(E + "void_knight.tres", 1, 2.5, 18.0),
	]
	_save(q4, "res://resources/waves/w18_4_miniboss.tres")

	var lvl18 := LevelDef.new()
	lvl18.id = &"lvl_18"
	lvl18.display_name = "Port de Haute-Nacelle"
	lvl18.terrain = "sand"
	lvl18.backdrop = "act1_sky"
	lvl18.intro_story = &"lvl_18_intro"
	lvl18.outro_story = &"lvl_18_outro"
	lvl18.waves = [q1, q2, q3, q4]
	lvl18.enemy_pool = [
		load(E + "nacelle_raider.tres"), load(E + "void_knight.tres"),
		load(E + "berserker.tres"), load(E + "shade.tres"),
		load(E + "current_eye.tres"), load(E + "dark_mage.tres"),
	]
	# DECK DE GROS COUPS. Le contraire exact du deck precedent, et c est
	# volontaire : contre un Chevalier qui avale le premier coup et un Berserker
	# que chaque coup accelere, une nappe est un piege. Meteore et Focalisation
	# donnent le paquet de degats ; la Marque de faiblesse double ce qui suit.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Focalisation et Marque de faiblesse. Sortent le Mur et la
	# Rupture de chaine (carte d histoire des Forges, qui doit s y decouvrir) ;
	# le Trait et la Boule de feu prennent leur place.
	lvl18.exploration_deck = _deck([
		[C + "rare/meteor.tres", 2],
		[C + "common/arcane_bolt.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/focus.tres", 1],
		[C + "common/piercing_arrow.tres", 2],
		[C + "epic/weakness_mark.tres", 2],
	])
	_poser_progression(lvl18)
	# Le port rend la main a `lvl_03`, l ossuaire de bordure : c est le moment ou
	# le document fait passer le fond de `act1_sky` a `act2_graveyard`.
	lvl18.next_levels = [&"lvl_03"]
	lvl18.act = 2
	lvl18.subtitle = "L ordre des cibles"
	lvl18.intro_text = "Haute-Nacelle a ete videe par le haut, pas par le bas. Sur \
les quais, trois facons de te tromper : le Chevalier du vide avale ton premier coup, \
le Berserker accelere a chaque coup recu, et les Pillards n arrivent meme pas par la \
ou tu regardes."
	lvl18.outro_text = "Le mage noir tombe sur ses propres soudures. L enfant \
traverse le quai sans hesiter, prend a droite et dit que la gauche est fermee. Il n est \
jamais venu ici. Personne ne releve."
	_save(lvl18, "res://resources/levels/lvl_18.tres")


## =====================================================================
## ACTE 3 — LE CIMETIERE DE TOMBOL  (chantier N2, docs/histoire.md section 5)
##
## Le document donne CINQ niveaux et une forme : « le Roi squelette FUIT. Tout
## l acte est une poursuite : a chaque niveau on arrive juste apres lui, on
## brise ce qu il a laisse derriere pour retarder. » Le jeu avait deux niveaux
## dans l acte 3 (`lvl_05` les Forges, `lvl_06` la Cour brisee), une FOURCHE, et
## rien de Tombol dedans.
##
## CE QUI EST AJOUTE : les trois niveaux de la poursuite — les fosses basses, la
## cour des rois morts, et le pentacle ou le roi est accule. La fourche existante
## est CONSERVEE telle quelle : elle est equilibree au banc et son contenu
## (blindes d un cote, effets de l autre) tient tres bien le role des deux
## etapes intermediaires du document (l ossuaire blinde, le puits de contrat).
## Elle est seulement re-chainee pour tomber dans le pentacle au lieu de sauter
## directement a l acte 4.
##
## ORDRE DE JEU DE L ACTE 3 :
##   lvl_04 (fin acte 2) -> lvl_19 (les fosses basses) -> lvl_20 (la cour des
##   rois morts) -> [lvl_05 | lvl_06] au choix -> lvl_21 (le pentacle)
##
## `lvl_21` EST LE PORTAIL DE L ACTE 4, et il est le seul. Le document
## (section 6) veut que les quatre grands demons s ouvrent d un coup : c est le
## pentacle qui les ouvre, puisque c est par lui qu on descend.
## =====================================================================
func _acte_3_suite(C: String, E: String) -> void:

	# ---------- lvl_19 : Les fosses basses ----------
	#
	# Document : « tombes ouvertes, on avance dans l eau », `ghoul_priest` et
	# `shade`. La lecon est le SOIN : tant qu un soigneur vit, les degats etales
	# ne comptent pas. Le niveau la pose en trois temps — un Pretre seul, puis
	# deux qui se soignent l un l autre, puis une Sorciere qui soigne ET leve
	# des mortes.

	var r1 := WaveDef.new()
	r1.id = &"w19_1"
	r1.duration = 26.0
	r1.difficulty = 1.40
	# Un seul Pretre, avec de la chair autour de lui : le joueur doit VOIR la
	# barre de vie remonter, et comprendre pourquoi.
	#
	# CHANTIER W2 — deux Slimes fantomes a la place des deux Ombres : on avance
	# dans l eau des tombes ouvertes, et ce qui y meurt ne reste pas mort. Trois
	# secondes apres chacun, un Slime squelette sort de la marque — la premiere
	# fois que le joueur voit le danger arriver AVANT qu il soit la.
	r1.entries = [
		_entry(E + "pit_ghoul.tres", 2, 2.4),
		_entry(E + "ghoul_priest.tres", 1, 2.0, 10.0),
		_entry(E + "slime_ghost.tres", 2, 2.2, 17.0),
	]
	_save(r1, "res://resources/waves/w19_1.tres")

	var r2 := WaveDef.new()
	r2.id = &"w19_2"
	r2.duration = 27.0
	r2.difficulty = 1.45
	# DEUX Pretres : ils se soignent mutuellement, donc en tuer un seul ne suffit
	# pas et en tuer aucun rend la vague interminable. Premier vrai probleme
	# d ordre de cibles de l acte.
	# CHANTIER W2 — deux Slimes squelettes descendent SEULS, sans fantome : la
	# silhouette qu on a vue renaitre devient une creature qu on connait.
	r2.entries = [
		_entry(E + "ghoul_priest.tres", 2, 2.5),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 9.0),
		_entry(E + "shade.tres", 1, 2.0, 18.0),
		_entry(E + "slime_skeleton.tres", 2, 2.0, 20.0),
	]
	_save(r2, "res://resources/waves/w19_2.tres")

	var r3 := WaveDef.new()
	r3.id = &"w19_3"
	r3.duration = 28.0
	r3.difficulty = 1.50
	# Le pic. On ajoute le Squelette pareur, qui avale le premier coup : contre
	# du soin, le joueur veut des coups repetes ; contre un pareur, le premier
	# coup est perdu. Les deux exigences s opposent dans la meme vague.
	# CHANTIER W2 — le Gros slime fantome ferme le pic a la place de deux
	# Ombres : il laisse DEUX squelettes, donc une marque qui vaut deux corps. Le
	# joueur qui a appris a viser la marque en w19_1 le fait ici pour de bon.
	r3.entries = [
		_entry(E + "pit_ghoul.tres", 2, 2.2),
		_entry(E + "parry_skeleton.tres", 3, 2.2, 8.0),
		_entry(E + "ghoul_priest.tres", 1, 2.0, 16.0),
		_entry(E + "slime_ghost_big.tres", 1, 2.0, 22.0),
	]
	_save(r3, "res://resources/waves/w19_3.tres")

	var r4 := WaveDef.new()
	r4.id = &"w19_4_miniboss"
	r4.duration = 34.0
	r4.difficulty = 1.10
	r4.is_miniboss = true
	# LA SORCIERE DES FOSSES. Elle soigne comme le Pretre et elle LEVE en plus :
	# la vague se remplit pendant qu on la nettoie. La seule sortie est d aller
	# la chercher dans sa propre foule, et son escorte est faite pour la cacher.
	r4.entries = [
		_entry(E + "pit_witch.tres", 1, 1.0),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 8.0),
		_entry(E + "parry_skeleton.tres", 2, 2.2, 19.0),
	]
	_save(r4, "res://resources/waves/w19_4_miniboss.tres")

	# CHANTIER W2 — LE TRIO DE MAGES, boss des fosses basses.
	#
	# Le premier acte de la poursuite : le Roi squelette laisse derriere lui ce
	# qu il a de plus precieux, TROIS gardiens de la pierre du pentacle (la meme
	# que le Sceau de Tombol, qu on affrontera au bout de l acte). Ils arrivent
	# ENSEMBLE — six dixiemes de seconde d ecart, le temps que le joueur lise trois
	# couleurs et non une tache.
	#
	# POURQUOI ICI ET PAS DANS LA COUR DES ROIS MORTS, dont les « statues »
	# appelaient le trio : mesure au banc du 27/09, `lvl_20` se gagne 13 fois sur
	# 30 et `lvl_19` 30 fois sur 30. Un boss de plus dans la cour la faisait tomber
	# a zero ; ici il donne au premier niveau de l acte le palier qui lui manquait.
	#
	# Escorte MINIMALE, et tardive : trois tetes a lire suffisent. Deux fournees
	# de goules a 20 s rappellent que les fosses continuent de se vider.
	var r5 := WaveDef.new()
	r5.id = &"w19_5_boss"
	r5.duration = 45.0
	r5.difficulty = 1.0
	r5.is_boss = true
	r5.entries = [
		_entry(E + "trio_ember.tres", 1, 1.0),
		_entry(E + "trio_frost.tres", 1, 1.0, 0.6),
		_entry(E + "trio_arcane.tres", 1, 1.0, 1.2),
		_entry(E + "pit_ghoul.tres", 2, 3.0, 20.0),
	]
	_save(r5, "res://resources/waves/w19_5_boss.tres")

	var lvl19 := LevelDef.new()
	lvl19.id = &"lvl_19"
	lvl19.display_name = "Les fosses basses"
	lvl19.terrain = "sand"
	lvl19.backdrop = "act2_graveyard"
	lvl19.intro_story = &"lvl_19_intro"
	lvl19.outro_story = &"lvl_19_outro"
	lvl19.waves = [r1, r2, r3, r4, r5]
	lvl19.enemy_pool = [
		load(E + "pit_ghoul.tres"), load(E + "ghoul_priest.tres"),
		load(E + "shade.tres"), load(E + "parry_skeleton.tres"),
		load(E + "risen_ghoul.tres"), load(E + "pit_witch.tres"),
		load(E + "slime_ghost.tres"), load(E + "slime_skeleton.tres"),
		load(E + "slime_ghost_big.tres"),
		load(E + "trio_frost.tres"), load(E + "trio_ember.tres"),
		load(E + "trio_arcane.tres"),
	]
	# DECK ANTI-SOIN. Un soigneur ne se bat pas au total de degats, il se bat au
	# DEBIT : il faut passer sa barre plus vite qu il ne la remonte. D ou trois
	# Meteores et la Focalisation, et la Lumiere purifiante qui efface ce que les
	# morts-vivants se donnent. Le Semis de fletrissure n y est pas : les goules
	# sont immunisees au venin.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Lumiere purifiante. Sortent le Registre des marees (la
	# legendaire se gagne, elle n est plus offerte ici), la Fleche et le Mur.
	lvl19.exploration_deck = _deck([
		[C + "rare/meteor.tres", 3],
		[C + "common/arcane_bolt.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/focus.tres", 1],
		[C + "rare/purifying_light.tres", 1],
		[C + "epic/weakness_mark.tres", 2],
	])
	_poser_progression(lvl19)
	lvl19.next_levels = [&"lvl_20"]
	lvl19.act = 3
	lvl19.subtitle = "Ce qui remonte les barres de vie"
	lvl19.intro_text = "Tombol commence par le bas : des fosses ouvertes ou l on \
avance dans l eau. Les Pretres goules y soignent tout ce qui marche, et ils se soignent \
entre eux. Contre eux, frapper fort et frapper juste sont deux choses differentes."
	lvl19.outro_text = "Le Roi squelette est passe ici il y a moins d une heure — \
l eau des fosses est encore trouble de son sillage. Il n a pas laisse un piege : il a \
laisse une GARDE, et une garde ne protege pas un fuyard, elle retarde un poursuivant."
	_save(lvl19, "res://resources/levels/lvl_19.tres")

	# ---------- lvl_20 : La cour des rois morts ----------
	#
	# Document : « statues, arrieres-gardes laissees par le roi »,
	# `totem_guardian` et `hive`. La lecon est la PRIORITE IMPOSEE : le
	# Gardien-totem rend ses voisins invulnerables, donc le joueur ne choisit
	# plus sa cible, la vague la choisit pour lui. La Ruche ajoute le probleme
	# inverse — la tuer FABRIQUE des lutins.
	#
	# C est aussi le niveau ou le joueur comprend que le roi ne se defend pas :
	# il abandonne des gardes, l une apres l autre, et chacune coute du temps.

	var s1 := WaveDef.new()
	s1.id = &"w20_1"
	s1.duration = 26.0
	s1.difficulty = 1.45
	# Un seul totem, isole, avec juste assez de monde autour pour que l aura se
	# VOIE. Le joueur doit pouvoir lire la regle avant qu on l en punisse.
	s1.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "parry_skeleton.tres", 3, 2.2, 8.0),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 17.0),
	]
	_save(s1, "res://resources/waves/w20_1.tres")

	var s2 := WaveDef.new()
	s2.id = &"w20_2"
	s2.duration = 28.0
	s2.difficulty = 1.50
	# La Ruche entre : elle explose en quatre lutins. Contre un totem on veut
	# frapper precis, contre une ruche on veut frapper large — la cour des rois
	# morts demande les deux dans la meme vague.
	s2.entries = [
		_entry(E + "hive.tres", 2, 3.0),
		_entry(E + "void_knight.tres", 2, 2.5, 10.0),
		_entry(E + "shade.tres", 3, 2.0, 19.0),
	]
	_save(s2, "res://resources/waves/w20_2.tres")

	var s3 := WaveDef.new()
	s3.id = &"w20_3"
	s3.duration = 29.0
	s3.difficulty = 1.55
	# Le pic : DEUX totems qui se couvrent l un l autre. Tant qu il en reste un,
	# l autre est intouchable — il faut les prendre par les cotes, et c est la
	# question que le boss de l acte posera en plus grand.
	s3.entries = [
		_entry(E + "totem_guardian.tres", 2, 3.0),
		_entry(E + "hive.tres", 1, 2.0, 11.0),
		_entry(E + "parry_skeleton.tres", 3, 2.0, 18.0),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 23.0),
	]
	_save(s3, "res://resources/waves/w20_3.tres")

	var s4 := WaveDef.new()
	s4.id = &"w20_4_miniboss"
	s4.duration = 33.0
	s4.difficulty = 1.10
	s4.is_miniboss = true
	# L EPEISTE D OMBRE, la derniere arriere-garde que le roi laisse. Le seul
	# mini-boss RAPIDE du cimetiere, et le seul qui cumule l avance par a-coups
	# et la parade du premier coup : viser ou il etait est faux deux fois.
	s4.entries = [
		_entry(E + "shadow_bladesman.tres", 1, 1.0),
		_entry(E + "shade.tres", 3, 2.0, 9.0),
		_entry(E + "parry_skeleton.tres", 2, 2.2, 20.0),
	]
	_save(s4, "res://resources/waves/w20_4_miniboss.tres")

	var lvl20 := LevelDef.new()
	lvl20.id = &"lvl_20"
	lvl20.display_name = "La cour des rois morts"
	lvl20.terrain = "sand"
	lvl20.backdrop = "act2_graveyard"
	lvl20.intro_story = &"lvl_20_intro"
	lvl20.outro_story = &"lvl_20_outro"
	lvl20.waves = [s1, s2, s3, s4]
	lvl20.enemy_pool = [
		load(E + "totem_guardian.tres"), load(E + "hive.tres"),
		load(E + "void_knight.tres"), load(E + "shade.tres"),
		load(E + "parry_skeleton.tres"), load(E + "pit_ghoul.tres"),
		load(E + "shadow_bladesman.tres"),
	]
	# DECK DE PERCEE. Contre une aura, il faut atteindre le PORTEUR : d ou la
	# Fleche percante, qui traverse la ligne, et le Trait pour finir. Contre les
	# ruches, deux zones — pas plus, sinon le joueur retombe dans le reflexe que
	# les totems punissent. Le Vide d emprise est la reponse d urgence : il efface
	# l aura du porteur.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Vide d emprise. Sortent la Spirale, le Mur et la Focalisation ;
	# la Fleche monte a 4, c est la carte du niveau.
	# Vague 8, deck de 12 : Fleche 3 (objectif « 21 Fleches »), le Trait (arcane,
	# x1,48 ici) garde ses 4 exemplaires et la Marque en perd un. Au banc (60
	# parties, incantations x2,25) : 15 victoires avec Trait 3 / Marque 2, 19 avec
	# Trait 4 / Marque 1.
	lvl20.exploration_deck = _deck([
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/fireball.tres", 2],
		[C + "rare/meteor.tres", 1],
		[C + "epic/weakness_mark.tres", 1],
		[C + "epic/void_grip.tres", 1],
	])
	_poser_progression(lvl20)
	# LA FOURCHE EXISTANTE. `lvl_05` (les Forges, des blindes) et `lvl_06` (la
	# Cour brisee, des monstres a effets) etaient deja une fourche equilibree au
	# banc : meme place dans la courbe, exigences opposees. Elle prend ici le
	# role des deux etapes intermediaires du document — l ossuaire blinde et le
	# puits de contrat — et les deux retombent dans le pentacle.
	lvl20.next_levels = [&"lvl_05", &"lvl_06"]
	lvl20.act = 3
	lvl20.subtitle = "La vague choisit ta cible"
	lvl20.intro_text = "Une cour de statues, et sous chaque statue un Gardien-totem \
qui rend ses voisins intouchables. Tu ne choisis plus ou frapper : il faut d abord \
abattre celui qui protege, et il se protege lui-meme derriere ceux qu il protege."
	lvl20.outro_text = "La derniere arriere-garde tombe sans un mot. Le Roi squelette \
n a laisse ni message ni piege : il a laisse des gens a mourir pour gagner une heure. \
On ne fuit pas comme ca devant un poursuivant. On fuit comme ca devant un creancier."
	_save(lvl20, "res://resources/levels/lvl_20.tres")

	# ---------- lvl_21 : Le pentacle ----------
	#
	# Document : « salle du portail, le roi accule », « mixte + le portail »,
	# et c est le RETOURNEMENT de l acte 3 — le roi n a jamais fui le mage, il
	# fuyait ses creanciers, et ils arrivent par le puits.
	#
	# FIN D ACTE, donc vague de BOSS : le Sceau de Tombol, le pentacle lui-meme.
	# Il n avance jamais, il rend ses voisins invulnerables et il fait monter des
	# squelettes du puits tant qu il vit. Le joueur doit entrer DANS l aura,
	# c est-a-dire faire exactement ce que la cour des rois morts lui a appris,
	# mais sans pouvoir attendre que le porteur vienne a lui.
	#
	# « Mixte » est pris au mot : les vagues normales melangent les trois actes
	# — vermine de la foret, volants des Sky Lands, morts-vivants de Tombol.
	# C est le dernier palier avant la descente et il doit se lire comme une
	# somme.

	var t1 := WaveDef.new()
	t1.id = &"w21_1"
	t1.duration = 27.0
	t1.difficulty = 1.50
	# Mixte des trois actes, et rien de neuf : le joueur doit reconnaitre tout ce
	# qui descend. C est ce qui fait sentir qu on est au bout d un voyage.
	t1.entries = [
		_entry(E + "pit_ghoul.tres", 2, 2.2),
		_entry(E + "current_eye.tres", 3, 2.0, 9.0),
		_entry(E + "berserker.tres", 2, 2.5, 17.0),
	]
	_save(t1, "res://resources/waves/w21_1.tres")

	var t2 := WaveDef.new()
	t2.id = &"w21_2_miniboss"
	t2.duration = 28.0
	t2.difficulty = 1.55
	# LE VER DE FEU entre : il remonte du puits, il ondule et il tire. Il est
	# aussi le seul monstre de l acte IMMUNISE AU FEU — le joueur qui a fini par
	# se fabriquer un deck de feu trouve ici la porte fermee.
	#
	# CHANTIER W2 — LA VAGUE DEVIENT UN PALIER : le Fossoyeur la mene. Le pentacle
	# n avait aucun mini-boss (voir w21_3) et le catalogue en compte desormais un
	# de plus. Il ENTRE PAR LE COTE, des tombes du bord, et il RELEVE les morts
	# autour de lui : chaque squelette abattu pres de lui se remet debout. La salle
	# du portail est la ou l on a enterre le plus, c est la qu il travaille.
	#
	# Le poids est tenu : il prend la place de deux Vers et d une Ombre, et la
	# difficulte descend a 1,10 comme sur tout palier — ses six releves sont deja
	# un supplement de PV que le tableau ne voit pas.
	t2.is_miniboss = true
	t2.difficulty = 1.10
	t2.entries = [
		_entry(E + "gravedigger.tres", 1, 1.0),
		_entry(E + "fire_worm.tres", 1, 2.2, 4.0),
		_entry(E + "parry_skeleton.tres", 2, 2.0, 10.0),
		_entry(E + "shade.tres", 1, 2.0, 19.0),
	]
	_save(t2, "res://resources/waves/w21_2_miniboss.tres")

	var t3 := WaveDef.new()
	t3.id = &"w21_3"
	t3.duration = 34.0
	t3.difficulty = 1.60
	# PAS DE VAGUE DE MINI-BOSS ICI, et c est un choix force autant qu assume.
	#
	# `test_bosses` interdit qu un mini-boss mene DEUX niveaux, et apres les cinq
	# tetes neuves de ce chantier (Grand Oeil, Mage noir, Sorciere des fosses,
	# Epeiste d ombre, Sceau de Tombol) le catalogue n en laisse plus un seul de
	# libre : Gardien, Ecumeur, Gardien d ossements, Seigneur de braise, Totem
	# ancien, Miroir de Forge, Matrone gorgone, Bourreau et Glouton menent deja
	# chacun le sien.
	#
	# Plutot que d en inventer un de plus pour remplir une case, ce dernier
	# palier reste une vague NORMALE et porte la difficulte la plus haute de
	# l acte (1,60). C est defendable narrativement : la salle du pentacle n a
	# pas de garde, le roi n en a plus a donner — tout ce qui reste sort du puits,
	# et c est le BOSS qui l ouvre.
	#
	# TROIS Chevaliers du vide et non deux. A deux, cette vague pesait 20 points
	# de troupes contre 22 a la vague precedente : LA COURBE RECULAIT juste avant
	# le boss, releve par `tools/data_sheet.tscn` (anomalie « courbe qui recule »).
	# Un palier qui redescend juste avant un boss laisse croire au joueur qu il a
	# passe le plus dur.
	t3.entries = [
		_entry(E + "void_knight.tres", 3, 2.5),
		_entry(E + "fire_worm.tres", 2, 2.2, 10.0),
		_entry(E + "totem_guardian.tres", 1, 2.0, 18.0),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 23.0),
	]
	_save(t3, "res://resources/waves/w21_3.tres")

	var t4 := WaveDef.new()
	t4.id = &"w21_4_boss"
	t4.duration = 45.0
	t4.difficulty = 1.05
	t4.is_boss = true
	# LE SCEAU DE TOMBOL ferme l acte 3. L escorte est volontairement LEGERE :
	# il fabrique deja ses propres squelettes et son aura les rend intouchables.
	# En ajouter reviendrait a fermer le terrain, et un terrain ferme n est plus
	# une decision.
	t4.entries = [
		_entry(E + "tombol_seal.tres", 1, 1.0),
		_entry(E + "fire_worm.tres", 2, 2.5, 12.0),
		_entry(E + "pit_ghoul.tres", 2, 2.2, 28.0),
	]
	_save(t4, "res://resources/waves/w21_4_boss.tres")

	var lvl21 := LevelDef.new()
	lvl21.id = &"lvl_21"
	lvl21.display_name = "Le pentacle"
	lvl21.terrain = "sand"
	lvl21.backdrop = "act2_graveyard"
	lvl21.intro_story = &"lvl_21_intro"
	lvl21.outro_story = &"lvl_21_outro"
	lvl21.waves = [t1, t2, t3, t4]
	lvl21.enemy_pool = [
		load(E + "pit_ghoul.tres"), load(E + "parry_skeleton.tres"),
		load(E + "fire_worm.tres"), load(E + "shade.tres"),
		load(E + "void_knight.tres"), load(E + "berserker.tres"),
		load(E + "totem_guardian.tres"), load(E + "current_eye.tres"),
		load(E + "tombol_seal.tres"), load(E + "gravedigger.tres"),
	]
	# DECK DE SYNTHESE DE L ACTE 3, et il doit resoudre TROIS problemes que rien
	# ne resout ensemble : une aura qu il faut percer, un boss qui ne bouge pas,
	# et un Ver de feu immunise au feu.
	# D ou la Fleche percante en nombre (elle traverse jusqu au porteur d aura),
	# le Trait arcanique — l element que le Sceau craint le plus (1,30) — et la
	# Pluie de givre, la seule zone que le Ver ne rende pas inutile. Plus AUCUNE
	# Boule de feu : le feu n est plus la reponse ici, et c est le niveau qui le dit.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Pluie de meteorites. Sortent la derniere Boule de feu et la
	# Focalisation ; Trait et Fleche montent a 4.
	#
	# DISSIPATION (chantier W9) : « une aura qu il faut percer » — les
	# Gardiens-totems de w21_3 et l aura du Sceau de Tombol — et le deck ne
	# portait aucune dissipation : la Fleche traverse jusqu au porteur, mais un
	# porteur couvert par un second porteur ne tombe pas. La Lumiere purifiante
	# prend la place de la Concentration (de l XP de carte, rien qui touche le
	# terrain). Elle est deja au livre (deck de lvl_19) : seul le deck la met
	# dans le pool de montee de ce niveau.
	lvl21.exploration_deck = _deck([
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/frost_rain.tres", 3],
		[C + "rare/meteor.tres", 1],
		[C + "rare/purifying_light.tres", 1],
		[C + "legendary/meteor_storm.tres", 1],
	])
	_poser_progression(lvl21)
	# LE PORTAIL DE L ACTE 4, et le seul. Le document (section 6) veut les quatre
	# grands demons ouverts d emblee : c est le pentacle de Tombol qui les ouvre,
	# puisque c est par lui qu on descend.
	#
	# CHANTIER N3 — LES QUATRE SONT `lvl_07`, `lvl_10`, `lvl_11` ET `lvl_12`, pas
	# `lvl_10..13`. Deux corrections a la liste ecrite d avance :
	#
	#   `lvl_07` EXISTAIT DEJA et porte le quatrieme demon (la forge de Vharn) —
	#   il etait l unique niveau de l acte 4 avant ce chantier, et l oublier ici
	#   l aurait laisse grise a vie alors qu il est ecrit et mesure au banc.
	#
	#   `lvl_13` EST LE PENTACLE BRISE, c est-a-dire le CINQUIEME niveau, celui
	#   qui clot l acte. Le document est explicite : « Le cinquieme ne s ouvre
	#   qu apres les quatre. » L ouvrir ici donnerait au joueur la fin de l acte
	#   avant ses epreuves. Ce sont les quatre demons qui le citent, chacun dans
	#   son propre `next_levels`.
	lvl21.next_levels = [&"lvl_07", &"lvl_10", &"lvl_11", &"lvl_12"]
	lvl21.act = 3
	lvl21.subtitle = "Il ne fuyait pas devant toi"
	lvl21.intro_text = "Au fond de Tombol, une salle et un pentacle qui tourne. Le \
Roi squelette est accule contre lui et il ne se bat pas : il te dit qu il a signe pour \
SAUVER son royaume, et que ce qui monte de ce puits ne negocie pas. L adversaire de \
cette salle n est pas le roi. C est le sceau."
	lvl21.outro_text = "Le sceau se fend et ce qui passe au travers n a pas d yeux, \
et sait pourtant exactement ou tout le monde se tient. Ils savent que tu as recule le \
temps : tout le monde, en bas, le sait. C est pour CA qu ils avancent si vite \
maintenant. Tu n as pas change la fin, tu as change la date. Le roi demande une place \
dans le groupe : il n a plus de royaume a perdre. On descend."
	_save(lvl21, "res://resources/levels/lvl_21.tres")


## =====================================================================
## ACTE 4, SUITE — LE MONDE DEMONIAQUE  (chantier N3)
##
## `docs/histoire.md` section 6 decrit CINQ niveaux, et le jeu n en avait qu un
## (`lvl_07`). Ces quatre le completent.
##
## LA STRUCTURE EST LA PARTICULARITE DE CET ACTE, et elle vient mot pour mot du
## testeur : « vous avez acces aux 4 niveaux des le debut ; une fois les 4
## realises vous brisez le pentacle ». C est le SEUL acte non lineaire du jeu.
##
## COMMENT ON L OBTIENT SANS TOUCHER AU CODE : `LevelDef.next_levels` est une
## LISTE, et `SaveData.record_victory()` appelle `unlock_level()` pour chacune de
## ses entrees. Il suffit donc que la fin de l acte 3 cite les quatre demons dans
## son `next_levels`, et que chacun des quatre cite le pentacle. Le joueur qui
## finit n importe lequel des quatre voit le pentacle s ouvrir... mais il ne
## pourra le TERMINER qu apres les autres, parce que c est lui qui rend la main a
## l acte 5 et que les trois autres restent sur sa carte. Verifie par
## `tests/unit/test_campaign_acts.gd`, qui refuse qu un demon conditionne un
## autre demon.
##
## LA CARTE DE CAMPAGNE LE SUPPORTE DEJA, et c est verifie avant d ecrire :
## `campaign_map.gd` pose un point par niveau de l acte, ordonne par IDENTIFIANT
## et non par `next_levels` — elle ne dessine aucune fleche entre les points.
## Un acte en eventail s y affiche donc comme une colonne de cinq points tous
## allumes, ce qui est exactement la lecture voulue. L acte 2 ouvrait deja deux
## branches d un coup (`lvl_04` -> `lvl_05` + `lvl_06`) sans que rien ne casse.
##
## POURQUOI LE PENTACLE EST `lvl_13` ET NON `lvl_10` : la carte trie les points
## de l acte par identifiant. Le closeur doit donc porter le plus GRAND numero de
## l acte, sinon il s afficherait au-dessus des quatre demons qu il est censé
## suivre. C est le seul endroit ou la decision de ne pas renumeroter coute
## quelque chose, et elle le coute ici, une fois.
##
## CE QUE JE N AI PAS PU FAIRE, et il faut le dire : le catalogue ne comptait
## plus qu UN boss libre pour SEPT niveaux a ecrire. Les quatre grands demons
## sont donc des tetes NEUVES (voir la section CHANTIER N3 de `_enemies()`), et
## elles partagent la silhouette de la famille qu elles commandent plutot que
## d ouvrir cinq feuilles d animation — les neuf silhouettes orphelines du
## catalogue etant prises par le chantier des actes 2 et 3.
## =====================================================================
func _acte_4_suite(C: String, E: String) -> void:

	# ---------- lvl_10 : Sesh, la Faim ----------
	#
	# Document : « fosses, tout se mange », `glutton`, `jelly`, `hive`.
	#
	# LE NIVEAU OU LE TERRAIN SE MANGE LUI-MEME. Toute la composition est faite de
	# monstres qui se multiplient ou qui devorent : la Gelee se divise, la Ruche
	# eclate, le Glouton gobe les deux. Un joueur qui nettoie mal ne laisse pas
	# des survivants, il laisse de la NOURRITURE, et Sesh arrive au bout.
	#
	# C est le plus simple des quatre demons a lire, donc celui qu on suppose joue
	# en premier par la plupart des joueurs — mais rien ne l impose, et c est tout
	# l interet de l eventail.

	var s1 := WaveDef.new()
	s1.id = &"w10_1"
	s1.duration = 26.0
	s1.difficulty = 1.30
	s1.entries = [
		_entry(E + "jelly.tres", 2, 2.8),
		_entry(E + "hopper.tres", 3, 2.0, 9.0),
	]
	_save(s1, "res://resources/waves/w10_1.tres")

	var s2 := WaveDef.new()
	s2.id = &"w10_2"
	s2.duration = 28.0
	s2.difficulty = 1.35
	# Le Glouton entre en VAGUE NORMALE, pas en tete : le joueur doit voir la
	# mecanique de son seigneur a petite echelle avant de l affronter en grand.
	s2.entries = [
		_entry(E + "glutton.tres", 1, 1.0),
		_entry(E + "hive.tres", 1, 2.5, 8.0),
		_entry(E + "mushroom.tres", 3, 2.2, 16.0),
	]
	_save(s2, "res://resources/waves/w10_2.tres")

	var s3 := WaveDef.new()
	s3.id = &"w10_3_miniboss"
	s3.duration = 32.0
	s3.difficulty = 1.05
	s3.is_miniboss = true
	# LE SLIME DEMONIAQUE mene la vague : il a la silhouette de la Gelee que le
	# joueur brule depuis le premier acte, et il est IMMUNISE AU FEU. Dans un
	# niveau dont toute la lecon est « ca se divise, brule-le », c est le piege
	# parfait — et il se resout en lisant le bestiaire.
	s3.entries = [
		_entry(E + "demon_slime.tres", 1, 1.0),
		_entry(E + "jelly.tres", 2, 2.5, 10.0),
		_entry(E + "carnivore_plant.tres", 3, 1.8, 20.0),
	]
	_save(s3, "res://resources/waves/w10_3_miniboss.tres")

	var s4 := WaveDef.new()
	s4.id = &"w10_4"
	s4.duration = 30.0
	s4.difficulty = 1.45
	# Le dernier palier avant le boss : il monte SANS doubler la vague precedente.
	#
	# CHANTIER W2 — deux Cacodemons a la place de trois Sauterelles : des gueules
	# volantes dans les fosses ou tout se mange. Le Glouton de la meme vague les
	# gobe s il les croise (P3 sous P4) — le joueur qui les laisse vivre nourrit
	# le monstre qu il devra finir, la lecon exacte de Sesh.
	s4.entries = [
		_entry(E + "glutton.tres", 1, 1.0),
		_entry(E + "hive.tres", 1, 2.5, 8.0),
		_entry(E + "jelly.tres", 2, 2.5, 16.0),
		_entry(E + "cacodaemon.tres", 2, 2.4, 22.0),
	]
	_save(s4, "res://resources/waves/w10_4.tres")

	var s5 := WaveDef.new()
	s5.id = &"w10_5_boss"
	s5.duration = 44.0
	s5.difficulty = 1.05
	s5.is_boss = true
	# SESH DEVORE SON PROPRE COUVERT. L escorte est volontairement faite de
	# monstres P1-P2 qu il peut gober : c est la seule facon de montrer la
	# mecanique, et elle transforme l escorte en compte a rebours. Le joueur doit
	# choisir entre nettoyer la vermine et frapper le boss — et les deux sont la
	# bonne reponse au meme moment, ce qui est exactement la tension voulue.
	s5.entries = [
		_entry(E + "demon_maw.tres", 1, 1.0),
		_entry(E + "mushroom.tres", 3, 2.2, 10.0),
		_entry(E + "jelly.tres", 2, 2.5, 22.0),
		_entry(E + "carnivore_plant.tres", 3, 1.8, 32.0),
	]
	_save(s5, "res://resources/waves/w10_5_boss.tres")

	var lvl10 := LevelDef.new()
	lvl10.id = &"lvl_10"
	lvl10.display_name = "Les fosses de Sesh"
	lvl10.terrain = "grass"
	lvl10.backdrop = "act3_demon"
	lvl10.intro_story = &"lvl_10_intro"
	lvl10.outro_story = &"lvl_10_outro"
	lvl10.waves = [s1, s2, s3, s4, s5]
	lvl10.enemy_pool = [
		load(E + "jelly.tres"), load(E + "jelly_mid.tres"), load(E + "jelly_small.tres"),
		load(E + "hive.tres"), load(E + "hopper.tres"), load(E + "glutton.tres"),
		load(E + "mushroom.tres"), load(E + "carnivore_plant.tres"),
		load(E + "demon_slime.tres"), load(E + "demon_maw.tres"),
		load(E + "cacodaemon.tres"),
	]
	# DECK DE ZONE, parce que le niveau est fait de nombre. Mais le Slime
	# demoniaque etant immunise au feu, le deck porte AUSSI du givre et de
	# l arcane : un deck mono-feu gagnerait les quatre premieres vagues et
	# perdrait le mini-boss, ce qui est la lecon. 0 legendaire (elle se gagne).
	# La Volte-face entre ICI : contre une fosse qui deborde, faire remonter tout
	# le monde trois secondes rend le temps de poser la zone suivante.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Volte-face. Sortent le Champ de givre, le Meteore, la Spirale
	# et le Mur ; la Pluie de givre et le Trait montent a 4.
	lvl10.exploration_deck = _deck([
		[C + "common/frost_rain.tres", 4],
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/fireball.tres", 2],
		[C + "epic/resonance.tres", 1],
		[C + "epic/maelstrom.tres", 1],
		[C + "rare/about_face.tres", 1],
	])
	_poser_progression(lvl10)
	# CHACUN DES QUATRE DEMONS MENE AU PENTACLE, et a lui seul. Aucun ne cite un
	# autre demon : c est ce qui rend l ordre libre.
	lvl10.next_levels = [&"lvl_13"]
	lvl10.act = 4
	lvl10.subtitle = "Tout ce que tu laisses vivre, il le mange"
	lvl10.intro_text = "Des fosses tiedes ou le sol remue. Sesh ne commande a rien : \
il a FAIM, et ses sujets sont ce qui n a pas encore ete avale. Ce que tu laisses \
derriere toi ne t attend pas, il le nourrit."
	lvl10.outro_text = "Sesh creve comme une outre, et ce qu il avait avale ressort \
intact et vivant. Sur son flanc, la meme plaque de metal noir que dans la poitrine du \
Gardien. Il n a jamais donne d ordre a personne : il en a recu un."
	_save(lvl10, "res://resources/levels/lvl_10.tres")

	# ---------- lvl_11 : Kaltek, la Chaine ----------
	#
	# Document : « arene, rage et esclaves », `berserker`, `void_knight`.
	#
	# LE NIVEAU QUI PUNIT LA PRECIPITATION. Tout y accelere : les Berserkers
	# s enragent quand on les frappe, Kaltek aussi, et le multiplicateur de
	# vitesse du jeu accelere deja tout le monde. C est le seul niveau ou monter
	# la jauge est un vrai risque, et c est pour ca qu il existe.

	var k1 := WaveDef.new()
	k1.id = &"w11_1"
	k1.duration = 26.0
	k1.difficulty = 1.30
	k1.entries = [
		_entry(E + "berserker.tres", 2, 2.5),
		_entry(E + "hopper.tres", 3, 2.0, 10.0),
	]
	_save(k1, "res://resources/waves/w11_1.tres")

	var k2 := WaveDef.new()
	k2.id = &"w11_2"
	k2.duration = 28.0
	k2.difficulty = 1.35
	# Le Chevalier du vide absorbe le PREMIER coup : dans un niveau qui recompense
	# les gros sorts charges, il apprend a ne pas les gaspiller.
	k2.entries = [
		_entry(E + "void_knight.tres", 2, 2.5),
		_entry(E + "berserker.tres", 2, 2.5, 10.0),
		_entry(E + "sprite.tres", 4, 1.5, 19.0),
	]
	_save(k2, "res://resources/waves/w11_2.tres")

	var k3 := WaveDef.new()
	k3.id = &"w11_3_miniboss"
	k3.duration = 32.0
	k3.difficulty = 1.05
	k3.is_miniboss = true
	# L ECUMEUR DU CIEL, dernier mini-boss libre du catalogue avec le Bourreau.
	# Il VOLE, donc il ignore les murs de l arene : dans un niveau ou tout le reste
	# charge au sol en ligne droite, il est la seule menace qu un mur ne resout
	# pas. C est ce contraste qui lui donne sa place ici plutot qu ailleurs.
	k3.entries = [
		_entry(E + "skyreaver.tres", 1, 1.0),
		_entry(E + "berserker.tres", 2, 2.5, 10.0),
		_entry(E + "wisp.tres", 4, 1.8, 20.0),
	]
	_save(k3, "res://resources/waves/w11_3_miniboss.tres")

	var k4 := WaveDef.new()
	k4.id = &"w11_4"
	k4.duration = 30.0
	k4.difficulty = 1.45
	k4.entries = [
		_entry(E + "void_knight.tres", 2, 2.5),
		_entry(E + "berserker.tres", 3, 2.2, 9.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 20.0),
	]
	_save(k4, "res://resources/waves/w11_4.tres")

	var k5 := WaveDef.new()
	k5.id = &"w11_5_boss"
	k5.duration = 44.0
	k5.difficulty = 1.05
	k5.is_boss = true
	# KALTEK INVOQUE DEJA SES ESCLAVES : l escorte ecrite reste donc LEGERE, sinon
	# la vague cumulerait deux sources de corps et depasserait le double de PV de
	# la vague precedente. C est le piege exact que le chantier d equilibrage avait
	# releve sur `w7_4` (ruches + nuees = 23 corps).
	k5.entries = [
		_entry(E + "demon_chain.tres", 1, 1.0),
		_entry(E + "void_knight.tres", 2, 2.5, 12.0),
		_entry(E + "sprite.tres", 4, 1.5, 28.0),
	]
	_save(k5, "res://resources/waves/w11_5_boss.tres")

	var lvl11 := LevelDef.new()
	lvl11.id = &"lvl_11"
	lvl11.display_name = "L arene de Kaltek"
	lvl11.terrain = "grass"
	lvl11.backdrop = "act3_demon"
	lvl11.intro_story = &"lvl_11_intro"
	lvl11.outro_story = &"lvl_11_outro"
	lvl11.waves = [k1, k2, k3, k4, k5]
	lvl11.enemy_pool = [
		load(E + "berserker.tres"), load(E + "void_knight.tres"),
		load(E + "hopper.tres"), load(E + "sprite.tres"), load(E + "wisp.tres"),
		load(E + "rat_swarm.tres"),
		load(E + "skyreaver.tres"), load(E + "demon_chain.tres"),
	]
	# DECK DE CONTROLE, et c est la reponse que le niveau recompense : on ne bat
	# pas la rage en frappant plus fort, on la FREINE. Givre et entrave portent
	# pleinement sur Kaltek (c est le seul boss du jeu qu on peut reellement
	# ralentir).
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Entrave temporelle et Gel profond. Sortent le Mur, le Meteore,
	# la Concentration et la Faille temporelle (la legendaire se gagne) ; la
	# Fleche monte a 4 et porte les degats.
	lvl11.exploration_deck = _deck([
		[C + "common/piercing_arrow.tres", 3],
		[C + "common/frost_field.tres", 3],
		[C + "common/frost_rain.tres", 2],
		[C + "common/fireball.tres", 1],
		[C + "rare/temporal_drag.tres", 1],
		[C + "epic/deep_freeze.tres", 2],
	])
	_poser_progression(lvl11)
	lvl11.next_levels = [&"lvl_13"]
	lvl11.act = 4
	lvl11.subtitle = "Plus tu frappes, plus vite il vient"
	lvl11.intro_text = "Une arene de sable noir, et des chaines partout : Kaltek ne \
tient pas ses esclaves, il les FABRIQUE. Chaque coup que tu lui rends le rend plus \
rapide. Ici, aller vite est une erreur — c est le seul niveau qui te le dira."
	lvl11.outro_text = "Kaltek tombe au milieu de ses propres chaines, et elles ne \
tenaient rien : elles PARTAIENT de lui, vers le haut. Lui aussi etait tenu. Un \
seigneur de la rage qui obeit, ca n a plus de nom."
	_save(lvl11, "res://resources/levels/lvl_11.tres")

	# ---------- lvl_12 : Ymoa, le Cercle ----------
	#
	# Document : « temple, auras et protections », `totem_guardian`, `ghoul_priest`.
	#
	# LE NIVEAU DE LA CIBLE JUSTE. Rien n y meurt tant qu on frappe la mauvaise
	# chose : les Totems rendent leurs voisins invulnerables, les Pretres goules
	# soignent, et Ymoa fait les deux depuis le fond du terrain. C est le seul des
	# quatre demons qu on ne peut PAS attendre sur sa ligne de defense.

	var y1 := WaveDef.new()
	y1.id = &"w12_1"
	y1.duration = 26.0
	y1.difficulty = 1.30
	# Un SEUL totem pour ouvrir : le joueur doit voir l aura s allumer sur ses
	# voisins et comprendre la regle avant qu elle se multiplie.
	y1.entries = [
		_entry(E + "totem_guardian.tres", 1, 1.0),
		_entry(E + "gnome.tres", 4, 1.8, 8.0),
	]
	_save(y1, "res://resources/waves/w12_1.tres")

	var y2 := WaveDef.new()
	y2.id = &"w12_2"
	y2.duration = 28.0
	y2.difficulty = 1.35
	# Aura ET soin dans la meme vague : deux raisons differentes pour lesquelles
	# la cible evidente ne meurt pas.
	y2.entries = [
		_entry(E + "ghoul_priest.tres", 2, 2.5),
		_entry(E + "totem_guardian.tres", 1, 1.0, 10.0),
		_entry(E + "shade.tres", 3, 2.0, 18.0),
	]
	_save(y2, "res://resources/waves/w12_2.tres")

	var y3 := WaveDef.new()
	y3.id = &"w12_3"
	y3.duration = 32.0
	y3.difficulty = 1.40
	# (CHANTIER W2 : le niveau a desormais son mini-boss, les Jumeaux du Cercle en
	# w12_4. La note qui suit explique pourquoi cette vague-ci s en passait.)
	#
	# PAS DE MINI-BOSS DANS CE NIVEAU, ET C EST UNE CONTRAINTE SUBIE, pas un
	# choix : le catalogue est EPUISE. Les huit mini-boss et les treize boss du
	# jeu mènent deja un niveau chacun (`test_bosses` interdit qu un adversaire en
	# mène deux), et les vingt-et-un niveaux de la campagne en consomment plus que
	# le bestiaire n en compte. Le Bourreau, seul candidat qui restait quand ce
	# niveau a ete ecrit, ferme desormais `lvl_06`.
	#
	# CE QUE JE METS A LA PLACE, et pourquoi ca tient quand meme : la vague porte
	# DEUX porteurs d aura et DEUX soigneurs, ce qui est le seul endroit du jeu ou
	# cette combinaison existe. Rien ne meurt tant que le joueur n a pas coupe les
	# quatre soutiens dans le bon ordre — c est une question de mini-boss posee par
	# une vague ordinaire, et elle sert exactement la lecon du temple.
	y3.entries = [
		_entry(E + "totem_elder.tres", 1, 1.0),
		_entry(E + "totem_guardian.tres", 1, 1.0, 10.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 18.0),
		_entry(E + "golem.tres", 2, 2.5, 26.0),
	]
	_save(y3, "res://resources/waves/w12_3.tres")

	var y4 := WaveDef.new()
	y4.id = &"w12_4_miniboss"
	y4.duration = 32.0
	y4.difficulty = 1.10
	y4.is_miniboss = true
	# LA VAGUE LA PLUS FERMEE DU NIVEAU, et celle qui prepare litteralement le
	# boss : une aura posee devant du BLINDAGE. La vague precedente demandait de
	# couper quatre soutiens ; celle-ci en laisse un seul, mais ce qu il protege
	# est un Behemoth de 130 PV. Le joueur ne peut plus etaler ses sorts, il doit
	# choisir l ordre — exactement ce qu Ymoa lui demandera depuis le fond du
	# terrain.
	#
	# CHANTIER W2 — LES JUMEAUX DU CERCLE prennent la place du Behemoth et font de
	# la vague le palier qui manquait au temple. Ce qu elle demandait reste vrai et
	# devient plus aigu : l aura du Totem couvre deux diablotins qui se RELEVENT
	# l un l autre tant que l autre tient debout. Le joueur doit couper le Totem,
	# puis frapper les deux ensemble — deux protections superposees, le propos
	# d Ymoa. Difficulte de palier (1,10) : la paire et ses retours sont le poids.
	y4.entries = [
		_entry(E + "circle_twins.tres", 1, 1.2),
		_entry(E + "totem_guardian.tres", 1, 1.0, 6.0),
		_entry(E + "shade.tres", 2, 2.0, 20.0),
	]
	_save(y4, "res://resources/waves/w12_4_miniboss.tres")

	var y5 := WaveDef.new()
	y5.id = &"w12_5_boss"
	y5.duration = 46.0
	y5.difficulty = 1.05
	y5.is_boss = true
	# YMOA CAMPE A 480 PX ET PROTEGE CE QUI L ENTOURE. L escorte doit donc rester
	# DANS son cercle pour que la mecanique se lise : des monstres lents, qui
	# descendent avec lui et non devant lui. Un escadron rapide sortirait de l aura
	# immediatement et le boss n aurait plus de mecanique visible.
	y5.entries = [
		_entry(E + "demon_circle.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 2.8, 10.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 22.0),
		_entry(E + "shade.tres", 3, 2.0, 34.0),
	]
	_save(y5, "res://resources/waves/w12_5_boss.tres")

	var lvl12 := LevelDef.new()
	lvl12.id = &"lvl_12"
	lvl12.display_name = "Le temple d Ymoa"
	lvl12.terrain = "sand"
	lvl12.backdrop = "act3_demon"
	lvl12.intro_story = &"lvl_12_intro"
	lvl12.outro_story = &"lvl_12_outro"
	lvl12.waves = [y1, y2, y3, y4, y5]
	lvl12.enemy_pool = [
		load(E + "totem_guardian.tres"), load(E + "totem_elder.tres"),
		load(E + "ghoul_priest.tres"), load(E + "golem.tres"),
		load(E + "shade.tres"), load(E + "gnome.tres"),
		load(E + "behemoth.tres"), load(E + "demon_circle.tres"),
		load(E + "circle_twins.tres"),
	]
	# DECK DE PORTEE ET DE PERCEE. Le boss campe au fond : il faut des cartes qui
	# vont LOIN (Fleche percante, Meteore) et de l arcane, qui fend le cristal.
	# La Focalisation et la Concentration sont la pour le coup unique qui atteint
	# le protecteur : c est le niveau ou le mono-cible lourd est enfin la reponse.
	# L Intuition arcanique entre ICI : piocher trois cartes, c est reunir plus vite la
	# Focalisation et le Meteore qui doivent partir ensemble.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Intuition arcanique. Sortent la Boule de feu, le Mur et la Marque.
	#
	# DISSIPATION (chantier W9) : quatre vagues de Gardiens-totems puis Ymoa, dont
	# l aura protege tout le cercle, et aucune carte pour la couper. Le Vide
	# d emprise (« efface rage, boucliers et auras ») prend la place de la
	# Concentration, qui depuis la vague 8 ne donne que de l XP de carte : ce
	# n est plus le coup unique dont parle le paragraphe ci-dessus. Il est deja au
	# livre (decks de lvl_06, lvl_07, lvl_20) : seul le deck le met dans le pool
	# de montee de ce niveau.
	lvl12.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/piercing_arrow.tres", 1],
		[C + "rare/meteor.tres", 2],
		[C + "rare/focus.tres", 3],
		[C + "epic/void_grip.tres", 1],
		[C + "epic/arcane_insight.tres", 1],
	])
	_poser_progression(lvl12)
	lvl12.next_levels = [&"lvl_13"]
	lvl12.act = 4
	lvl12.subtitle = "Rien ne meurt tant que le cercle tient"
	lvl12.intro_text = "Un temple de cristal ou tout est protege par autre chose. \
Ymoa ne descendra pas : il reste au fond et tient son cercle. Tant qu il vit, ce que \
tu frappes ne sent rien. Va le chercher."
	lvl12.outro_text = "Le cercle s eteint et tout ce qu il protegeait meurt d un \
coup, sans etre touche. Ymoa n avait jamais rien commande non plus : il PROTEGEAIT \
l ordre de quelqu un d autre, et il ne savait pas de qui."
	_save(lvl12, "res://resources/levels/lvl_12.tres")

	# ---------- lvl_13 : le pentacle brise ----------
	#
	# Document, section 6 : « apres les 4, le sol se derobe », « melange des
	# quatre ». C est la FIN DE L ACTE 4 et la charniere du jeu : le mage a battu
	# quatre seigneurs pour decouvrir qu aucun des quatre n avait donne l ordre.
	#
	# LE NIVEAU EST UN RESUME, et c est son role : chaque vague cite un des quatre
	# demons par sa famille, dans l ordre ou ils apparaissent sur la carte. Un
	# joueur qui a tout joue reconnait les quatre epreuves ; un joueur qui les a
	# faites dans un autre ordre les reconnait aussi, puisque c est la FAMILLE qui
	# parle, pas le numero.
	#
	# LA REINE GORGONE LE FERME, et c est le dernier boss libre du catalogue. Son
	# regard petrifie TROIS cartes de la main : le niveau qui precede l acte 5
	# enleve au joueur la moitie de ses options, ce qui est exactement la
	# sensation que le document demande — « on nous RETIRE. Comme on retire une
	# piece du plateau. » Elle annonce aussi la mecanique du boss final, qui
	# petrifie lui aussi : le joueur doit l avoir vue une fois avant la derniere
	# vague du jeu.
	#
	# CHANTIER W2 — MALYK FERME LE PENTACLE, LA REINE MENE SON PALIER. La Reine
	# tenait la place du boss faute de tete (« le dernier boss libre du
	# catalogue ») ; le Seigneur demon est celui que la scene attend sans le
	# nommer — « aucun des quatre n a lu l ordre, ils l ont RECU ». Elle ne quitte
	# pas le niveau : elle prend la tete de w13_3, qui etait deja la vague du
	# Regard, et ce qui est ecrit plus haut reste vrai — le joueur voit la
	# petrification a trois cartes avant l Enfant.

	var p1 := WaveDef.new()
	p1.id = &"w13_1"
	p1.duration = 27.0
	p1.difficulty = 1.35
	# Citation de VHARN, et son ECHO : le blindage, puis l ombre de son seigneur.
	# CHANTIER W4 — les seigneurs eux-memes ne descendent plus dans les vagues de
	# troupes (voir `demon_anvil_echo` et test_bosses) : ils ne comptent plus que
	# dans leur propre vague de boss, qui les tient dans le monde de l acte 4.
	p1.entries = [
		_entry(E + "golem.tres", 2, 2.5),
		_entry(E + "demon_anvil_echo.tres", 1, 1.0, 12.0),
		_entry(E + "behemoth.tres", 1, 1.0, 22.0),
	]
	_save(p1, "res://resources/waves/w13_1.tres")

	var p2 := WaveDef.new()
	p2.id = &"w13_2"
	p2.duration = 28.0
	p2.difficulty = 1.40
	# Citation de SESH, et son ECHO : le nombre qui se mange, et la gueule
	# qui le mange. Il gobe sa propre escorte de gelees sous les yeux du joueur.
	p2.entries = [
		_entry(E + "demon_maw_echo.tres", 1, 1.0),
		_entry(E + "hive.tres", 2, 2.5, 12.0),
		_entry(E + "jelly.tres", 2, 2.5, 20.0),
		_entry(E + "glutton.tres", 1, 1.0, 24.0),
	]
	_save(p2, "res://resources/waves/w13_2.tres")

	var p3 := WaveDef.new()
	p3.id = &"w13_3_miniboss"
	p3.duration = 36.0
	p3.difficulty = 1.10
	p3.is_miniboss = true
	# Citation de KALTEK : la rage et le blindage ensemble.
	#
	# PAS DE MINI-BOSS ICI NON PLUS, meme cause qu au temple d Ymoa : le catalogue
	# est epuise et la Matrone gorgone ferme deja `lvl_02`. Ce niveau garde en
	# revanche SON boss (la Reine gorgone), donc il n est pas prive de tete
	# d affiche — il est prive de son palier intermediaire.
	#
	# LE REGARD PETRIFIANT RESTE, porte par les REGARDS GORGONES, qui sont des P3
	# communs et bloquent UNE carte chacun. Trois d entre eux valent la Matrone en
	# effet (trois cartes bloquees) sans usurper sa place de mini-boss, et ils
	# preparent la Reine exactement comme il faut : le joueur apprend la mecanique
	# sur des cibles fragiles avant de la subir d un boss.
	#
	# CHANTIER W2 — LE PALIER EXISTE ENFIN, et c est la Reine qui le mene. Les
	# trois Regards de l ancienne vague etaient sa doublure : la Reine gele a elle
	# seule les trois cartes qu ils gelaient a trois. On garde UN Regard pour que
	# la lignee se lise (le petit sous la grande), et l escorte perd un Berserker
	# et un Chevalier pour que la vague ne pese pas la Reine EN PLUS de ce qu elle
	# pesait. Difficulte de palier (1,10).
	p3.entries = [
		_entry(E + "gorgon_queen.tres", 1, 1.0),
		_entry(E + "gorgon_gazer.tres", 1, 2.2, 8.0),
		_entry(E + "berserker.tres", 2, 2.2, 12.0),
		_entry(E + "void_knight.tres", 1, 2.5, 24.0),
	]
	_save(p3, "res://resources/waves/w13_3_miniboss.tres")

	var p4 := WaveDef.new()
	p4.id = &"w13_4"
	p4.duration = 31.0
	# 1,45 -> 1,25 (incantations plus longues, GameConfig.CAST_TIME_SCALE) : a
	# 1,45 cette vague pesait 879 PV joues apres les 385 de w13_3, un saut x2,28,
	# et c etait la vague de TOUTES les defaites du niveau (26 sur 26 au banc).
	# Le pentacle est limite par la PIOCHE, pas par l incantation : le mage a la
	# main vide quasiment chaque fois qu il n incante pas (Trait et Etincelle
	# partent vite), donc rallonger les sorts ne changeait presque rien
	# (34/60 a x1,8 comme a x2,25) et la vague demandait plus de cartes que la
	# pioche n en donne en 31 s. A 1,25 elle vaut 758 PV, x1,97 : sous la regle
	# du saut x2, verrouillee pour ce niveau dans test_balance. Banc (60 parties) :
	# 34 -> 43 victoires a x1,8, 29 -> 37 a x1,9 (le reglage retenu). Essai rejete :
	# retirer le Totem ancien (mini-boss, 175 PV) de la vague ne changeait rien
	# (34/60) — ce sont les Berserkers et les echos de Kaltek qui touchent, pas lui.
	p4.difficulty = 1.25
	# LE MELANGE DES QUATRE, litteralement : le document (section 6) decrit ce
	# niveau comme « melange des quatre », et cette vague est l endroit ou les
	# seigneurs reviennent. Ymoa et Kaltek descendent ensemble, l aura de l un
	# protegeant la rage de l autre.
	#
	# CHANTIER W4 — en ECHOS. Avec leurs PV de boss a difficulte 1,45, cette vague
	# faisait perdre 56 % des parties du niveau (banc, 90 parties). Le paragraphe
	# qui suit explique pourquoi ils etaient ici ; la raison mecanique ne tient
	# plus : chaque seigneur reste dans le monde de l acte 4 par sa propre vague
	# de boss, et ce sont leurs echos qui comptent ici.
	#
	# POURQUOI ILS SONT ICI ET PAS SEULEMENT DANS LEURS PROPRES NIVEAUX. Deux
	# raisons, et la seconde est mecanique.
	#
	#   Narrativement, le pentacle brise est le moment ou les quatre contrats se
	#   rejoignent : les voir cote a cote est ce qui fait comprendre qu ils n ont
	#   jamais travaille ensemble.
	#
	#   Mecaniquement, `WaveSpawner.build_membership()` rattache un monstre au
	#   monde de l acte ou il est le plus DENSE, et la densite est normalisee par
	#   le volume de l acte. Les quatre demons n apparaissaient qu une fois chacun,
	#   dans leur vague de boss, et l acte 5 — trois niveaux, donc un petit volume
	#   — les captait tous par sa seule citation finale. Resultat mesure : NEUF
	#   boss dans le monde 4 et aucun dans le monde demoniaque, et `pick_boss()`
	#   n en tirait plus qu un sur neuf. Leur donner leur vraie place dans leur
	#   propre acte remet chaque seigneur dans son monde de Massacre.
	p4.entries = [
		_entry(E + "demon_circle_echo.tres", 1, 1.0),
		# Deux echos de Kaltek : voir la mesure au-dessus de `demon_chain_echo`.
		_entry(E + "demon_chain_echo.tres", 2, 1.0, 12.0),
		_entry(E + "totem_elder.tres", 1, 1.0, 18.0),
		_entry(E + "berserker.tres", 3, 2.2, 8.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 24.0),
		_entry(E + "shade.tres", 3, 2.0, 30.0),
	]
	_save(p4, "res://resources/waves/w13_4.tres")

	var p5 := WaveDef.new()
	p5.id = &"w13_5_boss"
	p5.duration = 50.0
	p5.difficulty = 1.05
	p5.is_boss = true
	# MALYK, LE SEIGNEUR DEMON (chantier W2), a la place de la Reine gorgone, qui
	# mene desormais le palier w13_3. Une escorte melangee des quatre familles :
	# c est le pentacle qui se fend, donc les quatre mondes arrivent ensemble.
	#
	# Il appelle ses Cacodemons et les MANGE pour se soigner : l escorte ecrite ne
	# change pas, c est lui qui ajoute ses propres corps. Les Golems (P3, lents)
	# restent hors de portee de sa gueule le temps qu il les rattrape — il gobe ce
	# qui est plus faible que lui, et c est aussi une facon de lire le personnage.
	p5.entries = [
		_entry(E + "demon_lord.tres", 1, 1.0),
		_entry(E + "golem.tres", 2, 2.8, 12.0),
		_entry(E + "berserker.tres", 2, 2.5, 26.0),
		_entry(E + "hive.tres", 1, 2.5, 38.0),
	]
	_save(p5, "res://resources/waves/w13_5_boss.tres")

	var lvl13 := LevelDef.new()
	lvl13.id = &"lvl_13"
	lvl13.display_name = "Le pentacle brise"
	lvl13.terrain = "sand"
	lvl13.backdrop = "act3_demon"
	lvl13.intro_story = &"lvl_13_intro"
	lvl13.outro_story = &"lvl_13_outro"
	lvl13.waves = [p1, p2, p3, p4, p5]
	lvl13.enemy_pool = [
		load(E + "golem.tres"), load(E + "behemoth.tres"), load(E + "glutton.tres"),
		load(E + "hive.tres"), load(E + "jelly.tres"), load(E + "berserker.tres"),
		load(E + "void_knight.tres"), load(E + "totem_elder.tres"),
		load(E + "totem_guardian.tres"), load(E + "ghoul_priest.tres"),
		load(E + "shade.tres"),
		load(E + "gorgon_gazer.tres"), load(E + "gorgon_queen.tres"),
		load(E + "demon_lord.tres"), load(E + "cacodaemon.tres"),
		# Les ECHOS des quatre seigneurs, qui reviennent dans les vagues du
		# pentacle (chantier W4 : plus les seigneurs eux-memes, voir w13_4).
		load(E + "demon_anvil_echo.tres"), load(E + "demon_maw_echo.tres"),
		load(E + "demon_chain_echo.tres"), load(E + "demon_circle_echo.tres"),
	]
	# DECK DE SYNTHESE DE L ACTE : il doit repondre aux quatre registres, donc il
	# n excelle dans aucun. C est voulu : le joueur qui veut mieux doit avoir
	# gagne ses legendaires sur les quatre demons.
	# L Etincelle entre ICI : la foudre est neutre sur ce bestiaire, et un sort
	# rapide acheve ce que la Boule de feu laisse debout.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Etincelle. Sortent la Fleche, le Champ de givre, le Mur, la
	# Focalisation, la Resonance et la Concentration.
	# Vague 8, deck de 12 : le Trait (arcane, x1,36 ici) garde ses 4 exemplaires et
	# la Marque en perd un. Au banc (60 parties, incantations x2,25) : 25 victoires
	# avec Trait 3 / Marque 2, 34 avec Trait 4 / Marque 1.
	#
	# DISSIPATION (chantier W9) : l Echo d Ymoa descend dans w13_4, la vague la
	# plus dure du niveau, et son aura couvre la vague ; le deck n avait aucune
	# carte pour la couper. Le Vide d emprise prend la place de la derniere
	# Marque (qu il valait deja mieux retirer, mesure ci-dessus). Deja au livre
	# (decks de lvl_06, lvl_07, lvl_20) : seul le deck le met dans le pool.
	lvl13.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/fireball.tres", 2],
		[C + "common/spark.tres", 3],
		[C + "rare/meteor.tres", 1],
		[C + "epic/void_grip.tres", 1],
		[C + "legendary/hourglass_shard.tres", 1],
	])
	_poser_progression(lvl13)
	# LA SORTIE DE L ACTE 4 : l espace divin. Un seul niveau de l acte 4 ouvre
	# l acte 5, et c est celui-la.
	lvl13.next_levels = [&"lvl_14"]
	lvl13.act = 4
	lvl13.subtitle = "Quatre contrats, pas une signature en commun"
	lvl13.intro_text = "Quatre seigneurs tombes, quatre contrats, et aucun des quatre \
n avait lu l ordre : ils l ont RECU. Le pentacle qui tient ce monde est au centre de \
la salle, et il n a jamais ete a eux."
	lvl13.outro_text = "Le pentacle se fend en cinq morceaux et le monde avec lui. Ce \
n est pas toi qui l as casse : on te RETIRE, comme une piece qu on ote du plateau. \
L enfant te tient la main, et sa main est froide comme le puits. La chute ne va pas \
vers le bas."
	_save(lvl13, "res://resources/levels/lvl_13.tres")


## =====================================================================
## ACTE 5 — L ESPACE DIVIN  (chantier N3)
##
## `docs/histoire.md` section 7. TROIS niveaux, et ils ferment le jeu. Cet acte
## n avait AUCUN niveau : la page de l acte 5 sur la carte de campagne affichait
## « Le voyage ne va pas encore jusqu ici », et le fond `act5_divine.png`, qui
## existe sur le disque depuis le chantier des fonds, n avait jamais ete montre a
## personne.
##
## LE PROPOS DE L ACTE EST UNE REGLE MECANIQUE, pas une ambiance. Le document
## l ecrit noir sur blanc : « Les anciens boss redeviennent des monstres
## ordinaires. `warden` et `chronos` apparaissent en vagues normales : ce qui
## etait un evenement devient de la vermine, et c est exactement le propos. » On
## le fait donc VRAIMENT — le Gardien de la foret, qui fermait l acte 1 et dont
## la mort lance toute l intrigue, descend ici a trois exemplaires dans une vague
## sans nom. Le joueur qui a sue devant lui au niveau 4 le voit arriver par
## paquets, et c est tout le discours de l acte en une seconde.
##
## LE PIEGE QU IL FALLAIT EVITER : `test_bosses` interdit au Gardien de MENER une
## vague de boss ou de mini-boss apres l acte 1 (il est mort, et sa mort est un
## point d intrigue). La regle et le document ne se contredisent pas — ils disent
## la meme chose par deux bouts : il ne revient pas comme EVENEMENT, il revient
## comme VERMINE. Aucune des vagues ou il figure ici ne porte `is_boss` ni
## `is_miniboss`, et `tests/unit/test_campaign_acts.gd` verrouille desormais les
## deux moities de cette regle.
##
## CHANTIER W3 — DE LA VERMINE, PAS DES BOSS. Le premier jet envoyait les .tres
## des boss EUX-MEMES dans ces vagues, donc avec leurs PV et leur contact de boss :
## trois Gardiens a 140 PV dans une vague de troupes, un Chronos a 320. Ce n etait
## pas une decheance, c etait un mur (`lvl_16` a 5 victoires sur 30, mort en
## vague 1 ou 2). Ils descendent desormais en ECHOS (`warden_echo`,
## `chronos_echo`) : des .tres derives, un tiers des PV environ, la mecanique
## simplifiee, et `EnemyDef.demoted_from` qui dit de qui ils sont l echo. C est ce
## champ que test_campaign_acts lit pour reconnaitre un ancien boss, et que
## test_bosses compare a la version boss.
##
## POURQUOI AUCUN MONSTRE NEUF DANS CET ACTE. Le document, section 10 : « Aucun
## nouveau type de monstre. » C est l acte ou cette contrainte devient une force :
## un espace divin peuple de creatures INEDITES dirait « voici un nouveau lieu »,
## alors que le propos est « tout revient, plus rien n impressionne ». Le seul
## ajout est la tete du boss final, parce qu un boss final ne peut pas etre un
## monstre commun agrandi.
## =====================================================================
func _acte_5(C: String, E: String) -> void:

	# ---------- lvl_14 : La galerie des saisons ----------
	#
	# Document : « ce qui a deja ete efface, expose », melange acte 1 + 2, et
	# `warden` en vague normale — sous la forme de son ECHO (`warden_echo`, chantier
	# W3), jamais le .tres du mini-boss avec ses PV de mini-boss.
	#
	# LE NIVEAU EST UN MUSEE DE CE QUE LE JOUEUR A TUE. Il rejoue la vermine du
	# premier acte — gnomes, lutins, gelees, nuees — mais en quantites que
	# l acte 1 n aurait jamais osees, et avec le Gardien dedans comme piece
	# exposee. Rien n est neuf, tout est plus grand : c est la definition du
	# « plus rien n impressionne » demande par le document.

	var g1 := WaveDef.new()
	g1.id = &"w14_1"
	g1.duration = 27.0
	g1.difficulty = 1.40
	# La toute premiere vague du jeu, citee mot pour mot (gnomes et lutins), mais
	# au double du nombre. Le joueur doit reconnaitre la vitrine.
	#
	# CHANTIER W2 — deux Renards dormeurs a la place de deux Sauterelles : la
	# foret de Nuri exposee avec ses betes etranges, celles qui endormaient la
	# magie du mage devant le dirigeable.
	g1.entries = [
		_entry(E + "gnome.tres", 6, 1.6),
		_entry(E + "sprite.tres", 5, 1.4, 9.0),
		_entry(E + "sleepy_fox.tres", 2, 2.4, 16.0),
		_entry(E + "hopper.tres", 1, 1.8, 22.0),
	]
	_save(g1, "res://resources/waves/w14_1.tres")

	var g2 := WaveDef.new()
	g2.id = &"w14_2"
	g2.duration = 29.0
	g2.difficulty = 1.45
	# LE GARDIEN DE LA FORET, EN VAGUE NORMALE. C est la vague qui porte tout le
	# propos de l acte. Il n est PAS en tete d affiche : il arrive au milieu d une
	# vague ordinaire, escorte de la vermine qu il escortait lui-meme autrefois.
	#
	# Ce sont des ECHOS du Gardien (`warden_echo`, voir `_enemies_v3`), pas le
	# .tres du boss : un Gardien avec ses PV de boss dans une vague de troupes
	# etait un mur, pas une decheance. DEUX exemplaires et non trois : le compte
	# date du premier jet, ou chaque Gardien pesait ses PV de boss, et il a ete
	# garde tel quel quand l echo a remplace la piece — voir un SECOND Gardien
	# suffit deja a porter le message.
	g2.entries = [
		_entry(E + "warden_echo.tres", 2, 4.0),
		_entry(E + "rat_swarm.tres", 3, 2.2, 12.0),
		_entry(E + "jelly.tres", 2, 2.5, 20.0),
		_entry(E + "hopper.tres", 4, 1.8, 24.0),
	]
	_save(g2, "res://resources/waves/w14_2.tres")

	var g3 := WaveDef.new()
	g3.id = &"w14_3"
	g3.duration = 34.0
	g3.difficulty = 1.45
	# (CHANTIER W2 : la galerie a desormais un palier, le Cameleon des saisons en
	# w14_4, et un boss, le Slime colossal en w14_6. Le co-auteur a demande de
	# combler les niveaux sans tete ; la note qui suit explique pourquoi ils en
	# etaient prives, et le propos tient toujours — les TROUPES de l acte restent
	# d anciens boss sans titre.)
	#
	# AUCUNE VAGUE DE MINI-BOSS DANS TOUT L ACTE 5, et pour une fois la contrainte
	# et le propos disent la meme chose.
	#
	# LA CONTRAINTE : le catalogue est epuise. Les huit mini-boss du jeu mènent
	# chacun un niveau des actes 1 a 4, et `test_bosses` refuse qu un adversaire en
	# mène deux.
	#
	# LE PROPOS, qui aurait de toute facon impose ce choix : « les anciens boss
	# redeviennent des monstres ordinaires » (docs/histoire.md section 7). Poser un
	# mini-boss dans la galerie reviendrait a redonner un TITRE a quelqu un dans le
	# seul acte dont le sujet est que plus personne n en a. Le Gardien de la foret
	# descend ici par paquets de deux, sans fanfare, dans des vagues sans nom :
	# c est exactement ce que le document demande, et c est plus fort qu une
	# tete d affiche.
	#
	# TROIS GARDIENS dans cette vague, contre deux dans la precedente : la montee
	# se fait par le NOMBRE d anciens boss, ce qui est la seule courbe que cet
	# acte peut avoir.
	g3.entries = [
		_entry(E + "warden_echo.tres", 3, 4.0),
		_entry(E + "hornblower.tres", 2, 2.0, 14.0),
		_entry(E + "rat_swarm.tres", 2, 2.2, 20.0),
		_entry(E + "sprite.tres", 5, 1.4, 26.0),
	]
	_save(g3, "res://resources/waves/w14_3.tres")

	var g4 := WaveDef.new()
	g4.id = &"w14_4_miniboss"
	g4.duration = 33.0
	g4.difficulty = 1.10
	g4.is_miniboss = true
	# Melange acte 1 + acte 2, comme le document le demande : la foret et les Sky
	# Lands dans la meme vitrine.
	#
	# CHANTIER W2 — LE CAMELEON DES SAISONS mene la vague, qui devient le palier
	# de la galerie. Il change d element faible toutes les 5 s dans l ordre des
	# saisons : c est la galerie qui se met a tourner. L escorte perd la Ruche et
	# un Feu follet, et la difficulte descend a celle d un palier.
	g4.entries = [
		_entry(E + "season_chameleon.tres", 1, 1.0),
		_entry(E + "hornblower.tres", 1, 1.0, 4.0),
		_entry(E + "wisp.tres", 3, 1.8, 10.0),
		_entry(E + "imp_archer.tres", 2, 2.0, 18.0),
	]
	_save(g4, "res://resources/waves/w14_4_miniboss.tres")

	var g5 := WaveDef.new()
	g5.id = &"w14_5"
	g5.duration = 33.0
	g5.difficulty = 1.50
	# DERNIERE VAGUE SANS BOSS DU JEU, et c est volontaire : ce niveau n a pas de
	# tete d affiche a la fin. Les divinites ne mettent pas de gardien a la porte
	# d une galerie — elles regardent. Le joueur termine sur une vague ordinaire
	# tres dense, ce qui est plus inquietant qu un boss.
	#
	# (CHANTIER W2 : elle n est plus la derniere, le Slime colossal ferme la
	# galerie. Deux Caillots — le Coagule du niveau 2 en vermine — remplacent les
	# deux nuees : un ancien boss qui se releve encore, sans titre.)
	g5.entries = [
		_entry(E + "warden_echo.tres", 2, 5.0),
		_entry(E + "berserker.tres", 3, 2.5, 12.0),
		_entry(E + "hive.tres", 1, 2.5, 20.0),
		_entry(E + "blood_clot.tres", 2, 2.4, 26.0),
		_entry(E + "sprite.tres", 4, 1.4, 30.0),
	]
	_save(g5, "res://resources/waves/w14_5.tres")

	# CHANTIER W2 — LE SLIME COLOSSAL ferme la galerie des saisons.
	#
	# Le musee de ce que le joueur a tue finit sur la plus grosse piece : toutes
	# les gelees de l acte 1 et les slimes de l acte 2 refondus en une masse sous
	# une croute de lave. Rien n est neuf dans ce qu il fait (se diviser, le joueur
	# le sait depuis le niveau 2) ; tout est plus grand. C est la definition du
	# « plus rien n impressionne » — et pourtant il faut changer d element au
	# milieu du combat, quand la croute cede.
	#
	# Escorte MINIMALE et tardive : il lache lui-meme sept corps en deux temps. Sa
	# chaine pese 402 PV, sous la vague precedente : le palier est la mecanique.
	var g6 := WaveDef.new()
	g6.id = &"w14_6_boss"
	g6.duration = 48.0
	g6.difficulty = 1.0
	g6.is_boss = true
	g6.entries = [
		_entry(E + "slime_colossal.tres", 1, 1.0),
		_entry(E + "hopper.tres", 3, 2.0, 24.0),
	]
	_save(g6, "res://resources/waves/w14_6_boss.tres")

	var lvl14 := LevelDef.new()
	lvl14.id = &"lvl_14"
	lvl14.display_name = "La galerie des saisons"
	lvl14.terrain = "grass"
	# LE FOND DE L ACTE 5, montre pour la premiere fois. Il existait sur le disque
	# sans qu aucun niveau ne le nomme, donc `campaign_map` le tirait de sa table
	# de REPLI et le combat ne l affichait jamais.
	lvl14.backdrop = "act5_divine"
	lvl14.intro_story = &"lvl_14_intro"
	lvl14.outro_story = &"lvl_14_outro"
	lvl14.waves = [g1, g2, g3, g4, g5, g6]
	lvl14.enemy_pool = [
		load(E + "gnome.tres"), load(E + "sprite.tres"), load(E + "hopper.tres"),
		load(E + "rat_swarm.tres"), load(E + "jelly.tres"), load(E + "hive.tres"),
		load(E + "hornblower.tres"), load(E + "wisp.tres"),
		load(E + "imp_archer.tres"), load(E + "berserker.tres"),
		load(E + "warden_echo.tres"), load(E + "sleepy_fox.tres"), load(E + "blood_clot.tres"),
		load(E + "season_chameleon.tres"), load(E + "slime_colossal.tres"),
	]
	# LE DECK DU RETOUR. Il est fait des cartes de l acte 1 : le joueur refait la
	# galerie avec la main qu il avait au premier matin, et il decouvre qu elle
	# suffit — ce qui est le compliment le plus dur que le jeu puisse lui faire.
	# Le Flux de mana entre ICI : il ne change pas la main, il la fait revenir
	# plus vite.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Flux de mana. Sortent le Champ de givre, le Brasier, le Mur et
	# la Resonance.
	lvl14.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 3],
		[C + "common/piercing_arrow.tres", 2],
		[C + "common/fireball.tres", 3],
		[C + "rare/meteor.tres", 2],
		[C + "rare/mana_flow.tres", 1],
		[C + "legendary/hourglass_shard.tres", 1],
	])
	_poser_progression(lvl14)
	lvl14.next_levels = [&"lvl_15"]
	lvl14.act = 5
	lvl14.subtitle = "Ce qui a deja ete efface, expose"
	lvl14.intro_text = "Il n y a pas de sol. Il y a une galerie, et dans la galerie \
tout ce que tu as deja tue, range par saison. Le Gardien de la foret est dans une \
vitrine, et il y en a deux."
	lvl14.outro_text = "Personne n est venu defendre la galerie. On te laisse passer \
d une salle a l autre comme on laisse passer un visiteur. L enfant ne dit plus rien \
depuis le pentacle, et il marche devant."
	_save(lvl14, "res://resources/levels/lvl_14.tres")

	# ---------- lvl_15 : Le registre ----------
	#
	# Document : « colonnes de noms, dont le sien », melange acte 3 + 4, et
	# `chronos` en vague normale.
	#
	# LE NIVEAU OU LE MAGE LIT SA PROPRE LIGNE. La galerie exposait le passe ;
	# le registre expose le CALENDRIER — l extinction etait au programme, a la
	# date prevue, et le nom du mage y figure comme les autres. Chronos, l huissier
	# de la machine, y est un employe parmi d autres : il descend en vague normale,
	# a deux exemplaires.

	var r1 := WaveDef.new()
	r1.id = &"w15_1"
	r1.duration = 28.0
	r1.difficulty = 1.40
	# Melange acte 3 : les morts-vivants de Tombol, en colonne.
	#
	# CHANTIER W2 — deux Adeptes du givre a la place des deux Chevaliers : le trio
	# des fosses de Tombol revient en vermine, un tiers de ses PV, et il zigzague.
	r1.entries = [
		_entry(E + "ghoul_priest.tres", 2, 2.5),
		_entry(E + "adept_frost.tres", 2, 2.5, 10.0),
		_entry(E + "shade.tres", 3, 2.0, 20.0),
	]
	_save(r1, "res://resources/waves/w15_1.tres")

	var r2 := WaveDef.new()
	r2.id = &"w15_2"
	r2.duration = 30.0
	r2.difficulty = 1.45
	# CHRONOS EN VAGUE NORMALE. Le boss du premier niveau ET de l acte 4, celui
	# qu on a affronte deux fois comme un evenement, arrive ici SANS titre, au
	# milieu d une vague, accompagne de vermine.
	#
	# C est l ECHO de Chronos (`chronos_echo`, voir `_enemies_v3`), pas le boss.
	# UN SEUL dans cette vague, un SECOND a la vague 4 : c est la progression qui
	# porte le propos, pas l entassement. Le compte date du premier jet, ou
	# Chronos pesait ses PV de boss, et il a ete garde quand l echo l a remplace.
	r2.entries = [
		_entry(E + "chronos_echo.tres", 1, 1.0),
		_entry(E + "shade.tres", 4, 2.0, 12.0),
		_entry(E + "void_knight.tres", 2, 2.5, 20.0),
		_entry(E + "risen_ghoul.tres", 4, 1.8, 26.0),
	]
	_save(r2, "res://resources/waves/w15_2.tres")

	var r3 := WaveDef.new()
	r3.id = &"w15_3_miniboss"
	r3.duration = 36.0
	r3.difficulty = 1.10
	r3.is_miniboss = true
	# Meme regle que dans la galerie : aucune tete d affiche dans l acte 5 (voir
	# `w14_3` pour l argumentaire complet — le catalogue est epuise ET l acte a
	# pour sujet que plus personne n a de titre).
	#
	# LA GORGONE MATRONE fermait `lvl_02` et le MIROIR DE VERRE ferme `lvl_05` :
	# les deux monstres qui auraient porte cette vague sont pris. Ce sont donc les
	# REGARDS GORGONES, communs, qui apportent ici la petrification — et c est la
	# derniere fois que le joueur la voit avant que l Enfant la lui impose, ce qui
	# reste la fonction dramatique dont ce niveau avait besoin.
	#
	# CHANTIER W2 — LE GREFFIER mene la vague, qui devient le palier du registre.
	# Le commis des dieux RAYE une ligne de la main : il petrifie la plus longue
	# carte a incanter et la lance contre le mage. Dans le seul niveau dont le deck
	# est bati sur des sorts lourds, c est la question la plus cruelle possible —
	# jouer ses Meteores vite, ou les perdre. Un seul Regard reste pour que la
	# petrification se lise encore avant l Enfant (la Reine l a montree en `lvl_13`).
	r3.entries = [
		_entry(E + "spell_clerk.tres", 1, 1.0),
		_entry(E + "gorgon_gazer.tres", 1, 2.2, 6.0),
		_entry(E + "void_knight.tres", 2, 2.5, 12.0),
		_entry(E + "ghoul_priest.tres", 1, 2.5, 24.0),
	]
	_save(r3, "res://resources/waves/w15_3_miniboss.tres")

	var r4 := WaveDef.new()
	r4.id = &"w15_4"
	r4.duration = 32.0
	r4.difficulty = 1.50
	# Melange acte 4 : le blindage et l aura, plus le SECOND Chronos. La courbe a
	# rattrape son poids, il peut maintenant venir accompagne d un Behemoth.
	# CHANTIER W2 — deux Adeptes de braise a la place de trois Ombres : ils
	# reviennent une fois du haut, le rappel du Mage de braise des fosses.
	r4.entries = [
		_entry(E + "chronos_echo.tres", 1, 1.0),
		_entry(E + "behemoth.tres", 1, 1.0, 12.0),
		_entry(E + "totem_guardian.tres", 1, 1.0, 20.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 24.0),
		_entry(E + "adept_ember.tres", 2, 2.2, 28.0),
	]
	_save(r4, "res://resources/waves/w15_4.tres")

	var r5 := WaveDef.new()
	r5.id = &"w15_5"
	r5.duration = 40.0
	r5.difficulty = 1.50
	# (CHANTIER W2 : le registre a desormais son boss, l Horloger, en w15_6. Deux
	# Eclats de miroir — le Miroir de Forge en vermine — remplacent les deux
	# Chevaliers. La note qui suit dit pourquoi le niveau s en passait.)
	#
	# LE REGISTRE N A PAS DE BOSS, et c est la decision la plus consequente de ce
	# niveau. Le Reliquaire d os, qui devait le fermer, ferme deja `lvl_03` : le
	# catalogue des treize boss du jeu est entierement consomme par les vingt-et-un
	# niveaux de la campagne, et `test_bosses` refuse — a raison — qu un adversaire
	# mène deux niveaux.
	#
	# CE QUE CA COUTE, honnetement : l acte 5 n a plus qu UNE tete d affiche pour
	# ses trois niveaux, l Enfant au siege vide. Un joueur qui traverse la galerie
	# et le registre affronte deux niveaux sans nom propre a la fin.
	#
	# CE QUE CA RAPPORTE, et pourquoi je ne l ai pas contourne : ces deux niveaux
	# sont precisement ceux dont le document dit que « plus rien n impressionne ».
	# Un acte ou personne ne se leve pour vous arreter jusqu au tout dernier
	# combat raconte mieux « les dieux sont ASSIS » qu un boss intercalaire. La
	# derniere vague du registre est donc un FLUX — douze corps dont deux
	# Chronos-classe — et non un duel : le joueur sort de la salle parce qu il a
	# tenu, pas parce qu il a vaincu quelqu un.
	r5.entries = [
		_entry(E + "chronos_echo.tres", 1, 1.0),
		_entry(E + "mirror_shard.tres", 2, 2.5, 14.0),
		_entry(E + "ghoul_priest.tres", 2, 2.5, 24.0),
		_entry(E + "shade.tres", 3, 2.0, 32.0),
	]
	_save(r5, "res://resources/waves/w15_5.tres")

	# CHANTIER W2 — L HORLOGER ferme le registre.
	#
	# Chronos portait les dates ; l Horloger les REMONTE. Toutes les 7 s il revient
	# 3 s en arriere, position et PV compris : le seul adversaire du jeu qui fait
	# au mage ce que le mage a fait au monde. Le registre a ete rature une fois — le
	# mage l a fait — et c est lui qu on a charge de verifier que ca ne se reproduise
	# pas. Le deck du niveau (sorts lourds, Concentration, Precipitation) est
	# exactement celui qui frappe fort dans la fenetre qui suit un retour.
	#
	# Escorte legere : deux Adeptes des arcanes qui sautent de colonne en colonne,
	# pour que le joueur ne puisse pas regarder le boss seul.
	var r6 := WaveDef.new()
	r6.id = &"w15_6_boss"
	r6.duration = 48.0
	r6.difficulty = 1.0
	r6.is_boss = true
	r6.entries = [
		_entry(E + "clockmaker.tres", 1, 1.0),
		_entry(E + "adept_arcane.tres", 2, 3.0, 14.0),
	]
	_save(r6, "res://resources/waves/w15_6_boss.tres")

	var lvl15 := LevelDef.new()
	lvl15.id = &"lvl_15"
	lvl15.display_name = "Le registre"
	lvl15.terrain = "sand"
	lvl15.backdrop = "act5_divine"
	lvl15.intro_story = &"lvl_15_intro"
	lvl15.outro_story = &"lvl_15_outro"
	lvl15.waves = [r1, r2, r3, r4, r5, r6]
	lvl15.enemy_pool = [
		load(E + "ghoul_priest.tres"), load(E + "void_knight.tres"),
		load(E + "shade.tres"), load(E + "risen_ghoul.tres"),
		load(E + "behemoth.tres"), load(E + "totem_guardian.tres"),
		load(E + "chronos_echo.tres"), load(E + "gorgon_gazer.tres"),
		load(E + "adept_frost.tres"), load(E + "adept_ember.tres"),
		load(E + "adept_arcane.tres"), load(E + "mirror_shard.tres"),
		load(E + "spell_clerk.tres"), load(E + "clockmaker.tres"),
	]
	# LE DECK DU REGISTRE. Le Reliquaire compte les coups, donc il faut des sorts
	# LOURDS et peu nombreux : c est le seul deck de la campagne construit contre
	# le spam, et la Concentration y est doublee pour ca. La Precipitation entre
	# ICI : elle raccourcit l incantation des gros sorts au lieu d en ajouter.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouverte : Precipitation. Sortent le Trait, la Fleche, le Mur et la Marque ;
	# la Focalisation monte a 3, c est elle qui fait d un sort deux coups.
	#
	# DISSIPATION (chantier W9) : un Gardien-totem descend dans r4 avec le
	# Behemoth et les adeptes, et rien dans le deck ne coupait son aura. Le Vide
	# d emprise prend la place de la Concentration (de l XP de carte : elle ne
	# frappe rien, et ce deck est fait de coups lourds). La Precipitation reste :
	# c est la carte que ce niveau fait decouvrir. Le Vide est deja au livre
	# (decks de lvl_06, lvl_07, lvl_20) : seul le deck le met dans le pool.
	lvl15.exploration_deck = _deck([
		[C + "common/fireball.tres", 4],
		[C + "rare/meteor.tres", 3],
		[C + "rare/focus.tres", 2],
		[C + "epic/void_grip.tres", 1],
		[C + "rare/quickening.tres", 1],
		[C + "legendary/meteor_storm.tres", 1],
	])
	_poser_progression(lvl15)
	lvl15.next_levels = [&"lvl_16"]
	lvl15.act = 5
	lvl15.subtitle = "Ton nom y est, avec une date"
	lvl15.intro_text = "Des colonnes de noms qui montent plus haut que le regard. Ce \
n est pas une liste de morts : c est un CALENDRIER. L humanite n a pas ete attaquee, \
elle etait programmee pour s eteindre, a la date prevue. Ta ligne est la, et la date a \
ete raturee une fois."
	lvl15.outro_text = "Chronos n etait pas un ennemi, c etait un employe. Il portait \
les dates. Ton retour en arriere n a inquiete personne ici : il les a AMUSES. Un pion \
qui recule, c est la premiere chose distrayante depuis des eons, et on t a laisse \
courir pour voir jusqu ou tu irais."
	_save(lvl15, "res://resources/levels/lvl_15.tres")

	# ---------- lvl_16 : Le siege vide ----------
	#
	# Document, section 7 : « rien. Puis l enfant ». C est LE DERNIER NIVEAU DE LA
	# CAMPAGNE, et le retournement du jeu entier : l enfant sauve a la premiere
	# clairiere est la divinite qui a pose la date.
	#
	# COMMENT LA STRUCTURE DU NIVEAU RACONTE LE RETOURNEMENT. Le niveau est court
	# — QUATRE vagues, la plus courte fin d acte du jeu — et ses trois premieres
	# sont VIDES de tete d affiche. Le document dit « rien. Puis l enfant » : on ne
	# met donc pas un mini-boss a mi-parcours, parce qu il n y a personne pour
	# defendre le siege. Ce qui descend pendant trois vagues est ce que l enfant
	# envoie sans y penser, et il envoie des BOSS comme on chasse une mouche —
	# c est explicitement demande par le testeur : « ils n hesitent pas a envoyer
	# plusieurs boss comme des monstres normaux ».
	#
	# POURQUOI PAS DE MINI-BOSS ICI, alors que tous les autres niveaux en ont un.
	# `test_bosses` ne l exige pas (il interdit les DOUBLONS, il n impose pas la
	# presence), et le catalogue etait de toute facon epuise. Mais la vraie raison
	# est narrative : un mini-boss au niveau 16 serait un garde du corps, et le
	# siege est vide DEPUIS TOUJOURS. Il n y a personne entre le mage et son
	# adversaire, et c est ce qui rend la derniere vague terrifiante.

	var f1 := WaveDef.new()
	f1.id = &"w16_1"
	f1.duration = 28.0
	f1.difficulty = 1.45
	# DES ANCIENS BOSS DANS UNE VAGUE ORDINAIRE, sans titre ni fanfare : la demande
	# du testeur (« ils n hesitent pas a envoyer plusieurs boss comme des monstres
	# normaux ») et le propos du document (section 7) executes a la lettre. Deux
	# Gardiens de la foret PUIS Chronos, dans la premiere vague du dernier niveau,
	# escortes de la vermine du premier matin.
	#
	# POURQUOI CE SONT LE GARDIEN ET CHRONOS, et non le Coagule, le Colosse et
	# l Ensevelisseur comme dans le premier jet. Ce sont les deux que le document
	# NOMME pour l acte 5, et c est aussi la seule version qui ne casse pas le
	# Massacre : `build_membership()` rattache un monstre au monde de l acte ou il
	# est le plus DENSE, et l acte 5 — trois niveaux, donc un petit volume — captait
	# tout boss qu on citait ici. Mesure : cinq boss entasses dans le monde 4,
	# aucun dans le monde 0, et `pick_boss()` affamait Chronos une fois sur deux.
	# Les trois autres sont restes dans leur acte d origine, ou ils ont leur monde.
	#
	# Le Gardien et Chronos, eux, APPARTIENNENT a l acte 5 par le texte : ils sont
	# les deux pieces de musee que le document expose. Leur densite ici est donc
	# juste, pas un effet de bord.
	#
	# CHANTIER W3 — leurs ECHOS, plus eux : `warden.tres` et `chronos.tres` avec
	# leurs PV de boss faisaient de cette vague d ouverture la plus lourde du
	# niveau (deux Gardiens et un Chronos avant la moindre escorte) ; le banc y
	# voyait mourir le joueur 25 fois sur 30. La densite, elle, reste ici : ce sont les echos qui
	# appartiennent au monde 5, et le Gardien et Chronos retournent dans le monde de
	# leur acte, ou le Massacre les tire comme tetes.
	f1.entries = [
		_entry(E + "warden_echo.tres", 2, 4.0),
		_entry(E + "chronos_echo.tres", 1, 1.0, 18.0),
		_entry(E + "sprite.tres", 4, 1.5, 6.0),
		_entry(E + "hopper.tres", 3, 2.0, 16.0),
	]
	_save(f1, "res://resources/waves/w16_1.tres")

	var f2 := WaveDef.new()
	f2.id = &"w16_2"
	f2.duration = 30.0
	f2.difficulty = 1.50
	# Les quatre grands demons de l acte 4 reviennent, en ECHOS (chantier W4 :
	# leurs .tres de boss faisaient de w16_3 un mur, voir `demon_anvil_echo`) : le joueur a passe quatre niveaux a les abattre un par un, et
	# l enfant en renvoie deux d un coup sans commentaire. C est la vague qui fait
	# le plus mal au moral, et c est son seul travail.
	# CHANTIER W2 — deux Adeptes de braise a la place des deux Chevaliers : les
	# gardiens de Tombol, eux aussi renvoyes en vermine.
	f2.entries = [
		_entry(E + "demon_anvil_echo.tres", 1, 1.0),
		_entry(E + "demon_maw_echo.tres", 1, 1.0, 14.0),
		_entry(E + "berserker.tres", 3, 2.5, 8.0),
		_entry(E + "adept_ember.tres", 2, 2.5, 22.0),
	]
	_save(f2, "res://resources/waves/w16_2.tres")

	var f3 := WaveDef.new()
	f3.id = &"w16_3"
	f3.duration = 31.0
	f3.difficulty = 1.50
	# Les deux autres demons, plus Chronos. La derniere vague avant le siege : tout
	# ce que le joueur a vaincu dans la campagne descend en meme temps, et aucun
	# n a de titre.
	# CHANTIER W2 — un Adepte du givre et un des arcanes a la place des deux
	# Chevaliers : le trio complet est passe dans la vermine avant le siege.
	f3.entries = [
		# Deux echos de Kaltek : voir la mesure au-dessus de `demon_chain_echo`.
		_entry(E + "demon_chain_echo.tres", 2, 1.0),
		_entry(E + "demon_circle_echo.tres", 1, 1.0, 12.0),
		_entry(E + "chronos_echo.tres", 1, 1.0, 22.0),
		_entry(E + "adept_frost.tres", 1, 2.5, 8.0),
		_entry(E + "adept_arcane.tres", 1, 2.5, 10.5),
		_entry(E + "berserker.tres", 3, 2.2, 18.0),
		_entry(E + "hive.tres", 1, 2.5, 26.0),
	]
	_save(f3, "res://resources/waves/w16_3.tres")

	var f4 := WaveDef.new()
	f4.id = &"w16_4_boss"
	f4.duration = 60.0
	f4.difficulty = 1.0
	f4.is_boss = true
	# L ENFANT. LA DERNIERE VAGUE DU JEU.
	#
	# IL VIENT SEUL, et c est la decision la plus importante de ce niveau. Toutes
	# les autres vagues de boss du jeu portent une escorte ; celle-ci n en a pas.
	# Trois raisons, dans cet ordre :
	#
	#   1. Le document : « L enfant lache la main du mage. » La scene est un
	#      tete-a-tete, et une escorte la contredirait a l ecran.
	#   2. Il cumule TROIS mecaniques (petrification, renvoi, releve). Y ajouter
	#      des corps rendrait la vague illisible : le joueur ne saurait plus
	#      laquelle des trois le tue.
	#   3. Les trois vagues precedentes ont deja envoye SEPT anciens boss. La
	#      derniere doit faire le contraire du reste du niveau, sinon le
	#      retournement n a pas de silence pour resonner.
	#
	# `difficulty` a 1,0, le plus bas de tout l acte : le boss est deja le saut, et
	# multiplier sa pression par-dessus ses trois mecaniques ferait un combat qu on
	# perd sans comprendre. 60 s de duree parce qu il se RELEVE une fois — il faut
	# que la vague ait le temps de contenir ses deux moities.
	f4.entries = [
		_entry(E + "child_god.tres", 1, 1.0),
	]
	_save(f4, "res://resources/waves/w16_4_boss.tres")

	var lvl16 := LevelDef.new()
	lvl16.id = &"lvl_16"
	lvl16.display_name = "Le siege vide"
	lvl16.terrain = "sand"
	lvl16.backdrop = "act5_divine"
	lvl16.intro_story = &"lvl_16_intro"
	lvl16.outro_story = &"lvl_16_outro"
	lvl16.waves = [f1, f2, f3, f4]
	lvl16.enemy_pool = [
		load(E + "warden_echo.tres"), load(E + "chronos_echo.tres"),
		load(E + "demon_anvil_echo.tres"), load(E + "demon_maw_echo.tres"),
		load(E + "demon_chain_echo.tres"), load(E + "demon_circle_echo.tres"),
		load(E + "berserker.tres"), load(E + "child_god.tres"),
		# L escorte ordinaire des trois premieres vagues : sans elle, ces vagues
		# ne pesaient RIEN au budget (tout y est hors budget) et la courbe du
		# niveau etait illisible pour le banc.
		load(E + "sprite.tres"), load(E + "hopper.tres"),
		load(E + "void_knight.tres"), load(E + "hive.tres"),
		# CHANTIER W2 — le trio de Tombol, renvoye en vermine.
		load(E + "adept_ember.tres"), load(E + "adept_frost.tres"),
		load(E + "adept_arcane.tres"),
	]
	# LE DECK DE LA DERNIERE MAIN. Trois legendaires, et c est le seul niveau de
	# la campagne a les poser toutes les trois : le mage entre au siege vide avec
	# tout ce qu il a appris a faire du temps, parce que c est la seule chose que
	# l Enfant n a pas prevue.
	# C est aussi, a la lettre, le deck-limite de la regle des 6 : trois
	# legendaires a un exemplaire obligent les trois autres ids a quatre communes
	# chacun (3 x 1 + 3 x 4 = 15). Une quatrieme legendaire serait impossible.
	# L ARCANE DOMINE parce que c est la seule faille de la divinite (+40 %). La
	# Faille et le Sablier ne servent pas a frapper : ils servent a survivre a la
	# garde de renvoi, et c est au joueur de le trouver.
	#
	# REGLE DES 6 (27/09) : au plus 6 cartes differentes, 12 cartes (15 avant la vague 8 : trois exemplaires retires la ou l element du lieu mord le moins), exemplaires
	# 4/3/2/1. Le deck garde les cartes qui PORTENT le niveau et perd la variete de
	# fond ; chaque niveau fait decouvrir au moins une carte qu aucun deck joue
	# avant lui n avait montree (verifie dans l ordre de jeu par test_deck_rules).
	# Decouvertes : Faille temporelle et Metier du monde. Sortent le Meteore, la
	# Focalisation, le Mur, la Concentration et la Marque.
	#
	# DISSIPATION (chantier W9) : l Echo d Ymoa descend dans w16_3 et son aura
	# couvre les echos de Kaltek et de Vharn qui marchent avec lui ; le deck
	# n avait aucune carte pour la couper. Le Vide d emprise (x2) prend la place
	# des Fleches percantes. Banc (60 parties) : deck d avant 54 victoires ; Vide
	# a la place des Boules de feu (Fleche montee a 3) 20 ; a la place des
	# Fleches 51. Le Vide est deja au livre : seul le deck le met dans le pool de
	# montee.
	lvl16.exploration_deck = _deck([
		[C + "common/arcane_bolt.tres", 4],
		[C + "common/fireball.tres", 3],
		[C + "epic/void_grip.tres", 2],
		[C + "legendary/time_rift.tres", 1],
		[C + "legendary/hourglass_shard.tres", 1],
		[C + "legendary/world_loom.tres", 1],
	])
	_poser_progression(lvl16)
	# LA DERNIERE RECOMPENSE DE LA CAMPAGNE. L Echo de la main : le sort qui
	# rejoue ce qu on vient de lancer. Le mage scelle dans une boucle repart avec
	# la carte qui repete — c est le seul cadeau que cette fin pouvait faire.
	# FIN DE LA CAMPAGNE. La liste est VIDE, et c est ce qui fait de ce niveau la
	# derniere feuille du graphe : `test_campaign_acts` exige qu il n y en ait
	# qu une et qu elle tombe dans l acte 5.
	#
	# FINIR LA CAMPAGNE OUVRE LE MASSACRE. `SaveData.campaign_cleared()` compte
	# les niveaux termines sur le TOTAL de `ContentDB.levels` : il n y a donc rien
	# a declarer ici, le deblocage suit le contenu tout seul. C est verifie —
	# passer de 9 a 16 niveaux ne casse pas la recompense, elle demande juste la
	# campagne entiere, ce qui est precisement son sens (et ce que l ENDING
	# raconte : « MODE INFINI DEBLOQUE »).
	lvl16.next_levels = []
	lvl16.act = 5
	lvl16.subtitle = "Il est vide depuis toujours"
	lvl16.intro_text = "Au bout du registre, un siege. Il est vide depuis toujours, et \
personne ne le garde. Ce qui descend vers toi, l enfant l envoie sans y penser : des \
adversaires qui ont ferme des actes entiers arrivent par trois, sans un nom."
	lvl16.outro_text = "L enfant lache ta main. Il ne grandit pas, il ne change pas de \
forme : il arrete simplement de faire semblant d avoir peur. Il etait la depuis la \
date — c est lui qui l avait posee. Nuri le sixieme jour, Nox la septieme nuit. Et \
quand tu as recule, pour la premiere fois depuis tres longtemps, il n a pas su ce qui \
allait arriver."
	_save(lvl16, "res://resources/levels/lvl_16.tres")


## =====================================================================
## OBJECTIFS DE NIVEAU — trois par niveau, choisis POUR ce niveau.
##
## Jusqu au 27/09 les 21 niveaux portaient le MEME trio (vitesse au maximum,
## sans legendaire, sans degats). Il ne disait rien du niveau, et l un des
## trois etait hors d atteinte partout : la vitesse monte de 2 points par
## seconde depuis 150 %, il faut donc 175 s SANS UN COUP pour toucher 500 %,
## alors qu un niveau se gagne en 60 a 200 s. Mesure au banc sur les 21
## niveaux : 0 partie sur 630. `never_dropped_speed` reste dans le moteur,
## mais aucun niveau ne le porte tant qu un niveau ne dure pas assez longtemps
## pour qu il soit jouable.
##
## LES REGLES DE LA TABLE (chantier W7, demande du co-auteur du 30/09 : les
## objectifs etaient "mal realises, pas encore lies aux cartes du jeu")
## 1. Chaque objectif s appuie sur ce que le niveau CONTIENT : une carte de SON
##    DECK (la jouer N fois, s en passer, tuer telle espece avec elle), une de
##    SES especes (en tuer N d un seul sort, ne pas en etre touche, en prendre
##    un coup), ses volants, son monstre qui se releve, sa garde de renvoi.
##    Deux objectifs sur trois au moins sont ainsi LIES ; le troisieme peut
##    etre un pari de fin de combat (vitesse, chrono), comme dans l exemple du
##    co-auteur (Fleche 6 fois, sans Boule de feu, plus de 300 %).
##    L AUDIT refuse l impossible et signale le gratuit ; test_level_objectives
##    et test_level_progression refusent les deux.
## 2. Les trois objectifs sont CLASSES du plus facile au plus dur, et leur
##    position fixe la rarete de la carte qu ils debloquent : rare, epique,
##    legendaire (LevelDef.REWARD_RARITY_BY_RANK). Le classement n est pas une
##    intuition : chaque objectif est joue 60 fois au banc par un bot qui le VISE
##    (voir test_level_progression.MESURES), il doit y etre reussi au moins une
##    fois, rate au moins une fois, et le taux DECROIT du rang 1 au rang 3.
##    Les mesures datent de W7 : a re-mesurer apres la vague 8 (nouveaux decks,
##    elements, temps d incantation) ; les deux objectifs neufs de W8 attendent
##    leur mesure (test_level_progression.OBJECTIFS_A_MESURER).
## 3. Pas de « en tuer N d un seul sort » dans un niveau dont une carte jouable
##    (deck, cartes nouvelles, recompenses) pose un tueur PERMANENT (ronces,
##    arbre, autel) : il compte pour UN seul lancer de toute la partie.
##
## LES CARTES
## - « nouvelles » : les TROIS cartes que la montee de niveau fait decouvrir en
##   plus du deck ("seulement trois, sinon trop de cartes pour un niveau 1").
##   Jamais une carte du deck ; en acte 1, communes et rares sans objet
##   permanent ; pas de legendaire avant l acte 4 ; ni mur ni appat dans le
##   niveau des volants. Choisies contre les RESISTANCES du lieu,
##   qui comptent sur les degats ET sur les effets : un sort givre + lenteur ne
##   touche pas un monstre immunise a la lenteur (minimum des deux).
## - La carte de chaque objectif, A SON RANG : jamais au deck ni parmi les
##   nouvelles.
## - VRAIMENT NOUVELLES (chantier W8, 01/10). Une carte est OBTENUE des qu elle
##   est au deck d un niveau OUVERT (ou prise en combat) : quand le joueur joue
##   un niveau, il possede au moins l union des decks des niveaux deja ouverts,
##   le sien compris (les freres ouverts par la meme victoire aussi : lvl_05 et
##   lvl_06, les quatre demons). Et la victoire de ce niveau OUVRE les suivants :
##   leurs decks sont acquis au moment meme ou une recompense tombe, et une
##   carte nouvelle prise en combat le serait aussi en gagnant. Une carte
##   nouvelle ou une recompense n est donc JAMAIS dans les decks des niveaux
##   ouverts APRES la victoire. Un audit du 30/09 en trouvait 33 nouvelles et 19
##   recompenses sur 63 deja possedees.
## - Le catalogue ne suffit pas a 126 places inedites. Chaque sort qui peut
##   encore l etre (42 : ni au deck de lvl_01, ni a celui de lvl_02 qu ouvre sa
##   victoire) est propose une premiere fois AVANT d entrer dans un deck ouvert
##   (Sablier en lvl_02, Semis au lvl_17...) ; les 84 autres places sont des
##   REPRISES d une carte deja proposee plus tot (donc non garantie), le minimum
##   possible : 126 - 42. Elles sont reparties (jamais deux niveaux de suite,
##   peu dans une fenetre de quatre).
## - Les 11 legendaires remplissent d abord les 11 premieres recompenses de rang
##   3 (lvl_01 a lvl_05 dans l ordre de jeu) ; les reprises de legendaire
##   viennent toutes APRES, espacees d au moins quatre niveaux.
## - Verifie par test_level_progression._test_cartes_vraiment_nouvelles, qui
##   suit l ordre de jeu (next_levels) par un calcul propre, compare a celui du
##   jeu (SaveData.cards_owned_by_decks).
## - Les passifs n ont pas de ligne : a partir de l acte 2, le pool de montee de
##   niveau les contient tous (RunState.levelup_pool).
## Tout le catalogue devient ainsi obtenable en campagne (verifie par
## test_level_progression._test_tout_le_catalogue_est_obtenable).
## =====================================================================

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
## objectifs, la carte que chacun debloque (meme position) et ses cartes nouvelles.
func _poser_progression(lvl: LevelDef) -> void:
	var t: Dictionary = _progression_de(lvl.id)
	var objectifs: Array[ObjectiveDef] = []
	var recompenses: Array[SpellCard] = []
	for ligne: Array in t.get("objectifs", []):
		objectifs.append(ligne[0])
		recompenses.append(_carte(ligne[1]))
	var nouvelles: Array[SpellCard] = []
	for id: String in t.get("nouvelles", []):
		nouvelles.append(_carte(id))
	lvl.objectives = objectifs
	lvl.objective_rewards = recompenses
	lvl.levelup_cards = nouvelles


## Une carte du catalogue par son id, quel que soit son dossier de rarete.
func _carte(id: String) -> SpellCard:
	for dossier in ["common", "rare", "epic", "legendary"]:
		var chemin: String = "res://resources/cards/%s/%s.tres" % [dossier, id]
		if ResourceLoader.exists(chemin):
			return load(chemin)
	printerr("Carte inconnue dans la table de progression : %s" % id)
	return null


## Une longueur de terrain en pixels (enemy_travel s ecrit en pixels, se lit en
## longueurs : voir ObjectiveChecker.terrain_length).
func _longueurs(n: float) -> float:
	return n * ObjectiveChecker.terrain_length()


## LA TABLE, dans l ordre de jeu de la campagne.
func _progression_de(level_id: StringName) -> Dictionary:
	match level_id:
		&"lvl_01":
			# Tutoriel, l exemple du co-auteur quand il tient dans le niveau : Fleche
			# 9 fois (elle est au deck), gagner sans Boule de feu (au deck aussi : les
			# degats doivent venir d ailleurs). La Fleche etait a 6 fois, le chiffre du
			# co-auteur : apres la vague 8 (deck de 12, incantation x1,9) 6 lancers
			# reussissaient 60 parties sur 60, un objectif qui ne se rate jamais ; 9 :
			# 54 / 60, 12 : 6 / 60. Le « plus de 300 % » ne se joue
			# pas ici : 96 s de combat ne laissent monter la vitesse que vers 340 % sans un
			# coup, le seuil descend a 250 et l exemple passe au niveau suivant.
			# Nouvelles : Pluie de givre, Dard venimeux, Rupture de chaine, trois sorts
			# simples a un seul geste. Le Dard (vague 8, commune de poison) est ici parce
			# que le tutoriel est le lieu ou le poison mord le mieux (facteur 1,13 contre
			# 0,4 a 0,8 presque partout ailleurs) et que Chronos dure : le poison qui
			# court jusqu a la mort s y lit. Il prend la place du Brasier, dont la
			# premiere sortie passe en lvl_08. Recompenses : Volte-face, Maelstrom (au
			# deck de lvl_08) et la Faille temporelle, ancienne legendaire du niveau 1.
			# Ni le Meteore ni la Nappe : ils sont au deck de lvl_02, que cette victoire
			# ouvre.
			return {"nouvelles": ["frost_rain", "venom_dart", "chain_break"], "objectifs": [
				[_objectif(&"card_casts", {"card": "piercing_arrow", "count": 9}), "about_face"],
				[_objectif(&"no_card", {"card": "fireball"}), "maelstrom"],
				[_objectif(&"win_above_speed", {"pct": 250}), "time_rift"],
			]}
		&"lvl_02":
			# Le Coagule se RELEVE : l achever vite apres son releve est la lecon.
			# « Plus de 300 % » (exemple du co-auteur) : le combat dure trois minutes, la
			# vitesse a le temps de monter. Les Sauterelles avancent par a-coups et se
			# regroupent a l arret : en tuer 4 d un seul sort demande d attendre la pause.
			# Nouvelles : Elan du temps, Precipitation, Spirale de sel. L Elan (vague 8,
			# rare de temps) prend la place de l Intuition arcanique, devenue EPIQUE :
			# l acte 1 n offre que communes et rares ; sa premiere sortie passe en lvl_18.
			# Les deux cartes de temps ensemble : l une rend de la vitesse, l autre
			# accelere l incantation. Recompenses : Rappel d ossements, Concentration (au
			# deck de lvl_09) et le Sablier fendu, lui aussi au deck de lvl_09 : c est sa
			# derniere fenetre.
			# Rangs re-mesures apres la vague 8 (60 parties) : le pari des 300 % (43)
			# passe devant l achevement du releve en 8 s (35).
			# Chantier W9 : un Gardien-totem descend dans w2_6 et son aura rend la
			# vague intouchable ; ni le deck ni les cartes nouvelles ne la coupaient.
			# La Lumiere purifiante (rare, ni terrain ni objet : une carte simple
			# d acte 1) prend la place de la Spirale de sel, qui passe en lvl_08 ou
			# elle remplace la Lumiere : meme nombre de reprises, aucune carte deux
			# niveaux de suite.
			return {"nouvelles": ["time_surge", "quickening", "purifying_light"], "objectifs": [
				[_objectif(&"win_above_speed", {"pct": 300}), "bone_recall"],
				[_objectif(&"boss_quick_after_revive", {"seconds": 8}), "deep_focus"],
				[_objectif(&"kill_type_one_cast", {"enemy": "hopper", "count": 4}), "hourglass_shard"],
			]}
		&"lvl_08":
			# Le niveau des zones (seize Oiseaux mirage, gelees qui se divisent) :
			# l exemple du co-auteur « 4 Oiseaux mirage en une attaque » est ici, une nuee
			# en compte quatre. Les petites gelees craignent le feu : les achever a la
			# Boule de feu. Et la plus longue serie, 15 morts en moins d une seconde.
			# Nouvelles : Brasier (sa premiere sortie depuis la vague 8), Focalisation,
			# Spirale de sel (chantier W9 : elle venait de lvl_02, qui prend la Lumiere
			# purifiante contre son Gardien-totem ; ici elle aspire les nuees et les
			# gelees en paquets pour la Boule de feu). Recompenses : Onde de
			# repulsion, Resonance (au deck de lvl_17) et le Cadran des forges, feu en
			# pluie.
			# Rangs re-mesures apres la vague 8 : les gelees a la Boule de feu (37 / 60)
			# sont plus faciles que la nuee d un seul sort (28).
			return {"nouvelles": ["brazier", "focus", "salt_spiral"], "objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "jelly_small", "card": "fireball", "count": 8}), "repulsion_wave"],
				[_objectif(&"kill_type_one_cast", {"enemy": "rat_swarm", "count": 4}), "resonance"],
				[_objectif(&"multi_kill", {"count": 15, "window": 1}), "forge_dial"],
			]}
		&"lvl_09":
			# Le Sablier fendu est au deck : s en passer est un vrai choix. Le Renard
			# dormeur coupe la magie pendant son sommeil ; l exemple du co-auteur demande de
			# gagner APRES en avoir pris un coup, donc de le laisser approcher. Finir sous
			# 200 % est le pari de fin de combat.
			# Nouvelles : Etincelle, Cycle de pensee, Flux de mana, des cartes simples de
			# foudre et de grimoire a cote de la Concentration du deck. Recompenses :
			# Entrave temporelle, Marque de faiblesse (au deck du port) et la Mare de
			# venin (elle revient en lvl_11 contre Kaltek, qui craint le poison).
			return {"nouvelles": ["spark", "cycle_of_thought", "mana_flow"], "objectifs": [
				[_objectif(&"no_legendary_used"), "temporal_drag"],
				[_objectif(&"hit_from", {"enemy": "sleepy_fox"}), "weakness_mark"],
				[_objectif(&"win_below_speed", {"pct": 200}), "venom_mire"],
			]}
		&"lvl_17":
			# La Resonance du deck frappe chaque monstre present : la jouer souvent.
			# Vingt et un volants : les abattre tous. Le plus dur est le defi du co-auteur
			# « faire parcourir une tres grande distance a un monstre » (vague 8) : dix
			# longueurs de terrain a un Serpent des sables avant de l abattre. Le Serpent
			# ONDULE et son ondulation ne ralentit pas : retenu par le givre du deck (Pluie
			# x4, Champ x1) ou renvoye en haut par la Volte-face, il serpente sur place et
			# allonge son chemin. Mais il craint le givre (x1,9) : le retenir sans le tuer
			# trop tot est tout le geste. Remplace « tenir la ligne haute a 70 % ».
			# Mesure apres la vague 8 (60 parties) : six longueurs, le seuil provisoire,
			# se reussissaient 59 fois ; 9 : 44 ; 10 : 25 ; 11 : 1. Le classement suit
			# la mesure : Resonance 7 fois (50), 21 volants (46), 10 longueurs (25).
			# Nouvelles : Volte-face (fait remonter les serpents), Rupture de chaine (les
			# Oeils des courants craignent le physique), toutes deux deja proposees en
			# lvl_01, et le Totem de coeur-de-bois, un appat qui detourne les serpents. Le
			# Semis de fletrissure (recompense), au deck de l ossuaire, n a pas d autre
			# place : un terrain permanent n entre pas en acte 1, et le port ouvre l
			# ossuaire.
			return {"nouvelles": ["about_face", "chain_break", "heartwood_totem"], "objectifs": [
				[_objectif(&"card_casts", {"card": "resonance", "count": 7}), "salt_spiral"],
				[_objectif(&"kill_flying", {"count": 21}), "blight_sapling"],
				[_objectif(&"enemy_travel", {"enemy": "sand_serpent", "distance": _longueurs(10.0)}), "twin_channeling"],
			]}
		&"lvl_18":
			# Les Pillards arrivent par le cote et craignent le feu : les abattre a la
			# Boule de feu. Le port est le niveau le plus dur de l acte : le pari est de
			# finir en dessous de 190 %, et la Marque de faiblesse doit revenir souvent.
			# Nouvelles : Apprenti miroir, Intuition arcanique (premiere sortie depuis
			# qu elle est epique, vague 8) et Brasier (deja propose ; les pillards
			# craignent le feu). Legendaire : la Riviere, qui force les
			# pillards a un pont.
			return {"nouvelles": ["mirror_apprentice", "arcane_insight", "brazier"], "objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "nacelle_raider", "card": "fireball", "count": 5}), "bone_recall"],
				[_objectif(&"win_below_speed", {"pct": 190}), "terrain_pit"],
				[_objectif(&"card_casts", {"card": "weakness_mark", "count": 11}), "terrain_river"],
			]}
		&"lvl_03":
			# L ossuaire : l exemple du co-auteur « 8 monstres en moins d une seconde ».
			# La Pluie de givre (x4) porte le niveau : la lancer souvent, et achever avec
			# elle les Oiseaux mirage. Le Semis de fletrissure du deck est un tueur
			# permanent : pas de « d un seul sort » ici.
			# Nouvelles : Etincelle (deja proposee en lvl_09), Pacte imprudent, Racine de
			# tonnerre. Recompenses : Lumiere purifiante, Epuration, Metier du monde.
			# Rangs re-mesures apres la vague 8 : achever 15 Oiseaux a la Pluie (41 / 60)
			# est plus facile que de la lancer 26 fois (31).
			return {"nouvelles": ["spark", "reckless_bargain", "thunder_root"], "objectifs": [
				[_objectif(&"multi_kill", {"count": 8, "window": 1}), "purifying_light"],
				[_objectif(&"kill_type_with_card", {"enemy": "rat_swarm", "card": "frost_rain", "count": 15}), "deck_purge"],
				[_objectif(&"card_casts", {"card": "frost_rain", "count": 26}), "world_loom"],
			]}
		&"lvl_04":
			# Le Grand Appel : l Ensevelisseur leve des goules sans fin ; les achever aux
			# Braises (elles craignent le feu). Deux Lutins archers tirent de loin :
			# exemple du co-auteur, ne pas se faire toucher par eux : c est le plus dur
			# (5 / 60 apres la vague 8). Entre les deux, un combat court contre un appel
			# sans fin. « Sans une egratignure » ne se reussissait plus (0 / 60) et n a
			# pas de parametre : il est remplace par ce pari de fin de combat.
			# Nouvelles : Vide d emprise, Flux de mana et Precipitation (deja proposees en
			# acte 1 : le catalogue s epuise, voir l en-tete). Legendaire : la Clef de l
			# Appel, a sa place dans le Grand Appel.
			return {"nouvelles": ["void_grip", "mana_flow", "quickening"], "objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "risen_ghoul", "card": "ember_pool", "count": 2}), "temporal_drag"],
				[_objectif(&"win_under_time", {"seconds": 130}), "deep_freeze"],
				[_objectif(&"no_hit_from", {"enemy": "imp_archer"}), "summoners_key"],
			]}
		&"lvl_19":
			# Les Goules des fosses arrivent par six : en tuer quatre d un seul sort. La
			# Sorciere de givre du trio craint le feu, que le deck porte en majorite :
			# 60 sorts de feu, le plus facile apres la vague 8 (44 se reussissaient 60
			# fois sur 60 ; 60 : 48 / 60, contre 33 pour les quatre goules).
			# Nouvelles : Racine de tonnerre (foudre, que les goules craignent), Volte-
			# face, Brasier, toutes deja proposees. Recompenses : Rupture de chaine,
			# Bastion, Echo de la main.
			return {"nouvelles": ["thunder_root", "about_face", "brazier"], "objectifs": [
				[_objectif(&"element_casts", {"element": "FIRE", "count": 60}), "chain_break"],
				[_objectif(&"kill_type_one_cast", {"enemy": "pit_ghoul", "count": 4}), "bastion"],
				[_objectif(&"no_damage_taken"), "echo_of_the_hand"],
			]}
		&"lvl_20":
			# La cour des rois morts, niveau dur : le Vide d emprise du deck dissipe les
			# auras des Gardiens-totems, s en passer se paie ; la Fleche percante (x3)
			# traverse les rangs de squelettes pareurs ; le pari de finir sous 170 %.
			# Le defi du co-auteur « sous 120 % » etait ici a la vague 8 : 0 partie sur
			# 60 au banc des objectifs (la plus basse victoire finit a 127 %). Il est
			# passe a l arene de Kaltek (lvl_11), ou les berserkers frappent tard ; ici
			# le seuil remonte a 170 % (8 / 60).
			# Nouvelles : Fosse, Intuition arcanique, Flux de mana (totems et squelettes
			# craignent l arcane). Recompenses : Ronces, Autel d appel, Pluie de
			# meteorites (au deck du pentacle).
			return {"nouvelles": ["terrain_pit", "arcane_insight", "mana_flow"], "objectifs": [
				[_objectif(&"no_card", {"card": "void_grip"}), "terrain_brambles"],
				[_objectif(&"card_casts", {"card": "piercing_arrow", "count": 21}), "terrain_altar"],
				[_objectif(&"win_below_speed", {"pct": 170}), "meteor_storm"],
			]}
		&"lvl_05":
			# Les forges : Golems et Behemoths craignent l ARCANE, que le deck porte
			# (Trait x4, Focalisation, Marque) : en lancer beaucoup. Les Golems vont par
			# deux : les tuer d un seul sort. Puis finir au-dessus de 310 %. (« Ne jamais
			# frapper en garde de renvoi » contre le Miroir de forge : 0 a 4 parties sur
			# 30 au banc, le bot ne sait pas attendre la fin d une garde ; il reste au
			# Registre.) Presque tout ici est immunise a la lenteur : un sort givre +
			# lenteur ne mord pas (minimum des resistances) : les nouvelles n en portent
			# pas (Etincelle, Epuration, Mur de glace). Legendaire : le Registre des
			# marees, la onzieme et derniere legendaire proposee pour la premiere fois.
			# Chantier W9 : le Mur de glace (premier objet de glace) remplace le Pacte
			# imprudent, une reprise (propose en lvl_03, lvl_07, lvl_11...). C est sa
			# premiere et seule sortie : la reprise devient une decouverte, les
			# reprises restent au minimum. Il est ICI parce que le Colosse de forge
			# craint la glace (x2) : enferme derriere le mur, il le frappe moins fort
			# — l exemple du co-auteur — et le mur ne porte pas de lenteur, que tout
			# le niveau ignore.
			return {"nouvelles": ["spark", "deck_purge", "ice_wall"], "objectifs": [
				[_objectif(&"element_casts", {"element": "ARCANE", "count": 48}), "cycle_of_thought"],
				[_objectif(&"kill_type_one_cast", {"enemy": "golem", "count": 2}), "mirror_apprentice"],
				[_objectif(&"win_above_speed", {"pct": 310}), "tide_ledger"],
			]}
		&"lvl_06":
			# La Racine de tonnerre est a UN exemplaire et le Seigneur spectre craint la
			# foudre : lancer sept sorts de foudre. Les Sauterelles s arretent en groupe :
			# en tuer trois d un seul sort. Et un combat court.
			# Mesure apres la vague 8 (60 parties) : 5 sorts de foudre se reussissaient
			# 60 fois, 7 : 48 (trois Sauterelles : 38). Le combat court passe de 100 a
			# 108 s : l incantation x1,9 allonge les combats, 100 s n etait plus tenu
			# qu une fois sur 60 (108 s : 6).
			# Nouvelles : Volte-face, Intuition arcanique, Precipitation (arcane, que
			# craignent Seigneur, Ombres et Bourreau). Legendaire : la Faille temporelle
			# revient (lvl_01), premiere reprise de legendaire : les onze ont toutes ete
			# proposees une fois avant.
			return {"nouvelles": ["about_face", "arcane_insight", "quickening"], "objectifs": [
				[_objectif(&"element_casts", {"element": "LIGHTNING", "count": 7}), "temporal_drag"],
				[_objectif(&"kill_type_one_cast", {"enemy": "hopper", "count": 3}), "deep_freeze"],
				[_objectif(&"win_under_time", {"seconds": 108}), "time_rift"],
			]}
		&"lvl_21":
			# Le pentacle : les Vers de feu sont IMMUNISES au feu. Les abattre au Trait
			# arcanique, puis gagner sans aucun sort de feu, la bonne lecture du niveau.
			# Le combat court passe de 118 a 90 s apres la vague 8 : 118 s se tenait 53
			# fois sur 60, plus que les deux autres ; 90 s : 13.
			# Chantier W9 (Lumiere purifiante au deck a la place de la Concentration) :
			# trois Vers au Trait (57 / 60) et « sans feu » (58) se rejoignaient. « Sans
			# feu » passe au rang 1 et les Vers au rang 2, a cinq au lieu de trois :
			# un ecart d une partie ne classe rien.
			# Nouvelles : Etincelle, Epuration, Flux de mana.
			return {"nouvelles": ["spark", "deck_purge", "mana_flow"], "objectifs": [
				[_objectif(&"no_card_tag", {"tag": "FIRE"}), "cycle_of_thought"],
				[_objectif(&"kill_type_with_card", {"enemy": "fire_worm", "card": "arcane_bolt", "count": 5}), "bastion"],
				[_objectif(&"win_under_time", {"seconds": 90}), "twin_channeling"],
			]}
		&"lvl_07":
			# La forge de Vharn : l Apprenti miroir est la carte du niveau. S en passer,
			# puis a l inverse abattre avec lui cinq Lutins fileurs. L Autel (nouvelle) et
			# les Ronces (recompense) sont des tueurs permanents.
			# Nouvelles : Pacte imprudent, Autel d appel (deck d invocation),
			# Precipitation.
			return {"nouvelles": ["reckless_bargain", "terrain_altar", "quickening"], "objectifs": [
				[_objectif(&"no_card", {"card": "mirror_apprentice"}), "terrain_brambles"],
				[_objectif(&"kill_type_with_card", {"enemy": "sprite", "card": "mirror_apprentice", "count": 5}), "terrain_pit"],
				[_objectif(&"win_above_speed", {"pct": 350}), "forge_dial"],
			]}
		&"lvl_10":
			# Les fosses de Sesh : deux Cacodemons volent en fin de niveau. En abattre
			# un ; sans degats (pas de tireur) ; et le plus dur, en faire marcher un sur
			# 1,5 longueur de terrain avant de l abattre : ils sautent de colonne en
			# colonne, et la Volte-face du deck les fait remonter. A 0,8 longueur avant
			# la vague 8 : 48 parties sur 60, plus facile que « sans degats » (38) ;
			# 1,2 : 38 ; 1,4 : 18 ; 1,5 : 9.
			# « Tres grande distance » (chantier W9, audit) : 1,5 longueur reste le
			# plafond FAISABLE ici. Remesure sur 60 parties : 1,7 longueur 0 / 60,
			# 2,0 longueurs 0 / 60 — un objectif jamais reussi est refuse. La raison
			# tient au niveau : deux Cacodemons seulement, en fin de niveau (w10_4),
			# qui descendent en diagonale d un bord a l autre ; meme retenus par la
			# Volte-face du deck, aucun n a couvert 1,7 longueur avant de tomber ou
			# de toucher le mage sur 120 parties. Le vrai defi
			# de distance est celui de lvl_17 (dix longueurs a un Serpent, qui
			# ondule sur place dans le givre).
			# Nouvelles : Bastion (un mur permanent allonge le chemin), Metier du monde,
			# Flux de mana. Legendaire : la Riviere, qui fait marcher.
			return {"nouvelles": ["bastion", "world_loom", "mana_flow"], "objectifs": [
				[_objectif(&"kill_flying", {"count": 1}), "cycle_of_thought"],
				[_objectif(&"no_damage_taken"), "deck_purge"],
				[_objectif(&"enemy_travel", {"enemy": "cacodaemon", "distance": _longueurs(1.5)}), "terrain_river"],
			]}
		&"lvl_11":
			# L arene de Kaltek : Ecumeur du ciel et feux follets volent, Kaltek craint
			# le givre (le deck en est plein). Les berserkers accelerent et frappent
			# tard : c est ici que tombe le defi du co-auteur « finir sous 120 % »
			# (vague 8). Il est passe de la cour des rois morts a l arene apres la
			# re-mesure de la vague 8 : 0 partie sur 60 sous 120 % dans la cour, 8 ici
			# (sous 150 % : 17).
			# Nouvelles : Pacte imprudent, Fosse, Ronces (le deck est au givre et a la
			# lenteur). Legendaire : la Mare de venin (Kaltek craint le poison).
			return {"nouvelles": ["reckless_bargain", "terrain_pit", "terrain_brambles"], "objectifs": [
				[_objectif(&"element_casts", {"element": "ICE", "count": 32}), "quickening"],
				[_objectif(&"kill_flying", {"count": 4}), "terrain_altar"],
				[_objectif(&"win_below_speed", {"pct": 120}), "venom_mire"],
			]}
		&"lvl_12":
			# Le temple d Ymoa : les Ombres craignent l arcane, les abattre au Trait
			# arcanique ; la Focalisation est le coeur du deck ; et l exemple du
			# co-auteur « jouer la meme carte » pousse a 38 fois.
			# Mesure apres la vague 8 (60 parties) : 14 Focalisations se reussissaient
			# 60 fois, 21 : 59, 26 : 52, 28 : 49 ; les Ombres au Trait (56) passent
			# devant, la meme carte 38 fois (37) reste la plus dure.
			# Nouvelles : Epuration, Echo de la main, Flux de mana, pour un deck tourne
			# vers la main.
			return {"nouvelles": ["deck_purge", "echo_of_the_hand", "mana_flow"], "objectifs": [
				[_objectif(&"kill_type_with_card", {"enemy": "shade", "card": "arcane_bolt", "count": 7}), "cycle_of_thought"],
				[_objectif(&"card_casts", {"card": "focus", "count": 28}), "bastion"],
				[_objectif(&"same_card_casts", {"count": 38}), "summoners_key"],
			]}
		&"lvl_13":
			# Le pentacle brise : le Sablier fendu est au deck ; l Etincelle (x3) doit
			# porter 25 lancers ; finir au-dessus de 300 % contre les quatre echos.
			# Nouvelles : Pacte imprudent, Autel d appel, Precipitation.
			return {"nouvelles": ["reckless_bargain", "terrain_altar", "quickening"], "objectifs": [
				[_objectif(&"no_legendary_used"), "terrain_brambles"],
				[_objectif(&"card_casts", {"card": "spark", "count": 25}), "terrain_pit"],
				[_objectif(&"win_above_speed", {"pct": 300}), "time_rift"],
			]}
		&"lvl_14":
			# La galerie des saisons : vingt Oiseaux mirage (en tuer trois d un sort), les
			# deux Renards dormeurs (exemple du co-auteur : gagner en ayant pris leur
			# coup) et les deux Lutins archers (ne pas etre touche par eux).
			# Nouvelles : Bastion, Riviere, Registre des marees.
			# Rangs re-mesures apres la vague 8 : le coup du Renard (54 / 60) passe
			# devant les trois Oiseaux d un sort (43).
			return {"nouvelles": ["bastion", "terrain_river", "tide_ledger"], "objectifs": [
				[_objectif(&"hit_from", {"enemy": "sleepy_fox"}), "cycle_of_thought"],
				[_objectif(&"kill_type_one_cast", {"enemy": "rat_swarm", "count": 3}), "deck_purge"],
				[_objectif(&"no_hit_from", {"enemy": "imp_archer"}), "world_loom"],
			]}
		&"lvl_15":
			# Le registre : le deck est au feu (Boule x4, Meteore x3, Pluie de
			# meteorites) et les adeptes du givre, pretres et echos de Chronos le
			# craignent : 58 sorts de feu. Les Eclats de miroir renvoient les coups
			# pendant leur garde : ne jamais les frapper a ce moment. Puis finir au-dessus
			# de 380 %. (« Sans legendaire » ne coutait rien : 30 parties sur 30.)
			# Nouvelles : Pacte imprudent, Fosse, Canalisation jumelle.
			return {"nouvelles": ["reckless_bargain", "terrain_pit", "twin_channeling"], "objectifs": [
				[_objectif(&"element_casts", {"element": "FIRE", "count": 50}), "terrain_brambles"],
				[_objectif(&"never_hit_reflect"), "terrain_altar"],
				[_objectif(&"win_above_speed", {"pct": 380}), "forge_dial"],
			]}
		&"lvl_16":
			# Le siege vide : les Echos de Kaltek frappent au contact, les tenir a
			# distance ; l Enfant se RELEVE ; il ne craint que l arcane.
			# Nouvelles : Bastion, Echo de la main, Clef de l Appel.
			# Rangs re-mesures apres la vague 8 : 58 sorts d arcane (40 / 60) passent
			# devant l Enfant acheve en 9 s apres son releve (28).
			# Chantier W9, deck refait (Vide d emprise x2 a la place des Fleches) :
			# le bot qui joue l arcane d abord gaspille ses lancers en Vide et perd
			# plus souvent (58 sorts d arcane : 21 / 60) ; l Enfant en 9 s ne bouge pas
			# (28). Rangs echanges, ids gardes.
			return {"nouvelles": ["bastion", "echo_of_the_hand", "summoners_key"], "objectifs": [
				[_objectif(&"no_hit_from", {"enemy": "demon_chain_echo"}), "cycle_of_thought"],
				[_objectif(&"boss_quick_after_revive", {"seconds": 9}), "deck_purge"],
				[_objectif(&"element_casts", {"element": "ARCANE", "count": 58}), "venom_mire"],
			]}
	printerr("Niveau %s absent de la table de progression" % level_id)
	return {}
