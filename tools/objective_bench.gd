extends Node
## BANC DES OBJECTIFS : mesure, pour chaque objectif de niveau, combien de
## parties le reussissent quand le bot le VISE. C est l outil qui produit la
## table MESURES de tests/unit/test_level_progression.gd, qui verrouille le
## classement des objectifs du plus facile au plus dur (rang 1 rare, 2 epique,
## 3 legendaire).
##
## POURQUOI UN OUTIL VERSIONNE : la table MESURES venait d une sonde ecrite pour
## un chantier puis supprimee. Personne ne pouvait plus re-mesurer un objectif
## retouche : le classement serait devenu une supposition.
##
## Usage :
##   Godot --headless --path . tools/objective_bench.tscn
##   Godot --headless --path . tools/objective_bench.tscn -- --niveaux=lvl_01,lvl_02
##
## Options, apres `--` (toutes facultatives) :
##   --niveaux=lvl_01,lvl_02  ces niveaux seulement (defaut : tous, ordre de jeu)
##   --objectifs=obj_a,obj_b  ces objectifs seulement (dans les niveaux mesures)
##   --parties=60             parties par objectif (defaut : PARTIES, celles que
##                            test_level_progression exige pour MESURES)
##   --graine=0               decale les graines (partie i : 1000 + 37 (graine + i),
##                            les memes que le banc d equilibrage)
##   --detail                 une ligne par partie, avec son empreinte
##
## LE BOT : celui du banc d equilibrage (AutoPick : geste, cartes a la montee,
## ameliorations), plus la POLITIQUE de l objectif vise (AutoPick.politique_pour,
## une par cle, tableau en tete de cette section dans scripts/game/auto_pick.gd).
## Un objectif est REUSSI si la partie est GAGNEE et qu il est valide a la
## victoire (ObjectiveChecker.evaluate), comme a l ecran de victoire.
##
## Les objectifs a politique NEUTRE d un niveau (bot tel quel) sont mesures sur
## les MEMES parties : le banc est deterministe, les jouer une fois par objectif
## rendrait exactement les memes nombres, en plus long.
##
## DETERMINISME : deux processus a graine egale rendent les memes nombres (le
## hasard du monde passe par RunState.world_rng, fixe par RunState.set_seed ;
## verrouille par tests/unit/test_objective_bench.gd). Avant chaque partie le
## profil est remis a neuf, puis le niveau et ceux qui le precedent sont ouverts
## (regle du livre) : une partie ne depend ni de celles d avant, ni de l ordre
## des niveaux, ni du decoupage entre processus.
##
## EN PARALLELE : un processus par groupe de niveaux (--niveaux), puis on
## concatene les lignes « A COLLER » de chaque sortie. Le pas de temps et les
## graines sont fixes : la charge de la machine change la duree, pas le resultat.

const SimBalance = preload("res://tools/sim_balance.gd")

## Parties par objectif par defaut : celles que test_level_progression exige
## (PARTIES_DU_BANC) pour accepter une ligne de MESURES.
const PARTIES: int = 60
const FIXED_DELTA: float = 1.0 / 60.0
## Garde-fou anti-blocage du banc d equilibrage : une partie qui l atteint est perdue.
const MAX_SECONDS: float = SimBalance.MAX_SECONDS
## Graines : celles du banc d equilibrage et de l ancienne sonde.
const GRAINE_BASE: int = 1000
const GRAINE_PAS: int = 37
## Une empreinte de la partie toutes les N images (voir play_game).
const EMPREINTE_TOUTES: int = 30
## GARDE-FOU MEMOIRE (celui du banc d equilibrage) : au-dela, la partie est
## ARRETEE, comptee perdue et signalee, plutot que d emporter le processus.
const PLAFOND_OBJETS: int = SimBalance.PLAFOND_OBJETS


