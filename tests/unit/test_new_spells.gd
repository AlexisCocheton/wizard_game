extends TestCase
## Les sorts demandes par le testeur : repousse, vortex, dissipation, pioche
## immediate, mur permanent cassable, retention de carte, double incantation,
## pluie de meteorites et grande zone de poison.
##
## Chaque verification porte sur une REGLE (l ennemi s eloigne, le buff tombe,
## la carte revient en main), jamais sur une valeur d equilibrage : sinon le
## harnais empecherait de regler les sorts au lieu de les proteger.

func get_suite_name() -> String:
	return "new_spells"


# --- Outils ---

func _card(key: StringName, magnitude: float = 0.0, duration: float = 0.0,
		radius: float = 0.0, params: Dictionary = {}) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName("t_" + String(key))
	c.display_name = "Test " + String(key)
	c.base_cast_time = 1.0
	var sp := EffectSpec.new()
	sp.key = key
	sp.magnitude = magnitude
	sp.duration = duration
	sp.radius = radius
	sp.params = params
	c.effects = [sp]
	return c


## Un champ de bataille attache a l arbre : les monstres ont besoin de _ready().
func _field() -> Battlefield:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _dummy_def(id: String = "t_dummy") -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = "Cible"
	d.max_hp = 200.0
	d.base_speed = 0.0
	d.base_radius = 24.0
	d.base_xp = 1
	return d


func run() -> void:
	_test_handlers_enregistres()
	_test_knockback_repousse_et_blesse()
	_test_vortex_attire_vers_le_centre()
	_test_vortex_expire()
	_test_dispel_retire_les_buffs()
	_test_dispel_epargne_le_hors_zone()
	_test_draw_cards_pioche_sans_defausser()
	_test_mur_permanent_ne_disparait_pas()
	_test_mur_permanent_casse_sous_les_coups()
	_test_retain_next_garde_la_carte_en_main()
	_test_retain_next_ne_dure_qu_un_sort()
	_test_double_cast_autorise_deux_incantations()
	_test_double_cast_expire()
	_test_meteor_storm_frappe_toute_la_carte()
	_test_poison_field_est_une_zone_longue()
	_test_les_cartes_existent_dans_le_pool()
	_test_l_allie_invoque_est_visible()
	# Chantier H : les quatre sorts de TERRAIN (arbre provocateur, arbre a poison,
	# etourdissement, nappe d eau). Voir la section en bas de fichier.
	run_terrain_spells()


# --- 0. Enregistrement ---

func _test_handlers_enregistres() -> void:
	for key in [&"knockback", &"vortex_pull", &"dispel_zone", &"draw_cards",
			&"retain_next", &"double_cast", &"meteor_storm"]:
		ok(EffectRegistry.has_key(key), "handler '%s' enregistre" % key)


# --- 1. Repousse ---

func _test_knockback_repousse_et_blesse() -> void:
	var bf := _field()
	var centre := Vector2(540.0, 900.0)
	# Un monstre legerement sous le centre : il doit etre pousse vers le HAUT.
	var e: Enemy = bf.spawn_enemy(_dummy_def(), 540.0, 1.0, centre + Vector2(0.0, 40.0))
	var pv_avant: float = e.hp
	var y_avant: float = e.position.y

	var card := _card(&"knockback", 20.0, 0.0, 200.0, {&"push": 160.0})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)

	ok(e.position.y > y_avant, "le monstre est repousse a l oppose du centre")
	ok(e.hp < pv_avant, "la repousse inflige aussi des degats")
	# Hors du terrain, jamais : le monstre resterait invisible et increvable.
	between(e.position.x, 0.0, GameConfig.BATTLEFIELD_WIDTH,
		"la repousse garde le monstre dans le terrain")
	detach(bf)


# --- 2. Vortex ---

