class_name EffectHandlers
extends RefCounted
## Tous les handlers d effet, regroupes pour limiter le nombre de fichiers.
## Ajouter un VERBE de sort = une classe ici + une ligne dans EffectRegistry._ready().
## Ajouter une CARTE = un .tres composant des cles existantes, sans toucher au code.
##
## `ctx.damage_mult` (Focalisation) s applique a tout ce qui inflige des degats.


static func _tags(ctx: CastContext) -> Array:
	return ctx.card.tags if ctx.card != null else []


## Cellules qu un mur de cette carte bloquerait a ce point. Meme decoupe que
## `Battlefield.spawn_wall` -> `NavGrid.block_rect`, lue dans la MEME spec : la
## verification et la pose ne peuvent pas diverger.
static func wall_cells(spec: EffectSpec, bf: Node, at: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if bf == null or bf.get("nav") == null:
		return out
	var half: float = maxf(spec.radius, 60.0)
	var thickness: float = float(spec.get_param(&"thickness", 60.0))
	return (bf.nav as NavGrid).rect_cells(at, half, thickness)


## La carte peut-elle etre LACHEE a ce point ? Interroge par le glisser-deposer
## (apercu rouge) et par GameController.play_card (la carte reste en main).
##
## Seuls les objets qui BLOQUENT ont une raison d etre refuses : ils sont les seuls
## a pouvoir couper le chemin des monstres. Refuser AVANT de depenser la carte
## plutot que poser puis retirer : un objet qui disparait seul se lirait comme un
## bug, et une carte payee pour rien comme une injustice.
static func placement_allowed(card: SpellCard, point: Vector2, bf: Node) -> bool:
	if card == null or bf == null or point == Vector2.INF:
		return true
	for spec in card.effects:
		if spec == null:
			continue
		if spec.key == &"build_wall":
			if not bf.can_block(wall_cells(spec, bf, point)):
				return false
		elif spec.key == &"terrain_river":
			if not bf.river_possible(point.y):
				return false
	return true


## Genre d accessoire lu dans les params d une carte.
static func prop_kind(name: String) -> int:
	match name:
		"water": return TerrainProp.Kind.WATER
		"bramble": return TerrainProp.Kind.BRAMBLE
		"pit": return TerrainProp.Kind.PIT
		"altar": return TerrainProp.Kind.ALTAR
	return TerrainProp.Kind.TREE


## Plante un accessoire et ce qu il porte (zone au sol, generateur d allies).
## Partage par `taunt_prop` (qui attire) et `place_terrain` (qui n attire pas, ou
## peu) : la pose est la meme, seule la portee de provocation change.
##
## La zone attachee est posee APRES l accessoire et rangee dans `p.zone` : c est
## cette poignee qui permet a Battlefield de la couper quand l objet tombe. Une
## zone posee independamment survivrait a son porteur, et le joueur aurait
## interet a abattre son propre arbre pour garder le poison.
static func plant(spec: EffectSpec, ctx: CastContext, taunt_radius: float,
		zone_radius: float) -> TerrainProp:
	var genre: int = prop_kind(String(spec.get_param(&"kind", "tree")))
	var col: Color = Fx.color_for(_tags(ctx))
	var p: TerrainProp = ctx.battlefield.spawn_prop(
		genre, ctx.target_position, spec.duration,
		float(spec.get_param(&"prop_hp", 0.0)),
		taunt_radius, 0.0, 0.0, Fx.card_sheet(ctx.card), col, _tags(ctx))
	if p == null:
		return null
	if zone_radius > 0.0:
		# Duree de la zone = duree de l objet : INF pour un objet permanent. Elle
		# ne meurt de toute facon qu avec lui (`_destroy_prop`).
		p.zone = ctx.battlefield.spawn_ground_zone(
			p.position, zone_radius, p.time_left,
			spec.magnitude * ctx.damage_mult,
			float(spec.get_param(&"slow_pct", 0.0)), ctx.card,
			float(spec.get_param(&"vuln_mult", 1.0)))
	var tous_les: float = float(spec.get_param(&"summon_every", 0.0))
	if tous_les > 0.0:
		p.summon_every = tous_les
		# Le premier allie arrive a mi-intervalle : le joueur doit VOIR que l autel
		# fonctionne avant que la vague ne l ait abattu, sans pour autant recevoir
		# un allie gratuit a l instant de la pose.
		p.summon_timer = tous_les * 0.5
		p.summon_damage = float(spec.get_param(&"ally_damage", 0.0)) * ctx.damage_mult
		p.summon_duration = float(spec.get_param(&"ally_duration", tous_les))
	return p


## Degats sur une cible unique.
class DamageSingle extends EffectHandler:
	func get_key() -> StringName:
		return &"damage_single"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null or ctx.target_enemy == null:
			return
		var col: Color = Fx.color_for(EffectHandlers._tags(ctx))
		var to: Vector2 = (ctx.target_enemy as Node2D).position
		Fx.projectile(ctx.battlefield, ctx.caster_position(), to, col, Fx.card_sheet(ctx.card))
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
		# La fleche du pack est la meme pour tous les sorts en ligne. L eclat de
		# DEPART, lui, porte la feuille de la carte : c est ce qui distingue la
		# Fleche percante de la Faille temporelle, qui partent du meme point dans
		# la meme direction.
		Fx.impact(ctx.battlefield, origin, col, maxf(spec.radius, 60.0) * 0.5,
			Fx.card_sheet(ctx.card))
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
		Fx.impact(ctx.battlefield, ctx.target_position, Fx.color_for(EffectHandlers._tags(ctx)), spec.radius, Fx.card_sheet(ctx.card))
		for e in inside:
			ctx.battlefield.damage_enemy(e, per_target, ctx.card)


## Ralentit la jauge de vitesse des ennemis.
class SlowEnemyGauge extends EffectHandler:
	func get_key() -> StringName:
		return &"slow_enemy_gauge"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.screen_tint(ctx.battlefield, Fx.COL_FROST, Fx.card_sheet(ctx.card))
		ctx.battlefield.apply_global_enemy_slow(spec.magnitude, spec.duration,
			EffectHandlers._tags(ctx))


## Volte-face : les monstres remontent pendant la duree.
class ReverseEnemies extends EffectHandler:
	func get_key() -> StringName:
		return &"reverse_enemies"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.screen_tint(ctx.battlefield, Fx.COL_ARCANE, Fx.card_sheet(ctx.card))
		ctx.battlefield.apply_reverse(spec.duration, EffectHandlers._tags(ctx))


## Focalisation : le prochain sort inflige magnitude fois ses degats.
class EmpowerNext extends EffectHandler:
	func get_key() -> StringName:
		return &"empower_next"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))
		RunState.empower_next(maxf(1.0, spec.magnitude))