## Une partie complete, jouee par le bot avec la politique `p` (null : bot du
## banc tel quel). `g` est une partie DEJA demarree (start_level). Rend :
##   gagne      la partie est gagnee (niveau termine, mage vivant)
##   reussis    {id d objectif -> bool} pour chaque objectif du niveau, juge a
##              la victoire (tous faux sur une defaite)
##   temps, vague, vitesse, empreinte
##   liberes    noeuds liberes en cours de partie (voir plus bas)
##   en_attente noeuds encore en attente de liberation a la fin (toujours 0)
##   objets_pic objets moteur en plus du depart, au plus haut de la partie
##   alerte     "" ou la raison d un arret par le garde-fou memoire
## `max_seconds` : garde-fou anti-blocage ; une partie qui l atteint est perdue.
## Statique : le test de determinisme joue exactement cette boucle.
##
## LIBERATION A CHAQUE IMAGE (GameController.flush_freed) : toute la partie se
## joue dans UNE image moteur, le moteur ne libere donc jamais ce qui est
## `queue_free`. Sans cela, la main du HUD recreee a chaque carte jouee
## s accumulait jusqu a la fin : sur une partie figee jusqu a MAX_SECONDS (lvl_21,
## graine 2110, objectif sans feu), 17 000 cartes de main et le plantage
## « Element limit reached ». Verrouille par tests/unit/test_objective_bench.gd.
static func play_game(g: GameController, p: AutoPick.Politique,
		max_seconds: float = MAX_SECONDS) -> Dictionary:
	var vus: Dictionary = {}
	var t: float = 0.0
	var image: int = 0
	var fini: bool = false
	var trace: PackedStringArray = []
	var orientee: AutoPick.Politique = p if p != null and not p.neutre() else null
	var objets_depart: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var objets_pic: int = 0
	var liberes: int = 0
	var alerte: String = ""
	while t < max_seconds:
		t += FIXED_DELTA
		image += 1
		g.simulate(FIXED_DELTA)
		for e in g.battlefield.enemies:
			if e != null and is_instance_valid(e) and e.definition != null:
				vus[e.definition.id] = e.definition
		# Le bot joue des qu une carte est lancable (meme ordre que le banc
		# d equilibrage : simulation, releve, geste, offre, fin).
		if not g.caster.is_busy():
			AutoPick.try_play(g, orientee)
		if RunState.pending_offer.size() > 0:
			RunState.pick_offer(AutoPick.offer_index_for(RunState.pending_offer,
				vus.values(), orientee))
		if image % EMPREINTE_TOUTES == 0:
			trace.append(_instant(g))
		# Fin de l image : ce que le moteur liberait, on le libere.
		liberes += g.flush_freed()
		var objets: int = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objets_depart
		objets_pic = maxi(objets_pic, objets)
		if objets > PLAFOND_OBJETS:
			alerte = "%d objets de plus qu au depart a %.1f s (plafond %d) : partie arretee" % [
				objets, t, PLAFOND_OBJETS]
			push_warning("BANC DES OBJECTIFS : " + alerte)
			break
		if SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0:
			break
		if g.spawner.is_finished():
			fini = true
			break
	var gagne: bool = fini and alerte == "" 		and not (SpeedGauge.is_dying and SpeedGauge.death_gauge <= 0.0)
	var reussis: Dictionary = {}
	if g.level_def != null:
		for o: ObjectiveDef in g.level_def.objectives:
			if o != null:
				reussis[o.id] = gagne and ObjectiveChecker.evaluate(o)
	trace.append(_instant(g))
	return {
		"gagne": gagne, "reussis": reussis, "temps": t,
		"vague": RunState.wave_index, "vitesse": SpeedGauge.speed_percent,
		"empreinte": "|".join(trace).md5_text(),
		"liberes": liberes, "en_attente": GameController.count_queued_below(g),
		"objets_pic": objets_pic, "alerte": alerte,
	}


## Photo lisible de l etat : positions et PV des monstres, main, vitesse. Deux
## parties qui divergent, ne serait-ce que d un couloir, ont des photos
## differentes des la premiere vague.
static func _instant(g: GameController) -> String:
	var parts: PackedStringArray = []
	parts.append("%d/%d/%d" % [RunState.wave_index, SpeedGauge.speed_percent, RunState.hand.size()])
	for c in RunState.hand:
		parts.append(String((c as SpellCard).id) if c != null else "-")
	for e in g.battlefield.enemies:
		if e != null and is_instance_valid(e):
			parts.append("%s@%.1f,%.1f:%.1f" % [e.definition.id if e.definition != null else &"?",
				e.position.x, e.position.y, e.hp])
	return ",".join(parts)


