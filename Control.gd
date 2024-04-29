extends Control

signal test_signal

@export_enum("join", "remove", "free") var Mode

# Called when the node enters the scene tree for the first time.
#func _ready():
	#get_parent().signal_registered.connect(test)
	#get_parent().register_node_signal(test_signal)
	#get_parent().register_node_listener(self, "test_signal")
	##get_parent().call_deferred("remove_child", self)
	#call_deferred("queue_free")
	
func test() -> void:
	print("fired")
