class_name ObjectiveChecker
extends RefCounted
## Evaluation des objectifs de niveau : une bibliotheque de CONTROLES PARAMETRES.
##
## Une cle = une regle ; ses parametres (ObjectiveDef.params) disent le seuil.
## Les compteurs vivent dans RunState (section OBJECTIFS PARAMETRES) : ils
## enregistrent des faits, ce fichier les juge. Le libelle joueur est GENERE a
## partir des parametres (label()) : un texte ecrit a la main finirait par dire
## "30 fois" la ou les parametres disent 20.
##
## TOUS LES OBJECTIFS SE JUGENT A LA VICTOIRE (ecran de victoire). "Gagner" est
## donc toujours sous-entendu : une defaite ne valide rien.
##
## REFERENCE DU CHANTIER DE CONTENU
## ================================
## Les parametres s ecrivent en cles String dans le Dictionary. Types :
##   int    = entier GDScript (30, pas 30.0)
##   nombre = entier ou flottant (1, 0.5)
##   tag    = nom d un GameEnums.DamageTag en String ("FIRE", "SUMMON"...)
##   elem   = un tag qui est un vrai element (GameEnums.ELEMENTS : PHYSICAL,
##            FIRE, FROST, ARCANE, POISON, LIGHTNING)
##   effet  = cle d effet de EFFECT_PHRASES ci-dessous (celles qui ont un libelle)
##
## | cle                     | params                 | definition exacte (reussi si...)                               |
## |-------------------------|------------------------|----------------------------------------------------------------|
## | never_dropped_speed     | -                      | aucun coup encaisse ET vitesse au maximum a l evaluation       |
## | no_legendary_used       | -                      | aucune carte legendaire jouee                                  |
## | no_damage_taken         | -                      | aucun coup encaisse (contact, tir, renvoi)                     |
## | same_card_casts         | count:int >= 2         | un meme sort (meme id, tous exemplaires confondus) lance       |
## |                         |                        | au moins count fois dans la partie                             |
## | win_below_speed         | pct:int ]100, max]     | vitesse A LA VICTOIRE strictement sous pct %                   |
## | multi_kill              | count:int >= 2,        | count monstres tues dans une fenetre STRICTEMENT plus courte   |
## |                         | window:nombre ]0, 5]   | que window secondes de combat (morts d une meme image : 0 s)   |
## | no_card_key             | key:effet              | aucun sort lance ne porte un effet de cette cle                |
## | no_card_tag             | tag:tag                | aucun sort lance ne porte ce tag                               |
## | element_casts           | element:elem,          | au moins count sorts portant cet element lances                |
## |                         | count:int >= 1         |                                                                |
## | kill_flying             | count:int >= 1         | au moins count monstres volants tues                           |
## | boss_quick_after_revive | seconds:nombre > 0     | au moins un monstre s est releve, et CHAQUE monstre releve a   |
## |                         |                        | ete acheve moins de seconds s apres son releve                 |
## | never_hit_reflect       | -                      | aucun coup n a mordu un monstre en garde de renvoi             |
## | no_enemy_past           | ratio:nombre ]0, 0.95] | aucun monstre (hors projectiles) n est descendu au-dela de     |
## |                         |                        | ratio du chemin apparition -> ligne du mage (0 haut, 1 mage)   |
## | win_under_time          | seconds:nombre > 0     | victoire en strictement moins de seconds s de combat           |
## | max_distinct_cast       | count:int >= 1         | au plus count sorts DIFFERENTS lances (par id)                 |
## | no_passive              | -                      | aucun pouvoir passif equipe de toute la partie                 |
##
## "Secondes de combat" = temps REEL, pauses exclues (RunState.run_time) : le
## seul temps que le joueur percoit. Le temps du monde court 5 fois plus vite a
## 500 % et rendrait les durees illisibles.
##
## POURQUOI CES DEFINITIONS
## - multi_kill par FENETRE et non "par un meme lancer" : un sort de zone tue
##   sur plusieurs images (zone au sol, poison, chaine), et le joueur ne sait
##   pas quel lancer a porte le coup de grace. "5 monstres en moins de 1 s" se
##   voit a l ecran ; "d un meme lancer" demanderait de tracer chaque source.
## - win_below_speed sur la vitesse FINALE, photographiee a la victoire
##   (RunState.note_victory) : c est la phrase du co-auteur, "gagner avec moins
##   de 300 %". C est un pari de fin de combat — finir sur le fil, pas tout le
##   combat bride.
## - no_passive par l etat a la victoire : aucun chemin ne RETIRE un passif en
##   combat (equip ajoute, swap remplace), donc "aucun a la fin" = "jamais".
## - no_enemy_past borne a 0,95 : voir RunState.note_enemy_depths.
##
## L AUDIT refuse une cle inconnue, un parametre manquant, en trop ou mal type
## (validate), un objectif IMPOSSIBLE dans son niveau (impossible_reasons) et
## signale un objectif GRATUIT (trivial_reasons).