## Graine de la partie i (memes graines que le banc d equilibrage).
static func graine_de(decalage: int, i: int) -> int:
	return GRAINE_BASE + (decalage + i) * GRAINE_PAS


## Rang 1 = le plus facile. Les defauts du classement mesure, avec les regles de
## test_level_progression.defauts_classement (ids dans l ordre du niveau, chaque
## objectif reussi ET rate au moins une fois, taux strictement decroissant).
static func defauts(comptes: Array, parties: int) -> Array[String]:
	var out: Array[String] = []
	var precedent: int = parties + 1
	for ligne: Array in comptes:
		var n: int = int(ligne[1])
		if n < 1:
			out.append("%s jamais reussi" % ligne[0])
		if n > parties - 1:
			out.append("%s jamais rate" % ligne[0])
		if n >= precedent:
			out.append("%s (%d) pas plus dur que le rang precedent (%d)" % [ligne[0], n, precedent])
		precedent = n
	return out


# --- Le banc ------------------------------------------------------------------

var _parties: int = PARTIES
var _decalage: int = 0
var _detail: bool = false
var _filtre: Dictionary = {}
## Lignes « a coller », dans l ordre de jeu.
var _a_coller: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_all()
	_finish()


## Point de sortie UNIQUE (voir gotchas : un return anticipe ne doit jamais
## sauter le quit).
func _finish() -> void:
	print("\n=== A COLLER DANS MESURES (tests/unit/test_level_progression.gd) ===")
	for l in _a_coller:
		print(l)
	print("=== FIN ===")
	get_tree().quit(0)


func _run_all() -> void:
	var opts: Dictionary = _options()
	_parties = maxi(1, int(opts.get("parties", PARTIES)))
	_decalage = int(opts.get("graine", 0))
	_detail = opts.has("detail")
	if opts.has("objectifs"):
		for id in String(opts["objectifs"]).split(",", false):
			_filtre[StringName(id)] = true
	var niveaux: Array[String] = SimBalance._levels()
	if opts.has("niveaux"):
		niveaux.assign(Array(String(opts["niveaux"]).split(",", false)))
	print("=== BANC DES OBJECTIFS ===")
	print("  %d parties par objectif, graines %d + %d x (%d + i), bot AutoPick qui vise l objectif"
		% [_parties, GRAINE_BASE, GRAINE_PAS, _decalage])
	for id in niveaux:
		var lv: LevelDef = ContentDB.levels.get(StringName(id))
		if lv == null:
			print("\n  %s : niveau inconnu" % id)
			continue
		await _mesurer_niveau(lv)


func _options() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var t: String = String(a).trim_prefix("--")
		var i: int = t.find("=")
		if i < 0:
			out[t] = true
		else:
			out[t.substr(0, i)] = t.substr(i + 1)
	return out


