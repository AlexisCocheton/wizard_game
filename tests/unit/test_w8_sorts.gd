extends TestCase
## LES SORTS DEMANDES PAR LE CO-AUTEUR (vague 8, 02/10).
##
##   - le Dard venimeux : un poison mono-cible PORTE par le monstre jusqu a sa
##     mort (cle `poison_dot`) ; resistances au poison, attribution au lancer ;
##   - l Elan du temps : une carte qui rend de la vitesse au mage (`gain_speed`) ;
##   - les retouches de rarete (Nappe montante rare, Intuition arcanique epique)
##     et leurs consequences sur les decks et la progression.
##
## Chaque verification porte sur une REGLE (un rapport, un ordre, une rarete
## demandee), jamais sur un chiffre d equilibrage.

func get_suite_name() -> String:
	return "w8_sorts"


const DT: float = 1.0 / 60.0


func _card(key: StringName, magnitude: float, tags: Array[GameEnums.DamageTag] = []) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName("t_" + String(key))
	c.display_name = "Test " + String(key)
	c.base_cast_time = 1.0
	c.targeting = GameEnums.Targeting.TARGET
	if not tags.is_empty():
		c.element = tags[0]
	var sp := EffectSpec.new()
	sp.key = key
	sp.magnitude = magnitude
	c.effects = [sp]
	return c


func _field() -> Battlefield:
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _cible(pv: float, resistance_poison: float = 1.0, id: String = "t_cible") -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = "Cible"
	d.max_hp = pv
	d.base_speed = 0.0
	d.base_radius = 24.0
	d.base_xp = 1
	if resistance_poison != 1.0:
		d.resistances = {GameEnums.DamageTag.POISON: resistance_poison}
	return d


func _empoisonner(bf: Battlefield, e: Enemy, card: SpellCard) -> void:
	var ctx := CastContext.make(bf, card)
	ctx.target_enemy = e
	ctx.target_position = e.position
	EffectRegistry.cast(card, ctx)


## Avance le monde de `secondes` (temps du MONDE : la jauge est a x1).
func _avancer(bf: Battlefield, secondes: float) -> void:
	var t: float = 0.0
	while t < secondes:
		bf.simulate(DT)
		t += SpeedGauge.world_delta(DT)


func run() -> void:
	_test_handlers_enregistres()
	_test_le_poison_mord_a_son_debit()
	_test_deux_poisons_s_additionnent()
	_test_la_resistance_au_poison_s_applique()
	_test_le_poison_dure_jusqu_a_la_mort()
	_test_la_mort_par_poison_revient_au_lancer()
	_test_le_poison_se_voit_sur_le_monstre()
	_test_le_dard_venimeux_livre()
	_test_gagner_de_la_vitesse()
	_test_l_elan_du_temps_livre()
	_test_concentration_fait_murir_la_main()
	_test_les_voies_d_amelioration_ont_un_sens()
	_test_les_raretes_demandees()
	_test_les_cartes_neuves_s_obtiennent_en_campagne()


func _test_handlers_enregistres() -> void:
	for key in [&"poison_dot", &"gain_speed"]:
		ok(EffectRegistry.has_key(key), "handler '%s' enregistre" % key)
	ok(&"poison_dot" in ObjectiveChecker.KILLING_EFFECTS,
		"le poison peut tuer : kill_type_with_card le sait")


# --- Le Dard venimeux ---------------------------------------------------------

func _test_le_poison_mord_a_son_debit() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var e: Enemy = bf.spawn_enemy(_cible(10000.0), 540.0, 1.0, Vector2(540, 600))
	var debit: float = 3.0
	_empoisonner(bf, e, _card(&"poison_dot", debit, [GameEnums.DamageTag.POISON]))
	eq(bf.poison_count(e), 1, "le monstre porte un poison")
	var avant: float = e.hp
	var duree: float = 4.0
	_avancer(bf, duree)
	var perdu: float = avant - e.hp
	between(perdu / (debit * duree), 0.95, 1.05,
		"il perd son debit par seconde de monde (%.1f PV en %.0f s)" % [perdu, duree])
	detach(bf)


