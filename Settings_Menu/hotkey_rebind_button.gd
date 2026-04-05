class_name Hotkeyrebindbutton
extends Control

@onready var label: Label = $HBoxContainer/Label
@onready var button: Button = $HBoxContainer/Button


@export var action_name : String = "right"

func _ready():
	set_process_unhandled_key_input(false) 


func set_action_name() -> void:
	label.text = "Unassigned"
	
	match action_name:
		"right":
			label.text = "Move right"
		"left":
			label.text = "Move Left"