func _test_vortex_attire_vers_le_centre() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 900.0)
	var e: Enemy = bf.spawn_enemy(_dummy_def(), 540.0, 1.0, centre + Vector2(300.0, 0.0))
	var distance_avant: float = e.position.distance_to(centre)

	var card := _card(&"vortex_pull", 300.0, 3.0, 420.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	eq(bf.vortex_count(), 1, "un vortex est en place")

	for i in 60:
		bf.simulate(1.0 / 60.0)

	ok(e.position.distance_to(centre) < distance_avant,
		"le monstre se rapproche du centre de la spirale")
	detach(bf)


func _test_vortex_expire() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var card := _card(&"vortex_pull", 300.0, 1.0, 400.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 900.0)
	EffectRegistry.cast(card, ctx)
	for i in 120:
		bf.simulate(1.0 / 60.0)
	eq(bf.vortex_count(), 0, "le vortex disparait a expiration")
	detach(bf)


# --- 3. Dissipation ---

func _test_dispel_retire_les_buffs() -> void:
	var bf := _field()
	var centre := Vector2(540.0, 900.0)

	var def := _dummy_def("t_berserk")
	def.enrage_speed_pct = 20.0
	def.enrage_cap = 2.0
	def.first_hit_shield = true
	var e: Enemy = bf.spawn_enemy(def, 540.0, 1.0, centre)

	# On lui fait encaisser des coups : le premier tombe sur le bouclier, les
	# suivants montent l enrage.
	e.take_damage(5.0, [])
	e.take_damage(5.0, [])
	e.take_damage(5.0, [])
	ok(e.enrage_bonus() > 0.0, "le monstre est bien enrage avant la dissipation")

	var card := _card(&"dispel_zone", 0.0, 0.0, 220.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)

	feq(e.enrage_bonus(), 0.0, "la dissipation annule l enrage")
	not_ok(e.has_shield(), "la dissipation retire le bouclier de premier coup")
	detach(bf)


func _test_dispel_epargne_le_hors_zone() -> void:
	var bf := _field()
	var centre := Vector2(540.0, 400.0)

	var def := _dummy_def("t_berserk2")
	def.enrage_speed_pct = 20.0
	def.enrage_cap = 2.0
	# Volontairement LOIN du centre vise.
	var e: Enemy = bf.spawn_enemy(def, 200.0, 1.0, Vector2(200.0, 1400.0))
	e.take_damage(5.0, [])
	var enrage_avant: float = e.enrage_bonus()
	ok(enrage_avant > 0.0, "le monstre hors zone est enrage")

	var card := _card(&"dispel_zone", 0.0, 0.0, 150.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)

	feq(e.enrage_bonus(), enrage_avant,
		"un monstre hors de la petite zone garde ses effets")
	detach(bf)


# --- 4. Pioche immediate ---

func _test_draw_cards_pioche_sans_defausser() -> void:
	RunState.reset()
	var stock: Array[SpellCard] = []
	for i in 10:
		stock.append(_card(&"damage_single", 1.0))
	RunState.build_deck_from_list(stock)
	RunState.draw(2)

	var main_avant: int = RunState.hand.size()
	var defausse_avant: int = RunState.discard.size()

	var card := _card(&"draw_cards", 0.0, 0.0, 0.0, {&"count": 3})
	EffectRegistry.cast(card, CastContext.make(null, card))

	eq(RunState.hand.size(), main_avant + 3, "trois cartes piochees")
	eq(RunState.discard.size(), defausse_avant,
		"aucune carte defaussee : c est ce qui distingue draw_cards de discard_draw")
	RunState.reset()


# --- 5. Mur permanent cassable ---

func _test_mur_permanent_ne_disparait_pas() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var card := _card(&"build_wall", 0.0, 0.0, 200.0,
		{&"thickness": 60.0, &"permanent": true, &"wall_hp": 60.0})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 800.0)
	EffectRegistry.cast(card, ctx)
	eq(bf.wall_count(), 1, "le mur permanent est pose")

	# Bien plus longtemps que n importe quel mur temporaire.
	for i in 3600:
		bf.simulate(1.0 / 60.0)
	eq(bf.wall_count(), 1, "un mur permanent ne s efface pas avec le temps")
	ok(bf.nav.blocked_count() > 0, "il bloque toujours la navigation")
	detach(bf)


func _test_mur_permanent_casse_sous_les_coups() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 800.0)
	var card := _card(&"build_wall", 0.0, 0.0, 200.0,
		{&"thickness": 60.0, &"permanent": true, &"wall_hp": 30.0})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	eq(bf.wall_count(), 1, "mur en place")

	ok(bf.damage_wall_at(centre, 10.0), "le mur encaisse un coup")
	eq(bf.wall_count(), 1, "il tient encore")
	bf.damage_wall_at(centre, 25.0)
	eq(bf.wall_count(), 0, "le mur cede quand ses PV tombent a zero")
	eq(bf.nav.blocked_count(), 0, "et il libere la navigation en cedant")
	detach(bf)


