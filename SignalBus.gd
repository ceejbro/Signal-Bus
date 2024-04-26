extends Node
class_name SignalBus

signal signal_registered
signal listener_registered

var signals : Dictionary = {}
var monitored : Array[Node] = []
var queued_remove : Array = []


@onready var testsubject = get_child(0)

func get_registerd_signal_list() -> Array[String]:
	var returnval : Array[String] = signals.keys()
	return returnval

## This function is used to register a signal to be connected to any valid listeners
func register_node_signal(passed_signal : Signal) -> void:
	var source : Node = passed_signal.get_object()
	var signal_name : String = passed_signal.get_name()
	#if not (source is Node):
		#return
	if signals.find_key(signal_name):
		signals[signal_name].sources.append(source)
		for signal_listener in signals[signal_name].listeners:
			passed_signal.connect(signal_listener)
	else:
		signals[signal_name] = {
			"sources" : [source],
			"listeners" :  [], 
		}
	#_check_for_listeners(signal_name)
	_register_node_cleanup(source, signal_registered)

#func _check_for_listeners(signal_name : String) -> Array:
	#return listeners[signal_name].sources

## This function is used to register a listener to be connected to any valid signals.
func register_node_listener(connect_to : Callable, signal_name : String) -> void:
	if signals.find_key(signal_name):
		signals[signal_name].listeners.append(connect_to)
		for signal_source in signals[signal_name].sources:
			Signal(signal_source.get_object(), signal_name).connect(connect_to)
	else:
		signals[signal_name] = {
			"sources" : [],
			"listeners" : [connect_to],
		}
	_register_node_cleanup(connect_to.get_object(), listener_registered)

func _register_node_cleanup(source : Node, fire : Signal) -> void:
	if not source.tree_exiting.is_connected(Callable(self, "_node_exit_imminent").bind(source)):
		source.tree_exiting.connect(Callable(self, "_node_exit_imminent").bind(source))
	fire.emit()

func _node_exit_imminent(source : Node) -> void:
	if source.is_queued_for_deletion():
		print("deleting")
		if signals.find_key(source):
			signals.erase(source)
	else:
		print("monitoring")
		monitored.append(source)

func _monitoring() -> void:
	var item_index : int = 0
	for item in monitored:
		if item.is_queued_for_deletion():
			queued_remove.push_back(item_index)
			_node_exit_imminent(item)
		elif item.is_inside_tree():
			queued_remove.push_back(item_index)
		item_index += 1
	if queued_remove.size() > 0:
		for item_remove_index in range(queued_remove.size() - 1, -1, -1):
			monitored.remove_at(queued_remove.pop_back())


func _process(_delta) -> void:
	_monitoring()
	signal_registered.emit()