func _mesurer_niveau(lv: LevelDef) -> void:
	# Groupes de parties : un pour toutes les politiques neutres, un par
	# objectif oriente. {politique, ids}
	var groupes: Array[Dictionary] = []
	var neutre: Dictionary = {}
	var politiques: Dictionary = {}
	for o: ObjectiveDef in lv.objectives:
		if o == null or (not _filtre.is_empty() and not _filtre.has(o.id)):
			continue
		var p: AutoPick.Politique = AutoPick.politique_pour(o, lv)
		politiques[o.id] = p
		if p.neutre():
			if neutre.is_empty():
				neutre = {"politique": null, "ids": []}
				groupes.append(neutre)
			neutre["ids"].append(o.id)
		else:
			groupes.append({"politique": p, "ids": [o.id]})
	if groupes.is_empty():
		return
	print("\n  %s (%s)" % [lv.id, lv.display_name])
	var reussites: Dictionary = {}
	var victoires: Dictionary = {}
	for gr: Dictionary in groupes:
		var p: AutoPick.Politique = gr["politique"]
		var nom: String = "bot tel quel" if p == null else String(gr["ids"][0])
		var gagnees: int = 0
		for i in _parties:
			var r: Dictionary = await _une_partie(lv, p, graine_de(_decalage, i))
			if r["gagne"]:
				gagnees += 1
			for id in gr["ids"]:
				if bool(r["reussis"].get(id, false)):
					reussites[id] = int(reussites.get(id, 0)) + 1
			if _detail:
				print("    [%s] partie %d graine %d : %s en %.1f s, vague %d, vitesse %d %%, objectifs %s, objets +%d, empreinte %s"
					% [nom, i, graine_de(_decalage, i), "victoire" if r["gagne"] else "defaite",
						r["temps"], r["vague"], r["vitesse"], _bits(lv, r["reussis"]),
						r["objets_pic"], r["empreinte"]])
			if String(r["alerte"]) != "":
				print("    ALERTE MEMOIRE [%s] partie %d graine %d : %s"
					% [nom, i, graine_de(_decalage, i), r["alerte"]])
		for id in gr["ids"]:
			victoires[id] = gagnees
	# Le rapport, dans l ordre du niveau, avec le rang MESURE (1 = le plus facile).
	var comptes: Array = []
	for o: ObjectiveDef in lv.objectives:
		if o != null and politiques.has(o.id):
			comptes.append([String(o.id), int(reussites.get(o.id, 0))])
	var tri: Array = comptes.duplicate()
	tri.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	for k in comptes.size():
		var ligne: Array = comptes[k]
		var p: AutoPick.Politique = politiques[StringName(ligne[0])]
		print("    niveau #%d, rang mesure %d  %-48s %3d / %d  (%3.0f %%)  victoires %d  [%s]"
			% [k + 1, tri.find(ligne) + 1, ligne[0], ligne[1], _parties,
				100.0 * float(ligne[1]) / float(_parties), victoires[StringName(ligne[0])],
				p.resume])
	var complet: bool = comptes.size() == lv.objectives.size()
	if complet:
		var d: Array[String] = defauts(comptes, _parties)
		print("    classement : " + ("CONFORME (du plus facile au plus dur)" if d.is_empty()
			else "NON CONFORME : " + "; ".join(d)))
	var morceaux: PackedStringArray = []
	for ligne: Array in comptes:
		morceaux.append("[\"%s\", %d]" % [ligne[0], ligne[1]])
	var a_coller: String = "\t\"%s\": [%s]," % [lv.id, ", ".join(morceaux)]
	if not complet:
		a_coller += "  # PARTIEL (--objectifs)"
	if _parties != PARTIES:
		a_coller += "  # %d parties, MESURES en exige %d" % [_parties, PARTIES]
	print("    MESURES " + a_coller.strip_edges())
	_a_coller.append(a_coller)


## Une partie, sur une graine, profil remis a neuf. La partie est detruite
## IMMEDIATEMENT (voir sim_balance._drop_game : une partie liberee en fin
## d image continuait a piloter les autoloads pendant la suivante).
func _une_partie(lv: LevelDef, p: AutoPick.Politique, graine: int) -> Dictionary:
	SaveData.reset_profile()
	# Profil d un joueur qui arrive a ce niveau : lui et ceux d avant sont ouverts
	# (regle du livre : le deck d un niveau ouvert est obtenu).
	SimBalance.open_levels_up_to(lv.id)
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	RunState.set_seed(graine)
	g.start_level(lv, GameEnums.Mode.EXPLORATION)
	var r: Dictionary = play_game(g, p)
	g.running = false
	remove_child(g)
	g.free()
	await get_tree().process_frame
	return r


func _bits(lv: LevelDef, reussis: Dictionary) -> String:
	var s: String = ""
	for o: ObjectiveDef in lv.objectives:
		if o != null:
			s += "1" if bool(reussis.get(o.id, false)) else "0"
	return s
