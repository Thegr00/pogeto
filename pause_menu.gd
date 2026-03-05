extends Control

func _on_resume_pressed() -> void:
	pass
	
func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Settings_Menu/settings_menu.tscn")

func _on_exit_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn") 
