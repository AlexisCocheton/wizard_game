extends Node
## Profil persistant. Ecriture atomique, migration de schema, lecture tolerante.
##
## En headless (tests), la persistance est DESACTIVEE : les tests ne lisent ni
## n ecrivent jamais le vrai profil du joueur, et partent toujours d un etat neuf.

signal save_loaded()
signal profile_changed()
signal account_level_up(new_level: int)
signal challenge_completed(challenge: ChallengeDef)

const SAVE_PATH: String = "user://profile.json"
const CORRUPT_PATH: String = "user://profile.corrupt.json"
const CURRENT_VERSION: int = 1

var _data: Dictionary = {}
var persistence_enabled: bool = true


func _ready() -> void:
	persistence_enabled = DisplayServer.get_name() != "headless"
	load_profile()


func _defaults() -> Dictionary:
	return {
		"schema_version": CURRENT_VERSION,
		"profile": {
			"discovered_cards": [],
			"unlocked_legendaries": [],
			"campaign": {"current_node": "lvl_01", "unlocked_levels": ["lvl_01"]},
			"levels": {},
			"massacre_deck": [],
			"discovered_enemies": [],
			"account": {"level": 1, "xp": 0, "challenges": [], "stats": {}},
			## Scenes d histoire deja vues : une scene ne se rejoue pas quand on
			## refait un niveau. _migrate() ajoute la cle aux vieux profils.
			"stories_seen": [],
		},
		"settings": {
			"master_volume": 0.8,
			"sfx_volume": 1.0,
			"music_volume": 0.6,
			"haptics": true,
			"language": "fr",
		},
	}


func load_profile() -> void:
	_data = _defaults()
	if not persistence_enabled or not FileAccess.file_exists(SAVE_PATH):
		save_loaded.emit()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		save_loaded.emit()
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Sauvegarde illisible : on la met de cote plutot que de planter.
		var bad := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
		if bad != null:
			bad.store_string(raw)
			bad.close()
		push_warning("Profil illisible, sauvegarde mise de cote et profil neuf cree.")
		save_loaded.emit()
		return
	_data = _migrate(parsed as Dictionary)
	save_loaded.emit()


func _migrate(d: Dictionary) -> Dictionary:
	var version: int = int(d.get("schema_version", 0))
	while version < CURRENT_VERSION:
		match version:
			0:
				d = _migrate_0_to_1(d)
			_:
				break
		version = int(d.get("schema_version", version + 1))
	# Complete les cles manquantes sans ecraser l existant.
	var base: Dictionary = _defaults()
	for key: String in base:
		if not d.has(key):
			d[key] = base[key]
	for key: String in base["profile"]:
		if not d["profile"].has(key):
			d["profile"][key] = base["profile"][key]
	for key: String in base["settings"]:
		if not d["settings"].has(key):
			d["settings"][key] = base["settings"][key]
	return d


func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	d["schema_version"] = 1
	if not d.has("profile"):
		d["profile"] = _defaults()["profile"]
	return d


func save_profile() -> void:
	profile_changed.emit()
	if not persistence_enabled:
		return
	# Ecriture atomique : fichier temporaire puis renommage, pour qu un crash
	# en cours d ecriture ne corrompe jamais le profil existant.
	var tmp: String = SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d ecrire la sauvegarde : %s" % tmp)
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists(SAVE_PATH.get_file()):
			dir.remove(SAVE_PATH.get_file())
		dir.rename(tmp.get_file(), SAVE_PATH.get_file())


func profile() -> Dictionary:
	return _data.get("profile", {})


func settings() -> Dictionary:
	return _data.get("settings", {})


# --- Reglages ---

func get_setting(key: String, default_value: Variant) -> Variant:
	return settings().get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	settings()[key] = value
	profile_changed.emit()


# --- Cartes ---

func discover_card(card_id: StringName) -> void:
	var found: Array = profile().get("discovered_cards", [])
	if not found.has(String(card_id)):
		found.append(String(card_id))
		profile()["discovered_cards"] = found
		profile_changed.emit()


func is_discovered(card_id: StringName) -> bool:
	return profile().get("discovered_cards", []).has(String(card_id))


func discovered_count() -> int:
	return profile().get("discovered_cards", []).size()


func unlocked_legendaries() -> Array:
	return profile().get("unlocked_legendaries", [])


# --- Bestiaire ---
##
## Un monstre n'entre au bestiaire qu'apres avoir ete RENCONTRE en jeu : la
## consultation de ses competences est une recompense d'exploration, pas une
## fiche technique offerte d'emblee. L'appel vient de Battlefield.spawn_enemy().

func discover_enemy(enemy_id: StringName) -> void:
	if String(enemy_id) == "":
		return
	var found: Array = profile().get("discovered_enemies", [])
	if found.has(String(enemy_id)):
		return
	# On n'emet le signal QUE sur une vraie premiere rencontre : spawn_enemy est
	# appele des dizaines de fois par vague, et profile_changed reconstruit l'UI.
	found.append(String(enemy_id))
	profile()["discovered_enemies"] = found
	profile_changed.emit()