## Accelere temporairement l incantation du mage.
class SelfHaste extends EffectHandler:
	func get_key() -> StringName:
		return &"self_haste"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))
		ctx.battlefield.apply_cast_haste(spec.magnitude, spec.duration)


## Reduit le temps d incantation de toutes les cartes pendant une duree.
class CostReduction extends EffectHandler:
	func get_key() -> StringName:
		return &"cost_reduction"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.apply_cost_reduction(spec.magnitude, spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))


## Accelere la pioche pour une duree. magnitude = facteur (2 = deux fois plus vite).
class DrawBoost extends EffectHandler:
	func get_key() -> StringName:
		return &"draw_boost"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.boost_draw(spec.magnitude, spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE, Fx.card_sheet(ctx.card))


## Invoque un allie qui combat quelques secondes.
class SummonAlly extends EffectHandler:
	func get_key() -> StringName:
		return &"summon_ally"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		Fx.self_aura(ctx.battlefield, Fx.COL_SUMMON, Fx.card_sheet(ctx.card))
		ctx.battlefield.spawn_ally(spec.duration, spec.magnitude * ctx.damage_mult)


## Defausse N cartes puis en pioche N.
class DiscardDraw extends EffectHandler:
	func get_key() -> StringName:
		return &"discard_draw"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		var n: int = int(spec.get_param(&"count", 2))
		RunState.discard_random(n)
		RunState.draw(n)
		# Ces sorts ne touchent que la MAIN : sans aura sur le mage, la carte
		# partait sans rien afficher et rien ne distinguait « elle a ete lancee »
		# de « elle n est pas partie ».
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE, Fx.card_sheet(ctx.card))


