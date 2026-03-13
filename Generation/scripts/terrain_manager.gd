extends Node3D

@export var player: Node3D

const CHUNK_SIZE = 32 
const VOXEL_SIZE = 2.0 # Add this here so the manager knows!
const VIEW_DISTANCE = 4 # INCREASE THIS so you can see the canyon walls!
const CHUNKS_PER_FRAME = 1

var seed = randi()
var loaded_chunks = {}
var chunk_queue = []

var chunk_scene = preload("res://Generation/terrain_chunk.tscn")
var flight_path 

func _ready():
	flight_path = preload("res://Generation/scripts/flight_rename.gd").new()
	flight_path.generate(seed)

func _process(delta):
	if player == null: return
	var player_chunk = world_to_chunk(player.global_position)
	request_chunks(player_chunk)
	generate_chunks()

func world_to_chunk(pos: Vector3) -> Vector3i:
	# Multiply by VOXEL_SIZE so grid aligns correctly
	var chunk_actual_size = CHUNK_SIZE * VOXEL_SIZE 
	return Vector3i(
		floor(pos.x / chunk_actual_size),
		floor(pos.y / chunk_actual_size),
		floor(pos.z / chunk_actual_size)
	)

func request_chunks(center: Vector3i):
	for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for z in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			for y in range(-VIEW_DISTANCE * 2, 1):
				var c = center + Vector3i(x,y,z)
				if !loaded_chunks.has(c):
					loaded_chunks[c] = null
					chunk_queue.append(c)

func generate_chunks():
	for i in range(CHUNKS_PER_FRAME):
		if chunk_queue.is_empty(): return
		
		var pos = chunk_queue.pop_front()
		var chunk = chunk_scene.instantiate()
		
		# Space the chunks out correctly using VOXEL_SIZE
		chunk.position = Vector3(pos.x, pos.y, pos.z) * (CHUNK_SIZE * VOXEL_SIZE)
		
		add_child(chunk)
		chunk.setup(pos, seed, flight_path) 
		loaded_chunks[pos] = chunk
