extends TestCase
## LES OBJECTIFS LIVRES — le contenu, pas le moteur (test_objective_engine).
##
## Demande du co-auteur (27/09) : trois objectifs par combat de campagne,
## differents, coherents avec le niveau, et une vraie variete sur la campagne.
## Les 21 niveaux portaient jusque-la le MEME trio recopie. Ce qui est verifie :
##   - trois objectifs valides par niveau, trois CONTROLES differents ;
##   - aucun objectif impossible ni gratuit selon l AUDIT (l AUDIT ne fait
##     qu AVERTIR sur le gratuit : ici c est une faute) ;
##   - la variete : assez de controles differents, aucun controle partout,
##     aucun trio recopie d un niveau a l autre ;
##   - les exemples du co-auteur presents quelque part ;
##   - le libelle livre = le libelle genere.
##
## Les BORNES de variete sont ecrites en dur : un test qui les relirait dans le
## contenu qu il controle ne mordrait jamais (piege note dans gotchas.md).

func get_suite_name() -> String:
	return "level_objectives"


## Au moins autant de controles differents sur la campagne. Il en existe 16 ;
## un seul (never_dropped_speed) est hors d atteinte dans des niveaux de moins
## de 175 s, voir la table de tools/make_content.gd.
const MIN_CLES_DIFFERENTES: int = 12
## Un meme controle sur plus d un tiers des 21 niveaux redevient un trio
## recopie qui ne dit plus rien du niveau.
const MAX_NIVEAUX_PAR_CLE: int = 7
## Les exemples ecrits par le co-auteur : "ne pas perdre de vie, ne pas utiliser
## de legendaire, jouer 30 fois la meme carte, gagner avec moins de 300 de
## vitesse, tuer 5 monstres en meme temps".
const EXEMPLES_CO_AUTEUR: Array[StringName] = [
	&"no_damage_taken", &"no_legendary_used", &"same_card_casts",
	&"win_below_speed", &"multi_kill",
]
## Les exemples du 30/09, qui LIENT les objectifs aux cartes et aux monstres :
## "tuer 4 Oiseaux mirage en une attaque", "tuer 8 monstres en moins d une
## seconde", "jouer Fleche 6 fois", "gagner sans jouer Boule de feu", "finir
## avec plus de 300 %", "ne pas se faire toucher par un lutin archer", "gagner
## en ayant pris des degats d un renard dormeur". Ecrits avec LEURS chiffres :
## ce sont les phrases du co-auteur, pas des reglages. Un exemple dont le seuil
## serait retouche au banc doit etre retire d ici en le disant, pas maquille.
const EXEMPLES_30_09: Array[Dictionary] = [
	{"key": &"kill_type_one_cast", "params": {"enemy": "rat_swarm", "count": 4}},
	{"key": &"multi_kill", "params": {"count": 8, "window": 1}},
	{"key": &"card_casts", "params": {"card": "piercing_arrow", "count": 6}},
	{"key": &"no_card", "params": {"card": "fireball"}},
	{"key": &"win_above_speed", "params": {"pct": 300}},
	{"key": &"no_hit_from", "params": {"enemy": "imp_archer"}},
	{"key": &"hit_from", "params": {"enemy": "sleepy_fox"}},
]


## Les deux defis du co-auteur que la campagne exploitait mal (vague 8, 01/10) :
## "finir avec moins de 120 % de vitesse" n etait nulle part (le plus bas etait
## 150 %), "faire parcourir une tres grande distance a un monstre" une seule
## fois, a 0,8 longueur. Ses mots : 120 %, et PLUSIEURS longueurs de terrain.
const DEFI_VITESSE_BASSE: int = 120
const DEFI_GRANDE_DISTANCE_LONGUEURS: float = 2.0
## Ce qui FAIT MARCHER un monstre : mur, riviere, volte-face, nappe, appat.
const CLES_QUI_FONT_MARCHER: Array[StringName] = [
	&"build_wall", &"terrain_river", &"reverse_enemies", &"water_flood", &"taunt_prop",
]


func run() -> void:
	_test_trois_objectifs_valides_et_differents()
	_test_ni_impossible_ni_gratuit()
	_test_variete_sur_la_campagne()
	_test_exemples_du_co_auteur()
	_test_les_defis_de_la_vague_8()
	_test_libelle_livre_est_le_libelle_genere()
	_test_le_detecteur_de_doublon_mord()


