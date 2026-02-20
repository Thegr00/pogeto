extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
@export_group("Flight Constants")
@export var max_speed = 60.0
@export var min_speed = 15.0
@export var dive_acceleration = 30.0  
@export var up_deceleration = 15.0 
@export var rotation_speed = 3
@export var slerp_speed = 3.0

@export_group("Camera")
@onready var pivot = $"cam origin"
@onready var camera = $"cam origin"/CABECA
@onready var spring_arm = $"cam origin"/SpringArm3D
@export var sens = 0.5

@onready var wind_particles = $"cam origin/Particulas"
#adicionar audio *****

var current_speed = 10.0
#MOUSE
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.set_as_top_level(true) #assim a camera nao ta presa ao gajo 
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens))
		pivot.rotate_x(deg_to_rad(-event.relative.y * sens))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))
		pivot.rotation.z = 0 #pa camera nao mexer no eixo dos z 
		rotation.z = clamp(rotation.z, deg_to_rad(-45), deg_to_rad(45))
func _physics_process(delta: float) -> void:
#SAIR
	if Input.is_action_just_pressed("quit"):
		get_tree().quit() 
#VOAR
	handle_flight_rotation(delta)
	calculate_flight_speed(delta)
	move_and_slide()
	update_camera_effects(delta)
	update_camera_soft_follow(delta)
	pivot.global_rotation.y = global_rotation.y
	pivot.rotation.z = 0 
	camera.rotation.z = 0
	pivot.global_rotation.z = 0
	var forward_dir = -global_transform.basis.z
	var target_velocity = forward_dir * current_speed
	velocity = velocity.lerp(target_velocity, slerp_speed * delta) #TIRA A CLUNKYNESS
	if current_speed < min_speed + 2: #SE POUCA VELOCIDADE CAIS UMA BECA (GRAVIDADE)
		velocity += get_gravity() * delta
func handle_flight_rotation(delta):
	var pitch = Input.get_axis("back", "forward")     #VARIAVEL DE MOVIEMENTO CIMA-BAIXO (-1 A 1)
	var roll = Input.get_axis("right", "left")       #IGUAL SOQ LADOS
	rotate_object_local(Vector3.RIGHT, pitch * rotation_speed * delta)   #RODA DE ACORDO COM VALORES/PRESSES
	rotate_object_local(Vector3.FORWARD, roll * rotation_speed * delta)  #NOTA: DELTA= MANTEM A SPEED BOA INDEEPENDENTE DE FPS
	rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89)) 
	var turn_strength = -rotation.z    #QUANDO DIREITA VIRAS PA DIREITA MSM
	rotate_y(turn_strength * delta * 2.0) 
	if roll == 0:
		rotation.z = lerp_angle(rotation.z, 0, delta * 2.0)  #SE PARAR DE VIRAR FICA DIREITO
func calculate_flight_speed(delta):
	var look_dir_y = -transform.basis.z.y 
	if look_dir_y < 0: #DIVE
		current_speed += abs(look_dir_y)* dive_acceleration * delta
	else: #up
		current_speed -= look_dir_y * up_deceleration * delta
	current_speed -= 1.0 * delta
	current_speed = clamp(current_speed, min_speed, max_speed)
#CAMERA TIPO SUPERFLIGHT
func update_camera_soft_follow(delta: float):
	spring_arm.global_position = spring_arm.global_position.lerp(global_position, delta * 20.0)
	var target_rotation = global_transform.basis.get_rotation_quaternion()
	var current_rotation = spring_arm.global_transform.basis.get_rotation_quaternion()
	var smoothed_rotation = current_rotation.slerp(target_rotation, delta * 4.0)
	spring_arm.global_transform.basis = Basis(smoothed_rotation)
	var target_margin = 4.0 + (current_speed * 0.05)
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_margin, delta * 2.0)
func update_camera_effects(delta): #CAMERA TIPO SUPERFLIGHT
	var target_fov = 75.0 + (current_speed * 0.8) #MUDA O FOV COM A SPEED
	camera.fov = lerp(camera.fov, target_fov, delta * 2.0)  #FAZ COM Q O VALOR NAO MUDE BRUSCAMENTEe
	var subtle_tilt = -rotation.z * 0.2 
	camera.rotation.z = lerp_angle(camera.rotation.z, subtle_tilt, delta * 5.0)
	var _speed_ratio = (current_speed - min_speed) / (max_speed - min_speed) 
	if _speed_ratio > 0.8:
		wind_particles.emitting = true
		wind_particles.amount_ratio = clamp(_speed_ratio, 0.0, 1.0)
	else:
		wind_particles.emitting = false    
