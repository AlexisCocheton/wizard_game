extends TestCase
## Visual novel : les scenes de dialogue entre les niveaux (docs/histoire.md).
##
## Ce qui est teste ici est ce qui casse SILENCIEUSEMENT :
##   - une scene referencee par un niveau mais absente du disque,
##   - une scene qui se rejoue a chaque fois qu on refait un niveau,
##   - une scene qui se jouerait pendant le smoke ou le banc d equilibrage, qui
##     appellent start_level() en boucle sans personne pour appuyer.
## La mise en page n est pas testee : c est la capture du smoke qui la montre.

func get_suite_name() -> String:
	return "story"


func run() -> void:
	SaveData.reset_profile()
	_test_les_scenes_citees_existent()
	_test_chaque_replique_est_bien_formee()
	_test_la_scene_se_construit_et_avance()
	_test_une_scene_vue_ne_se_rejoue_pas()
	_test_le_prologue_precede_le_premier_niveau()
	_test_rien_ne_se_joue_en_headless()
	_test_le_massacre_na_pas_dhistoire()
	_test_chaque_personnage_a_un_visage()
	SaveData.reset_profile()


## Un `intro_story` qui ne pointe sur rien est du contenu mort : le joueur ne
## verra jamais la scene et personne ne s en apercevra.
func _test_les_scenes_citees_existent() -> void:
	var cites: int = 0
	for id: StringName in ContentDB.levels:
		var lvl: LevelDef = ContentDB.levels[id]
		if lvl == null:
			continue
		for story_id: StringName in [lvl.intro_story, lvl.outro_story]:
			if String(story_id) == "":
				continue
			cites += 1
			ok(DialogueDef.load_by_id(story_id) != null,
				"%s : la scene %s existe sur le disque" % [id, story_id])
	ok(cites >= 2, "au moins un niveau est encadre par des scenes (%d trouvees)" % cites)
	# Le prologue n appartient a aucun niveau : il se verifie a part.
	ok(DialogueDef.load_by_id(SceneRouter.PROLOGUE_STORY) != null,
		"le prologue existe")


## Une replique mal formee ne fait pas planter la scene : elle s affiche vide.
## C est donc ICI qu on la voit, pas en jouant.
func _test_chaque_replique_est_bien_formee() -> void:
	var dir: DirAccess = DirAccess.open(DialogueDef.DIR)
	ok(dir != null, "le dossier %s existe" % DialogueDef.DIR)
	if dir == null:
		return
	var scenes: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def: DialogueDef = load(DialogueDef.DIR + file) as DialogueDef
		if def == null:
			ok(false, "%s ne se charge pas en DialogueDef" % file)
			continue
		scenes += 1
		ok(def.line_count() > 0, "%s a au moins une replique" % file)
		ok(def.scene_background != "", "%s nomme un fond" % file)
		ok(ResourceLoader.exists("res://assets/backdrops/%s.png" % def.scene_background),
			"%s : le fond %s existe" % [file, def.scene_background])
		for i: int in def.line_count():
			var line: Dictionary = def.line(i)
			ok(String(line.get("text", "")).strip_edges() != "",
				"%s ligne %d : du texte" % [file, i])
			# Les accents ne se dessinent pas dans planes_valmore.ttf : ils
			# sortent en carres. Mieux vaut le voir ici qu a l ecran.
			ok(not _a_des_accents(String(line.get("text", ""))),
				"%s ligne %d : sans accents" % [file, i])
			ok(["left", "right"].has(String(line.get("side", "left"))),
				"%s ligne %d : cote valide" % [file, i])
	ok(scenes >= 5, "prologue + les 4 scenes de l acte 1 au minimum (%d)" % scenes)


func _a_des_accents(s: String) -> bool:
	for c: String in s:
		if c.unicode_at(0) > 127:
			return true
	return false


