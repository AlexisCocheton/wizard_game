class_name GameController
extends Node2D
## Chef d orchestre d une partie : relie vagues, incantation, HUD et fin de niveau.
##
## IMPORTANT : SpeedGauge.tick() n est appele QUE d ici. Un second appelant
## doublerait silencieusement la montee automatique du multiplicateur.
##
## Modes (GameEnums.Mode) :
##   Exploration : vagues ecrites du niveau, choix de carte a chaque montee de niveau.
##   Infini      : UN niveau prolonge sans fin, vagues par budget a travers les
##                 cinq mondes, choix de carte toutes les N vagues.
##   Massacre    : le niveau infini A PART (MassacreMode) : monstres de tous les
##                 niveaux melanges, boss de tout le jeu, fond fixe.
## Dans tous les modes, les cartes proposees viennent de RunState.levelup_pool().

signal level_won()
signal level_lost()
signal cards_offered(cards: Array[SpellCard])
## CHANTIER W8 : une carte BRULEE attend d etre visee (le HUD affiche la carte a
## glisser), puis elle est partie.
signal burn_aim_requested(card: SpellCard)
signal burn_resolved(card: SpellCard)

## Modes sans fin (Infini et Massacre) : un choix de 3 cartes toutes les N
## vagues nettoyees.
const WAVES_PER_CHOICE: int = 2

@onready var battlefield: Battlefield = $Battlefield
@onready var caster: Caster = $Caster
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var backdrop: BattleBackdrop = get_node_or_null("Backdrop")
@onready var mage: MageView = get_node_or_null("Mage")

var level_def: LevelDef = null
var mode: GameEnums.Mode = GameEnums.Mode.EXPLORATION
var running: bool = false
## La partie est TERMINEE (mort ou victoire). Distinct de `running`, que le smoke
## met a faux pour piloter la simulation lui-meme : confondre les deux rendait la
## partie de test inerte. Ce drapeau-la ne dit pas "qui fait avancer le temps",
## il dit "il n y a plus rien a faire avancer".
var _ended: bool = false
## Vrai en test headless : on ne change pas de scene a la fin.
var headless_mode: bool = false


func _ready() -> void:
	var payload: Dictionary = SceneRouter.payload
	var level_id: StringName = payload.get("level_id", &"lvl_01")
	mode = payload.get("mode", GameEnums.Mode.EXPLORATION)
	# OUTILS DU TESTEUR (vague 8) : une vague composee dans l onglet TEST n a pas
	# de .tres, son niveau est fabrique par TesterRun (meme principe que le
	# Massacre) et sa vitesse de depart posee apres start_level().
	if TesterRun.is_test_payload(payload):
		TesterRun.start_in(self, payload)
		return
	# MODES (chantier M) : le Massacre n a pas de .tres, son niveau est fabrique.
	var def: LevelDef = MassacreMode.resolve_level(level_id, mode)
	if def == null:
		push_error("Niveau introuvable : %s" % level_id)
		return
	start_level(def, mode)


