extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var mouse_sensitivity: float = 0.003

# --- VARIÁVEIS DO HEAD BOBBING ---
var bob_freq: float = 2.4 # Frequência base
@export var bob_amp: float = 0.08 
var t_bob: float = 0.0
var base_camera_pos: Vector3 

@onready var camera = $Camera3D
@onready var torch = $Camera3D/SpotLight3D # Sua nova lanterna 3D!

# Variável de velocidade atual
var speed: float = 5.0 

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	base_camera_pos = camera.position 

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# USAR ADRENALINA (Tecla Q)
	if event.is_action_pressed("usar_adrenalina"):
		if GameManager.try_use_adrenaline():
			GameManager.terror_level = max(0.0, GameManager.terror_level - 30.0)
			print("PLAYER 3D: Adrenalina injetada!")

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	# --- 1. GESTÃO DE VELOCIDADE E ESTADOS ---
	if GameManager.is_adrenaline_active:
		if GameManager.is_addicted:
			speed = walk_speed * 1.2 # Bônus viciado
			bob_freq = 3.0 # Passos um pouco mais rápidos
		else:
			speed = walk_speed * 2.5 # Corrida desesperada
			bob_freq = 4.5 # Câmera balança muito rápido!
	elif GameManager.terror_level >= 50.0:
		speed = walk_speed * 0.5 # Lento por pânico
		bob_freq = 1.5 # Passos pesados e arrastados
	else:
		speed = walk_speed # Normal
		bob_freq = 2.4 # Ritmo normal
		
	# --- 2. DRENO DA LANTERNA (Energia no lugar de Escala) ---
	# No 3D, usamos a energia da luz (light_energy) em vez de texture_scale
	if torch.light_energy > 0.2:
		if GameManager.gasoline_count > 0:
			torch.light_energy -= 0.05 * delta # Ajuste o dreno conforme necessário

	# --- 3. FÍSICA E MOVIMENTO ---
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# --- 4. HEAD BOBBING DINÂMICO ---
	if is_on_floor() and direction != Vector3.ZERO:
		t_bob += delta * velocity.length() 
		var bob_y = sin(t_bob * bob_freq) * bob_amp
		var bob_x = cos(t_bob * bob_freq / 2.0) * bob_amp
		camera.position = base_camera_pos + Vector3(bob_x, bob_y, 0)
	else:
		t_bob = 0.0
		camera.position.y = lerp(camera.position.y, base_camera_pos.y, delta * 10.0)
		camera.position.x = lerp(camera.position.x, base_camera_pos.x, delta * 10.0)
