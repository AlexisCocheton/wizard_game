extends TestCase
## CIBLES MORTES (vague 10, chantier C1) : les SCRIPT ERROR que seuls les bancs
## voyaient depuis la fusion de B1b (~2200 par banc complet, 0 au harnais).
##
##   1. Une majeure a `aim_offset` (Barriere de givre, Triple jet...) recopiait la
##      cible du lancer dans le contexte decale. Une cible MORTE et liberee pendant
##      l incantation faisait echouer l affectation (SCRIPT ERROR), la copie
##      rendait null, et le handler plantait sur un contexte nul : les effets
##      decales etaient perdus. Ils doivent tomber au POINT vise.
##   2. Un residu (degat continu des majeures) qui tuait son porteur faisait
##      retirer TOUS les residus du mort pendant le parcours a rebours de
##      _w10_tick_dots : index hors du tableau, et les residus suivants ne
##      mordaient plus.
##
## Les deux cas exigent un objet LIBERE (ou une mort pendant le tic) : c est ce
## que le harnais ne produisait jamais. Sabotage verifie : chaque correctif retire
## fait echouer sa verification ET ecrit une SCRIPT ERROR (gate stderr).


func get_suite_name() -> String:
	return "cibles_mortes_w10"


func run() -> void:
	_test_copies_decalees_tombent_au_point_vise()
	_test_triple_jet_sur_cible_liberee()
	_test_copie_decalee_garde_une_cible_vivante()
	_test_rejeu_sur_cible_liberee()
	_test_residu_qui_tue_ne_sort_pas_du_tableau()
	RunState.reset()


# --- Outils ------------------------------------------------------------------

func _field() -> Battlefield:
	reset_gauge_at_normal_speed()
	var bf := Battlefield.new()
	bf.nav = NavGrid.new()
	attach(bf)
	return bf


func _def(id: String, pv: float) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = pv
	d.base_speed = 0.0
	d.base_radius = 30.0
	d.base_xp = 1
	return d


func _carte(id: String) -> SpellCard:
	return ContentDB.cards.get(StringName(id)) as SpellCard


## Prend la majeure `id_majeure` du sort `id_carte` pour la partie ; null si absente.
func _prendre(id_carte: String, id_majeure: String) -> SpellCard:
	RunState.reset()
	var c: SpellCard = _carte(id_carte)
	var m: MajorUpgradeDef = c.major_upgrade(StringName(id_majeure)) if c != null else null
	ok(m != null, "%s/%s existe" % [id_carte, id_majeure])
	if m == null:
		return null
	RunState.upgrades_taken[c.id] = [RunState.major_id_of(m)]
	return c


func _lancer(bf: Battlefield, c: SpellCard, ou: Vector2, cible: Variant) -> void:
	var ctx := CastContext.make(bf, c)
	ctx.target_position = ou
	ctx.direction = Vector2.UP
	# Affecter un objet libere a un champ type est lui-meme une erreur : la
	# cible est posee VIVANTE, comme le fait le jeu au moment du lacher, puis
	# liberee par l appelant si le test le veut.
	if cible != null and is_instance_valid(cible):
		ctx.target_enemy = cible
	EffectRegistry.cast(c, ctx)


## Le contexte d un lacher sur un monstre vivant, qui meurt AVANT la resolution
## et est LIBERE, comme le fait le banc a chaque image (GameController.flush_freed).
func _lancer_apres_mort(bf: Battlefield, c: SpellCard, ou: Vector2) -> void:
	var e: Enemy = bf.spawn_enemy(_def("t_cm_victime", 1.0), ou.x, 1.0, ou)
	var ctx := CastContext.make(bf, c)
	ctx.target_position = ou
	ctx.direction = Vector2.UP
	ctx.target_enemy = e
	bf.damage_enemy(e, 999.0, null)
	ok(e.is_dead(), "la cible meurt pendant l incantation")
	GameController.free_queued_below(bf)
	var v: Variant = e
	ok(not is_instance_valid(v), "la cible est liberee avant la resolution")
	EffectRegistry.cast(c, ctx)


# --- 1. Les copies decalees ---------------------------------------------------

## Barriere de givre : trois champs cote a cote, meme si la cible du lacher est
## morte pendant l incantation. Sans le correctif : un seul champ (les deux
## copies plantent dans GroundZone.apply).
func _test_copies_decalees_tombent_au_point_vise() -> void:
	var c: SpellCard = _prendre("frost_field", "barriere_de_givre")
	if c == null:
		return
	var bf := _field()
	var ou := Vector2(540.0, 900.0)
	var avant: int = bf.zones.size()
	_lancer_apres_mort(bf, c, ou)
	eq(bf.zones.size() - avant, 3, "trois champs poses malgre la cible liberee")
	var xs: Array[float] = []
	for z in bf.zones:
		var p: Vector2 = z["pos"]
		feq(p.y, ou.y, "chaque champ tombe a la hauteur du point vise", 0.5)
		xs.append(p.x)
	xs.sort()
	if xs.size() == 3:
		feq(xs[0], ou.x - 180.0, "champ de gauche au point vise decale", 0.5)
		feq(xs[1], ou.x, "champ central au point vise", 0.5)
		feq(xs[2], ou.x + 180.0, "champ de droite au point vise decale", 0.5)
	detach(bf)
	RunState.reset()