func start_level(def: LevelDef, level_mode: GameEnums.Mode) -> void:
	level_def = def
	mode = level_mode
	# Sans cette remise a zero, REJOUER apres une defaite laisserait la partie
	# inerte : le drapeau de fin serait encore leve.
	_ended = false

	SpeedGauge.reset()
	RunState.reset()
	RunState.current_level_def = def
	RunState.mode = level_mode

	caster.battlefield = battlefield
	battlefield.clear_all()

	RunState.build_deck_from_list(_build_deck())
	RunState.draw(GameConfig.START_HAND_SIZE)
	# PASSIFS EQUIPES AU DECK : actifs DES LE DEBUT du combat, mais SEULEMENT en
	# Infini et en Massacre, et des l acte 2 atteint (retouche du 30/09). Un
	# niveau de campagne part sans eux : ses passifs viennent des montees de
	# niveau. APRES reset(), qui vide la barre, et apres current_level_def /
	# mode, dont depend la regle.
	RunState.equip_saved_passives()

	# MODES (chantier M). L Infini traverse les cinq mondes (le lieu pese sur le
	# tirage, le fond change) ; le Massacre les MELANGE : aucun monde, donc aucun
	# poids local et aucun changement de fond, et ses paliers tirent dans les
	# boss de tout le jeu.
	if mode == GameEnums.Mode.INFINITE:
		spawner.setup_procedural(battlefield, _procedural_pool(), _boss_pool())
	elif mode == GameEnums.Mode.MASSACRE:
		spawner.setup_procedural(battlefield, _procedural_pool(),
			MassacreMode.boss_pool(), 0, {}, false)
	else:
		spawner.setup(battlefield, def.waves)

	# Branchement idempotent : start_level() peut etre rappele (rejouer, tests).
	_connect_once(spawner.wave_cleared, _on_wave_cleared)
	_connect_once(spawner.all_waves_cleared, _on_all_cleared)
	_connect_once(SpeedGauge.died, _on_died)
	_connect_once(battlefield.mage_hit, _on_mage_hit)
	_connect_once(battlefield.enemy_killed, _on_enemy_killed_for_challenges)
	_connect_once(RunState.level_up, _on_level_up)
	# L amelioration d un sort est proposee par RunState au huitieme lancer : on
	# ecoute le signal plutot que de compter ici, pour que le comptage reste au
	# point de passage unique des sorts (EffectRegistry.cast).
	_connect_once(RunState.upgrade_ready, _on_upgrade_ready)
	_connect_once(RunState.purge_requested, _on_purge_requested)
	# CHANTIER W8 : echange de passif en pause, vague qui traine.
	_connect_once(RunState.passive_swap_needed, _on_passive_swap_needed)
	_connect_once(spawner.wave_overtime, _on_wave_overtime)

	var hud: Node = get_node_or_null("HUD")
	if hud != null and hud.has_method("bind"):
		hud.bind(self)
	if backdrop != null:
		backdrop.setup(def.terrain)
	if mage != null:
		mage.bind(caster)
	_connect_once(spawner.wave_started, _on_wave_started)
	_connect_once(SpeedGauge.speed_lost, _on_speed_lost)
	AudioBus.play_music(&"battle")

	spawner.start_next()
	running = true


