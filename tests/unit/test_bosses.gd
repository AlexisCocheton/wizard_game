extends TestCase
## Les trois mecaniques de BOSS. Un boss doit demander une reponse DIFFERENTE,
## pas seulement plus de sorts : ces tests verrouillent ce qui rend la reponse
## differente, et rien d autre.
##
##   1. morcele     -> il faut detruire les parties AVANT de pouvoir l entamer
##   2. tireur loin -> il ne descend pas jusqu au mage, il campe et harcele
##   3. invocateur  -> il fabrique des monstres tant qu il vit
##
## Ecrit AVANT le code : chaque assertion decrit une regle, pas une valeur
## d equilibrage (voir gotchas.md, « un test qui fige un REGLAGE bloque
## l equilibrage »).

func get_suite_name() -> String:
	return "bosses"

var _bf: Battlefield = null


func _def(id: String, hp: float = 100.0, speed: float = 60.0, power: int = 1) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.max_hp = hp
	d.base_speed = speed
	d.power = power
	d.base_radius = 40.0
	return d


func _fresh() -> void:
	if _bf != null:
		detach(_bf)
	_bf = Battlefield.new()
	_bf.nav = NavGrid.new()
	attach(_bf)
	reset_gauge_at_normal_speed()
	RunState.reset()


## Simule `seconds` de MONDE A x1, en maintenant le mage en vie.
##
## Depuis que la vitesse EST la vie (26 septembre), ces deux exigences sont la
## meme : le monde tourne a x1 quand le mage est a 100 %, et 100 % est le
## plancher mortel. Un boss qui tire tuait donc le mage en quelques secondes, et
## TOUT le reste de la simulation basculait au ralenti d agonie (x0,25) — le
## symptome etant un boss qui "n arrive jamais a sa ligne de tir", trois etages
## en aval de la vraie cause.
##
## Ces suites mesurent des deplacements, des cadences et des portees ; la survie
## du mage n y est jamais le sujet. On la lui rend donc image par image, ce qui
## tient l horloge du monde exactement a x1. Les tests qui veulent au contraire
## VERIFIER qu un coup coute quelque chose relevent la vitesse avant et apres,
## et ils la lisent dans la meme image que le coup.
func _sim(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_bf.simulate(1.0 / 60.0)
		# `is_dying` ne se leve pas tout seul : le remettre a 100 % sans sortir
		# de l agonie laisserait world_delta() au ralenti pour toujours, et le
		# test mesurerait un monde au quart de sa vitesse sans rien signaler.
		if SpeedGauge.is_dying:
			SpeedGauge.reset()
		SpeedGauge.set_speed_percent(100)
		t += 1.0 / 60.0


func run() -> void:
	_test_morcele_les_parties_protegent_le_coeur()
	_test_morcele_chaque_partie_detruite_affaiblit()
	_test_morcele_sans_parties_se_comporte_normalement()
	_test_tireur_a_distance_s_arrete_a_sa_ligne()
	_test_tireur_a_distance_harcele_depuis_sa_ligne()
	_test_invocateur_fabrique_des_monstres()
	_test_invocateur_mort_cesse_d_invoquer()
	_test_invocateur_ne_noie_pas_l_ecran()
	_test_ressuscite_se_releve_une_fois()
	_test_ressuscite_ne_se_releve_qu_une_fois()
	_test_ressuscite_ne_donne_pas_deux_fois_l_xp()
	_test_ressuscite_se_voit()
	_test_immunise_n_coups_ignore_la_puissance()
	_test_immunise_n_coups_ne_bloque_pas_le_ralentissement()
	_test_renvoi_retourne_les_degats_au_mage()
	_test_renvoi_ne_renvoie_rien_hors_fenetre()
	_test_renvoi_n_empeche_pas_de_le_tuer()
	_test_les_boss_livres_ont_bien_leurs_mecaniques()
	_test_les_trois_nouvelles_mecaniques_sont_livrees()
	_test_chaque_niveau_a_son_propre_adversaire()
	_test_les_silhouettes_du_26_septembre_portent_des_monstres()
	_test_les_monstres_neufs_apparaissent_en_campagne()
	_test_les_monstres_neufs_sont_rattaches_a_un_monde()
	_test_les_monstres_neufs_sortent_vraiment_en_massacre()
	_test_les_paliers_de_la_gorgone_sont_des_paliers()
	if _bf != null:
		detach(_bf)
		_bf = null


# --- 1. Boss en plusieurs morceaux -----------------------------------------

## La regle centrale : tant qu une partie tient, le coeur n encaisse rien. C est
## ce qui change la reponse du joueur — il doit VISER les parties, pas empiler
## les degats sur la masse centrale.
func _test_morcele_les_parties_protegent_le_coeur() -> void:
	_fresh()
	var d := _def("morcele", 100.0, 0.0, 10)
	d.parts_count = 3
	d.part_hp = 20.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))

	eq(boss.parts_left(), 3, "le boss entre avec ses trois parties")
	# Le coup PORTE (flash et son : le joueur voit qu il tape juste), mais il
	# entame la partie, pas le coeur.
	ok(boss.take_damage(15.0, []), "le coup porte sur la partie visee")
	feq(boss.hp, 100.0, "et le coeur reste intact")
	eq(boss.parts_left(), 3, "la partie visee tient encore")

	# Il restait 5 PV a la partie entamee : elle cede.
	boss.take_damage(20.0, [])
	eq(boss.parts_left(), 2, "une partie cede")
	feq(boss.hp, 100.0, "le coeur n a toujours rien pris")

	boss.take_damage(200.0, [])
	eq(boss.parts_left(), 1, "un coup enorme ne detruit QU UNE partie : pas de report")
	feq(boss.hp, 100.0, "le surplus est perdu, il ne coule pas sur le coeur")

	boss.take_damage(20.0, [])
	eq(boss.parts_left(), 0, "derniere partie detruite")
	feq(boss.hp, 100.0, "le coeur est encore intact a cet instant")

	ok(boss.take_damage(30.0, []), "parties tombees : le coeur devient enfin touchable")
	feq(boss.hp, 70.0, "et il encaisse normalement")


