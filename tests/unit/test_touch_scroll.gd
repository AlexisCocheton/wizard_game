extends TestCase
## Defilement au doigt (TouchScroll) : la REGLE du geste, et aucune zone de
## defilement construite sans elle.
##
## Le geste lui-meme (doigt sur un bouton, un curseur, le fond, a plusieurs
## formats d ecran) est rejoue par tests/smoke/touch_scroll_check.gd : il faut
## des frames et une mise en page, que cet etage n a pas.
##
## POURQUOI LE BALAYAGE DES SOURCES. Le defaut du 03/10 (les reglages ne
## defilaient pas sur le telephone du co-auteur) venait d un ScrollContainer
## NU : le moteur ne le fait defiler au doigt que si le toucher lui remonte, et
## les boutons, les curseurs et la page de livre le gardent pour eux. Un ecran
## ajoute demain avec `ScrollContainer.new()` aurait exactement le meme defaut,
## invisible au harnais si personne ne pense a l y ajouter.

## La seule zone qui garde son propre geste : le deck de l ecran de deck, ou un
## glisser vertical sur une vignette defile et un glisser de cote PREND la carte
## (DeckPanel.gesture_for, verifie au doigt par le smoke `_check_deck_scroll`).
## Deux decideurs sur le meme doigt feraient sauter la page.
const EXCEPTION: String = "_deck_scroll"


func get_suite_name() -> String:
	return "touch_scroll"


func run() -> void:
	_test_la_regle_du_geste()
	_test_make_accroche_le_doigt()
	_test_aucune_zone_nue()


func _test_la_regle_du_geste() -> void:
	var s: float = TouchScroll.SEUIL_PX
	# Sous le seuil : rien n est decide, c est encore un toucher.
	eq(TouchScroll.gesture_for(Vector2(0.0, s * 0.5), false), TouchScroll.Geste.AUCUN,
		"sous le seuil, un appui reste un toucher")
	eq(TouchScroll.gesture_for(Vector2(s * 0.5, 0.0), true), TouchScroll.Geste.AUCUN,
		"sous le seuil, un curseur ne bouge pas")
	# Vertical : la page defile, QUEL QUE SOIT le controle touche.
	eq(TouchScroll.gesture_for(Vector2(0.0, -s * 2.0), false), TouchScroll.Geste.DEFILER,
		"vers le haut depuis un bouton : la page defile")
	eq(TouchScroll.gesture_for(Vector2(0.0, s * 2.0), false), TouchScroll.Geste.DEFILER,
		"vers le bas : la page defile aussi")
	eq(TouchScroll.gesture_for(Vector2(s * 0.5, -s * 2.0), true), TouchScroll.Geste.DEFILER,
		"depuis un CURSEUR, un glisser surtout vertical fait defiler, il ne regle pas")
	# Horizontal : le curseur suit le doigt ; un bouton garde son geste.
	eq(TouchScroll.gesture_for(Vector2(s * 2.0, s * 0.5), true), TouchScroll.Geste.REGLER,
		"un glisser horizontal sur un curseur le regle")
	eq(TouchScroll.gesture_for(Vector2(-s * 2.0, 0.0), false), TouchScroll.Geste.LAISSER,
		"un glisser horizontal sur un bouton n est pas un defilement")


func _test_make_accroche_le_doigt() -> void:
	var sc: ScrollContainer = TouchScroll.make()
	ok(TouchScroll.of(sc) != null, "make() accroche le defilement au doigt")
	eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"la zone ne defile que verticalement")
	eq(sc.get_child_count(), 0,
		"le noeud est INTERNE : la zone garde son contenu comme seul enfant")
	ok(TouchScroll.attach(sc) == TouchScroll.of(sc), "attach() est idempotent")
	var contenu := VBoxContainer.new()
	sc.add_child(contenu)
	ok(sc.get_child(0) == contenu, "le contenu reste get_child(0)")
	sc.free()


func _test_aucune_zone_nue() -> void:
	var nues: Array[String] = []
	for chemin in _fichiers("res://scripts", ".gd"):
		if chemin.ends_with("touch_scroll.gd"):
			continue
		var lignes: PackedStringArray = FileAccess.get_file_as_string(chemin).split("\n")
		for i in lignes.size():
			var l: String = lignes[i]
			if l.contains("ScrollContainer.new()") and not l.contains(EXCEPTION):
				nues.append("%s:%d" % [chemin, i + 1])
	for chemin in _fichiers("res://scenes", ".tscn"):
		if FileAccess.get_file_as_string(chemin).contains("type=\"ScrollContainer\""):
			nues.append(chemin)
	ok(nues.is_empty(),
		"zones de defilement sans TouchScroll (utiliser TouchScroll.make()) : %s" % str(nues))


func _fichiers(dossier: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dossier.path_join(f))
	for sous in d.get_directories():
		out.append_array(_fichiers(dossier.path_join(sous), ext))
	return out
