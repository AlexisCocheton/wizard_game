extends TestCase
## MODE TESTEUR — deblocage temporaire de tout le contenu.
##
## Pourquoi ce mode existe : le controle qualite doit juger une carte
## legendaire, un niveau tardif ou un cosmetique SANS rejouer la campagne. Ce
## n est pas une triche, c est un raccourci d inspection.
##
## POURQUOI UN INTERRUPTEUR ET NON UN BOUTON "TOUT DEBLOQUER"
## Un bouton ecrirait les deblocages DANS le profil : la progression reelle du
## testeur serait alors indistinguable du deblocage, et definitivement perdue.
## L interrupteur est un CALQUE : les listes du profil ne bougent pas, seuls les
## accesseurs repondent "oui" tant qu il est allume. L eteindre rend la
## progression reelle a l identique — c est ce que verifie
## `_test_eteindre_rend_la_progression_reelle()`, et c est la raison d etre du
## choix.
##
## CE QUI EST DEDUIT DU CONTENU, JAMAIS RECOPIE
## Le nombre de niveaux, de cartes, de monstres, de defis et de paliers de compte
## change a chaque chantier. Aucun test ici n ecrit "7" ou "16" : tout se compte
## sur ContentDB. Un mode testeur qui debloquerait six niveaux sur vingt-et-un
## serait pire qu inutile — il donnerait l illusion d avoir tout ouvert.

func get_suite_name() -> String:
	return "tester_mode"


func run() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	_test_eteint_par_defaut()
	_test_debloque_tous_les_niveaux()
	_test_ouvre_le_massacre()
	_test_decouvre_toutes_les_cartes_et_legendaires()
	_test_decouvre_tout_le_bestiaire()
	_test_ouvre_les_cosmetiques_et_le_niveau_de_compte()
	_test_ouvre_tous_les_succes()
	_test_eteindre_rend_la_progression_reelle()
	_test_remise_a_zero_eteint_le_mode()
	_test_le_mode_est_persiste_dans_les_reglages()
	_test_interface_des_reglages()
	_test_les_encres_du_bloc_sont_lisibles()
	# Etat propre pour les suites suivantes : un mode testeur qui fuit d une
	# suite a l autre rendrait vrais tous les verrous que les autres testent.
	SaveData.set_tester_mode(false)
	SaveData.reset_profile()
	ContentDB.discover_starters()


func _test_eteint_par_defaut() -> void:
	SaveData.reset_profile()
	not_ok(SaveData.tester_mode(),
		"un profil neuf n est PAS en mode testeur")
	not_ok(SaveData.is_level_unlocked(&"lvl_02"),
		"et ses verrous tiennent normalement")


## Tous les niveaux du CATALOGUE, quel qu en soit le nombre. La campagne passe de
## 7 a 21 niveaux : une liste codee en dur serait fausse demain.
func _test_debloque_tous_les_niveaux() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	ok(ContentDB.levels.size() >= 7,
		"le catalogue a au moins 7 niveaux (%d)" % ContentDB.levels.size())
	for id in ContentDB.levels.keys():
		ok(SaveData.is_level_unlocked(id),
			"%s est ouvert en mode testeur" % id)
	eq(SaveData.playable_levels().size(), ContentDB.levels.size(),
		"la campagne propose TOUT le catalogue, pas une partie")
	# Un id qui n existe pas ne doit pas devenir vrai pour autant : le mode
	# ouvre le contenu existant, il n invente pas de niveau.
	not_ok(SaveData.is_level_unlocked(&"lvl_inexistant"),
		"un niveau qui n existe pas reste ferme, meme en mode testeur")


func _test_ouvre_le_massacre() -> void:
	SaveData.reset_profile()
	not_ok(SaveData.campaign_cleared(), "ferme sur un profil neuf")
	SaveData.set_tester_mode(true)
	ok(SaveData.campaign_cleared(),
		"le mode testeur ouvre le Massacre sans finir les 7 niveaux")
	eq(int(SaveData.campaign_progress()[0]), int(SaveData.campaign_progress()[1]),
		"la progression affichee est coherente avec le deblocage")


