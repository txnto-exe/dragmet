extends Node
## Звуки (автозагрузка Sfx). Все файлы — в res://sfx/*.wav.

var _cache := {}
var world_root: Node = null   # куда добавлять 3D-звуки (узел внутри мира с камерой)


func stream(name: String) -> AudioStream:
	if not _cache.has(name):
		_cache[name] = load("res://sfx/%s.wav" % name)
	return _cache[name]


func looped(name: String) -> AudioStream:
	var s: AudioStreamWAV = stream(name).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func play(name: String, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play3d(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, max_dist := 20.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = 3.0
	p.bus = "SFX"
	var root: Node = world_root if is_instance_valid(world_root) else get_tree().current_scene
	root.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p
