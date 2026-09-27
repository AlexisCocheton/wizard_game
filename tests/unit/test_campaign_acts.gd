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
## CHANTIER N3 — les actes 4 et 5 sont livres : la FIN DU JEU. L acte 4 est le
## seul acte NON LINEAIRE de la campagne (quatre grands demons ouverts d emblee),
## l acte 5 ferme la campagne sur `lvl_16` et debloque le Massacre.
## CHANTIER N2 — les actes 2 et 3 sont livres. L acte 2 est la MONTEE (les
## courants, le port de Haute-Nacelle, puis le cimetiere de bordure) et
## l acte 3 est une POURSUITE en cinq etapes dont une fourche conservee.
const ACTES_LIVRES: Array[int] = [1, 2, 3, 4, 5]


func run() -> void:
	_test_les_actes_livres_ont_leur_compte()
	_test_le_reste_du_plan_est_connu()
	_test_tout_niveau_appartient_a_un_acte_du_plan()
	_test_chaque_niveau_est_atteignable_depuis_le_premier()
	_test_chaque_niveau_a_trois_objectifs_evaluables()
	_test_chaque_niveau_a_un_fond_qui_existe()
	_test_lacte_1_suit_le_document()
	_test_la_campagne_ne_se_termine_pas_en_impasse()
	# --- chantier N2 : les actes 2 et 3, la montee et la poursuite ---
	_test_lacte_2_suit_le_document()
	_test_lacte_2_monte_avant_de_descendre()
	_test_lacte_3_est_une_poursuite_avec_sa_fourche()
	_test_lacte_3_se_ferme_sur_le_sceau_de_tombol()
	_test_les_silhouettes_orphelines_ont_un_niveau()
	# --- chantier N3 : les actes 4 et 5, la fin du jeu ---
	_test_lacte_4_est_ouvert_en_eventail()
	_test_lacte_4_se_ferme_sur_le_pentacle()
	_test_lacte_5_suit_le_document()
	_test_lacte_5_renvoie_les_anciens_boss_en_vague_normale()
	_test_la_campagne_se_termine_sur_lacte_5()


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


## =====================================================================
## CHANTIER N3 — LES ACTES 4 ET 5, LA FIN DU JEU
## =====================================================================

