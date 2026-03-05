extends Control

@onready var option_button: OptionButton = $HBoxContainer/OptionButton


const WINDOW_MODE_ARRAY : Array[String] = [
	"Full-screen",
	"Window Mode"
]


func _ready():
	add_window_mode_items()
	option_button.item_selected.connect(on_window_mode_selected)

func add_window_mode_items()-> void:
	for i in WINDOW_MODE_ARRAY:
		option_button.add_item(i)


func on_window_mode_selected(index: int) -> void:
	match index:
		0: #FULLscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		1: #Window Mode
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
