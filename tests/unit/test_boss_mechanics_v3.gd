extends TestCase
## Les six MECANIQUES DE BOSS v3 (27 septembre) et la borne de `hits_immune`.
##
##   1. Horloger              -> il revient N s en arriere ; frapper APRES le retour
##   2. Jumeaux               -> le mort revient si l autre survit ; les tuer ensemble
##   3. Cameleon              -> l element faible tourne, la legende le dit en mots
##   4. Voleur de sorts       -> il tient une carte, puis la lance contre le mage
##   5. Devoreur-invocateur   -> il invoque, laisse murir, avale et se soigne
##   6. Miroir du mage        -> sa vitesse suit celle du mage, bornee
##
## Chaque mecanique est testee DEUX fois : qu elle se DECLENCHE, et qu elle se
## TERMINE (plafond, garantie de mort, carte rendue). Une mecanique de boss qui ne
## se termine pas est un mur, pas un combat.
##
## Aucune valeur d equilibrage n est figee : chaque test construit son EnemyDef,
## et toutes les assertions sont exprimees a partir des champs qu il a poses.

func get_suite_name() -> String:
	return "boss_v3"


var _bf: Battlefield = null
var _tues: int = 0
const DT: float = 1.0 / 60.0


func _def(id: String, hp: float = 100.0, speed: float = 0.0, power: int = 10) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.kind = GameEnums.EnemyKind.BOSS if power >= 10 else GameEnums.EnemyKind.NORMAL
	d.max_hp = hp
	d.base_speed = speed
	d.power = power
	d.base_radius = 40.0
	return d


func _card(id: String, cast: float) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = id
	c.base_cast_time = cast
	c.tags = [GameEnums.DamageTag.ARCANE]
	return c


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()
	_tues = 0
	if not _bf.enemy_killed.is_connected(_compte_mort):
		_bf.enemy_killed.connect(_compte_mort)


func _compte_mort(_d: EnemyDef) -> void:
	_tues += 1


## Monde a x1 et mage maintenu en vie (voir test_bosses.gd::_sim : la vitesse est
## la vie ET l horloge, un mage mort ferait tourner le monde au ralenti).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(DT)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
		t += DT


## Simule jusqu a ce que `cond` soit vraie (au plus `max_s` secondes). Rend le
## temps ecoule, ou -1 si la condition n est jamais venue.
func _sim_until(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while t < max_s:
		if cond.call():
			return t
		_sim(DT)
		t += DT
	return t if cond.call() else -1.0


func run() -> void:
	_test_horloger_revient_en_arriere()
	_test_horloger_les_coups_apres_le_retour_restent()
	_test_horloger_finit_toujours_par_mourir()
	_test_horloger_plafond_de_retours()
	_test_jumeaux_le_mort_revient_si_l_autre_survit()
	_test_jumeaux_tues_ensemble_meurent_pour_de_bon()
	_test_jumeaux_plafond_de_retours()
	_test_cameleon_faible_et_resiste()
	_test_cameleon_change_et_boucle()
	_test_voleur_vole_puis_lance_contre_le_mage()
	_test_voleur_tue_a_temps_rend_la_carte()
	_test_voleur_laisse_toujours_une_carte_jouable()
	_test_voleur_qui_quitte_le_terrain_rend_la_carte()
	_test_deux_voleurs_rendent_chacun_leur_exemplaire()
	_test_deux_voleurs_lancent_chacun_leur_exemplaire()
	_test_voleur_dont_l_exemplaire_part_ne_prend_pas_celui_du_voisin()
	_test_devoration_soigne_en_pourcentage()
	_test_glouton_historique_grossit_toujours()
	_test_devoreur_invocateur_laisse_murir_puis_avale()
	_test_devoreur_invocateur_affame_si_on_tue_ses_sbires()
	_test_devoreur_invocateur_finit_par_mourir()
	_test_miroir_suit_la_vitesse_du_mage()
	_test_hits_immune_accepte_dix()
	_test_bestiaire_explique_les_six_mecaniques()


# --- 1. L HORLOGER -------------------------------------------------------------

func _horloger(id: String, speed: float = 60.0) -> EnemyDef:
	var d := _def(id, 100.0, speed)
	d.rewind_interval = 6.0
	d.rewind_seconds = 3.0
	return d


## Il revient a la POSITION et aux PV qu il avait `rewind_seconds` plus tot, et le
## fantome montrait bien ce point avant le saut.
func _test_horloger_revient_en_arriere() -> void:
	_fresh()
	var d := _horloger("horloger")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 200.0))
	var v: float = d.base_speed * GameConfig.ENEMY_SPEED_SCALE
	var tol: float = v * Enemy.REWIND_SAMPLE * 3.0 + 1.0
	var periode: float = b.rewind_period()

	# On se place juste apres l instant que le retour visera.
	_sim(periode - d.rewind_seconds + DT)
	var y_alors: float = b.position.y
	var hp_alors: float = b.hp
	# Coup porte dans la zone EFFACEE : moins de `rewind_seconds` avant le retour.
	_sim(d.rewind_seconds * 0.5)
	b.take_damage(hp_alors * 0.3, [])
	ok(b.hp < hp_alors, "le coup mord d abord")
	_sim_until(func() -> bool: return b.rewind_time_left() <= DT * 1.5, periode)
	between(b.rewind_target_position().y, y_alors - tol, y_alors + tol,
		"juste avant le saut, le fantome montre ou il reviendra")
	feq(b.rewind_target_hp(), hp_alors, "et avec quels PV", 0.01)

	var y_avant: float = b.position.y
	var t: float = _sim_until(func() -> bool: return b.rewinds_done() >= 1, periode)
	ok(t >= 0.0, "le retour a bien lieu")
	between(b.position.y, y_alors - tol, y_alors + tol,
		"il reapparait a la position qu il avait %s s plus tot" % d.rewind_seconds)
	ok(b.position.y < y_avant - v * d.rewind_seconds * 0.5,
		"il a RECULE : le retour se voit sur le terrain")
	feq(b.hp, hp_alors, "et il a retrouve les PV d alors : le coup est efface", 0.01)