func _niveaux() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for lv: LevelDef in ContentDB.levels.values():
		if lv != null:
			out.append(lv)
	return out


## Les raisons de refuser le trio d UN niveau. Vide = conforme. Separe du test
## pour pouvoir le SABOTER sur un niveau fabrique (_test_le_detecteur_de_doublon_mord).
static func defauts_du_trio(lv: LevelDef) -> Array[String]:
	var out: Array[String] = []
	if lv.objectives.size() != 3:
		out.append("%d objectifs (3 attendus)" % lv.objectives.size())
	var cles: Dictionary = {}
	var ids: Dictionary = {}
	for o: ObjectiveDef in lv.objectives:
		if o == null:
			out.append("objectif nul")
			continue
		for err in ObjectiveChecker.validate(o):
			out.append("%s : %s" % [o.id, err])
		if ids.has(o.id):
			out.append("id %s en double" % o.id)
		ids[o.id] = true
		# DIFFERENTS = trois controles distincts. Deux multi_kill a des seuils
		# differents font deux etoiles pour un seul geste.
		if cles.has(o.check_key):
			out.append("controle %s en double" % o.check_key)
		cles[o.check_key] = true
	return out


func _test_trois_objectifs_valides_et_differents() -> void:
	var niveaux: Array[LevelDef] = _niveaux()
	ok(niveaux.size() > 0, "des niveaux a controler")
	for lv in niveaux:
		var defauts: Array[String] = defauts_du_trio(lv)
		ok(defauts.is_empty(), "%s : trio conforme %s" % [lv.id, defauts])


func _test_ni_impossible_ni_gratuit() -> void:
	for lv in _niveaux():
		for o: ObjectiveDef in lv.objectives:
			if o == null:
				continue
			var impossible: Array[String] = ObjectiveChecker.impossible_reasons(o, lv)
			ok(impossible.is_empty(), "%s / %s possible %s" % [lv.id, o.id, impossible])
			var gratuit: Array[String] = ObjectiveChecker.trivial_reasons(o, lv)
			ok(gratuit.is_empty(), "%s / %s pas gratuit %s" % [lv.id, o.id, gratuit])


func _test_variete_sur_la_campagne() -> void:
	var niveaux_par_cle: Dictionary = {}
	var trios: Dictionary = {}
	for lv in _niveaux():
		var ids: Array[String] = []
		for o: ObjectiveDef in lv.objectives:
			if o == null:
				continue
			ids.append(String(o.id))
			niveaux_par_cle[o.check_key] = int(niveaux_par_cle.get(o.check_key, 0)) + 1
		ids.sort()
		var trio: String = "+".join(ids)
		ok(not trios.has(trio), "%s : trio different de %s" % [lv.id, trios.get(trio, "-")])
		trios[trio] = lv.id
	ok(niveaux_par_cle.size() >= MIN_CLES_DIFFERENTES,
		"%d controles differents sur la campagne (au moins %d)"
		% [niveaux_par_cle.size(), MIN_CLES_DIFFERENTES])
	for cle in niveaux_par_cle:
		ok(int(niveaux_par_cle[cle]) <= MAX_NIVEAUX_PAR_CLE,
			"%s porte par %d niveaux (au plus %d)"
			% [cle, niveaux_par_cle[cle], MAX_NIVEAUX_PAR_CLE])


func _test_exemples_du_co_auteur() -> void:
	var vues: Dictionary = {}
	for lv in _niveaux():
		for o: ObjectiveDef in lv.objectives:
			if o != null:
				vues[o.check_key] = true
	for cle in EXEMPLES_CO_AUTEUR:
		ok(vues.has(cle), "l exemple du co-auteur %s est dans la campagne" % cle)
	for ex: Dictionary in EXEMPLES_30_09:
		var trouve: bool = false
		for lv in _niveaux():
			for o: ObjectiveDef in lv.objectives:
				if o != null and o.check_key == ex["key"] and _memes_params(o.params, ex["params"]):
					trouve = true
		ok(trouve, "l exemple du co-auteur %s %s est dans la campagne" % [ex["key"], ex["params"]])


