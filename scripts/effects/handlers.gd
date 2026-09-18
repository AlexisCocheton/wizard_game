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
		# Mur PERMANENT : il ne s efface pas au bout de N secondes, il tombe quand
		# les monstres enfermes l ont casse. Meme cle d effet, meme carte-donnee :
		# c est un parametre, pas un second handler.
		if bool(spec.get_param(&"permanent", false)):
			ctx.battlefield.spawn_breakable_wall(ctx.target_position, half, thickness,
				float(spec.get_param(&"wall_hp", 80.0)))
			return
		ctx.battlefield.spawn_wall(ctx.target_position, half, spec.duration, thickness)


## Defausse la main ; chaque carte defaussee reduit l incantation de cette carte.
class DiscardHandForSpeed extends EffectHandler:
	func get_key() -> StringName:
		return &"discard_hand_for_speed"

	func apply(spec: EffectSpec, _ctx: CastContext) -> void:
		var discarded: int = RunState.discard_hand()
		var per_card: float = float(spec.get_param(&"seconds_per_card", 1.0))
		RunState.apply_cost_reduction(discarded * per_card, spec.duration)


# --- Verbes demandes par le testeur ---

## Souffle : degats en zone PUIS repousse loin du centre.
## L ordre compte : on frappe a la position ou le joueur a vise, sinon la moitie
## des monstres seraient deja partis quand les degats tombent.
## params : push (pixels de recul au centre de la zone).
class Knockback extends EffectHandler:
	func get_key() -> StringName:
		return &"knockback"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var col: Color = Fx.color_for(EffectHandlers._tags(ctx))
		Fx.impact(ctx.battlefield, ctx.target_position, col, spec.radius)
		for e in ctx.battlefield.enemies_in_radius(ctx.target_position, spec.radius):
			ctx.battlefield.damage_enemy(e, spec.magnitude * ctx.damage_mult, ctx.card)
		ctx.battlefield.knockback_from(ctx.target_position, spec.radius,
			float(spec.get_param(&"push", 150.0)))


## Spirale qui aspire les monstres vers son centre pendant toute sa duree.
## magnitude = vitesse d aspiration en px/s. Le vortex ne fait AUCUN degat :
## il sert a rassembler pour qu un autre sort fasse le travail.
class VortexPull extends EffectHandler:
	func get_key() -> StringName:
		return &"vortex_pull"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		ctx.battlefield.spawn_vortex(ctx.target_position, spec.radius,
			spec.duration, spec.magnitude)


## Dissipation : efface les effets acquis par les monstres d une petite zone
## (rage, bouclier de premier coup, ralentissement en cours).
##
## La zone est volontairement PETITE sur les cartes : une dissipation large
## annulerait aussi tous les ralentissements du joueur, et la carte se
## retournerait contre lui.
class DispelZone extends EffectHandler:
	func get_key() -> StringName:
		return &"dispel_zone"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		ctx.battlefield.dispel_at(ctx.target_position, spec.radius)


## Pioche immediate, SANS defausser. C est toute la difference avec discard_draw :
## celui-la echange des cartes, celui-ci en ajoute.
class DrawCards extends EffectHandler:
	func get_key() -> StringName:
		return &"draw_cards"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.draw(int(spec.get_param(&"count", 2)))
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE)


## Les prochaines cartes lancees reviennent en main au lieu de partir.
## magnitude = nombre de cartes gardees.
class RetainNext extends EffectHandler:
	func get_key() -> StringName:
		return &"retain_next"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.retain_next(int(maxf(spec.magnitude, 1.0)))
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE)


## Deux sorts chargent en meme temps pendant `duration` secondes.
class DoubleCast extends EffectHandler:
	func get_key() -> StringName:
		return &"double_cast"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.allow_double_cast(spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE)


## Pluie de meteorites sur TOUTE la carte : `impacts` zones breves reparties au
## hasard, etalees dans le temps.
##
## Elles sont posees d un coup avec des durees decalees plutot que creees au fil
## de l eau : un handler est sans etat et ne recoit aucun tick, donc l etalement
## doit etre encode dans les zones elles-memes. Chaque zone ne frappe que sur sa
## derniere seconde de vie — d ou le rayon qui ne sert qu a la surface touchee.
class MeteorStorm extends EffectHandler:
	func get_key() -> StringName:
		return &"meteor_storm"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var n: int = maxi(int(spec.get_param(&"impacts", 12)), 1)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# Marge faible : les impacts doivent pouvoir tomber pres des bords, sinon
		# les monstres qui longent le decor traversent la pluie sans rien prendre.
		var marge: float = minf(spec.radius * 0.25, 80.0)
		var x0: float = marge
		var x1: float = GameConfig.BATTLEFIELD_WIDTH - marge
		var y0: float = GameConfig.SPAWN_LINE_Y + marge
		var y1: float = GameConfig.MAGE_LINE_Y - marge
		# Grille secouee plutot que tirage libre. Un pur hasard laisse regulierement
		# un quart du terrain intact : la carte promet de couvrir TOUTE la carte,
		# elle doit le faire a chaque lancement, pas en moyenne.
		var cols: int = maxi(int(round(sqrt(float(n) * (x1 - x0) / maxf(y1 - y0, 1.0)))), 1)
		var lignes: int = int(ceil(float(n) / float(cols)))
		for i in n:
			var cx: int = i % cols
			var cy: int = i / cols
			var pas_x: float = (x1 - x0) / float(cols)
			var pas_y: float = (y1 - y0) / float(lignes)
			# Secousse VOLONTAIREMENT faible autour du centre de la case : au-dela,
			# un impact colle a un bord de sa case laisse le coin oppose intact et
			# un monstre peut traverser la pluie sans rien prendre. Le hasard sert
			# a ce que deux lancements ne se ressemblent pas, pas a faire des trous.
			var at := Vector2(
				x0 + (cx + 0.5 + rng.randf_range(-0.18, 0.18)) * pas_x,
				y0 + (cy + 0.5 + rng.randf_range(-0.18, 0.18)) * pas_y)
			# Chaque impact dure une fraction de la duree totale : les monstres
			# voient la pluie tomber au lieu de perdre leurs PV d un seul coup.
			var vie: float = maxf(spec.duration / float(n), 0.2)
			ctx.battlefield.spawn_ground_zone(at, spec.radius, vie,
				spec.magnitude * ctx.damage_mult / vie, 0.0, ctx.card)
