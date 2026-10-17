class_name ThreatLore
extends RefCounted
## CE QU UN MONSTRE FAIT, ET CE QUI Y REPOND (vague 10).
##
## Deux ecrans en ont besoin : le BRIEFING (une ligne de mecanique par monstre)
## et le BILAN de fin de niveau (un conseil contre le monstre qui a coute le
## plus de vitesse). Les deux lisent les memes TRAITS, tires des CHAMPS
## d EnemyDef (comme BestiaryLore : le `kind` seul mentirait sur un monstre qui
## cumule), dans le meme ordre d importance. La fiche du bestiaire garde ses
## phrases longues ; ici, des mots courts qui se lisent entre deux vagues.
##
## LES REGLES DU CONSEIL (demande du co-auteur du 14/10 : « donne un conseil pour
## le monstre qui a fait le plus de degats : il est faible a tel element, ou tu
## devrais les tuer en premier, ou trouve un sort de zone »). Deux lignes au plus.
##
##   1. ELEMENT. Sa plus forte FAIBLESSE parmi les huit elements, et une carte de
##      cet element qui fait des degats : « Craint le feu (+58 %) : Boule de
##      feu ». Sans faiblesse, sa plus forte RESISTANCE, pour dire quoi eviter.
##      Neutre partout : pas de ligne (rien d utile a dire).
##   2. MECANIQUE. Le PREMIER trait de `traits()` qu il porte, sa phrase, et une
##      carte de la REPONSE associee (`REPONSE_DU_TRAIT`). Les reponses suivent la
##      table des recompenses coherentes de la vague 10 : tireur -> mur, nuee ->
##      zone, rapide -> ralentir, colosse -> doubleur, deplacement bizarre ->
##      controle, lent -> duree, invocateur -> duree, bloqueur de main -> pioche,
##      protecteur -> dissipation. Un monstre sans trait : « garde un sort pret ».
##
##   LA CARTE vient du DECK de la partie d abord (le joueur l a sous la main),
##   sinon du LIVRE (cartes obtenues), jamais d ailleurs : on ne conseille pas une
##   carte que le joueur ne possede pas. Aucune ne repond : la phrase seule.
##   A egalite, la plus rare, puis le nom (un conseil ne depend pas du melange).
##
## Tout est STATIQUE et sans etat : les tests lisent les regles sans ecran.

## Vitesse de base (px/s a x1) a partir de laquelle un monstre est RAPIDE, et
## sous laquelle il est LENT. Les memes seuils que BestiaryLore.speed_word
## (« vive », « lente ») : la fiche et le conseil disent la meme chose.
const RAPIDE_PX: float = 75.0
const LENT_PX: float = 35.0
## Temps d incantation HORS COMBAT (CardView.menu_cast_seconds) au-dessous
## duquel un sort de degats est une reponse RAPIDE.
const RAPIDE_CAST_S: float = 1.5
## Duree (s) a partir de laquelle une zone de degats est un degat SUR LA DUREE.
const DUREE_MIN_S: float = 4.0

## L ORDRE D IMPORTANCE des traits : ce qui change une REGLE (la main, la magie,
## la protection des autres) d abord, puis ce qui change la CIBLE, puis le
## mouvement, puis la masse. Le conseil lit le premier ; le briefing les deux
## premiers. Verrouille par test_screens_w10 (un monstre, un trait attendu).
##
## VAGUE 10 (chantier B2) : l ECHEANCE (Chronos) change une regle (ne pas frapper
## coute), elle vient avec le sommeil ; la GARDE LEVEE (Gardien d ossements) avec
## le renvoi, dont elle reprend le cycle.
const TRAITS: Array[StringName] = [
	&"protege", &"petrifie", &"endort", &"echeance", &"vole_carte", &"invoque", &"soigne",
	&"riposte", &"renvoi", &"garde", &"compte_coups", &"remonte", &"onde", &"tire",
	&"nuee", &"divise", &"jumeaux", &"revient", &"reanime", &"devore", &"brise",
	&"meneur", &"vole", &"enrage", &"miroir", &"rapide", &"imprevisible",
	&"cameleon", &"colosse", &"immobile", &"lent",
]

