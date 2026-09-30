extends TestCase
## LES CHOIX AUTOMATIQUES du banc et des parties headless (AutoPick).
##
## Pourquoi ces tests : le banc prenait toujours la PREMIERE option. Tant que
## l offre d amelioration etait fixe, c etait l identite du sort en forme forte ;
## depuis qu elle est tiree puis melangee, c etait une voie au hasard, et le banc
## a mesure un joueur qui choisit a pile ou face sans que personne ne le voie
## (lvl_16 : 25 -> 14 victoires sur 30, jeu inchange). Ces tests verrouillent que
## le choix suit une REGLE, et qu il ne depend pas de l ordre d affichage.
##
## Aucune valeur de reglage : tout se lit sur le catalogue et sur les constantes.

func get_suite_name() -> String:
	return "auto_pick"


func run() -> void:
	_test_l_amelioration_suit_la_regle_sur_tout_le_catalogue()
	_test_l_amelioration_ne_depend_pas_de_l_ordre()
	_test_la_partie_headless_applique_la_regle()
	_test_la_carte_resistee_n_est_pas_prise()
	_test_hors_resistance_la_premiere_carte()


func _sorts() -> Array[SpellCard]:
	var out: Array[SpellCard] = []
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c != null and not c.is_passive:
			out.append(c)
	return out


func _rang(card: SpellCard, v: Dictionary) -> int:
	var identite: StringName = RunState.upgrade_identity_axis(card)
	var axe: StringName = StringName(v["axis"])
	var forme: StringName = StringName(v["form"])
	if axe == identite and forme == RunState.UP_STRONG:
		return 3
	if axe == RunState.UP_CAST and forme == RunState.UP_STRONG:
		return 2
	if axe == identite and forme == RunState.UP_LIGHT:
		return 1
	return 0


## Pour chaque sort du catalogue et plusieurs tirages : la voie retenue est
## toujours du MEILLEUR rang present dans l offre (identite forte, puis vitesse
## forte, puis identite legere).
func _test_l_amelioration_suit_la_regle_sur_tout_le_catalogue() -> void:
	var offres: int = 0
	var hors_premiere: int = 0
	for c in _sorts():
		for graine in 6:
			RunState.reset()
			RunState.set_seed(4100 + graine)
			var voies: Array = RunState.draw_upgrade_offer(c)
			if voies.is_empty():
				continue
			offres += 1
			var k: int = AutoPick.upgrade_index(c, voies)
			ok(k >= 0 and k < voies.size(), "%s : indice dans l offre" % c.id)
			var meilleur: int = 0
			for v in voies:
				meilleur = maxi(meilleur, _rang(c, v))
			eq(_rang(c, voies[k]), meilleur,
				"%s (graine %d) : la voie retenue %s est du meilleur rang de l offre %s"
				% [c.id, graine, voies[k]["id"], _ids(voies)])
			if k != 0:
				hors_premiere += 1
	ok(offres > 0, "le catalogue produit des offres d amelioration")
	# Le test mord : si la regle revenait a "la premiere", une bonne part des
	# offres serait mal tranchee (l ordre est melange).
	ok(hors_premiere > 0, "la regle retient parfois une autre voie que la premiere")
	RunState.reset()


## L offre est MELANGEE a l affichage : le choix ne doit pas en dependre des
## qu une regle le designe.
func _test_l_amelioration_ne_depend_pas_de_l_ordre() -> void:
	for c in _sorts():
		RunState.reset()
		RunState.set_seed(4300)
		var voies: Array = RunState.draw_upgrade_offer(c)
		if voies.size() < 2:
			continue
		var k: int = AutoPick.upgrade_index(c, voies)
		if _rang(c, voies[k]) == 0:
			continue
		var retournee: Array = voies.duplicate()
		retournee.reverse()
		var k2: int = AutoPick.upgrade_index(c, retournee)
		eq(retournee[k2]["id"], voies[k]["id"],
			"%s : meme voie retenue quel que soit l ordre de l offre" % c.id)
	RunState.reset()


## Une vraie partie headless tranche l ecran d amelioration avec la regle, et
## non avec la premiere option. On ecoute l offre APRES GameController : la voie
## prise est deja connue quand notre ecouteur la recoit.
var _vu_offre: Array = []
var _vu_carte: SpellCard = null


func _on_offre(card: SpellCard, paths: Array) -> void:
	_vu_carte = card
	_vu_offre = paths