## Accelere les ennemis en echange d un avantage immediat.
class HasteEnemiesBoon extends EffectHandler:
	func get_key() -> StringName:
		return &"haste_enemies_boon"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield != null:
			# Accelerer TOUS les monstres est l effet le plus dangereux du jeu :
			# il doit se voir en grand, comme son symetrique le ralentissement.
			Fx.screen_tint(ctx.battlefield, Fx.COL_LIGHTNING, Fx.card_sheet(ctx.card))
			ctx.battlefield.apply_global_enemy_slow(-spec.magnitude, spec.duration)
		RunState.draw(int(spec.get_param(&"draw", 2)))


## Retire definitivement des cartes du deck.
class RemoveCards extends EffectHandler:
	func get_key() -> StringName:
		return &"remove_cards"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.exile_from_deck(int(spec.get_param(&"count", 1)))
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE, Fx.card_sheet(ctx.card))


## Erige un mur qui bloque le pathfinding des monstres pendant une duree.
class BuildWall extends EffectHandler:
	func get_key() -> StringName:
		return &"build_wall"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var half: float = maxf(spec.radius, 60.0)
		var thickness: float = float(spec.get_param(&"thickness", 60.0))
		# Les rochers du pack sont les memes pour les deux murs : c est le meme
		# verbe. La feuille de la carte les distingue — le Bastion ne se batit pas
		# comme un Mur de pierre.
		Fx.impact(ctx.battlefield, ctx.target_position, Fx.COL_WALL, half * 0.6,
			Fx.card_sheet(ctx.card))
		# GARANTIE DE CHEMIN, reverifiee a la resolution. L apercu de visee a deja
		# refuse les poses qui enferment (voir `placement_allowed`), mais le terrain
		# a pu changer pendant l incantation : un second sort charge en meme temps,
		# une riviere posee entre-temps. Un mur qui couperait tout chemin figerait
		# une vague derriere de l eau qu aucun monstre ne sait frapper.
		if not ctx.battlefield.can_block(EffectHandlers.wall_cells(spec, ctx.battlefield,
				ctx.target_position)):
			return
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

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		var discarded: int = RunState.discard_hand()
		var per_card: float = float(spec.get_param(&"seconds_per_card", 1.0))
		RunState.apply_cost_reduction(discarded * per_card, spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))


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
		Fx.impact(ctx.battlefield, ctx.target_position, col, spec.radius, Fx.card_sheet(ctx.card))
		for e in ctx.battlefield.enemies_in_radius(ctx.target_position, spec.radius):
			ctx.battlefield.damage_enemy(e, spec.magnitude * ctx.damage_mult, ctx.card)
		ctx.battlefield.knockback_from(ctx.target_position, spec.radius,
			float(spec.get_param(&"push", 150.0)), EffectHandlers._tags(ctx))


## Spirale qui aspire les monstres vers son centre pendant toute sa duree.
## magnitude = vitesse d aspiration en px/s. Le vortex ne fait AUCUN degat :
## il sert a rassembler pour qu un autre sort fasse le travail.
class VortexPull extends EffectHandler:
	func get_key() -> StringName:
		return &"vortex_pull"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		# `spawn_vortex` pose un anneau generique : Spirale de sel et Maelstrom
		# aspiraient a l identique. La feuille de la carte est jouee au centre.
		Fx.impact(ctx.battlefield, ctx.target_position, Fx.COL_ARCANE,
			spec.radius * 0.5, Fx.card_sheet(ctx.card))
		ctx.battlefield.spawn_vortex(ctx.target_position, spec.radius,
			spec.duration, spec.magnitude, EffectHandlers._tags(ctx))


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
		# L effet est joue ICI et pas dans `dispel_at` pour deux raisons. D abord
		# le sort doit se voir meme quand il ne dissipe RIEN : `dispel_at` ne
		# dessine que s il a touche quelqu un, donc une Lumiere purifiante lancee
		# a cote laissait le joueur sans aucun retour — il ne pouvait pas savoir
		# si la carte etait partie. Ensuite c est le handler qui connait la carte,
		# donc sa feuille propre : sans elle, Vide d emprise et Lumiere purifiante
		# s affichaient d un seul et meme eclat arcanique.
		Fx.impact(ctx.battlefield, ctx.target_position, Fx.COL_ARCANE,
			spec.radius, Fx.card_sheet(ctx.card))
		ctx.battlefield.dispel_at(ctx.target_position, spec.radius, EffectHandlers._tags(ctx))