func _connect_once(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


## Deck de la partie selon le mode.
##   Exploration : la liste pre-etablie du niveau (une entree = un exemplaire).
##   Infini et Massacre : deck de depart SIMPLE — le deck compose par le joueur
##                 s il est valide, sinon les communes. Les cartes fortes arrivent
##                 par les choix.
func _build_deck() -> Array[SpellCard]:
	if GameEnums.is_endless(mode):
		var ids: Array = SaveData.massacre_deck()
		if DeckRules.is_valid(ids):
			var chosen: Array[SpellCard] = DeckRules.resolve(ids)
			if chosen.size() >= DeckRules.MIN_CARDS:
				return chosen
	# Plus AUCUN passif dans le deck : ils sont equipes hors deck et agissent des
	# le debut du combat (voir RunState.equipped_passives). Les melanger aux
	# cartes obligeait a les piocher puis a les incanter pour en profiter.
	if level_def != null and not level_def.exploration_deck.is_empty():
		var expl: Array[SpellCard] = []
		for c: SpellCard in level_def.exploration_deck:
			if c != null and not c.is_passive:
				expl.append(c)
		return expl
	return DeckRules.resolve(DeckRules.default_deck_ids())


## Pool des modes sans fin : les monstres du niveau, boss exclus. Pour le
## Massacre, le "niveau" est celui de MassacreMode, dont le pool reunit deja les
## monstres de tous les niveaux.
func _procedural_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var source: Array = level_def.enemy_pool if level_def != null else []
	if source.is_empty():
		source = ContentDB.enemies.values()
	for d in source:
		if d != null and not d.is_boss():
			out.append(d)
	return out


func _boss_pool() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for d: EnemyDef in ContentDB.enemies.values():
		if d.is_boss():
			out.append(d)
	return out


func _process(delta: float) -> void:
	if not running:
		return
	simulate(delta)


## Extrait pour que le smoke test puisse piloter la partie avec un delta fixe.
## En pause pendant un choix de carte : rien n avance tant que le joueur n a pas choisi.
func simulate(delta: float) -> void:
	if not RunState.pending_offer.is_empty():
		return
	# AMELIORATION DE CARTE en attente : meme regle que le choix de carte, et pour
	# la meme raison. Le joueur a trois compromis a LIRE, chacun avec un gain et un
	# prix ; les lire pendant que les monstres descendent, c est soit choisir au
	# hasard, soit prendre un coup en lisant.
	if RunState.pending_upgrade_card != null:
		return
	# Epuration, passif a echanger, carte brulee a viser (voir la fonction).
	if game_frozen_by_choice():
		return
	SpeedGauge.tick(delta)   # UNIQUE appelant
	# La mort (ou la victoire) declenche un CHANGEMENT DE SCENE depuis ce tick :
	# le champ de bataille est alors en cours de liberation. Continuer a le
	# simuler plantait la partie au boss du niveau 4.
	if _ended:
		return
	# La pioche suit le temps du MONDE : a x4, quatre fois plus de monstres
	# arrivent, il faut quatre fois plus de cartes pour y repondre.
	RunState.tick(SpeedGauge.world_delta(delta))
	# OBJECTIFS : horloge en temps REEL (voir RunState, OBJECTIFS PARAMETRES).
	RunState.advance_clock(delta)
	caster.tick(delta)
	battlefield.simulate(delta)
	# OBJECTIFS : profondeur atteinte par les monstres (no_enemy_past).
	RunState.note_enemy_depths(battlefield.enemies)
	# OBJECTIFS : chemin des monstres vivants, pour le bandeau (enemy_travel).
	RunState.note_enemy_travel_live(battlefield.enemies)
	# Une carte lancee peut tuer le dernier monstre et terminer le niveau : on
	# reverifie avant de faire apparaitre la vague suivante.
	if _ended:
		return
	spawner.tick(delta)
	if not spawner.active and not spawner.is_finished():
		spawner.start_next()


## Joue une carte a une position visee.
##
## `target_pos` vient du glisser-deposer : c est l endroit ou le joueur a relache
## son doigt. Chaque mode de ciblage l interprete differemment :
##   POSITION  -> centre de la zone / du mur
##   DIRECTION -> definit la direction du tir depuis le mage
##   TARGET    -> le monstre le plus proche du point relache
##   NONE      -> ignore, l effet agit sur le mage
func play_card(card: SpellCard, target_pos: Vector2 = Vector2.INF,
		target_enemy: Object = null) -> bool:
	# Pre-cast : on accepte un second sort pendant le chargement du premier. Il
	# partira a la suite, vise ou le joueur a relache. Un troisieme le remplace.
	if not running or card == null:
		return false
	if not RunState.pending_offer.is_empty():
		return false
	if RunState.pending_upgrade_card != null:
		return false
	if game_frozen_by_choice():
		return false
	# Une carte a viser exige un point : sans lui, on refuse plutot que de
	# lancer le sort a un endroit arbitraire.
	if requires_aim(card) and target_pos == Vector2.INF:
		return false
	# Un objet qui BLOQUE ne se pose pas la ou il couperait tout chemin des
	# monstres au sol : la carte reste en main plutot que d etre depensee pour rien.
	if not aim_allowed(card, target_pos):
		return false
	if not RunState.play_card(card):
		return false
	return caster.queue_next(card, _make_cast_context(card, target_pos, target_enemy))


## Le contexte d un lancer vise : ce que le point relache veut dire pour CE mode
## de ciblage. Extrait de play_card (chantier W8) pour que la carte BRULEE, qui
## part sans incantation, interprete le geste exactement comme une carte de la
## main — meme apercu, meme point, meme cible.
func _make_cast_context(card: SpellCard, target_pos: Vector2,
		target_enemy: Object) -> CastContext:
	var ctx := CastContext.make(battlefield, card)
	ctx.caster = self
	var aim: Vector2 = target_pos if target_pos != Vector2.INF else _default_aim()

	match card.targeting:
		GameEnums.Targeting.POSITION:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy
		GameEnums.Targeting.DIRECTION:
			var origin: Vector2 = _mage_position()
			var d: Vector2 = aim - origin
			ctx.direction = d.normalized() if d.length() > 1.0 else Vector2.UP
			ctx.target_position = aim
			ctx.target_enemy = target_enemy
		GameEnums.Targeting.TARGET:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy if target_enemy != null \
				else battlefield.enemy_nearest_to(aim)
		_:
			ctx.target_position = aim
			ctx.direction = Vector2.UP
			ctx.target_enemy = target_enemy
	return ctx


## La carte peut-elle etre lachee a ce point ? Lu par le HUD pour peindre
## l apercu en rouge AVANT le lacher. Voir EffectHandlers.placement_allowed.
func aim_allowed(card: SpellCard, point: Vector2) -> bool:
	return EffectHandlers.placement_allowed(card, point, battlefield)


## Vrai si la carte doit etre glissee sur le terrain pour etre jouee.
func requires_aim(card: SpellCard) -> bool:
	return card != null and card.targeting != GameEnums.Targeting.NONE


## Publique : CastContext s en sert comme origine des sorts (voir caster_position).
func mage_position() -> Vector2:
	return Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y)


