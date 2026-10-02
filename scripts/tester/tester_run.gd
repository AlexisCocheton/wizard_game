class_name TesterRun
extends RefCounted
## L ONGLET TEST : composer une vague et la JOUER tout de suite.
##
## "Creer un onglet TEST ou je peux composer une vague pour tester les monstres
## et les sorts."
##
## UNE VRAIE PARTIE, PAS UNE SIMULATION. On reutilise GameController tel quel
## avec un LevelDef FABRIQUE, exactement comme MassacreMode.level_def() : le
## testeur juge un monstre ou un sort dans les conditions du jeu (HUD, vitesse,
## pioche, incantation), pas dans un bac a sable qui finirait par diverger.
##
## AUCUN .tres. Le niveau de test n existe pas dans ContentDB (son id ne doit
## jamais y etre) : il n est donc compte ni par la campagne, ni par l AUDIT, ni
## par les ecrans de fin. A la fin de la partie on revient aux outils du testeur
## avec le bilan, sans passer par l ecran de victoire, qui debloquerait le
## "niveau suivant" et distribuerait des recompenses de campagne.

const LEVEL_ID: StringName = &"tester_wave"
const DISPLAY_NAME: String = "Vague de test"
## Cle de la charge utile du routeur : sa presence fait d une partie une partie
## de test (GameController._ready).
const PAYLOAD_KEY: String = "tester_run"
const TOOLS_SCENE: String = "res://scenes/tester/TesterTools.tscn"

## Bornes de la composition. La vitesse suit la jauge : sous 100 % le mage est
## deja mort, au-dela du maximum la jauge refuse.
const MAX_ENTRIES: int = 12
const MAX_COUNT: int = 60
const MAX_CARDS: int = 30
const DEFAULT_SPEED: int = 150

## Derniere composition et dernier bilan : gardes entre deux parties pour que
## "rejouer apres une retouche" ne demande pas de tout recomposer.
static var composition: Dictionary = {}
static var last_result: Dictionary = {}


## Composition par defaut : quelques gnomes, le deck de depart, la vitesse de
## depart du jeu. Jouable telle quelle, au premier toucher.
static func default_composition() -> Dictionary:
	var cartes: Array = []
	for id in DeckRules.default_deck_ids():
		cartes.append(String(id))
	return {
		"entries": [{"enemy": "gnome", "count": 5}],
		"cards": cartes,
		"speed": GameConfig.SPEED_START_PERCENT,
		"difficulty": 1.0,
		"backdrop": "act1_sky",
	}


static func current() -> Dictionary:
	if composition.is_empty():
		composition = default_composition()
	return composition


## Le LevelDef fabrique : une seule vague, ecrite, avec le deck choisi.
## Une entree dont le monstre n existe plus (mise a jour du contenu) est sautee
## plutot que de faire planter la partie.
static func make_level(comp: Dictionary) -> LevelDef:
	var d := LevelDef.new()
	d.id = LEVEL_ID
	d.display_name = DISPLAY_NAME
	d.act = 0
	d.subtitle = "Composee dans les outils du testeur"
	d.backdrop = String(comp.get("backdrop", "act1_sky"))
	var w := WaveDef.new()
	w.id = &"tester_w1"
	w.difficulty = clampf(float(comp.get("difficulty", 1.0)), 0.05, 20.0)
	var entrees: Array[WaveEntry] = []
	var pool: Array[EnemyDef] = []
	var decalage: float = 0.0
	for e in comp.get("entries", []):
		var def: EnemyDef = ContentDB.enemies.get(StringName(String(e.get("enemy", ""))))
		if def == null:
			continue
		var we := WaveEntry.new()
		we.enemy = def
		we.count = clampi(int(e.get("count", 1)), 1, MAX_COUNT)
		we.spawn_delay = float(e.get("spawn_delay", 1.2))
		# Les groupes arrivent l un apres l autre, comme dans une vague ecrite :
		# tout lacher a la seconde 0 empilerait les monstres sur la meme ligne.
		we.start_offset = decalage
		decalage += 2.0
		entrees.append(we)
		if not pool.has(def):
			pool.append(def)
	w.entries = entrees
	w.duration = maxf(20.0, decalage + 20.0)
	for we2 in entrees:
		if we2.enemy.is_boss():
			w.is_boss = true
	var vagues: Array[WaveDef] = [w]
	d.waves = vagues
	d.enemy_pool = pool
	var deck: Array[SpellCard] = []
	for id in comp.get("cards", []):
		var c: SpellCard = ContentDB.cards.get(StringName(String(id)))
		if c != null and not c.is_passive and deck.size() < MAX_CARDS:
			deck.append(c)
	d.exploration_deck = deck
	return d


