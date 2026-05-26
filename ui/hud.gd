extends CanvasLayer

@onready var gas_label = $PanicVignette/MarginContainer/VBoxContainer/GasLabel
@onready var terror_label = $PanicVignette/MarginContainer/VBoxContainer/TerrorLabel
@onready var panic_vignette = $PanicVignette
@onready var cure_label = $PanicVignette/MarginContainer/VBoxContainer/TextCura
@onready var status_label = $PanicVignette/MarginContainer/VBoxContainer/TextStatus
@onready var adrenaline_timer_label = $PanicVignette/MarginContainer/VBoxContainer/TextAdrenalineTimer
@onready var adrenaline_label = $PanicVignette/MarginContainer/VBoxContainer/Adrenalina 
@onready var torch_label = $PanicVignette/MarginContainer/VBoxContainer/TextTorchRefil

func _ready() -> void:
	# Começa com o filtro vermelho invisível (Opacidade / Alpha = 0)
	panic_vignette.color.a = 0.0

func _process(delta: float) -> void:
	# 1. Atualiza os textos consultando o Autoload
	gas_label.text = "Galões: " + str(GameManager.gasoline_count) + "/7"
	terror_label.text = "Terror: " + str(int(GameManager.terror_level)) + "%"
	torch_label.text = "Tocha: " + str(GameManager.torch_refills)
	adrenaline_label.text = "Adrenalina:" + str(GameManager.adrenaline_count)
	# 2. O Efeito de Pânico!
	# Só começa a piscar/sujar a tela se o terror passar da metade
	if GameManager.terror_level > 50.0:
		# Transforma o terror (50 a 100) em um multiplicador (0.0 a 1.0)
		var intensity = (GameManager.terror_level - 50.0) / 50.0
		
		# Aplica a intensidade na opacidade da cor vermelha (Alpha)
		# Multipliquei por 0.5 para não ficar 100% cego quando chegar no 100 de terror
		panic_vignette.color.a = intensity * 0.5 
	else:
		panic_vignette.color.a = 0.0
	if GameManager.adrenaline_time_left > 0:
		# int() remove as casas decimais para a tela ficar limpa (ex: 5s em vez de 5.342s)
		adrenaline_timer_label.text = "Efeito Adrenalina: " + str(int(GameManager.adrenaline_time_left)) + "s"
		adrenaline_timer_label.visible = true
	else:
		adrenaline_timer_label.visible = false # Esconde quando o efeito acaba
		
	if GameManager.is_addicted:
		status_label.text = "Estado: VICIADO"
		status_label.modulate = Color(1, 0, 0) # Vermelho
	elif GameManager.terror_level >= 60:
		status_label.text = "Estado: EM PÂNICO"
		status_label.modulate = Color(1, 0.5, 0) # Laranja
	else:
		status_label.text = "Estado: NORMAL"
		status_label.modulate = Color(0, 1, 0) # Verde