## LA REPONSE DU JOUEUR : un coup porte juste APRES le retour n est jamais efface.
func _test_horloger_les_coups_apres_le_retour_restent() -> void:
	_fresh()
	var d := _horloger("horloger2")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 200.0))
	var periode: float = b.rewind_period()
	_sim_until(func() -> bool: return b.rewinds_done() >= 1, periode * 2.0)
	b.take_damage(b.max_hp() * 0.3, [])
	var hp_apres: float = b.hp
	var t: float = _sim_until(func() -> bool: return b.rewinds_done() >= 2, periode * 2.0)
	ok(t >= 0.0, "le deuxieme retour a lieu")
	feq(b.hp, hp_apres, "le coup porte juste apres le retour est reste", 0.01)


## GARANTIE DE FIN. Meme un intervalle de contenu degenere (egal a la duree du
## retour, ce qui effacerait TOUT) garde une fenetre : un joueur qui frappe sans
## arret finit par le tuer, en un temps borne.
func _test_horloger_finit_toujours_par_mourir() -> void:
	_fresh()
	var d := _horloger("horloger3", 0.0)
	d.rewind_interval = d.rewind_seconds   # la valeur qui rendrait le boss immortel
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	var periode: float = b.rewind_period()
	ok(periode > d.rewind_seconds, "l intervalle est releve au-dessus de la duree du retour")
	# Sans retour, ce DPS le tuerait en 10 periodes. Avec retours, seule la part
	# (periode - retour) / periode des degats tient.
	var dps: float = b.max_hp() / (periode * 10.0)
	var tenue: float = (periode - d.rewind_seconds) / periode
	# La borne ne doit JAMAIS etre infinie : si la garantie saute (fenetre nulle),
	# le test doit echouer en temps fini, pas faire tourner l etage jusqu au
	# timeout. On la calcule donc sur la fenetre PROMISE, pas sur celle mesuree.
	var promise: float = Enemy.REWIND_MIN_WINDOW / (d.rewind_seconds + Enemy.REWIND_MIN_WINDOW)
	var borne: float = periode * 10.0 / maxf(tenue, promise) + periode * 2.0
	var t: float = 0.0
	while t < borne and not b.is_dead():
		b.take_damage(dps * DT, [])
		_sim(DT)
		t += DT
	ok(b.is_dead(), "frapper sans arret finit par le tuer (%.1f s, borne %.1f s)" % [t, borne])
	ok(b.rewinds_done() >= 1, "et il est bien revenu en arriere en chemin")


## Le plafond dur : au-dela de `rewind_max` retours, il ne revient plus, et son
## fantome disparait (le joueur n a plus rien a attendre).
func _test_horloger_plafond_de_retours() -> void:
	_fresh()
	var d := _horloger("horloger4", 0.0)
	d.rewind_max = 2
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	_sim(b.rewind_period() * (d.rewind_max + 2))
	eq(b.rewinds_done(), d.rewind_max, "il ne revient pas plus de rewind_max fois")
	feq(b.rewind_time_left(), 0.0, "et plus aucun retour n est annonce")
	b.take_damage(b.max_hp() * 0.5, [])
	var hp_apres: float = b.hp
	_sim(b.rewind_period() * 2.0)
	feq(b.hp, hp_apres, "les degats tiennent desormais", 0.01)


# --- 2. LES JUMEAUX ------------------------------------------------------------

