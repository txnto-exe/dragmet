class_name ZScan
## Отладка: ищет «зет-файтинг» — две грани разных коробок/квадов, лежащие в одной плоскости,
## смотрящие в одну сторону и перекрывающиеся. Такие грани мерцают при движении камеры.
## Запуск: godot --path . -- --zscan   (печатает список и выходит)

const TOL := 0.004       # грани ближе 4 мм считаются совпадающими
const MIN_OVER := 0.006  # перекрытие меньше 6 мм по любой оси — не считаем


static func scan(root: Node) -> Array:
	var faces := []   # [axis, sign, coord, rect(Vector4: u0,v0,u1,v1), node]
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		if not (mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh):
			continue
		var b := mi.global_transform.basis.orthonormalized()
		if not _axis_aligned(b):
			continue
		var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
		for a in 3:
			if ab.size[a] < 0.0005:
				# плоский квад: одна грань, сторона — по нормали
				var nrm: Vector3 = mi.global_transform.basis * (Vector3(0, 0, 1) if mi.mesh is QuadMesh else Vector3(0, 1, 0))
				if mi.mesh is QuadMesh and (mi.mesh as QuadMesh).orientation != PlaneMesh.FACE_Z:
					nrm = mi.global_transform.basis * (Vector3(0, 1, 0) if (mi.mesh as QuadMesh).orientation == PlaneMesh.FACE_Y else Vector3(1, 0, 0))
				faces.append([a, signf(nrm[a]), ab.position[a], _rect(ab, a), mi])
			elif mi.mesh is BoxMesh:
				faces.append([a, -1.0, ab.position[a], _rect(ab, a), mi])
				faces.append([a, 1.0, ab.end[a], _rect(ab, a), mi])
	# сплошные коробки — чтобы отбросить грани, которые упёрлись в другой объект (их не видно)
	var solids := []
	for f in faces:
		if f[4].mesh is BoxMesh and not solids.has(f[4]):
			solids.append(f[4])
	var boxes := []
	for mi in solids:
		boxes.append([mi.global_transform * mi.mesh.get_aabb(), mi])
	var out := []
	var seen := {}
	for i in faces.size():
		var f: Array = faces[i]
		for j in range(i + 1, faces.size()):
			var g: Array = faces[j]
			if f[0] != g[0] or f[1] != g[1] or f[4] == g[4]:
				continue
			if absf(f[2] - g[2]) > TOL:
				continue
			var r1: Vector4 = f[3]
			var r2: Vector4 = g[3]
			var ou := minf(r1.z, r2.z) - maxf(r1.x, r2.x)
			var ov := minf(r1.w, r2.w) - maxf(r1.y, r2.y)
			if ou < MIN_OVER or ov < MIN_OVER:
				continue
			# точки перекрытия, сдвинутые на 1 см вперёд по нормали: если все внутри чужой коробки — грань скрыта
			var u0 := maxf(r1.x, r2.x)
			var v0 := maxf(r1.y, r2.y)
			var hidden := true
			for t in [Vector2(0.5, 0.5), Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]:
				var pt := Vector3.ZERO
				pt[f[0]] = f[2] + f[1] * 0.01
				pt[(f[0] + 1) % 3] = u0 + ou * t.x
				pt[(f[0] + 2) % 3] = v0 + ov * t.y
				var inside := false
				for bx in boxes:
					if bx[1] != f[4] and bx[1] != g[4] and (bx[0] as AABB).grow(-0.001).has_point(pt):
						inside = true
						break
				if not inside:
					hidden = false
					break
			if hidden:
				continue
			var key := "%s|%s|%d|%d" % [f[4].get_instance_id(), g[4].get_instance_id(), f[0], int(f[1])]
			if seen.has(key):
				continue
			seen[key] = true
			out.append("%s%s=%.3f  over %.2fx%.2f  A=%s  B=%s" % ["-+"[int(f[1] > 0)], "xyz"[f[0]], f[2], ou, ov,
				_desc(f[4]), _desc(g[4])])
	return out


static func _axis_aligned(b: Basis) -> bool:
	for c in [b.x, b.y, b.z]:
		var v: Vector3 = c.abs()
		if maxf(v.x, maxf(v.y, v.z)) < 0.999:
			return false
	return true


static func _rect(ab: AABB, a: int) -> Vector4:
	var u := (a + 1) % 3
	var v := (a + 2) % 3
	return Vector4(ab.position[u], ab.position[v], ab.end[u], ab.end[v])


static func _desc(mi: MeshInstance3D) -> String:
	var p := mi.global_position
	var s := ""
	if mi.mesh is BoxMesh:
		s = "box%s" % [(mi.mesh as BoxMesh).size]
	else:
		s = mi.mesh.get_class()
	return "%s@(%.2f,%.2f,%.2f) %s" % [s, p.x, p.y, p.z, str(mi.get_parent().name)]