func _test_decouvre_toutes_les_cartes_et_legendaires() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	ok(ContentDB.cards.size() >= 24,
		"le catalogue a au moins 24 cartes (%d)" % ContentDB.cards.size())
	for id in ContentDB.cards.keys():
		ok(SaveData.is_discovered(id), "la carte %s est decouverte" % id)
	eq(SaveData.discovered_count(), ContentDB.cards.size(),
		"le compteur du menu montre TOUT le catalogue")

	# Les legendaires sont un verrou SEPARE : le deck les refuse si elles ne sont
	# pas dans `unlocked_legendaries()`, meme decouvertes.
	var legendaires: Array = ContentDB.cards_of_rarity(GameEnums.Rarity.LEGENDARY)
	ok(legendaires.size() >= 1, "il existe des legendaires")
	for c: SpellCard in legendaires:
		ok(SaveData.unlocked_legendaries().has(String(c.id)),
			"la legendaire %s est utilisable" % c.id)


func _test_decouvre_tout_le_bestiaire() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	ok(ContentDB.enemies.size() >= 20,
		"le catalogue a au moins 20 monstres (%d)" % ContentDB.enemies.size())
	for id in ContentDB.enemies.keys():
		ok(SaveData.is_enemy_discovered(id), "le monstre %s est au bestiaire" % id)
	eq(SaveData.discovered_enemies_count(), ContentDB.enemies.size(),
		"le compteur du bestiaire montre tout le catalogue")
	eq(SaveData.discovered_enemies().size(), ContentDB.enemies.size(),
		"et la liste aussi (elle alimente la galerie)")


## Le niveau de compte commande les cosmetiques : `equip_cosmetic()` refuse une
## recompense dont `at_level` depasse le niveau. Le mode testeur doit donc lever
## le niveau, pas seulement contourner l equipement — sinon la moitie des
## cosmetiques reste injugeable.
func _test_ouvre_les_cosmetiques_et_le_niveau_de_compte() -> void:
	SaveData.reset_profile()
	var palier_max: int = 1
	for r: AccountRewardDef in ContentDB.rewards_list():
		palier_max = maxi(palier_max, r.at_level)
	ok(palier_max > 1, "des recompenses demandent un niveau de compte (%d)" % palier_max)

	SaveData.set_tester_mode(true)
	ok(SaveData.account_level() >= palier_max,
		"le niveau de compte atteint le palier le plus haut (%d >= %d)"
			% [SaveData.account_level(), palier_max])
	eq(SaveData.unlocked_rewards().size(), ContentDB.rewards_list().size(),
		"TOUTES les recompenses de compte sont debloquees")
	for r: AccountRewardDef in ContentDB.rewards_list():
		if r.is_equippable():
			ok(SaveData.equip_cosmetic(r.id),
				"le cosmetique %s s equipe en mode testeur" % r.id)


func _test_ouvre_tous_les_succes() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	ok(ContentDB.challenges.size() >= 10,
		"le catalogue a au moins 10 succes (%d)" % ContentDB.challenges.size())
	for id in ContentDB.challenges.keys():
		ok(SaveData.is_challenge_done(id),
			"le succes %s est marque accompli" % id)
	eq(SaveData.completed_challenges().size(), ContentDB.challenges.size(),
		"la liste du profil les montre tous")