func _jumeau(id: String) -> EnemyDef:
	var d := _def(id, 80.0, 0.0)
	d.twin_group = &"soleil_lune"
	d.twin_revive_delay = 2.0
	d.twin_revive_hp_pct = 50.0
	d.twin_max_returns = 2
	d.base_xp = 5
	return d


func _test_jumeaux_le_mort_revient_si_l_autre_survit() -> void:
	_fresh()
	var da := _jumeau("soleil")
	var a: Enemy = _bf.spawn_enemy(da, 300.0, 1.0, Vector2(300.0, 400.0))
	var b: Enemy = _bf.spawn_enemy(_jumeau("lune"), 700.0, 1.0, Vector2(700.0, 400.0))
	a.take_damage(9999.0, [])
	not_ok(a.is_dead(), "tue pendant que son jumeau tient debout, il ne meurt pas")
	ok(a.is_fallen(), "il est A TERRE")
	eq(_bf.alive_count(), 2, "et il compte encore : la vague n est pas finie")
	eq(_tues, 0, "une chute n est pas une mort : ni XP ni statistique")
	not_ok(a.take_damage(1.0, []), "a terre, il est intouchable")
	not_ok(b.is_fallen(), "son jumeau, lui, tient debout")

	_sim(da.twin_revive_delay * 0.5)
	ok(a.is_fallen(), "il reste a terre pendant le delai")
	_sim(da.twin_revive_delay * 0.5 + 0.1)
	not_ok(a.is_fallen(), "l autre a survecu au delai : il se RELEVE")
	feq(a.hp, a.max_hp() * da.twin_revive_hp_pct * 0.01,
		"avec twin_revive_hp_pct de ses PV", 0.01)
	eq(a.twin_returns(), 1, "le retour est compte")


func _test_jumeaux_tues_ensemble_meurent_pour_de_bon() -> void:
	_fresh()
	var da := _jumeau("soleil2")
	var a: Enemy = _bf.spawn_enemy(da, 300.0, 1.0, Vector2(300.0, 400.0))
	var b: Enemy = _bf.spawn_enemy(_jumeau("lune2"), 700.0, 1.0, Vector2(700.0, 400.0))
	a.take_damage(9999.0, [])
	_sim(da.twin_revive_delay * 0.5)
	b.take_damage(9999.0, [])
	ok(b.is_dead(), "le dernier debout meurt pour de bon")
	ok(a.is_dead(), "et entraine son jumeau a terre avec lui")
	_sim(0.1)
	eq(_bf.alive_count(), 0, "le terrain est vide : le combat est fini")
	eq(_tues, 2, "deux morts, deux statistiques, pas une de plus")


## Sans zone, un joueur doit quand meme finir : apres `twin_max_returns` retours,
## le jumeau meurt pour de bon meme si l autre tient debout.
func _test_jumeaux_plafond_de_retours() -> void:
	_fresh()
	var da := _jumeau("soleil3")
	da.twin_max_returns = 1
	var a: Enemy = _bf.spawn_enemy(da, 300.0, 1.0, Vector2(300.0, 400.0))
	var b: Enemy = _bf.spawn_enemy(_jumeau("lune3"), 700.0, 1.0, Vector2(700.0, 400.0))
	for i in da.twin_max_returns:
		a.take_damage(9999.0, [])
		ok(a.is_fallen(), "chute %d : il tombe" % (i + 1))
		_sim(da.twin_revive_delay + 0.1)
		not_ok(a.is_fallen(), "chute %d : il se releve" % (i + 1))
	a.take_damage(9999.0, [])
	ok(a.is_dead(), "retours epuises : la mort suivante est definitive")
	not_ok(b.is_dead(), "meme si son jumeau vit encore")
	_sim(0.1)
	eq(_bf.alive_count(), 1, "il ne reste que l autre")


# --- 3. LE CAMELEON ------------------------------------------------------------

func _cameleon(id: String) -> EnemyDef:
	var d := _def(id, 1000.0, 0.0)
	d.chameleon_interval = 5.0
	d.chameleon_elements = [GameEnums.DamageTag.FIRE, GameEnums.DamageTag.ICE,
		GameEnums.DamageTag.POISON, GameEnums.DamageTag.LIGHTNING]
	d.chameleon_weak_mult = 1.5
	d.chameleon_resist_mult = 0.5
	return d


## Un element neutre (ni faible ni resiste, hors du cycle) pour les comparaisons.
func _neutre(d: EnemyDef) -> int:
	for t in GameEnums.ELEMENTS:
		if not (t in d.chameleon_elements):
			return t
	return -1


func _perte(b: Enemy, amount: float, tags: Array) -> float:
	var avant: float = b.hp
	b.take_damage(amount, tags)
	return avant - b.hp