## Le niveau donne-t-il de quoi faire marcher un monstre (deck ou cartes
## nouvelles) ? Les recompenses n y sont pas : elles arrivent APRES l etoile.
static func fait_marcher(lv: LevelDef) -> bool:
	for liste: Array in [lv.exploration_deck, lv.levelup_cards]:
		for c in liste:
			if c == null:
				continue
			for cle: StringName in (c as SpellCard).effect_keys():
				if cle in CLES_QUI_FONT_MARCHER:
					return true
	return false


## Les defis de la vague 8 tels que le contenu les porte : chacun en RANG 3 (le
## plus dur) d au moins un niveau, la grande distance la ou l on peut faire
## marcher les monstres. Rend la liste de ce qui manque.
static func defauts_defis_vague_8(niveaux: Array[LevelDef]) -> Array[String]:
	var vitesse: bool = false
	var distance: bool = false
	for lv in niveaux:
		if lv.objectives.size() < 3 or lv.objectives[2] == null:
			continue
		var o: ObjectiveDef = lv.objectives[2]
		match o.check_key:
			&"win_below_speed":
				if int(o.params.get("pct", 0)) <= DEFI_VITESSE_BASSE:
					vitesse = true
			&"enemy_travel":
				var d: float = float(o.params.get("distance", 0.0))
				if d >= DEFI_GRANDE_DISTANCE_LONGUEURS * ObjectiveChecker.terrain_length() \
						and fait_marcher(lv):
					distance = true
	var out: Array[String] = []
	if not vitesse:
		out.append("aucun rang 3 « finir sous %d %% »" % DEFI_VITESSE_BASSE)
	if not distance:
		out.append("aucun rang 3 « %s longueurs de terrain » dans un niveau qui fait marcher"
			% DEFI_GRANDE_DISTANCE_LONGUEURS)
	return out


func _test_les_defis_de_la_vague_8() -> void:
	var niveaux: Array[LevelDef] = _niveaux()
	var d: Array[String] = defauts_defis_vague_8(niveaux)
	ok(d.is_empty(), "les deux defis du co-auteur sont en rang 3 %s" % [d])
	# Sabotage : les memes niveaux sans leur rang 3 ne passent plus.
	var amputes: Array[LevelDef] = []
	for lv in niveaux:
		var copie: LevelDef = lv.duplicate()
		var deux: Array[ObjectiveDef] = []
		for i in mini(2, lv.objectives.size()):
			deux.append(lv.objectives[i])
		copie.objectives = deux
		amputes.append(copie)
	eq(defauts_defis_vague_8(amputes).size(), 2, "sans rang 3, les deux defis manquent")


## Memes parametres, a la valeur pres (1 et 1.0 sont le meme seuil).
static func _memes_params(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in b:
		var v: Variant = a.get(k, a.get(StringName(k)))
		if v == null or str(v) != str(b[k]):
			if not (v is float or v is int) or not is_equal_approx(float(v), float(b[k])):
				return false
	return true


## La description d un .tres n est plus qu un repli : si elle divergeait du
## libelle genere, un ecran qui retomberait dessus dirait autre chose que les
## autres.
func _test_libelle_livre_est_le_libelle_genere() -> void:
	for lv in _niveaux():
		for o: ObjectiveDef in lv.objectives:
			if o != null:
				eq(o.description, ObjectiveChecker.label(o),
					"%s / %s : description = libelle genere" % [lv.id, o.id])


## SABOTAGE EMBARQUE : le detecteur doit refuser un trio recopie en interne.
## Sans ce cas, un defauts_du_trio() qui ne verrait rien passerait en silence.
func _test_le_detecteur_de_doublon_mord() -> void:
	var lv := LevelDef.new()
	lv.id = &"t_sabotage"
	var a := ObjectiveDef.new()
	a.id = &"t_a"
	a.check_key = &"multi_kill"
	a.params = {"count": 5, "window": 1}
	var b := ObjectiveDef.new()
	b.id = &"t_b"
	b.check_key = &"multi_kill"
	b.params = {"count": 6, "window": 1}
	var c := ObjectiveDef.new()
	c.id = &"t_c"
	c.check_key = &"no_passive"
	lv.objectives = [a, b, c]
	not_ok(defauts_du_trio(lv).is_empty(), "deux controles identiques sont refuses")
	lv.objectives = [a, c]
	not_ok(defauts_du_trio(lv).is_empty(), "deux objectifs au lieu de trois sont refuses")
