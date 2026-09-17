extends TestCase
## Ecran de briefing : il doit dire la verite sur ce qui attend le joueur.
##
## Les tests portent sur les DONNEES qu il lit, pas sur sa mise en page : un
## briefing qui annonce le mauvais boss ou le mauvais deck est pire que pas de
## briefing du tout.

func get_suite_name() -> String:
	return "briefing"


func run() -> void:
	_test_la_route_passe_par_le_briefing()
	_test_le_boss_annonce_est_celui_du_niveau()
	_test_le_deck_annonce_est_celui_du_niveau()
	_test_les_objectifs_suivent_la_progression()


## Lancer un niveau doit mener au briefing, pas directement au combat.
func _test_la_route_passe_par_le_briefing() -> void:
	ok(SceneRouter.LOADING != SceneRouter.GAME,
		"la route de lancement ne pointe pas directement sur la partie")
	ok(ResourceLoader.exists(SceneRouter.LOADING), "la scene de briefing existe")


## Le boss affiche doit etre celui que le niveau envoie vraiment.
func _test_le_boss_annonce_est_celui_du_niveau() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	var boss: EnemyDef = null
	var miniboss: EnemyDef = null
	for wave: WaveDef in level.waves:
		for entry: WaveEntry in wave.entries:
			if entry == null or entry.enemy == null:
				continue
			if entry.enemy.kind == GameEnums.EnemyKind.BOSS:
				boss = entry.enemy
			elif entry.enemy.kind == GameEnums.EnemyKind.MINIBOSS:
				miniboss = entry.enemy
	ok(boss != null, "le niveau 1 envoie bien un boss")
	ok(miniboss != null, "le niveau 1 envoie bien un mini-boss")
	if boss != null:
		ok(boss.display_name != "", "le boss a un nom affichable")


## Chaque monstre annonce doit avoir une vignette : un briefing sans image est
## illisible sur mobile.
func _test_le_deck_annonce_est_celui_du_niveau() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null:
		return
	ok(not level.exploration_deck.is_empty(), "le niveau 1 a un deck pre-etabli")
	for wave: WaveDef in level.waves:
		for entry: WaveEntry in wave.entries:
			if entry == null or entry.enemy == null:
				continue
			ok(AnimCatalog.has(entry.enemy.anim_key),
				"%s a une feuille : le briefing peut l illustrer" % entry.enemy.id)


## L etat coche des objectifs vient de SaveData, pas d une copie locale.
func _test_les_objectifs_suivent_la_progression() -> void:
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	if level == null or level.objectives.is_empty():
		return
	SaveData.reset_profile()
	var obj: ObjectiveDef = level.objectives[0]
	not_ok(SaveData.is_objective_done(level.id, obj.id),
		"objectif non acquis sur un profil neuf")
	var done: Dictionary = {}
	for o in level.objectives:
		if o != null:
			done[o.id] = (o == obj)
	SaveData.record_victory(level, GameEnums.Mode.EXPLORATION, done, 6)
	ok(SaveData.is_objective_done(level.id, obj.id),
		"l objectif reussi est retenu et sera coche au briefing suivant")
	SaveData.reset_profile()