## Chaque partie detruite doit RECOMPENSER immediatement, sinon le joueur a
## l impression de taper dans le vide pendant la moitie du combat.
func _test_morcele_chaque_partie_detruite_affaiblit() -> void:
	_fresh()
	var d := _def("morcele2", 100.0, 60.0, 10)
	d.parts_count = 2
	d.part_hp = 10.0
	d.part_slow_pct = 25.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))

	var y0: float = boss.position.y
	boss.advance(1.0)
	var pleine_vitesse: float = boss.position.y - y0

	boss.take_damage(10.0, [])
	eq(boss.parts_left(), 1, "une partie de moins")
	var y1: float = boss.position.y
	boss.advance(1.0)
	var vitesse_reduite: float = boss.position.y - y1
	ok(vitesse_reduite < pleine_vitesse,
		"une partie detruite ralentit le boss : le joueur voit son travail")

	boss.take_damage(10.0, [])
	var y2: float = boss.position.y
	boss.advance(1.0)
	ok(boss.position.y - y2 < vitesse_reduite,
		"la seconde partie le ralentit encore")


## Un boss sans parties (Chronos, Gardien) ne doit rien changer a son comportement :
## le champ est facultatif, pas une refonte du modele de degats.
func _test_morcele_sans_parties_se_comporte_normalement() -> void:
	_fresh()
	var boss: Enemy = _bf.spawn_enemy(_def("simple", 50.0, 0.0, 10), 500.0, 1.0, Vector2(500.0, 500.0))
	eq(boss.parts_left(), 0, "aucune partie declaree")
	ok(boss.take_damage(10.0, []), "les degats passent directement")
	feq(boss.hp, 40.0, "PV entames des le premier coup")


# --- 2. Boss qui tire a distance -------------------------------------------

## Il ne descend PAS jusqu au mage : il s arrete a sa ligne de tir. Le joueur ne
## peut donc pas l ignorer en attendant le contact, ni compter sur sa propre
## ligne de defense — il faut aller le chercher.
func _test_tireur_a_distance_s_arrete_a_sa_ligne() -> void:
	_fresh()
	var d := _def("canonnier", 200.0, 120.0, 10)
	d.keeps_distance_at = 500.0
	d.shoot_interval = 1.0
	d.shot_damage = 1
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 100.0))

	_sim(20.0)
	var ligne: float = GameConfig.MAGE_LINE_Y - 500.0
	ok(boss.position.y <= ligne + 6.0, "il s arrete au plus loin a sa ligne de tir")
	ok(boss.position.y >= ligne - 40.0, "mais il y monte bien : il ne reste pas en haut")
	ok(absf(boss.position.y - ligne) < 20.0, "il se stabilise sur sa ligne, il n oscille pas")
	ok(not boss.is_dead(), "et il n a jamais atteint le mage")


## Une fois campe, il continue de harceler : la distance n est pas une pause.
func _test_tireur_a_distance_harcele_depuis_sa_ligne() -> void:
	_fresh()
	var d := _def("canonnier2", 200.0, 200.0, 10)
	d.keeps_distance_at = 400.0
	d.shoot_interval = 0.4
	d.shot_damage = 1
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 900.0))
	# De la marge, sans emballer le monde : le tir doit BLESSER le mage pendant
	# les 12 s simulees, pas le tuer au premier projectile.
	SpeedGauge.heal(60)
	var pv0: int = SpeedGauge.speed_percent
	_sim(12.0)
	ok(SpeedGauge.speed_percent < pv0, "camper loin n empeche pas de faire mal")


# --- 3. Boss qui invoque ----------------------------------------------------

func _test_invocateur_fabrique_des_monstres() -> void:
	_fresh()
	var sbire := _def("sbire", 5.0, 40.0, 1)
	var d := _def("invocateur", 300.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 1.0
	d.summon_count = 2
	d.summon_max_alive = 99
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))

	eq(_bf.alive_count(), 1, "seul au depart")
	_sim(1.2)
	eq(_bf.alive_count(), 3, "une salve de deux sbires")
	_sim(1.1)
	eq(_bf.alive_count(), 5, "puis une deuxieme salve")


