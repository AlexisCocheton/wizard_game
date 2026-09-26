extends TestCase
## LA CAMPAGNE COMPLETE — chantier N.
##
## `docs/histoire.md` decrit 21 niveaux sur 5 actes. Le jeu en avait 7, repartis
## deux par acte : une COMPRESSION, pas un plan. Ce test verrouille la structure
## d actes livree, acte par acte, pour qu un acte a moitie ecrit soit rouge au
## lieu de passer inapercu.
##
## POURQUOI un fichier a part plutot que des assertions dans test_campaign_map :
## celui-la teste l ECRAN (positions, fleches, etoiles) et se moque du nombre de
## niveaux. Celui-ci teste le CONTENU de la campagne et se moque de l ecran. Les
## melanger rendait impossible de savoir, en lisant un echec, s il fallait
## corriger l UI ou `tools/make_content.gd`.
##
## POURQUOI on n a PAS renumerote (decision du chantier N) : les identifiants
## `lvl_01..lvl_07` sont graves dans les sauvegardes des joueurs
## (`SaveData.levels_done`, `current_level`, `stories_seen`), dans les 9 scenes
## de `resources/story/` et dans une trentaine d assertions de tests. Les
## renumeroter pour coller aux LIEUX du document aurait casse les trois a la
## fois pour un gain purement cosmetique. Les niveaux neufs s ajoutent donc a la
## suite (`lvl_08`, `lvl_09`, ...) et c est l ACTE qui porte le plan du
## document, pas le numero. Voir le rapport du chantier N.

func get_suite_name() -> String:
	return "campaign_acts"


## LA CIBLE de docs/histoire.md, acte par acte. Ecrite en dur et JAMAIS lue
## depuis ContentDB : un test qui compte ce qu il trouve valide n importe quel
## contenu, y compris un acte vide.
const PLAN: Dictionary = {
	1: 4,
	2: 4,
	3: 5,
	4: 5,
	5: 3,
}

## Les actes effectivement LIVRES a ce jour. Le chantier N s est arrete a une
## frontiere propre — l acte 1 entier — plutot que de bacler les cinq.
##
## POURQUOI DEUX TABLES et pas une seule qu on ferait grossir : la cible reste
## ecrite et visible, donc `_test_le_reste_du_plan_est_connu` peut dire
## exactement ce qui manque au lieu de laisser croire que 7 niveaux suffisent.
## Le jour ou l acte 2 est livre, on ajoute `2` a cette liste : si le compte ne
## tombe pas juste, le test mord immediatement.
const ACTES_LIVRES: Array[int] = [1]


func run() -> void:
	_test_les_actes_livres_ont_leur_compte()
	_test_le_reste_du_plan_est_connu()
	_test_tout_niveau_appartient_a_un_acte_du_plan()
	_test_chaque_niveau_est_atteignable_depuis_le_premier()
	_test_chaque_niveau_a_trois_objectifs_evaluables()
	_test_chaque_niveau_a_un_fond_qui_existe()
	_test_lacte_1_suit_le_document()
	_test_la_campagne_ne_se_termine_pas_en_impasse()


func _par_acte() -> Dictionary:
	var out: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		out[lv.act] = int(out.get(lv.act, 0)) + 1
	return out


## Un acte declare LIVRE doit avoir exactement le compte du document. C est
## l assertion qui dit « cet acte est fini », et elle est la raison d etre du
## fichier : un acte a moitie ecrit doit etre rouge, pas discret.
func _test_les_actes_livres_ont_leur_compte() -> void:
	var compte: Dictionary = _par_acte()
	for acte: int in ACTES_LIVRES:
		eq(int(compte.get(acte, 0)), int(PLAN[acte]),
			"acte %d declare livre : %d niveaux, le document en demande %d"
			% [acte, int(compte.get(acte, 0)), int(PLAN[acte])])


## Le reste du plan n est pas oublie : il est COMPTE. Ce test ne echoue pas tant
## que les actes manquants sont hors de `ACTES_LIVRES` — il sert a imprimer le
## reste a faire dans la sortie du harnais, et a garantir qu un acte livre ne
## depasse jamais sa cible en douce.
func _test_le_reste_du_plan_est_connu() -> void:
	var compte: Dictionary = _par_acte()
	var reste: int = 0
	for acte: int in PLAN:
		var vise: int = int(PLAN[acte])
		var pose: int = int(compte.get(acte, 0))
		ok(pose <= vise,
			"acte %d : %d niveaux poses, jamais plus que les %d du document"
			% [acte, pose, vise])
		reste += maxi(0, vise - pose)
	ok(reste >= 0, "il reste %d niveaux a ecrire pour finir la campagne" % reste)


## Aucun niveau ne doit tomber hors du plan : un `act = 0` ou `act = 6` le
## rendrait invisible sur la carte de campagne, qui ne connait que 1 a 5.
func _test_tout_niveau_appartient_a_un_acte_du_plan() -> void:
	for lv: LevelDef in ContentDB.levels.values():
		ok(PLAN.has(lv.act),
			"%s appartient a un acte du plan (trouve %d)" % [lv.id, lv.act])