func _mage_position() -> Vector2:
	return mage_position()


func _default_aim() -> Vector2:
	return Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5, GameConfig.MAGE_LINE_Y - 400.0)


# --- Choix de cartes ---

func _offer_cards() -> void:
	var cards: Array[SpellCard] = RunState.offer_choices(GameConfig.LEVEL_UP_CHOICES)
	if cards.is_empty():
		return
	cards_offered.emit(cards)


## Le joueur prend l option i : elle rejoint la defausse et la partie reprend.
func choose_card(i: int) -> SpellCard:
	return RunState.pick_offer(i)


## BRULER l option i : la carte n entre jamais dans le deck et part SANS
## INCANTATION — la ou le joueur la vise (chantier W8).
##
## Avant, elle partait d office au centre de la moitie haute (540, 675) : un mur
## ou une zone y tombaient souvent dans le vide, et bruler etait un pari sur la
## place des monstres plutot qu un choix. Desormais :
##   - une carte SANS visee (sur le mage, sur la main) part tout de suite ;
##   - une carte a viser reste EN ATTENTE (RunState.burned_card), la partie en
##     pause, jusqu a ce que le joueur la glisse sur le terrain avec le geste
##     habituel (meme apercu que la main) : cast_burned(point) ;
##   - `target_pos` donne d emblee (tests, banc) la lance tout de suite.
## Un PASSIF ne se brule pas (RunState.burn_offer le refuse, l offre reste
## ouverte) : rend null.
func burn_card(i: int, target_pos: Vector2 = Vector2.INF) -> SpellCard:
	var card: SpellCard = RunState.burn_offer(i)
	if card == null:
		return null
	if not requires_aim(card) or target_pos != Vector2.INF:
		if not cast_burned(target_pos):
			# Point refuse (mur qui couperait tout chemin) : la carte reste a viser.
			burn_aim_requested.emit(card)
		return card
	burn_aim_requested.emit(card)
	return card


## La carte brulee en attente vient d etre lachee en `target_pos`. Rend vrai si
## elle est partie. Refusee (et toujours en attente) si le point est interdit,
## exactement comme une carte de la main : un mur qui couperait tout chemin ne
## se pose pas, et la carte n est pas perdue pour autant.
func cast_burned(target_pos: Vector2 = Vector2.INF) -> bool:
	var card: SpellCard = RunState.burned_card
	if card == null:
		return false
	if requires_aim(card) and target_pos == Vector2.INF:
		return false
	if requires_aim(card) and not aim_allowed(card, target_pos):
		return false
	RunState.take_burned()
	EffectRegistry.cast(card, _make_cast_context(card, target_pos, null))
	burn_resolved.emit(card)
	return true


## MEDITER plutot que prendre une carte : +1 XP de carte a chaque carte en main
## (RunState.meditate_offer). Rend le nombre de cartes qui ont medite.
func meditate() -> int:
	return RunState.meditate_offer()


# --- Amelioration des cartes en combat ---

## L ecran de choix d amelioration, cree a la premiere occasion et reutilise.
## Cree par CODE et non pose dans Game.tscn : il n existe que quelques secondes
## par partie, et le construire a la demande evite un noeud invisible qui
## traverserait toutes les scenes du jeu.
var _upgrade_panel: CardUpgradePanel = null


func _on_upgrade_ready(card: SpellCard, paths: Array) -> void:
	AudioBus.play_sfx(&"level_up")
	if headless_mode:
		# EN TEST HEADLESS, PERSONNE NE PEUT TOUCHER L ECRAN. Laisser l offre en
		# attente bloque `simulate()` pour toujours : le banc a rendu 0 victoire
		# sur 30 aux SEPT niveaux, toutes les parties mourant sur le garde-fou de
		# 900 s. Le choix doit donc etre tranche ici, tout de suite.
		#
		# On prend la voie que prendrait un joueur RAISONNABLE (AutoPick) :
		# l identite du sort en forme forte, sinon la vitesse. Ce n etait plus
		# "la premiere" depuis que l offre est tiree et melangee : la premiere
		# etait une voie au hasard, et le banc mesurait un joueur qui choisit
		# a pile ou face (lvl_16 : 25 -> 14 victoires sur 30, jeu inchange).
		RunState.pick_upgrade(AutoPick.upgrade_index(card, paths))
		return
	var panel: CardUpgradePanel = _ensure_upgrade_panel()
	panel.show_paths(card, paths)


