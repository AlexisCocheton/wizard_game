extends TestCase
## LA RESISTANCE S APPLIQUE AUX EFFETS (vague 5), pas seulement aux degats.
##
## Demande du co-auteur : « un monstre qui resiste a la glace resistera a ses
## ralentissements ; un monstre qui resiste au vent sera moins attire ; adapte
## aux autres effets ». Chaque verbe de controle est verifie ici sur un vrai
## Battlefield, par COMPARAISON entre un monstre neutre et un monstre resistant
## a l element de la carte : aucun reglage de contenu n y est ecrit en dur, seul
## le rapport compte (voir gotchas, « un test qui fige une valeur de reglage »).
##
## Rappel de la regle (EnemyDef.control_factor) : facteur = resistance a
## l element de la carte, plafonnee a 1 ; pour un RALENTISSEMENT, le plus petit
## de ce facteur et de la ligne SLOW.

func get_suite_name() -> String:
	return "resist_effects"


var _bf: Battlefield = null

const T := GameEnums.DamageTag


func _def(id: String, table: Dictionary = {}, speed: float = 60.0) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = 500.0
	d.base_speed = speed
	d.power = 1
	d.resistances = table
	return d


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()


## Monde a x1, mage maintenu en vie (meme raison que test_enemy_behaviors).
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(1.0 / 60.0)
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
		t += 1.0 / 60.0


func _card(tags: Array) -> SpellCard:
	var c := SpellCard.new()
	c.id = &"t_effet"
	for t in tags:
		c.tags.append(t)
	return c


func run() -> void:
	_test_le_facteur_suit_la_regle()
	_test_le_champ_de_givre_ralentit_moins_un_monstre_de_glace()
	_test_le_ralentissement_global_respecte_la_resistance()
	_test_l_etourdissement_lit_l_element()
	_test_le_repoussement_lit_l_element()
	_test_l_aspiration_lit_l_element()
	_test_la_provocation_lit_l_element()
	_test_la_volte_face_lit_l_element()
	_test_la_vulnerabilite_lit_l_element()
	_test_la_dissipation_lit_l_element()
	_test_le_courant_lit_l_element()
	_test_le_cameleon_reste_coherent()
	_test_les_handlers_transmettent_l_element()
	if _bf != null:
		detach(_bf)
		_bf = null


func _test_le_facteur_suit_la_regle() -> void:
	var neutre := _def("neutre")
	feq(neutre.control_factor([T.FROST]), 1.0, "sans resistance, l effet est entier")
	var glace := _def("glace", {T.FROST: 0.4})
	feq(glace.control_factor([T.FROST]), 0.4, "l element de la carte attenue l effet")
	feq(glace.control_factor([T.FIRE]), 1.0, "un autre element n est pas attenue")
	var fragile := _def("fragile", {T.FROST: 1.8})
	feq(fragile.control_factor([T.FROST]), 1.0,
		"une FAIBLESSE ne renforce pas le controle (plafond a 1)")
	var lourd := _def("lourd", {T.SLOW: 0.0, T.FROST: 1.0})
	feq(lourd.control_factor([T.FROST, T.SLOW], true), 0.0,
		"un ralentissement lit aussi la ligne SLOW")
	feq(lourd.control_factor([T.FROST, T.SLOW], false), 1.0,
		"un effet qui ne ralentit pas ignore la ligne SLOW")
	var bi := _def("bi", {T.FIRE: 0.3, T.PHYSICAL: 1.5})
	feq(bi.control_factor([T.FIRE, T.PHYSICAL]), 0.3,
		"sort bi-element : le pire element pour le joueur, comme les degats")


## Descente en une seconde dans une zone de ralentissement de la carte.
func _descente_en_zone(def: EnemyDef, tags: Array, ralentit: bool = true) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 500.0))
	_bf.spawn_ground_zone(Vector2(540.0, 560.0), 400.0, 5.0, 0.0,
		50.0 if ralentit else 0.0, _card(tags))
	var y0: float = e.position.y
	_sim(1.0)
	return e.position.y - y0


func _test_le_champ_de_givre_ralentit_moins_un_monstre_de_glace() -> void:
	var givre: Array = [T.FROST, T.SLOW]
	var libre: float = _descente_en_zone(_def("temoin"), givre, false)
	var neutre: float = _descente_en_zone(_def("neutre"), givre)
	var glace: float = _descente_en_zone(_def("glace", {T.FROST: 0.3}), givre)
	var immobile: float = _descente_en_zone(_def("lourd", {T.SLOW: 0.0}), givre)
	ok(neutre < libre - 1.0, "le champ de givre ralentit un monstre neutre")
	ok(glace > neutre + 1.0, "un monstre qui resiste au GIVRE est moins ralenti")
	ok(glace < libre - 0.5, "mais il l est encore un peu (resistance, pas immunite)")
	feq(immobile, libre, "immunise au ralentissement : aucun effet", 0.5)


