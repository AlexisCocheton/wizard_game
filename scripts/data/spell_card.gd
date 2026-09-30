class_name SpellCard
extends Resource
## Une carte de sort jouable depuis la main.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Temps d'incantation en secondes A x1. Divise par le multiplicateur au lancement.
@export var base_cast_time: float = 2.0
@export var targeting: GameEnums.Targeting = GameEnums.Targeting.NONE
@export var tags: Array[GameEnums.DamageTag] = []
@export var effects: Array[EffectSpec] = []
## Nombre d'exemplaires places dans le deck de depart (cartes communes).
@export var copies_in_starter: int = 0
## Si vrai, la carte quitte la partie apres usage au lieu d'aller a la defausse.
@export var exile_after_cast: bool = false

## Un POUVOIR PASSIF. Il n est PLUS une carte du deck (demande du testeur du
## 21 septembre) : il s EQUIPE dans un des trois emplacements et agit des le
## debut du combat, sans incantation ni pioche.
@export var is_passive: bool = false

## Vitesse MINIMALE, en pourcentage, a partir de laquelle un passif agit.
##
## "Les passifs ne sont actifs que si la vitesse du jeu va assez vite. Exemple
## pour fire boom : le passif n a lieu qu a partir de 140 % de speed."
##
## C est ce qui fait tenir la mecanique signature ensemble : aller vite ne donne
## plus seulement de l XP et du bouclier, ca ALLUME des regles. Et comme un coup
## recu fait retomber la vitesse, il eteint aussi les passifs — le prix d un
## contact devient lisible d un coup d oeil sur la barre.
##
## La valeur n a de sens que si `is_passive` est vrai ; elle est ignoree ailleurs.
@export var speed_threshold: int = 100

## Feuille d effet PROPRE a cette carte (nom dans Fx.STRIPS ou Fx.GRIDS). Vide,
## l effet retombe sur la feuille de l element — ce qui faisait que tous les sorts
## de feu partageaient la meme animation. L AUDIT exige une feuille par carte,
## et jamais la meme pour deux cartes : c est ce qui les rend reconnaissables.
@export var fx_key: StringName = &""
## Son joue a la resolution du sort (cle dans AudioBus.sfx_keys()). Vide, le son
## generique d incantation est joue.
@export var sfx_key: StringName = &""
@export var icon: Texture2D


func effect_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in effects:
		if e != null:
			out.append(e.key)
	return out


## --- TYPE DU SORT (vague 5) ---
##
## Chaque carte a UN type visible, avec son logo (ElementIcons) : son ELEMENT
## quand elle en porte un, sinon un petit nombre de types non elementaires. Le
## joueur lit sur la carte ce que le bestiaire lui dit des resistances : un
## golem immunise au sablier n est pas ralenti par une carte au sablier.
##
## DERIVE et non stocke : le type se deduit des tags et des effets, deux choses
## que la carte porte deja. Un champ ecrit a la main aurait pu contredire les
## tags (une carte « feu » qui inflige du givre), et chaque carte neuve aurait
## du penser a le remplir. test_elements interdit qu une carte reste sans type :
## un verbe neuf sans famille rougit le harnais au lieu d afficher un blanc.
##
## ORDRE DE LECTURE, du plus utile au joueur au moins utile :
##   1. le premier ELEMENT des tags — c est lui que les resistances lisent. Une
##      Mare de venin est poison avant d etre ralentissante, un Totem physique
##      avant d etre un objet de terrain ;
##   2. un objet pose sur le terrain (mur, riviere, fosse, autel) : TERRAIN ;
##   3. une invocation : INVOCATION ;
##   4. un ralentissement sans element (Entrave temporelle) : RALENTISSEMENT,
##      le meme logo que la ligne « immunise au ralentissement » du bestiaire ;
##   5. tout ce qui agit sur la main, la pioche ou l incantation : GRIMOIRE.
## Un passif est PASSIF, quelle que soit sa regle.
const TYPE_TERRAIN_KEYS: Array[StringName] = [
	&"build_wall", &"place_terrain", &"terrain_river", &"taunt_prop", &"water_flood",
]
const TYPE_GRIMOIRE_KEYS: Array[StringName] = [
	&"draw_cards", &"discard_draw", &"retain_next", &"remove_cards", &"double_cast",
	&"draw_boost", &"discard_hand_for_speed", &"cost_reduction", &"empower_next",
	&"self_haste",
]