func is_enemy_discovered(enemy_id: StringName) -> bool:
	return profile().get("discovered_enemies", []).has(String(enemy_id))


## Copie : l'appelant ne doit jamais pouvoir vider la liste du profil en la
## triant ou en la modifiant (piege deja rencontre avec offer_choices()).
func discovered_enemies() -> Array:
	return profile().get("discovered_enemies", []).duplicate()


func discovered_enemies_count() -> int:
	return profile().get("discovered_enemies", []).size()


# --- Histoire ---
##
## Une scene de visual novel se joue UNE fois : rejouer un niveau pour ses
## objectifs ne doit pas imposer de relire le dialogue. Le profil retient les
## ids vus ; SceneRouter consulte la liste avant de router vers StoryScene.

func mark_story_seen(story_id: StringName) -> void:
	if String(story_id) == "":
		return
	var seen: Array = profile().get("stories_seen", [])
	if seen.has(String(story_id)):
		return
	seen.append(String(story_id))
	profile()["stories_seen"] = seen
	profile_changed.emit()


## Un id vide compte comme "vu" : un niveau sans scene n a rien a jouer.
func is_story_seen(story_id: StringName) -> bool:
	if String(story_id) == "":
		return true
	return profile().get("stories_seen", []).has(String(story_id))


## Copie, pour que l appelant ne puisse pas vider la liste du profil.
func stories_seen() -> Array:
	return profile().get("stories_seen", []).duplicate()


# --- Deck Massacre ---

func massacre_deck() -> Array:
	return profile().get("massacre_deck", [])


func set_massacre_deck(ids: Array) -> void:
	var clean: Array = []
	for id in ids:
		clean.append(String(id))
	profile()["massacre_deck"] = clean
	profile_changed.emit()


# --- Campagne ---

func unlocked_levels() -> Array:
	return profile().get("campaign", {}).get("unlocked_levels", [])


## Les niveaux reellement jouables, dans l ordre. La campagne listait tout le
## catalogue : le niveau 2 etait accessible avant d avoir termine le 1.
func playable_levels() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	var ids: Array = ContentDB.levels.keys()
	ids.sort()
	for id in ids:
		if is_level_unlocked(id):
			out.append(ContentDB.levels[id])
	return out


func is_level_unlocked(level_id: StringName) -> bool:
	return unlocked_levels().has(String(level_id))


func unlock_level(level_id: StringName) -> void:
	var camp: Dictionary = profile().get("campaign", {})
	var list: Array = camp.get("unlocked_levels", [])
	if not list.has(String(level_id)):
		list.append(String(level_id))
	camp["unlocked_levels"] = list
	profile()["campaign"] = camp
	profile_changed.emit()


func current_level() -> StringName:
	return StringName(profile().get("campaign", {}).get("current_node", "lvl_01"))


func set_current_level(level_id: StringName) -> void:
	var camp: Dictionary = profile().get("campaign", {})
	camp["current_node"] = String(level_id)
	profile()["campaign"] = camp


func level_record(level_id: StringName) -> Dictionary:
	var levels: Dictionary = profile().get("levels", {})
	if not levels.has(String(level_id)):
		levels[String(level_id)] = {
			"cleared_exploration": false,
			"cleared_massacre": false,
			"best_wave": 0,
			"objectives": {},
		}
		profile()["levels"] = levels
	return levels[String(level_id)]


func is_level_cleared(level_id: StringName) -> bool:
	var rec: Dictionary = level_record(level_id)
	return bool(rec.get("cleared_exploration", false)) or bool(rec.get("cleared_massacre", false))


## Un objectif precis est-il acquis ? (cumule sur toutes les parties du niveau)
func is_objective_done(level_id: StringName, objective_id: StringName) -> bool:
	var objs: Dictionary = level_record(level_id).get("objectives", {})
	return bool(objs.get(String(objective_id), false))


func objectives_done_count(level: LevelDef) -> int:
	if level == null:
		return 0
	var objs: Dictionary = level_record(level.id).get("objectives", {})
	var n: int = 0
	for obj in level.objectives:
		if obj != null and bool(objs.get(String(obj.id), false)):
			n += 1
	return n