## Les REPONSES, c est-a-dire des familles de cartes reconnues a leurs DONNEES
## (cles d effet, element, ciblage, duree) par `answers_of`.
const ZONE: StringName = &"zone"
const MUR: StringName = &"mur"
const RALENTIR: StringName = &"ralentir"
const DISSIPER: StringName = &"dissiper"
const PIOCHE: StringName = &"pioche"
const DUREE: StringName = &"duree"
const GROS_SORT: StringName = &"gros_sort"
const CONTROLE: StringName = &"controle"
const RAPIDE: StringName = &"rapide"
const CIBLE: StringName = &"cible"
## Pas de reponse particuliere : n importe quel sort de degats.
const DEGATS: StringName = &"degats"

## Trait -> reponse. Une ligne par trait de TRAITS (verifie par le test).
const REPONSE_DU_TRAIT: Dictionary = {
	&"protege": DISSIPER, &"petrifie": PIOCHE, &"endort": RAPIDE, &"echeance": RAPIDE,
	&"garde": DUREE,
	&"vole_carte": RAPIDE, &"invoque": DUREE, &"soigne": CIBLE,
	&"riposte": GROS_SORT, &"renvoi": GROS_SORT, &"compte_coups": GROS_SORT,
	&"remonte": GROS_SORT, &"onde": CIBLE, &"tire": MUR, &"nuee": ZONE,
	&"divise": ZONE, &"jumeaux": ZONE, &"revient": DUREE, &"reanime": CIBLE,
	&"devore": GROS_SORT, &"brise": CONTROLE, &"meneur": CIBLE, &"vole": CIBLE,
	&"enrage": RALENTIR, &"miroir": RALENTIR, &"rapide": RALENTIR,
	&"imprevisible": CONTROLE, &"cameleon": RAPIDE, &"colosse": GROS_SORT,
	&"immobile": CIBLE, &"lent": DUREE,
}

## Ce que dit la reponse, apres la phrase du trait : la CARTE suit.
const PHRASE_DE_REPONSE: Dictionary = {
	ZONE: "un sort de zone", MUR: "un mur arrete ses tirs",
	RALENTIR: "ralentis-le", DISSIPER: "une dissipation eteint son aura",
	PIOCHE: "pioche pour garder des sorts", DUREE: "un degat sur la duree",
	GROS_SORT: "double ton prochain sort", CONTROLE: "un sort de controle le fixe",
	RAPIDE: "un sort rapide", CIBLE: "frappe-le directement",
	DEGATS: "garde un sort pret pour lui",
}

# Familles de cartes, par cle d effet.
## Les effets qui BLESSENT un monstre (magnitude = des degats). SpellCard.has_damage
## ne suffit pas : la magnitude y sert aussi de vitesse d aspiration, de soin, de
## nombre de cartes ou d XP (mesure : 9 sorts utilitaires y repondaient vrai).
const _DEGATS_KEYS: Array[StringName] = [
	&"damage_single", &"pierce_line", &"ground_zone", &"meteor_storm",
	&"damage_per_enemy", &"poison_dot", &"knockback", &"stun_zone", &"place_terrain",
	&"summon_ally",
]
const _ZONE_KEYS: Array[StringName] = [
	&"ground_zone", &"meteor_storm", &"damage_per_enemy", &"pierce_line",
]
const _MUR_KEYS: Array[StringName] = [&"build_wall"]
const _RALENTIR_KEYS: Array[StringName] = [&"slow_enemy_gauge", &"stun_zone"]
const _DISSIPER_KEYS: Array[StringName] = [&"dispel_zone"]
const _PIOCHE_KEYS: Array[StringName] = [
	&"draw_cards", &"discard_draw", &"draw_boost", &"retain_next",
]
const _GROS_SORT_KEYS: Array[StringName] = [&"empower_next", &"double_cast"]
const _CONTROLE_KEYS: Array[StringName] = [
	&"vortex_pull", &"knockback", &"reverse_enemies", &"stun_zone", &"taunt_prop",
]


# --- LES TRAITS ---------------------------------------------------------------

