extends Node
class_name SignalBus

signal signal_registered
signal listener_registered

@export var debug: bool = true
var _signaldb = SignalDB.new().data.signaldb
var _monitored: Array[Node] = []
var _queued_remove: Array = []

@onready var testsubject = get_child(0)


func _ready() -> void:
	print("SignalBus debug mode: ", debug)
	if debug:
		print("Debug messages from SignalBus will be printed to Output Dock...")


func get_registered_signal_list() -> Array[String]:
	var returnval: Array[String] = _signaldb.keys()
	return returnval


## This function is used to register a signal to be connected to any valid listeners
## weak_reference is only applied if the signal's source is a descendant of RefCounted.
func register_signal(passed_signal: Signal, weak_reference: bool = true) -> void:
	if _signaldb.add_signal_to_db(passed_signal, weak_reference, debug):
		if debug:
			print("Signal ", passed_signal, "added to DB")
	else:
		if debug:
			printerr("Unable to add signal ", passed_signal, " to DB")
		return
	var source = passed_signal.get_object()
	var sourceid = passed_signal.get_object_id()
	var signal_name: String = passed_signal.get_name()

	if not source is RefCounted:
		_registration_cleanup(source)
	signal_registered.emit()


## This function is used to register a listener to be connected to any valid _signaldb.
func register_listener(
	connect_to: Callable, signal_name: String, flags: int, weak_reference: bool
) -> void:
	var source = connect_to.get_object()
	if source is RefCounted:
		var refsource = weakref(source)
		#TODO implement check for anonymous lambdas
		connect_to = Callable(refsource, connect_to.get_method())
	var sourceid = connect_to.get_object_id()

	if _signaldb.find_key(signal_name):
		_signaldb[signal_name].listeners.append(connect_to)
		for signal_source in _signaldb[signal_name].sources:
			Signal(signal_source.get_object(), signal_name).connect(connect_to)
	else:
		_signaldb[signal_name] = {
			"sources": [],
			"listeners": [connect_to],
		}
	if not source is RefCounted:
		_registration_cleanup(connect_to.get_object())
	listener_registered.emit()


func _registration_cleanup(source: Node) -> void:
	if not source.tree_exiting.is_connected(Callable(self, "_node_exit_imminent").bind(source)):
		source.tree_exiting.connect(Callable(self, "_node_exit_imminent").bind(source))


func _node_exit_imminent(source: Node) -> void:
	if source.is_queued_for_deletion():
		print("deleting")
	else:
		print("monitoring")
		_monitored.append(source)


func _monitoring() -> void:
	var item_index: int = 0
	for item in _monitored:
		if item.is_queued_for_deletion():
			_queued_remove.push_back(item_index)
			_node_exit_imminent(item)
		elif item.is_inside_tree():
			_queued_remove.push_back(item_index)
		item_index += 1
	if _queued_remove.size() > 0:
		for item_remove_index in range(_queued_remove.size() - 1, -1, -1):
			_monitored.remove_at(_queued_remove.pop_back())


func _process(_delta) -> void:
	_monitoring()