const KEYS: Array[StringName] = [
	&"never_dropped_speed",
	&"no_legendary_used",
	&"no_damage_taken",
	&"same_card_casts",
	&"win_below_speed",
	&"multi_kill",
	&"no_card_key",
	&"no_card_tag",
	&"element_casts",
	&"kill_flying",
	&"boss_quick_after_revive",
	&"never_hit_reflect",
	&"no_enemy_past",
	&"win_under_time",
	&"max_distinct_cast",
	&"no_passive",
]

const T_INT: String = "int"
const T_NUM: String = "nombre"
const T_TAG: String = "tag"
const T_ELEM: String = "elem"
const T_EFFECT: String = "effet"

## Parametres attendus par cle : {nom: type}. Une cle sans parametre a {}.
const SCHEMA: Dictionary = {
	&"never_dropped_speed": {},
	&"no_legendary_used": {},
	&"no_damage_taken": {},
	&"same_card_casts": {"count": T_INT},
	&"win_below_speed": {"pct": T_INT},
	&"multi_kill": {"count": T_INT, "window": T_NUM},
	&"no_card_key": {"key": T_EFFECT},
	&"no_card_tag": {"tag": T_TAG},
	&"element_casts": {"element": T_ELEM, "count": T_INT},
	&"kill_flying": {"count": T_INT},
	&"boss_quick_after_revive": {"seconds": T_NUM},
	&"never_hit_reflect": {},
	&"no_enemy_past": {"ratio": T_NUM},
	&"win_under_time": {"seconds": T_NUM},
	&"max_distinct_cast": {"count": T_INT},
	&"no_passive": {},
}

## Fenetre maximale de multi_kill : au-dela, ce n est plus "en meme temps".
const MULTI_KILL_MAX_WINDOW: float = 5.0
## Plafond de no_enemy_past : voir RunState.note_enemy_depths.
const MAX_DEPTH_RATIO: float = 0.95

## Les cles d effet interdisables, avec la fin de phrase "Gagner sans ...".
## Une cle absente d ici est REFUSEE par validate() : un objectif doit se lire.
const EFFECT_PHRASES: Dictionary = {
	&"build_wall": "poser de mur",
	&"summon_ally": "invoquer d allie",
	&"knockback": "repousser les monstres",
	&"vortex_pull": "lancer de vortex",
	&"stun_zone": "etourdir les monstres",
	&"taunt_prop": "planter d appat",
	&"water_flood": "inonder le terrain",
	&"ground_zone": "poser de zone au sol",
	&"pierce_line": "tirer de sort en ligne",
	&"meteor_storm": "pluie de meteores",
	&"slow_enemy_gauge": "ralentir les monstres",
	&"reverse_enemies": "faire reculer les monstres",
	&"draw_cards": "piocher de carte en plus",
	&"double_cast": "double incantation",
}


static func has_key(key: StringName) -> bool:
	return key in KEYS


# --- Lecture des parametres ---------------------------------------------------

## Valeur d un parametre, qu il soit ecrit en cle String ou StringName.
static func _param(o: ObjectiveDef, name: String) -> Variant:
	if o.params.has(name):
		return o.params[name]
	if o.params.has(StringName(name)):
		return o.params[StringName(name)]
	return null


static func _int(o: ObjectiveDef, name: String) -> int:
	return int(_param(o, name))


static func _num(o: ObjectiveDef, name: String) -> float:
	return float(_param(o, name))


