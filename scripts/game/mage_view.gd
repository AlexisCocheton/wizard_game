class_name MageView
extends Node2D
## Le personnage du joueur en combat : le mage (le moine bleu de Tiny Swords,
## animation de soin reutilisee comme incantation) ou l un de ses APPRENTIS,
## choisi dans le profil. Cercle de lancement (Free Pixel Effects) sous lui.
##
## Ce fichier ne sait pas QUI il affiche : feuille, taille et pose viennent de
## UiTheme.hero_*(). Un nouvel apprenti ne demande donc aucune ligne ici.

var _anim: AnimatedSprite2D = null
## Le CHAPEAU : un calque enfant du sprite (il herite de son echelle), recale sur
## le sommet de la tete a chaque image. Absent pour la tete nue et les apprentis.
var _hat: Sprite2D = null
## La feuille jouee (robe ou tenue) : cle des ancrages de tete.
var _sheet: String = ""
var _charge: Node = null
## VITRINES SEULEMENT (smoke, etage visual) : imposer une feuille et un chapeau
## sans toucher au profil, pour montrer toute la garde-robe d un coup. Vides en
## jeu : tout vient du profil. A poser AVANT l ajout a l arbre.
var forced_sheet: String = ""
var forced_hat: String = ""
var forced_scale: float = 0.0
## La pose d incantation du personnage joue ("cast" pour le mage, "attack" pour
## les sorcieres, qui n ont pas d autre geste de sort).
var _cast_anim: StringName = &"cast"
var _casting: bool = false


func _ready() -> void:
	if not Fx.enabled():
		return
	_anim = AnimatedSprite2D.new()
	# Tout vient du profil : le compte ne donne que du cosmetique.
	_sheet = UiTheme.hero_sheet_key()
	var pose_key: String = ""
	if forced_sheet != "":
		_sheet = forced_sheet
		# Une robe du mage se pose comme le mage ; toute autre feuille comme un
		# apprenti (taille et pieds deduits de la feuille).
		pose_key = AccountRewardDef.CHARACTER_MAGE if UiTheme.hat_rig(_sheet) != "" else _sheet
	_anim.sprite_frames = AnimCatalog.frames(StringName(_sheet)) if forced_sheet != "" \
		else UiTheme.hero_frames()
	_cast_anim = UiTheme.hero_cast_anim(_anim.sprite_frames)
	# Chaque feuille remplit sa case a sa facon : l echelle et la hauteur sont
	# calculees pour que tout personnage ait les pieds sur la ligne du mage, a la
	# taille du mage (APPRENTICE_SCALE fois pour un apprenti).
	var pose: Dictionary = UiTheme.hero_pose(pose_key)
	_anim.scale = Vector2.ONE * float(pose["scale"])
	_anim.position = Vector2(0.0, float(pose["y"]))
	if forced_scale > 0.0:
		scale = Vector2.ONE * forced_scale
	var chapeau: String = UiTheme.hero_hat_key() if forced_sheet == "" else forced_hat
	if chapeau != "" and chapeau != AccountRewardDef.HAT_NONE \
			and UiTheme.hat_rig(_sheet) != "":
		_hat = Sprite2D.new()
		_hat.texture = UiTheme.hat_texture(chapeau)
		_hat.centered = false
		_hat.offset = -WardrobeData.HAT_PIVOT
		_anim.add_child(_hat)
		_anim.frame_changed.connect(_place_hat)
		_anim.animation_changed.connect(_place_hat)
	# L attaque des sorcieres ne boucle pas (le catalogue la partage avec les
	# monstres, qui frappent une fois) : on la relance tant que l incantation
	# dure, sinon l apprentie se fige sur sa derniere image.
	_anim.animation_finished.connect(_on_anim_finished)
	add_child(_anim)
	_anim.play("idle")
	_place_hat()


## Recale le chapeau sur le sommet de la tete de l image courante (mesure image
## par image : la tete monte et descend en attente, part en arriere pendant
## l incantation). Cache si l image n a pas d ancrage plutot que mal pose.
func _place_hat() -> void:
	if _hat == null or _anim == null:
		return
	var p: Vector2 = UiTheme.hat_offset(_sheet, _anim.animation, _anim.frame)
	_hat.visible = p != Vector2.INF
	if _hat.visible:
		_hat.position = p


## Pour les tests et les vitrines : le calque chapeau, ou null.
func hat_layer() -> Sprite2D:
	return _hat


## Pour les tests et les vitrines : le sprite du personnage, ou null.
func body() -> AnimatedSprite2D:
	return _anim


func _on_anim_finished() -> void:
	if _casting and _anim != null and _anim.animation == _cast_anim:
		_anim.play(_cast_anim)


func bind(caster: Caster) -> void:
	if caster == null:
		return
	if not caster.cast_started.is_connected(_on_cast_started):
		caster.cast_started.connect(_on_cast_started)
	if not caster.cast_finished.is_connected(_on_cast_finished):
		caster.cast_finished.connect(_on_cast_finished)


func _on_cast_started(_card: SpellCard, _duration: float) -> void:
	_casting = true
	if _anim != null:
		_anim.play(_cast_anim)
	if _charge == null or not is_instance_valid(_charge):
		_charge = Fx.cast_charge(self, Vector2(0.0, 30.0))
	AudioBus.play_sfx(&"cast_start")


func _on_cast_finished(_card: SpellCard) -> void:
	_casting = false
	if _anim != null:
		_anim.play("idle")
	if _charge != null and is_instance_valid(_charge):
		_charge.queue_free()
	_charge = null
	# Le son generique seulement si la carte n a pas le sien : sinon deux sons
	# se superposent a chaque lancer.
	if _card == null or _card.sfx_key == &"":
		AudioBus.play_sfx(&"cast_done")
