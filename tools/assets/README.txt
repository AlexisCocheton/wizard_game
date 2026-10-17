Scripts de preparation des assets (Python 3 + Pillow + numpy).

compose_ui.py       : recompose les planches 9-tranches Tiny Swords (assets/ui/<nom>9.png) et ecrit UiTheme.NINE
make_wardrobe.py    : garde-robe du profil (robes, apprentis et teintes, tours, portraits,
                      chapeaux dessines par hat_painter.py + leur ancrage image par image)
                      -> scripts/game/wardrobe_data.gd. Argument : chemin de raw_assets/.
measure_occupancy.py: mesure la part occupee de chaque feuille et ecrit AnimCatalog occupancy + Fx.OCC
make_apprentice_portraits.py : portraits des trois apprentis pour les scenes d histoire
                      (assets/portraits/apprentice_cast.png), decoupes dans LEURS feuilles
                      de combat (assets/units/), agrandis au plus proche voisin. Aucun pack lu.
extract_w10_audio.py: sons et musiques de la vague 10 (familles de monstres, objets, sorts,
                      musique par acte) depuis les packs audio ; mesure TOUS les sons et ecrit
                      la table de gains de scripts/autoload/audio_bus.gd. Demande ffmpeg.

A relancer apres tout ajout de feuille dans assets/. Puis : bash tools/run_tests.sh visual