## L ACTE 4 EST LE SEUL ACTE NON LINEAIRE DE LA CAMPAGNE.
##
## `docs/histoire.md` section 6, mot pour mot : « les 4 premiers niveaux sont
## ouverts d emblee, un par grand demon. Le joueur choisit son ordre et son
## style. Le cinquieme ne s ouvre qu apres les quatre. »
##
## POURQUOI CE TEST EXISTE ALORS QUE `_test_chaque_niveau_est_atteignable`
## PASSERAIT DEJA : l atteignabilite est satisfaite par une CHAINE. Un acte 4
## ecrit en file indienne (Vharn -> Sesh -> Kaltek -> Ymoa) serait vert partout
## ailleurs dans ce fichier et trahirait pourtant la seule demande structurelle
## du document. Ce test verifie la FORME du graphe, pas seulement sa connexite :
## un unique niveau ouvre les quatre d un coup, et aucun des quatre n ouvre l un
## des trois autres.
func _test_lacte_4_est_ouvert_en_eventail() -> void:
	var acte4: Array[StringName] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act == 4:
			acte4.append(lv.id)
	acte4.sort()
	eq(acte4.size(), 5, "l acte 4 compte cinq niveaux (trouve %s)" % str(acte4))
	if acte4.size() != 5:
		return

	# LES QUATRE GRANDS DEMONS : les niveaux de l acte 4 qui NE ferment PAS
	# l acte, donc ceux qui n ouvrent pas l acte 5. On les deduit de la structure
	# plutot que de les nommer, pour que le test survive a un renommage.
	var demons: Array[StringName] = []
	var pentacle: StringName = &""
	for id: StringName in acte4:
		var lv: LevelDef = ContentDB.levels[id]
		var ferme: bool = false
		for suivant: StringName in lv.next_levels:
			var apres: LevelDef = ContentDB.levels.get(suivant)
			if apres != null and apres.act == 5:
				ferme = true
		if ferme:
			pentacle = id
		else:
			demons.append(id)
	eq(demons.size(), 4,
		"quatre grands demons dans l acte 4, plus le pentacle (trouve %s + %s)"
		% [str(demons), pentacle])
	if demons.size() != 4:
		return

	# LES PORTAILS : les niveaux d un acte ANTERIEUR qui ouvrent l acte 4.
	#
	# POURQUOI ON EN TOLERE PLUSIEURS. L acte 3 peut se terminer sur plusieurs
	# branches (c est deja le cas : `lvl_05` et `lvl_06` menent tous deux a
	# l acte 4), et le decoupage de l acte 3 n appartient pas a ce chantier. La
	# regle qui compte n est pas « un seul portail » mais « tout chemin vers
	# l acte 4 y entre par les QUATRE demons a la fois » : un portail qui n en
	# ouvrirait que deux imposerait un ordre au joueur qui passe par lui.
	var portails: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act >= 4:
			continue
		var ouvre: Array[StringName] = []
		for suivant: StringName in lv.next_levels:
			var apres: LevelDef = ContentDB.levels.get(suivant)
			if apres != null and apres.act == 4:
				ouvre.append(suivant)
		if ouvre.is_empty():
			continue
		portails += 1
		eq(ouvre.size(), 4,
			("%s entre dans l acte 4 : il doit en ouvrir les QUATRE grands" % lv.id)
			+ " demons d un coup (docs/histoire.md section 6), pas %d"
			% ouvre.size())
		not_ok(ouvre.has(pentacle),
			"%s ne doit pas ouvrir le pentacle %s : il se merite apres les quatre"
			% [lv.id, pentacle])
	ok(portails >= 1, "au moins un niveau ouvre l acte 4 (%d)" % portails)

	# Les quatre demons sont AUTONOMES : aucun ne conditionne un autre. C est ce
	# qui rend l ordre libre. Un seul lien entre deux d entre eux ferait un ordre
	# impose que le joueur subirait sans le voir.
	for id: StringName in demons:
		var lv: LevelDef = ContentDB.levels[id]
		for suivant: StringName in lv.next_levels:
			not_ok(demons.has(suivant),
				("%s ne doit pas conditionner %s : les quatre grands" % [id, suivant])
				+ " demons s affrontent dans l ordre qu on veut")


## Le CINQUIEME niveau de l acte 4 ne s ouvre qu apres les quatre, et il est le
## seul a rendre la main a l acte 5.
##
## Le deblocage reel est le fait de `SaveData.unlock_level()`, appele pour chaque
## `next_levels` du niveau termine : les quatre demons doivent donc TOUS citer le
## pentacle. Un seul qui l oublie et le joueur qui finit par celui-la reste
## bloque devant un acte 5 grise, sans rien pour le lui expliquer.
func _test_lacte_4_se_ferme_sur_le_pentacle() -> void:
	var pentacles: Array[StringName] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act != 4:
			continue
		var ouvre_acte5: bool = false
		for suivant: StringName in lv.next_levels:
			var apres: LevelDef = ContentDB.levels.get(suivant)
			if apres != null and apres.act == 5:
				ouvre_acte5 = true
		if ouvre_acte5:
			pentacles.append(lv.id)
	eq(pentacles.size(), 1,
		"un seul niveau de l acte 4 ouvre l acte 5 (trouve : %s)" % str(pentacles))
	if pentacles.size() != 1:
		return
	var pentacle: StringName = pentacles[0]

	# LES QUATRE DEMONS MENENT TOUS AU PENTACLE. C est la traduction exacte de
	# « une fois les 4 realises vous brisez le pentacle » dans un systeme qui
	# deverrouille par `next_levels`.
	var demons: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act != 4 or lv.id == pentacle:
			continue
		demons += 1
		ok(lv.next_levels.has(pentacle),
			("%s mene au pentacle %s : sinon le joueur qui finit" % [lv.id, pentacle])
			+ " l acte par ce niveau-la ne le voit jamais s ouvrir")
	eq(demons, 4, "quatre grands demons devant le pentacle (%d)" % demons)


