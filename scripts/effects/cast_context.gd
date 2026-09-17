class_name CastContext
extends RefCounted
## Contexte d un lancement de sort. Decouple les handlers de la structure de scene,
## ce qui permet aux tests de les piloter avec un champ de bataille factice.

var caster: Node = null
var battlefield: Object = null
var target_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN
var target_enemy: Object = null
var card: SpellCard = null
## Multiplicateur de degats du sort (Focalisation : x2 sur le prochain sort).
var damage_mult: float = 1.0


static func make(bf: Object, card_ref: SpellCard = null) -> CastContext:
	var c := CastContext.new()
	c.battlefield = bf
	c.card = card_ref
	return c


## Position d origine du sort : toujours le mage.
##
## Ne PAS utiliser la position globale du `caster` : le GameController est un
## Node2D pose a l origine de la scene, la fleche percante partait donc du coin
## haut-gauche et sa ligne ne croisait plus aucun monstre.
func caster_position() -> Vector2:
	if caster != null and caster.has_method("mage_position"):
		return caster.call("mage_position")
	return Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)