func _test_cameleon_faible_et_resiste() -> void:
	_fresh()
	var d := _cameleon("cameleon")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	var faible: int = b.chameleon_weak()
	var resiste: int = b.chameleon_resisted()
	ok(faible >= 0 and resiste >= 0, "il a un element faible et un element resiste")
	ok(faible != resiste, "jamais le meme")
	var coup: float = 10.0
	feq(_perte(b, coup, [faible]), coup * d.chameleon_weak_mult, "l element faible le blesse plus", 0.01)
	feq(_perte(b, coup, [resiste]), coup * d.chameleon_resist_mult, "l element resiste moins", 0.01)
	feq(_perte(b, coup, [_neutre(d)]), coup, "un element hors cycle est neutre", 0.01)
	feq(_perte(b, coup, [faible, resiste]), coup * d.chameleon_resist_mult,
		"un sort bi-element retient le PLUS FAIBLE, comme la table resistances", 0.01)
	ok(b.chameleon_caption().contains(GameEnums.tag_name(faible).to_upper()),
		"la legende ECRIT l element faible (lisible sans la couleur)")


func _test_cameleon_change_et_boucle() -> void:
	_fresh()
	var d := _cameleon("cameleon2")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	var vus: Array[int] = [b.chameleon_weak()]
	for i in d.chameleon_elements.size() - 1:
		var avant: int = b.chameleon_weak()
		_sim(d.chameleon_interval + DT)
		ok(b.chameleon_weak() != avant, "changement %d : l element faible a tourne" % (i + 1))
		ok(b.chameleon_caption().contains(GameEnums.tag_name(b.chameleon_weak()).to_upper()),
			"changement %d : la legende suit" % (i + 1))
		vus.append(b.chameleon_weak())
	for t in d.chameleon_elements:
		ok(t in vus, "chaque element du cycle devient faible a son tour (%s)" % GameEnums.tag_name(t))
	_sim(d.chameleon_interval + DT)
	eq(b.chameleon_weak(), vus[0], "le cycle boucle : il repart du premier element")


# --- 4. LE VOLEUR DE SORTS -----------------------------------------------------

func _voleur(id: String) -> EnemyDef:
	var d := _def(id, 100.0, 0.0)
	d.steal_interval = 4.0
	d.steal_cast_delay = 3.0
	d.steal_damage_per_cast_second = 6.0
	return d


## Trois cartes de temps d incantation differents ; rend la plus longue.
func _main_de_trois() -> SpellCard:
	var courte := _card("courte", 1.0)
	var longue := _card("longue", 3.0)
	var moyenne := _card("moyenne", 2.0)
	RunState.hand.clear()
	RunState.hand.append(courte)
	RunState.hand.append(longue)
	RunState.hand.append(moyenne)
	return longue


func _test_voleur_vole_puis_lance_contre_le_mage() -> void:
	_fresh()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var d := _voleur("voleur")
	var longue: SpellCard = _main_de_trois()
	var v: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))

	v.advance(d.steal_interval * 0.5)
	eq(v.stolen_card(), null, "il ne vole pas avant son intervalle")
	v.advance(d.steal_interval * 0.5 + DT)
	eq(v.stolen_card(), longue, "il vole la carte la plus LONGUE a incanter")
	ok(RunState.is_card_stolen(longue), "la main la sait volee")
	ok(RunState.is_card_blocked(longue), "donc injouable, comme une carte petrifiee")
	not_ok(RunState.play_card(longue), "le joueur ne peut pas la lancer")

	var avant: int = SpeedGauge.speed_percent
	v.advance(d.steal_cast_delay * 0.5)
	eq(SpeedGauge.speed_percent, avant, "rien ne part avant le delai")
	v.advance(d.steal_cast_delay * 0.5 + DT)
	var attendu: int = Enemy.stolen_card_damage(d, longue)
	eq(attendu, int(round(longue.base_cast_time * d.steal_damage_per_cast_second)),
		"la regle : secondes d incantation x tarif du voleur")
	eq(avant - SpeedGauge.speed_percent, attendu, "le mage perd exactement ces points de vitesse")
	not_ok(RunState.hand.has(longue), "la carte a quitte la main")
	ok(RunState.discard.has(longue), "elle part a la defausse, comme si on l avait jouee")
	not_ok(RunState.is_card_stolen(longue), "et plus rien n est tenu")
	eq(v.stolen_card(), null, "le voleur a les mains vides : il retourne a la chasse")


func _test_voleur_tue_a_temps_rend_la_carte() -> void:
	_fresh()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var d := _voleur("voleur2")
	var longue: SpellCard = _main_de_trois()
	var v: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	v.advance(d.steal_interval + DT)
	ok(RunState.is_card_stolen(longue), "carte volee")
	var avant: int = SpeedGauge.speed_percent
	v.take_damage(9999.0, [])
	ok(v.is_dead(), "le voleur tombe avant de lancer")
	not_ok(RunState.is_card_stolen(longue), "la carte lui est reprise")
	eq(SpeedGauge.speed_percent, avant, "et le mage n a rien encaisse")
	ok(RunState.play_card(longue), "elle redevient jouable")


