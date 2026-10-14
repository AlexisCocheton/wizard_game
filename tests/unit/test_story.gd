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
	_test_le_mage_nest_plus_un_demon()
	_test_les_fonds_de_dialogue_sont_des_decors()
	_test_aucune_scene_orpheline()
	_test_chaque_niveau_de_campagne_est_encadre()
	_test_le_narrateur_ne_nomme_que_ce_qui_est_joue()
	_test_les_textes_du_niveau_sont_sans_accents()
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


## Le Massacre est, diegetiquement, ce qui vient APRES la derniere scene. Le
## LIBRE (vague 10) rejoue un niveau que la campagne a deja raconte.
func _test_le_massacre_na_pas_dhistoire() -> void:
	SaveData.reset_profile()
	var avant: bool = SceneRouter.stories_enabled
	SceneRouter.stories_enabled = true
	for m in [GameEnums.Mode.FREE, GameEnums.Mode.MASSACRE]:
		eq(SceneRouter.stories_before_level(&"lvl_01", m).size(), 0,
			"le mode %s ne joue aucune intro" % GameEnums.mode_name(m))
		eq(SceneRouter.story_outro_for(&"lvl_01", m), &"",
			"le mode %s ne joue aucune outro" % GameEnums.mode_name(m))
	eq(SceneRouter.stories_before_level(MassacreMode.LEVEL_ID, GameEnums.Mode.MASSACRE).size(), 0,
		"le niveau du Massacre n a pas d histoire")
	SceneRouter.stories_enabled = avant
	SaveData.reset_profile()


## Chaque personnage qui parle doit avoir un VISAGE, et ce visage doit venir
## d une planche de portraits recadree, pas d un corps entier.
##
## Le defaut que ce test empeche de revenir, en deux temps.
##
## 1. Les scenes affichaient le CORPS ENTIER du pack, ou le visage fait 40 px
##    tout en haut d une silhouette a pattes d araignee. On corrige en exigeant
##    un AtlasTexture : la preuve qu on a recadre sur le visage.
## 2. Le seul pack disponible ne contenait que des GUERRIERS DEMONS. Le heros du
##    jeu, un vieux mage humain, etait affiche en demon cornu a peau orange. Un
##    AtlasTexture ne suffit donc pas : il faut aussi que le portrait vienne du
##    pack de PERSONNAGES et pas de la planche de demons. C est le role de
##    `_test_le_mage_nest_plus_un_demon` ci-dessous.
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
	var cartes: Dictionary = sc.get_script_constant_map()["CAST"]

	# 1. Toute cle citee par une replique a un visage.
	# Les dialogues vivent dans un DOSSIER, pas dans ContentDB : on les parcourt
	# comme le fait _test_chaque_replique_est_bien_formee().
	var citees: Dictionary = _portraits_cites()
	ok(not citees.is_empty(), "des repliques citent des portraits (%d cles)"
		% citees.size())
	for k in citees:
		ok(cartes.has(k), "%s est dans le casting" % k)
		var tex: Texture2D = vue.call(&"_portrait_texture", k)
		ok(tex != null, "%s a un portrait" % k)
		# Un AtlasTexture prouve qu on a RECADRE sur le visage. Un ImageTexture
		# voudrait dire qu on affiche la planche ou le corps entier tel quel.
		ok(tex is AtlasTexture,
			"%s est un gros plan, pas un corps entier" % k)
		if tex is AtlasTexture:
			var r: Rect2 = (tex as AtlasTexture).region
			ok(r.size.x > 0.0 and r.size.y > 0.0,
				"%s : la decoupe n est pas vide" % k)

	# 2. Tout le casting se resout, pas seulement ce que l acte 1 cite : les
	#    actes 2 a 5 de docs/histoire.md citeront le reste, et une cle morte ne
	#    se verrait qu au moment ou la scene s afficherait devant un joueur.
	for k in cartes:
		ok(vue.call(&"_portrait_texture", k) != null,
			"%s (casting complet) se resout en portrait" % k)

	detach(vue)


