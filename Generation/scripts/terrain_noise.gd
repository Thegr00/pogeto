class_name TerrainNoise

var height_noise : FastNoiseLite
var detail_noise : FastNoiseLite
var warp_noise : FastNoiseLite
var float_noise : FastNoiseLite

func setup(seed:int):

	height_noise = FastNoiseLite.new()
	height_noise.seed = seed
	height_noise.frequency = 0.003
	height_noise.fractal_octaves = 5

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = seed + 1
	detail_noise.frequency = 0.02

	warp_noise = FastNoiseLite.new()
	warp_noise.seed = seed + 2
	warp_noise.frequency = 0.01

	float_noise = FastNoiseLite.new()
	float_noise.seed = seed + 3
	float_noise.frequency = 0.01
