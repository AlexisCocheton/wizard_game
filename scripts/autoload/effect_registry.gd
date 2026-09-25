extends Node
## Table cle d'effet -> handler. Enregistrement explicite (pas de scan magique,
## fragile en headless). L'etage AUDIT croise cette table avec les .tres.

signal handler_registered(key: StringName)

var _handlers: Dictionary = {}  # StringName -> EffectHandler


func _ready() -> void:
	register_defaults()


func register_defaults() -> void:
	_handlers.clear()
	for h in [
		EffectHandlers.DamageSingle.new(),
		EffectHandlers.PierceLine.new(),
		EffectHandlers.GroundZone.new(),
		EffectHandlers.SlowEnemyGauge.new(),
		EffectHandlers.SelfHaste.new(),
		EffectHandlers.CostReduction.new(),
		EffectHandlers.DrawBoost.new(),
		EffectHandlers.SummonAlly.new(),
		EffectHandlers.DiscardDraw.new(),
		EffectHandlers.HasteEnemiesBoon.new(),
		EffectHandlers.RemoveCards.new(),
		EffectHandlers.BuildWall.new(),
		EffectHandlers.DamagePerEnemy.new(),
		EffectHandlers.ReverseEnemies.new(),
		EffectHandlers.EmpowerNext.new(),
		EffectHandlers.DiscardHandForSpeed.new(),
		EffectHandlers.Knockback.new(),
		EffectHandlers.VortexPull.new(),
		EffectHandlers.DispelZone.new(),
		EffectHandlers.DrawCards.new(),
		EffectHandlers.RetainNext.new(),
		EffectHandlers.DoubleCast.new(),
		EffectHandlers.MeteorStorm.new(),
		# Chantier H — sorts de TERRAIN. Ils ne visent pas les PV : ils posent une
		# cible qu on prefere au mage, un courant qui renverse la descente, un
		# etourdissement qui l arrete net. Le Mur de pierre etait jusqu ici le seul
		# sort de terrain du jeu, et il ne savait que barrer un passage.
		EffectHandlers.TauntProp.new(),
		EffectHandlers.StunZone.new(),
		EffectHandlers.WaterFlood.new(),
	]:
		register(h)


func register(handler: EffectHandler) -> void:
	var key: StringName = handler.get_key()
	if key == &"":
		push_error("Handler sans cle : %s" % handler)
		return
	if _handlers.has(key):
		push_error("Cle d'effet dupliquee : %s" % key)
		return
	_handlers[key] = handler
	handler_registered.emit(key)


func has_key(key: StringName) -> bool:
	return _handlers.has(key)


func keys() -> Array:
	return _handlers.keys()


## Applique un effet. Renvoie false si aucun handler ne repond a la cle.
func dispatch(spec: EffectSpec, ctx: CastContext) -> bool:
	if spec == null:
		return false
	var handler: EffectHandler = _handlers.get(spec.key)
	if handler == null:
		# push_error part sur stderr : la gate du harnais transforme ca en build rouge.
		push_error("Aucun handler pour la cle d'effet '%s'" % spec.key)
		return false
	handler.apply(spec, ctx)
	return true


## Applique toute la pipeline d'effets d'une carte.
func cast(card: SpellCard, ctx: CastContext) -> void:
	if card == null:
		return
	# Un POUVOIR PASSIF ne passe plus JAMAIS par ici : il est equipe hors deck et
	# ses regles sont relues en continu par RunState. Le garde reste pour qu une
	# sauvegarde ancienne, dont le deck contiendrait encore un id de passif, ne
	# le lance pas comme un sort sans effet.
	if card.is_passive:
		return
	# Compteur d usage lu par la fiche du grimoire ("lance N fois"). Pose ici et
	# non dans l interface de la main : c est le SEUL point par ou passe un sort
	# reellement lance, quel que soit l ecran qui l a declenche.
	ChallengeTracker.bump(StringName("card_uses:%s" % card.id))
	# Compteur de lancers DE LA PARTIE, qui mene a l amelioration du sort
	# (chantier G). Distinct du compteur ci-dessus, qui est un total de carriere
	# affiche au grimoire : celui-la est remis a zero a chaque niveau.
	RunState.note_cast(card)
	ctx.card = card
	# Le son PROPRE au sort. Trois sons generiques couvraient 45 cartes : a
	# l oreille, tous les sorts etaient le meme.
	if card.sfx_key != &"":
		AudioBus.play_sfx(card.sfx_key)
	# Focalisation : le multiplicateur est consomme par le sort suivant, quel qu il soit.
	ctx.damage_mult = RunState.take_next_spell_multiplier()
	# AMELIORATION DE LA CARTE (chantier G) : les valeurs appliquees ne sortent
	# plus de `card.effects` mais de RunState.cast_specs(), qui rend des COPIES
	# portant la voie retenue dans cette partie. Les EffectSpec du .tres sont des
	# Resources partagees et mises en cache par Godot : les modifier ferait fuir
	# l amelioration dans le grimoire et dans la partie suivante.
	var specs: Array[EffectSpec] = RunState.cast_specs(card)
	for spec in specs:
		dispatch(spec, ctx)
	# PASSIF "Debordement" (legendaire) : chaque sort est RESOLU DEUX FOIS. La
	# regle change ici, au point unique par ou passe tout sort reellement lance —
	# aucune carte n a besoin de le savoir. Le garde  empeche la
	# seconde resolution de se dedoubler a son tour (2 sorts, pas 4).
	if not _resolving and RunState.has_passive(&"passive_twin_cast"):
		_resolving = true
		for spec2 in specs:
			dispatch(spec2, ctx)
		_resolving = false


## Vrai pendant la seconde resolution de "Debordement" : voir cast().
var _resolving: bool = false
