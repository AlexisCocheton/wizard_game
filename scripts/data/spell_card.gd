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

## Un POUVOIR PASSIF : se joue une fois, son effet vaut pour tout le combat.
## Il ne revient jamais en main — le rejouer n aurait aucun sens et il
## encombrerait la pioche jusqu a la fin de la partie.
@export var is_passive: bool = false

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