## Tuer l invocateur doit ARRETER le flux : c est toute la reponse que le boss
## demande (couper la source plutot que nettoyer les sbires).
func _test_invocateur_mort_cesse_d_invoquer() -> void:
	_fresh()
	var sbire := _def("sbire2", 5.0, 0.0, 1)
	var d := _def("invocateur2", 30.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 0.5
	d.summon_count = 1
	d.summon_max_alive = 99
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(1.1)
	var apres_deux_salves: int = _bf.alive_count()
	ok(apres_deux_salves >= 3, "le flux a commence")
	boss.take_damage(999.0, [])
	var restants: int = _bf.alive_count()
	_sim(3.0)
	eq(_bf.alive_count(), restants, "boss mort : plus aucune invocation")


## Le plafond existe pour que l invocation reste une PRESSION et non un
## ensevelissement : sans lui, un joueur qui traine perd par accumulation
## mecanique, ce qui n est plus une decision.
func _test_invocateur_ne_noie_pas_l_ecran() -> void:
	_fresh()
	var sbire := _def("sbire3", 5.0, 0.0, 1)
	var d := _def("invocateur3", 500.0, 0.0, 10)
	d.summon_def = sbire
	d.summon_interval = 0.2
	d.summon_count = 2
	d.summon_max_alive = 4
	_bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 400.0))
	_sim(8.0)
	ok(_bf.alive_count() <= 5, "le plafond tient : 4 sbires + le boss au plus")
	ok(_bf.alive_count() >= 3, "mais il invoque quand meme")


# --- 4. Boss qui RESSUSCITE --------------------------------------------------
#
# Ce que la mecanique change : le sens du mot « tuer ». Le joueur voit la barre
# se vider, entend la mort, et repart sur la cible suivante — puis le boss se
# releve derriere lui. Aucune autre mecanique du jeu ne lui demande de GARDER
# des cartes en reserve apres avoir cru le combat fini.

## Il tombe, et il se releve avec une FRACTION de ses PV. Il n a pas disparu du
## terrain : c est la difference entre ressusciter et invoquer un second boss.
func _test_ressuscite_se_releve_une_fois() -> void:
	_fresh()
	var d := _def("phenix", 100.0, 0.0, 10)
	d.revive_hp_pct = 40.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))

	eq(_bf.alive_count(), 1, "un seul boss sur le terrain")
	boss.take_damage(150.0, [])
	not_ok(boss.is_dead(), "il ne meurt pas au premier zero : il se releve")
	eq(_bf.alive_count(), 1, "et c est le MEME monstre, pas un second boss")
	feq(boss.hp, 40.0, "il revient avec 40 % de ses PV d origine")
	ok(boss.has_revived(), "le releve est memorise")


## La resurrection est UNIQUE. Sans plafond, un joueur qui n a pas le bon deck
## ne finirait jamais le combat : ce ne serait plus une surprise, ce serait un
## mur de PV deguise.
func _test_ressuscite_ne_se_releve_qu_une_fois() -> void:
	_fresh()
	var d := _def("phenix2", 100.0, 0.0, 10)
	d.revive_hp_pct = 50.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	boss.take_damage(100.0, [])
	not_ok(boss.is_dead(), "premier releve")
	# Le repit de releve doit s ecouler : tant qu il tient, le boss est
	# intouchable — c est ce qui rend le releve visible a l ecran, et c est aussi
	# ce qui interdit au sort qui vient de le tuer de le retuer dans la meme frame.
	ok(not boss.take_damage(999.0, []),
		"pendant le repit du releve, il est intouchable")
	_sim(1.5)
	boss.take_damage(999.0, [])
	ok(boss.is_dead(), "le repit passe, la deuxieme mort est definitive")
	_sim(0.1)
	eq(_bf.alive_count(), 0, "et il quitte bien le terrain")


## L XP et le compteur de chasse ne doivent tomber QU A la mort definitive.
## Un boss qui paierait deux fois serait la meilleure ferme d XP du jeu, et le
## compteur d objectifs ("tuer N boss") compterait un adversaire pour deux.
var _tues: int = 0


func _compte_mort(_def: EnemyDef) -> void:
	_tues += 1


func _test_ressuscite_ne_donne_pas_deux_fois_l_xp() -> void:
	_fresh()
	var d := _def("phenix3", 60.0, 0.0, 10)
	d.revive_hp_pct = 50.0
	d.base_xp = 30
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	_tues = 0
	if not _bf.enemy_killed.is_connected(_compte_mort):
		_bf.enemy_killed.connect(_compte_mort)
	boss.take_damage(60.0, [])
	eq(_tues, 0, "un releve ne compte pas comme une mort : ni XP ni statistique")
	_sim(1.5)
	boss.take_damage(999.0, [])
	eq(_tues, 1, "la mort definitive, elle, compte une fois")


## Une mecanique qu on ne VOIT pas n existe pas pour le joueur. Le releve doit
## etre lisible : PV visibles a l ecran (barre reaffichee) et la barre ne doit
## pas rester a zero derriere un boss qui marche encore.
func _test_ressuscite_se_voit() -> void:
	_fresh()
	var d := _def("phenix4", 100.0, 0.0, 10)
	d.revive_hp_pct = 35.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	boss.take_damage(200.0, [])
	ok(boss.hp > 0.0, "il porte des PV : la barre a de quoi se remplir")
	ok(boss.hp < boss.max_hp(),
		"mais pas pleins : le joueur doit voir qu il l a deja entame")


