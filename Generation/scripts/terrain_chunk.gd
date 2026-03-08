extends Node3D

const CHUNK_SIZE = 24
const VOXEL_SIZE: float = 2.0

var chunk_position : Vector3i
var seed
var warp_noise := FastNoiseLite.new()
var voxels = []
var flight_path: Node
var noise := FastNoiseLite.new()
var density_map := []
func setup(pos: Vector3i, world_seed):
	chunk_position = pos
	seed = world_seed
	flight_path = preload("res://Generation/scripts/flight_rename.gd").new()
	flight_path.generate(seed)
	configure_noise()
	build_density()   # build voxel data
	build_mesh()      # build mesh

func configure_noise():

	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	warp_noise.seed = seed + 1337
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = 0.01

func domain_warp(pos: Vector3) -> Vector3:

	var warp_strength: float = 25.0

	var wx: float = warp_noise.get_noise_3d(pos.x, pos.y, pos.z)
	var wy: float = warp_noise.get_noise_3d(pos.x + 200, pos.y, pos.z)
	var wz: float = warp_noise.get_noise_3d(pos.x, pos.y + 200, pos.z)

	return pos + Vector3(wx, wy, wz) * warp_strength

func generate_voxels():
	voxels.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):

				var world = Vector3(
					x + chunk_position.x * CHUNK_SIZE,
					y + chunk_position.y * CHUNK_SIZE,
					z + chunk_position.z * CHUNK_SIZE
				)
				var d = density(world)
				voxels[index(x,y,z)] = d > 0.35

func build_density():

	density_map.resize(CHUNK_SIZE)

	for x in range(CHUNK_SIZE):

		density_map[x] = []
		density_map[x].resize(CHUNK_SIZE)

		for y in range(CHUNK_SIZE):

			density_map[x][y] = []
			density_map[x][y].resize(CHUNK_SIZE)

			for z in range(CHUNK_SIZE):

				var world_pos := Vector3(
					x + chunk_position.x * CHUNK_SIZE,
					y + chunk_position.y * CHUNK_SIZE,
					z + chunk_position.z * CHUNK_SIZE
				)

				density_map[x][y][z] = density(world_pos)
func index(x,y,z):
	return x + CHUNK_SIZE * (y + CHUNK_SIZE * z)

func density(pos: Vector3) -> float:
	pos = domain_warp(pos)
	var d: float = 0.0
	d += canyon_density(pos)
	d += floating_islands(pos) * 0.3
	d += tower_density(pos) * 0.45
	d += arch_density(pos)
	d -= tunnel_density(pos) * 1.1
	return d

func build_mesh():

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var dims = Vector3i(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)

	var mask = []

	for d in range(3):

		var u = (d + 1) % 3
		var v = (d + 2) % 3

		var x = Vector3i()  # your index vector
		var q = Vector3i()
		q[d] = 1

		for xd in range(-1, dims[d]):
			x[d] = xd
			mask.clear()

		for xv in range(dims[v]):
			x[v] = xv
		for xu in range(dims[u]):
			x[u] = xu
			var a = false
			var b = false
			if x[d] >= 0:
				a = is_solid(x.x, x.y, x.z)
			if x[d] < dims[d]-1:
				b = is_solid(x.x + q.x, x.y + q.y, x.z + q.z)

			if a != b:
				mask.append(1 if a else -1)
			else:
				mask.append(0)
			x[d] += 1

			var n = 0

			for j in range(dims[v]):
				var i = 0

				while i < dims[u]:

					var c = mask[n]

					if c != 0:

						var w = 1
						while i + w < dims[u] and mask[n + w] == c:
							w += 1

						var h = 1
						var done = false

						while j + h < dims[v]:

							for k in range(w):
								if mask[n + k + h * dims[u]] != c:
									done = true
									break

							if done:
								break

							h += 1

						x[u] = i
						x[v] = j

						var du = Vector3i()
						var dv = Vector3i()

						du[u] = w
						dv[v] = h

						add_quad(
							st,
							Vector3(x.x, x.y, x.z),
							Vector3(du.x, du.y, du.z),
							Vector3(dv.x, dv.y, dv.z),
							d,
							c
						)

						for l in range(h):
							for k in range(w):
								mask[n + k + l * dims[u]] = 0

						i += w
						n += w

					else:
						i += 1
						n += 1
				n += dims[u] - i

	var mesh = st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

func add_quad(st, pos, du, dv, axis, sign):

	var normal = Vector3()
	normal[axis] = sign

	var v0 = pos
	var v1 = pos + dv
	var v2 = pos + du + dv
	var v3 = pos + du

	v0 *= VOXEL_SIZE
	v1 *= VOXEL_SIZE
	v2 *= VOXEL_SIZE
	v3 *= VOXEL_SIZE

	if sign > 0:

		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)

		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v3)

	else:

		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v1)

		st.add_vertex(v0)
		st.add_vertex(v3)
		st.add_vertex(v2)

func is_solid(x:int,y:int,z:int) -> bool:

	if x < 0 or y < 0 or z < 0:
		return false

	if x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE:
		return false

	return density_map[x][y][z] > 0.35

func arch_density(pos: Vector3) -> float:

	var arch_center := Vector3(
		round(pos.x / 120.0) * 120.0,
		40.0,
		round(pos.z / 120.0) * 120.0
	)

	var ring : float = abs(pos.distance_to(arch_center) - 30.0)

	return 8.0 - ring

func canyon_density(pos: Vector3) -> float:

	var closest: Vector3 = flight_path.get_closest_point(pos)

	var dist: float = pos.distance_to(closest)

	var canyon_radius: float = 70.0

	var wall: float = (dist - canyon_radius) / canyon_radius

	var vertical: float = clamp((120.0 - pos.y) / 120.0, 0.0, 1.0)

	return wall + vertical * 0.8


func tower_density(pos: Vector3) -> float:

	var closest: Vector3 = flight_path.get_closest_point(pos)

	var dist: float = pos.distance_to(closest)

	if dist < 60.0 or dist > 120.0:
		return -100.0

	var grid: float = 80.0

	var tower_center := Vector3(
		round(pos.x / grid) * grid,
		0.0,
		round(pos.z / grid) * grid
	)

	var d: float = pos.distance_to(tower_center)

	var radius: float = 16.0
	var height: float = 200.0

	var vertical: float = clamp((height - pos.y) / height, 0.0, 1.0)

	return (radius - d) * vertical

func spike_density(pos: Vector3) -> float:

	var tower_pos := Vector3(
		round(pos.x / 40.0) * 40.0,
		0.0,
		round(pos.z / 40.0) * 40.0
	)

	var d := pos.distance_to(tower_pos)

	var radius := 12.0
	var height := 120.0

	var vertical: float = clamp((height - pos.y) / height, 0.0, 1.0)

	return (radius - d) * vertical

func tunnel_density(pos: Vector3) -> float:

	var tunnel_center: Vector3 = Vector3(
		sin(pos.y * 0.02) * 80.0,
		pos.y,
		pos.z
	)

	var d: float = pos.distance_to(tunnel_center)

	return 18.0 - d

func floating_islands(pos: Vector3) -> float:

	var n: float = noise.get_noise_3d(
		pos.x * 0.01,
		pos.y * 0.01,
		pos.z * 0.01
	)

	return n - 0.7