func _test_deux_poisons_s_additionnent() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var un: Enemy = bf.spawn_enemy(_cible(10000.0), 300.0, 1.0, Vector2(300, 600))
	var deux: Enemy = bf.spawn_enemy(_cible(10000.0), 800.0, 1.0, Vector2(800, 600))
	var c := _card(&"poison_dot", 2.0, [GameEnums.DamageTag.POISON])
	_empoisonner(bf, un, c)
	_empoisonner(bf, deux, c)
	_empoisonner(bf, deux, c)
	_avancer(bf, 3.0)
	var p1: float = un.definition.max_hp - un.hp
	var p2: float = deux.definition.max_hp - deux.hp
	between(p2 / maxf(p1, 0.001), 1.9, 2.1, "deux dards font deux poisons (%.1f contre %.1f)" % [p2, p1])
	detach(bf)


func _test_la_resistance_au_poison_s_applique() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var neutre: Enemy = bf.spawn_enemy(_cible(10000.0), 200.0, 1.0, Vector2(200, 600))
	var resistant: Enemy = bf.spawn_enemy(_cible(10000.0, 0.5, "t_resiste"), 540.0, 1.0,
		Vector2(540, 600))
	var immunise: Enemy = bf.spawn_enemy(_cible(10000.0, 0.0, "t_immun"), 880.0, 1.0,
		Vector2(880, 600))
	var c := _card(&"poison_dot", 4.0, [GameEnums.DamageTag.POISON])
	for e in [neutre, resistant, immunise]:
		_empoisonner(bf, e, c)
	_avancer(bf, 3.0)
	var pn: float = neutre.definition.max_hp - neutre.hp
	var pr: float = resistant.definition.max_hp - resistant.hp
	var pi: float = immunise.definition.max_hp - immunise.hp
	ok(pn > 0.0, "le poison mord un monstre neutre")
	between(pr / maxf(pn, 0.001), 0.45, 0.55,
		"un monstre qui resiste a moitie perd moitie moins (%.1f contre %.1f)" % [pr, pn])
	feq(pi, 0.0, "un monstre immunise au poison ne perd rien")
	detach(bf)


func _test_le_poison_dure_jusqu_a_la_mort() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var pv: float = 12.0
	var debit: float = 4.0
	var e: Enemy = bf.spawn_enemy(_cible(pv), 540.0, 1.0, Vector2(540, 600))
	_empoisonner(bf, e, _card(&"poison_dot", debit, [GameEnums.DamageTag.POISON]))
	# Bien au-dela de ce qu un poison a duree fixe aurait tenu : il ne s arrete
	# que quand la cible tombe.
	_avancer(bf, pv / debit * 0.5)
	ok(not e.is_dead() and bf.poison_count(e) == 1, "a mi-chemin il mord toujours")
	_avancer(bf, pv / debit * 0.6 + 0.2)
	ok(not is_instance_valid(e) or e.is_dead(), "la cible finit par mourir du poison seul")
	eq(bf.poisons.size(), 0, "et le poison s eteint avec elle")
	detach(bf)


## « kill_type_with_card » : une mort par poison revient a la carte qui l a pose,
## meme si un autre sort a ete lance entre-temps.
func _test_la_mort_par_poison_revient_au_lancer() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var def := _cible(6.0, 1.0, "t_victime")
	var e: Enemy = bf.spawn_enemy(def, 540.0, 1.0, Vector2(540, 600))
	var dard := _card(&"poison_dot", 3.0, [GameEnums.DamageTag.POISON])
	_empoisonner(bf, e, dard)
	# Un autre lancer ouvre une autre source : le poison ne doit pas la suivre.
	var autre := _card(&"poison_dot", 0.0)
	autre.id = &"t_autre"
	var ctx := CastContext.make(bf, autre)
	EffectRegistry.cast(autre, ctx)
	_avancer(bf, 3.0)
	ok(not is_instance_valid(e) or e.is_dead(), "la victime est morte du poison")
	eq(RunState.kills_with_card(dard.id, def.id), 1, "la mort est creditee au dard")
	eq(RunState.kills_with_card(autre.id, def.id), 0, "et pas au sort lance ensuite")
	detach(bf)


## Lisible SUR le monstre : la pose du poison joue la feuille de la carte en
## boucle sur lui (le mouchard de Fx voit la demande, meme sans ecran).
func _test_le_poison_se_voit_sur_le_monstre() -> void:
	reset_gauge_at_normal_speed()
	RunState.reset()
	var bf := _field()
	var e: Enemy = bf.spawn_enemy(_cible(10000.0), 540.0, 1.0, Vector2(540, 600))
	var dard: SpellCard = ContentDB.cards.get(&"venom_dart")
	ok(dard != null, "le Dard venimeux existe")
	if dard == null:
		detach(bf)
		return
	Fx.begin_trace()
	bf.poison_enemy(e, 1.0, dard)
	var vues: Array[String] = Fx.end_trace()
	ok(vues.has(String(dard.fx_key)), "la feuille du dard est jouee sur le monstre %s" % [vues])
	detach(bf)