## Le plafond de la main vaut pour le voleur comme pour la gorgone : il reste
## TOUJOURS une carte jouable, meme quand les deux se cumulent.
func _test_voleur_laisse_toujours_une_carte_jouable() -> void:
	_fresh()
	var d := _voleur("voleur3")
	RunState.hand.clear()
	for i in RunState.MIN_PLAYABLE_CARDS:
		RunState.hand.append(_card("seule%d" % i, 2.0))
	var v: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	v.advance(d.steal_interval + DT)
	eq(v.stolen_card(), null, "main minimale : il ne peut rien prendre")

	_main_de_trois()
	v.advance(d.steal_interval + DT)
	ok(v.stolen_card() != null, "main plus grande : il vole")
	RunState.set_card_block_count(99)   # une gorgone enorme par-dessus
	var jouables: int = 0
	for c in RunState.hand:
		if not RunState.is_card_blocked(c):
			jouables += 1
	ok(jouables >= RunState.MIN_PLAYABLE_CARDS,
		"voleur + gorgone : il reste %d carte(s) jouable(s)" % jouables)


## Gobe, arrive au mage, fin de partie : un voleur qui quitte le terrain SANS
## mourir doit aussi rendre sa carte.
func _test_voleur_qui_quitte_le_terrain_rend_la_carte() -> void:
	_fresh()
	var d := _voleur("voleur4")
	var longue: SpellCard = _main_de_trois()
	var v: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	v.advance(d.steal_interval + DT)
	ok(RunState.is_card_stolen(longue), "carte volee")
	_bf.enemies.erase(v)
	detach(v)
	not_ok(RunState.is_card_stolen(longue), "le voleur parti, la carte est rendue")


## DEUX VOLEURS, DEUX COPIES D UNE MEME CARTE. Les copies partagent la meme
## ressource : un voleur qui ne retenait que la carte relachait ou lancait la
## PREMIERE copie volee trouvee, donc parfois celle de son voisin. La main est
## [longue, courte, longue, moyenne] : la carte courte entre les deux copies rend
## l erreur VISIBLE, car la copie qui part ou se rallume change de position.
##
## Rend [voleur de gauche, voleur de droite, la carte longue].
func _deux_voleurs(prefixe: String) -> Array:
	_fresh()
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var longue := _card("longue", 3.0)
	RunState.hand.clear()
	RunState.hand.append(longue)
	RunState.hand.append(_card("courte", 1.0))
	RunState.hand.append(longue)
	RunState.hand.append(_card("moyenne", 2.0))
	var d1 := _voleur(prefixe + "_1")
	var d2 := _voleur(prefixe + "_2")
	var v1: Enemy = _bf.spawn_enemy(d1, 500.0, 1.0, Vector2(400.0, 300.0))
	v1.advance(d1.steal_interval + DT)
	var v2: Enemy = _bf.spawn_enemy(d2, 500.0, 1.0, Vector2(600.0, 300.0))
	v2.advance(d2.steal_interval + DT)
	return [v1, v2, longue]


## Position dans la main de l exemplaire que tient ce voleur (-1 : plus rien).
func _place(v: Enemy) -> int:
	return RunState.stolen_slot_of(v.stolen_hold())


func _test_deux_voleurs_rendent_chacun_leur_exemplaire() -> void:
	var r: Array = _deux_voleurs("voleur_rend")
	var v1: Enemy = r[0]
	var v2: Enemy = r[1]
	var longue: SpellCard = r[2]
	eq(v1.stolen_card(), longue, "(le premier voleur prend une copie de la longue)")
	eq(v2.stolen_card(), longue, "(le second prend l autre copie)")
	var gauche: int = _place(v1)
	var droite: int = _place(v2)
	ok(gauche >= 0 and droite >= 0 and gauche != droite,
		"chaque voleur tient un exemplaire DIFFERENT")
	v2.take_damage(9999.0, [])
	ok(v2.is_dead(), "(le second voleur tombe)")
	not_ok(RunState.is_slot_stolen(droite), "SON exemplaire se rallume, a sa place")
	ok(RunState.is_slot_stolen(gauche), "celui du premier voleur reste tenu")
	eq(_place(v1), gauche, "et le premier voleur le sait toujours au meme endroit")
	ok(RunState.play_card(longue, droite), "le joueur lance la copie rendue")
	ok(RunState.is_slot_stolen(_place(v1)), "la copie du premier voleur, elle, reste grisee")