func _ensure_upgrade_panel() -> CardUpgradePanel:
	if _upgrade_panel != null and is_instance_valid(_upgrade_panel):
		return _upgrade_panel
	_upgrade_panel = CardUpgradePanel.new()
	_upgrade_panel.name = "CardUpgradePanel"
	_upgrade_panel.path_chosen.connect(_on_upgrade_path_chosen)
	_upgrade_panel.declined.connect(_on_upgrade_declined)
	# DANS le CanvasLayer du HUD : pose sur le Node2D de la partie, un Control
	# suivrait la camera et les coordonnees du terrain au lieu de l ecran.
	var hud: Node = get_node_or_null("HUD")
	if hud != null:
		hud.add_child(_upgrade_panel)
	else:
		add_child(_upgrade_panel)
	return _upgrade_panel


## EPURATION (vague 8) : le choix des cartes a retirer. Meme partage que pour
## l amelioration : en headless, personne ne peut toucher l ecran, AutoPick
## tranche tout de suite ; sinon l ecran DeckBrowser se pose sur le HUD et
## tranche lui-meme a VALIDER. Plusieurs parties peuvent ecouter le signal
## (tests) : la premiere qui tranche vide `pending_purge`, les autres s arretent.
##
## UN SEUL ecran : une seconde demande pendant le choix (Debordement) releve le
## plafond de l ecran deja ouvert, `pending_purge` portant le cumul.
var _purge_screen: Control = null


func _on_purge_requested(_max_count: int) -> void:
	if RunState.pending_purge <= 0:
		return
	if headless_mode:
		RunState.resolve_purge(AutoPick.purge_choice(RunState.run_deck_groups(),
			RunState.pending_purge))
		return
	var ouvert: bool = _purge_screen != null and is_instance_valid(_purge_screen)
	if ouvert and not _purge_screen.is_queued_for_deletion():
		DeckBrowser.set_overlay_max(_purge_screen, RunState.pending_purge)
		return
	_purge_screen = DeckBrowser.purge_overlay(RunState.pending_purge)
	var hud: Node = get_node_or_null("HUD")
	if hud != null:
		hud.add_child(_purge_screen)
	else:
		add_child(_purge_screen)


## On CACHE le panneau AVANT de trancher : depuis le chantier W8, trancher peut
## ouvrir aussitot l offre d une autre carte (meditation : deux cartes franchissent
## leur palier ensemble), et cette offre REMONTRE le panneau. Le cacher apres
## coup laissait la partie en pause derriere un ecran invisible.
func _on_upgrade_path_chosen(index: int) -> void:
	if _upgrade_panel != null and is_instance_valid(_upgrade_panel):
		_upgrade_panel.visible = false
	RunState.pick_upgrade(index)


func _on_upgrade_declined() -> void:
	if _upgrade_panel != null and is_instance_valid(_upgrade_panel):
		_upgrade_panel.visible = false
	RunState.decline_upgrade()


func _on_level_up(_new_level: int) -> void:
	AudioBus.play_sfx(&"level_up")
	if mode == GameEnums.Mode.EXPLORATION:
		_offer_cards()


