class_name MajorUpgradeDef
extends Resource
## UNE AMELIORATION MAJEURE (« enorme ») d un sort — vague 10, chantier A1.
##
## Une voie ordinaire (RunState.upgrade_pool_for) ne sait que POUSSER un chiffre
## du sort : +30 % de degats, +1 cible, -15 % de vitesse. Elle ne peut pas
## changer ce que le sort FAIT. Le co-auteur demande des ameliorations qui
## changent sa STRUCTURE : une seconde ligne de fleches, une vague de plus, un
## poison qui reste apres le contact, un mur que les volants ne franchissent
## plus. Une majeure est donc DECLAREE par carte dans le contenu (SpellCard.
## major_upgrades), avec un langage de modificateurs, plutot que derivee des
## effets comme les voies : une structure nouvelle ne se devine pas.
##
## LE FORMAT (ecrit par tools/make_content.gd, lu par RunState) :
##
##   var m := MajorUpgradeDef.make(&"seconde_volee", "Seconde volee",
##       "Une seconde ligne de fleches part a 25 degres",
##       [{"op": "duplicate", "key": &"pierce_line", "params": {&"angle_deg": 25.0}}],
##       [{"op": "axis", "axis": &"damage", "pct": -0.5}])
##   carte.major_upgrades = [m, m2]
##
## Chaque modificateur (et chaque prix, meme langage) est un Dictionary dont
## « op » choisit le verbe. Les cles s ecrivent en String ou en StringName
## (`field()` lit les deux : un .tres sauve l une ou l autre selon l auteur).
##
##   axis        {axis, pct}     meme semantique qu une voie : +0.3 = +30 % sur
##                               l axe (RunState.UP_DAMAGE, UP_CAST, UP_AREA...),
##                               s ADDITIONNE aux voies prises. C est la forme
##                               conseillee pour un PRIX : le texte s ecrit seul
##                               (« -50 % degats ») et le bot du banc le lit.
##   add_effect  {key, magnitude, duration, radius, params} ou {spec: EffectSpec}
##                               ajoute un effet au sort (la cle doit avoir un
##                               handler, verifie par validation_errors).
##   set         {key, field | param, value}
##                               remplace (ou ajoute) un champ de spec
##                               (magnitude, duration, radius) ou un param.
##   scale       {key, field | param, factor}
##                               multiplie un champ ou un param.
##   duplicate   {key, params}   copie chaque effet `key` ; la copie recoit
##                               `params` par-dessus les siens (decalage d angle,
##                               de visee...).
##   repeat      {delay, factor} le sort se RESOUT de nouveau `delay` s (monde)
##                               plus tard, magnitudes x `factor` (1 par defaut) :
##                               une vague supplementaire.
##   cast_time   {factor}        multiplie le temps d incantation (0.15 = quasi
##                               instantane ; le plancher de 0,1 s tient).
##
## `key` vide (ou absent) vise TOUS les effets du sort pour set, scale et
## duplicate. Chaque op peut porter un « text » : c est lui que l ecran affiche
## (sinon un texte est deduit pour axis, cast_time, repeat et scale).
##
## PARAMS NEUFS que les handlers comprennent (a poser par set ou duplicate) :
##   pierce_line   angle_deg (rotation de la ligne), offset_px (decalage lateral)
##   tous          aim_offset (Vector2 ajoute au point vise)
##   ground_zone   grow_start, grow_peak (rayon x start -> x peak a mi-vie -> x start)
##                 residue_dps, residue_duration (degat CONTINU qui reste apres la zone)
##   tout effet qui touche un monstre (damage_enemy) : residue_dps, residue_duration
##   build_wall    blocks_flyers (les volants ne passent plus), unbreakable
##   place_terrain, taunt_prop : unbreakable (ni frappe ni Briseur ; prop_hp = 0)
##   electric_mark marks_per_death, jump_range, decay
##
## REGLES DE L OFFRE (RunState, section MAJEURES) : jamais a la premiere
## maturation, au plus une parmi les trois propositions, une seule prise par
## sort et par partie (GameConfig.MAJOR_UPGRADE_FROM_TIER, MAJOR_UPGRADES_PER_CARD).

const OP_AXIS: StringName = &"axis"
const OP_ADD_EFFECT: StringName = &"add_effect"
const OP_SET: StringName = &"set"
const OP_SCALE: StringName = &"scale"
const OP_DUPLICATE: StringName = &"duplicate"
const OP_REPEAT: StringName = &"repeat"
const OP_CAST_TIME: StringName = &"cast_time"
const OPS: Array[StringName] = [OP_AXIS, OP_ADD_EFFECT, OP_SET, OP_SCALE,
	OP_DUPLICATE, OP_REPEAT, OP_CAST_TIME]
## Champs d EffectSpec que set et scale peuvent viser (le reste passe par param).
const SPEC_FIELDS: Array[StringName] = [&"magnitude", &"duration", &"radius"]

