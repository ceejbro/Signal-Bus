@tool
extends EditorScript

func _run() -> void:
	print("Found: ", EditorInterface.get_base_control().get_tree().root.find_children("@ScriptEditor@*","",true,false))
	print(EditorInterface.get_script_editor().get_current_editor().get_base_editor().code_completion_prefixes)
	EditorInterface.get_script_editor().get_current_editor().get_base_editor().code_completion_requested.connect(func(): print("code!"))
	
