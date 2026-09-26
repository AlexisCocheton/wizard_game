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
	_check_gauge_tints()
	_check_voice_keys()
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
		# RunState (equipped_passives) au lieu de s executer une fois. Leurs cles
		# sont verrouillees par test_passives.gd contre RunState.PASSIVE_KEYS.
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


## La VIE doit rester LISIBLE dans le HUD — et depuis le 26 septembre, la barre
## de vie EST la barre de vitesse : il n y en a plus qu une.
##
## Le defaut reel qui justifie ce controle : la barre portait autrefois une
## teinte posee dans la scene, la texture du pack etant deja rouge, et la
## multiplication donnait un VIOLET sombre, impossible a lire comme une barre de
## vie — elle paraissait vide a 100 / 100. Rien ne plantait, aucun test ne
## rougissait : seule une capture le montrait.
##
## Ce que le controle surveille A CHANGE DE PLACE avec la regle. La teinte de la
## barre unique est desormais calculee en CODE (hud.gd::_speed_color) pour
## passer de l or au rouge a mesure qu on approche du plancher mortel : une
## valeur figee dans la scene serait maintenant le bug, pas la protection. On
## verifie donc les deux bouts :
##   1. la barre existe toujours dans la scene, et elle est SEULE ;
##   2. le code sait encore la peindre en rouge quand il ne reste presque rien.
func _check_gauge_tints() -> void:
	var path: String = "res://scenes/hud/HUD.tscn"
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		fail("%s : illisible" % path)
		return
	if text.find("[node name=\"EnemyBar\"") < 0:
		fail("%s : EnemyBar (la barre de VITESSE, qui est la barre de VIE)"
			% path + " est introuvable")
		return
	# UNE SEULE barre verticale. L ancienne barre de PV a ete supprimee avec les
	# PV eux-memes ; la voir revenir voudrait dire qu une reserve fantome a ete
	# reintroduite quelque part, et le joueur chercherait sa vie a deux endroits.
	if text.find("[node name=\"SpellBar\"") >= 0:
		fail("%s : SpellBar (l ancienne barre de PV) est revenue — le mage n a"
			% path + " plus qu une seule reserve, sa vitesse")

	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	if hud == "":
		fail("res://scripts/ui/hud.gd : illisible")
		return
	if not hud.contains("_speed_color"):
		fail("res://scripts/ui/hud.gd : la barre unique n a plus de degrade de"
			+ " danger — rien ne dira au joueur qu il approche du plancher")
	if not hud.contains("tint_progress = _speed_color"):
		fail("res://scripts/ui/hud.gd : _speed_color n est plus appliquee a la"
			+ " teinte de la barre")


## Toute replique demandee par le code doit EXISTER dans assets/voice/.
##
## Le defaut que ceci empeche : `AudioBus.play_voice()` est SILENCIEUX quand le
## fichier manque — c est voulu, un son absent ne doit pas faire planter une
## partie. Mais cela veut dire qu un moment mal orthographie, ou invente, ne se
## remarque jamais. J ai ecrit `play_voice(&"surprised")` alors que ce moment
## n a pas ete extrait : rien n a rougi, la voix ne se serait simplement jamais
## fait entendre.
func _check_voice_keys() -> void:
	var files: Array[String] = []
	_scan_text("res://scripts", files)
	var vus: Dictionary = {}
	for path in files:
		var text: String = FileAccess.get_file_as_string(path)
		var depuis: int = 0
		while true:
			var i: int = text.find("play_voice(&\"", depuis)
			if i < 0:
				break
			var debut: int = i + 13
			var fin: int = text.find("\"", debut)
			if fin < 0:
				break
			vus[text.substr(debut, fin - debut)] = path
			depuis = fin
	for moment in vus:
		# La variante 1 suffit : l extraction les produit par familles, une
		# famille sans variante 1 n existe pas.
		var attendu: String = "res://assets/voice/voice_%s_1.wav" % moment
		if not ResourceLoader.exists(attendu):
			fail("%s : play_voice(\"%s\") mais %s est absent"
				% [vus[moment], moment, attendu])


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
