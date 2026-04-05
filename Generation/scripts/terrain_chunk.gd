extends Node3D

const CHUNK_SIZE = 32
const VOXEL_SIZE: float = 2.0
const SOLID_THRESHOLD := 0.35

var chunk_position : Vector3i
var world_seed : int
var thread : Thread

# Packed arrays for fast memory access
var density_map : PackedFloat32Array
var noise := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()

# Passed in from WorldManager to save performance
var flight_path 

@export var canyon_frequency := 0.035
@export var warp_strength := 25.0

# --- INITIALIZATION & THREADING ---

func setup(pos: Vector3i, s: int, path_ref):
	chunk_position = pos
	world_seed = s
	flight_path = path_ref
	
	configure_noise()
	
	# Check if we even need to build this chunk
	if chunk_is_empty():
		queue_free()
		return

	# Start heavy lifting on a background thread
	thread = Thread.new()
	thread.start(_threaded_generation)

func _threaded_generation():
	build_density()
	# Tell the main thread to build the mesh when ready
	call_deferred("_finalize_mesh")

func _finalize_mesh():
	if thread.is_started():
		thread.wait_to_finish()
	
	build_mesh()

# --- NOISE & DENSITY GENERATION ---

func configure_noise():
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = canyon_frequency
	noise.fractal_octaves = 4

	warp_noise.seed = world_seed + 1337
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise.frequency = 0.5

func chunk_is_empty() -> bool:
	var step = CHUNK_SIZE / 2.0
	for x in range(3):
		for y in range(3):
			for z in range(3):
				# Multiply the sample coordinate by VOXEL_SIZE
				var sample_pos = Vector3(
					(chunk_position.x * CHUNK_SIZE) + (x * step),
					(chunk_position.y * CHUNK_SIZE) + (y * step),
					(chunk_position.z * CHUNK_SIZE) + (z * step)
				) * VOXEL_SIZE
				
				if density(sample_pos) > SOLID_THRESHOLD:
					return false
	return true

func build_density():
	var total = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
	density_map = PackedFloat32Array()
	density_map.resize(total) 

	var idx = 0
	for z in CHUNK_SIZE:
		for y in CHUNK_SIZE:
			for x in CHUNK_SIZE:
				# Multiply the final world position by VOXEL_SIZE
				var world_pos = Vector3(
					x + (chunk_position.x * CHUNK_SIZE),
					y + (chunk_position.y * CHUNK_SIZE),
					z + (chunk_position.z * CHUNK_SIZE)
				) * VOXEL_SIZE
				
				density_map[idx] = density(world_pos)
				idx += 1
func index(x: int, y: int, z: int) -> int:
	return x + CHUNK_SIZE * (y + CHUNK_SIZE * z)

# --- SDF MATH (THE SHAPES) ---

func density(pos: Vector3) -> float:
	pos = domain_warp(pos)

	var canyon = canyon_density(pos)
	var towers = tower_density(pos)
	var arches = arch_density(pos)
	var tunnels = tunnel_density(pos)

	# Combine shapes using SDF logic
	var d = min(canyon, arches)
	d = max(d, towers)
	d -= tunnels * 1.2
	d += floating_islands(pos) * 0.4

	return d

func domain_warp(pos: Vector3) -> Vector3:
	var wx = warp_noise.get_noise_3d(pos.x, pos.y, pos.z)
	var wy = warp_noise.get_noise_3d(pos.x + 200, pos.y, pos.z)
	var wz = warp_noise.get_noise_3d(pos.x, pos.y + 200, pos.z)
	return pos + Vector3(wx, wy, wz) * warp_strength

func arch_density(pos: Vector3) -> float:
	var arch_center := Vector3(
		round(pos.x / 120.0) * 120.0,
		40.0,
		round(pos.z / 120.0) * 120.0
	)
	var ring : float = abs(pos.distance_to(arch_center) - 30.0)
	return 8.0 - ring

func canyon_density(pos: Vector3) -> float:
	if flight_path == null: return 0.0
	var closest = flight_path.get_closest_point(pos)
	var dist = pos.distance_to(closest)
	var canyon_radius := 70.0
	var wall = (dist - canyon_radius) / canyon_radius 
	var vertical = clamp((120.0 - pos.y) / 120.0, 0.0, 1.0)
	return wall + vertical * 0.8

func tower_density(pos: Vector3) -> float:
	if flight_path == null: return -100.0
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

func tunnel_density(pos: Vector3) -> float:
	var tunnel_center: Vector3 = Vector3(
		sin(pos.y * 0.02) * 80.0,
		pos.y,
		pos.z
	)
	var d: float = pos.distance_to(tunnel_center)
	return 18.0 - d

func floating_islands(pos: Vector3) -> float:
	var noise_val = noise.get_noise_3d(pos.x * 0.01, pos.y * 0.01, pos.z * 0.01)
	return noise_val - 0.7

# --- GREEDY MESHING ---

func build_mesh():
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var dims = Vector3i(CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
	
	# Pre-allocate mask to prevent dynamic resizing lag
	var mask = PackedInt32Array()
	mask.resize(CHUNK_SIZE * CHUNK_SIZE)

	for d in range(3):
		var u = (d + 1) % 3
		var v = (d + 2) % 3
		var x = Vector3i()
		var q = Vector3i()
		q[d] = 1

		for xd in range(-1, dims[d]):
			x[d] = xd
			
			var n = 0
			for xv in range(dims[v]):
				x[v] = xv
				for xu in range(dims[u]):
					x[u] = xu

					var a = false
					var b = false

					if x[d] >= 0:
						a = is_solid(x.x, x.y, x.z)
					if x[d] < dims[d] - 1:
						b = is_solid(x.x + q.x, x.y + q.y, x.z + q.z)

					if a != b:
						mask[n] = 1 if a else -1
					else:
						mask[n] = 0
					n += 1

			n = 0
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

						add_quad(st, Vector3(x.x, x.y, x.z), Vector3(du.x, du.y, du.z), Vector3(dv.x, dv.y, dv.z), d, c)

						for l in range(h):
							for k in range(w):
								mask[n + k + l * dims[u]] = 0

						i += w
						n += w
					else:
						i += 1
						n += 1

	var mesh = st.commit()
	
	if mesh != null and mesh.get_faces().size() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		add_child(mesh_instance)
		
		# Generate collision strictly after adding to the tree
		mesh_instance.create_trimesh_collision()
	else:
		# Clean up completely empty chunks
		queue_free()

func add_quad(st: SurfaceTool, pos: Vector3, du: Vector3, dv: Vector3, axis: int, sign: int):
	var v0 = pos * VOXEL_SIZE
	var v1 = (pos + dv) * VOXEL_SIZE
	var v2 = (pos + du + dv) * VOXEL_SIZE
	var v3 = (pos + du) * VOXEL_SIZE

	# Calculate and set normal so lighting looks correct
	var normal = Vector3()
	normal[axis] = sign
	st.set_normal(normal)

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

func is_solid(x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0 or x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE:
		return false
	return density_map[index(x, y, z)] > SOLID_THRESHOLD
