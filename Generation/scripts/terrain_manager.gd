extends Node3D

@export var player: Node3D

const CHUNK_SIZE = 24
const VIEW_DISTANCE = 2
const CHUNKS_PER_FRAME = 1

var seed = randi()

var loaded_chunks = {}
var chunk_queue = []

var chunk_scene = preload("res://Generation/terrain_chunk.tscn")


func _process(delta):

	if player == null:
		return

	var player_chunk = world_to_chunk(player.global_position)

	request_chunks(player_chunk)

	generate_chunks()


func world_to_chunk(pos: Vector3) -> Vector3i:
	return Vector3i(
		floor(pos.x / CHUNK_SIZE),
		floor(pos.y / CHUNK_SIZE),
		floor(pos.z / CHUNK_SIZE)
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

		if chunk_queue.is_empty():
			return

		var pos = chunk_queue.pop_front()

		var chunk = chunk_scene.instantiate()

		chunk.position = Vector3(
			pos.x * CHUNK_SIZE,
			pos.y * CHUNK_SIZE,
			pos.z * CHUNK_SIZE
		)

		chunk.setup(pos, seed)

		add_child(chunk)

		loaded_chunks[pos] = chunk