## LE defaut principal, celui qui a survecu a trois vagues de travail : le mage
## etait un DEMON CORNU. Le pack de portraits ne contenait que huit guerriers
## demons, alors le heros du jeu — un vieux mage humain chauve (docs/histoire.md)
## — empruntait le visage d une creature a cornes, peau orange et yeux bleus.
##
## Ce test est la garde : les personnages HUMAINS de l histoire ne doivent PAS
## venir de la planche de demons. On le verifie sur la source du portrait, pas
## sur son allure : c est la seule chose qu une machine sache lire.
func _test_le_mage_nest_plus_un_demon() -> void:
	var scene: PackedScene = load("res://scenes/story/StoryScene.tscn")
	if scene == null:
		return
	var vue: Node = scene.instantiate()
	attach(vue)
	var sc: Script = vue.get_script()
	var cartes: Dictionary = sc.get_script_constant_map()["CAST"]

	# Les personnages que docs/histoire.md decrit comme humains ou humanoides
	# non demoniaques. Le jour ou un acte ajoute un vrai demon qui parle, il ne
	# sera pas dans cette liste et pourra garder une tete de demon.
	var humains: Array[StringName] = [
		&"mage", &"mage_grave", &"child", &"rat", &"mayor",
		&"skeleton_king", &"guardian",
	]
	for k: StringName in humains:
		ok(cartes.has(k), "%s fait partie du casting" % k)
		var src: String = String(cartes.get(k, {}).get("sheet", ""))
		not_ok(src.contains("demon_heads"),
			"%s ne vient PAS de la planche de demons (source : %s)" % [k, src])

	# Et le mage en particulier vient bien du pack de personnages.
	var mage: Texture2D = vue.call(&"_portrait_texture", &"mage")
	ok(mage is AtlasTexture, "le mage a un portrait recadre")
	if mage is AtlasTexture:
		var atlas: Texture2D = (mage as AtlasTexture).atlas
		ok(atlas != null, "le portrait du mage a une planche source")
		if atlas != null:
			not_ok(atlas.resource_path.contains("demon"),
				"la planche du mage n est pas celle des demons (%s)"
				% atlas.resource_path)
	detach(vue)


## Les scenes de dialogue ne doivent plus reutiliser les fonds de COMBAT
## assombris : le testeur a fourni un pack de decors peints pour ca.
func _test_les_fonds_de_dialogue_sont_des_decors() -> void:
	var dir: DirAccess = DirAccess.open(DialogueDef.DIR)
	if dir == null:
		return
	var vus: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var d: DialogueDef = load(DialogueDef.DIR + file) as DialogueDef
		if d == null:
			continue
		vus += 1
		# Un fond de combat s appelle `actN_*` : c est la texture que le
		# champ de bataille affiche derriere les monstres. Une scene de
		# dialogue merite son propre decor.
		not_ok(d.scene_background.begins_with("act"),
			"%s : fond de dialogue dedie, pas un fond de combat (%s)"
			% [file, d.scene_background])
	ok(vus > 0, "des scenes ont ete relues (%d)" % vus)


## UNE SCENE QU AUCUN NIVEAU NE CITE NE SE JOUE JAMAIS (vague 10, revue A4 n° 1).
## Les deux scenes de Vharn (`lvl_07`) ont vecu ainsi des semaines : generees,
## relues, sur le disque, et jamais jouees, parce que `lvl_07` ne posait pas son
## `intro_story`. `_test_les_scenes_citees_existent` ne regarde que le sens
## niveau -> scene ; celui-ci regarde l autre sens. Le prologue est la seule
## scene sans niveau : `SceneRouter` le joue avant le premier.
func _test_aucune_scene_orpheline() -> void:
	var citees: Dictionary = {String(SceneRouter.PROLOGUE_STORY): true}
	for lvl: LevelDef in ContentDB.levels.values():
		if lvl == null:
			continue
		for sid: StringName in [lvl.intro_story, lvl.outro_story]:
			if String(sid) != "":
				citees[String(sid)] = true
	var dir: DirAccess = DirAccess.open(DialogueDef.DIR)
	if dir == null:
		return
	var vues: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		vues += 1
		var id: String = file.get_basename()
		ok(citees.has(id),
			"la scene %s est citee par un niveau (sinon elle ne se joue jamais)" % id)
	ok(vues > 0, "des scenes ont ete relues (%d)" % vues)


## CHAQUE NIVEAU DE LA CAMPAGNE A SON INTRO ET SON OUTRO. La fourche de l acte 3
## (`lvl_05`, `lvl_06`) et la forge de Vharn n en avaient pas : trois niveaux
## muets au milieu d une campagne qui raconte une histoire, et aucun test pour le
## voir. Les QUETES ANNEXES ne sont pas concernees (`is_campaign_level`) : une
## annexe peut se jouer sans scene.
func _test_chaque_niveau_de_campagne_est_encadre() -> void:
	var niveaux: Array[LevelDef] = ContentDB.campaign_levels()
	ok(not niveaux.is_empty(), "la campagne a des niveaux (%d)" % niveaux.size())
	for lvl: LevelDef in niveaux:
		ok(DialogueDef.load_by_id(lvl.intro_story) != null,
			"%s a une scene d intro jouable (%s)" % [lvl.id, lvl.intro_story])
		ok(DialogueDef.load_by_id(lvl.outro_story) != null,
			"%s a une scene d outro jouable (%s)" % [lvl.id, lvl.outro_story])