func _test_deux_voleurs_lancent_chacun_leur_exemplaire() -> void:
	var r: Array = _deux_voleurs("voleur_lance")
	var v1: Enemy = r[0]
	var v2: Enemy = r[1]
	var longue: SpellCard = r[2]
	var gauche: int = _place(v1)
	var droite: int = _place(v2)
	ok(gauche < droite, "(le premier voleur tient la copie de gauche)")
	var entre: SpellCard = RunState.hand[gauche + 1]
	ok(entre != longue, "(une autre carte separe les deux copies)")
	var taille: int = RunState.hand.size()
	# Seul le second voleur arrive au bout de son delai.
	v2.advance(v2.definition.steal_cast_delay + DT)
	eq(v2.stolen_card(), null, "(le second voleur a lance)")
	eq(RunState.hand.size(), taille - 1, "une seule carte a quitte la main")
	eq(RunState.hand[gauche], longue, "la copie de GAUCHE, celle du premier voleur, est restee")
	eq(RunState.hand[gauche + 1], entre, "la carte voisine n a pas bouge : c est bien la droite qui est partie")
	eq(_place(v1), gauche, "le premier voleur tient toujours sa copie, a sa place")
	# Au tour du premier : c est sa copie qui part, pas une autre.
	v1.advance(v1.definition.steal_cast_delay + DT)
	eq(RunState.hand.size(), taille - 2, "le premier voleur lance a son tour")
	not_ok(RunState.hand.has(longue), "et plus aucune copie de la longue n est en main")


## Un exemplaire vole quitte la main par un autre chemin : SON voleur doit le
## savoir, meme si une copie jumelle reste tenue par l autre. Par la carte, il se
## croyait encore arme et lancait ensuite la copie du voisin.
func _test_voleur_dont_l_exemplaire_part_ne_prend_pas_celui_du_voisin() -> void:
	var r: Array = _deux_voleurs("voleur_perd")
	var v1: Enemy = r[0]
	var v2: Enemy = r[1]
	var gauche: int = _place(v1)
	var droite: int = _place(v2)
	# La main change sans passer par RunState (un test, une reconstruction).
	RunState.hand[droite] = _card("remplacante", 1.0)
	v2.advance(DT)
	eq(v2.stolen_card(), null, "le second voleur voit que SA copie est partie")
	ok(v1.stolen_card() != null, "le premier garde la sienne")
	eq(_place(v1), gauche, "a la meme place")
	var taille: int = RunState.hand.size()
	v2.advance(v2.definition.steal_cast_delay + DT)
	eq(RunState.hand.size(), taille, "le second voleur ne lance pas la copie du premier")
	eq(_place(v1), gauche, "qui est toujours tenue par son voleur")


# --- 5. LE DEVOREUR-INVOCATEUR -------------------------------------------------

func _proie(id: String, hp: float) -> EnemyDef:
	var p := _def(id, hp, 0.0, 1)
	return p


func _test_devoration_soigne_en_pourcentage() -> void:
	_fresh()
	var d := _def("glouton_soin", 200.0, 0.0, 4)
	d.kind = GameEnums.EnemyKind.DEVOURER
	d.devours = true
	d.devour_heal_pct = 50.0
	var g: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	g.take_damage(g.max_hp() * 0.5, [])
	var hp_avant: float = g.hp
	var max_avant: float = g.max_hp()
	var p: Enemy = _bf.spawn_enemy(_proie("proie", 40.0), 500.0, 1.0, Vector2(500.0, 520.0))
	p.take_damage(p.max_hp() * 0.25, [])
	var pv_avales: float = p.hp
	_sim(DT * 2.0)
	eq(_bf.alive_count(), 1, "la proie a ete avalee")
	feq(g.hp - hp_avant, pv_avales * d.devour_heal_pct * 0.01,
		"soin = devour_heal_pct des PV RESTANTS de la proie", 0.01)
	feq(g.max_hp(), max_avant, "avec un soin, il ne grossit plus : son maximum ne bouge pas")
	feq(g.growth, 1.0, "ni sa taille")


## Garde-fou : le Glouton historique (sans soin) garde exactement sa regle.
func _test_glouton_historique_grossit_toujours() -> void:
	_fresh()
	var d := _def("glouton", 200.0, 0.0, 4)
	d.devours = true
	var g: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	var max_avant: float = g.max_hp()
	var p: Enemy = _bf.spawn_enemy(_proie("proie2", 40.0), 500.0, 1.0, Vector2(500.0, 520.0))
	var gain: float = p.max_hp() * 0.5
	_sim(DT * 2.0)
	feq(g.max_hp() - max_avant, gain, "il gagne toujours la moitie des PV max de la proie", 0.01)
	ok(g.growth > 1.0, "et il grossit")


