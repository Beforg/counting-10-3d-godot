extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var mouse_sensitivity: float = 0.003

# --- VARIÁVEIS DO HEAD BOBBING ---
var bob_freq: float = 2.4 # Frequência base
@export var bob_amp: float = 0.08 
var t_bob: float = 0.0
var base_camera_pos: Vector3 
var light_drain_rate: float = 0.05

@onready var camera = $Camera3D
@onready var torch = $Camera3D/SpotLight3D # Sua nova lanterna 3D!
@onready var heart_low = $HeartbeatLow
@onready var heart_high = $HeartbeatHight
@onready var som_passos = $SomPassos

var passo_tocado = false
# Variável de velocidade atual
var speed: float = 5.0 

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	base_camera_pos = camera.position 
	GameManager.difficulty_increased.connect(_on_difficulty_increased)

func _input(event: InputEvent) -> void:
	var item_sound = $UseItem
	if event.is_action_pressed("usar_cura"):
		if GameManager.cures_count > 0:
			GameManager.cures_count -= 1
			GameManager.terror_level = 0
			item_sound.play()
			GameManager.is_addicted = false # Remove o vício
			GameManager.adrenaline_use_history = []
			print("Você usou a cura! Estado normalizado.")
		else:
			print("Você não tem curas!")
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# USAR ADRENALINA (Tecla Q)
	if event.is_action_pressed("usar_adrenalina"):
		if GameManager.try_use_adrenaline():
			GameManager.terror_level = max(0.0, GameManager.terror_level - 30.0)
			
			item_sound.play()
			print("PLAYER 3D: Adrenalina injetada!")
			
	if event.is_action_pressed("usar_tocha"):
		if GameManager.torch_refills > 0:
			item_sound.play()
			GameManager.torch_refills -= 1
			torch.light_energy = clamp(torch.light_energy + 2.25, 0.2, 9.99)
			torch.spot_range = clamp(torch.spot_range + 4.5, 3, 20) # Corrigido typo aqui
			print("Tocha recarregada!")
			
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	_update_heartbeat_audio()
	
	# --- 1. GESTÃO DE VELOCIDADE E ESTADOS ---
	if GameManager.is_adrenaline_active:
		if GameManager.is_addicted:
			speed = walk_speed * 1.15 # Bônus viciado
			bob_freq = 3.8 # Passos um pouco mais rápidos
		else:
			speed = walk_speed * 1.24 # Corrida desesperada
			bob_freq = 2.8 # Câmera balança muito rápido!
	elif GameManager.terror_level >= 50.0:
		speed = walk_speed * 0.8 # Lento por pânico
		bob_freq = 1.5 # Passos pesados e arrastados
	else:
		speed = walk_speed # Normal
		bob_freq = 2.4 # Ritmo normal
		
	# --- 2. DRENO DA LANTERNA ---
	if torch.light_energy > 0.2:
		if GameManager.gasoline_count > 0:
			torch.light_energy -= light_drain_rate * delta
			torch.spot_range -=(light_drain_rate*2.05) * delta
			print("ENERGIA" + str(torch.light_energy) + "TAMANHO: " + str(torch.spot_range))
			print()

	# --- 3. FÍSICA E MOVIMENTO ---
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# --- 4. HEAD BOBBING DINÂMICO E PASSOS ---
	if is_on_floor() and direction != Vector3.ZERO:
		t_bob += delta * velocity.length() 
		
		# Isolamos o seno puro para usar como gatilho do som
		var pure_sin = sin(t_bob * bob_freq)
		
		var bob_y = pure_sin * bob_amp
		var bob_x = cos(t_bob * bob_freq / 2.0) * bob_amp
		camera.position = base_camera_pos + Vector3(bob_x, bob_y, 0)
		
		# --- GATILHO DO ÁUDIO ---
		if pure_sin < -0.8 and not passo_tocado:
			tocar_passo()
			passo_tocado = true
		elif pure_sin > -0.5:
			passo_tocado = false
			
	else:
		t_bob = 0.0
		passo_tocado = false # Reseta o passo ao parar
		camera.position.y = lerp(camera.position.y, base_camera_pos.y, delta * 10.0)
		camera.position.x = lerp(camera.position.x, base_camera_pos.x, delta * 10.0)
		
func _update_heartbeat_audio():
	var level = GameManager.terror_level
	
	if level >= 50:
		if not heart_high.playing:
			heart_high.play()
			heart_low.stop()
	elif level >= 25:
		if not heart_low.playing:
			heart_low.play()
			heart_high.stop()
	else:
		if heart_low.playing: heart_low.stop()
		if heart_high.playing: heart_high.stop()

func _on_difficulty_increased(level: int) -> void:
	if level == 1:
		light_drain_rate = 0.13 
		print("PLAYER: A bateria está gastando mais rápido (Nível 1)")
	elif level == 2:
		light_drain_rate = 0.15 
		print("PLAYER: A luz enfraqueceu e o cone fechou! (Nível 2)")

func tocar_passo() -> void:
	# Altera levemente o pitch e o volume para soar orgânico, como um sample real
	som_passos.pitch_scale = randf_range(0.85, 1.15)
	som_passos.volume_db = randf_range(-5.0, 0.0)
	som_passos.play()