# --- 5. Boss IMMUNISE aux N premiers coups -----------------------------------
#
# Ce que la mecanique change : la MONNAIE des degats. Partout ailleurs le joueur
# paie en points de degats ; ici il paie en NOMBRE DE COUPS. Le spam de petites
# cartes devient le pire choix possible, et le gros sort charge le meilleur —
# l inverse exact du reflexe que tout le reste du jeu encourage.

## Le coeur de la regle : la PUISSANCE du coup n entre pas en ligne de compte.
func _test_immunise_n_coups_ignore_la_puissance() -> void:
	_fresh()
	var d := _def("intouchable", 100.0, 0.0, 10)
	d.hits_immune = 3
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))

	eq(boss.hits_immune_left(), 3, "il entre avec trois coups d avance")
	not_ok(boss.take_damage(9999.0, []),
		"un coup ENORME ne passe pas mieux qu un petit : c est un COMPTEUR")
	feq(boss.hp, 100.0, "aucun degat")
	eq(boss.hits_immune_left(), 2, "mais le coup a bien ete consomme")

	not_ok(boss.take_damage(1.0, []), "deuxieme coup consomme")
	not_ok(boss.take_damage(1.0, []), "troisieme coup consomme")
	eq(boss.hits_immune_left(), 0, "le compteur est vide")

	ok(boss.take_damage(30.0, []), "le quatrieme coup, lui, mord")
	feq(boss.hp, 70.0, "et il encaisse normalement ensuite")


## Un compteur de COUPS ne doit pas rendre le boss insensible au CONTROLE :
## sinon la mecanique cesse d etre « depense tes coups » pour devenir « cinq
## secondes d invulnerabilite totale », ce que le joueur ne peut pas jouer.
func _test_immunise_n_coups_ne_bloque_pas_le_ralentissement() -> void:
	_fresh()
	var d := _def("intouchable2", 100.0, 60.0, 10)
	d.hits_immune = 5
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 300.0))
	# Reference : ce qu il parcourt en une seconde sans rien subir.
	var ref0: float = boss.position.y
	boss.advance(1.0)
	var libre: float = boss.position.y - ref0

	ok(boss.apply_stun(1.0), "il se fige comme n importe qui")
	eq(boss.hits_immune_left(), 5,
		"et un etourdissement ne consomme AUCUN coup : ce n est pas un degat")
	var y_stun: float = boss.position.y
	boss.advance(0.5)
	ok(absf(boss.position.y - y_stun) < 1.0, "etourdi, il n avance pas du tout")

	boss.apply_slow(0.5, 5.0)
	_sim(0.6)  # le reste de l etourdissement s ecoule
	var y1: float = boss.position.y
	boss.advance(1.0)
	var ralenti: float = boss.position.y - y1
	ok(ralenti > 0.0, "il repart apres l etourdissement")
	ok(ralenti < libre * 0.7,
		"et il est ralenti : %.1f px contre %.1f px libre" % [ralenti, libre])
	eq(boss.hits_immune_left(), 5, "le controle n a toujours mange aucun coup")


# --- 6. Boss a BOUCLIER DE RENVOI --------------------------------------------
#
# Ce que la mecanique change : le MOMENT du lancement. Tout le reste du jeu
# recompense le joueur qui lance des qu une carte est prete ; ici lancer au
# mauvais moment lui coute ses propres PV. C est la seule mecanique du jeu ou
# regarder le boss vaut mieux que regarder sa main.

## Pendant la fenetre de renvoi, les degats reviennent au mage. Ils passent par
## le meme chemin bouclier-puis-PV qu un contact : le renvoi n est pas une
## exception a la mecanique signature.
func _test_renvoi_retourne_les_degats_au_mage() -> void:
	_fresh()
	var d := _def("miroir", 200.0, 0.0, 10)
	d.reflect_interval = 4.0
	d.reflect_window = 2.0
	d.reflect_pct = 50.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))

	# On force la fenetre plutot que d attendre : le test verrouille la REGLE du
	# renvoi, pas la cadence, qui est un reglage d equilibrage.
	boss.force_reflect_window(2.0)
	ok(boss.is_reflecting(), "la fenetre est ouverte")

	# De la marge : au plancher, le mage mourrait au lieu d encaisser. Ces
	# trois tests ne chronometrent rien (ils appellent damage_enemy directement),
	# la vitesse du monde n y change donc rien.
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var pv0: int = SpeedGauge.speed_percent
	var tags: Array = []
	_bf.damage_enemy(boss, 40.0, null)
	ok(SpeedGauge.speed_percent < pv0, "le mage encaisse son propre sort")
	ok(boss.hp < 200.0, "le boss encaisse quand meme : le renvoi n est pas un mur")


## Hors fenetre, il se comporte comme n importe quel boss. Sans cette respiration
## le joueur ne pourrait JAMAIS lancer, et la mecanique deviendrait une interdiction
## au lieu d un choix de timing.
func _test_renvoi_ne_renvoie_rien_hors_fenetre() -> void:
	_fresh()
	var d := _def("miroir2", 200.0, 0.0, 10)
	d.reflect_interval = 6.0
	d.reflect_window = 1.0
	d.reflect_pct = 100.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	not_ok(boss.is_reflecting(), "il n entre pas la garde levee")

	# De la marge : au plancher, le mage mourrait au lieu d encaisser. Ces
	# trois tests ne chronometrent rien (ils appellent damage_enemy directement),
	# la vitesse du monde n y change donc rien.
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var pv0: int = SpeedGauge.speed_percent
	_bf.damage_enemy(boss, 40.0, null)
	eq(SpeedGauge.speed_percent, pv0, "hors fenetre, rien ne revient")
	feq(boss.hp, 160.0, "et le sort porte pleinement")