## L ACTE 5 — L ESPACE DIVIN, trois niveaux, et il ferme le jeu.
##
## Le test nomme les niveaux comme celui de l acte 1, et pour la meme raison :
## les identifiants ne suivent pas l ordre de jeu, donc seul un ordre ECRIT en
## dur prouve que le chainage est celui du document.
func _test_lacte_5_suit_le_document() -> void:
	const ORDRE: Array[StringName] = [&"lvl_14", &"lvl_15", &"lvl_16"]
	for id: StringName in ORDRE:
		ok(ContentDB.levels.has(id), "%s existe" % id)
		if not ContentDB.levels.has(id):
			return
		eq((ContentDB.levels[id] as LevelDef).act, 5,
			"%s appartient a l acte 5" % id)
		# L espace divin a SON fond, et il n avait jamais ete affiche : la page
		# de l acte 5 montrait « Le voyage ne va pas encore jusqu ici ».
		eq((ContentDB.levels[id] as LevelDef).backdrop, "act5_divine",
			"%s se joue dans l espace divin" % id)

	for i in ORDRE.size() - 1:
		var lv: LevelDef = ContentDB.levels[ORDRE[i]]
		ok(lv.next_levels.has(ORDRE[i + 1]),
			"%s mene a %s (ordre du document)" % [ORDRE[i], ORDRE[i + 1]])

	# LE BOSS FINAL EST L ENFANT. Le document (section 7) fait du gamin sauve au
	# premier niveau la divinite qui a pose la date. Sans cette assertion, le
	# dernier niveau de la campagne pourrait se fermer sur n importe quel gros
	# monstre et la scene du retournement parlerait dans le vide.
	var fin: LevelDef = ContentDB.levels[ORDRE[2]]
	var boss: WaveDef = fin.boss_wave()
	ok(boss != null, "le dernier niveau de la campagne porte une vague de boss")
	if boss == null:
		return
	ok(not boss.entries.is_empty() and boss.entries[0] != null
		and boss.entries[0].enemy != null
		and boss.entries[0].enemy.id == &"child_god",
		"c est l Enfant, devenu divinite, qui ferme la campagne")


## « Les anciens boss redeviennent des monstres ordinaires » (section 7). C est
## le PROPOS de l acte 5, et c est aussi une regle mecanique verifiable : le
## Gardien et Chronos doivent apparaitre dans des vagues NORMALES de l acte 5.
##
## Attention a la regle voisine, dans `test_bosses` : le Gardien est mort a la
## fin de l acte 1 et ne doit plus MENER de vague de boss ou de mini-boss. Les
## deux regles ne se contredisent pas, elles se completent — il revient en
## vermine, pas en evenement, et c est exactement la difference que l acte 5
## raconte.
func _test_lacte_5_renvoie_les_anciens_boss_en_vague_normale() -> void:
	var en_vermine: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act != 5:
			continue
		for w: WaveDef in lv.waves:
			if w == null or w.is_boss or w.is_miniboss:
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					en_vermine[e.enemy.id] = lv.id
	for ancien: StringName in [&"warden", &"chronos"]:
		ok(en_vermine.has(ancien),
			("%s descend en vague NORMALE a l acte 5 : ce qui etait un" % ancien)
			+ " evenement devient de la vermine (docs/histoire.md section 7)")


## LA CAMPAGNE FINIT DANS L ESPACE DIVIN, et finir la campagne ouvre le
## Massacre.
##
## `_test_la_campagne_ne_se_termine_pas_en_impasse` compte les culs-de-sac mais
## ne dit pas OU ils tombent : la campagne pourrait se terminer au milieu de
## l acte 2 et rester verte. Celui-ci nomme la sortie.
##
## `SaveData.campaign_cleared()` compte les niveaux termines sur le TOTAL de
## `ContentDB.levels` : ajouter sept niveaux ne peut pas rendre le Massacre
## inatteignable, mais peut le rendre inatteignable en PRATIQUE si un niveau
## n est relie a rien. C est pour cela que l atteignabilite est testee plus haut
## sur TOUS les niveaux, celui-ci fermant la boucle par l autre bout.
func _test_la_campagne_se_termine_sur_lacte_5() -> void:
	var feuilles: Array[StringName] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv.next_levels.is_empty():
			feuilles.append(lv.id)
	for id: StringName in feuilles:
		var lv: LevelDef = ContentDB.levels[id]
		eq(lv.act, 5,
			("%s ferme la campagne : ce doit etre un niveau de l acte 5," % id)
			+ " pas un cul-de-sac au milieu du voyage")