func _on_wave_started(_index: int, wave: WaveDef) -> void:
	# Passif "Compagnon fidele" : un allie a chaque nouvelle vague. C est ici, et
	# pas dans EffectRegistry, parce qu un passif ne s execute pas une fois : il
	# change une regle pour tout le combat.
	#
	# has_passive() teste DEJA le seuil de vitesse : si la jauge est retombee a
	# 100 % juste avant la vague, l allie n arrive pas. C est voulu — un passif
	# ne recompense que le joueur qui tient sa vitesse.
	if battlefield != null:
		if RunState.has_passive(&"passive_wave_ally"):
			battlefield.spawn_ally(12.0, 10.0)
		# Passif "Ecorce vive" : un mur pousse en travers du chemin a chaque vague.
		# Il ne tue rien, il ACHETE DU TEMPS — c est le passif commun le plus
		# lisible : on voit exactement ce qu il fait.
		if RunState.has_passive(&"passive_start_wall"):
			var au_milieu := Vector2(GameConfig.BATTLEFIELD_WIDTH * 0.5,
				GameConfig.MAGE_LINE_Y * 0.62)
			# Un mur d ECORCE est de nature (vague 8) : les monstres qui
			# craignent la nature le frappent moins fort.
			battlefield.spawn_wall(au_milieu, 170.0, 14.0, 60.0, [GameEnums.DamageTag.NATURE])
	if wave != null and (wave.is_boss or wave.is_miniboss):
		AudioBus.play_sfx(&"boss")
		AudioBus.play_voice(&"attack")
		if wave.is_boss:
			AudioBus.play_music(&"boss")
	else:
		AudioBus.play_sfx(&"wave_start")


## Le mage vient de perdre de la vitesse, c est-a-dire de la VIE : depuis le
## 26 septembre c est la meme chose. Ce crochet remplace l ancien _on_hp_changed
## ET l ancien _on_shield_collapsed, qui annoncaient deux evenements distincts
## d un systeme a deux reserves. Il n y en a plus qu un.
func _on_speed_lost(_amount: int, _percent: int) -> void:
	AudioBus.play_sfx(&"hp_lost")
	# La VOIX en plus du bruitage : le bruitage dit "quelque chose a frappe",
	# la voix dit "c est MOI qui ai pris". A 400 % de vitesse, ou tout va vite,
	# c est la difference entre un bruit de fond et une information.
	AudioBus.play_voice(&"hurt")
	# L objectif "ne jamais laisser retomber la jauge" se juge ici : toute perte
	# de vitesse est desormais une perte de vie, les deux objectifs se lisent au
	# meme endroit (voir objective_checker.gd, qui les distingue toujours).
	RunState.note_speed_drop()


func _on_mage_hit(_dmg: int, source: EnemyDef) -> void:
	RunState.note_damage_taken(source)
	# PASSIF "Verrou temporel" (legendaire) : un coup ne coute que la moitie de
	# la vitesse qu il devrait. Depuis que la vitesse EST la vie, c est la seule
	# reduction de DEGATS du jeu — d ou son seuil tres haut : il faut deja avoir
	# tenu 300 % pour en profiter.
	#
	# On RE-POUSSE la jauge apres coup au lieu de modifier SpeedGauge.take_hit() :
	# le chemin du coup reste unique et intouche, et le passif se lit comme ce
	# qu il est, une exception rendue au joueur.
	#
	# `heal()` et non `set_speed_percent()` : si le coup vient de tuer le mage,
	# heal() refuse — on ne ressuscite pas avec un passif, meme legendaire. Et
	# le passif ne peut donc pas annuler un coup mortel, seulement adoucir ceux
	# qu on survit.
	#
	# LE SEUIL SE JUGE SUR LA VITESSE D AVANT LE COUP. On ne peut pas passer par
	# has_passive(), qui lit la vitesse COURANTE : a cet instant le coup est deja
	# encaisse, et un contact de 24 points recu a 310 % laisse le mage a 286 %,
	# sous le seuil de 300. Le passif ne se serait donc JAMAIS declenche sur les
	# coups qu il est precisement cense adoucir. Le defaut existait deja avant le
	# passage a la vitesse-vie, mais il y etait invisible : la chute forfaitaire
	# de 60 points sautait le seuil d un bloc et le joueur mettait l absence
	# d effet sur le compte de la punition. Verrouille par test_speed_is_life.
	var avant: int = battlefield.speed_before_hit if battlefield != null else 100
	if avant > 100 and _passive_equipped_at(&"passive_shield_keeper", avant):
		var perdu: int = avant - SpeedGauge.speed_percent
		if perdu > 0:
			SpeedGauge.heal(perdu / 2)


## Un passif de cette cle serait-il actif A `percent` % de vitesse ? Meme regle
## que RunState.has_passive(), mais sur une vitesse DONNEE au lieu de la vitesse
## courante. Sert aux crochets qui s executent APRES que la jauge a bouge.
func _passive_equipped_at(key: StringName, percent: int) -> bool:
	for c: SpellCard in RunState.equipped_passives:
		if c == null or percent < c.speed_threshold:
			continue
		for spec in c.effects:
			if spec != null and spec.key == key:
				return true
	return false