## Triple jet : les trois bandes repoussent, cible du lacher liberee.
func _test_triple_jet_sur_cible_liberee() -> void:
	var c: SpellCard = _prendre("water_jet", "triple_jet")
	if c == null:
		return
	var bf := _field()
	var ou := Vector2(540.0, 1000.0)
	var colonnes: Array[Enemy] = []
	for dx in [-170.0, 0.0, 170.0]:
		colonnes.append(bf.spawn_enemy(_def("t_cm_colonne", 100000.0), ou.x + dx, 1.0,
			Vector2(ou.x + dx, ou.y)))
	_lancer_apres_mort(bf, c, ou)
	var pousses: int = 0
	for e in colonnes:
		if e.position.y < ou.y - 1.0:
			pousses += 1
	eq(pousses, 3, "les trois jets repoussent malgre la cible liberee")
	detach(bf)
	RunState.reset()


## Une cible VIVANTE reste recopiee dans le contexte decale : le correctif ne
## doit pas couper ce que les handlers lisent quand elle existe.
func _test_copie_decalee_garde_une_cible_vivante() -> void:
	var c: SpellCard = _prendre("frost_field", "barriere_de_givre")
	if c == null:
		return
	var bf := _field()
	var vivante: Enemy = bf.spawn_enemy(_def("t_cm_vivante", 100000.0), 540.0, 1.0,
		Vector2(540.0, 900.0))
	var ctx := CastContext.make(bf, c)
	ctx.target_position = Vector2(540.0, 900.0)
	ctx.target_enemy = vivante
	var spec := EffectSpec.new()
	spec.key = &"ground_zone"
	spec.params = {&"aim_offset": Vector2(180.0, 0.0)}
	var copie: CastContext = EffectRegistry._w10_ctx_for(spec, ctx)
	ok(copie != null and copie != ctx, "un aim_offset rend une COPIE du contexte")
	if copie != null:
		ok(copie.target_enemy == vivante, "la copie garde la cible vivante")
		feq(copie.target_position.x, 720.0, "la copie vise le point decale", 0.5)
	# Meme contexte, cible liberee : une copie quand meme, sans cible.
	bf.damage_enemy(vivante, 999999.0, null)
	GameController.free_queued_below(bf)
	var copie2: CastContext = EffectRegistry._w10_ctx_for(spec, ctx)
	ok(copie2 != null, "cible liberee : la copie existe (elle rendait null)")
	if copie2 != null:
		ok(copie2.target_enemy == null, "cible liberee : la copie n a pas de cible")
		feq(copie2.target_position.x, 720.0, "cible liberee : la copie vise le point decale", 0.5)
	detach(bf)
	RunState.reset()


## Geyser (vague supplementaire) : la cible du lancer meurt et est liberee avant
## le rejeu ; le rejeu repart au point vise sans erreur.
func _test_rejeu_sur_cible_liberee() -> void:
	var c: SpellCard = _prendre("water_jet", "geyser")
	if c == null:
		return
	var bf := _field()
	var ou := Vector2(540.0, 1000.0)
	var victime: Enemy = bf.spawn_enemy(_def("t_cm_victime", 100000.0), ou.x, 1.0, ou)
	_lancer(bf, c, ou, victime)
	eq(bf.w10_pending_recasts(), 1, "le geyser programme un rejeu")
	bf.damage_enemy(victime, 9999999.0, null)
	GameController.free_queued_below(bf)
	var colonne: Enemy = bf.spawn_enemy(_def("t_cm_colonne", 100000.0), ou.x, 1.0, ou)
	var t: float = 0.0
	while t < 1.2:
		bf.simulate(1.0 / 60.0)
		GameController.free_queued_below(bf)
		t += SpeedGauge.world_delta(1.0 / 60.0)
		SpeedGauge.set_speed_percent(100)
	eq(bf.w10_recasts_done, 1, "le rejeu a eu lieu")
	ok(colonne.position.y < ou.y - 1.0, "le rejeu repousse au point vise")
	detach(bf)
	RunState.reset()


# --- 2. Le residu qui tue -------------------------------------------------------

## Trois residus : un sur un monstre solide (indice 0), deux sur un monstre frele
## (indices 1 et 2, deux lancers differents). Le tic tue le frele : sa mort retire
## SES DEUX residus pendant le parcours. Ancien code : index hors du tableau au
## tour suivant, la fonction s arretait, le monstre solide n etait jamais mordu.
func _test_residu_qui_tue_ne_sort_pas_du_tableau() -> void:
	RunState.reset()
	var bf := _field()
	var solide: Enemy = bf.spawn_enemy(_def("t_cm_solide", 100000.0), 300.0, 1.0,
		Vector2(300.0, 900.0))
	var frele: Enemy = bf.spawn_enemy(_def("t_cm_frele", 2.0), 700.0, 1.0,
		Vector2(700.0, 900.0))
	var tags: Array = [GameEnums.DamageTag.FIRE]
	bf._w10_add_dot(solide, 600.0, 4.0, tags, {"t_cast": 1}, {})
	bf._w10_add_dot(frele, 600.0, 4.0, tags, {"t_cast": 2}, {})
	bf._w10_add_dot(frele, 600.0, 4.0, tags, {"t_cast": 3}, {})
	eq(bf.w10_dots.size(), 3, "trois residus poses")
	var pv_avant: float = solide.hp
	bf._w10_tick_dots(1.0 / 60.0)
	ok(frele.is_dead(), "le residu tue le monstre frele")
	ok(solide.hp < pv_avant, "le residu du monstre solide mord dans le meme tic")
	eq(bf.w10_dots.size(), 1, "seul le residu du survivant reste")
	eq(bf.w10_dot_count(frele), 0, "plus aucun residu sur le mort")
	# Les tics suivants tournent sans erreur et le residu s eteint a sa duree.
	for i in 300:
		bf._w10_tick_dots(1.0 / 60.0)
	eq(bf.w10_dots.size(), 0, "le residu s eteint a sa duree")
	detach(bf)
	RunState.reset()