## L ACTE 2 — LES SKY LANDS, quatre etapes dans l ordre du document (section 4) :
## les courants, le port de Haute-Nacelle, le cimetiere de bordure, le Grand
## Appel. Comme pour l acte 1, les niveaux sont NOMMES : c est la seule facon de
## prouver que l ordre de JEU est celui du document alors que les identifiants,
## eux, ne le suivent pas.
##
## POURQUOI CET ORDRE ET PAS L ORDRE DES NUMEROS : `lvl_03` et `lvl_04`
## existaient avant les deux niveaux de vol et portent le cimetiere de bordure,
## donc la FIN de l acte. Les deux niveaux neufs sont la montee, donc le debut.
## Un test qui se contenterait de compter quatre niveaux dans l acte 2
## laisserait passer un chainage qui monte dans les courants APRES avoir visite
## un cimetiere trois iles plus loin.
func _test_lacte_2_suit_le_document() -> void:
	const ORDRE: Array[StringName] = [&"lvl_17", &"lvl_18", &"lvl_03", &"lvl_04"]
	for id: StringName in ORDRE:
		ok(ContentDB.levels.has(id), "%s existe" % id)
		if not ContentDB.levels.has(id):
			return
		eq((ContentDB.levels[id] as LevelDef).act, 2,
			"%s appartient a l acte 2" % id)

	for i in ORDRE.size() - 1:
		var lv: LevelDef = ContentDB.levels[ORDRE[i]]
		ok(lv.next_levels.has(ORDRE[i + 1]),
			"%s mene a %s (ordre du document)" % [ORDRE[i], ORDRE[i + 1]])

	# L acte 1 doit ouvrir sur LA MONTEE, pas sur le cimetiere de bordure. Sans
	# cette assertion, `lvl_09` pourrait continuer de pointer sur `lvl_03` et les
	# deux niveaux de vol resteraient greffes au milieu de nulle part.
	var avant: LevelDef = ContentDB.levels.get(&"lvl_09")
	ok(avant != null and avant.next_levels.has(&"lvl_17"),
		"la fin de l acte 1 ouvre LES COURANTS, la premiere etape de l acte 2")

	# La fin de l acte rend la main a l acte 3, et a lui seul.
	var fin: LevelDef = ContentDB.levels[ORDRE[3]]
	eq(fin.next_levels.size(), 1, "la fin de l acte 2 n ouvre qu une suite")
	for suivant: StringName in fin.next_levels:
		var apres: LevelDef = ContentDB.levels.get(suivant)
		ok(apres != null and apres.act == 3,
			"la fin de l acte 2 ouvre l acte 3 (%s)" % suivant)

	# LES QUATRE NIVEAUX SONT ENCADRES DE DIALOGUES. C est le defaut que ce
	# chantier repare : `lvl_03` et `lvl_04` appartenaient a l acte 2 et
	# n avaient PLUS DE SCENE — les leurs avaient ete rendues a l acte 1 parce
	# qu elles y racontaient le dirigeable devant un ossuaire. Deux niveaux muets
	# au milieu d une campagne qui raconte une histoire ne se voient dans aucun
	# autre test.
	for id: StringName in ORDRE:
		var lv: LevelDef = ContentDB.levels[id]
		ok(String(lv.intro_story) != "", "%s a une scene d intro" % id)
		ok(String(lv.outro_story) != "", "%s a une scene d outro" % id)
		for sid: StringName in [lv.intro_story, lv.outro_story]:
			if String(sid) == "":
				continue
			ok(DialogueDef.load_by_id(sid) != null,
				"%s : la scene %s existe sur le disque" % [id, sid])


