extends Node
## Generateur des POUVOIRS PASSIFS.
##
## Fichier separe de make_content.gd a dessein : les passifs sont une famille a
## part (joues une fois, effet pour tout le combat) et ce decoupage permet de les
## regenerer sans toucher au reste du contenu.
##
## Usage : Godot --headless --path . tools/make_passives.tscn

const DIR := "res://resources/cards/passive/"


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_passives()
	print("PASSIVES_OK")
	get_tree().quit(0)


func _spec(key: String, magnitude: float) -> EffectSpec:
	var s := EffectSpec.new()
	s.key = StringName(key)
	s.magnitude = magnitude
	return s


func _passive(id: String, dname: String, desc: String, rarity: GameEnums.Rarity,
		cast_time: float, key: String, magnitude: float) -> SpellCard:
	var c := SpellCard.new()
	c.id = StringName(id)
	c.display_name = dname
	c.description = desc
	c.rarity = rarity
	c.base_cast_time = cast_time
	c.targeting = GameEnums.Targeting.NONE
	c.effects = [_spec(key, magnitude)]
	c.is_passive = true
	return c


func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Sauvegarde impossible : %s (err %d)" % [path, err])
	else:
		print("  ecrit ", path)


func _passives() -> void:
	# Celerite : le passif le plus lisible, un gain constant sur chaque sort.
	var haste := _passive("pass_celerity", "Celerite",
		"Passif : chaque sort se lance 0,3 s plus vite, pour tout le combat.",
		GameEnums.Rarity.RARE, 1.5, "passive_cast_haste", 0.3)
	_save(haste, DIR + "pass_celerity.tres")

	# Compagnon : un allie a chaque vague. Fort sur la duree, nul si on meurt vite.
	var ally := _passive("pass_companion", "Compagnon fidele",
		"Passif : un allie apparait au debut de chaque vague.",
		GameEnums.Rarity.RARE, 2.0, "passive_wave_ally", 12.0)
	_save(ally, DIR + "pass_companion.tres")

	# Double incantation : deux sorts a la fois mais 50 % plus lents. Le prix est
	# indispensable, sinon le passif double purement la puissance du mage.
	var dual := _passive("pass_dual", "Double incantation",
		"Passif : deux sorts chargent en meme temps, mais chacun prend 50 pourcent plus de temps.",
		GameEnums.Rarity.EPIC, 2.5, "passive_double_cast", 1.0)
	_save(dual, DIR + "pass_dual.tres")