# --- 6. Retention de carte ---

func _test_retain_next_garde_la_carte_en_main() -> void:
	RunState.reset()
	var stock: Array[SpellCard] = []
	for i in 6:
		stock.append(_card(&"damage_single", 1.0))
	RunState.build_deck_from_list(stock)
	RunState.draw(2)
	var cible: SpellCard = RunState.hand[0]

	var card := _card(&"retain_next", 1.0)
	EffectRegistry.cast(card, CastContext.make(null, card))
	ok(RunState.retained_casts() > 0, "une charge de retention est active")

	var defausse_avant: int = RunState.discard.size()
	ok(RunState.play_card(cible), "la carte est jouee")
	ok(RunState.hand.has(cible), "elle reste en main au lieu de partir")
	eq(RunState.discard.size(), defausse_avant, "rien n a rejoint la defausse")
	RunState.reset()


func _test_retain_next_ne_dure_qu_un_sort() -> void:
	RunState.reset()
	var stock: Array[SpellCard] = []
	for i in 6:
		stock.append(_card(&"damage_single", 1.0))
	RunState.build_deck_from_list(stock)
	RunState.draw(3)

	var card := _card(&"retain_next", 1.0)
	EffectRegistry.cast(card, CastContext.make(null, card))

	var a: SpellCard = RunState.hand[0]
	RunState.play_card(a)
	eq(RunState.retained_casts(), 0, "la charge est consommee")

	var b: SpellCard = RunState.hand[0]
	var defausse_avant: int = RunState.discard.size()
	RunState.play_card(b)
	eq(RunState.discard.size(), defausse_avant + 1,
		"la carte SUIVANTE repart normalement a la defausse")
	RunState.reset()


# --- 7. Double incantation ---

func _test_double_cast_autorise_deux_incantations() -> void:
	RunState.reset()
	var bf := _field()
	var caster := Caster.new()
	caster.battlefield = bf
	attach(caster)

	var a := _card(&"damage_single", 1.0)
	var b := _card(&"damage_single", 1.0)

	# Sans la carte, le second sort ne peut qu ATTENDRE derriere le premier.
	eq(RunState.cast_slots(), 1, "une seule place d incantation au depart")
	caster.queue_next(a, CastContext.make(bf, a))
	caster.queue_next(b, CastContext.make(bf, b))
	ok(caster.has_queued(), "sans la carte, le second sort fait la queue")
	caster.cancel()

	var card := _card(&"double_cast", 0.0, 10.0)
	EffectRegistry.cast(card, CastContext.make(bf, card))
	ok(RunState.double_cast_active(), "la double incantation est active")
	eq(RunState.cast_slots(), 2, "elle ouvre une seconde place de chargement")

	caster.queue_next(a, CastContext.make(bf, a))
	caster.queue_next(b, CastContext.make(bf, b))
	ok(caster.is_busy(), "le premier sort charge")
	not_ok(caster.has_queued(),
		"le second sort charge EN PARALLELE au lieu de faire la queue")

	detach(caster)
	detach(bf)
	RunState.reset()


func _test_double_cast_expire() -> void:
	RunState.reset()
	var card := _card(&"double_cast", 0.0, 2.0)
	EffectRegistry.cast(card, CastContext.make(null, card))
	ok(RunState.double_cast_active(), "active juste apres le lancement")
	for i in 240:
		RunState.tick(1.0 / 60.0)
	not_ok(RunState.double_cast_active(), "elle retombe apres sa duree")
	RunState.reset()


# --- 8. Pluie de meteorites ---