## Enregistre une victoire : niveau marque, objectifs acquis, niveaux suivants
## debloques, legendaire si les 3 objectifs sont reussis (cumules sur les runs).
## Renvoie true si la legendaire du niveau vient d etre debloquee.
func record_victory(level: LevelDef, mode: GameEnums.Mode,
		objectives_done: Dictionary, waves: int) -> bool:
	if level == null:
		return false
	var rec: Dictionary = level_record(level.id)
	if mode == GameEnums.Mode.EXPLORATION:
		rec["cleared_exploration"] = true
	else:
		rec["cleared_massacre"] = true
	rec["best_wave"] = maxi(int(rec.get("best_wave", 0)), waves)

	# Un objectif reussi une fois reste acquis : on cumule d un run a l autre.
	var objs: Dictionary = rec.get("objectives", {})
	for obj_id in objectives_done:
		if bool(objectives_done[obj_id]):
			objs[String(obj_id)] = true
	rec["objectives"] = objs

	for nxt in level.next_levels:
		unlock_level(nxt)

	var all_done: bool = not level.objectives.is_empty()
	for obj in level.objectives:
		if obj == null or not bool(objs.get(String(obj.id), false)):
			all_done = false

	var newly: bool = false
	if all_done and level.legendary_reward != null:
		var unlocked: Array = profile().get("unlocked_legendaries", [])
		var lid: String = String(level.legendary_reward.id)
		if not unlocked.has(lid):
			unlocked.append(lid)
			newly = true
		profile()["unlocked_legendaries"] = unlocked
		discover_card(level.legendary_reward.id)
	profile_changed.emit()
	return newly


## --- Progression de COMPTE ---
##
## Elle ne donne QUE des titres et des avatars. Un niveau de compte qui rendrait
## le mage plus fort perimerait les taux de victoire mesures au banc et
## avantagerait qui joue beaucoup plutot que qui joue bien.

## XP total a atteindre pour passer AU niveau donne. Progression douce : les
## premiers paliers tombent vite, pour que le joueur voie la mecanique bouger.
func account_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var total: int = 0
	for n in range(2, level + 1):
		total += 250 + 150 * (n - 2)
	return total


func _account() -> Dictionary:
	var p: Dictionary = profile()
	if not p.has("account"):
		p["account"] = {"level": 1, "xp": 0, "challenges": []}
	return p["account"]


func account_level() -> int:
	return int(_account().get("level", 1))


func account_xp() -> int:
	return int(_account().get("xp", 0))


## Avancement vers le palier suivant, de 0 a 1 : c est ce que la barre affiche.
func account_progress() -> float:
	var lvl: int = account_level()
	var bas: int = account_xp_for_level(lvl)
	var haut: int = account_xp_for_level(lvl + 1)
	if haut <= bas:
		return 1.0
	return clampf(float(account_xp() - bas) / float(haut - bas), 0.0, 1.0)


## Verse de l XP et fait monter le niveau autant de fois qu il le faut.
## Rend le nombre de niveaux gagnes, pour que l interface puisse le feter.
func grant_account_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var a: Dictionary = _account()
	a["xp"] = int(a.get("xp", 0)) + amount
	var gagnes: int = 0
	while int(a.get("xp", 0)) >= account_xp_for_level(int(a.get("level", 1)) + 1):
		a["level"] = int(a.get("level", 1)) + 1
		gagnes += 1
		if gagnes > 200:
			break  # garde-fou : jamais de boucle infinie sur un profil corrompu
	if gagnes > 0:
		account_level_up.emit(int(a["level"]))
	profile_changed.emit()
	return gagnes


## Compteurs durables lus par les defis (monstres tues, niveaux finis...).
func challenge_stats() -> Dictionary:
	var a: Dictionary = _account()
	if not a.has("stats"):
		a["stats"] = {}
	return a["stats"]


func set_challenge_stats(stats: Dictionary) -> void:
	_account()["stats"] = stats
	profile_changed.emit()


func completed_challenges() -> Array:
	return (_account().get("challenges", []) as Array).duplicate()


func is_challenge_done(challenge_id: StringName) -> bool:
	return (_account().get("challenges", []) as Array).has(String(challenge_id))


## Valide un defi. Rend false s il etait deja accompli : un defi ne paie qu une
## fois, sinon ce serait une source d XP infinie.
func complete_challenge(challenge_id: StringName) -> bool:
	if is_challenge_done(challenge_id):
		return false
	var d: ChallengeDef = ContentDB.challenges.get(challenge_id)
	if d == null:
		return false
	var a: Dictionary = _account()
	var liste: Array = a.get("challenges", [])
	liste.append(String(challenge_id))
	a["challenges"] = liste
	grant_account_xp(d.xp_reward)
	challenge_completed.emit(d)
	return true


## Les recompenses debloquees a un niveau donne.
func rewards_unlocked_at(level: int) -> Array[AccountRewardDef]:
	var out: Array[AccountRewardDef] = []
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.at_level == level:
			out.append(r)
	return out


## Tout ce que le compte a deja debloque, pour l ecran de profil.
func unlocked_rewards() -> Array[AccountRewardDef]:
	var out: Array[AccountRewardDef] = []
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r != null and r.at_level <= account_level():
			out.append(r)
	return out


## Pour les tests : charge un profil brut en passant par la migration.
func load_from_dictionary(raw: Dictionary) -> void:
	_data = _migrate(raw.duplicate(true))
	profile_changed.emit()


func reset_profile() -> void:
	_data = _defaults()
	profile_changed.emit()
