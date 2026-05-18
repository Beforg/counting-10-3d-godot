extends CharacterBody3D

enum State { HIDDEN, STALKING, HUNTING }
var current_state: State = State.HIDDEN
var is_active: bool = false 

@onready var sprite = $Sprite3D
@onready var terror_aura = $TerrorAura
@export var player: Node3D

# Valores convertidos para "Metros" no 3D
@export var stalk_speed: float = 2.0 
@export var hunt_speed: float = 4.5
@export var base_light_energy: float = 5.0 

var circle_direction: int = 1 

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	# Aplica gravidade para o monstro ficar no chão
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if player != null and player.get("torch") != null:
		var light = player.torch.light_energy
		var distance = global_position.distance_to(player.global_position)
		var current_safe_zone = base_light_energy * light * 0.8
		
		# --- 1. REGRA GLOBAL: O TOQUE FATAL (1.5 Metros) ---
		if distance <= 1.5:
			print("Game Over 3D!")
			GameManager.reset_game()
			get_tree().change_scene_to_file("res://game_over_screen.tscn")
			return 
		
		# --- 2. ONIPRESENÇA (Rubber Banding para 25 Metros) ---
		if distance > 25.0: 
			teleport_near_player(current_safe_zone)
			distance = global_position.distance_to(player.global_position)
			
		# --- 3. DEFINIÇÃO DE ESTADOS ---
		var is_furious = (current_state == State.HUNTING and GameManager.terror_level > 80.0)
		
		if GameManager.terror_level >= 98.0 or is_furious:
			current_state = State.HUNTING
			current_safe_zone = 0.0 
		elif light > 5: # Ajuste conforme a energia máxima da sua lanterna
			current_state = State.HIDDEN
		elif light > 3: 
			current_state = State.STALKING
		else:
			current_state = State.HUNTING
			current_safe_zone = 0.0
			
		# Calcula a direção, mas ZERA o Y para ele não tentar "voar"
		var dir = global_position.direction_to(player.global_position)
		dir.y = 0 
		dir = dir.normalized()
			
		# --- 4. A AÇÃO 3D ---
		match current_state:
			State.HIDDEN:
				sprite.visible = GameManager.terror_level > 25
				velocity.x = dir.x * stalk_speed * 0.45
				velocity.z = dir.z * stalk_speed * 0.45
				move_and_slide()
				
			State.STALKING:
				sprite.visible = true
				if distance > current_safe_zone:
					velocity.x = dir.x * stalk_speed
					velocity.z = dir.z * stalk_speed
				elif distance < current_safe_zone - 2.0:
					velocity.x = -dir.x * (stalk_speed * 0.8)
					velocity.z = -dir.z * (stalk_speed * 0.8)
				else:
					# Rotaciona ao redor do Eixo Y (Cima)
					var tangent = dir.rotated(Vector3.UP, PI / 2 * circle_direction)
					velocity.x = tangent.x * (stalk_speed * 0.7)
					velocity.z = tangent.z * (stalk_speed * 0.7)
					if randf() < 0.02:
						circle_direction *= -1
				
				move_and_slide()
				
			State.HUNTING:
				sprite.visible = true
				if distance > 15.0:
					teleport_near_player(current_safe_zone)
					distance = global_position.distance_to(player.global_position)
					dir = global_position.direction_to(player.global_position)
					dir.y = 0
					dir = dir.normalized()
				
				velocity.x = dir.x * hunt_speed
				velocity.z = dir.z * hunt_speed
				move_and_slide()
					
	# Lógica da Aura de Terror
	var bodies = terror_aura.get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player":
			var dist = global_position.distance_to(body.global_position)
			var intensity = remap(dist, 25.0, 0.0, 4.0, 20.0)
			GameManager.increase_terror(intensity * delta)

func teleport_near_player(safe_zone: float) -> void:
	var random_angle = randf() * TAU 
	var spawn_distance = max(5.0, safe_zone + 2.0) # Metros em vez de Pixels
	var offset = Vector3(cos(random_angle), 0, sin(random_angle)) * spawn_distance
	
	global_position = player.global_position + offset
	global_position.y = player.global_position.y # Mantém na mesma altura do chão

func _ready() -> void:
	GameManager.monster_awakened.connect(_on_monster_awakened)
	GameManager.difficulty_increased.connect(_on_difficulty_increased)

func _on_monster_awakened() -> void:
	is_active = true
	if player != null:
		var light = player.torch.light_energy
		var current_safe_zone = base_light_energy * light * 0.8
		teleport_near_player(current_safe_zone)

func _on_difficulty_increased(level: int) -> void:
	if level == 1:
		stalk_speed += 0.5 
	elif level == 2:
		stalk_speed += 0.2  
		hunt_speed += 1.0