func _test_meteor_storm_frappe_toute_la_carte() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	# Trois monstres aux quatre coins du terrain JOUABLE. Le but de la carte est
	# qu aucun d eux ne soit epargne : c est ce qui la distingue d une grosse zone.
	var gauche: Enemy = bf.spawn_enemy(_dummy_def("m1"), 0.0, 1.0, Vector2(150.0, 200.0))
	var droite: Enemy = bf.spawn_enemy(_dummy_def("m2"), 0.0, 1.0,
		Vector2(GameConfig.BATTLEFIELD_WIDTH - 150.0, 800.0))
	var bas: Enemy = bf.spawn_enemy(_dummy_def("m3"), 0.0, 1.0, Vector2(540.0, 1300.0))

	var card := _card(&"meteor_storm", 30.0, 4.0, 200.0, {&"impacts": 14})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 900.0)
	EffectRegistry.cast(card, ctx)
	ok(bf.zones.size() >= 8, "la pluie couvre la carte de plusieurs impacts")

	for i in 600:
		bf.simulate(1.0 / 60.0)

	for paire in [[gauche, "a gauche"], [droite, "a droite"], [bas, "en bas"]]:
		var e: Enemy = paire[0]
		var mort: bool = not is_instance_valid(e) or e.is_dead()
		ok(mort or e.hp < e.max_hp(), "la pluie touche le monstre %s" % paire[1])
	detach(bf)


# --- 9. Grande zone de poison ---

func _test_poison_field_est_une_zone_longue() -> void:
	var poison: SpellCard = ContentDB.cards.get(&"venom_mire")
	ok(poison != null, "la carte de poison existe")
	if poison == null:
		return
	eq(poison.rarity, GameEnums.Rarity.LEGENDARY, "le poison est legendaire")
	var sp: EffectSpec = poison.effects[0]
	# Elle doit battre la plus grande zone commune ET durer plus longtemps
	# qu une zone de feu rare : c est ce qui justifie sa rarete.
	var pluie: SpellCard = ContentDB.cards.get(&"frost_rain")
	var brasier: SpellCard = ContentDB.cards.get(&"brazier")
	if pluie != null:
		ok(sp.radius > pluie.effects[0].radius,
			"la mare de venin est plus large que la pluie de givre")
	if brasier != null:
		ok(sp.duration > brasier.effects[0].duration,
			"elle dure plus longtemps que le brasier")
	ok(sp.magnitude > 0.0, "elle inflige bien des degats par seconde")


# --- 10. Contenu branche ---

## Un handler sans carte est du contenu mort : l AUDIT le signale, mais autant
## le verrouiller ici pour que la regression soit ROUGE et pas un avertissement.
func _test_les_cartes_existent_dans_le_pool() -> void:
	var attendues: Array[StringName] = [
		&"repulsion_wave", &"maelstrom", &"purifying_light", &"arcane_insight",
		&"bastion", &"echo_of_the_hand", &"twin_channeling", &"meteor_storm",
		&"venom_mire",
	]
	for id in attendues:
		ok(ContentDB.cards.has(id), "la carte '%s' est dans le pool" % id)

	var cles: Array[StringName] = [&"knockback", &"vortex_pull", &"dispel_zone",
		&"draw_cards", &"retain_next", &"double_cast", &"meteor_storm"]
	var utilisees: Dictionary = {}
	for c: SpellCard in ContentDB.cards.values():
		for k in c.effect_keys():
			utilisees[k] = true
	for k in cles:
		ok(utilisees.has(k), "le handler '%s' est porte par une carte" % k)


## L allie invoque doit SE VOIR. Le testeur signalait : "on ne voit pas
## l invocation de l Allie dans le sort apprenti miroir". Il frappait bien, mais
## n existait que comme une entree de donnees : aucun sprite, aucun tir visible.
func _test_l_allie_invoque_est_visible() -> void:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)

	bf.spawn_ally(6.0, 10.0)
	eq(bf.allies.size(), 1, "un allie est invoque")
	var a: Dictionary = bf.allies[0]
	ok(a.has("pos"), "il a une position sur le terrain")
	ok(a["pos"].y < GameConfig.MAGE_LINE_Y, "il se tient devant le mage, pas dessus")
	ok(a["pos"].y > GameConfig.MAGE_LINE_Y - 500.0, "mais pas au milieu du champ")

	# Sa duree reste tenue par la simulation, et il disparait a l expiration.
	for i in 420:
		bf.simulate(1.0 / 60.0)
	eq(bf.allies.size(), 0, "il disparait quand sa duree est ecoulee")


