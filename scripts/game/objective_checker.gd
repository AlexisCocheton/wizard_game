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
##   elem   = un tag qui est un vrai element (GameEnums.ELEMENTS : FIRE, WATER,
##            NATURE, WIND, LIGHTNING, ICE, ARCANE, POISON — vague 8)
##   effet  = cle d effet de EFFECT_PHRASES ci-dessous (celles qui ont un libelle)
##   carte  = id String d une SpellCard du catalogue (ContentDB), jamais un passif
##   monstre= id String d un EnemyDef du catalogue, jamais un projectile (une
##            boule de poison n est pas une espece : voir no_hit_from)
##   [x]    = parametre FACULTATIF (absent = "n importe lequel")
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
## | card_casts              | card:carte,            | la carte `card` (par id, tous exemplaires confondus) lancee    |
## |                         | count:int >= 1         | au moins count fois                                            |
## | no_card                 | card:carte             | la carte `card` n est JAMAIS lancee                            |
## | win_above_speed         | pct:int ]100, max[     | vitesse A LA VICTOIRE strictement au-dessus de pct %           |
## | kill_type_one_cast      | enemy:monstre,         | un meme LANCER tue au moins count monstres de l espece `enemy` |
## |                         | count:int >= 2         | (zones, poisons et allies de ce lancer compris : voir LANCER)  |
## | kill_type_with_card     | enemy:monstre,         | au moins count monstres de l espece `enemy` tues par la carte  |
## |                         | card:carte,            | `card`, tous lancers et exemplaires confondus (meme regle      |
## |                         | count:int >= 1         | d attribution que ci-dessus)                                   |
## | no_hit_from             | enemy:monstre          | aucun coup recu de l espece `enemy` (voir COUP RECU)           |
## | hit_from                | enemy:monstre          | au moins un coup recu de l espece `enemy`                      |
## | enemy_travel            | [enemy:monstre],       | un monstre (de l espece `enemy`, ou de n importe laquelle si   |
## |                         | distance:nombre        | absent) a parcouru au moins `distance` px de CHEMIN avant de   |
## |                         | ]0, 20 longueurs]      | mourir (voir CHEMIN). Libelle en longueurs de terrain.         |
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
## - card_casts / no_card visent une CARTE (son id), la ou same_card_casts compte
##   "n importe quel sort" et no_card_key une cle d EFFET partagee par plusieurs
##   cartes. "Jouer Fleche 6 fois" et "gagner sans Boule de feu" ne se disaient
##   pas avec ces deux-la.
## - win_above_speed est le miroir de win_below_speed : meme photo a la victoire.
##   100 est exclu parce qu un mage vivant est toujours au-dessus du plancher.
##
## LANCER (kill_type_one_cast, kill_type_with_card). Un lancer = UN passage dans
## EffectRegistry.cast(), qui lui donne un numero (CastContext.cast_id). Tout
## degat inflige pendant sa resolution lui est attribue, et ce que le lancer
## POSE emporte son numero : zone au sol, pluie de meteores, arbre empoisonne,
## ronces, allie invoque, allies d un autel. Une mort causee par une zone
## trois secondes plus tard appartient donc au lancer qui l a posee.
##   Pourquoi pas une fenetre de temps (comme multi_kill) : le co-auteur demande
##   "en UNE attaque" et "avec TELLE carte", ce qui est une question de source,
##   pas d horloge. Une zone qui tue sur la duree reste l attaque du joueur.
##   Consequence assumee : un objet PERMANENT (ronces, autel) est un seul lancer
##   de toute la partie. Le chantier de contenu doit donc eviter kill_type_one_cast
##   dans un niveau dont le deck pose un terrain permanent qui tue.
##   Ce qui n est PAS un lancer : les passifs (Combustion, Reaction en chaine,
##   Compagnon fidele), les renvois, et tout coup porte hors de ces chemins. Une
##   mort sans source ne compte pour aucune carte. "Debordement" resout la carte
##   deux fois : c est le MEME lancer.
##   Le coup de grace decide : un monstre entame par un sort puis acheve par un
##   autre appartient au second.
##
## COUP RECU (no_hit_from, hit_from). Tout ce qui fait baisser la jauge et que
## le jeu impute a un monstre (Battlefield.mage_hit) : contact, fleche, onde de
## choc, laser, sort vole, renvoi de garde. Par id d EnemyDef, pas par nom
## affiche. Les projectiles-monstres (boule de poison) comptent pour l espece
## qui les invoque (EnemyDef.summon_def) : "ne pas etre touche par le Planogo"
## doit inclure ses boules. Si deux especes invoquent le meme projectile, un
## coup de boule compte pour les deux (angle mort assume : aucun contenu ne le
## fait, et l alternative etait de marquer chaque boule a sa naissance).
##
## CHEMIN (enemy_travel). La distance que le monstre a reellement couverte, image
## par image, pendant SON deplacement : descente, detours autour des murs et de
## la riviere, zigzag, marche vers un arbre qui provoque, remontee par Volte-face
## et deplacement par le courant d une nappe. C est tout l interet avec les sorts
## de terrain : un mur bien pose allonge le chemin. Ne comptent PAS : les
## deplacements instantanes ou subis d un bloc (repousse, vortex, retour dans le
## temps de Chronos, vie supplementaire qui renvoie en haut), qui ne sont pas un
## chemin. Juge a la MORT du monstre (tue, pas arrive au mage). Le joueur lit des
## LONGUEURS DE TERRAIN : une longueur = la descente apparition -> mage
## (terrain_length()), "Faire marcher un monstre sur 3 longueurs de terrain".
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
	&"card_casts",
	&"no_card",
	&"win_above_speed",
	&"kill_type_one_cast",
	&"kill_type_with_card",
	&"no_hit_from",
	&"hit_from",
	&"enemy_travel",
]

