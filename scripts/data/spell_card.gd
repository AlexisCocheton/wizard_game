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