## La scene se construit hors ecran et avance replique par replique jusqu au bout.
func _test_la_scene_se_construit_et_avance() -> void:
	var def: DialogueDef = DialogueDef.load_by_id(SceneRouter.PROLOGUE_STORY)
	if def == null:
		return
	var packed: PackedScene = load(SceneRouter.STORY)
	ok(packed != null and packed.can_instantiate(), "StoryScene.tscn s instancie")
	if packed == null:
		return
	# Le routeur ne doit RIEN reprendre a la fin : on coupe la suite en vidant la
	# file, sinon le test ferait changer de scene le lanceur de tests lui-meme.
	SceneRouter.payload = {"story_id": SceneRouter.PROLOGUE_STORY, "test_mode": true}
	var screen: Control = packed.instantiate()
	attach(screen)
	eq(screen.call("line_index"), 0, "on demarre sur la premiere replique")
	eq(screen.call("total_lines"), def.line_count(), "toutes les repliques sont chargees")
	ok(not screen.call("is_finished"), "une scene d une replique au moins n est pas finie")

	var garde: int = 0
	while not screen.call("is_finished") and garde < 200:
		screen.call("advance")
		garde += 1
	ok(screen.call("is_finished"), "la scene finit par se terminer")
	eq(garde, def.line_count(), "une avance par replique, ni plus ni moins")
	detach(screen)


## Refaire un niveau pour ses objectifs ne doit pas reimposer le dialogue.
func _test_une_scene_vue_ne_se_rejoue_pas() -> void:
	SaveData.reset_profile()
	not_ok(SaveData.is_story_seen(&"lvl_01_intro"), "profil neuf : rien n est vu")
	SaveData.mark_story_seen(&"lvl_01_intro")
	ok(SaveData.is_story_seen(&"lvl_01_intro"), "la scene vue est retenue")
	SaveData.mark_story_seen(&"lvl_01_intro")
	eq(SaveData.stories_seen().size(), 1, "pas de doublon dans la liste")
	# Un id vide compte comme vu : un niveau sans scene n a rien a jouer.
	ok(SaveData.is_story_seen(&""), "un id vide ne bloque personne")
	SaveData.reset_profile()


## Le prologue passe AVANT l intro du premier niveau, et une seule fois.
func _test_le_prologue_precede_le_premier_niveau() -> void:
	SaveData.reset_profile()
	var avant: bool = SceneRouter.stories_enabled
	SceneRouter.stories_enabled = true

	var plan: Dictionary = SceneRouter.plan_level_start(&"lvl_01", GameEnums.Mode.EXPLORATION)
	var suite: Array = plan.get("stories", [])
	ok(suite.size() >= 2, "prologue + intro du niveau 1 (%d scenes)" % suite.size())
	if suite.size() >= 2:
		eq(suite[0], SceneRouter.PROLOGUE_STORY, "le prologue passe en premier")
		eq(suite[1], &"lvl_01_intro", "puis l intro du niveau")
	eq(plan.get("path", ""), SceneRouter.STORY, "on part sur la scene d histoire")
	eq(plan.get("payload", {}).get("level_id", &""), &"lvl_01",
		"le briefing recoit bien le niveau, la scene ne l avale pas")

	# Une fois vues, elles disparaissent du plan et on va droit au briefing.
	for id: StringName in suite:
		SaveData.mark_story_seen(id)
	var plan2: Dictionary = SceneRouter.plan_level_start(&"lvl_01", GameEnums.Mode.EXPLORATION)
	eq(plan2.get("stories", []).size(), 0, "rien a rejouer la seconde fois")
	eq(plan2.get("path", ""), SceneRouter.LOADING, "on va droit au briefing")

	# L outro suit la meme regle, cote victoire.
	var lvl: LevelDef = ContentDB.levels.get(&"lvl_01")
	if lvl != null and lvl.outro_story != &"":
		eq(SceneRouter.story_outro_for(&"lvl_01", GameEnums.Mode.EXPLORATION),
			lvl.outro_story, "la victoire du niveau 1 a une outro")
		SaveData.mark_story_seen(lvl.outro_story)
		eq(SceneRouter.story_outro_for(&"lvl_01", GameEnums.Mode.EXPLORATION), &"",
			"l outro vue ne se rejoue pas")

	SceneRouter.stories_enabled = avant
	SaveData.reset_profile()


## LA regle critique : le smoke et le banc appellent start_level() en boucle.
## Une scene de dialogue qui s y intercalerait attendrait un doigt qui n existe
## pas, et les deux se bloqueraient.
func _test_rien_ne_se_joue_en_headless() -> void:
	not_ok(SceneRouter.stories_enabled,
		"en headless, les scenes d histoire sont coupees")
	SaveData.reset_profile()
	var plan: Dictionary = SceneRouter.plan_level_start(&"lvl_01", GameEnums.Mode.EXPLORATION)
	eq(plan.get("stories", []).size(), 0, "aucune scene planifiee en headless")
	eq(plan.get("path", ""), SceneRouter.LOADING, "la route va droit au briefing")
	eq(SceneRouter.story_outro_for(&"lvl_01", GameEnums.Mode.EXPLORATION), &"",
		"aucune outro en headless")