const T_INT: String = "int"
const T_NUM: String = "nombre"
const T_TAG: String = "tag"
const T_ELEM: String = "elem"
const T_EFFECT: String = "effet"
const T_CARD: String = "carte"
const T_ENEMY: String = "monstre"

## Parametres FACULTATIFS par cle. Absent = "n importe lequel" ; present, il
## doit quand meme etre du bon type. Une liste a part plutot qu un type
## "optionnel" : le SCHEMA reste la liste complete de ce qu une cle accepte.
const OPTIONAL: Dictionary = {
	&"enemy_travel": ["enemy"],
}

## Plafond de enemy_travel, en longueurs de terrain. Au-dela ce n est plus un
## defi de placement mais une attente : il faudrait tenir un monstre en vie des
## minutes entieres.
const MAX_TRAVEL_LENGTHS: float = 20.0

## Les cles d effet qui peuvent TUER (magnitude > 0) : sert a l AUDIT de
## kill_type_with_card, une carte qui ne blesse personne ne peut rien achever.
## Un nouveau verbe de degats non range ici rendrait l objectif "impossible" et
## l AUDIT rougirait : l oubli se voit, il ne passe pas en silence.
const KILLING_EFFECTS: Array[StringName] = [
	&"damage_single", &"pierce_line", &"ground_zone", &"damage_per_enemy",
	&"knockback", &"meteor_storm", &"stun_zone", &"taunt_prop", &"place_terrain",
	&"summon_ally", &"poison_dot",
]

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
	&"card_casts": {"card": T_CARD, "count": T_INT},
	&"no_card": {"card": T_CARD},
	&"win_above_speed": {"pct": T_INT},
	&"kill_type_one_cast": {"enemy": T_ENEMY, "count": T_INT},
	&"kill_type_with_card": {"enemy": T_ENEMY, "card": T_CARD, "count": T_INT},
	&"no_hit_from": {"enemy": T_ENEMY},
	&"hit_from": {"enemy": T_ENEMY},
	&"enemy_travel": {"enemy": T_ENEMY, "distance": T_NUM},
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

