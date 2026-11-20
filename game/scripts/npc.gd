class_name Npc
extends Node3D
## Трёхмерный персонаж: базовая модель Quaternius + нарисованная одежда + причёска/борода,
## анимации из Universal Animation Library (обе библиотеки переназначены на один скелет).

const BODY := "res://assets/chars/ubc/Superhero_Male_FullBody.gltf"
const LIB_A := "res://assets/anim/ual1.glb"
const LIB_B := "res://assets/anim/ual2.glb"
const LOOPED := ["Idle", "Walk", "Walk_Formal", "Sitting_Idle", "Sitting_Talking", "Idle_Talking", "Idle_FoldArms",
	"Idle_TalkingPhone", "Crouch_Idle", "Fixing_Kneeling", "Zombie_Idle", "Idle_Torch", "Idle_Lantern", "Idle_Rail"]

static var _libs := {}

var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var head_attach: BoneAttachment3D
var current := ""
var _walk_tween: Tween


static func lib(path: String) -> AnimationLibrary:
	if not _libs.has(path):
		var n: Node = (load(path) as PackedScene).instantiate()
		var p: AnimationPlayer = n.get_node("AnimationPlayer")
		var l: AnimationLibrary = p.get_animation_library("")
		for a_name in l.get_animation_list():
			if a_name in LOOPED:
				l.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR
		_libs[path] = l
		n.free()
	return _libs[path]


## outfit — имя текстуры одежды (assets/chars/skins), hair — Hair_* или "", beard — борода, hat — цвет шапки или null
func setup(outfit: String, hair := "Hair_Buzzed", beard := false, hat: Variant = null) -> void:
	model = (load(BODY) as PackedScene).instantiate()
	add_child(model)
	skel = model.find_child("GeneralSkeleton", true, false)
	var body: MeshInstance3D = skel.get_node("SuperHero_Male")
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/chars/skins/%s.png" % outfit)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.88
	body.set_surface_override_material(0, mat)
	var parts: Array[String] = []
	if hair != "":
		parts.append(hair)
	if beard:
		parts.append("Hair_Beard")
	for h in parts:
		var hs: Node = (load("res://assets/chars/ubc/%s.gltf" % h) as PackedScene).instantiate()
		for c in hs.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			mi.get_parent().remove_child(mi)
			mi.owner = null
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
		hs.free()
	Props.pixelate(model)
	head_attach = BoneAttachment3D.new()
	head_attach.bone_name = "Head"
	skel.add_child(head_attach)
	if hat != null:
		_add_beanie(hat)
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("a", lib(LIB_A))
	ap.add_animation_library("b", lib(LIB_B))
	play("Idle")
	for c in model.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_beanie(col: Color) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.118
	s.height = 0.15
	s.is_hemisphere = true
	s.radial_segments = 10
	s.rings = 4
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	var tex := NoiseTexture2D.new()
	tex.width = 32
	tex.height = 32
	var nz := FastNoiseLite.new()
	nz.frequency = 0.35
	tex.noise = nz
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.material_override = mat
	m.position = Vector3(0, 0.135, -0.01)
	m.scale = Vector3(1.0, 1.0, 1.08)
	head_attach.add_child(m)
	var rim := MeshInstance3D.new()
	var t := CylinderMesh.new()
	t.top_radius = 0.123
	t.bottom_radius = 0.123
	t.height = 0.045
	t.radial_segments = 10
	rim.mesh = t
	var mat2 := mat.duplicate()
	mat2.albedo_color = col.darkened(0.25)
	rim.material_override = mat2
	rim.position = Vector3(0, 0.14, -0.01)
	rim.scale = Vector3(1.0, 1.0, 1.08)
	head_attach.add_child(rim)


func has_anim(n: String) -> bool:
	return ap.has_animation("a/" + n) or ap.has_animation("b/" + n)


func play(n: String, blend := 0.25, speed := 1.0) -> void:
	var full := ("a/" + n) if ap.has_animation("a/" + n) else ("b/" + n)
	if not ap.has_animation(full):
		push_warning("нет анимации " + n)
		return
	current = n
	ap.play(full, blend, speed)


func queue_anim(n: String) -> void:
	var full := ("a/" + n) if ap.has_animation("a/" + n) else ("b/" + n)
	ap.queue(full)


func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.001:
		rotation.y = atan2(dir.x, dir.z)


func face_to(p: Vector3) -> void:
	face(p - global_position)


## Пройти по точкам. Возвращает, когда дошёл.
func walk_path(points: Array, speed := 1.15) -> void:
	play("Walk", 0.2)
	for p in points:
		var target: Vector3 = p
		var d := target - position
		d.y = 0
		if d.length() < 0.01:
			continue
		var start_rot := rotation.y
		var end_rot := atan2(d.x, d.z)
		var turn := create_tween()
		turn.tween_method(func(v: float): rotation.y = lerp_angle(start_rot, end_rot, v), 0.0, 1.0, 0.25)
		_walk_tween = create_tween()
		_walk_tween.tween_property(self, "position", Vector3(target.x, position.y, target.z), d.length() / speed)
		await _walk_tween.finished
	play("Idle", 0.3)


func sit() -> void:
	play("Sitting_Enter", 0.2)
	queue_anim("Sitting_Idle")