func _test_le_dard_venimeux_livre() -> void:
	var c: SpellCard = ContentDB.cards.get(&"venom_dart")
	ok(c != null, "venom_dart est au catalogue")
	if c == null:
		return
	eq(c.rarity, GameEnums.Rarity.COMMON, "le dard est une commune (demande du co-auteur)")
	eq(c.main_element(), GameEnums.DamageTag.POISON, "son element est le poison")
	eq(c.targeting, GameEnums.Targeting.TARGET, "il vise UNE cible")
	eq(c.effect_keys(), [&"poison_dot"] as Array[StringName], "un seul effet : le poison porte")
	ok(c.effects[0].duration <= 0.0, "sans duree : jusqu a la mort")
	ok(c.description.contains("POISON") and c.description.contains("mort"),
		"le texte dit poison et jusqu a la mort : %s" % c.description)


# --- L Elan du temps -----------------------------------------------------------

func _test_gagner_de_la_vitesse() -> void:
	RunState.reset()
	SpeedGauge.reset()
	var gain: float = 20.0
	var c := _card(&"gain_speed", gain, [GameEnums.DamageTag.ARCANE])
	var avant: int = SpeedGauge.speed_percent
	EffectRegistry.cast(c, CastContext.make(null, c))
	eq(SpeedGauge.speed_percent - avant, int(gain), "le mage gagne la magnitude en points")
	# Plafonne au maximum : la vitesse ne deborde pas.
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT - 1)
	EffectRegistry.cast(c, CastContext.make(null, c))
	eq(SpeedGauge.speed_percent, GameConfig.SPEED_MAX_PERCENT, "jamais au-dela du maximum")
	# Pendant l agonie, rien : on ne ressuscite pas.
	SpeedGauge.set_speed_percent(101)
	SpeedGauge.take_hit(5)
	ok(SpeedGauge.is_dying, "le mage est a l agonie")
	var mort: int = SpeedGauge.speed_percent
	EffectRegistry.cast(c, CastContext.make(null, c))
	eq(SpeedGauge.speed_percent, mort, "l elan ne ressuscite pas")
	SpeedGauge.reset()


func _test_l_elan_du_temps_livre() -> void:
	var c: SpellCard = ContentDB.cards.get(&"time_surge")
	ok(c != null, "time_surge est au catalogue")
	if c == null:
		return
	eq(c.main_element(), GameEnums.DamageTag.ARCANE, "carte de temps : arcanique")
	eq(c.effect_keys(), [&"gain_speed"] as Array[StringName], "elle rend de la vitesse")
	ok(c.effects[0].magnitude > 0.0, "un gain positif")
	ok(c.description.contains(str(int(c.effects[0].magnitude))),
		"le texte annonce le gain du .tres : %s" % c.description)


# --- Concentration -----------------------------------------------------------

## « Donne 1 XP a toutes les cartes de ta main » : chaque carte DISTINCTE de la
## main gagne l XP du .tres (deux copies la partagent, comme MEDITER), l XP est
## rangee a part (card_xp_bonus) et ne compte PAS comme un lancer.
func _test_concentration_fait_murir_la_main() -> void:
	var conc: SpellCard = ContentDB.cards.get(&"deep_focus")
	ok(conc != null, "Concentration existe")
	if conc == null:
		return
	eq(conc.effect_keys(), [&"hand_card_xp"] as Array[StringName],
		"Concentration donne de l XP de carte, elle ne defausse plus la main")
	var gain: int = int(round(conc.effects[0].magnitude))
	ok(gain > 0, "un gain d XP positif")
	ok(conc.description.contains("%d XP" % gain), "le texte annonce le gain : %s" % conc.description)
	RunState.reset()
	var a := _card(&"damage_single", 1.0)
	a.id = &"t_main_a"
	var b := _card(&"damage_single", 1.0)
	b.id = &"t_main_b"
	RunState.hand.assign([a, a, b])
	var main_avant: int = RunState.hand.size()
	EffectRegistry.cast(conc, CastContext.make(null, conc))
	eq(RunState.card_xp(a), gain, "deux copies en main partagent leur XP (+%d, pas +%d)" % [gain, 2 * gain])
	eq(RunState.card_xp(b), gain, "chaque carte distincte de la main murit")
	eq(RunState.casts_of(a) + RunState.casts_of(b), 0, "l XP donnee n est pas un lancer")
	eq(RunState.hand.size(), main_avant, "la main n est plus defaussee")
	RunState.reset()


