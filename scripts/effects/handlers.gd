class_name EffectHandlers
extends RefCounted
## Tous les handlers d effet, regroupes pour limiter le nombre de fichiers.
## Ajouter un VERBE de sort = une classe ici + une ligne dans EffectRegistry._ready().
## Ajouter une CARTE = un .tres composant des cles existantes, sans toucher au code.
##
## `ctx.damage_mult` (Focalisation) s applique a tout ce qui inflige des degats.


static func _tags(ctx: CastContext) -> Array:
	return ctx.card.tags if ctx.card != null else []


## Degats sur une cible unique.
class DamageSingle extends EffectHandler:
	func get_key() -> StringName:
		return &"damage_single"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null or ctx.target_enemy == null:
			return
		var col: Color = Fx.color_for(EffectHandlers._tags(ctx))
		var to: Vector2 = (ctx.target_enemy as Node2D).position
		Fx.projectile(ctx.battlefield, ctx.caster_position(), to, col)
		ctx.battlefield.damage_enemy(ctx.target_enemy, spec.magnitude * ctx.damage_mult, ctx.card)


## Degats en ligne droite, traverse plusieurs cibles.
class PierceLine extends EffectHandler:
	func get_key() -> StringName:
		return &"pierce_line"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var max_targets: int = int(spec.get_param(&"max_targets", 99))
		var origin: Vector2 = ctx.caster_position()
		var col: Color = Fx.color_for(EffectHandlers._tags(ctx))
		Fx.beam(ctx.battlefield, origin, ctx.direction, spec.radius, col)
		var hit: Array = ctx.battlefield.enemies_in_line(origin, ctx.direction, spec.radius, max_targets)
		for e in hit:
			ctx.battlefield.damage_enemy(e, spec.magnitude * ctx.damage_mult, ctx.card)


## Zone au sol : degats sur la duree, ralentissement, et/ou vulnerabilite.
## params : slow_pct (0..100), vuln_mult (>1 = les degats recus sont multiplies).
class GroundZone extends EffectHandler:
	func get_key() -> StringName:
		return &"ground_zone"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		ctx.battlefield.spawn_ground_zone(
			ctx.target_position, spec.radius, spec.duration,
			spec.magnitude * ctx.damage_mult,
			float(spec.get_param(&"slow_pct", 0.0)), ctx.card,
			float(spec.get_param(&"vuln_mult", 1.0)))


## Degats immediats a chaque monstre de la zone, PROPORTIONNELS a leur nombre :
## plus ils sont serres, plus ca fait mal. magnitude = degats par monstre present.
class DamagePerEnemy extends EffectHandler:
	func get_key() -> StringName:
		return &"damage_per_enemy"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var inside: Array = ctx.battlefield.enemies_in_radius(ctx.target_position, spec.radius)
		var per_target: float = spec.magnitude * inside.size() * ctx.damage_mult
		Fx.impact(ctx.battlefield, ctx.target_position, Fx.color_for(EffectHandlers._tags(ctx)), spec.radius)
		for e in inside:
			ctx.battlefield.damage_enemy(e, per_target, ctx.card)


## Ralentit la jauge de vitesse des ennemis.
class SlowEnemyGauge extends EffectHandler:
	func get_key() -> StringName:
		return &"slow_enemy_gauge"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.screen_tint(ctx.battlefield, Fx.COL_FROST)
		ctx.battlefield.apply_global_enemy_slow(spec.magnitude, spec.duration)


## Volte-face : les monstres remontent pendant la duree.
class ReverseEnemies extends EffectHandler:
	func get_key() -> StringName:
		return &"reverse_enemies"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.screen_tint(ctx.battlefield, Fx.COL_ARCANE)
		ctx.battlefield.apply_reverse(spec.duration)


## Focalisation : le prochain sort inflige magnitude fois ses degats.
class EmpowerNext extends EffectHandler:
	func get_key() -> StringName:
		return &"empower_next"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE)
		RunState.empower_next(maxf(1.0, spec.magnitude))


## Accelere temporairement l incantation du mage.
class SelfHaste extends EffectHandler:
	func get_key() -> StringName:
		return &"self_haste"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.self_aura(ctx.battlefield, Fx.COL_HASTE)
		ctx.battlefield.apply_cast_haste(spec.magnitude, spec.duration)


## Reduit le temps d incantation de toutes les cartes pendant une duree.
class CostReduction extends EffectHandler:
	func get_key() -> StringName:
		return &"cost_reduction"

	func apply(spec: EffectSpec, _ctx: CastContext) -> void:
		RunState.apply_cost_reduction(spec.magnitude, spec.duration)


## Accelere la pioche pour une duree. magnitude = facteur (2 = deux fois plus vite).
class DrawBoost extends EffectHandler:
	func get_key() -> StringName:
		return &"draw_boost"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.boost_draw(spec.magnitude, spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE)


## Invoque un allie qui combat quelques secondes.
class SummonAlly extends EffectHandler:
	func get_key() -> StringName:
		return &"summon_ally"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.self_aura(ctx.battlefield, Fx.COL_SUMMON)
		ctx.battlefield.spawn_ally(spec.duration, spec.magnitude * ctx.damage_mult)


## Defausse N cartes puis en pioche N.
class DiscardDraw extends EffectHandler:
	func get_key() -> StringName:
		return &"discard_draw"

	func apply(spec: EffectSpec, _ctx: CastContext) -> void:
		var n: int = int(spec.get_param(&"count", 2))
		RunState.discard_random(n)
		RunState.draw(n)


## Accelere les ennemis en echange d un avantage immediat.
class HasteEnemiesBoon extends EffectHandler:
	func get_key() -> StringName:
		return &"haste_enemies_boon"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield != null:
			ctx.battlefield.apply_global_enemy_slow(-spec.magnitude, spec.duration)
		RunState.draw(int(spec.get_param(&"draw", 2)))


## Retire definitivement des cartes du deck.
class RemoveCards extends EffectHandler:
	func get_key() -> StringName:
		return &"remove_cards"

	func apply(spec: EffectSpec, _ctx: CastContext) -> void:
		RunState.exile_from_deck(int(spec.get_param(&"count", 1)))


## Erige un mur qui bloque le pathfinding des monstres pendant une duree.
class BuildWall extends EffectHandler:
	func get_key() -> StringName:
		return &"build_wall"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var half: float = maxf(spec.radius, 60.0)
		var thickness: float = float(spec.get_param(&"thickness", 60.0))
		ctx.battlefield.spawn_wall(ctx.target_position, half, spec.duration, thickness)


## Defausse la main ; chaque carte defaussee reduit l incantation de cette carte.
class DiscardHandForSpeed extends EffectHandler:
	func get_key() -> StringName:
		return &"discard_hand_for_speed"

	func apply(spec: EffectSpec, _ctx: CastContext) -> void:
		var discarded: int = RunState.discard_hand()
		var per_card: float = float(spec.get_param(&"seconds_per_card", 1.0))
		RunState.apply_cost_reduction(discarded * per_card, spec.duration)
