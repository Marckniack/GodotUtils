@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/keystore_creator/keystore_creator_dock.tscn")

var dock_instance: Control = null


func _enter_tree() -> void:
	dock_instance = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_instance)


func _exit_tree() -> void:
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
		dock_instance = null