## Identifiant STABLE dans la carte : c est lui que la partie retient
## (RunState.upgrades_taken, sous la forme « major:<id> »).
@export var id: StringName = &""
## Le nom de la majeure, en titre de son bouton (« Seconde volee »).
@export var title: String = ""
## Ce qu elle fait, en clair : la ligne VERTE de l ecran.
@export_multiline var description: String = ""
## Le GAIN, dans l ordre d application.
@export var modifiers: Array[Dictionary] = []
## Le PRIX, meme langage, affiche en ROUGE. Une majeure sans prix est refusee
## par validation_errors : c est un saut de structure, il se paie.
@export var prices: Array[Dictionary] = []


## Fabrique une majeure en une ligne (make_content.gd, tests).
static func make(p_id: StringName, p_title: String, p_description: String,
		p_modifiers: Array, p_prices: Array) -> MajorUpgradeDef:
	var m := MajorUpgradeDef.new()
	m.id = p_id
	m.title = p_title
	m.description = p_description
	for d in p_modifiers:
		if d is Dictionary:
			m.modifiers.append(d)
	for d in p_prices:
		if d is Dictionary:
			m.prices.append(d)
	return m


## Lit un champ d op ecrit en String OU en StringName. Un .tres garde le type de
## cle que l auteur a ecrit ; le lecteur ne doit pas en dependre.
static func field(op: Dictionary, name: String, default_value: Variant) -> Variant:
	if op.has(name):
		return op[name]
	return op.get(StringName(name), default_value)


static func op_of(op: Dictionary) -> StringName:
	return StringName(str(field(op, "op", "")))


## Modificateurs puis prix : l ordre dans lequel ils s appliquent.
func all_ops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(modifiers)
	out.append_array(prices)
	return out


## Les defauts de cette majeure pour `card`, en phrases. Vide = majeure valide.
## Lue par test_major_upgrades sur TOUT le catalogue : le contenu de la phase B
## arrive verifie sans que l AUDIT ait a connaitre le langage.
func validation_errors(card: SpellCard) -> Array[String]:
	var out: Array[String] = []
	var nom: String = "%s/%s" % [card.id if card != null else &"?", id]
	if id == &"":
		out.append("%s : id vide" % nom)
	if title.strip_edges() == "":
		out.append("%s : titre vide" % nom)
	if description.strip_edges() == "":
		out.append("%s : description vide" % nom)
	if modifiers.is_empty():
		out.append("%s : aucun modificateur (une majeure doit changer le sort)" % nom)
	if prices.is_empty():
		out.append("%s : aucun prix (une majeure se paie)" % nom)
	var cles: Dictionary = {}
	if card != null:
		for s in card.effects:
			if s != null:
				cles[s.key] = true
	for op in all_ops():
		var verbe: StringName = op_of(op)
		if not OPS.has(verbe):
			out.append("%s : op inconnue '%s'" % [nom, verbe])
			continue
		var cle: StringName = StringName(str(field(op, "key", "")))
		match verbe:
			OP_AXIS:
				var axe: StringName = StringName(str(field(op, "axis", "")))
				if not RunState.MAJOR_AXES.has(axe):
					out.append("%s : axe inconnu '%s'" % [nom, axe])
				if not (field(op, "pct", null) is float or field(op, "pct", null) is int):
					out.append("%s : axe %s sans pct chiffre" % [nom, axe])
			OP_ADD_EFFECT:
				var spec: Variant = field(op, "spec", null)
				var k: StringName = (spec as EffectSpec).key if spec is EffectSpec else cle
				if k == &"" or not EffectRegistry.has_key(k):
					out.append("%s : add_effect sur une cle sans handler '%s'" % [nom, k])
				else:
					cles[k] = true
			OP_SET, OP_SCALE:
				if cle != &"" and not cles.has(cle):
					out.append("%s : %s vise '%s', absent du sort" % [nom, verbe, cle])
				var champ: StringName = StringName(str(field(op, "field", "")))
				var param: StringName = StringName(str(field(op, "param", "")))
				if champ == &"" and param == &"":
					out.append("%s : %s sans field ni param" % [nom, verbe])
				elif champ != &"" and not SPEC_FIELDS.has(champ):
					out.append("%s : champ inconnu '%s'" % [nom, champ])
				if verbe == OP_SCALE and float(field(op, "factor", 0.0)) <= 0.0:
					out.append("%s : scale sans facteur positif" % nom)
				if verbe == OP_SET and not (op.has("value") or op.has(&"value")):
					out.append("%s : set sans value" % nom)
			OP_DUPLICATE:
				if cle != &"" and not cles.has(cle):
					out.append("%s : duplicate vise '%s', absent du sort" % [nom, cle])
			OP_REPEAT:
				if float(field(op, "delay", 0.0)) <= 0.0:
					out.append("%s : repeat sans delai positif" % nom)
			OP_CAST_TIME:
				if float(field(op, "factor", 0.0)) <= 0.0:
					out.append("%s : cast_time sans facteur positif" % nom)
	return out