func _vitesse_sous_entrave(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 500.0))
	_bf.apply_global_enemy_slow(50.0, 5.0, tags)
	_bf.simulate(1.0 / 60.0)
	return e.speed_scale


func _test_le_ralentissement_global_respecte_la_resistance() -> void:
	var entrave: Array = [T.ARCANE, T.SLOW]
	var neutre: float = _vitesse_sous_entrave(_def("neutre"), entrave)
	var arcane: float = _vitesse_sous_entrave(_def("rune", {T.ARCANE: 0.5}), entrave)
	var lourd: float = _vitesse_sous_entrave(_def("lourd", {T.SLOW: 0.0}), entrave)
	ok(neutre < 1.0, "l entrave ralentit un monstre neutre")
	ok(arcane > neutre and arcane < 1.0, "un monstre qui resiste a l arcane est moins ralenti")
	feq(lourd, 1.0, "immunise au ralentissement, l entrave ne le touche pas", 0.001)
	# Une ACCELERATION des monstres (Pacte temeraire) est un prix paye par le
	# joueur : aucun monstre n y « resiste ».
	_fresh()
	var e: Enemy = _bf.spawn_enemy(_def("lourd2", {T.SLOW: 0.0, T.LIGHTNING: 0.2}),
		540.0, 1.0, Vector2(540.0, 500.0))
	_bf.apply_global_enemy_slow(-50.0, 5.0, [T.LIGHTNING])
	_bf.simulate(1.0 / 60.0)
	ok(e.speed_scale > 1.0, "une acceleration n est jamais attenuee")


func _test_l_etourdissement_lit_l_element() -> void:
	_fresh()
	var foudre: Array = [T.LIGHTNING]
	var neutre: Enemy = _bf.spawn_enemy(_def("neutre"), 400.0, 1.0, Vector2(400.0, 500.0))
	var isole: Enemy = _bf.spawn_enemy(_def("isole", {T.LIGHTNING: 0.2}), 700.0, 1.0,
		Vector2(700.0, 500.0))
	var tenace: Enemy = _bf.spawn_enemy(_def("tenace", {T.LIGHTNING: 0.75}), 550.0, 1.0,
		Vector2(550.0, 800.0))
	ok(neutre.apply_stun(1.0, foudre), "un monstre neutre est fige par la foudre")
	not_ok(isole.apply_stun(1.0, foudre),
		"un monstre qui resiste FORT a la foudre echappe a la Racine de tonnerre")
	ok(isole.apply_stun(1.0, [T.FIRE]), "mais un etourdissement d un autre element le fige")
	ok(tenace.apply_stun(1.0, foudre), "une resistance moderee laisse passer l etourdissement")
	# ... pour moins longtemps : au-dela de la duree raccourcie, il est libre.
	_sim(0.85)
	ok(neutre.is_stunned(), "le neutre est encore fige")
	not_ok(tenace.is_stunned(), "le resistant est deja libre : sa duree a ete raccourcie")


## Recul d un monstre sous une Onde de repulsion posee juste sous lui.
func _recul(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 900.0))
	_bf.knockback_from(Vector2(540.0, 1000.0), 300.0, 200.0, tags)
	return 900.0 - e.position.y


func _test_le_repoussement_lit_l_element() -> void:
	var phys: Array = [T.PHYSICAL]
	var neutre: float = _recul(_def("neutre"), phys)
	var roc: float = _recul(_def("roc", {T.PHYSICAL: 0.5}), phys)
	ok(neutre > 1.0, "le souffle repousse un monstre neutre")
	feq(roc / neutre, 0.5, "resistant a 50 % au physique, il recule moitie moins", 0.02)
	feq(_recul(_def("mur", {T.PHYSICAL: 0.0}), phys), 0.0,
		"immunise a l element, il ne bouge pas", 0.01)


func _aspiration(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 300.0, 1.0, Vector2(300.0, 900.0))
	_bf.spawn_vortex(Vector2(540.0, 900.0), 400.0, 5.0, 60.0, tags)
	# Une image : le monstre marche aussi, on ne mesure que l ecart HORIZONTAL.
	_bf.simulate(1.0 / 60.0)
	return e.position.x - 300.0


