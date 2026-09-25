extends Node
## Capture la DESCENTE du mode infini : une image par monde, prise en poussant le
## spawner de vague en vague, comme en jeu. C est la seule preuve que le fond
## change reellement en cours de partie — l etage `backdrops` pose chaque fond a
## la main et ne franchit jamais un bloc de monde.
##
## Usage : Godot --path . --resolution 540x960 tools/_probe_worlds.tscn

func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/game/Game.tscn")
	var g: GameController = packed.instantiate()
	g.headless_mode = true
	add_child(g)
	await get_tree().process_frame
	var level: LevelDef = ContentDB.levels.get(&"lvl_01")
	g.start_level(level, GameEnums.Mode.MASSACRE)
	g.running = false
	var vu: Array[String] = []
	print("[MONDES] fond au demarrage : %s" % g.backdrop.backdrop)
	# On franchit les vagues une par une et on capture au CHANGEMENT de fond.
	for n in range(1, WaveBudget.WORLDS.size() * WaveBudget.WORLD_EVERY + 2):
		var attendu: String = WaveBudget.backdrop_for(n)
		if g.backdrop.backdrop != attendu:
			printerr("[MONDES] vague %d : fond %s, attendu %s"
				% [n, g.backdrop.backdrop, attendu])
		if not vu.has(attendu):
			vu.append(attendu)
			var w: WaveDef = g.spawner.current_wave()
			# Quelques monstres de la vague reelle, pour juger le contraste.
			if w != null:
				var x: float = 140.0
				for e: WaveEntry in w.entries:
					if e.enemy == null:
						continue
					g.battlefield.spawn_enemy(e.enemy, x, 1.0, Vector2(x, 620.0))
					x += 150.0
					if x > 950.0:
						break
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			if img != null:
				var dir: String = ProjectSettings.globalize_path("res://.testout")
				DirAccess.make_dir_recursive_absolute(dir)
				var f: String = "%s/world_%02d_v%02d_%s.png" % [dir, vu.size(), n, attendu]
				img.save_png(f)
				print("[MONDES] v%-2d monde %d (%s) -> %s" % [n,
					WaveBudget.world_index_for(n), WaveBudget.world_name_for(n),
					f.get_file()])
			g.battlefield.clear_all()
		g.spawner.start_next()
		await get_tree().process_frame
	print("[MONDES] fonds traverses : %s" % ", ".join(vu))
	print("MONDES_OK")
	get_tree().quit(0)
