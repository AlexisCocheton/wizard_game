extends Node
## APERCU de l ecran d amelioration de sort, en fenetre reelle.
##
## POURQUOI CET OUTIL NE GENERE AUCUN .tres
## ----------------------------------------
## Les autres tools/make_*.tscn ecrivent du contenu. Celui-ci n en ecrit pas, et
## c est le coeur de la conception : les trois voies d amelioration sont DERIVEES
## des effets de chaque carte (RunState.upgrade_paths_for), pas ecrites carte par
## carte dans un .tres. 45 cartes x 3 voies feraient 135 entrees a maintenir, et
## surtout chaque nouveau sort ajoute par un autre chantier arriverait SANS
## amelioration — le systeme mentirait au joueur sur la moitie du catalogue.
##
## Il n y a donc rien a generer. Ce qu il reste a faire, c est REGARDER l ecran :
## un ecran de choix qu on ne sait pas lire est un ecran rate. Cet outil capture
## l ecran sur les deux formes de carte qui existent (un sort de zone, qui a une
## voie AMPLEUR, et un sort a cible unique, qui recoit ENDURANCE a la place).
##
## Usage : Godot --path . tools/make_upgrades.tscn
##         (fenetre REELLE, pas --headless : sans rendu la capture est vide)

const OUT := "res://.testout"


func _ready() -> void:
	SaveData.persistence_enabled = false
	await get_tree().process_frame
	RunState.reset()
	await _apercu(_carte_de_zone(), "up_01_zone")
	await _apercu(_carte_simple(), "up_02_cible")
	print("UPGRADES_OK")
	get_tree().quit(0)


## Monte l ecran sur une carte donnee, apres l avoir "lancee" jusqu au palier
## pour que le compteur affiche un nombre vrai.
func _apercu(card: SpellCard, nom: String) -> void:
	if card == null:
		return
	RunState.reset()
	for i in GameConfig.CARD_UPGRADE_CASTS:
		RunState.note_cast(card)

	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.theme = UiTheme.make()
	add_child(racine)
	# Un fond de champ de bataille : l ecran est semi-transparent, le juger sur
	# du noir ne dirait rien de sa lisibilite en jeu.
	var fond := ColorRect.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.color = Color(0.22, 0.42, 0.20)
	racine.add_child(fond)

	var panneau := CardUpgradePanel.new()
	racine.add_child(panneau)
	panneau.show_paths(card, RunState.upgrade_paths_for(card))
	await _capture(nom)
	racine.queue_free()
	await get_tree().process_frame


## Un sort de ZONE : c est le seul qui recoit la voie AMPLEUR (il a un rayon).
func _carte_de_zone() -> SpellCard:
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and c.has_area() and c.has_damage():
			return c
	return null


## Un sort a cible unique : sans rayon, la voie AMPLEUR devient ENDURANCE.
func _carte_simple() -> SpellCard:
	for c: SpellCard in ContentDB.cards.values():
		if c != null and not c.is_passive and not c.has_area() and c.has_damage():
			return c
	return null


func _capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var dir: String = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/%s.png" % [dir, nom])
	print("[APERCU] %s.png" % nom)