## Pioche immediate, SANS defausser. C est toute la difference avec discard_draw :
## celui-la echange des cartes, celui-ci en ajoute.
class DrawCards extends EffectHandler:
	func get_key() -> StringName:
		return &"draw_cards"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.draw(int(spec.get_param(&"count", 2)))
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_ARCANE, Fx.card_sheet(ctx.card))


## Les prochaines cartes lancees reviennent en main au lieu de partir.
## magnitude = nombre de cartes gardees.
class RetainNext extends EffectHandler:
	func get_key() -> StringName:
		return &"retain_next"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.retain_next(int(maxf(spec.magnitude, 1.0)))
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))


## Deux sorts chargent en meme temps pendant `duration` secondes.
class DoubleCast extends EffectHandler:
	func get_key() -> StringName:
		return &"double_cast"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		RunState.allow_double_cast(spec.duration)
		if ctx.battlefield != null:
			Fx.self_aura(ctx.battlefield, Fx.COL_HASTE, Fx.card_sheet(ctx.card))


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
		# Hasard du MONDE de la partie (fixe par la graine), et non un
		# generateur re-seme au hasard a chaque lancer.
		var rng: RandomNumberGenerator = RunState.world_rng
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


# --- Verbes de TERRAIN (chantier H) ---
#
# Le jeu n avait qu un seul sort de terrain, le Mur de pierre, et il ne savait que
# barrer un passage. Ces trois verbes posent autre chose sur le sol : une cible
# qu on prefere au mage, un courant qui renverse la descente, un etourdissement
# qui l arrete net. Aucun ne vise les PV en premier — ils achetent de la PLACE, ce
# qui est le levier que le joueur n avait pas.


## Plante un accessoire de terrain qui PROVOQUE : les monstres a portee le visent
## au lieu du mage et le frappent jusqu a l abattre.
##
## Il ne bloque AUCUNE cellule de navigation, contrairement au mur : un arbre
## qu on contourne serait un mur en bois, alors qu un arbre qu on va frapper est
## du temps achete. C est la difference qui justifie une carte de plus.
##
## params :
##   prop_hp     PV de l accessoire (obligatoire : sans PV il serait eternel)
##   kind        "tree" (defaut) ou "water"
##   zone_radius > 0 : l accessoire porte une zone au sol de ce rayon, alimentee
##               par `magnitude` degats/seconde et l element de la carte. La zone
##               MEURT avec lui — abattre l arbre coupe le poison.
##   slow_pct    ralentissement de la zone attachee, si elle existe
class TauntProp extends EffectHandler:
	func get_key() -> StringName:
		return &"taunt_prop"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		# Sans PV, un appat serait eternel ET invulnerable : il tiendrait la vague
		# loin du mage pour toujours. La valeur de repli n est qu un filet, les
		# cartes livrees donnent toujours la leur.
		if not spec.params.has(&"prop_hp"):
			spec = spec.duplicate()
			spec.params = spec.params.duplicate()
			spec.params[&"prop_hp"] = 80.0
		EffectHandlers.plant(spec, ctx, spec.radius,
			float(spec.get_param(&"zone_radius", 0.0)))


## Pose un objet de terrain QUI N ATTIRE PAS (ou peu) : ronces, fosse, arbre
## empoisonne, autel. Meme pose que `taunt_prop`, lue autrement :
##   radius      rayon de la ZONE au sol portee par l objet (0 = aucune)
##   magnitude   degats/seconde de cette zone (element de la carte)
##   duration    <= 0 : l objet reste jusqu a la fin du combat
## params :
##   kind          "tree", "bramble", "pit", "altar"
##   prop_hp       PV ; 0 = indestructible (seul le plafond le remplace)
##   taunt_radius  provocation, 0 par defaut. L autel en porte une PETITE : sans
##                 elle, pose loin du passage, il invoquerait pour toujours et
##                 vaudrait une infinite de sorts en Massacre.
##   slow_pct, vuln_mult   effets de la zone
##   summon_every, ally_damage, ally_duration   GENERATEUR d allies
##
## Pourquoi une cle a part plutot que `taunt_prop` sans portee : dans le .tres,
## `taunt_prop` DIT « attire ». Des ronces ecrites `taunt_prop` mentiraient a qui
## relit la carte, et le rayon de la spec y designe la provocation, pas la zone.
class PlaceTerrain extends EffectHandler:
	func get_key() -> StringName:
		return &"place_terrain"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		EffectHandlers.plant(spec, ctx, float(spec.get_param(&"taunt_radius", 0.0)),
			spec.radius)