## Le graphe `next_levels` doit MENER a tous les niveaux depuis lvl_01. Un
## niveau qu aucun autre ne cite est injouable : il s affiche sur la carte,
## grise pour toujours. C est exactement le defaut qu un ajout de 14 niveaux
## fabrique si on oublie un chainon.
func _test_chaque_niveau_est_atteignable_depuis_le_premier() -> void:
	var atteints: Dictionary = {&"lvl_01": true}
	var file: Array[StringName] = [&"lvl_01"]
	var garde: int = 0
	while not file.is_empty() and garde < 200:
		garde += 1
		var id: StringName = file.pop_front()
		var lv: LevelDef = ContentDB.levels.get(id)
		if lv == null:
			continue
		for suivant: StringName in lv.next_levels:
			ok(ContentDB.levels.has(suivant),
				"%s mene a %s, qui doit exister" % [id, suivant])
			if not atteints.has(suivant):
				atteints[suivant] = true
				file.append(suivant)
	for id: StringName in ContentDB.levels:
		ok(atteints.has(id),
			"%s est atteignable depuis lvl_01 (sinon il reste grise a vie)" % id)


## Trois objectifs par niveau, et chaque cle doit etre EVALUABLE. Une cle
## inventee donne une etoile qu on ne peut jamais decrocher.
func _test_chaque_niveau_a_trois_objectifs_evaluables() -> void:
	for lv: LevelDef in ContentDB.levels.values():
		eq(lv.objectives.size(), 3, "%s a exactement 3 objectifs" % lv.id)
		for o: ObjectiveDef in lv.objectives:
			ok(o != null, "%s : aucun objectif nul" % lv.id)
			if o == null:
				continue
			ok(ObjectiveChecker.has_key(o.check_key),
				"%s : la cle %s est connue d ObjectiveChecker" % [lv.id, o.check_key])


## Un niveau sans fond retombe sur les tuiles. Sur 21 niveaux, c est le genre
## d oubli qui ne se voit qu en jouant le niveau 17.
func _test_chaque_niveau_a_un_fond_qui_existe() -> void:
	for lv: LevelDef in ContentDB.levels.values():
		ok(lv.backdrop != "", "%s nomme un fond d acte" % lv.id)
		if lv.backdrop == "":
			continue
		ok(FileAccess.file_exists("res://assets/backdrops/%s.png" % lv.backdrop),
			"%s : le fond %s existe sur le disque" % [lv.id, lv.backdrop])


## L ACTE 1, LIVRE EN ENTIER, suit le document section 3 : quatre etapes dans
## cet ordre — la lisiere, le village, la route du maire, le dirigeable — et
## l acte se ferme sur LA MORT DU GARDIEN.
##
## Le test nomme les niveaux explicitement. C est volontaire : c est la seule
## facon de verrouiller que l ordre de JEU est bien celui du document alors que
## les identifiants, eux, ne le suivent pas (decision du chantier N, en tete de
## fichier). Un test qui se contenterait de compter quatre niveaux laisserait
## passer un chainage qui saute le dirigeable.
func _test_lacte_1_suit_le_document() -> void:
	const ORDRE: Array[StringName] = [&"lvl_01", &"lvl_02", &"lvl_08", &"lvl_09"]
	for id: StringName in ORDRE:
		ok(ContentDB.levels.has(id), "%s existe" % id)
		if not ContentDB.levels.has(id):
			return
		eq((ContentDB.levels[id] as LevelDef).act, 1,
			"%s appartient a l acte 1" % id)

	# Le chainage suit l ordre du document, pas l ordre des numeros.
	for i in ORDRE.size() - 1:
		var lv: LevelDef = ContentDB.levels[ORDRE[i]]
		ok(lv.next_levels.has(ORDRE[i + 1]),
			"%s mene a %s (ordre du document)" % [ORDRE[i], ORDRE[i + 1]])

	# La fin de l acte rend la main a l acte 2, et a lui seul.
	var fin: LevelDef = ContentDB.levels[ORDRE[3]]
	eq(fin.next_levels.size(), 1, "la fin de l acte 1 n ouvre qu une suite")
	for suivant: StringName in fin.next_levels:
		var apres: LevelDef = ContentDB.levels.get(suivant)
		ok(apres != null and apres.act == 2,
			"la fin de l acte 1 ouvre l acte 2 (%s)" % suivant)

	# LE GARDIEN FERME L ACTE, mort comprise (docs/histoire.md section 3). Sans
	# cette assertion, l acte pourrait se terminer sur n importe quelle vague et
	# la scene d outro parlerait d un cadavre que le joueur n a jamais vu.
	var boss: WaveDef = fin.boss_wave()
	ok(boss != null, "le dernier niveau de l acte 1 porte une vague de boss")
	if boss == null:
		return
	ok(not boss.entries.is_empty() and boss.entries[0] != null
		and boss.entries[0].enemy != null
		and boss.entries[0].enemy.id == &"warden",
		"c est le Gardien de la foret qui ferme l acte 1")


## Aucun niveau ne doit etre un cul-de-sac INATTENDU. Tant que la campagne n est
## pas finie, il reste normalement UN seul bout de chaine : le dernier niveau
## ecrit. Deux culs-de-sac veulent dire qu une branche a ete oubliee en route —
## le defaut exact qu un ajout de niveaux au milieu d un chainage fabrique.
func _test_la_campagne_ne_se_termine_pas_en_impasse() -> void:
	var feuilles: Array[StringName] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv.next_levels.is_empty():
			feuilles.append(lv.id)
	feuilles.sort()
	eq(feuilles.size(), 1,
		"un seul niveau ferme la campagne (trouve : %s)" % str(feuilles))
