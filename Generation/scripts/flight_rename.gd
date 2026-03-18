extends Node

var points: Array[Vector3] = []

const PATH_LENGTH := 60
const STEP_DISTANCE := 45.0
const DROP_PER_STEP := 14.0

func generate(seed: int):

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	points.clear()

	var current := Vector3.ZERO

	for i in PATH_LENGTH:

		points.append(current)

		var turn: float = rng.randf_range(-0.5,0.5)

		current.x += sin(i * 0.4 + turn) * STEP_DISTANCE
		current.z += STEP_DISTANCE
		current.y -= DROP_PER_STEP
		
func get_closest_point(pos: Vector3) -> Vector3:

	var closest := points[0]
	var min_dist := pos.distance_to(closest)

	for p in points:

		var d := pos.distance_to(p)

		if d < min_dist:
			min_dist = d
			closest = p

	return closest