## LE TEST QUI JUSTIFIE L INTERRUPTEUR.
##
## Le testeur a une progression REELLE sur son telephone. Allumer puis eteindre
## le mode doit la lui rendre a l identique : sinon le mode lui coute sa partie,
## et il ne l allumera jamais.
func _test_eteindre_rend_la_progression_reelle() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	# Une progression reelle modeste : un niveau fini, quelques cartes.
	var lvl1: LevelDef = ContentDB.levels.get(&"lvl_01")
	SaveData.record_victory(lvl1, GameEnums.Mode.EXPLORATION, {}, 6)
	var cartes_avant: int = SaveData.discovered_count()
	var niveaux_avant: int = SaveData.unlocked_levels().size()
	var compte_avant: int = SaveData.account_level()
	var xp_avant: int = SaveData.account_xp()
	var succes_avant: int = SaveData.completed_challenges().size()
	var monstres_avant: int = SaveData.discovered_enemies_count()

	SaveData.set_tester_mode(true)
	eq(SaveData.discovered_count(), ContentDB.cards.size(), "tout est ouvert pendant")
	SaveData.set_tester_mode(false)

	eq(SaveData.discovered_count(), cartes_avant,
		"les cartes reellement decouvertes sont rendues a l identique")
	eq(SaveData.unlocked_levels().size(), niveaux_avant,
		"les niveaux reellement debloques aussi")
	eq(SaveData.account_level(), compte_avant, "le niveau de compte n a pas bouge")
	eq(SaveData.account_xp(), xp_avant, "ni l XP")
	eq(SaveData.completed_challenges().size(), succes_avant, "ni les succes")
	eq(SaveData.discovered_enemies_count(), monstres_avant, "ni le bestiaire")
	ok(SaveData.is_level_unlocked(&"lvl_01"), "le niveau 1 reste ouvert")
	not_ok(SaveData.campaign_cleared(),
		"et le Massacre se REFERME : le verrou reel est de nouveau la")


## Le piege signale : `reset_profile()` est l inverse du deblocage. Un profil
## debloque puis remis a zero doit redevenir VRAIMENT neuf — mode eteint compris,
## sinon la remise a zero ne remettrait rien a zero.
func _test_remise_a_zero_eteint_le_mode() -> void:
	SaveData.set_tester_mode(true)
	ok(SaveData.tester_mode(), "allume")
	SaveData.reset_profile()
	not_ok(SaveData.tester_mode(),
		"la remise a zero eteint le mode testeur")
	not_ok(SaveData.is_level_unlocked(&"lvl_02"),
		"un profil remis a zero est vraiment neuf : le niveau 2 est referme")
	eq(SaveData.completed_challenges().size(), 0, "aucun succes")
	eq(SaveData.account_level(), 1, "niveau de compte 1")
	eq(SaveData.discovered_enemies_count(), 0, "bestiaire vide")


## Le mode vit dans les REGLAGES et non dans le profil : il survit a la remise a
## zero de la progression ? Non — justement pas (voir le test precedent). Mais il
## doit survivre a un redemarrage, sinon le testeur le rallume a chaque lancement.
func _test_le_mode_est_persiste_dans_les_reglages() -> void:
	SaveData.reset_profile()
	SaveData.set_tester_mode(true)
	# On relit le profil comme au demarrage, par la migration.
	var brut: Dictionary = {
		"schema_version": 1,
		"profile": {},
		"settings": {"tester_mode": true},
	}
	SaveData.load_from_dictionary(brut)
	ok(SaveData.tester_mode(),
		"un profil enregistre en mode testeur redemarre en mode testeur")
	# Et un ancien profil, qui n a pas la cle, redemarre eteint.
	SaveData.load_from_dictionary({"schema_version": 1, "profile": {}, "settings": {}})
	not_ok(SaveData.tester_mode(),
		"un profil qui ne connait pas la cle redemarre eteint")
	SaveData.reset_profile()
	ContentDB.discover_starters()