## LE NARRATEUR NE NOMME QUE CE QUI EST JOUE. Une replique de narrateur decrit ce
## qui se passe a l ecran ; si elle nomme un monstre, ce monstre doit etre dans
## les vagues du niveau. Le defaut que ce test attrape : l outro de `lvl_17`
## faisait tomber « l Ecumeur du ciel », absent du niveau (revue A4, n° 9). Il
## sert surtout de GARDE entre l ecriture et les vagues : retirer d un niveau un
## monstre qu une scene fait tomber rougit ici, et dit quelle scene reprendre.
##
## Les personnages, eux, ont le droit de se souvenir (« le corniste, au
## village ») : seules les repliques SANS locuteur sont lues. Les noms sont lus
## sans leur article (« L Horloger » -> « Horloger », le narrateur ecrit
## « l Horloger ») et, pour les seigneurs, avant la virgule (« Malyk, Seigneur
## demon » -> « Malyk »). La casse compte : « les gardiens de la galerie » n est
## pas le Gardien.
func _test_le_narrateur_ne_nomme_que_ce_qui_est_joue() -> void:
	var cles: Dictionary = {}
	for def: EnemyDef in ContentDB.enemies.values():
		if def == null or def.display_name.strip_edges() == "":
			continue
		cles[_cle_de_nom(def.display_name)] = true
	var lus: int = 0
	for lvl: LevelDef in ContentDB.levels.values():
		if lvl == null:
			continue
		var joues: Array[String] = []
		for w: WaveDef in lvl.waves:
			if w == null:
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					joues.append(e.enemy.display_name)
		for sid: StringName in [lvl.intro_story, lvl.outro_story]:
			var d: DialogueDef = DialogueDef.load_by_id(sid)
			if d == null:
				continue
			for i: int in d.line_count():
				var ligne: Dictionary = d.line(i)
				if String(ligne.get("speaker", "")) != "":
					continue
				lus += 1
				var texte: String = String(ligne.get("text", ""))
				for cle: String in cles:
					if not _mot_entier(texte, cle):
						continue
					var trouve: bool = false
					for nom: String in joues:
						if nom.contains(cle):
							trouve = true
							break
					ok(trouve, "%s : le narrateur nomme « %s », absent des vagues du niveau"
						% [sid, cle])
	ok(lus > 0, "des repliques de narrateur ont ete lues (%d)" % lus)


## Le nom d un monstre tel qu un narrateur l ecrit : sans article, et pour un
## seigneur, sans son titre.
func _cle_de_nom(nom: String) -> String:
	var cle: String = nom.strip_edges()
	if cle.contains(","):
		cle = cle.get_slice(",", 0).strip_edges()
	for article: String in ["L ", "Le ", "La ", "Les "]:
		if cle.begins_with(article) and cle.length() > article.length():
			return cle.substr(article.length())
	return cle


## `cle` apparait-elle dans `texte` comme un mot entier ? Une lettre collee
## avant ou apres en fait un autre mot (« Ombre » dans « Ombres » compte, pas
## dans « Sombre »).
func _mot_entier(texte: String, cle: String) -> bool:
	var de: int = texte.find(cle)
	while de >= 0:
		var avant: bool = de == 0 or not _est_lettre(texte[de - 1])
		var fin: int = de + cle.length()
		var apres: bool = fin >= texte.length() or not _est_lettre(texte[fin]) \
			or (texte[fin] == "s" and (fin + 1 >= texte.length() or not _est_lettre(texte[fin + 1])))
		if avant and apres:
			return true
		de = texte.find(cle, de + 1)
	return false


func _est_lettre(c: String) -> bool:
	var u: int = c.unicode_at(0)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122)


## Le briefing affiche `intro_text` depuis la vague 10 (loading_screen.gd), la
## carte de campagne le nom et le sous-titre. Meme police que les scenes, meme
## regle : un accent ou un tiret long sort en carre. Trois intro_text portaient
## un tiret long (« — ») au 14/10.
func _test_les_textes_du_niveau_sont_sans_accents() -> void:
	for lvl: LevelDef in ContentDB.levels.values():
		if lvl == null:
			continue
		for champ: String in ["display_name", "subtitle", "intro_text"]:
			ok(not _a_des_accents(String(lvl.get(champ))),
				"%s.%s : sans accents ni tiret long" % [lvl.id, champ])


## Les cles de portrait citees par toutes les scenes du disque.
func _portraits_cites() -> Dictionary:
	var citees: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DialogueDef.DIR)
	if dir == null:
		return citees
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var d: DialogueDef = load(DialogueDef.DIR + file) as DialogueDef
		if d == null:
			continue
		for i: int in d.line_count():
			var k: StringName = StringName(d.line(i).get("portrait", ""))
			if k != &"":
				citees[k] = true
	return citees
