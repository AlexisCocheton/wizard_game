extends TestCase
## LES CARTES DE LA VAGUE 10 (chantier B1a) : les six sorts demandes par le
## co-auteur, les rares passees en commune, les communes qui couvrent les huit
## elements et les roles de base, la dette des sons soldee.
##
## Les chiffres des cartes sont des REGLAGES : ils ne sont pas ecrits ici. Ce
## qui l est, ce sont les REGLES de la demande (« sur tout le plateau », « jusqu a
## 0 », « forme de I », « commune »...), exprimees en rapports entre cartes.

const E := GameEnums.DamageTag

## id -> [element, cle d effet] : la demande du co-auteur, mot pour mot.
const DEMANDEES: Dictionary = {
	&"south_wind": [E.WIND, &"global_wind"],
	&"electric_mark": [E.LIGHTNING, &"electric_mark"],
	&"heavy_rain": [E.WATER, &"global_rain"],
	&"purifying_light": [E.ARCANE, &"dispel_zone"],
	&"quicksand": [E.NATURE, &"quicksand"],
	&"water_jet": [E.WATER, &"water_jet"],
}

## Les rares les plus simples, passees en commune (voir l en-tete de _cards).
const DEVENUES_COMMUNES: Array[StringName] = [&"stone_wall", &"meteor", &"chain_break",
	&"salt_spiral", &"cycle_of_thought", &"quickening", &"bone_recall", &"purifying_light"]


func get_suite_name() -> String:
	return "w10_cartes"


func run() -> void:
	_test_les_six_cartes_demandees()
	_test_le_vent_du_sud()
	_test_la_marque_electrique()
	_test_la_pluie_abondante()
	_test_la_lumiere_purifiante()
	_test_le_sable_mouvant()
	_test_le_jet_d_eau()
	_test_les_rares_devenues_communes()
	_test_les_communes_couvrent_les_huit_elements()
	_test_les_communes_couvrent_les_roles()
	_test_une_commune_par_niveau()
	_test_le_son_ne_vit_qu_a_un_endroit()


func _carte(id: StringName) -> SpellCard:
	return ContentDB.cards.get(id)


func _spec(c: SpellCard, cle: StringName) -> EffectSpec:
	if c == null:
		return null
	for s: EffectSpec in c.effects:
		if s != null and s.key == cle:
			return s
	return null


func _test_les_six_cartes_demandees() -> void:
	for id in DEMANDEES:
		var c: SpellCard = _carte(id)
		ok(c != null, "%s existe" % id)
		if c == null:
			continue
		eq(c.rarity, GameEnums.Rarity.COMMON, "%s est commune" % id)
		eq(int(c.element), int(DEMANDEES[id][0]), "%s porte son element" % id)
		ok(_spec(c, DEMANDEES[id][1]) != null, "%s compose la cle %s" % [id, DEMANDEES[id][1]])
		ok(c.base_cast_time > 0.0, "%s a une incantation" % id)
		ok(c.fx_key != &"" and c.sfx_key != &"", "%s a sa feuille et son son" % id)


## « Agit sur tout le plateau 6 s » : aucune visee, une duree, aucun degat.
func _test_le_vent_du_sud() -> void:
	var c: SpellCard = _carte(&"south_wind")
	var s: EffectSpec = _spec(c, &"global_wind")
	if s == null:
		return
	eq(c.targeting, GameEnums.Targeting.NONE, "le vent ne se vise pas : tout le terrain")
	ok(s.duration > 0.0, "le vent dure")
	feq(s.magnitude, 0.0, "le vent ne blesse pas")


## « S il meurt, la marque saute avec 1 degat de moins, jusqu a 0 » : un
## monstre vise, et une chaine qui s eteint d elle-meme.
func _test_la_marque_electrique() -> void:
	var c: SpellCard = _carte(&"electric_mark")
	var s: EffectSpec = _spec(c, &"electric_mark")
	if s == null:
		return
	eq(c.targeting, GameEnums.Targeting.TARGET, "la marque se pose sur un monstre")
	var baisse: float = float(s.get_param(&"decay", 1.0))
	ok(baisse > 0.0, "chaque saut perd des degats : la chaine finit")
	ok(s.magnitude > baisse, "la marque peut sauter au moins une fois")
	feq(fmod(s.magnitude, baisse), 0.0, "la chaine tombe pile a 0", 0.001)


## « Pluie sur tout le terrain, 1 degat d eau toutes les 2 s » : plusieurs
## gouttes, aucune visee.
func _test_la_pluie_abondante() -> void:
	var c: SpellCard = _carte(&"heavy_rain")
	var s: EffectSpec = _spec(c, &"global_rain")
	if s == null:
		return
	eq(c.targeting, GameEnums.Targeting.NONE, "la pluie tombe sur tout le terrain")
	var intervalle: float = float(s.get_param(&"interval", GameConfig.RAIN_INTERVAL))
	ok(s.duration / intervalle >= 2.0, "plusieurs gouttes par pluie")
	ok(s.magnitude > 0.0, "chaque goutte mord")


## Commune, et plus longue a lancer que le Vide d emprise, l epique du meme verbe.
func _test_la_lumiere_purifiante() -> void:
	var lumiere: SpellCard = _carte(&"purifying_light")
	var vide: SpellCard = _carte(&"void_grip")
	if lumiere == null or vide == null:
		ok(false, "Lumiere purifiante et Vide d emprise existent")
		return
	ok(lumiere.base_cast_time > vide.base_cast_time,
		"la commune se prepare, l epique part plus vite")