func _on_enemy_killed_for_challenges(_def: EnemyDef) -> void:
	ChallengeTracker.bump(&"enemies_killed")
	# OBJECTIFS : instant de la mort (multi_kill) et volants (kill_flying).
	RunState.note_kill(_def)
	# Compteur PAR ESPECE, affiche sur la fiche du bestiaire ("N vaincus").
	if _def != null:
		ChallengeTracker.bump(StringName("kills:%s" % _def.id))


func _on_wave_cleared(index: int) -> void:
	RunState.wave_index = index + 1
	RunState.wave_changed.emit(RunState.wave_index)
	ChallengeTracker.record_best(&"max_speed_reached", SpeedGauge.speed_percent)
	# MODES (chantier M) : les deux modes sans fin comptent pour les succes de
	# survie, et chaque vague nettoyee met le record a jour tout de suite. Le
	# tenir ici plutot qu a l ecran de defaite, c est ne pas le perdre quand le
	# joueur ABANDONNE depuis la pause, qui ne passe par aucun ecran de fin.
	if GameEnums.is_endless(mode):
		ChallengeTracker.record_best(&"massacre_wave", RunState.wave_index)
		SaveData.record_run_waves(level_def.id if level_def != null else &"",
			mode, RunState.wave_index)
	# PLUS DE RECOMPENSE DE BOSS D OFFICE (chantier P). Un mini-boss offrait trois
	# epiques et un boss trois legendaires, tirees dans TOUT le catalogue : le
	# pool de montee de niveau n aurait rien voulu dire, et un niveau d acte 1
	# distribuait des legendaires. Les cartes fortes s obtiennent maintenant par
	# les objectifs du niveau (LevelDef.objective_rewards). La vague de boss suit
	# donc la cadence ordinaire.
	# Les offres des modes sans fin passent par RunState.offer_choices(), qui
	# tire dans RunState.levelup_pool(level_def, mode) : hors campagne, toutes
	# les cartes obtenues (niveau fabrique du Massacre compris).
	if GameEnums.is_endless(mode) and RunState.wave_index % WAVES_PER_CHOICE == 0:
		_offer_cards()


func _on_all_cleared() -> void:
	# OBJECTIFS : photo de la vitesse et du temps AU MOMENT de la victoire.
	RunState.note_victory()
	running = false
	_ended = true
	level_won.emit()
	AudioBus.play_music(&"victory", false)
	AudioBus.play_sfx(&"victory")
	AudioBus.play_voice(&"victory")
	# Une partie de test revient aux outils du testeur, sans ecran de victoire
	# (qui ouvrirait un "niveau suivant" et donnerait des recompenses).
	if not headless_mode and not TesterRun.end_run(level_def, true):
		SceneRouter.goto(SceneRouter.VICTORY, {"level_id": level_def.id})


## ABANDON — le joueur quitte le combat depuis l ecran de pause.
##
## Distinct d une defaite : aucune statistique, aucun ecran de fin, aucun signal.
## Il n a pas perdu, il s en va.
##
## `_ended` AVANT tout le reste : la partie est en pause, donc `_process` ne
## tourne pas, mais le smoke et les tests pilotent `simulate()` a la main. Sans
## ce drapeau la simulation continuerait sur un champ de bataille en cours de
## liberation pendant le changement de scene — exactement le plantage deja vu au
## boss du niveau 4.
func abandon_run() -> void:
	_ended = true
	running = false
	# Le record d un mode sans fin est deja a jour (_on_wave_cleared) ; il faut
	# encore l ECRIRE, puisqu aucun ecran de fin ne le fera.
	if GameEnums.is_endless(mode):
		SaveData.save_profile()


func _on_died() -> void:
	running = false
	_ended = true
	level_lost.emit()
	AudioBus.play_music(&"defeat", false)
	AudioBus.play_sfx(&"defeat")
	AudioBus.play_voice(&"death")
	if not headless_mode and not TesterRun.end_run(level_def, false):
		SceneRouter.goto(SceneRouter.DEFEAT, {"level_id": level_def.id,
			"waves": RunState.wave_index})


# =====================================================================
# CHANTIER W8 — choix modaux de la montee de niveau, vagues qui trainent.
# Section a part pour se fusionner sans toucher au reste : chaque accroche
# ailleurs dans ce fichier est une ligne qui appelle une fonction d ici.
# =====================================================================