func _devoreur_invocateur(id: String) -> EnemyDef:
	var d := _def(id, 300.0, 0.0)
	d.devours = true
	d.devour_heal_pct = 100.0
	d.devour_delay = 3.0
	d.summon_interval = 4.0
	d.summon_count = 1
	d.summon_max_alive = 3
	# Un sbire qui BOUGE : le rappel doit l avaler meme hors de portee de gueule.
	d.summon_def = _proie(id + "_sbire", 30.0)
	d.summon_def.base_speed = 60.0
	return d


func _test_devoreur_invocateur_laisse_murir_puis_avale() -> void:
	_fresh()
	var d := _devoreur_invocateur("ogre")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	b.take_damage(b.max_hp() * 0.5, [])
	var hp_blesse: float = b.hp
	_sim(d.summon_interval + DT)
	eq(_bf.alive_count(), 2, "il invoque un sbire")
	_sim(d.devour_delay * 0.5)
	eq(_bf.alive_count(), 2, "le sbire n est PAS avale tout de suite : il murit")
	eq(b.hp, hp_blesse, "et rien n a ete soigne")
	_sim(d.devour_delay * 0.5 + DT * 6.0)
	eq(_bf.alive_count(), 1, "mur, le sbire est RAPPELE et avale")
	ok(b.hp > hp_blesse, "et le boss s est soigne")
	ok(b.hp <= b.max_hp(), "sans depasser son maximum")


## LA REPONSE DU JOUEUR : tuer les sbires avant qu ils murissent l affame.
func _test_devoreur_invocateur_affame_si_on_tue_ses_sbires() -> void:
	_fresh()
	var d := _devoreur_invocateur("ogre2")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	b.take_damage(b.max_hp() * 0.5, [])
	var hp_blesse: float = b.hp
	_sim(d.summon_interval + DT)
	for e in _bf.enemies.duplicate():
		if e != b:
			e.take_damage(9999.0, [])
	_sim(d.devour_delay + DT)
	eq(b.hp, hp_blesse, "sbire tue avant maturite : aucun soin")


## Il finit par mourir : chaque proie ne soigne que ses PV restants, borne au
## maximum, et le plafond de sbires borne le debit de soin.
func _test_devoreur_invocateur_finit_par_mourir() -> void:
	_fresh()
	var d := _devoreur_invocateur("ogre3")
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	# Debit de soin MAXIMAL : un sbire plein par invocation, soigne a 100 %.
	var soin_max: float = d.summon_def.max_hp * d.summon_count * d.devour_heal_pct * 0.01 \
		/ d.summon_interval
	var dps: float = soin_max * 2.0 + b.max_hp() / (d.summon_interval * 5.0)
	var borne: float = b.max_hp() / (dps - soin_max) + d.summon_interval * 2.0
	var t: float = 0.0
	var max_vu: float = 0.0
	while t < borne and not b.is_dead():
		b.take_damage(dps * DT, [])
		_sim(DT)
		max_vu = maxf(max_vu, b.hp)
		t += DT
	ok(b.is_dead(), "un DPS superieur au soin maximal le tue (%.1f s, borne %.1f s)" % [t, borne])
	ok(max_vu <= b.max_hp() + 0.01, "ses PV n ont jamais depasse son maximum")


# --- 6. LE MIROIR DU MAGE ------------------------------------------------------

## Distance parcourue en une seconde de monde, a une vitesse de mage donnee.
func _pas(e: Enemy, pct: int) -> float:
	SpeedGauge.set_speed_percent(pct)
	var y0: float = e.position.y
	e.advance(1.0)
	return e.position.y - y0


func _test_miroir_suit_la_vitesse_du_mage() -> void:
	_fresh()
	var ref: int = int(GameConfig.SPEED_MAX_PERCENT * 0.5)
	var d := _def("miroir_mage", 100.0, 40.0)
	d.mirror_speed_ref = ref
	d.mirror_speed_min = 0.5
	d.mirror_speed_max = 2.0
	var m: Enemy = _bf.spawn_enemy(d, 300.0, 1.0, Vector2(300.0, 200.0))
	var n: Enemy = _bf.spawn_enemy(_def("temoin", 100.0, 40.0), 700.0, 1.0, Vector2(700.0, 200.0))

	feq(_pas(m, ref), _pas(n, ref), "a la vitesse de reference, il va a sa vitesse de base", 0.01)
	var pct_haut: int = mini(ref * 2, GameConfig.SPEED_MAX_PERCENT)
	var attendu_haut: float = clampf(float(pct_haut) / ref, d.mirror_speed_min, d.mirror_speed_max)
	feq(_pas(m, pct_haut) / _pas(n, pct_haut), attendu_haut,
		"mage plus rapide : le miroir aussi, au rapport des vitesses", 0.01)
	var pct_bas: int = 100
	var attendu_bas: float = clampf(float(pct_bas) / ref, d.mirror_speed_min, d.mirror_speed_max)
	feq(_pas(m, pct_bas) / _pas(n, pct_bas), attendu_bas,
		"mage blesse, donc lent : le miroir ralentit, borne au minimum", 0.01)

	# La borne haute : un facteur qui suivrait sans limite rendrait le boss
	# injouable en fin de partie.
	d.mirror_speed_max = 1.25
	SpeedGauge.set_speed_percent(pct_haut)
	feq(m.mirror_factor(), d.mirror_speed_max, "le facteur est plafonne a mirror_speed_max", 0.01)

	# LA VITESSE EST LA VIE : un coup recu ralentit le miroir.
	d.mirror_speed_max = 2.0
	SpeedGauge.set_speed_percent(pct_haut)
	var avant: float = m.mirror_factor()
	SpeedGauge.take_hit(int(ref * 0.5))
	ok(m.mirror_factor() < avant, "un coup encaisse par le mage ralentit le miroir")
	feq(n.mirror_factor(), 1.0, "un monstre ordinaire n a pas de facteur miroir")