# =====================================================================
# CHANTIER H — SORTS DE TERRAIN
#
# Demande du testeur, mot pour mot : « Arbre qui attire les ennemis ; sort de
# stun ; arbre a zone de poison ; eau qui ralentit ».
#
# Ces quatre sorts ne retirent pas des PV : ils POSENT quelque chose sur le
# terrain et changent la facon dont les monstres descendent. La seule carte de ce
# genre etait le Mur de pierre, qui BLOQUE. Les nouvelles cartes attirent,
# immobilisent, empoisonnent et renversent le courant — quatre reponses
# differentes a la meme question « ils arrivent trop bas ».
#
# Ce qui est verifie ici, ce sont les REGLES, jamais les valeurs d equilibrage :
# les chiffres se lisent contre GameConfig ou contre les cartes livrees, sinon le
# harnais empecherait de regler le jeu au lieu de le proteger.


func run_terrain_spells() -> void:
	_test_h_handlers_enregistres()
	_test_arbre_detourne_les_monstres()
	_test_arbre_encaisse_et_tombe()
	_test_arbre_expire_seul()
	_test_arbre_hors_portee_ne_detourne_pas()
	_test_arbre_poison_pose_une_zone_qui_le_suit()
	_test_arbre_poison_respecte_les_resistances()
	_test_stun_immobilise_puis_relache()
	_test_stun_respecte_la_resistance_au_ralentissement()
	_test_stun_coute_plus_quil_ne_dure()
	_test_eau_remonte_le_courant()
	_test_eau_se_distingue_du_champ_de_givre()
	_test_eau_ne_fait_aucun_degat()
	_test_les_quatre_cartes_sont_dans_le_pool()
	_test_chaque_carte_de_terrain_a_sa_feuille_et_son_icone()


# --- 0. Enregistrement des verbes ---

func _test_h_handlers_enregistres() -> void:
	for key in [&"taunt_prop", &"stun_zone", &"water_flood"]:
		ok(EffectRegistry.has_key(key), "handler '%s' enregistre" % key)


# --- 1. L arbre qui attire ---

## La regle centrale : le monstre VISE l arbre au lieu du mage. Il ne descend donc
## plus, et c est exactement le temps que la carte achete.
func _test_arbre_detourne_les_monstres() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var arbre := Vector2(300.0, 900.0)
	# Un monstre a la MEME hauteur que l arbre mais decale sur le cote, et DANS la
	# portee de provocation : s il continuait vers le mage il descendrait tout
	# droit sans bouger en x. C est donc le x qui prouve la regle.
	var d := _dummy_def("t_taunt")
	d.base_speed = 120.0
	var e: Enemy = bf.spawn_enemy(d, 700.0, 1.0, Vector2(700.0, 900.0))
	var x_avant: float = e.position.x
	var loin_avant: float = e.position.distance_to(arbre)

	var card := _card(&"taunt_prop", 0.0, 12.0, 520.0,
		{&"prop_hp": 200.0, &"kind": "tree"})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = arbre
	EffectRegistry.cast(card, ctx)
	eq(bf.prop_count(), 1, "un arbre est plante")

	for i in 60:
		bf.simulate(1.0 / 60.0)

	ok(e.position.x < x_avant - 20.0,
		"le monstre se detourne vers l arbre (x %.0f -> %.0f)" % [x_avant, e.position.x])
	ok(e.position.distance_to(arbre) < loin_avant, "il s en rapproche vraiment")
	detach(bf)


## L arbre n est pas un mur : il se fait taper et il tombe. Sans cela le joueur
## poserait un arbre et n aurait plus rien a faire.
func _test_arbre_encaisse_et_tombe() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var arbre := Vector2(540.0, 900.0)
	var card := _card(&"taunt_prop", 0.0, 60.0, 520.0,
		{&"prop_hp": 40.0, &"kind": "tree"})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = arbre
	EffectRegistry.cast(card, ctx)

	var pv_pleins: float = bf.prop_hp_at(arbre)
	ok(pv_pleins > 0.0, "l arbre a des PV")
	ok(bf.damage_prop_at(arbre, pv_pleins * 0.5), "il encaisse un coup")
	ok(bf.prop_hp_at(arbre) < pv_pleins, "ses PV descendent")
	eq(bf.prop_count(), 1, "il tient encore a mi-vie")
	bf.damage_prop_at(arbre, pv_pleins)
	eq(bf.prop_count(), 0, "il tombe quand ses PV sont epuises")
	detach(bf)