## Les traits du monstre, dans l ordre de TRAITS. Vide = il descend sans ruse.
static func traits(def: EnemyDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if def == null:
		return out
	for t in TRAITS:
		if has_trait(def, t):
			out.append(t)
	return out


static func has_trait(def: EnemyDef, t: StringName) -> bool:
	if def == null:
		return false
	match t:
		&"protege": return def.aura_shield_radius > 0.0
		&"petrifie": return def.blocks_cards > 0
		&"endort": return def.sleep_interval > 0.0
		&"echeance": return def.has_deadline()
		&"garde": return def.guard_block_pct > 0.0 and def.reflect_pct <= 0.0 and def.reflect_window > 0.0
		&"vole_carte": return def.steal_interval > 0.0
		&"invoque":
			return def.summon_interval > 0.0 and def.summon_def != null \
				and not def.summon_def.projectile
		&"soigne": return def.heal_per_second > 0.0
		&"riposte": return def.laser_damage > 0
		&"renvoi": return def.reflect_pct > 0.0 and def.reflect_window > 0.0
		&"compte_coups": return def.hits_immune > 0
		&"remonte": return def.rewind_interval > 0.0 and def.rewind_seconds > 0.0
		&"onde":
			return def.shockwave_interval > 0.0 and def.shockwave_radius > 0.0 \
				and def.shockwave_damage > 0
		&"tire":
			return (def.shoot_interval > 0.0 and def.shot_damage > 0) \
				or (def.summon_def != null and def.summon_def.projectile)
		&"nuee": return def.swarm_count > 1
		&"divise": return def.split_into != null and def.split_count > 0
		&"jumeaux": return def.twin_group != &""
		&"revient":
			return def.extra_lives > 0 or def.revive_hp_pct > 0.0 \
				or (def.rebirth_def != null and def.rebirth_count > 0)
		&"reanime": return def.reanimate_max > 0 and def.reanimate_radius > 0.0
		&"devore": return def.devours
		&"brise": return def.terrain_break_interval > 0.0
		&"meneur": return def.buff_speed_pct > 0.0
		&"vole": return def.flying and not def.projectile
		&"enrage": return def.enrage_speed_pct > 0.0
		&"miroir": return def.mirror_speed_ref > 0
		&"rapide":
			return def.base_speed >= RAPIDE_PX or def.burst_move \
				or def.kind == GameEnums.EnemyKind.FAST \
				or def.kind == GameEnums.EnemyKind.BURSTER
		&"imprevisible":
			return def.move_pattern != EnemyDef.MovePattern.STRAIGHT \
				or def.wave_amplitude > 0.0 or def.phase_interval > 0.0 \
				or def.dodge_chance > 0.0 or def.entry_side
		&"cameleon": return def.chameleon_interval > 0.0
		&"colosse":
			return def.kind == GameEnums.EnemyKind.TANK or def.first_hit_shield \
				or def.parts_count > 0
		&"immobile": return def.base_speed <= 0.0
		&"lent": return def.base_speed > 0.0 and def.base_speed < LENT_PX
	return false


## Le trait en quelques mots, pour la ligne du briefing (« tire de loin »).
static func trait_text(t: StringName, def: EnemyDef) -> String:
	match t:
		&"protege": return "protege les monstres proches"
		&"petrifie":
			return "petrifie %s de ta main" % ("une carte" if def.blocks_cards <= 1
				else "%d cartes" % def.blocks_cards)
		&"endort": return "son sommeil coupe ta magie"
		&"echeance":
			return ("se plante : frappe-le vite" if def.deadline_penalty > 0
				else "se plante, puis s emballe")
		&"garde": return "leve sa garde : les coups glissent"
		&"vole_carte": return "vole ton sort le plus long"
		&"invoque": return "appelle des renforts (%s)" % def.summon_def.display_name
		&"soigne": return "soigne les autres"
		&"riposte": return "riposte au laser"
		&"renvoi": return "renvoie tes degats pendant sa garde"
		&"compte_coups": return "ignore ses %d premiers coups" % def.hits_immune
		&"remonte": return "revient dans le temps"
		&"onde": return "frappe le sol en onde"
		&"tire": return "tire de loin"
		&"nuee": return "arrive en groupe de %d" % def.swarm_count
		&"divise": return "se divise a sa mort"
		&"jumeaux": return "se releve tant que son jumeau tient"
		&"revient": return "revient apres sa mort"
		&"reanime": return "releve les morts"
		&"devore": return "gobe les plus faibles"
		&"brise": return "brise ton decor"
		&"meneur": return "accelere les autres"
		&"vole": return "vole au-dessus des murs"
		&"enrage": return "accelere quand on le frappe"
		&"miroir": return "suit ta vitesse"
		&"rapide": return "fonce par a-coups" if def.burst_move else "rapide"
		&"imprevisible": return _mouvement(def)
		&"cameleon": return "change d element"
		&"colosse":
			if def.parts_count > 0:
				return "a %d parties a briser" % def.parts_count
			if def.first_hit_shield and def.shield_regen > 0.0:
				return "son armure se referme"
			return "encaisse le premier coup" if def.first_hit_shield else "encaisse beaucoup"
		&"immobile": return "n avance jamais"
		&"lent": return "lent"
	return ""


static func _mouvement(def: EnemyDef) -> String:
	match def.move_pattern:
		EnemyDef.MovePattern.ZIGZAG: return "avance en zigzag"
		EnemyDef.MovePattern.BOUNCE: return "rebondit d un bord a l autre"
		EnemyDef.MovePattern.HOP: return "saute de colonne en colonne"
		EnemyDef.MovePattern.SPIRAL: return "descend en spirale"
	if def.dodge_chance > 0.0:
		return "esquive %d %% des sorts" % int(round(def.dodge_chance * 100.0))
	if def.phase_interval > 0.0:
		return "disparait par moments"
	if def.wave_amplitude > 0.0:
		return "ondule"
	return "entre par le cote"


## LA LIGNE DU BRIEFING : les `combien` premiers traits, la premiere lettre en
## majuscule. Un monstre sans trait le dit, une ligne vide se lirait comme un oubli.
static func mechanic_line(def: EnemyDef, combien: int = 2) -> String:
	var mots: PackedStringArray = []
	for t in traits(def):
		if mots.size() >= combien:
			break
		mots.append(trait_text(t, def))
	var s: String = ", ".join(mots) if not mots.is_empty() else "descend tout droit, sans ruse"
	return s.substr(0, 1).to_upper() + s.substr(1)


## La phrase de CONSEIL d un trait, sans la carte. Ecrite au tutoiement, comme
## le reste des ecrans de fin (« garde un sort pour... »).
static func trait_advice(t: StringName, def: EnemyDef) -> String:
	match t:
		&"protege": return "Protege les monstres autour de lui : abats-le d abord"
		&"petrifie": return "Son regard fige tes cartes : tue-le en premier pour les liberer"
		&"endort": return "Son sommeil t empeche de lancer : tue-le pendant qu il veille"
		&"echeance":
			if def.deadline_penalty > 0:
				return "Quand il se plante, frappe-le avant la fin du sablier : sinon tu perds de la vitesse"
			return "Quand il se plante, frappe-le : sinon il repart plus vite"
		&"garde": return "Sa garde amortit les coups, pas les zones ni le poison"
		&"vole_carte": return "Il vole tes sorts les plus longs : tue-le avant qu il les lance"
		&"invoque":
			return "Appelle des renforts (%s) : tue-le en premier pour couper le flux" \
				% def.summon_def.display_name
		&"soigne": return "Soigne les autres monstres : tue-le en premier"
		&"riposte": return "Riposte a chaque coup : un gros sort vaut mieux que dix petits"
		&"renvoi": return "Sa garde te renvoie tes degats : frappe entre deux gardes"
		&"compte_coups": return "Ignore ses premiers coups, quelle que soit leur force"
		&"remonte": return "Efface les degats d avant son retour : frappe juste apres"
		&"onde": return "Son onde frappe a distance : va le chercher"
		&"tire": return "Tire de loin : tue-le en premier"
		&"nuee": return "Arrive en groupe : prends-les tous d un coup"
		&"divise": return "Se divise en mourant : finis les morceaux d un coup"
		&"jumeaux": return "Se releve tant que son jumeau tient : tue-les ensemble"
		&"revient": return "Revient apres sa mort : use-le sur tout le chemin"
		&"reanime": return "Releve les morts autour de lui : tue-le en premier"
		&"devore": return "Grossit en mangeant les autres : tue-le avant qu il mange"
		&"brise": return "Brise tes murs et tes arbres : arrete-le pendant son geste"
		&"meneur": return "Accelere les autres : tue-le en premier"
		&"vole": return "Vole : aucun mur ne l arrete"
		&"enrage": return "Accelere quand on le frappe : ne le laisse pas s emballer"
		&"miroir": return "Va aussi vite que toi"
		&"rapide": return "Rapide : il t atteint avant tes sorts"
		&"imprevisible": return "Bouge de facon imprevisible : difficile a viser"
		&"cameleon": return "Change d element : frappe avec celui qu il craint maintenant"
		&"colosse": return "Encaisse beaucoup"
		&"immobile": return "N avance jamais : il faut aller le chercher"
		&"lent": return "Lent : il te laisse le temps de l user"
	return "T a coute le plus de vitesse"


# --- LES REPONSES (familles de cartes) -----------------------------------------

## Les familles de reponse auxquelles une carte appartient, lues dans ses DONNEES.
## Un passif ne repond a rien ici : il ne se joue pas contre un monstre.
static func answers_of(card: SpellCard) -> Array[StringName]:
	var out: Array[StringName] = []
	if card == null or card.is_passive:
		return out
	var cles: Array[StringName] = card.effect_keys()
	var degats: bool = deals_damage(card)
	if degats:
		out.append(DEGATS)
	for e: EffectSpec in card.effects:
		if e == null:
			continue
		if e.key in _ZONE_KEYS and e.magnitude > 0.0 and not out.has(ZONE):
			out.append(ZONE)
		var duree_zone: bool = e.key in _ZONE_KEYS and e.magnitude > 0.0 \
			and e.duration >= DUREE_MIN_S
		if (e.key == &"poison_dot" or duree_zone) and not out.has(DUREE):
			out.append(DUREE)
	if _any_in(cles, _MUR_KEYS):
		out.append(MUR)
	if card.has_tag(GameEnums.DamageTag.SLOW) or _any_in(cles, _RALENTIR_KEYS):
		out.append(RALENTIR)
	if _any_in(cles, _DISSIPER_KEYS):
		out.append(DISSIPER)
	if _any_in(cles, _PIOCHE_KEYS):
		out.append(PIOCHE)
	if _any_in(cles, _GROS_SORT_KEYS):
		out.append(GROS_SORT)
	if _any_in(cles, _CONTROLE_KEYS):
		out.append(CONTROLE)
	if degats and CardView.menu_cast_seconds(card) <= RAPIDE_CAST_S:
		out.append(RAPIDE)
	if degats and card.targeting == GameEnums.Targeting.TARGET:
		out.append(CIBLE)
	return out


## Le sort BLESSE-t-il un monstre ? Un de ses effets de degats a une magnitude.
static func deals_damage(card: SpellCard) -> bool:
	if card == null or card.is_passive:
		return false
	for e: EffectSpec in card.effects:
		if e != null and e.key in _DEGATS_KEYS and e.magnitude > 0.0:
			return true
	return false


static func _any_in(cles: Array[StringName], famille: Array[StringName]) -> bool:
	for k in cles:
		if k in famille:
			return true
	return false


# --- LE CONSEIL -----------------------------------------------------------------

## La plus forte faiblesse du monstre parmi les huit elements : {tag, mult}, vide
## s il ne craint rien. A egalite, l ordre d affichage des elements.
static func strongest_weakness(def: EnemyDef) -> Dictionary:
	var best: Dictionary = {}
	if def == null:
		return best
	for tag in GameEnums.ELEMENTS:
		var r: float = def.resistance_to(tag)
		if r > 1.0 and (best.is_empty() or r > float(best["mult"])):
			best = {"tag": tag, "mult": r}
	return best


## Sa plus forte resistance (immunite comprise) : {tag, mult}, vide si aucune.
static func strongest_resistance(def: EnemyDef) -> Dictionary:
	var best: Dictionary = {}
	if def == null:
		return best
	for tag in GameEnums.ELEMENTS:
		var r: float = def.resistance_to(tag)
		if r < 1.0 and (best.is_empty() or r < float(best["mult"])):
			best = {"tag": tag, "mult": r}
	return best


## La carte du joueur qui repond : d abord le DECK, puis le LIVRE. `filtre`
## decide si une carte convient. {card, from_deck} ou vide.
static func pick_card(deck: Array, book: Array, filtre: Callable) -> Dictionary:
	for source in [[deck, true], [book, false]]:
		var meilleure: SpellCard = null
		for c in source[0]:
			var carte: SpellCard = c as SpellCard
			if carte == null or carte.is_passive or not bool(filtre.call(carte)):
				continue
			if meilleure == null or _avant(carte, meilleure):
				meilleure = carte
		if meilleure != null:
			return {"card": meilleure, "from_deck": source[1]}
	return {}


## Ordre stable entre deux cartes qui repondent : la plus rare, puis le nom.
static func _avant(a: SpellCard, b: SpellCard) -> bool:
	if a.rarity != b.rarity:
		return a.rarity > b.rarity
	return String(a.display_name) < String(b.display_name)


## LE CONSEIL contre `def` : une ou deux lignes (voir l en-tete).
##   [{kind: &"element" | &"mecanique", text, tag (-1 hors element), mult,
##     trait, answer, card (SpellCard ou null), from_deck}]
## `text` est la phrase entiere, carte comprise : l ecran la recompose en
## couleurs, les tests la lisent telle quelle.
static func advice(def: EnemyDef, deck: Array, book: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null:
		return out
	# 1. L ELEMENT.
	var faible: Dictionary = strongest_weakness(def)
	if not faible.is_empty():
		var tag: int = int(faible["tag"])
		var pris: Dictionary = pick_card(deck, book, func(c: SpellCard) -> bool:
			return c.main_element() == tag and deals_damage(c))
		var phrase: String = "Craint %s (%s)" % [_le(tag), ElementIcons.percent_text(float(faible["mult"]))]
		out.append(_ligne(&"element", phrase, tag, float(faible["mult"]), &"", &"", pris))
	else:
		var fort: Dictionary = strongest_resistance(def)
		if not fort.is_empty():
			var tag_r: int = int(fort["tag"])
			var mult_r: float = float(fort["mult"])
			var phrase_r: String = ("Immunise %s : prends un autre element" % _au(tag_r)) \
				if mult_r <= 0.0 else ("Resiste %s (%s) : prends un autre element"
					% [_au(tag_r), ElementIcons.percent_text(mult_r)])
			out.append(_ligne(&"element", phrase_r, tag_r, mult_r, &"", &"", {}))
	# 2. LA MECANIQUE.
	var ses_traits: Array[StringName] = traits(def)
	var t: StringName = ses_traits[0] if not ses_traits.is_empty() else &""
	var reponse: StringName = REPONSE_DU_TRAIT.get(t, DEGATS)
	var carte: Dictionary = pick_card(deck, book, func(c: SpellCard) -> bool:
		return answers_of(c).has(reponse))
	var suite: String = String(PHRASE_DE_REPONSE[reponse])
	var phrase_m: String = "%s. %s" % [trait_advice(t, def),
		suite.substr(0, 1).to_upper() + suite.substr(1)]
	out.append(_ligne(&"mecanique", phrase_m, -1, 1.0, t, reponse, carte))
	return out


static func _ligne(kind: StringName, phrase: String, tag: int, mult: float,
		t: StringName, reponse: StringName, pris: Dictionary) -> Dictionary:
	var carte: SpellCard = pris.get("card", null)
	var depuis_deck: bool = bool(pris.get("from_deck", false))
	var texte: String = phrase
	if carte != null:
		texte += " : %s (%s)" % [carte.display_name, source_text(depuis_deck)]
	return {"kind": kind, "text": texte, "phrase": phrase, "tag": tag, "mult": mult,
		"trait": t, "answer": reponse, "card": carte, "from_deck": depuis_deck}


## « dans ton deck » / « dans ton livre » : d ou vient la carte conseillee.
static func source_text(from_deck: bool) -> String:
	return "dans ton deck" if from_deck else "dans ton livre"


## « le feu », « l eau », « la nature »... pour « Craint le feu ».
static func _le(tag: int) -> String:
	match tag:
		GameEnums.DamageTag.WATER, GameEnums.DamageTag.ARCANE:
			return "l %s" % GameEnums.tag_name(tag)
		GameEnums.DamageTag.NATURE, GameEnums.DamageTag.LIGHTNING, GameEnums.DamageTag.ICE:
			return "la %s" % GameEnums.tag_name(tag)
	return "le %s" % GameEnums.tag_name(tag)


## « au feu », « a l eau », « a la glace »... pour « Resiste au feu ».
static func _au(tag: int) -> String:
	var le: String = _le(tag)
	if le.begins_with("le "):
		return "au " + le.substr(3)
	return "a " + le


## Les cartes du DECK de la partie (pioche, main, defausse, exilees) : ce que le
## joueur avait en main pendant ce niveau. Doublons gardes, sans importance.
static func run_deck() -> Array:
	var out: Array = []
	for pile: Array in [RunState.deck, RunState.hand, RunState.discard, RunState.exiled]:
		for c in pile:
			if c != null:
				out.append(c)
	return out


## Le LIVRE : les sorts obtenus (SaveData.is_discovered), par id. Les passifs
## n y sont pas : ils ne se jouent pas contre un monstre.
static func book_cards() -> Array:
	var ids: Array = ContentDB.cards.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var out: Array = []
	for id in ids:
		var c: SpellCard = ContentDB.cards[id]
		if c != null and not c.is_passive and SaveData.is_discovered(c.id):
			out.append(c)
	return out