## Le renvoi ne doit pas rendre le boss increvable : on peut le tuer PENDANT sa
## garde, en acceptant le prix. Sinon ce n est plus un choix, c est une attente.
func _test_renvoi_n_empeche_pas_de_le_tuer() -> void:
	_fresh()
	var d := _def("miroir3", 30.0, 0.0, 10)
	d.reflect_interval = 5.0
	d.reflect_window = 3.0
	d.reflect_pct = 50.0
	var boss: Enemy = _bf.spawn_enemy(d, 500.0, 1.0, Vector2(500.0, 500.0))
	boss.force_reflect_window(3.0)
	# De la marge : au plancher, le mage mourrait au lieu d encaisser. Ces
	# trois tests ne chronometrent rien (ils appellent damage_enemy directement),
	# la vitesse du monde n y change donc rien.
	SpeedGauge.set_speed_percent(GameConfig.SPEED_MAX_PERCENT)
	var pv0: int = SpeedGauge.speed_percent
	_bf.damage_enemy(boss, 99.0, null)
	ok(boss.is_dead(), "garde levee ou non, il meurt quand les PV tombent")
	# ET LE COUP FATAL SE PAIE QUAND MEME. C est la regle la plus fragile des
	# trois : la part renvoyee doit etre relevee AVANT d appliquer les degats,
	# parce que le coup ferme la garde en tuant son porteur. La lire apres rendrait
	# le coup mortel GRATUIT — le joueur apprendrait a tout garder pour la garde,
	# soit l inverse exact de ce que la mecanique demande.
	ok(SpeedGauge.speed_percent < pv0,
		"le coup qui le tue pendant sa garde est renvoye lui aussi")
	not_ok(boss.is_reflecting(), "et sa garde tombe avec lui")


# --- Le contenu livre --------------------------------------------------------

## Les trois mecaniques doivent exister DANS LE JEU, pas seulement dans le
## moteur : un champ implemente que personne n utilise est du code mort.
func _test_les_boss_livres_ont_bien_leurs_mecaniques() -> void:
	var morcele: int = 0
	var distant: int = 0
	var invocateur: int = 0
	for def: EnemyDef in ContentDB.enemies.values():
		if not def.is_boss():
			continue
		if def.parts_count > 0:
			morcele += 1
			ok(def.part_hp > 0.0, "%s : des parties sans PV seraient increvables" % def.id)
		if def.keeps_distance_at > 0.0:
			distant += 1
			ok(def.shoot_interval > 0.0,
				"%s : camper loin sans tirer ne serait qu une absence" % def.id)
		if def.summon_interval > 0.0:
			invocateur += 1
			ok(def.summon_def != null, "%s : invoque du vide" % def.id)
			ok(def.summon_max_alive > 0, "%s : invocation sans plafond" % def.id)
			ok(def.summon_def.power < def.power,
				"%s : un boss invoque des sbires, pas ses egaux" % def.id)
	ok(morcele >= 1, "au moins un boss en plusieurs morceaux est livre")
	ok(distant >= 1, "au moins un boss qui campe et harcele est livre")
	ok(invocateur >= 1, "au moins un boss qui invoque est livre")