# --- Ameliorations, raretes, obtention -----------------------------------------

## Les voies sont DERIVEES des effets : le dard doit pouvoir gagner des degats
## (son poison), l elan ne doit pas promettre un axe qu il n a pas.
func _test_les_voies_d_amelioration_ont_un_sens() -> void:
	var dard: SpellCard = ContentDB.cards.get(&"venom_dart")
	var elan: SpellCard = ContentDB.cards.get(&"time_surge")
	if dard == null or elan == null:
		ok(false, "les deux cartes neuves existent")
		return
	var axes_dard: Dictionary = {}
	for v in RunState.upgrade_pool_for(dard):
		for a in (v["mods"] as Dictionary).keys():
			axes_dard[StringName(a)] = true
	ok(axes_dard.has(RunState.UP_DAMAGE), "le dard peut gagner des degats de poison")
	ok(not axes_dard.has(RunState.UP_AREA), "pas de zone a agrandir sur une cible unique")
	ok(not axes_dard.has(RunState.UP_DURATION), "pas de duree : il dure jusqu a la mort")
	var voies_elan: Array = RunState.upgrade_pool_for(elan)
	ok(voies_elan.size() >= GameConfig.LEVEL_UP_CHOICES,
		"l elan a de quoi remplir une maturation (%d voies)" % voies_elan.size())
	for v in voies_elan:
		for a in (v["mods"] as Dictionary).keys():
			ok(StringName(a) in [RunState.UP_CAST, RunState.UP_DRAW, RunState.UP_DISCARD],
				"l elan ne promet que vitesse de lancement et pioche (%s)" % a)


func _test_les_raretes_demandees() -> void:
	var nappe: SpellCard = ContentDB.cards.get(&"tidal_pool")
	var intuition: SpellCard = ContentDB.cards.get(&"arcane_insight")
	ok(nappe != null and intuition != null, "Nappe et Intuition existent")
	if nappe == null or intuition == null:
		return
	eq(nappe.rarity, GameEnums.Rarity.RARE, "la Nappe montante est rare")
	eq(intuition.rarity, GameEnums.Rarity.EPIC, "l Intuition arcanique est epique")
	# Une seule fiche par carte : l ancien fichier, laisse dans l ancien
	# dossier, ferait charger deux cartes du meme id selon l ordre du disque.
	for chemin in ["res://resources/cards/common/tidal_pool.tres",
			"res://resources/cards/rare/arcane_insight.tres"]:
		not_ok(FileAccess.file_exists(chemin), "plus de fiche perimee : %s" % chemin)
	# Le Rappel d ossements (rare) garde moins de sorts que l Echo de la main
	# (legendaire, meme verbe) : la rarete se lit dans le chiffre.
	var rappel: SpellCard = ContentDB.cards.get(&"bone_recall")
	var echo: SpellCard = ContentDB.cards.get(&"echo_of_the_hand")
	if rappel != null and echo != null:
		ok(rappel.effects[0].magnitude < echo.effects[0].magnitude,
			"le Rappel garde moins de sorts que l Echo")
	# L Intuition (epique) pioche moins que le Registre (legendaire) n en pioche.
	var registre: SpellCard = ContentDB.cards.get(&"tide_ledger")
	if registre != null:
		ok(int(intuition.effects[0].get_param(&"count", 0))
			< int(registre.effects[0].get_param(&"count", 0)),
			"l Intuition pioche moins que le Registre des marees")


## Chaque carte neuve s obtient : elle est proposee en campagne (carte nouvelle
## ou recompense), et c est une carte que le joueur ne possede pas encore la.
func _test_les_cartes_neuves_s_obtiennent_en_campagne() -> void:
	for id in [&"venom_dart", &"time_surge"]:
		var ou: Array[String] = []
		for lv: LevelDef in ContentDB.levels.values():
			for liste: Array in [lv.levelup_cards, lv.objective_rewards]:
				for c in liste:
					if c != null and (c as SpellCard).id == id:
						ou.append(String(lv.id))
		ok(not ou.is_empty(), "%s est proposee en campagne (%s)" % [id, ou])