## LA RIVIERE : une ligne d eau sur toute la largeur, un seul pont, jusqu a la
## fin du combat. Les monstres au sol passent par le pont ; volants et projectiles
## passent au-dessus (ils ignorent deja la grille de navigation).
##
## Le joueur vise la HAUTEUR ; le pont est tire au hasard parmi les colonnes qui
## gardent un chemin. Toutes les decisions sont detaillees sur
## `Battlefield.spawn_river`.
##
## duration <= 0 : jusqu a la fin du combat.
class River extends EffectHandler:
	func get_key() -> StringName:
		return &"terrain_river"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var y: float = NavGrid.row_center_y(NavGrid.river_row(ctx.target_position.y))
		# L effet propre a la carte est joue meme si la pose echoue : le joueur
		# doit voir que le sort est parti. Refus possible seulement si le terrain
		# a change pendant l incantation, l apercu ayant deja filtre la visee.
		Fx.impact(ctx.battlefield, Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, y),
			Fx.COL_FROST, 160.0, Fx.card_sheet(ctx.card))
		ctx.battlefield.spawn_river(ctx.target_position.y, spec.duration,
			Fx.card_sheet(ctx.card))


## Etourdit les monstres d une zone : vitesse NULLE, pas un ralentissement fort.
##
## Immobiliser est la chose la plus forte qu on puisse faire dans un jeu en temps
## reel, donc la duree est breve et la zone petite. Les monstres qui resistent au
## ralentissement (golem, behemoth, colosse, Chronos) y echappent : sans cette
## regle, leur immunite au controle ne voudrait plus rien dire.
class StunZone extends EffectHandler:
	func get_key() -> StringName:
		return &"stun_zone"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		var col: Color = Fx.color_for(EffectHandlers._tags(ctx))
		Fx.impact(ctx.battlefield, ctx.target_position, col, spec.radius,
			Fx.card_sheet(ctx.card))
		# Les degats d abord, l etourdissement ensuite : un monstre que le sort tue
		# n a pas besoin d etre fige, et l ordre inverse aurait fait compter comme
		# « figes » des monstres deja morts.
		if spec.magnitude > 0.0:
			for e in ctx.battlefield.enemies_in_radius(ctx.target_position, spec.radius):
				ctx.battlefield.damage_enemy(e, spec.magnitude * ctx.damage_mult, ctx.card)
		ctx.battlefield.stun_at(ctx.target_position, spec.radius, spec.duration,
			EffectHandlers._tags(ctx))


## Nappe d eau : un COURANT qui remonte les monstres vers le haut.
##
## Ce n est pas un champ de givre en bleu. Un ralentissement est un facteur : il
## tend vers zero sans jamais renverser la marche, et un monstre dans le givre
## avance toujours, juste moins vite. Le courant, lui, s ajoute au deplacement
## avec le signe oppose : dans la nappe, le monstre RECULE. Le joueur ne gagne
## plus du temps, il regagne du terrain — et c est la seule carte du jeu qui le
## fasse sur la duree (l Onde de repulsion, elle, pousse une fois et s arrete).
##
## Elle ne fait aucun degat, expres : avec des degats elle serait strictement
## meilleure que le Champ de givre, qui n aurait plus de raison d exister.
## magnitude = vitesse du courant en px/s a x1.
class WaterFlood extends EffectHandler:
	func get_key() -> StringName:
		return &"water_flood"

	func apply(spec: EffectSpec, ctx: CastContext) -> void:
		if ctx.battlefield == null:
			return
		# hp = 0 : une flaque ne se casse pas. Laisser les monstres la frapper leur
		# donnerait une cible alors qu ils devraient simplement patauger.
		ctx.battlefield.spawn_prop(TerrainProp.Kind.WATER, ctx.target_position,
			spec.duration, 0.0, 0.0, spec.magnitude, spec.radius,
			Fx.card_sheet(ctx.card), Fx.COL_FROST, EffectHandlers._tags(ctx))