## Les trois mecaniques du chantier I doivent exister DANS LE JEU, et surtout
## etre RENCONTRABLES : le piege mesure le 25 septembre est qu un monstre cree
## mais absent de toute vague ecrite n appartient a aucun monde, donc le mode
## infini ne le propose JAMAIS et l audit ne voit rien.
##
## Ce test ne se contente donc pas de l existence du .tres : il sonde les deux
## chemins reels par lesquels le joueur peut le croiser.
func _test_les_trois_nouvelles_mecaniques_sont_livrees() -> void:
	var ressuscite: Array[EnemyDef] = []
	var compteur: Array[EnemyDef] = []
	var renvoi: Array[EnemyDef] = []
	for def: EnemyDef in ContentDB.enemies.values():
		if def.revive_hp_pct > 0.0:
			ressuscite.append(def)
			ok(def.revive_hp_pct < 100.0,
				"%s : revenir a PV pleins serait deux combats, pas un releve" % def.id)
		if def.hits_immune > 0:
			compteur.append(def)
			ok(def.hits_immune <= 12,
				"%s : au-dela d une dizaine de coups le joueur ne peut plus payer" % def.id)
		if def.reflect_pct > 0.0:
			renvoi.append(def)
			ok(def.reflect_interval > 0.0 and def.reflect_window > 0.0,
				"%s : un renvoi sans cadence ne s ouvre jamais" % def.id)
			ok(def.reflect_window < def.reflect_interval,
				"%s : une fenetre plus longue que son cycle = garde permanente" % def.id)
	ok(ressuscite.size() >= 1, "au moins un boss qui ressuscite est livre")
	ok(compteur.size() >= 1, "au moins un boss immunise aux N premiers coups est livre")
	ok(renvoi.size() >= 1, "au moins un boss a bouclier de renvoi est livre")

	# SONDE 1 — la CAMPAGNE. Le boss doit mener une vague ecrite.
	var en_campagne: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					en_campagne[e.enemy.id] = lv.id
	for def in ressuscite + compteur + renvoi:
		ok(en_campagne.has(def.id),
			"%s n apparait dans AUCUNE vague de campagne : injouable" % def.id)

	# SONDE 2 — le MASSACRE. L appartenance a un monde se DEDUIT de la densite
	# dans les vagues ecrites : un boss absent des vagues n a pas de monde, donc
	# pick_boss() ne le choisira jamais pour son palier.
	var membership: Dictionary = WaveSpawner.build_membership()
	for def in ressuscite + compteur + renvoi:
		ok(membership.has(def.id),
			"%s n est rattache a aucun monde : le Massacre ne le proposera jamais"
			% def.id)

	# SONDE 3 — il est bien TIRE par le mode infini. On genere assez de vagues pour
	# couvrir plusieurs tours de mondes et on releve les TETES de palier.
	#
	# CE QUE CETTE SONDE A MESURE, et qui est un DEFAUT DU MOTEUR, pas du contenu :
	# `WaveBudget.pick_boss()` renvoie le PREMIER boss du pool dont le monde
	# correspond, et le pool arrive dans l ordre de lecture du disque, donc
	# ALPHABETIQUE. Des qu un monde compte deux boss du meme `kind`, le second
	# n est JAMAIS tire — quel que soit le contenu ecrit pour lui.
	#
	# Releve du 25 septembre sur 300 vagues, AVANT toute modification du chantier I :
	# `gravecaller`, `warden` et `wraith_lord` etaient deja injoignables en
	# Massacre pour cette raison — trois boss sur les neuf d alors. `glass_mirror`
	# s ajoute a la liste, derriere `emberlord` dans le monde demoniaque.
	#
	# Le correctif vit dans `scripts/game/wave_budget.gd` (tirer au hasard parmi
	# les candidats du monde, au lieu du premier) et ce fichier est HORS du
	# perimetre du chantier I. Le test verrouille donc ce qu il peut verrouiller
	# sans mentir : qu au moins une des mecaniques neuves sort en Massacre, et que
	# le nombre de boss starves ne GRANDIT pas. Il rougira au prochain boss ajoute
	# dans un monde deja servi, ce qui est exactement le moment ou il faut ouvrir
	# wave_budget.gd.
	var bosses: Array[EnemyDef] = []
	var pool: Array[EnemyDef] = []
	for def: EnemyDef in ContentDB.enemies.values():
		if def.is_boss():
			bosses.append(def)
		elif not def.projectile:
			pool.append(def)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var tetes: Dictionary = {}
	for n in range(1, 301):
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, bosses, membership)
		if (w.is_boss or w.is_miniboss) and not w.entries.is_empty() \
				and w.entries[0].enemy != null:
			tetes[w.entries[0].enemy.id] = true

	# Les deux boss (kind BOSS) du chantier menent chacun leur monde : eux doivent
	# sortir, sans exception.
	for def in ressuscite + compteur:
		ok(tetes.has(def.id),
			"%s n est jamais tire sur 300 vagues de Massacre" % def.id)

	# Le compte de boss starves ne doit pas grandir. 4 est le releve du jour, dont
	# 3 anterieurs au chantier I.
	var prives: Array[String] = []
	for def in bosses:
		if not tetes.has(def.id):
			prives.append(String(def.id))
	prives.sort()
	ok(prives.size() <= 4,
		("%d boss ne sont jamais tires en Massacre (%s) : pick_boss() rend le"
		+ " PREMIER candidat du monde, donc le premier par ordre alphabetique."
		+ " Le correctif est dans wave_budget.gd.")
		% [prives.size(), ", ".join(prives)])


## Un niveau doit avoir SON adversaire, pas celui du voisin.
##
## Le defaut mesure le 25 septembre : sur six niveaux a boss, le joueur
## affrontait DEUX adversaires uniques — le meme Gardien six fois en mini-boss,
## et Chronos quatre fois en boss, dont le premier et le dernier niveau. Le
## manque de monstres n y etait pour rien (quatre P10 et sept candidats
## mini-boss existaient) : c etait une compression de 21 niveaux en 7.
##
## La seule repetition tolere est CHRONOS en `lvl_07`, et elle est voulue :
## docs/histoire.md fait revenir "l huissier du niveau 1" pour fermer la boucle.
## Le test l autorise nommement plutot que de compter large, pour qu une
## deuxieme repetition, elle, fasse rougir.
func _test_chaque_niveau_a_son_propre_adversaire() -> void:
	var vus_mini: Dictionary = {}
	var vus_boss: Dictionary = {}
	var niveaux: int = 0
	for lv: LevelDef in ContentDB.levels.values():
		niveaux += 1
		for w: WaveDef in lv.waves:
			if w == null or w.entries.is_empty():
				continue
			var tete: WaveEntry = w.entries[0]
			if tete == null or tete.enemy == null:
				continue
			var id: StringName = tete.enemy.id
			if w.is_boss:
				if vus_boss.has(id):
					# La seule exception, nommee : la boucle narrative.
					ok(id == &"chronos",
						"%s ferme %s ET %s — un seul boss peut revenir, Chronos"
						% [id, vus_boss[id], lv.id])
				else:
					vus_boss[id] = lv.id
			elif w.is_miniboss:
				not_ok(vus_mini.has(id),
					"%s mene le mini-boss de %s ET de %s"
					% [id, vus_mini.get(id, &"?"), lv.id])
				vus_mini[id] = lv.id
	ok(niveaux >= 7, "la campagne compte au moins 7 niveaux (%d)" % niveaux)
	# Le compte prouve la VARIETE, pas seulement l absence de doublon : sans lui,
	# supprimer tous les boss ferait passer le test.
	ok(vus_boss.size() >= 5,
		"au moins 5 boss differents sur la campagne (%d)" % vus_boss.size())
	ok(vus_mini.size() >= 5,
		"au moins 5 mini-boss differents (%d)" % vus_mini.size())

	# Le Gardien de la foret MEURT en lvl_04 (docs/histoire.md : "il s effondre
	# en un tas de bois mort", et la plaque de metal dans sa poitrine lance
	# l intrigue). Il ne doit reapparaitre dans aucun niveau suivant.
	for lv: LevelDef in ContentDB.levels.values():
		if String(lv.id) <= "lvl_04":
			continue
		for w: WaveDef in lv.waves:
			if w == null or not (w.is_boss or w.is_miniboss):
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					not_ok(e.enemy.id == &"warden",
						"%s : le Gardien est mort en lvl_04, il ne revient pas"
						% lv.id)