## Valeur entiere du tag nomme ("FIRE" -> DamageTag.FIRE), -1 si inconnu.
static func tag_from_name(name: Variant) -> int:
	if typeof(name) != TYPE_STRING and typeof(name) != TYPE_STRING_NAME:
		return -1
	var s: String = String(name)
	if not GameEnums.DamageTag.has(s):
		return -1
	return int(GameEnums.DamageTag[s])


# --- Validation (AUDIT) -------------------------------------------------------

## Tout ce qui empeche d evaluer l objectif tel qu il est ecrit. Vide = valide.
static func validate(o: ObjectiveDef) -> Array[String]:
	var errs: Array[String] = []
	if o == null:
		errs.append("objectif nul")
		return errs
	if not has_key(o.check_key):
		errs.append("cle inconnue '%s'" % o.check_key)
		return errs
	var attendus: Dictionary = SCHEMA[o.check_key]
	for k in o.params:
		if not attendus.has(String(k)):
			errs.append("parametre inattendu '%s'" % k)
	for nom: String in attendus:
		var v: Variant = _param(o, nom)
		if v == null:
			errs.append("parametre manquant '%s'" % nom)
			continue
		var erreur: String = _type_error(String(attendus[nom]), v)
		if erreur != "":
			errs.append("parametre '%s' : %s" % [nom, erreur])
	if not errs.is_empty():
		return errs
	var borne: String = _bounds_error(o)
	if borne != "":
		errs.append(borne)
	return errs


static func _type_error(type: String, v: Variant) -> String:
	match type:
		T_INT:
			if typeof(v) != TYPE_INT:
				return "entier attendu"
		T_NUM:
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				return "nombre attendu"
		T_TAG:
			if tag_from_name(v) < 0:
				return "nom de GameEnums.DamageTag attendu"
		T_ELEM:
			var t: int = tag_from_name(v)
			if t < 0 or not GameEnums.ELEMENTS.has(t):
				return "element attendu (%s)" % _element_names()
		T_EFFECT:
			if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
				return "cle d effet attendue"
			if not EFFECT_PHRASES.has(StringName(v)):
				return "cle d effet sans libelle (voir EFFECT_PHRASES)"
	return ""


static func _element_names() -> String:
	var noms: PackedStringArray = []
	for t: int in GameEnums.ELEMENTS:
		noms.append(GameEnums.DamageTag.keys()[t])
	return ", ".join(noms)


## Les bornes qui rendent un seuil ABSURDE (gratuit ou impossible en soi).
static func _bounds_error(o: ObjectiveDef) -> String:
	match o.check_key:
		&"same_card_casts":
			if _int(o, "count") < 2:
				return "count doit valoir au moins 2"
		&"win_below_speed":
			var pct: int = _int(o, "pct")
			if pct <= 100 or pct > GameConfig.SPEED_MAX_PERCENT:
				return "pct doit etre dans ]100, %d]" % GameConfig.SPEED_MAX_PERCENT
		&"multi_kill":
			if _int(o, "count") < 2:
				return "count doit valoir au moins 2"
			var w: float = _num(o, "window")
			if w <= 0.0 or w > MULTI_KILL_MAX_WINDOW:
				return "window doit etre dans ]0, %s]" % _fmt(MULTI_KILL_MAX_WINDOW)
		&"element_casts", &"kill_flying", &"max_distinct_cast":
			if _int(o, "count") < 1:
				return "count doit valoir au moins 1"
		&"boss_quick_after_revive", &"win_under_time":
			if _num(o, "seconds") <= 0.0:
				return "seconds doit etre positif"
		&"no_enemy_past":
			var r: float = _num(o, "ratio")
			if r <= 0.0 or r > MAX_DEPTH_RATIO:
				return "ratio doit etre dans ]0, %s]" % _fmt(MAX_DEPTH_RATIO)
	return ""


# --- Evaluation ---------------------------------------------------------------

