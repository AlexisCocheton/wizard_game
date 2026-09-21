extends StageRunner
## ETAGE AUDIT — contenu mort et incoherences de donnees.
## Categories DURES = build rouge. Categories DOUCES = avertissement seulement,
## pour ne pas bloquer les jalons ou le contenu est encore incomplet.

var _soft: Array[String] = []


func stage_name() -> String:
	return "AUDIT"


func run_stage() -> void:
	_check_duplicates()
	_check_effect_keys()
	_check_card_fx()
	_check_unused_handlers()
	_check_enemies_spawned()
	_check_levels()
	_check_objective_keys()
	_check_assets()
	_check_raw_sheets()
	for w in _soft:
		print("  [AVERTISSEMENT] %s" % w)
	print("[AUDIT] %d avertissement(s)" % _soft.size())


func _check_duplicates() -> void:
	for dup in ContentDB.duplicate_ids:
		fail("id duplique : %s" % dup)


## Chaque carte a SA feuille d effet et SON son, et deux cartes ne partagent
## jamais une feuille. Retour du testeur : "beaucoup trop de sorts utilisent les
## memes animations et les memes icones". Les effets etaient choisis par ELEMENT
## (feu, givre...) : tous les sorts de feu explosaient pareil. L icone derivant
## de la feuille, l unicite de l une entraine celle de l autre.
func _check_card_fx() -> void:
	var prises: Dictionary = {}
	var sons: Array[StringName] = AudioBus.sfx_keys()
	for card: SpellCard in ContentDB.cards.values():
		if card.is_passive:
			continue  # un passif n a pas d effet visible sur le terrain
		if card.fx_key == &"":
			fail("carte %s : pas de feuille d effet propre (fx_key)" % card.id)
		elif not Fx.has_sheet(String(card.fx_key)):
			fail("carte %s : feuille '%s' inconnue de Fx" % [card.id, card.fx_key])
		elif prises.has(card.fx_key):
			fail("carte %s : feuille '%s' deja prise par %s" % [card.id, card.fx_key, prises[card.fx_key]])
		else:
			prises[card.fx_key] = card.id
		if card.sfx_key == &"":
			fail("carte %s : pas de son propre (sfx_key)" % card.id)
		elif not sons.has(card.sfx_key):
			fail("carte %s : son '%s' absent de AudioBus.sfx_keys()" % [card.id, card.sfx_key])


## Une cle d'effet sans handler = echec runtime garanti des que la carte est jouee.
func _check_effect_keys() -> void:
	for card: SpellCard in ContentDB.cards.values():
		# Les POUVOIRS PASSIFS n ont pas de handler : ils changent une regle dans
		# RunState.activate_passive() au lieu de s executer une fois.
		if card.is_passive:
			continue
		for spec in card.effects:
			if spec == null:
				fail("carte %s : effet vide" % card.id)
				continue
			if not EffectRegistry.has_key(spec.key):
				fail("carte %s : aucun handler pour '%s'" % [card.id, spec.key])


func _check_unused_handlers() -> void:
	var used: Dictionary = {}
	for card: SpellCard in ContentDB.cards.values():
		for key in card.effect_keys():
			used[key] = true
	for key in EffectRegistry.keys():
		if not used.has(key):
			_soft.append("handler jamais utilise : %s" % key)


func _check_enemies_spawned() -> void:
	var spawned: Dictionary = {}
	for wave: WaveDef in ContentDB.waves.values():
		for e in wave.enemy_defs():
			spawned[e.id] = true
	for level: LevelDef in ContentDB.levels.values():
		for e in level.enemy_pool:
			if e != null:
				spawned[e.id] = true
	# Un monstre engendre par division/explosion est place par son parent.
	for enemy: EnemyDef in ContentDB.enemies.values():
		if enemy.split_into != null:
			spawned[enemy.split_into.id] = true
	# Un monstre INVOQUE l est aussi : son parent le fait apparaitre en combat,
	# il n a donc rien a faire dans une vague. C est le cas de la boule de poison
	# du Planogo, et deja celui de la goule du Necromancien — qui ne passait
	# jusqu ici que parce qu elle figure AUSSI dans un pool de niveau. La regle
	# (« tout contenu doit etre atteignable ») est la bonne ; c est le releve
	# des chemins d apparition qui en oubliait un.
	for enemy: EnemyDef in ContentDB.enemies.values():
		if enemy.summon_def != null:
			spawned[enemy.summon_def.id] = true
	for enemy: EnemyDef in ContentDB.enemies.values():
		if not spawned.has(enemy.id):
			_soft.append("monstre jamais place dans une vague : %s" % enemy.id)


## Chaque monstre a une feuille du catalogue, chaque feuille/son/effet existe sur disque.
func _check_assets() -> void:
	for enemy: EnemyDef in ContentDB.enemies.values():
		if enemy.anim_key == &"":
			fail("monstre %s : pas d anim_key (forme dessinee interdite)" % enemy.id)
		elif not AnimCatalog.has(enemy.anim_key):
			fail("monstre %s : anim_key '%s' absente du catalogue" % [enemy.id, enemy.anim_key])
	for key in AnimCatalog.keys():
		for path in AnimCatalog.sheet_paths(StringName(key)):
			if not ResourceLoader.exists(path):
				fail("feuille manquante : %s (%s)" % [path, key])
	for name in Fx.sheet_names():
		if Fx.frames_of(name) == null:
			fail("feuille d effet illisible : %s" % name)
	for k in AudioBus.sfx_keys():
		if not ResourceLoader.exists(AudioBus.SFX_DIR + String(k) + ".wav"):
			fail("son manquant : %s" % k)
	for k in AudioBus.music_keys():
		if not ResourceLoader.exists(AudioBus.MUSIC_DIR + String(k) + ".ogg"):
			fail("musique manquante : %s" % k)


## Les planches d UI du pack sont des grilles de morceaux espaces : referencee telle
## quelle (l editeur peut re-sauver une scene avec l ancien chemin), elle s affiche en
## damier. Seules les versions recomposees <nom>9.png et wood_tile.png sont autorisees.
func _check_raw_sheets() -> void:
	var raw: Array[String] = ["wood"]
	for key in UiTheme.NINE.keys():
		raw.append(String(key).trim_suffix("9"))
	var files: Array[String] = []
	_scan_text("res://scenes", files)
	_scan_text("res://scripts", files)
	for path in files:
		var text: String = FileAccess.get_file_as_string(path)
		for name in raw:
			if text.contains("assets/ui/%s.png\"" % name) or text.contains("tex(\"%s\")" % name):
				fail("%s : planche brute '%s' referencee (utiliser %s9.png / tex_box)" % [path, name, name])


func _scan_text(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_text(full, out)
		elif entry.ends_with(".tscn") or entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()


## Un objectif dont la cle n est pas evaluable serait impossible a valider.
func _check_objective_keys() -> void:
	for obj: ObjectiveDef in ContentDB.objectives.values():
		if not ObjectiveChecker.has_key(obj.check_key):
			fail("objectif %s : aucun checker pour '%s'" % [obj.id, obj.check_key])


func _check_levels() -> void:
	for level: LevelDef in ContentDB.levels.values():
		if level.objectives.size() != 3:
			fail("niveau %s : %d objectifs (3 attendus)" % [level.id, level.objectives.size()])
		if level.legendary_reward == null:
			fail("niveau %s : pas de recompense legendaire" % level.id)
		for next_id in level.next_levels:
			if not ContentDB.levels.has(next_id):
				fail("niveau %s : next_levels pointe vers '%s' qui n'existe pas"
					% [level.id, next_id])
