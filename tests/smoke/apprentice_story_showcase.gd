class_name ApprenticeStoryShowcase
extends RefCounted
## VITRINE : les trois APPRENTIS parlent avec leur visage dans leurs scenes
## d annexe (vague 10, chantier C6).
##
## Ils parlaient sans portrait, comme « Un mort ». Leur buste vient maintenant de
## `assets/portraits/apprentice_cast.png` (pixel art agrandi au plus proche
## voisin, voir tools/assets/make_apprentice_portraits.py). Pour chacun :
##   - la scene se deroule jusqu a SA DERNIERE replique, celle ou le mage a deja
##     parle : le mage (buste peint, a gauche, dans l ombre) et l apprenti (a
##     droite, en pleine lumiere) sont a l ecran ensemble, ce qui montre si les
##     deux styles tiennent dans le meme cadre ;
##   - CONTROLE (smoke ET visual) : le portrait de droite est visible, il vient de
##     la planche des apprentis, il est en pleine lumiere ;
##   - CAPTURE `histoire_apprenti_<cle>` (visual seulement), a lire.
##
## Fichier a part du pilote (smoke_driver.gd ne porte qu une ligne d appel).

## scene -> cle de casting de l apprenti qui y parle.
const SCENES: Array = [
	[&"side_squire_intro", &"soldier"],
	[&"side_fairy_outro", &"fairy"],
	[&"side_bluewitch_outro", &"bluewitch"],
]


static func run(driver: Node) -> void:
	var packed: PackedScene = load(SceneRouter.STORY)
	if packed == null:
		driver.call("_fail", "apprentis : StoryScene.tscn introuvable")
		return
	for paire: Array in SCENES:
		await _une_scene(driver, packed, paire[0], paire[1])
	SceneRouter.payload = {}


static func _une_scene(driver: Node, packed: PackedScene, story_id: StringName,
		cle: StringName) -> void:
	var def: DialogueDef = DialogueDef.load_by_id(story_id)
	if def == null:
		driver.call("_fail", "apprentis : la scene %s n existe pas" % story_id)
		return
	var cible: int = -1
	for i: int in def.line_count():
		if StringName(def.line(i).get("portrait", "")) == cle:
			cible = i
	if cible < 0:
		driver.call("_fail", "apprentis : %s ne fait pas parler %s avec son visage"
			% [story_id, cle])
		return
	# test_mode : la scene ne previent pas le routeur a la fin.
	SceneRouter.payload = {"story_id": story_id, "test_mode": true}
	var screen: Control = packed.instantiate()
	driver.add_child(screen)
	await driver.get_tree().process_frame
	for i: int in cible:
		screen.call("advance")
	await driver.get_tree().process_frame

	var cote: String = String(def.line(cible).get("side", "left"))
	var rect: TextureRect = screen.get_node("%PortraitRight" if cote == "right" else "%PortraitLeft")
	var tex: Texture2D = rect.texture
	if not rect.visible or tex == null:
		driver.call("_fail", "apprentis : %s parle sans visage dans %s" % [cle, story_id])
	elif not (tex is AtlasTexture) \
			or not (tex as AtlasTexture).atlas.resource_path.contains("apprentice_cast"):
		driver.call("_fail", "apprentis : le visage de %s ne vient pas de sa planche" % cle)
	elif rect.modulate != Color.WHITE:
		driver.call("_fail", "apprentis : %s parle dans l ombre" % cle)
	await driver._shot("histoire_apprenti_%s" % cle)
	screen.queue_free()
	await driver.get_tree().process_frame