# --- hits_immune a 10 -----------------------------------------------------------

## Le co-auteur veut un boss immunise aux 10 premiers coups : la borne du champ
## doit l accepter, et la mecanique doit tenir a cette valeur.
func _test_hits_immune_accepte_dix() -> void:
	_fresh()
	var voulu: int = 10
	var borne_max: int = -1
	for p in EnemyDef.new().get_property_list():
		if str(p.get("name", "")) == "hits_immune":
			var morceaux: PackedStringArray = str(p.get("hint_string", "")).split(",")
			if morceaux.size() >= 2:
				borne_max = int(morceaux[1])
	ok(borne_max >= voulu, "la borne d edition de hits_immune accepte %d (max %d)" % [voulu, borne_max])

	var d := _def("reliquaire10", 100.0, 0.0)
	d.hits_immune = voulu
	var b: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	for i in voulu:
		not_ok(b.take_damage(9999.0, []), "coup %d absorbe" % (i + 1))
	feq(b.hp, b.max_hp(), "dix coups, aucun degat")
	ok(b.take_damage(10.0, []), "le onzieme mord")


# --- Bestiaire ------------------------------------------------------------------

func _contient(lignes: Array[String], mot: String) -> bool:
	for l in lignes:
		if l.contains(mot):
			return true
	return false


## Chaque mecanique est expliquee EN CLAIR avec ses chiffres : un joueur qui la
## decouvre en combat sans l avoir lue croit que le jeu est casse.
func _test_bestiaire_explique_les_six_mecaniques() -> void:
	var h := _horloger("h")
	var lh: Array[String] = BestiaryLore.behaviours(h)
	ok(_contient(lh, BestiaryLore._num(Enemy._rewind_period(h)) + " s"), "Horloger : son intervalle")
	ok(_contient(lh, BestiaryLore._num(h.rewind_seconds) + " s en arriere"), "Horloger : sa duree")
	ok(_contient(lh, "APRES"), "Horloger : la reponse (frapper apres)")

	var j := _jumeau("j")
	var lj: Array[String] = BestiaryLore.behaviours(j)
	ok(_contient(lj, BestiaryLore._num(j.twin_revive_delay) + " s"), "Jumeaux : le delai")
	ok(_contient(lj, "%d fois" % j.twin_max_returns), "Jumeaux : le plafond")

	var c := _cameleon("c")
	var lc: Array[String] = BestiaryLore.behaviours(c)
	ok(_contient(lc, "FAIBLE"), "Cameleon : la regle")
	ok(_contient(lc, GameEnums.tag_name(c.chameleon_elements[0])), "Cameleon : son cycle")

	var v := _voleur("v")
	var lv: Array[String] = BestiaryLore.behaviours(v)
	ok(_contient(lv, BestiaryLore._num(v.steal_damage_per_cast_second) + " points"), "Voleur : le tarif")
	ok(_contient(lv, "defausse"), "Voleur : ce que devient la carte")

	var o := _devoreur_invocateur("o")
	var lo: Array[String] = BestiaryLore.behaviours(o)
	ok(_contient(lo, "%d %%" % int(round(o.devour_heal_pct))), "Devoreur : le soin")
	not_ok(_contient(lo, "grossit"), "Devoreur soigneur : la fiche ne dit plus qu il grossit")

	var m := _def("m")
	m.mirror_speed_ref = int(GameConfig.SPEED_MAX_PERCENT * 0.5)
	var lm: Array[String] = BestiaryLore.behaviours(m)
	ok(_contient(lm, "%d %%" % m.mirror_speed_ref), "Miroir : sa vitesse de reference")