func _test_la_partie_headless_applique_la_regle() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	ok(level != null, "lvl_01 existe")
	if level == null:
		return
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	attach(g)
	var tranchees: int = 0
	var hors_premiere: int = 0
	for c in _sorts():
		for graine in 3:
			RunState.set_seed(4500 + graine)
			g.start_level(level, GameEnums.Mode.EXPLORATION)
			g.running = false
			if not RunState.upgrade_ready.is_connected(_on_offre):
				RunState.upgrade_ready.connect(_on_offre)
			_vu_offre = []
			_vu_carte = null
			for i in RunState.next_upgrade_at(c):
				RunState.note_cast(c)
			if _vu_offre.is_empty():
				continue
			tranchees += 1
			var attendu: int = AutoPick.upgrade_index(_vu_carte, _vu_offre)
			eq(RunState.upgrade_of(c), StringName(_vu_offre[attendu]["id"]),
				"%s : la partie headless prend la voie de la regle" % c.id)
			ok(RunState.pending_upgrade_card == null, "%s : l offre est tranchee, la partie ne reste pas en pause" % c.id)
			if attendu != 0:
				hors_premiere += 1
	if RunState.upgrade_ready.is_connected(_on_offre):
		RunState.upgrade_ready.disconnect(_on_offre)
	ok(tranchees > 0, "des offres ont ete tranchees en partie headless")
	ok(hors_premiere > 0, "au moins une offre ou la regle differe de la premiere option")
	detach(g)
	RunState.reset()


func _ids(voies: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v in voies:
		out.append(StringName(v.get("id", &"")))
	return out


## Un monstre, un sort qu il RESISTE et un sort qu il ne resiste pas. Lu dans
## le contenu : aucune resistance ecrite ici.
func _paire_resistee() -> Dictionary:
	var sorts: Array[SpellCard] = _sorts()
	var ids: Array = ContentDB.enemies.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var d: EnemyDef = ContentDB.enemies[id]
		for r in sorts:
			if d.resistance_to_tags(r.tags) >= AutoPick.RESISTED:
				continue
			for n in sorts:
				if d.resistance_to_tags(n.tags) >= AutoPick.RESISTED:
					return {"monstre": d, "resiste": r, "neutre": n}
	return {}


func _test_la_carte_resistee_n_est_pas_prise() -> void:
	var p: Dictionary = _paire_resistee()
	ok(not p.is_empty(), "le catalogue a un monstre qui resiste a un sort")
	if p.is_empty():
		return
	var seen: Array = [p["monstre"]]
	var offre: Array = [p["resiste"], p["neutre"]]
	eq(AutoPick.offer_index(offre, seen), 1,
		"%s resiste a %s : le bot prend %s, meme propose en second"
		% [p["monstre"].id, p["resiste"].id, p["neutre"].id])
	# Sans monstre croise, rien a lire : aucune carte n est ecartee pour une
	# resistance que le joueur n a pas encore vue.
	feq(AutoPick.element_factor(p["resiste"], []), 1.0, "sans monstre croise, facteur neutre")
	eq(AutoPick.offer_index(offre, []), 0, "sans monstre croise, la premiere carte proposee")
	# Tout est resiste : le moins resiste, pas une case vide ni la premiere.
	var pire: SpellCard = null
	var pire_f: float = 2.0
	for c in _sorts():
		var f: float = p["monstre"].resistance_to_tags(c.tags)
		if f < pire_f:
			pire_f = f
			pire = c
	if pire != null and pire_f < p["monstre"].resistance_to_tags(p["resiste"].tags):
		eq(AutoPick.offer_index([pire, p["resiste"]], seen), 1,
			"tout est resiste : le bot prend le moins resiste (%s plutot que %s)"
			% [p["resiste"].id, pire.id])


## Hors resistance, le bot garde la PREMIERE carte : chaque case de l offre est
## un tirage independant du pool. Une regle "sort qui frappe, puis rarete" a ete
## mesuree et rejetee (voir AutoPick.offer_index) ; ce test empeche qu elle
## revienne sans passer par le banc.
func _test_hors_resistance_la_premiere_carte() -> void:
	var sorts: Array[SpellCard] = _sorts()
	var seen: Array = []
	var ids: Array = ContentDB.enemies.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids.slice(0, 4):
		seen.append(ContentDB.enemies[id])
	var verifiees: int = 0
	for i in range(0, sorts.size() - 2, 3):
		var offre: Array = [sorts[i], sorts[i + 1], sorts[i + 2]]
		if AutoPick.element_factor(offre[0], seen) < AutoPick.RESISTED:
			continue
		verifiees += 1
		eq(AutoPick.offer_index(offre, seen), 0,
			"offre %s, %s, %s : la premiere, que rien ne resiste"
			% [offre[0].id, offre[1].id, offre[2].id])
	ok(verifiees > 0, "des offres sans resistance ont ete verifiees")
