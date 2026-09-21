extends Control
## Ecran de victoire : resume, badges d objectifs, legendaire debloquee.
## Toute la logique de progression vit dans SaveData.record_victory() — testee
## a froid — cet ecran ne fait que l afficher.

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _objectives: VBoxContainer = %Objectives
@onready var _menu_btn: Button = %MenuButton

## Meme pastille que la carte de campagne : le pack n a pas d icone d etoile, et
## la piece d or est la seule forme ronde qui se lit a cette taille (DEC-012).
const STAR_ICON: int = 3


func _ready() -> void:
	theme = UiTheme.make()
	_menu_btn.pressed.connect(func() -> void: SceneRouter.goto(SceneRouter.MAIN_MENU))
	_title.text = "NIVEAU TERMINE"
	_title.add_theme_color_override(&"font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)

	var level_id: StringName = SceneRouter.payload.get("level_id", &"lvl_01")
	var level: LevelDef = ContentDB.levels.get(level_id)
	_summary.text = "Niveau joueur %d   -   %d vagues survecues" % [
		RunState.level, RunState.wave_index]
	_summary.add_theme_color_override(&"font_color", UiTheme.TEXT_DARK)
	if level == null:
		return

	var done: Dictionary = {}
	for obj in level.objectives:
		if obj != null:
			done[obj.id] = ObjectiveChecker.evaluate(obj)

	# Defis de compte : un niveau fini, et la performance s il n a rien encaisse.
	var cleared: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if SaveData.is_level_cleared(lv.id):
			cleared += 1
	ChallengeTracker.record_best(&"levels_cleared", cleared + 1)
	if not RunState.took_any_damage:
		ChallengeTracker.bump(&"flawless_clears")
	ChallengeTracker.record_best(&"cards_discovered", SaveData.discovered_count())
	ChallengeTracker.record_best(&"enemies_discovered", SaveData.discovered_enemies().size())

	var newly: bool = SaveData.record_victory(level, RunState.mode, done, RunState.wave_index)
	SaveData.save_profile()

	_remplir(level, done, newly)


## L ecran de victoire est le moment de RECOMPENSE, et il ressemblait a un
## journal d erreurs : des prefixes "[OK]" / "[   ]" en tete de ligne, aucune
## etoile alors que la carte de campagne en compte trois par niveau, aucune
## trace de l XP de compte gagnee, et un grand vide au milieu de la page.
## L ecran de DEFAITE en disait davantage au joueur que celui de victoire.
##
## Trois blocs, dans l ordre de ce qui compte : les ETOILES obtenues, ce qui
## vient de S OUVRIR, puis l avancement du COMPTE.
func _remplir(level: LevelDef, done: Dictionary, newly: bool) -> void:
	var gagnees: int = 0
	for obj in level.objectives:
		if obj != null and bool(done.get(obj.id, false)):
			gagnees += 1

	# --- Les etoiles, en gros, avant tout le reste ---
	# La liste respire : sans separation, les trois blocs se collaient en haut
	# de la page et laissaient la moitie basse vide (vu sur capture).
	_objectives.add_theme_constant_override(&"separation", 14)
	_objectives.alignment = BoxContainer.ALIGNMENT_CENTER

	var rangee := HBoxContainer.new()
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	rangee.add_theme_constant_override(&"separation", 26)
	_objectives.add_child(rangee)
	for i in level.objectives.size():
		# Grandes : c est l image que le joueur retient de sa partie.
		var s: TextureRect = UiTheme.icon(STAR_ICON, 132.0 if i < gagnees else 92.0)
		# Meme regle que sur la carte de campagne : acquise = pleine, doree et
		# GRANDE ; manquante = un creux sombre et reduit. La forme porte
		# l information autant que la couleur.
		s.modulate = Color(1.0, 0.88, 0.35) if i < gagnees 			else Color(0.30, 0.26, 0.22, 0.45)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(s)

	_objectives.add_child(UiTheme.label(
		"%d objectif%s sur %d" % [gagnees, "s" if gagnees > 1 else "",
			level.objectives.size()],
		UiTheme.FONT_BODY, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))

	# --- Le detail : ce qui est pris, ce qui reste a prendre ---
	for obj in level.objectives:
		if obj == null:
			continue
		var pris: bool = bool(done.get(obj.id, false))
		# Plus de prefixe entre crochets : la couleur et le mot disent l etat.
		# "[   ]" se lisait comme une case a cocher cassee.
		_objectives.add_child(UiTheme.label(
			"%s  -  %s" % ["Reussi" if pris else "A refaire", obj.description],
			UiTheme.FONT_SMALL,
			Color(0.16, 0.46, 0.22) if pris else Color(0.52, 0.42, 0.30)))

	# --- Ce qui vient de s ouvrir ---
	if newly and level.legendary_reward != null:
		_objectives.add_child(UiTheme.label(
			"Legendaire debloquee : %s" % level.legendary_reward.display_name,
			UiTheme.FONT_BODY, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if not level.next_levels.is_empty():
		_objectives.add_child(UiTheme.label("Niveau suivant debloque",
			UiTheme.FONT_BODY, UiTheme.TEAL, HORIZONTAL_ALIGNMENT_CENTER))

	# --- Le compte : la progression qui SURVIT a la partie ---
	# Sans ce bloc, le joueur finit un niveau sans jamais voir bouger la seule
	# chose qui le suit d une partie a l autre.
	_objectives.add_child(UiTheme.label("COMPTE  -  niveau %d"
		% SaveData.account_level(), UiTheme.FONT_BODY, UiTheme.GOLD.darkened(0.25),
		HORIZONTAL_ALIGNMENT_CENTER))
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 34)
	barre.show_percentage = false
	barre.value = SaveData.account_progress() * 100.0
	_objectives.add_child(barre)
	var bas: int = SaveData.account_xp_for_level(SaveData.account_level())
	var haut: int = SaveData.account_xp_for_level(SaveData.account_level() + 1)
	_objectives.add_child(UiTheme.label("%d / %d XP vers le niveau %d"
		% [SaveData.account_xp() - bas, haut - bas, SaveData.account_level() + 1],
		UiTheme.FONT_SMALL, UiTheme.TEXT_DARK, HORIZONTAL_ALIGNMENT_CENTER))