## Cle du type ("feu", "terrain"...), "" si aucune regle ne s applique.
func spell_type() -> StringName:
	if is_passive:
		return &"passif"
	for t in tags:
		if t in GameEnums.ELEMENTS:
			return type_of_tag(t)
	var cles: Array[StringName] = effect_keys()
	for k in cles:
		if k in TYPE_TERRAIN_KEYS:
			return &"terrain"
	if GameEnums.DamageTag.SUMMON in tags or &"summon_ally" in cles:
		return &"invocation"
	if GameEnums.DamageTag.SLOW in tags:
		return &"ralentissement"
	for k in cles:
		if k in TYPE_GRIMOIRE_KEYS:
			return &"grimoire"
	return &""


## Cle de type d un tag : la meme pour une carte de feu et pour la ligne « feu »
## d une fiche de monstre, donc le meme logo aux deux endroits.
static func type_of_tag(tag: int) -> StringName:
	match tag:
		GameEnums.DamageTag.PHYSICAL: return &"physique"
		GameEnums.DamageTag.FIRE: return &"feu"
		GameEnums.DamageTag.FROST: return &"givre"
		GameEnums.DamageTag.ARCANE: return &"arcane"
		GameEnums.DamageTag.POISON: return &"poison"
		GameEnums.DamageTag.LIGHTNING: return &"foudre"
		GameEnums.DamageTag.SLOW: return &"ralentissement"
		GameEnums.DamageTag.SUMMON: return &"invocation"
	return &""


## --- AMELIORATION EN COMBAT ---
##
## Les trois voies d amelioration de ce sort, sous la forme attendue par le
## grimoire : [{text: String, unlocked: bool}]. Le contrat a ete fixe AVANT ce
## chantier par GalleryPanel.upgrades_of() ; il est verrouille par
## tests/unit/test_upgrades.gd (_test_le_contrat_du_grimoire_est_respecte).
##
## POURQUOI UNE PROPRIETE CALCULEE ET NON UN @export
## -------------------------------------------------
## Un @export serait ecrit dans le .tres, donc PARTAGE : les Resources sont
## mises en cache par Godot, le meme SpellCard sert la main du joueur, la fiche
## du grimoire et la partie suivante. Marquer `unlocked = true` dedans ferait
## fuir l amelioration hors de la partie — exactement ce que la regle
## "l amelioration vaut pour la partie en cours" interdit.
##
## L etat vit donc dans RunState (efface par reset() a chaque niveau) et cette
## propriete ne fait que le presenter. Le grimoire lit `card.upgrades` sans rien
## savoir de tout cela.
var upgrades: Array:
	get:
		return RunState.upgrade_lines_for(self)


## Vrai si ce sort peut etre elargi : seul un effet qui a un RAYON gagne quelque
## chose a etre "plus ample". Sur un trait a cible unique, la voie AMPLEUR
## n aurait rien a agrandir et mentirait au joueur — RunState.upgrade_paths_for()
## lui substitue alors une autre voie.
func has_area() -> bool:
	for e in effects:
		if e != null and e.radius > 0.0:
			return true
	return false


## Vrai si ce sort inflige des degats chiffres. Un sort utilitaire (pioche,
## reduction de cout, mur) n a pas de degats a augmenter.
func has_damage() -> bool:
	for e in effects:
		if e != null and e.magnitude > 0.0:
			return true
	return false