## « -10 % de vitesse ; les monstres encore dedans a la fin subissent des
## degats ; duree assez longue » : un ralentissement LEGER (moins que le Champ
## de givre), des degats a la fin, une zone qui dure plus que le givre.
func _test_le_sable_mouvant() -> void:
	var s: EffectSpec = _spec(_carte(&"quicksand"), &"quicksand")
	var givre: EffectSpec = _spec(_carte(&"frost_field"), &"ground_zone")
	if s == null or givre == null:
		ok(false, "Sable mouvant et Champ de givre existent")
		return
	ok(s.magnitude > 0.0, "le sable avale : degats a la fin")
	ok(float(s.get_param(&"slow_pct", 0.0)) > 0.0, "le sable ralentit")
	ok(float(s.get_param(&"slow_pct", 0.0)) < float(givre.get_param(&"slow_pct", 0.0)),
		"le sable retient moins que le givre")
	ok(s.duration > givre.duration, "le sable dure plus que le givre")
	ok(s.radius > 0.0, "le sable est une zone")


## « Bande fine et haute (forme de I) qui repousse, degats selon la distance » :
## plus haute que trois fois sa largeur, une poussee, des degats par distance.
func _test_le_jet_d_eau() -> void:
	var c: SpellCard = _carte(&"water_jet")
	var s: EffectSpec = _spec(c, &"water_jet")
	if s == null:
		return
	var largeur: float = 2.0 * s.radius
	var hauteur: float = float(s.get_param(&"length", 0.0))
	ok(largeur > 0.0 and hauteur > 3.0 * largeur, "le jet est un I : fin et haut (%d x %d)"
		% [int(largeur), int(hauteur)])
	ok(float(s.get_param(&"push", 0.0)) > 0.0, "le jet repousse")
	ok(s.magnitude > 0.0, "le jet blesse selon la distance parcourue")
	eq(c.targeting, GameEnums.Targeting.POSITION, "le jet se vise : un couloir")


## Les rares passees en commune le sont, et leur ancienne fiche a disparu : un
## .tres laisse dans rare/ ferait charger deux cartes du meme id.
func _test_les_rares_devenues_communes() -> void:
	for id in DEVENUES_COMMUNES:
		var c: SpellCard = _carte(id)
		ok(c != null, "%s existe" % id)
		if c != null:
			eq(c.rarity, GameEnums.Rarity.COMMON, "%s est commune" % id)
		not_ok(FileAccess.file_exists("res://resources/cards/rare/%s.tres" % id),
			"plus de fiche perimee pour %s" % id)
	ok(ContentDB.duplicate_ids.is_empty(), "aucun id duplique au catalogue")


static func communes() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.rarity == GameEnums.Rarity.COMMON:
			out.append(c)
	return out


func _test_les_communes_couvrent_les_huit_elements() -> void:
	var vus: Dictionary = {}
	for c in communes():
		vus[int(c.element)] = true
	for el in GameEnums.ELEMENTS:
		ok(vus.has(el), "une commune au moins est de %s" % GameEnums.tag_name(el))


## Les roles de base de la demande : degats mono-cible, zone, ralentissement,
## mur (bloque-projectiles), pioche / rapidite, controle.
func _test_les_communes_couvrent_les_roles() -> void:
	var roles: Dictionary = {
		"degats mono-cible": [&"damage_single", &"poison_dot", &"electric_mark"],
		"zone": [&"ground_zone", &"global_rain", &"knockback"],
		"mur": [&"build_wall"],
		"pioche ou rapidite": [&"discard_draw", &"draw_cards", &"draw_boost", &"self_haste",
			&"retain_next"],
		"controle": [&"global_wind", &"vortex_pull", &"knockback", &"water_jet",
			&"reverse_enemies", &"dispel_zone"],
	}
	for role in roles:
		var trouve: bool = false
		for c in communes():
			for k in c.effect_keys():
				if k in roles[role]:
					trouve = true
		ok(trouve, "une commune tient le role %s" % role)
	var ralentit: bool = false
	for c in communes():
		for s: EffectSpec in c.effects:
			if s != null and float(s.get_param(&"slow_pct", 0.0)) > 0.0:
				ralentit = true
	ok(ralentit, "une commune ralentit")


## La campagne refaite donne une commune NOUVELLE par niveau (co-auteur, 14/10).
func _test_une_commune_par_niveau() -> void:
	var niveaux: int = 0
	for lv: LevelDef in ContentDB.campaign_levels():
		if lv != null:
			niveaux += 1
	ok(niveaux > 0, "des niveaux de campagne")
	ok(communes().size() >= niveaux, "%d communes pour %d niveaux de campagne"
		% [communes().size(), niveaux])


## Dette de la phase A soldee : le son d un sort vit dans son sfx_key, la table
## de secours d AudioBus est vide.
func _test_le_son_ne_vit_qu_a_un_endroit() -> void:
	ok(AudioBus.CARD_SFX.is_empty(), "AudioBus.CARD_SFX est vide : le son est dans la carte")
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive:
			eq(AudioBus.card_sfx_key(c), c.sfx_key, "%s joue son propre sfx_key" % c.id)