## Le Massacre est, diegetiquement, ce qui vient APRES la derniere scene.
func _test_le_massacre_na_pas_dhistoire() -> void:
	SaveData.reset_profile()
	var avant: bool = SceneRouter.stories_enabled
	SceneRouter.stories_enabled = true
	eq(SceneRouter.stories_before_level(&"lvl_01", GameEnums.Mode.MASSACRE).size(), 0,
		"le Massacre ne joue aucune intro")
	eq(SceneRouter.story_outro_for(&"lvl_01", GameEnums.Mode.MASSACRE), &"",
		"le Massacre ne joue aucune outro")
	SceneRouter.stories_enabled = avant
	SaveData.reset_profile()


## Chaque personnage qui parle doit avoir un VISAGE, et ce visage doit venir de
## la grille de gros plans, pas du corps entier.
##
## Le defaut que ce test empeche de revenir : les scenes affichaient le CORPS
## ENTIER du pack, ou le visage fait 40 px tout en haut d une silhouette a
## pattes d araignee. Le personnage etait illisible, et on parlait du "mage
## demon cornu" comme d une fatalite alors que le pack fournissait les 32 gros
## plans depuis le debut — extraits, jamais branches.
func _test_chaque_personnage_a_un_visage() -> void:
	var scene: PackedScene = load("res://scenes/story/StoryScene.tscn")
	ok(scene != null, "la scene d histoire se charge")
	if scene == null:
		return
	var vue: Node = scene.instantiate()
	attach(vue)
	# On lit les constantes SUR L INSTANCE : le script n a pas de `class_name`,
	# et en ajouter un pour le confort du test ferait porter au code de
	# production une contrainte que seul le test demande.
	var sc: Script = vue.get_script()
	var head_px: int = int(sc.get_script_constant_map()["HEAD_PX"])
	var head_cols: int = int(sc.get_script_constant_map()["HEAD_COLS"])
	var head_faces: Dictionary = sc.get_script_constant_map()["HEAD_FACES"]
	var faces: Dictionary = sc.get_script_constant_map()["FACES"]

	# 1. Toute cle citee par une replique a un visage en gros plan.
	# Les dialogues vivent dans un DOSSIER, pas dans ContentDB : on les parcourt
	# comme le fait _test_chaque_replique_est_bien_formee().
	var citees: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DialogueDef.DIR)
	if dir != null:
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			var d: DialogueDef = load(DialogueDef.DIR + file) as DialogueDef
			if d == null:
				continue
			for i in d.line_count():
				var k: StringName = StringName(d.line(i).get("portrait", ""))
				if k != &"":
					citees[k] = true
	ok(not citees.is_empty(), "des repliques citent des portraits (%d cles)"
		% citees.size())
	for k in citees:
		var tex: Texture2D = vue.call(&"_portrait_texture", k)
		ok(tex != null, "%s a un portrait" % k)
		# Un AtlasTexture prouve que ca vient de la GRILLE de visages. Un
		# ImageTexture voudrait dire qu on est retombe sur le corps entier.
		ok(tex is AtlasTexture,
			"%s est un gros plan, pas un corps entier" % k)
		if tex is AtlasTexture:
			var r: Rect2 = (tex as AtlasTexture).region
			eq(int(r.size.x), head_px, "%s : largeur d une case" % k)
			eq(int(r.size.y), head_px, "%s : hauteur d une case" % k)

	# 2. Les deux tables decrivent les MEMES personnages. Si l une gagne une cle
	#    que l autre n a pas, le repli renverrait quelqu un d autre a l ecran.
	for k in head_faces:
		ok(faces.has(k),
			"%s a aussi un corps entier en repli" % k)

	# 3. Les expressions existent dans la grille (4 colonnes, 8 lignes).
	for k in head_faces:
		var rc: Array = head_faces[k]
		var ligne: int = int(rc[0])
		var colonne: int = int(rc[1])
		ok(ligne >= 1 and ligne <= 8, "%s : personnage %d dans la grille" % [k, ligne])
		ok(colonne >= 1 and colonne <= head_cols,
			"%s : expression %d dans la grille" % [k, colonne])

	detach(vue)