static func evaluate(objective: ObjectiveDef) -> bool:
	if objective == null:
		return false
	# Un objectif mal ecrit ne se valide JAMAIS : le compter reussi offrirait
	# une etoile, le compter echoue est au moins visible.
	if not validate(objective).is_empty():
		return false
	var o: ObjectiveDef = objective
	match o.check_key:
		&"never_dropped_speed":
			# DEUX CONDITIONS, et c est nouveau. Depuis que la vitesse EST la vie
			# (26 septembre), "la jauge n est jamais retombee" et "aucun degat
			# subi" sont devenus le MEME evenement : les deux objectifs du jeu
			# se seraient valides ensemble, et l un des deux n aurait plus rien
			# signifie.
			#
			# Celui-ci demande donc ce que son libelle a toujours promis —
			# "en gardant la vitesse AU MAXIMUM" — : finir intact ET a plein
			# regime. C est strictement plus dur que "sans subir de degats",
			# puisqu il faut en plus avoir eu le temps de monter jusqu en haut.
			return not RunState.speed_dropped and SpeedGauge.is_at_max()
		&"no_legendary_used":
			return not RunState.used_legendary
		&"no_damage_taken":
			# Aucun coup encaisse. La vitesse n a donc jamais baisse non plus,
			# mais elle n a pas eu besoin d atteindre le maximum : c est ce qui
			# distingue cet objectif de never_dropped_speed.
			return not RunState.took_any_damage
		&"same_card_casts":
			return RunState.max_same_card_casts() >= _int(o, "count")
		&"win_below_speed":
			return RunState.final_speed_percent() < _int(o, "pct")
		&"multi_kill":
			return RunState.best_kill_burst(_num(o, "window")) >= _int(o, "count")
		&"no_card_key":
			return RunState.casts_with_effect(StringName(_param(o, "key"))) == 0
		&"no_card_tag":
			return RunState.casts_with_tag(tag_from_name(_param(o, "tag"))) == 0
		&"element_casts":
			return RunState.casts_with_tag(tag_from_name(_param(o, "element"))) \
				>= _int(o, "count")
		&"kill_flying":
			return RunState.flying_kills >= _int(o, "count")
		&"boss_quick_after_revive":
			# Un releve jamais acheve (parti au contact) fait echouer : le joueur
			# ne l a pas acheve du tout, a fortiori pas a temps.
			if RunState.revive_kill_delays.is_empty() or RunState.revived_still_standing() > 0:
				return false
			for d: float in RunState.revive_kill_delays:
				if d >= _num(o, "seconds"):
					return false
			return true
		&"never_hit_reflect":
			return RunState.reflect_hits == 0
		&"no_enemy_past":
			return RunState.enemy_depth_max <= _num(o, "ratio")
		&"win_under_time":
			return RunState.final_time() < _num(o, "seconds")
		&"max_distinct_cast":
			return RunState.distinct_cards_cast() <= _int(o, "count")
		&"no_passive":
			return RunState.equipped_passives.is_empty()
	return false


# --- Suivi EN COMBAT (HUD) ------------------------------------------------------
#
# Le bandeau d objectifs du HUD lit ces trois fonctions. Elles ne jugent pas la
# victoire (c est evaluate()) : elles disent au joueur OU il en est, et quand un
# objectif est DEJA perdu. Sans elles le joueur decouvrait a l ecran de victoire
# qu il avait rate une etoile a la vague 1 — trop tard pour changer de jeu.

## Libelle COURT pour le HUD, ou la place manque : le libelle complet (label())
## fait jusqu a 45 caracteres, soit la moitie de l ecran a la plus petite police.
static func short_label(o: ObjectiveDef) -> String:
	if o == null or not validate(o).is_empty():
		return o.description if o != null else ""
	match o.check_key:
		&"never_dropped_speed": return "Vitesse max"
		&"no_legendary_used": return "Sans legendaire"
		&"no_damage_taken": return "Sans degats"
		&"same_card_casts": return "Meme sort"
		&"win_below_speed": return "Sous %d %%" % _int(o, "pct")
		&"multi_kill": return "Serie en %s" % _duration(_num(o, "window"))
		&"no_card_key": return "Sans %s" % EFFECT_PHRASES[StringName(_param(o, "key"))]
		&"no_card_tag":
			return "Sans sort %s" % _of_tag(tag_from_name(_param(o, "tag")), false)
		&"element_casts":
			return "Sorts %s" % _of_tag(tag_from_name(_param(o, "element")), true)
		&"kill_flying": return "Volants"
		&"boss_quick_after_revive": return "Releve acheve"
		&"never_hit_reflect": return "Sans renvoi"
		&"no_enemy_past": return "Ligne tenue"
		&"win_under_time": return "Chrono"
		&"max_distinct_cast": return "Sorts differents"
		&"no_passive": return "Sans passif"
	return o.description