## L INTERFACE. Le mode doit etre ATTEIGNABLE depuis les reglages, armer en deux
## touchers comme la remise a zero, et se VOIR quand il est allume.
##
## Le test porte sur les noeuds reellement construits et non sur une constante :
## un interrupteur present dans le code mais jamais ajoute a l arbre ne debloque
## rien pour personne.
func _test_interface_des_reglages() -> void:
	SaveData.reset_profile()
	ContentDB.discover_starters()
	var panel := SettingsPanel.new()
	attach(panel)

	var bouton: Button = null
	for n in _tous(panel):
		if n is Button and (n as Button).text.to_lower().contains("testeur"):
			bouton = n
	ok(bouton != null, "un bouton MODE TESTEUR existe dans les reglages")
	if bouton == null:
		detach(panel)
		return
	ok(bouton.custom_minimum_size.y >= 90.0,
		"la cible tactile fait au moins 90 px (%.0f)" % bouton.custom_minimum_size.y)

	# Premier toucher : il ARME, il ne debloque pas. C est le modele de la
	# remise a zero, et une action qui reecrit tout le profil le merite.
	bouton.pressed.emit()
	not_ok(SaveData.tester_mode(),
		"le premier toucher arme seulement, rien n est debloque")
	# Second toucher : il allume.
	bouton.pressed.emit()
	ok(SaveData.tester_mode(), "le second toucher allume le mode")

	# Un avertissement doit etre a l ecran quand c est allume : un testeur qui
	# oublie qu il a tout debloque juge mal la difficulte.
	panel.refresh()
	var vu: String = ""
	for n in _tous(panel):
		if n is Label:
			vu += (n as Label).text + "\n"
	ok(vu.to_lower().contains("testeur"),
		"le mode allume se VOIT dans les reglages (texte vu : %d car.)" % vu.length())

	# Eteindre est IMMEDIAT : un seul toucher. On n arme pas une action qui
	# remet le jeu dans son etat normal.
	for n in _tous(panel):
		if n is Button and (n as Button).text.to_lower().contains("testeur"):
			bouton = n
	bouton.pressed.emit()
	not_ok(SaveData.tester_mode(), "un seul toucher eteint le mode")

	detach(panel)
	SaveData.reset_profile()
	ContentDB.discover_starters()


## LES ENCRES, MESUREES ET NON REGARDEES.
##
## Le premier jet mettait UiTheme.RED sur le libelle ACTIF, par reflexe
## ("rouge = attention"). Mesure sur la tuile teal du bouton : 1,15:1, soit un
## texte invisible — justement l etat qu il faut voir. Ce test refait le calcul
## WCAG au lieu de faire confiance a un nom de couleur, pour les DEUX fonds de ce
## bloc, parce qu une encre lisible sur l un est souvent illisible sur l autre.
func _test_les_encres_du_bloc_sont_lisibles() -> void:
	# Luminances des deux fonds de ce bloc, mesurees sur la capture de l ecran.
	var papier: float = 0.84
	var bouton: float = _luminance(Color(0.19, 0.47, 0.53))

	var seuil: float = SettingsPanel.CONTRAST_MIN
	ok(_ratio(_luminance(SettingsPanel.TESTER_INK), papier) >= seuil,
		"l encre du bloc allume tient le seuil sur le papier (%.2f:1)"
			% _ratio(_luminance(SettingsPanel.TESTER_INK), papier))
	ok(_ratio(_luminance(SettingsPanel.TESTER_INK_OFF), papier) >= seuil,
		"l encre du bloc eteint aussi (%.2f:1)"
			% _ratio(_luminance(SettingsPanel.TESTER_INK_OFF), papier))
	ok(_ratio(_luminance(SettingsPanel.TESTER_BTN_INK_ON), bouton) >= seuil,
		"le libelle ACTIF est lisible SUR LE BOUTON (%.2f:1)"
			% _ratio(_luminance(SettingsPanel.TESTER_BTN_INK_ON), bouton))
	# Le piege lui-meme, ecrit noir sur blanc : le rouge du theme est fait pour
	# le fond sombre du jeu, pas pour cette tuile.
	not_ok(_ratio(_luminance(UiTheme.RED), bouton) >= seuil,
		"UiTheme.RED sur ce bouton serait illisible (%.2f:1) — d ou le blanc"
			% _ratio(_luminance(UiTheme.RED), bouton))


## Luminance relative WCAG.
func _luminance(c: Color) -> float:
	return 0.2126 * _canal(c.r) + 0.7152 * _canal(c.g) + 0.0722 * _canal(c.b)


func _canal(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func _ratio(a: float, b: float) -> float:
	var haut: float = maxf(a, b)
	var bas: float = minf(a, b)
	return (haut + 0.05) / (bas + 0.05)


## Tous les descendants, a plat.
func _tous(racine: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in racine.get_children():
		out.append(c)
		out.append_array(_tous(c))
	return out