## La meme interdiction dite en UN nom, pour le bandeau de combat ("Sans appat").
## La phrase complete tient dans l ecran de fin, pas dans le coin ou vit le
## bandeau : « Sans planter d appat : rate » debordait sur la tour du mage, alors
## que les autres libelles courts sont deja des noms (« Sans passif », « Sans
## renvoi »). Une cle absente d ici retombe sur sa phrase complete ; le test
## d emprise du bandeau mesure toutes les cles, il dira si elle deborde.
const EFFECT_SHORT: Dictionary = {
	&"build_wall": "mur",
	&"summon_ally": "allie",
	&"knockback": "repousser",
	&"vortex_pull": "vortex",
	&"stun_zone": "etourdir",
	&"taunt_prop": "appat",
	&"water_flood": "inonder",
	&"ground_zone": "zone au sol",
	&"pierce_line": "sort en ligne",
	&"meteor_storm": "meteores",
	&"slow_enemy_gauge": "ralentir",
	&"reverse_enemies": "faire reculer",
	&"draw_cards": "pioche bonus",
	&"double_cast": "double sort",
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


## Id de carte ou de monstre ecrit dans le parametre, &"" s il est absent.
static func _id(o: ObjectiveDef, name: String) -> StringName:
	var v: Variant = _param(o, name)
	if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
		return &""
	return StringName(v)


static func _optional(key: StringName, name: String) -> bool:
	return (OPTIONAL.get(key, []) as Array).has(name)


## Une longueur de terrain, en pixels : la descente de la ligne d apparition a
## la ligne du mage. C est l unite de enemy_travel cote joueur ; le chantier de
## contenu ecrit `distance = n * terrain_length()` pour demander n longueurs.
static func terrain_length() -> float:
	return GameConfig.MAGE_LINE_Y - GameConfig.SPAWN_LINE_Y


## Valeur entiere du tag nomme ("FIRE" -> DamageTag.FIRE), -1 si inconnu.
static func tag_from_name(name: Variant) -> int:
	if typeof(name) != TYPE_STRING and typeof(name) != TYPE_STRING_NAME:
		return -1
	return GameEnums.tag_from_name(String(name))


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
			if not _optional(o.check_key, nom):
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
		T_CARD:
			# Contre le CATALOGUE : un id mal orthographie ferait un objectif que
			# rien ne peut jamais mordre (no_card gratuit, card_casts impossible).
			if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
				return "id de carte attendu"
			var c: SpellCard = ContentDB.cards.get(StringName(v))
			if c == null:
				return "carte inconnue '%s'" % v
			if c.is_passive:
				return "'%s' est un passif : il s equipe, il ne se lance pas" % v
		T_ENEMY:
			if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
				return "id de monstre attendu"
			var d: EnemyDef = ContentDB.enemies.get(StringName(v))
			if d == null:
				return "monstre inconnu '%s'" % v
			# Un projectile n est ni tue (aucune mort notee) ni une espece que le
			# joueur reconnait : ses coups comptent pour celui qui l invoque.
			if d.projectile:
				return "'%s' est un projectile, viser l espece qui le lance" % v
	return ""


static func _element_names() -> String:
	var noms: PackedStringArray = []
	for t: int in GameEnums.ELEMENTS:
		# find_key et non keys()[t] : les valeurs de l enum sont ecrites a la main
		# depuis la vague 8 (voir GameEnums.DamageTag).
		noms.append(GameEnums.tag_key(t))
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
		&"element_casts", &"kill_flying", &"max_distinct_cast", &"card_casts", \
				&"kill_type_with_card":
			if _int(o, "count") < 1:
				return "count doit valoir au moins 1"
		&"kill_type_one_cast":
			# Un seul monstre d un seul sort, c est n importe quelle mort : "en une
			# attaque" ne veut dire quelque chose qu a partir de deux.
			if _int(o, "count") < 2:
				return "count doit valoir au moins 2"
		&"win_above_speed":
			var pct2: int = _int(o, "pct")
			if pct2 <= 100 or pct2 >= GameConfig.SPEED_MAX_PERCENT:
				return "pct doit etre dans ]100, %d[" % GameConfig.SPEED_MAX_PERCENT
		&"enemy_travel":
			var dist: float = _num(o, "distance")
			if dist <= 0.0 or dist > MAX_TRAVEL_LENGTHS * terrain_length():
				return "distance doit etre dans ]0, %s] px (%s longueurs de terrain)" \
					% [_fmt(MAX_TRAVEL_LENGTHS * terrain_length()), _fmt(MAX_TRAVEL_LENGTHS)]
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
		&"card_casts":
			return RunState.casts_of_id(_id(o, "card")) >= _int(o, "count")
		&"no_card":
			return RunState.casts_of_id(_id(o, "card")) == 0
		&"win_above_speed":
			return RunState.final_speed_percent() > _int(o, "pct")
		&"kill_type_one_cast":
			return RunState.best_kills_in_one_cast(_id(o, "enemy")) >= _int(o, "count")
		&"kill_type_with_card":
			return RunState.kills_with_card(_id(o, "card"), _id(o, "enemy")) \
				>= _int(o, "count")
		&"no_hit_from":
			return RunState.hits_from_enemy(_id(o, "enemy")) == 0
		&"hit_from":
			return RunState.hits_from_enemy(_id(o, "enemy")) >= 1
		&"enemy_travel":
			# Seuls les monstres TUES comptent : un monstre arrive au mage n a pas
			# fini son chemin, il a fini le joueur.
			return RunState.travel_record_of(_id(o, "enemy")) >= _num(o, "distance")
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
		&"no_card_key":
			var k: StringName = StringName(_param(o, "key"))
			return "Sans %s" % EFFECT_SHORT.get(k, EFFECT_PHRASES[k])
		&"no_card_tag":
			# Le nom seul, comme « Sans passif » : « Sans sort de foudre : rate » ne
			# tenait pas entre la tour du mage et le bord de l ecran.
			return "Sans %s" % _tag_short(tag_from_name(_param(o, "tag")))
		&"element_casts":
			return "Sorts %s" % _of_tag(tag_from_name(_param(o, "element")), true)
		&"kill_flying": return "Volants"
		&"boss_quick_after_revive": return "Releve acheve"
		&"never_hit_reflect": return "Sans renvoi"
		&"no_enemy_past": return "Ligne tenue"
		&"win_under_time": return "Chrono"
		&"max_distinct_cast": return "Sorts differents"
		&"no_passive": return "Sans passif"
		# Un ou deux mots, SANS le nom de la carte ou du monstre : « Sans Totem de
		# coeur-de-bois : rate » ne tient pas entre la tour et le bord. Le nom se
		# lit au briefing et a la victoire (label()), le bandeau dit ou on en est.
		&"card_casts": return "Sort impose"
		&"no_card": return "Sort interdit"
		&"win_above_speed": return "Plus de %d %%" % _int(o, "pct")
		&"kill_type_one_cast": return "Un seul sort"
		&"kill_type_with_card": return "Chasse"
		&"no_hit_from": return "Esquive"
		&"hit_from": return "Coup subi"
		&"enemy_travel": return "Longue marche"
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
		&"card_casts":
			return {"current": RunState.casts_of_id(_id(o, "card")), "target": _int(o, "count"),
				"time": false}
		&"kill_type_one_cast":
			return {"current": RunState.best_kills_in_one_cast(_id(o, "enemy")),
				"target": _int(o, "count"), "time": false}
		&"kill_type_with_card":
			return {"current": RunState.kills_with_card(_id(o, "card"), _id(o, "enemy")),
				"target": _int(o, "count"), "time": false}
		&"hit_from":
			# Borne a 1 : « Coup subi 3/1 » se lirait comme une erreur.
			return {"current": mini(RunState.hits_from_enemy(_id(o, "enemy")), 1),
				"target": 1, "time": false}
		&"enemy_travel":
			# En POURCENT de la distance demandee : le bandeau ecrit des entiers, et
			# « 1843/4140 » (des pixels) ne dit rien au joueur. Le meilleur monstre
			# VIVANT compte dans l affichage — c est lui qu il faut garder en vie
			# puis achever — mais seule une mort valide (evaluate).
			var meilleur: float = maxf(RunState.travel_record_of(_id(o, "enemy")),
				RunState.travel_live_of(_id(o, "enemy")))
			return {"current": int(floor(100.0 * meilleur / maxf(_num(o, "distance"), 1.0))),
				"target": 100, "time": false}
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
		# Un lancer et un coup recu ne s effacent jamais : irreversibles.
		&"no_card":
			return RunState.casts_of_id(_id(o, "card")) > 0
		&"no_hit_from":
			return RunState.hits_from_enemy(_id(o, "enemy")) > 0
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
		&"card_casts":
			return "Lancer %d fois %s" % [_int(o, "count"), _card_name(_id(o, "card"))]
		&"no_card":
			return "Gagner sans lancer %s" % _card_name(_id(o, "card"))
		&"win_above_speed":
			return "Gagner avec plus de %d %% de vitesse" % _int(o, "pct")
		# « <Monstre> : ... » : le nom en tete evite d accorder un article et un
		# pluriel a un nom propre (« une Sorciere », « 4 Oiseaux mirage »).
		&"kill_type_one_cast":
			return "%s : en tuer %d d un seul sort" % [_enemy_name(_id(o, "enemy")),
				_int(o, "count")]
		&"kill_type_with_card":
			return "%s : en tuer %d avec %s" % [_enemy_name(_id(o, "enemy")),
				_int(o, "count"), _card_name(_id(o, "card"))]
		&"no_hit_from":
			return "%s : gagner sans en etre touche" % _enemy_name(_id(o, "enemy"))
		&"hit_from":
			return "%s : gagner apres en avoir ete touche" % _enemy_name(_id(o, "enemy"))
		&"enemy_travel":
			var longueurs: String = _lengths(_num(o, "distance"))
			var qui: StringName = _id(o, "enemy")
			if qui == &"":
				return "Faire marcher un monstre sur %s" % longueurs
			return "%s : en faire marcher un sur %s" % [_enemy_name(qui), longueurs]
	return o.description


static func _card_name(id: StringName) -> String:
	var c: SpellCard = ContentDB.cards.get(id)
	return c.display_name if c != null and c.display_name != "" else String(id)


static func _enemy_name(id: StringName) -> String:
	var d: EnemyDef = ContentDB.enemies.get(id)
	return d.display_name if d != null and d.display_name != "" else String(id)


## 4140 px -> "3 longueurs de terrain", 2070 -> "1,5 longueur de terrain".
## Au dixieme : "2,17 longueurs" ne se lit pas mieux que "2,2".
static func _lengths(px: float) -> String:
	var n: float = snappedf(px / terrain_length(), 0.1)
	return "%s longueur%s de terrain" % [_fmt(n), "s" if n >= 2.0 else ""]


## "de feu", "d arcane", "de glace" : le complement d un sort de cet element.
## Nom d un tag pour le bandeau : celui de GameEnums, sauf le seul trop long.
static func _tag_short(tag: int) -> String:
	if tag == GameEnums.DamageTag.SLOW:
		return "ralentir"
	return GameEnums.tag_name(tag)


static func _of_tag(tag: int, _pluriel: bool) -> String:
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
		&"card_casts":
			if not card_obtainable(level, _id(o, "card")):
				out.append("la carte %s n est ni dans le deck ni dans les cartes de niveau"
					% _id(o, "card"))
		&"kill_type_one_cast", &"kill_type_with_card":
			var qui: StringName = _id(o, "enemy")
			if not monstres.any(func(d: EnemyDef) -> bool: return d.id == qui):
				out.append("le monstre %s n apparait pas dans ce niveau" % qui)
			else:
				var cap: int = type_capacity(level, qui)
				if cap >= 0 and cap < _int(o, "count"):
					out.append("%d %s au plus pour %d demandes" % [cap, qui, _int(o, "count")])
			if o.check_key == &"kill_type_with_card":
				var carte: StringName = _id(o, "card")
				if not card_obtainable(level, carte):
					out.append("la carte %s n est ni dans le deck ni dans les cartes de niveau"
						% carte)
				elif not card_can_kill(ContentDB.cards.get(carte), ContentDB.enemies.get(qui)):
					out.append("la carte %s ne peut pas tuer %s (aucun degat, ou immunite)"
						% [carte, qui])
		&"hit_from":
			var qui2: StringName = _id(o, "enemy")
			if not monstres.any(func(d: EnemyDef) -> bool: return d.id == qui2):
				out.append("le monstre %s n apparait pas dans ce niveau" % qui2)
			elif not can_hurt_mage(ContentDB.enemies.get(qui2)):
				out.append("le monstre %s ne touche jamais le mage" % qui2)
		&"enemy_travel":
			var qui3: StringName = _id(o, "enemy")
			if qui3 != &"" and not monstres.any(func(d: EnemyDef) -> bool: return d.id == qui3):
				out.append("le monstre %s n apparait pas dans ce niveau" % qui3)
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
		&"no_card":
			if not card_obtainable(level, _id(o, "card")):
				out.append("la carte %s ne peut pas etre jouee dans ce niveau" % _id(o, "card"))
		&"no_hit_from":
			var qui: StringName = _id(o, "enemy")
			if not level_enemies(level).any(func(d: EnemyDef) -> bool: return d.id == qui):
				out.append("le monstre %s n apparait pas dans ce niveau" % qui)
			elif not can_hurt_mage(ContentDB.enemies.get(qui)):
				out.append("le monstre %s ne touche jamais le mage" % qui)
	return out


## La carte peut-elle se retrouver en main dans ce niveau ? Deck du niveau, plus
## le pool de montee de niveau `LevelDef.levelup_cards` s il existe.
##
## Le champ est ajoute par un autre chantier (progression) : il est lu par NOM
## (`get`) pour que ce fichier compile avec ou sans lui. Tant qu il n existe pas,
## le deck seul fait foi — les offres de montee de niveau piochent alors dans
## tout le catalogue, et un objectif qui reposerait sur elles serait un pari, pas
## une etoile garantie.
static func card_obtainable(level: LevelDef, card_id: StringName) -> bool:
	if level == null or card_id == &"":
		return false
	for c: SpellCard in level.exploration_deck:
		if c != null and c.id == card_id:
			return true
	var pool: Variant = level.get("levelup_cards")
	if pool is Array:
		for c in pool:
			if c is SpellCard and (c as SpellCard).id == card_id:
				return true
	return false


## La carte peut-elle achever ce monstre ? Il lui faut un effet qui blesse
## (KILLING_EFFECTS avec une magnitude, ou un generateur d allies), et que le
## monstre n y soit pas totalement insensible. Les allies frappent en SUMMON,
## qu aucune resistance elementaire ne couvre : leur carte peut toujours tuer.
static func card_can_kill(card: SpellCard, def: EnemyDef) -> bool:
	if card == null or def == null:
		return false
	for spec: EffectSpec in card.effects:
		if spec == null:
			continue
		var allies: bool = (spec.key == &"summon_ally" and spec.magnitude > 0.0) \
			or (float(spec.get_param(&"summon_every", 0.0)) > 0.0
				and float(spec.get_param(&"ally_damage", 0.0)) > 0.0)
		# Vague 8 : un allie frappe a l element de sa carte, il bute donc lui
		# aussi sur une immunite.
		if allies and def.resistance_to_tags(card.combat_tags()) > 0.0:
			return true
		if spec.key in KILLING_EFFECTS and spec.magnitude > 0.0 \
				and def.resistance_to_tags(card.combat_tags()) > 0.0:
			return true
	return false


## Le monstre peut-il faire baisser la jauge ? Contact (s il avance et ne
## s arrete pas a une ligne de tir), fleche, onde, laser, vol de sort, garde de
## renvoi, ou un projectile-monstre qu il invoque et qui, lui, touche.
static func can_hurt_mage(def: EnemyDef, profondeur: int = 0) -> bool:
	if def == null or profondeur > 4:
		return false
	if def.base_speed > 0.0 and def.keeps_distance_at <= 0.0:
		return true
	if def.shoot_interval > 0.0 and def.shot_damage > 0:
		return true
	if def.shockwave_interval > 0.0 and def.shockwave_radius > 0.0 and def.shockwave_damage > 0:
		return true
	if def.laser_damage > 0 or def.steal_interval > 0.0:
		return true
	if def.reflect_pct > 0.0 and def.reflect_window > 0.0 and def.reflect_interval > 0.0:
		return true
	return def.summon_def != null and def.summon_def.projectile \
		and can_hurt_mage(def.summon_def, profondeur + 1)


## Exemplaires de l espece `id` que le niveau peut produire au plus. -1 = sans
## borne (un monstre du niveau l invoque tant qu il vit). Divisions et
## renaissances suivies sur toute leur chaine, comme flying_capacity.
static func type_capacity(level: LevelDef, id: StringName) -> int:
	for d: EnemyDef in level_enemies(level):
		if d.summon_def != null and d.summon_def.id == id:
			return -1
	var total: int = 0
	for w: WaveDef in level.waves:
		if w == null:
			continue
		for e: WaveEntry in w.entries:
			if e == null or e.enemy == null:
				continue
			total += e.count * maxi(1, e.enemy.swarm_count) * _type_from(e.enemy, id, 0)
	return total


## Exemplaires de `id` produits par UN exemplaire de `d`, lui compris.
static func _type_from(d: EnemyDef, id: StringName, profondeur: int) -> int:
	if d == null or profondeur > 8:
		return 0
	var n: int = 1 if d.id == id else 0
	if d.split_into != null and d.split_count > 0:
		n += d.split_count * _type_from(d.split_into, id, profondeur + 1)
	if d.rebirth_def != null and d.rebirth_count > 0:
		n += d.rebirth_count * _type_from(d.rebirth_def, id, profondeur + 1)
	return n


## Toutes les especes que le niveau peut faire apparaitre : vagues, plus leurs
## divisions, invocations et renaissances (un volant peut n arriver que par
## invocation, un monstre vise par un objectif que par renaissance).
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
		if d.rebirth_def != null:
			pile.append(d.rebirth_def)
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
		if c != null and not c.is_passive and c.has_tag(tag):
			n += 1
	return n
