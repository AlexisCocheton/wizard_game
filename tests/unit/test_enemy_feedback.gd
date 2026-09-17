extends TestCase
## Retour visuel sur les monstres : barre de vie et etat apres degats.

func get_suite_name() -> String:
	return "enemy_feedback"


func _enemy(hp: float = 100.0) -> Enemy:
	var def := EnemyDef.new()
	def.id = &"t_mob"
	def.max_hp = hp
	def.base_speed = 60.0
	def.base_xp = 1
	var packed: PackedScene = load("res://scenes/game/Enemy.tscn")
	var e: Enemy = packed.instantiate()
	e.setup(def, 1.0)
	return e


func run() -> void:
	_test_pv_decroissent()
	_test_ratio_de_vie()
	_test_mort()
	_test_immunite_bloque_les_degats()
	_test_le_bilan_designe_le_coupable()


func _test_pv_decroissent() -> void:
	var e := _enemy(100.0)
	eq(e.hp, 100.0, "PV initiaux")
	var applique: bool = e.take_damage(30.0, [])
	ok(applique, "les degats sont appliques")
	feq(e.hp, 70.0, "PV apres 30 degats")
	e.free()


## Le ratio pilote la largeur et la couleur de la micro barre.
func _test_ratio_de_vie() -> void:
	var e := _enemy(100.0)
	feq(e.hp / 100.0, 1.0, "intact = ratio 1 (barre cachee)")
	e.take_damage(50.0, [])
	feq(e.hp / 100.0, 0.5, "moitie des PV = ratio 0.5")
	e.take_damage(30.0, [])
	feq(e.hp / 100.0, 0.2, "ratio bas = barre rouge")
	e.free()


func _test_mort() -> void:
	var e := _enemy(20.0)
	var morts: Array[int] = [0]
	e.died.connect(func(_x) -> void: morts[0] += 1)
	e.take_damage(25.0, [])
	ok(e.is_dead(), "le monstre meurt quand les PV tombent a zero")
	eq(morts[0], 1, "le signal died est emis une seule fois")
	# Un monstre mort ne reprend pas de degats.
	not_ok(e.take_damage(10.0, []), "un monstre mort ignore les degats")
	eq(morts[0], 1, "died n est pas reemis")
	e.free()


func _test_immunite_bloque_les_degats() -> void:
	var def := EnemyDef.new()
	def.id = &"t_immune"
	def.max_hp = 50.0
	def.immune_tags = [GameEnums.DamageTag.FROST]
	var packed: PackedScene = load("res://scenes/game/Enemy.tscn")
	var e: Enemy = packed.instantiate()
	e.setup(def, 1.0)

	not_ok(e.take_damage(20.0, [GameEnums.DamageTag.FROST]),
		"un sort immunise n applique aucun degat")
	feq(e.hp, 50.0, "PV intacts apres un sort immunise")
	ok(e.take_damage(20.0, [GameEnums.DamageTag.FIRE]),
		"un autre element passe normalement")
	e.free()


## Le bilan de defaite compte les coups PAR SOURCE : c est la seule facon pour le
## joueur de savoir ce qui l a tue et d ajuster son deck.
func _test_le_bilan_designe_le_coupable() -> void:
	RunState.reset()
	var gnome := EnemyDef.new()
	gnome.id = &"t_gnome"
	gnome.display_name = "Gnome"
	var archer := EnemyDef.new()
	archer.id = &"t_archer"
	archer.display_name = "Lutin archer"

	RunState.note_damage_taken(gnome)
	RunState.note_damage_taken(archer)
	RunState.note_damage_taken(archer)
	eq(int(RunState.hits_by_source.get("Gnome", 0)), 1, "un coup de Gnome")
	eq(int(RunState.hits_by_source.get("Lutin archer", 0)), 2, "deux coups de Lutin archer")
	eq(RunState.worst_threat(), "Lutin archer", "la pire menace est celle qui a le plus frappe")

	# Un projectile dont le tireur est mort reste comptabilise, sans nom invente.
	RunState.note_damage_taken(null)
	eq(int(RunState.hits_by_source.get("Projectile", 0)), 1, "coup sans source identifiee")

	# Le compteur repart a zero d une partie a l autre, sinon le bilan cumule tout.
	RunState.reset()
	ok(RunState.hits_by_source.is_empty(), "le bilan est vide au debut d une partie")
	eq(RunState.worst_threat(), "", "aucune menace sans coup recu")