## « Fond : act1_sky PUIS act2_graveyard » (docs/histoire.md section 4). L acte 2
## MONTE dans le ciel de l acte 1 avant de toucher le cimetiere : les deux
## premieres etapes gardent le ciel, les deux dernieres prennent le cimetiere.
##
## Ce n est pas de la decoration. Le fond determine le MONDE du mode Massacre
## (`WaveBudget.WORLDS` associe un fond a un acte) et surtout il dit au joueur ou
## il se trouve : un cimetiere affiche des la premiere plate-forme volante ferait
## mentir la scene qui vient de se jouer.
func _test_lacte_2_monte_avant_de_descendre() -> void:
	for id: StringName in [&"lvl_17", &"lvl_18"]:
		var lv: LevelDef = ContentDB.levels.get(id)
		ok(lv != null, "%s existe" % id)
		if lv == null:
			continue
		eq(lv.backdrop, "act1_sky",
			"%s se joue encore dans le ciel : l acte 2 MONTE avant de descendre" % id)
	for id: StringName in [&"lvl_03", &"lvl_04"]:
		var lv: LevelDef = ContentDB.levels.get(id)
		if lv == null:
			continue
		eq(lv.backdrop, "act2_graveyard",
			"%s est le cimetiere de bordure : le fond a change" % id)

	# ET IL DOIT Y AVOIR DU VOL. Un acte qui s appelle « Les Sky Lands » dont
	# aucun niveau n envoie de monstre volant serait un decor peint : c est
	# exactement ce que l acte 2 etait avant ce chantier.
	var volants: int = 0
	var lv17: LevelDef = ContentDB.levels.get(&"lvl_17")
	if lv17 != null:
		for w: WaveDef in lv17.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null and e.enemy.flying:
					volants += e.count
	ok(volants >= 6,
		("les courants envoient du VOL : %d corps volants ecrits, il en faut" % volants)
		+ " assez pour que le Mur de pierre soit un mauvais choix")


## L ACTE 3 — LE CIMETIERE DE TOMBOL, cinq etapes, et une FORME que le document
## impose (section 5) : « le Roi squelette FUIT. Tout l acte est une poursuite. »
##
## La fourche `lvl_05` / `lvl_06`, equilibree au banc bien avant ce chantier, est
## CONSERVEE au milieu de l acte : elle tient le role des deux etapes
## intermediaires. Ce test verrouille donc une forme precise — deux etapes
## imposees, une fourche a deux branches, une derniere etape imposee — parce que
## c est elle qui fait tenir ensemble le document et le contenu deja mesure.
func _test_lacte_3_est_une_poursuite_avec_sa_fourche() -> void:
	var acte3: Array[StringName] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act == 3:
			acte3.append(lv.id)
	acte3.sort()
	eq(acte3.size(), 5, "l acte 3 compte cinq niveaux (trouve %s)" % str(acte3))

	# Les deux premieres etapes, imposees et dans cet ordre.
	const DEBUT: Array[StringName] = [&"lvl_19", &"lvl_20"]
	for id: StringName in DEBUT:
		ok(ContentDB.levels.has(id), "%s existe" % id)
		if not ContentDB.levels.has(id):
			return
		eq((ContentDB.levels[id] as LevelDef).act, 3, "%s appartient a l acte 3" % id)
	var fosses: LevelDef = ContentDB.levels[&"lvl_19"]
	ok(fosses.next_levels.has(&"lvl_20"),
		"les fosses basses menent a la cour des rois morts")

	# LA FOURCHE. La cour ouvre les DEUX branches d un coup : c est ce qui rend
	# l ordre libre, et c est la seule chose qui distingue une fourche d une
	# file indienne.
	var cour: LevelDef = ContentDB.levels[&"lvl_20"]
	eq(cour.next_levels.size(), 2,
		"la cour des rois morts ouvre les deux branches de la fourche (%d)"
		% cour.next_levels.size())
	for id: StringName in cour.next_levels:
		var lv: LevelDef = ContentDB.levels.get(id)
		ok(lv != null and lv.act == 3,
			"%s, branche de la fourche, appartient a l acte 3" % id)

	# LES DEUX BRANCHES SE REJOIGNENT devant la derniere etape. Une seule qui
	# l oublie et le joueur qui finit l acte par cette branche-la reste devant un
	# acte 4 grise sans rien pour le lui expliquer — le deblocage passe par
	# `next_levels`, pas par un compteur d actes.
	for id: StringName in cour.next_levels:
		var lv: LevelDef = ContentDB.levels.get(id)
		if lv == null:
			continue
		ok(lv.next_levels.has(&"lvl_21"),
			"%s retombe dans le pentacle : les deux branches se rejoignent" % id)
		eq(lv.next_levels.size(), 1,
			"%s ne doit rien ouvrir d autre que le pentacle" % id)