# --- CHANTIER I2 : les monstres du 26 septembre sont-ils RENCONTRES ? ------
#
# LE PIEGE QUI A COUTE LE PLUS CHER sur ce projet, et qu aucun autre etage ne
# voit : creer un monstre ne suffit pas a le rendre atteignable. Le .tres
# existe, l audit le trouve dans un pool, et le joueur ne le croise jamais.
#
# Deux chemins mènent au joueur, et il faut sonder LES DEUX :
#   1. la CAMPAGNE — il doit apparaitre dans une WaveDef ecrite ;
#   2. le MASSACRE — `build_membership()` deduit le monde d un monstre de sa
#      DENSITE dans les vagues ecrites. Un monstre absent des vagues n a pas de
#      monde, donc le tirage pondere ne le propose jamais.
#
# Ce test verifie les deux pour CHAQUE monstre portant une silhouette du pack du
# 26 septembre, en les trouvant par leur `anim_key` plutot que par une liste
# d ids en dur : ainsi il mordra aussi pour le prochain monstre ajoute sur une
# de ces feuilles sans etre branche dans une vague.
const SILHOUETTES_2026_09_26: Array[StringName] = [
	&"flyingeye", &"goblin2", &"mushroom", &"skeleton2", &"evilwizard",
	&"fireworm", &"ghoul", &"gorgon", &"bluewitch", &"smallmonster",
	&"mageguardian", &"demonslime", &"nightborne", &"executioner",
]


func _test_les_silhouettes_du_26_septembre_portent_des_monstres() -> void:
	var portees: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.anim_key in SILHOUETTES_2026_09_26:
			portees[d.anim_key] = true
	# On n exige pas les quatorze : mieux vaut cinq monstres soignes que
	# quatorze batacles. On exige que le travail d extraction ne soit pas MORT.
	ok(portees.size() >= 5,
		("seulement %d des 14 silhouettes du 26 septembre portent un monstre :"
		+ " le reste est du travail extrait qui ne sert a rien")
		% portees.size())


## SONDE 1 — la CAMPAGNE. Chaque monstre neuf doit mener ou peupler une vague
## ecrite, sinon il est invisible en campagne ET sans monde en Massacre.
func _test_les_monstres_neufs_apparaissent_en_campagne() -> void:
	var en_campagne: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					en_campagne[e.enemy.id] = lv.id
	var muets: Array[String] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile or not (d.anim_key in SILHOUETTES_2026_09_26):
			continue
		# Un sbire invoque par un boss est atteignable par son invocateur : il n a
		# pas besoin de sa propre vague. On verifie donc qu il a une SOURCE.
		if _est_invoque(d.id):
			continue
		if not en_campagne.has(d.id):
			muets.append(String(d.id))
	muets.sort()
	ok(muets.is_empty(),
		("ces monstres neufs n apparaissent dans AUCUNE vague de campagne et ne"
		+ " sont invoques par personne : injouables — %s") % ", ".join(muets))


func _est_invoque(id: StringName) -> bool:
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.summon_def != null and d.summon_def.id == id:
			return true
	return false


## SONDE 2 — le MASSACRE. Le monde se DEDUIT des vagues ecrites ; sans monde,
## pick_boss() et le tirage pondere ignorent le monstre pour toujours.
func _test_les_monstres_neufs_sont_rattaches_a_un_monde() -> void:
	var membership: Dictionary = WaveSpawner.build_membership()
	var orphelins: Array[String] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile or not (d.anim_key in SILHOUETTES_2026_09_26):
			continue
		if _est_invoque(d.id):
			continue
		if not membership.has(d.id):
			orphelins.append(String(d.id))
	orphelins.sort()
	ok(orphelins.is_empty(),
		("ces monstres neufs ne sont rattaches a AUCUN monde : le Massacre ne les"
		+ " proposera jamais — %s") % ", ".join(orphelins))