## Avancement d un objectif QUI SE COMPTE : {"current", "target", "time"}.
## Vide pour un objectif qui ne se compte pas (une interdiction, un etat final) :
## il n a rien a afficher tant qu il n est pas perdu.
##
## `time` = vrai quand les deux valeurs sont des secondes (win_under_time) : le
## HUD les ecrit en minutes, "83/180" ne se lit pas comme une duree.
static func progress(o: ObjectiveDef) -> Dictionary:
	if o == null or not validate(o).is_empty():
		return {}
	match o.check_key:
		&"same_card_casts":
			return {"current": RunState.max_same_card_casts(), "target": _int(o, "count"),
				"time": false}
		&"multi_kill":
			# Le RECORD de la partie : une serie reussie reste acquise meme si les
			# morts suivantes s etalent.
			return {"current": RunState.best_kill_burst(_num(o, "window")),
				"target": _int(o, "count"), "time": false}
		&"element_casts":
			return {"current": RunState.casts_with_tag(tag_from_name(_param(o, "element"))),
				"target": _int(o, "count"), "time": false}
		&"kill_flying":
			return {"current": RunState.flying_kills, "target": _int(o, "count"),
				"time": false}
		&"max_distinct_cast":
			# Un PLAFOND et non un but : le compte monte vers la limite a ne pas
			# franchir. is_failed() le declare perdu des qu il la depasse.
			return {"current": RunState.distinct_cards_cast(), "target": _int(o, "count"),
				"time": false}
		&"win_under_time":
			return {"current": RunState.run_time, "target": _num(o, "seconds"), "time": true}
	return {}


## L objectif est-il DEJA perdu, quoi qu il arrive d ici la victoire ?
##
## LA REGLE : on ne declare perdu que sur un fait IRREVERSIBLE — un compteur qui
## ne redescend jamais dans une partie. Annoncer « rate » puis voir l etoile
## tomber a la victoire serait pire que ne rien dire : le joueur aurait lache
## l objectif sur la foi d un faux signal. Donc, pour chaque cle ici,
## is_failed() vrai IMPLIQUE evaluate() faux a la victoire (verrouille par
## test_objective_progress.gd).
##
## Ne sont jamais declares perdus en cours de route : ce qui peut encore etre
## atteint (compter plus, tuer plus) et ce qui se juge sur l etat FINAL
## (win_below_speed : la vitesse peut encore baisser).
static func is_failed(o: ObjectiveDef) -> bool:
	if o == null or not validate(o).is_empty():
		return false
	match o.check_key:
		&"never_dropped_speed":
			return RunState.speed_dropped
		&"no_legendary_used":
			return RunState.used_legendary
		&"no_damage_taken":
			return RunState.took_any_damage
		&"no_card_key":
			return RunState.casts_with_effect(StringName(_param(o, "key"))) > 0
		&"no_card_tag":
			return RunState.casts_with_tag(tag_from_name(_param(o, "tag"))) > 0
		&"boss_quick_after_revive":
			# Un releve acheve trop tard, ou un releve encore debout depuis plus
			# longtemps que le delai : dans les deux cas il ne peut plus l etre a temps.
			var s: float = _num(o, "seconds")
			for d: float in RunState.revive_kill_delays:
				if d >= s:
					return true
			return RunState.revived_oldest_age() >= s
		&"never_hit_reflect":
			return RunState.reflect_hits > 0
		&"no_enemy_past":
			return RunState.enemy_depth_max > _num(o, "ratio")
		&"win_under_time":
			return RunState.run_time >= _num(o, "seconds")
		&"max_distinct_cast":
			return RunState.distinct_cards_cast() > _int(o, "count")
		&"no_passive":
			return not RunState.equipped_passives.is_empty()
	return false


# --- Libelle joueur -----------------------------------------------------------