## Il ne dure pas eternellement : la carte achete un temps BORNE.
func _test_arbre_expire_seul() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var card := _card(&"taunt_prop", 0.0, 2.0, 400.0,
		{&"prop_hp": 9999.0, &"kind": "tree"})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(540.0, 900.0)
	EffectRegistry.cast(card, ctx)
	eq(bf.prop_count(), 1, "plante")
	for i in 300:
		bf.simulate(1.0 / 60.0)
	eq(bf.prop_count(), 0, "un arbre intact disparait quand sa duree est ecoulee")
	detach(bf)


## Un monstre LOIN de l arbre continue sa descente : la provocation a une portee,
## sinon la carte deviendrait un bouton « plus personne n avance ».
func _test_arbre_hors_portee_ne_detourne_pas() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var d := _dummy_def("t_far")
	d.base_speed = 120.0
	var e: Enemy = bf.spawn_enemy(d, 900.0, 1.0, Vector2(900.0, 300.0))
	var x_avant: float = e.position.x
	var y_avant: float = e.position.y

	var card := _card(&"taunt_prop", 0.0, 12.0, 200.0,
		{&"prop_hp": 200.0, &"kind": "tree"})
	var ctx := CastContext.make(bf, card)
	ctx.target_position = Vector2(150.0, 1300.0)
	EffectRegistry.cast(card, ctx)

	for i in 60:
		bf.simulate(1.0 / 60.0)
	feq(e.position.x, x_avant, "hors portee, il ne se detourne pas", 1.0)
	ok(e.position.y > y_avant, "et il continue de descendre")
	detach(bf)


# --- 2. L arbre a zone de poison ---

## L arbre de poison est un arbre QUI PORTE UNE ZONE. La zone n est pas
## independante : elle nait avec l arbre et doit mourir avec lui, sinon le joueur
## abattrait son propre arbre et garderait le poison gratuitement.
func _test_arbre_poison_pose_une_zone_qui_le_suit() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var arbre := Vector2(540.0, 900.0)
	var card := _card(&"taunt_prop", 12.0, 60.0, 420.0,
		{&"prop_hp": 30.0, &"kind": "tree", &"zone_radius": 220.0})
	card.tags = [GameEnums.DamageTag.POISON]
	var ctx := CastContext.make(bf, card)
	ctx.target_position = arbre
	EffectRegistry.cast(card, ctx)

	eq(bf.prop_count(), 1, "l arbre empoisonne est plante")
	ok(bf.zones.size() >= 1, "il porte une zone au sol")

	var e: Enemy = bf.spawn_enemy(_dummy_def("t_poisoned"), 540.0, 1.0,
		arbre + Vector2(60.0, 0.0))
	var pv_avant: float = e.hp
	for i in 60:
		bf.simulate(1.0 / 60.0)
	ok(e.hp < pv_avant, "un monstre dans la zone perd des PV")

	# On abat l arbre : la zone doit partir avec lui.
	bf.damage_prop_at(arbre, 1000.0)
	eq(bf.prop_count(), 0, "l arbre est abattu")
	eq(bf.zones.size(), 0, "sa zone de poison disparait avec lui")
	detach(bf)


## L element POISON doit mordre sur la table de resistances. Un monstre immunise
## traverse la mare sans rien sentir : c est voulu, c est ce qui donne une raison
## de recomposer son deck d un niveau a l autre.
func _test_arbre_poison_respecte_les_resistances() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var arbre := Vector2(540.0, 900.0)

	var immune := _dummy_def("t_undead")
	immune.resistances = {GameEnums.DamageTag.POISON: 0.0}
	var mort_vivant: Enemy = bf.spawn_enemy(immune, 540.0, 1.0, arbre + Vector2(40.0, 0.0))
	var chair: Enemy = bf.spawn_enemy(_dummy_def("t_flesh"), 540.0, 1.0,
		arbre - Vector2(40.0, 0.0))

	var card := _card(&"taunt_prop", 20.0, 60.0, 420.0,
		{&"prop_hp": 9999.0, &"kind": "tree", &"zone_radius": 220.0})
	card.tags = [GameEnums.DamageTag.POISON]
	var ctx := CastContext.make(bf, card)
	ctx.target_position = arbre
	EffectRegistry.cast(card, ctx)

	var pv_immune: float = mort_vivant.hp
	var pv_chair: float = chair.hp
	for i in 90:
		bf.simulate(1.0 / 60.0)
	feq(mort_vivant.hp, pv_immune, "un immunise au poison ne perd rien", 0.001)
	ok(chair.hp < pv_chair, "un monstre de chair, lui, fond")
	detach(bf)