func _test_l_aspiration_lit_l_element() -> void:
	var arcane: Array = [T.ARCANE]
	var neutre: float = _aspiration(_def("neutre"), arcane)
	var rune: float = _aspiration(_def("rune", {T.ARCANE: 0.25}), arcane)
	ok(neutre > 0.0, "la spirale aspire un monstre neutre")
	feq(rune / neutre, 0.25, "resistant a l arcane, il est aspire d autant moins vite", 0.02)


func _test_la_provocation_lit_l_element() -> void:
	_fresh()
	var totem: TerrainProp = _bf.spawn_prop(TerrainProp.Kind.TREE, Vector2(540.0, 900.0),
		0.0, 100.0, 300.0, 0.0, 0.0, "", Color.WHITE, [T.PHYSICAL])
	# A 200 px : dans la portee pleine (300), hors de la portee d un monstre qui
	# resiste a 50 % au physique (150).
	var point := Vector2(540.0, 700.0)
	var neutre: Enemy = _bf.spawn_enemy(_def("neutre"), 540.0, 1.0, point)
	var roc: Enemy = _bf.spawn_enemy(_def("roc", {T.PHYSICAL: 0.5}), 540.0, 1.0, point)
	ok(_bf.taunt_target_for(point, neutre) == totem, "un monstre neutre est attire")
	ok(_bf.taunt_target_for(point, roc) == null,
		"un monstre qui resiste a l element du totem n est attire que de pres")
	ok(_bf.taunt_target_for(Vector2(540.0, 800.0), roc) == totem,
		"de pres, il cede quand meme")
	ok(_bf.taunt_target_for(point) == totem, "sans monstre designe, portee pleine")


func _remontee(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 900.0))
	_bf.apply_reverse(2.0, tags)
	_sim(0.5)
	return 900.0 - e.position.y


func _test_la_volte_face_lit_l_element() -> void:
	var arcane: Array = [T.ARCANE]
	var neutre: float = _remontee(_def("neutre", {}, 100.0), arcane)
	var rune: float = _remontee(_def("rune", {T.ARCANE: 0.5}, 100.0), arcane)
	var sourd: float = _remontee(_def("sourd", {T.ARCANE: 0.0}, 100.0), arcane)
	ok(neutre > 1.0, "la volte-face fait remonter un monstre neutre")
	feq(rune / neutre, 0.5, "resistant a l arcane, il remonte moitie moins vite", 0.05)
	ok(sourd < 0.0, "immunise, il ne se retourne pas et continue de descendre")


func _test_la_vulnerabilite_lit_l_element() -> void:
	_fresh()
	var marque: SpellCard = _card([T.ARCANE])
	_bf.spawn_ground_zone(Vector2(540.0, 900.0), 300.0, 5.0, 0.0, 0.0, marque, 2.0)
	var neutre: Enemy = _bf.spawn_enemy(_def("neutre"), 540.0, 1.0, Vector2(540.0, 900.0))
	var rune: Enemy = _bf.spawn_enemy(_def("rune", {T.ARCANE: 0.5, T.FIRE: 1.0}), 560.0, 1.0,
		Vector2(560.0, 900.0))
	var feu: SpellCard = _card([T.FIRE])
	var pv_n: float = neutre.hp
	var pv_r: float = rune.hp
	_bf.damage_enemy(neutre, 20.0, feu)
	_bf.damage_enemy(rune, 20.0, feu)
	var perte_n: float = pv_n - neutre.hp
	var perte_r: float = pv_r - rune.hp
	feq(perte_n, 40.0, "dans la marque x2, un monstre neutre prend le double", 0.01)
	# Le BONUS est attenue (x1 + 1 * 0,5), pas le multiplicateur entier.
	feq(perte_r / 20.0, 1.5, "resistant a l element de la marque : bonus reduit de moitie", 0.01)


func _test_la_dissipation_lit_l_element() -> void:
	_fresh()
	var protege := _def("protege")
	protege.first_hit_shield = true
	var armure := _def("armure", {T.ARCANE: 0.3})
	armure.first_hit_shield = true
	var a: Enemy = _bf.spawn_enemy(protege, 500.0, 1.0, Vector2(500.0, 900.0))
	var b: Enemy = _bf.spawn_enemy(armure, 580.0, 1.0, Vector2(580.0, 900.0))
	var n: int = _bf.dispel_at(Vector2(540.0, 900.0), 200.0, [T.ARCANE])
	eq(n, 1, "un seul monstre dissipe")
	var pv_a: float = a.hp
	var pv_b: float = b.hp
	_bf.damage_enemy(a, 10.0, _card([T.FIRE]))
	_bf.damage_enemy(b, 10.0, _card([T.FIRE]))
	ok(a.hp < pv_a, "le bouclier du monstre neutre est tombe")
	feq(b.hp, pv_b, "l armure qui avale l arcane garde son bouclier", 0.001)


