extends Node
## Audio : effets (400 Sounds Pack, FreeSFX) et musiques (16-bit RPG Music,
## xDeviruchi), charges depuis assets/. Inerte en headless.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const POOL_SIZE: int = 10

var _muted: bool = false
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer = null
var _current_music: StringName = &""
var _streams: Dictionary = {}


func _ready() -> void:
	_muted = DisplayServer.get_name() == "headless"
	if _muted:
		return
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	apply_settings()


func _stream(dir: String, key: StringName, ext: String) -> AudioStream:
	var path: String = dir + String(key) + ext
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_streams[path] = s
	return s


## Relit les volumes dans SaveData et les pousse sur les bus audio.
func apply_settings() -> void:
	if _muted:
		return
	var master: float = clampf(float(SaveData.get_setting("master_volume", 0.8)), 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master, 0.0001)))
		AudioServer.set_bus_mute(idx, master <= 0.0)
	if _music != null:
		var mv: float = clampf(float(SaveData.get_setting("music_volume", 0.6)), 0.0, 1.0)
		_music.volume_db = linear_to_db(maxf(mv, 0.0001))


func play_sfx(key: StringName) -> void:
	if _muted or _pool.is_empty():
		return
	var s: AudioStream = _stream(SFX_DIR, key, ".wav")
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = linear_to_db(clampf(float(SaveData.get_setting("sfx_volume", 1.0)), 0.0001, 1.0))
	p.play()


func play_music(key: StringName, loop: bool = true) -> void:
	if _muted or _music == null:
		return
	if _current_music == key and _music.playing:
		return
	var s: AudioStream = _stream(MUSIC_DIR, key, ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_current_music = key
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_current_music = &""
	if _music != null:
		_music.stop()


## Cles connues, pour l AUDIT : chaque cle doit avoir son fichier.
static func sfx_keys() -> Array[StringName]:
	return [&"cast_start", &"cast_done", &"cast_zone", &"hit", &"enemy_die", &"shield_break",
		&"hp_lost", &"wall", &"wave_start", &"boss", &"victory", &"defeat", &"ui_tap",
		&"card_pick", &"card_draw", &"speed_up", &"level_up", &"arrow", &"explosion", &"grow", &"heal"]


static func music_keys() -> Array[StringName]:
	return [&"menu", &"battle", &"boss", &"victory", &"defeat"]