## SONDE 3 — ils sortent VRAIMENT. On joue des vagues et on releve ce qui tombe.
## C est la seule sonde qui attrape un `pick_boss()` qui affame un candidat, et
## un poids de monde qui etouffe une famille entiere.
func _test_les_monstres_neufs_sortent_vraiment_en_massacre() -> void:
	var membership: Dictionary = WaveSpawner.build_membership()
	var pool: Array[EnemyDef] = []
	var bosses: Array[EnemyDef] = []
	var neufs: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile:
			continue
		if d.is_boss():
			bosses.append(d)
		else:
			pool.append(d)
		if (d.anim_key in SILHOUETTES_2026_09_26) and not _est_invoque(d.id):
			neufs.append(d)

	var vus: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for n in range(1, 301):
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, bosses, membership)
		if w == null:
			continue
		for e: WaveEntry in w.entries:
			if e != null and e.enemy != null:
				vus[e.enemy.id] = true

	var jamais: Array[String] = []
	for d in neufs:
		if not vus.has(d.id):
			jamais.append(String(d.id))
	jamais.sort()
	ok(jamais.is_empty(),
		("sur 300 vagues de Massacre ces monstres neufs ne sortent JAMAIS : le"
		+ " .tres existe, le joueur ne les verra pas — %s") % ", ".join(jamais))


## LES TROIS PALIERS DE LA GORGONE DOIVENT ETRE DES PALIERS, donc rencontres
## dans l ordre de puissance croissante et non au hasard.
##
## CE QUE CE TEST N EXIGE PAS, et pourquoi. Un premier jet exigeait que la
## gorgone de BOSS mene une vague de boss de campagne. Verifie sur le contenu
## reel : les sept niveaux ont chacun SON boss et SON mini-boss, et six des sept
## boss portent une mecanique unique ecrite pour leur niveau (morcele, canonnier,
## invocateur, ressuscite, compteur de coups, renvoi). Lui faire de la place
## aurait voulu dire en DEPLACER un, donc casser le travail du chantier I et la
## narration de docs/histoire.md. Le test aurait ete vert au prix du contenu, ce
## qui est exactement l inverse de son role.
##
## Ce qu il exige a la place, et qui est la VRAIE condition de jouabilite :
##   - le palier 1 (monstre commun) descend dans des vagues ecrites ;
##   - le palier 2 (mini-boss) MENE une vague de mini-boss de campagne, donc le
##     joueur rencontre la mecanique a un palier avant de l affronter a trois ;
##   - le palier 3 (boss) est rattache a un monde et TIRE par le Massacre, qui
##     est le chemin reel par lequel un boss sans niveau se rencontre.
func _test_les_paliers_de_la_gorgone_sont_des_paliers() -> void:
	var par_regard: Dictionary = {}
	for d: EnemyDef in ContentDB.enemies.values():
		if d != null and d.blocks_cards > 0:
			par_regard[d.blocks_cards] = d
	eq(par_regard.size(), 3, "les trois paliers 1 / 2 / 3 existent")
	if par_regard.size() < 3:
		return

	# La puissance doit MONTER avec le nombre de regards : un monstre commun qui
	# gelerait plus de cartes qu un boss rendrait les paliers illisibles.
	var p1: EnemyDef = par_regard[1]
	var p2: EnemyDef = par_regard[2]
	var p3: EnemyDef = par_regard[3]
	ok(p1.power < p2.power and p2.power <= p3.power,
		"plus le monstre gele de cartes, plus il est puissant (%d / %d / %d)"
		% [p1.power, p2.power, p3.power])

	# Palier 1 : il descend dans des vagues ecrites.
	var corps: Dictionary = {}
	var mene_mini: Dictionary = {}
	for lv: LevelDef in ContentDB.levels.values():
		for w: WaveDef in lv.waves:
			if w == null or w.entries.is_empty():
				continue
			for e: WaveEntry in w.entries:
				if e != null and e.enemy != null:
					corps[e.enemy.id] = true
			if w.is_miniboss and w.entries[0] != null and w.entries[0].enemy != null:
				mene_mini[w.entries[0].enemy.id] = lv.id
	ok(corps.has(p1.id), "%s (1 regard) descend dans des vagues de campagne" % p1.id)

	# Palier 2 : il MENE une vague de mini-boss. C est le palier pedagogique — la
	# mecanique doit etre enseignee a 2 cartes avant d etre payee a 3.
	ok(mene_mini.has(p2.id),
		"%s (2 regards) doit MENER une vague de mini-boss : c est la ou le joueur"
		% p2.id + " apprend la mecanique avant de la subir a trois cartes")

	# Palier 3 : rattache a un monde ET reellement tire par le Massacre.
	var membership: Dictionary = WaveSpawner.build_membership()
	ok(membership.has(p3.id),
		"%s (3 regards) doit etre rattache a un monde, sinon le Massacre l ignore"
		% p3.id)
	var pool: Array[EnemyDef] = []
	var bosses: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d == null or d.projectile:
			continue
		if d.is_boss():
			bosses.append(d)
		else:
			pool.append(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var sorti: bool = false
	for n in range(1, 301):
		var w: WaveDef = WaveBudget.build_wave(n, pool, rng, bosses, membership)
		if w == null:
			continue
		for e: WaveEntry in w.entries:
			if e != null and e.enemy != null and e.enemy.id == p3.id:
				sorti = true
	ok(sorti, "%s (3 regards) sort reellement sur 300 vagues de Massacre" % p3.id)