## Ce que la composition a de bancal, en clair. Vide = jouable.
static func problems(comp: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if make_level(comp).waves[0].entries.is_empty():
		out.append("ajoute au moins un monstre")
	if make_level(comp).exploration_deck.is_empty():
		out.append("ajoute au moins une carte")
	return out


## Lance la partie. Passe directement par la scene de jeu : le briefing
## (LoadingScreen) lit son niveau dans ContentDB, ou celui-ci n est pas.
static func start(comp: Dictionary) -> void:
	composition = comp.duplicate(true)
	SceneRouter.goto(SceneRouter.GAME, {
		"level_id": LEVEL_ID,
		"mode": GameEnums.Mode.EXPLORATION,
		PAYLOAD_KEY: comp.duplicate(true),
	})


static func is_test_payload(payload: Dictionary) -> bool:
	return payload.has(PAYLOAD_KEY)


## Appele par GameController._ready() pour une partie de test : fabrique le
## niveau, demarre, puis pose la vitesse de depart. APRES start_level(), qui
## remet la jauge a neuf (meme piege que `running`, voir la memoire du projet).
static func start_in(game: GameController, payload: Dictionary) -> void:
	var comp: Dictionary = payload.get(PAYLOAD_KEY, {})
	# LE HASARD DE LA VAGUE passe par RunState.world_rng, comme toute partie :
	# start_level() seme le WaveSpawner sur RunState.world_seed(). Une graine
	# donnee dans la composition rejoue donc la MEME vague (couloirs, esquives),
	# ce qui permet de comparer deux reglages a hasard egal. 0 = au hasard.
	var graine: int = int(comp.get("seed", 0))
	if graine != 0:
		RunState.set_seed(graine)
	game.start_level(make_level(comp), GameEnums.Mode.EXPLORATION)
	apply_speed(comp)


static func apply_speed(comp: Dictionary) -> void:
	var v: int = clampi(int(comp.get("speed", GameConfig.SPEED_START_PERCENT)),
		101, GameConfig.SPEED_MAX_PERCENT)
	SpeedGauge.set_speed_percent(v)


## Fin d une partie : si c etait une partie de test, retour aux outils avec le
## bilan, et vrai. Sinon faux, et l appelant suit sa route normale.
static func end_run(level: LevelDef, won: bool) -> bool:
	if level == null or level.id != LEVEL_ID:
		return false
	last_result = result_of(won)
	SceneRouter.goto(TOOLS_SCENE, {"tab": "test"})
	return true


static func result_of(won: bool) -> Dictionary:
	return {
		"won": won,
		"seconds": RunState.run_time,
		"speed": SpeedGauge.speed_percent,
		"kills": RunState.kill_times.size(),
	}


static func result_text() -> String:
	if last_result.is_empty():
		return ""
	var t: String = "Derniere partie : %s" % ("VICTOIRE" if last_result["won"] else "DEFAITE")
	if float(last_result.get("seconds", 0.0)) > 0.0:
		t += " en %d s" % int(last_result["seconds"])
	t += ", %d morts" % int(last_result.get("kills", 0))
	t += ", vitesse finale %d %%" % int(last_result.get("speed", 0))
	return t