func _recul_courant(def: EnemyDef, tags: Array) -> float:
	_fresh()
	var e: Enemy = _bf.spawn_enemy(def, 540.0, 1.0, Vector2(540.0, 900.0))
	_bf.spawn_prop(TerrainProp.Kind.WATER, Vector2(540.0, 900.0), 5.0, 0.0, 0.0,
		200.0, 300.0, "", Color.WHITE, tags)
	_sim(0.5)
	return 900.0 - e.position.y


func _test_le_courant_lit_l_element() -> void:
	var eau: Array = [T.FROST, T.SLOW]
	var neutre: float = _recul_courant(_def("neutre"), eau)
	var glace: float = _recul_courant(_def("glace", {T.FROST: 0.2}), eau)
	ok(neutre > 1.0, "la nappe fait reculer un monstre neutre")
	ok(glace < neutre - 1.0, "un monstre de glace recule moins dans la nappe de givre")


## Le Cameleon change d element resiste : ses EFFETS doivent tourner avec ses
## degats, sinon sa teinte mentirait une fois sur deux.
func _test_le_cameleon_reste_coherent() -> void:
	_fresh()
	var d := _def("cameleon")
	d.chameleon_interval = 5.0
	d.chameleon_elements = [T.FIRE, T.POISON, T.FROST, T.LIGHTNING]
	d.chameleon_weak_mult = 2.0
	d.chameleon_resist_mult = 0.3
	var c: Enemy = _bf.spawn_enemy(d, 540.0, 1.0, Vector2(540.0, 700.0))
	var faible: int = c.chameleon_weak()
	var resiste: int = c.chameleon_resisted()
	feq(c.control_factor([faible]), 1.0, "l element faible passe entier (plafond)")
	feq(c.control_factor([resiste]), d.chameleon_resist_mult,
		"l element resiste du moment attenue aussi les effets", 0.001)
	_sim(d.chameleon_interval + 0.1)
	ok(c.chameleon_resisted() != resiste, "le cycle a tourne")
	if c.chameleon_resisted() != resiste and c.chameleon_weak() != resiste:
		feq(c.control_factor([resiste]), 1.0, "l ancien element resiste ne l est plus", 0.001)
	feq(c.control_factor([c.chameleon_resisted()]), d.chameleon_resist_mult,
		"le nouvel element resiste attenue a son tour", 0.001)


## Les handlers doivent TRANSMETTRE l element de la carte : un parametre `tags`
## qui resterait a sa valeur par defaut rendrait toute la regle inerte en jeu,
## alors que les tests ci-dessus, qui appellent Battlefield directement,
## resteraient verts. On joue donc les VRAIES cartes par le registre d effets.
func _test_les_handlers_transmettent_l_element() -> void:
	var cles: Dictionary = {
		&"knockback": "repousse", &"vortex_pull": "aspire", &"stun_zone": "fige",
	}
	for id in ContentDB.cards.keys():
		var card: SpellCard = ContentDB.cards[id]
		var cle: StringName = &""
		for k in card.effect_keys():
			if cles.has(k):
				cle = k
		if cle == &"" or card.tags.is_empty():
			continue
		# Un monstre IMMUNISE a tous les elements de la carte : si l element est
		# bien transmis, l effet ne doit RIEN lui faire.
		var table: Dictionary = {}
		for t in card.tags:
			table[t] = 0.0
		_fresh()
		var e: Enemy = _bf.spawn_enemy(_def("sourd", table, 0.0), 540.0, 1.0, Vector2(540.0, 900.0))
		var ctx := CastContext.new()
		ctx.card = card
		ctx.battlefield = _bf
		ctx.target_position = Vector2(560.0, 920.0)
		ctx.target_enemy = e
		ctx.direction = Vector2.UP
		EffectRegistry.cast(card, ctx)
		_sim(0.3)
		feq(e.position.distance_to(Vector2(540.0, 900.0)), 0.0,
			"%s : l element de la carte atteint l effet (%s)" % [id, cles[cle]], 0.5)
		not_ok(e.is_stunned(), "%s : un monstre immunise a son element n est pas fige" % id)
