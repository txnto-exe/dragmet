extends SceneTree
## Отладка: печатает структуру импортированных моделей и список анимаций.
## godot --headless --path game -s tools/inspect.gd -- res://path.glb ...

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		print("=== ", path)
		var ps: PackedScene = load(path)
		if ps == null:
			print("  не загрузилось")
			continue
		var n := ps.instantiate()
		_dump(n, 0)
		n.free()
	quit()


func _dump(n: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + n.name + " <" + n.get_class() + ">"
	if n is MeshInstance3D:
		var m: MeshInstance3D = n
		line += " surfaces=%d skin=%s" % [m.mesh.get_surface_count() if m.mesh else 0, str(m.skeleton)]
	if n is Skeleton3D:
		var s: Skeleton3D = n
		line += " bones=%d first=%s" % [s.get_bone_count(), s.get_bone_name(0) if s.get_bone_count() else ""]
	print(line)
	if n is AnimationPlayer:
		var ap: AnimationPlayer = n
		var names := ap.get_animation_list()
		print("  ".repeat(depth + 1), "anims(", names.size(), "): ", ", ".join(names))
		if names.size() > 0:
			var a := ap.get_animation(names[0])
			for t in mini(a.get_track_count(), 3):
				print("  ".repeat(depth + 1), "track: ", a.track_get_path(t))
	if depth < 4:
		for c in n.get_children():
			_dump(c, depth + 1)
