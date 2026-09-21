extends Control
## Ecran de briefing, entre le menu et la partie.
##
## Le joueur choisissait un niveau et se retrouvait immediatement au combat, sans
## savoir ce qui l attendait : ni le nombre de vagues, ni le boss, ni les monstres.
## Cet ecran montre ce qu il va affronter et avec quoi, pour qu il puisse penser
## son deck avant et non apres.
##
## Il n affiche QUE des donnees reelles lues dans les .tres du niveau. Rien n est
## invente ici : si une information manque, la ligne disparait.

const HOLD_SECONDS: float = 0.35   ## laisse le temps de lire avant que le bouton reponde

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _waves: VBoxContainer = %Waves
@onready var _deck: VBoxContainer = %Deck
@onready var _start_btn: Button = %StartButton
@onready var _back_btn: Button = %BackButton

var _level: LevelDef = null
var _mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION
var _armed: bool = false


func _ready() -> void:
	theme = UiTheme.make()
	UiTheme.style_primary(_start_btn)
	_start_btn.pressed.connect(_on_start)
	_back_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))

	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	_mode = SceneRouter.payload.get("mode", GameEnums.Mode.EXPLORATION)
	_level = ContentDB.levels.get(level_id)
	_build()

	# Le bouton ne repond pas instantanement : sans ce delai, un double appui sur
	# "JOUER" dans le menu traversait cet ecran sans qu on le voie.
	await get_tree().create_timer(HOLD_SECONDS).timeout
	_armed = true


func _build() -> void:
	if _level == null:
		_title.text = "NIVEAU INTROUVABLE"
		return
	_title.text = _level.display_name.to_upper()
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)

	if _mode == GameEnums.Mode.MASSACRE:
		_subtitle.text = "Massacre  -  vagues sans fin, ton deck"
	else:
		_subtitle.text = "Exploration  -  %d vagues, deck du niveau" % _level.waves.size()
	_subtitle.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)

	_build_threats()
	_build_objectives()
	_build_deck()


## Ce qui arrive : les monstres du niveau, du plus faible au plus fort, et le boss.
func _build_threats() -> void:
	_waves.add_child(UiTheme.label("CE QUI T ATTEND", UiTheme.FONT_BODY, UiTheme.GOLD))

	var boss: EnemyDef = null
	var miniboss: EnemyDef = null
	var ordinaires: Array[EnemyDef] = []
	for def in _threat_pool():
		if def == null:
			continue
		if def.kind == GameEnums.EnemyKind.BOSS:
			boss = def
		elif def.kind == GameEnums.EnemyKind.MINIBOSS:
			miniboss = def
		elif not ordinaires.has(def):
			ordinaires.append(def)
	ordinaires.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return a.power < b.power)

	if not ordinaires.is_empty():
		_waves.add_child(_portraits(ordinaires))
	if miniboss != null:
		_waves.add_child(_boss_line("Mini-boss", miniboss, UiTheme.TEAL))
	if boss != null:
		_waves.add_child(_boss_line("Boss", boss, UiTheme.RED))


## Les monstres reellement envoyes par ce niveau, sans doublon.
func _threat_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	if _level == null:
		return out
	var source: Array = _level.enemy_pool if _mode == GameEnums.Mode.MASSACRE else []
	if source.is_empty():
		for wave: WaveDef in _level.waves:
			for entry: WaveEntry in wave.entries:
				if entry != null and entry.enemy != null and not out.has(entry.enemy):
					out.append(entry.enemy)
		return out
	for def in source:
		if def != null and not out.has(def):
			out.append(def)
	return out


## Rangee de vignettes : la silhouette de chaque monstre, a sa taille relative.
func _portraits(defs: Array[EnemyDef]) -> Control:
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override(&"h_separation", 14)
	wrap.add_theme_constant_override(&"v_separation", 10)
	for def in defs:
		var cell := VBoxContainer.new()
		# 150 px et non 112 : a FONT_SMALL, "Sauterelle" et "Corniste" ne
		# tenaient plus et AUTOWRAP_WORD_SMART coupait AU MILIEU du mot
		# ("Sautere / lle"). Un nom coupe se lit plus mal qu un nom serre.
		cell.custom_minimum_size = Vector2(150.0, 0.0)
		cell.add_theme_constant_override(&"separation", 2)
		var tex: TextureRect = _thumb(def, 78.0)
		if tex != null:
			cell.add_child(tex)
		var nom := UiTheme.label(def.display_name, UiTheme.FONT_SMALL, UiTheme.TEXT_DARK,
			HORIZONTAL_ALIGNMENT_CENTER)
		# WORD, pas WORD_SMART : "smart" s autorise a casser un mot trop long
		# pour la ligne, ce qui est exactement le defaut constate. WORD prefere
		# deborder, et le nom reste lisible.
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD
		cell.add_child(nom)
		wrap.add_child(cell)
	return wrap


