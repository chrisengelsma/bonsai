extends Node

const AUDIO_DIR := "res://audio/"


func _ready() -> void:
	_ensure_buses()


func _ensure_buses() -> void:
	_add_bus_if_missing("Music", 0)
	_add_bus_if_missing("Ambience", 0)
	_add_bus_if_missing("SFX", 0)


func _add_bus_if_missing(name: String, send_level: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, send_level)


func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func play_sfx(sound_name: String) -> void:
	var path := AUDIO_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