# --- 3. Le stun ---

## Immobiliser est la chose la plus forte qu on puisse faire dans un jeu en temps
## reel : la regle est donc BINAIRE (vitesse nulle) et la duree, breve.
func _test_stun_immobilise_puis_relache() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 900.0)
	var d := _dummy_def("t_stun")
	d.base_speed = 200.0
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, centre)

	var card := _card(&"stun_zone", 0.0, 1.0, 220.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	ok(e.is_stunned(), "le monstre est immobilise")

	var y_fige: float = e.position.y
	for i in 30:
		bf.simulate(1.0 / 60.0)
	feq(e.position.y, y_fige,
		"il n a pas avance d un pixel pendant l etourdissement", 0.5)

	# Au-dela de la duree, il repart.
	for i in 180:
		bf.simulate(1.0 / 60.0)
	not_ok(e.is_stunned(), "l etourdissement se dissipe")
	ok(e.position.y > y_fige, "et il reprend sa descente")
	detach(bf)


## Un stun qui ignorerait l immunite au ralentissement viderait cette immunite de
## son sens : le golem serait ralenti a 0 % et bloque a 100 %. Il passe donc par
## la MEME table de resistances que les ralentissements.
func _test_stun_respecte_la_resistance_au_ralentissement() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 900.0)

	var roc := _dummy_def("t_roc")
	roc.resistances = {GameEnums.DamageTag.SLOW: 0.0}
	roc.base_speed = 200.0
	var golem: Enemy = bf.spawn_enemy(roc, 540.0, 1.0, centre)

	var card := _card(&"stun_zone", 0.0, 1.5, 220.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	not_ok(golem.is_stunned(),
		"un monstre immunise au ralentissement ne se fige pas")

	var y_avant: float = golem.position.y
	for i in 30:
		bf.simulate(1.0 / 60.0)
	ok(golem.position.y > y_avant, "il continue d avancer malgre le sort")
	detach(bf)


## Le prix du stun, exprime en RATIO et non en secondes : l etourdissement doit
## etre plus court que l incantation qui le relance, sinon deux exemplaires
## suffisent a figer la partie pour toujours. Le rapport se conserve a toute
## vitesse, puisque la jauge divise les deux termes.
func _test_stun_coute_plus_quil_ne_dure() -> void:
	var stun: SpellCard = ContentDB.cards.get(&"thunder_root")
	ok(stun != null, "la carte de stun existe")
	if stun == null:
		return
	var duree: float = stun.effects[0].duration
	ok(duree < stun.base_cast_time,
		"l etourdissement (%.2f s) dure moins que son incantation (%.2f s)"
		% [duree, stun.base_cast_time])
	ok(stun.rarity >= GameEnums.Rarity.EPIC,
		"immobiliser est reserve aux raretes hautes")
	# Sa zone doit rester plus petite que la plus grande zone commune : un stun
	# de la taille d une Pluie de givre couvrirait la vague entiere.
	var pluie: SpellCard = ContentDB.cards.get(&"frost_rain")
	if pluie != null:
		ok(stun.effects[0].radius < pluie.effects[0].radius,
			"la zone d etourdissement reste plus petite que la pluie de givre")


# --- 4. L eau qui ralentit ---

## Ce qui la distingue du Champ de givre : le givre ralentit la descente, l eau la
## REMONTE. Un monstre pose dans la nappe recule au lieu d avancer lentement.
func _test_eau_remonte_le_courant() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 900.0)
	var d := _dummy_def("t_wet")
	d.base_speed = 60.0
	var e: Enemy = bf.spawn_enemy(d, 540.0, 1.0, centre)
	var y_avant: float = e.position.y

	var card := _card(&"water_flood", 60.0, 6.0, 300.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	eq(bf.flood_count(), 1, "une nappe d eau est posee")

	for i in 60:
		bf.simulate(1.0 / 60.0)
	ok(e.position.y < y_avant,
		"le courant le fait REMONTER (%.0f -> %.0f)" % [y_avant, e.position.y])

	for i in 600:
		bf.simulate(1.0 / 60.0)
	eq(bf.flood_count(), 0, "la nappe s evapore a expiration")
	detach(bf)


## Deux cartes qui font la meme chose en deux couleurs ne meritent pas d exister
## toutes les deux. La difference doit se LIRE dans les donnees livrees.
func _test_eau_se_distingue_du_champ_de_givre() -> void:
	var eau: SpellCard = ContentDB.cards.get(&"tidal_pool")
	var givre: SpellCard = ContentDB.cards.get(&"frost_field")
	ok(eau != null, "la carte d eau existe")
	if eau == null or givre == null:
		return
	eq(eau.effects[0].key, &"water_flood",
		"l eau n est pas une zone au sol de plus : elle a son propre verbe")
	eq(givre.effects[0].key, &"ground_zone", "le givre reste une zone au sol")
	ok(eau.effects[0].radius > givre.effects[0].radius,
		"la nappe couvre plus large que le champ de givre")


## Aucun degat : l eau achete du terrain, elle ne le nettoie pas. Sans cette regle
## elle serait un « champ de givre qui fait mal », donc strictement meilleure, et
## le Champ de givre n aurait plus de raison d exister.
func _test_eau_ne_fait_aucun_degat() -> void:
	var bf := _field()
	reset_gauge_at_normal_speed()
	var centre := Vector2(540.0, 900.0)
	var e: Enemy = bf.spawn_enemy(_dummy_def("t_dry"), 540.0, 1.0, centre)
	var pv_avant: float = e.hp

	var card := _card(&"water_flood", 60.0, 5.0, 300.0)
	var ctx := CastContext.make(bf, card)
	ctx.target_position = centre
	EffectRegistry.cast(card, ctx)
	for i in 180:
		bf.simulate(1.0 / 60.0)
	feq(e.hp, pv_avant, "la nappe ne retire pas un seul PV", 0.001)
	detach(bf)


# --- 5. Contenu branche ---

## Une carte hors de tout pool est du contenu mort. L AUDIT le signale ; on le
## verrouille ici pour que la regression soit ROUGE et non un avertissement.
func _test_les_quatre_cartes_sont_dans_le_pool() -> void:
	var ids: Array[StringName] = [&"heartwood_totem", &"blight_sapling",
		&"thunder_root", &"tidal_pool"]
	for id in ids:
		ok(ContentDB.cards.has(id), "la carte '%s' est dans le pool" % id)

	# Et elles doivent etre ATTEIGNABLES : plusieurs dans les decks de campagne,
	# sinon le joueur ne les rencontre jamais dans l ordre normal du jeu.
	var dans_un_deck: Dictionary = {}
	for key in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[key]
		for c in lvl.exploration_deck:
			if c != null:
				dans_un_deck[(c as SpellCard).id] = true
	var trouvees: int = 0
	for id in ids:
		if dans_un_deck.has(id):
			trouvees += 1
	ok(trouvees >= 2,
		"au moins deux sorts de terrain sont joues en campagne (%d)" % trouvees)


## « Beaucoup trop de sorts utilisent les memes animations » : quatre sorts de
## terrain qui partageraient la feuille du mur seraient refuses par l AUDIT. On le
## verifie aussi ici, parce qu une carte meconnaissable est un defaut de JEU avant
## d etre un defaut de contenu.
func _test_chaque_carte_de_terrain_a_sa_feuille_et_son_icone() -> void:
	var vues: Dictionary = {}
	var signatures: Dictionary = {}
	var mur: SpellCard = ContentDB.cards.get(&"stone_wall")
	for id in [&"heartwood_totem", &"blight_sapling", &"thunder_root", &"tidal_pool"]:
		var c: SpellCard = ContentDB.cards.get(id)
		if c == null:
			continue
		ok(c.fx_key != &"", "%s porte une feuille d effet" % id)
		ok(Fx.has_sheet(String(c.fx_key)), "%s : feuille '%s' connue" % [id, c.fx_key])
		not_ok(vues.has(c.fx_key),
			"%s : feuille '%s' pas deja prise par %s" % [id, c.fx_key, vues.get(c.fx_key, "")])
		vues[c.fx_key] = id
		var sig: String = CardIcons.signature(c)
		not_ok(signatures.has(sig),
			"%s : icone distincte de %s" % [id, signatures.get(sig, "")])
		signatures[sig] = id
		if mur != null:
			ok(c.fx_key != mur.fx_key, "%s ne reutilise pas l effet du mur" % id)