## LA PARTIE EST-ELLE FIGEE PAR UN CHOIX ? Un seul etat, lisible par tous (HUD,
## tests, smoke) : tant qu il est vrai, simulate() n avance rien et play_card()
## refuse. Les cinq choix modaux du combat, pour la meme raison a chaque fois —
## le joueur LIT, il ne doit pas encaisser en lisant :
##   - une offre de cartes (montee de niveau) ;
##   - une amelioration de sort (trois voies a comparer) ;
##   - une EPURATION (le joueur parcourt son deck) ;
##   - un quatrieme PASSIF : le joueur designe celui qu il retire, ou refuse ;
##   - une carte BRULEE a viser : elle part sans incantation, la ou le joueur la
##     lache, et viser pendant que tout bouge rendrait bruler pire que prendre.
## (Le commentaire vit ici et pas dans simulate() : test_balance lit le debut de
## simulate() et exige d y trouver la sortie sur `_ended`.)
func game_frozen_by_choice() -> bool:
	return not RunState.pending_offer.is_empty() \
		or RunState.pending_upgrade_card != null \
		or RunState.pending_purge > 0 \
		or RunState.pending_passive != null \
		or RunState.burned_card != null


## Le panneau d echange de passif, cree a la premiere occasion (meme raison que
## le panneau d amelioration : il n existe que quelques secondes par partie).
var _passive_swap_panel: PassiveSwapPanel = null


## Un quatrieme passif est pris alors que les trois emplacements sont pleins.
## Avant, le choix se faisait en touchant une pastille du RAIL, sans pause et
## sans moyen de refuser — et les pastilles etant triees par seuil, l indice
## touche n etait pas l emplacement : on pouvait retirer le mauvais passif. Le
## panneau montre les trois CARTES equipees, chacune liee a SON emplacement
## (indice dans RunState.equipped_passives), plus la nouvelle et un REFUS.
func _on_passive_swap_needed(card: SpellCard) -> void:
	if card == null:
		return
	if headless_mode:
		# EN TEST HEADLESS, PERSONNE NE PEUT TOUCHER L ECRAN, et la partie est
		# maintenant en pause tant que l echange attend. On garde les trois
		# passifs equipes : c est ce que faisait le jeu d avant pour le banc
		# (l echange restait en attente sans jamais aboutir), donc les mesures
		# d equilibrage restent comparables.
		RunState.decline_pending_passive()
		return
	_ensure_passive_swap_panel().show_swap(card, RunState.equipped_passives)


func _ensure_passive_swap_panel() -> PassiveSwapPanel:
	if _passive_swap_panel != null and is_instance_valid(_passive_swap_panel):
		return _passive_swap_panel
	_passive_swap_panel = PassiveSwapPanel.new()
	_passive_swap_panel.name = "PassiveSwapPanel"
	_passive_swap_panel.slot_chosen.connect(_on_passive_slot_chosen)
	_passive_swap_panel.refused.connect(_on_passive_swap_refused)
	# Dans le CanvasLayer du HUD, pour la meme raison que le panneau
	# d amelioration : pose sur le Node2D de la partie, il suivrait le terrain.
	var hud: Node = get_node_or_null("HUD")
	if hud != null:
		hud.add_child(_passive_swap_panel)
	else:
		add_child(_passive_swap_panel)
	return _passive_swap_panel


func _on_passive_slot_chosen(slot: int) -> void:
	if _passive_swap_panel != null and is_instance_valid(_passive_swap_panel):
		_passive_swap_panel.visible = false
	RunState.resolve_pending_passive(slot)


func _on_passive_swap_refused() -> void:
	if _passive_swap_panel != null and is_instance_valid(_passive_swap_panel):
		_passive_swap_panel.visible = false
	RunState.decline_pending_passive()


## La vague en cours a TRAINE (GameConfig.WAVE_OVERTIME_SECONDS apres sa derniere
## apparition) : le spawner passe la main a la suivante, les monstres restants
## restent en jeu. La partie la compte comme une vague franchie — compteur, record
## des modes sans fin, choix de carte toutes les deux vagues — parce que c est ce
## que le joueur vit : il a tenu la vague, la suivante arrive. Le HUD l annonce
## (il ecoute le signal du spawner, comme le bandeau de monde).
func _on_wave_overtime(index: int) -> void:
	_on_wave_cleared(index)