## Le texte affiche au joueur (briefing, carte de campagne, victoire). Genere
## depuis les parametres. La `description` du .tres ne sert plus que de repli
## pour une cle inconnue.
static func label(o: ObjectiveDef) -> String:
	if o == null:
		return ""
	if not validate(o).is_empty():
		return o.description
	match o.check_key:
		&"never_dropped_speed":
			return "Gagner en gardant la vitesse au maximum des la vague 1"
		&"no_legendary_used":
			return "Gagner sans utiliser de carte legendaire"
		&"no_damage_taken":
			return "Gagner sans subir de degats"
		&"same_card_casts":
			return "Lancer %d fois le meme sort" % _int(o, "count")
		&"win_below_speed":
			return "Gagner avec moins de %d %% de vitesse" % _int(o, "pct")
		&"multi_kill":
			return "Tuer %d monstres en moins de %s" % [_int(o, "count"),
				_duration(_num(o, "window"))]
		&"no_card_key":
			return "Gagner sans %s" % EFFECT_PHRASES[StringName(_param(o, "key"))]
		&"no_card_tag":
			return "Gagner sans sort %s" % _of_tag(tag_from_name(_param(o, "tag")), false)
		&"element_casts":
			var n: int = _int(o, "count")
			return "Lancer %d sort%s %s" % [n, "s" if n > 1 else "",
				_of_tag(tag_from_name(_param(o, "element")), n > 1)]
		&"kill_flying":
			var n: int = _int(o, "count")
			if n == 1:
				return "Abattre un monstre volant"
			return "Abattre %d monstres volants" % n
		&"boss_quick_after_revive":
			return "Achever un boss releve en moins de %s" % _duration(_num(o, "seconds"))
		&"never_hit_reflect":
			return "Ne jamais frapper un monstre en garde de renvoi"
		&"no_enemy_past":
			return "Aucun monstre au-dela %s du terrain" % _share(_num(o, "ratio"))
		&"win_under_time":
			return "Gagner en moins de %s" % _duration(_num(o, "seconds"))
		&"max_distinct_cast":
			var n: int = _int(o, "count")
			return "Gagner avec %d sort%s different%s au plus" % [n,
				"s" if n > 1 else "", "s" if n > 1 else ""]
		&"no_passive":
			return "Gagner sans pouvoir passif"
	return o.description


## "de feu", "d arcane", "physique(s)" : le complement d un sort de cet element.
static func _of_tag(tag: int, pluriel: bool) -> String:
	if tag == GameEnums.DamageTag.PHYSICAL:
		return "physiques" if pluriel else "physique"
	var nom: String = GameEnums.tag_name(tag)
	if nom.substr(0, 1) in ["a", "e", "i", "o", "u"]:
		return "d " + nom
	return "de " + nom


## "de la moitie", "des trois quarts", "de 60 %".
static func _share(ratio: float) -> String:
	if is_equal_approx(ratio, 0.5):
		return "de la moitie"
	if is_equal_approx(ratio, 0.75):
		return "des trois quarts"
	return "de %d %%" % int(round(ratio * 100.0))


## 0.5 -> "0,5 s", 90 -> "90 s", 180 -> "3 min", 150 -> "2 min 30".
static func _duration(s: float) -> String:
	if s < 120.0:
		return "%s s" % _fmt(s)
	var total: int = int(round(s))
	var m: int = total / 60
	var r: int = total % 60
	if r == 0:
		return "%d min" % m
	return "%d min %02d" % [m, r]


## Nombre a la francaise, sans decimale inutile : 1 -> "1", 0.5 -> "0,5".
static func _fmt(x: float) -> String:
	if is_equal_approx(x, round(x)):
		return "%d" % int(round(x))
	return String.num(snappedf(x, 0.01)).replace(".", ",")


# --- Coherence avec le niveau (AUDIT) -----------------------------------------