## LE SCEAU DE TOMBOL FERME L ACTE 3, et le pentacle est le SEUL passage vers
## l acte 4.
##
## Les deux assertions vont ensemble et c est voulu : `test_bosses` exige un
## adversaire unique par niveau, donc la fin d acte est le seul endroit ou une
## vague de boss se justifie, et `_test_lacte_4_est_ouvert_en_eventail` (acte 4)
## exige qu UN SEUL niveau anterieur ouvre les quatre grands demons. Si le
## pentacle cessait d etre la fin de l acte 3, les deux regles tomberaient
## ensemble sans qu on sache laquelle corriger — d ou une assertion qui les
## nomme toutes les deux au meme endroit.
func _test_lacte_3_se_ferme_sur_le_sceau_de_tombol() -> void:
	var fin: LevelDef = ContentDB.levels.get(&"lvl_21")
	ok(fin != null, "le pentacle existe")
	if fin == null:
		return
	eq(fin.act, 3, "le pentacle appartient a l acte 3")

	var boss: WaveDef = fin.boss_wave()
	ok(boss != null, "le dernier niveau de l acte 3 porte une vague de boss")
	if boss == null:
		return
	ok(not boss.entries.is_empty() and boss.entries[0] != null
		and boss.entries[0].enemy != null
		and boss.entries[0].enemy.id == &"tombol_seal",
		"c est le Sceau de Tombol qui ferme l acte 3")

	# UN SEUL PASSAGE VERS L ACTE 4, et c est le pentacle.
	for lv: LevelDef in ContentDB.levels.values():
		if lv.act > 3:
			continue
		for suivant: StringName in lv.next_levels:
			var apres: LevelDef = ContentDB.levels.get(suivant)
			if apres != null and apres.act == 4:
				eq(lv.id, &"lvl_21",
					("%s ouvre l acte 4 : seul le pentacle descend dans le" % lv.id)
					+ " monde demoniaque (docs/histoire.md section 5)")


## LES SILHOUETTES ORPHELINES DOIVENT ETRE JOUEES.
##
## `AnimCatalog.UNITS` portait neuf feuilles extraites qu aucun monstre
## n utilisait : du travail d extraction paye et mort. Les actes 2 et 3 leur
## donnent un lieu.
##
## POURQUOI CE TEST ICI ET PAS DANS `test_bosses` : celui-la verifie qu une
## silhouette porte un MONSTRE ; celui-ci verifie que le monstre descend dans une
## VAGUE ECRITE d un niveau de campagne. Ce sont deux defauts differents et le
## second est le plus courant — un `.tres` present dans un `enemy_pool` mais dans
## aucune vague est invisible pour un joueur de campagne.
func _test_les_silhouettes_orphelines_ont_un_niveau() -> void:
	const ORPHELINES: Array[StringName] = [
		&"flyingeye", &"goblin2", &"skeleton2", &"evilwizard", &"fireworm",
		&"ghoul", &"bluewitch", &"nightborne", &"mageguardian",
	]
	# anim_key -> le monstre qui la porte.
	var portees: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.anim_key in ORPHELINES:
			portees[d.anim_key] = d.id
	for cle: StringName in ORPHELINES:
		ok(portees.has(cle),
			("la silhouette %s ne porte aucun monstre : elle a ete extraite pour" % cle)
			+ " rien")

	# ET ELLE DESCEND DANS UNE VAGUE ECRITE.
	var en_vague: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					en_vague[e.enemy.id] = lv.id
	for cle: StringName in ORPHELINES:
		if not portees.has(cle):
			continue
		var id: StringName = portees[cle]
		ok(en_vague.has(id),
			("%s (silhouette %s) n apparait dans AUCUNE vague de campagne :" % [id, cle])
			+ " le joueur ne le croisera jamais")