func _boss_line(etiquette: String, def: EnemyDef, teinte: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var tex: TextureRect = _thumb(def, 104.0)
	if tex != null:
		row.add_child(tex)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiTheme.label(etiquette, UiTheme.FONT_SMALL, teinte))
	col.add_child(UiTheme.label(def.display_name, UiTheme.FONT_BODY, UiTheme.TEXT_DARK))
	row.add_child(col)
	return row


## Premiere image de la feuille de marche du monstre. Null si l asset manque :
## l ecran doit rester lisible sans lui.
func _thumb(def: EnemyDef, taille: float) -> TextureRect:
	if def == null or def.anim_key == &"" or not AnimCatalog.has(def.anim_key):
		return null
	var frames: SpriteFrames = AnimCatalog.frames(def.anim_key)
	var tex: Texture2D = null
	if frames != null and frames.has_animation(&"walk") and frames.get_frame_count(&"walk") > 0:
		tex = frames.get_frame_texture(&"walk", 0)
	elif AnimCatalog.is_static(def.anim_key):
		tex = AnimCatalog.static_texture(def.anim_key)
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(taille, taille)
	rect.modulate = AnimCatalog.modulate_for(def.id)
	return rect


## Pourquoi : les trois objectifs du niveau et la legendaire qu ils debloquent.
## Le joueur doit les connaitre AVANT de jouer, sinon il ne peut pas les viser.
func _build_objectives() -> void:
	if _level == null or _mode == GameEnums.Mode.MASSACRE or _level.objectives.is_empty():
		return
	_waves.add_child(UiTheme.label("OBJECTIFS", UiTheme.FONT_BODY, UiTheme.GOLD))
	for obj: ObjectiveDef in _level.objectives:
		if obj == null:
			continue
		var fait: bool = SaveData.is_objective_done(_level.id, obj.id)
		# Plus de prefixe "[   ]" : il se lisait comme une case a cocher cassee.
		# Le MOT dit l etat, la couleur le confirme — et un joueur daltonien lit
		# quand meme "Acquis" ou "A faire".
		_waves.add_child(UiTheme.label(
			"%s  -  %s" % ["Acquis" if fait else "A faire", obj.description],
			UiTheme.FONT_BODY,
			Color(0.16, 0.46, 0.22) if fait else UiTheme.TEXT_DARK))
	if _level.legendary_reward != null:
		_waves.add_child(UiTheme.label("Recompense : %s" % _level.legendary_reward.display_name,
			UiTheme.FONT_BODY, UiTheme.GOLD))


## Aucune taille de police LITTERALE dans cet ecran : elles echappent au theme.
## Le briefing en portait trois (17, 19, 20) la ou la plus petite taille du theme
## vaut 30 — le texte y faisait donc la moitie de ce qui est lisible, ce qui est
## exactement la plainte du testeur sur les polices. Passer par FONT_SMALL et
## FONT_BODY garantit qu un reglage de taille touche AUSSI cet ecran.
## Avec quoi : la composition du deck, par nom et nombre de copies.
func _build_deck() -> void:
	var cartes: Array = _deck_list()
	if cartes.is_empty():
		return
	_deck.add_child(UiTheme.label("TON DECK  (%d cartes)" % cartes.size(),
		UiTheme.FONT_BODY, UiTheme.GOLD))
	var copies: Dictionary = {}
	var ordre: Array[SpellCard] = []
	for c: SpellCard in cartes:
		if c == null:
			continue
		if not copies.has(c.id):
			copies[c.id] = 0
			ordre.append(c)
		copies[c.id] = int(copies[c.id]) + 1
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override(&"h_separation", 10)
	wrap.add_theme_constant_override(&"v_separation", 8)
	for c in ordre:
		var tag := UiTheme.label("%s x%d" % [c.display_name, copies[c.id]],
			UiTheme.FONT_SMALL, UiTheme.rarity_ink(c.rarity))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		wrap.add_child(tag)
	_deck.add_child(wrap)


## Rend des SpellCard. Attention : SaveData.massacre_deck() stocke des IDENTIFIANTS
## texte, pas des cartes — les melanger faisait planter la boucle typee.
func _deck_list() -> Array:
	if _mode != GameEnums.Mode.MASSACRE:
		return _level.exploration_deck if _level != null else []
	var out: Array = []
	for id in SaveData.massacre_deck():
		var card: SpellCard = ContentDB.cards.get(StringName(id))
		if card != null:
			out.append(card)
	return out


func _on_start() -> void:
	if not _armed or _level == null:
		return
	SceneRouter.goto(SceneRouter.GAME, {"level_id": _level.id, "mode": _mode})


## Pour les tests : l ecran est-il pret a lancer la partie ?
func is_armed() -> bool:
	return _armed


func arm_now() -> void:
	_armed = true