## Raisons pour lesquelles l objectif ne peut PAS etre reussi dans ce niveau.
## Build rouge : une etoile inaccessible est du contenu mort.
static func impossible_reasons(o: ObjectiveDef, level: LevelDef) -> Array[String]:
	var out: Array[String] = []
	if o == null or level == null or not validate(o).is_empty():
		return out
	var monstres: Array[EnemyDef] = level_enemies(level)
	match o.check_key:
		&"kill_flying":
			var cap: int = flying_capacity(level)
			if cap == 0:
				out.append("aucun monstre volant dans les vagues")
			elif cap > 0 and cap < _int(o, "count"):
				out.append("%d volants au plus pour %d demandes" % [cap, _int(o, "count")])
		&"boss_quick_after_revive":
			if not monstres.any(func(d: EnemyDef) -> bool: return d.revive_hp_pct > 0.0):
				out.append("aucun monstre ne se releve dans ce niveau")
		&"element_casts":
			if _deck_count_tag(level, tag_from_name(_param(o, "element"))) == 0:
				out.append("aucune carte de cet element dans le deck du niveau")
		&"multi_kill":
			var plus_grosse: int = 0
			for w: WaveDef in level.waves:
				if w != null:
					plus_grosse = maxi(plus_grosse, w.total_enemies())
			if plus_grosse < _int(o, "count"):
				out.append("aucune vague ne compte %d monstres" % _int(o, "count"))
	return out


## Raisons pour lesquelles l objectif est GRATUIT dans ce niveau. Avertissement
## seulement : une carte proposee en cours de partie peut encore le faire mordre.
static func trivial_reasons(o: ObjectiveDef, level: LevelDef) -> Array[String]:
	var out: Array[String] = []
	if o == null or level == null or not validate(o).is_empty():
		return out
	match o.check_key:
		&"never_hit_reflect":
			if not level_enemies(level).any(func(d: EnemyDef) -> bool:
					return d.reflect_pct > 0.0 and d.reflect_window > 0.0 \
						and d.reflect_interval > 0.0):
				out.append("aucun monstre a garde de renvoi dans ce niveau")
		&"no_card_tag":
			if _deck_count_tag(level, tag_from_name(_param(o, "tag"))) == 0:
				out.append("aucune carte de ce tag dans le deck du niveau")
		&"no_card_key":
			var cle: StringName = StringName(_param(o, "key"))
			var trouve: bool = false
			for c: SpellCard in level.exploration_deck:
				if c != null and not c.is_passive and cle in c.effect_keys():
					trouve = true
			if not trouve:
				out.append("aucune carte de cet effet dans le deck du niveau")
		&"max_distinct_cast":
			var ids: Dictionary = {}
			for c: SpellCard in level.exploration_deck:
				if c != null and not c.is_passive:
					ids[c.id] = true
			if ids.size() <= _int(o, "count"):
				out.append("le deck ne compte que %d sorts differents" % ids.size())
	return out


## Toutes les especes que le niveau peut faire apparaitre : vagues, plus leurs
## divisions et invocations (un volant peut n arriver que par invocation).
static func level_enemies(level: LevelDef) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var pile: Array[EnemyDef] = []
	for w: WaveDef in level.waves:
		if w != null:
			pile.append_array(w.enemy_defs())
	while not pile.is_empty():
		var d: EnemyDef = pile.pop_back()
		if d == null or out.has(d):
			continue
		out.append(d)
		if d.split_into != null:
			pile.append(d.split_into)
		if d.summon_def != null:
			pile.append(d.summon_def)
	return out


## Volants que le niveau peut produire au plus. -1 = sans borne (un invocateur
## de volants en fabrique tant qu il vit). Les divisions sont suivies sur toute
## leur chaine.
static func flying_capacity(level: LevelDef) -> int:
	for d: EnemyDef in level_enemies(level):
		if d.summon_def != null and d.summon_def.flying and not d.summon_def.projectile:
			return -1
	var total: int = 0
	for w: WaveDef in level.waves:
		if w == null:
			continue
		for e: WaveEntry in w.entries:
			if e == null or e.enemy == null:
				continue
			total += e.count * maxi(1, e.enemy.swarm_count) * _flyers_from(e.enemy, 0)
	return total


## Volants produits par UN exemplaire de `d`, lui compris, divisions comprises.
static func _flyers_from(d: EnemyDef, profondeur: int) -> int:
	if d == null or profondeur > 8:
		return 0
	var n: int = 1 if (d.flying and not d.projectile) else 0
	if d.split_into != null and d.split_count > 0:
		n += d.split_count * _flyers_from(d.split_into, profondeur + 1)
	return n


static func _deck_count_tag(level: LevelDef, tag: int) -> int:
	var n: int = 0
	for c: SpellCard in level.exploration_deck:
		if c != null and not c.is_passive and c.tags.has(tag):
			n += 1
	return n
