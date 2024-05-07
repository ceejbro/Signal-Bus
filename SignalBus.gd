extends Node

signal signal_registered
signal listener_registered

## Enables debug messages printed to output console. Disable for final build.
@export var debug: bool = true
## Enables the use of groups to track and manage signals (Default). 
## Disable to use internal database based tracking.
@export var group_mode: bool = true:
	set(value):
		if Engine.is_editor_hint():
			group_mode = value
		else:
			printerr("Cannot set group_mode while running. Set this value manually in the editor")
## Assigns a unique String to prefix an integer to keep all managed signals grouped.
## This string will be used to create unique group names and tracked internally by integer.
@export var unique_group_label: String = "SignalManager":
	set(value):
		if Engine.is_editor_hint():
			unique_group_label = value
		else:
			printerr("Cannot set unique_group_label while running. Set this value manually in the editor")

var _monitored: Array[Node] = []
var _queued_remove: Array = []

var _signaldb 
@onready var testsubject = get_child(0)

# Debug printing function. Toggled from the main SignalBus scene export variable 'Debug.'
func _printdbg(message: String, error: bool = false) -> void:
	if debug:
		if error:
			printerr(message)
		else:
			print(message)


func _ready() -> void:
	print("SignalBus debug mode: ", debug)
	_printdbg("Debug messages from SignalBus will be printed to Output Dock...")
	_signaldb = SignalDB.new(debug, group_mode, unique_group_label)

## This function is used to register a signal to be connected to any valid listeners
## weak_reference is only applied if the signal's source is a descendant of RefCounted.
## override is only needed if previous registrations of a RefCounted's signal or listener registrations
## were different to the current call since the weakness is tracked as a whole for the signal /
## method in the RefCounted object.
## If Object is not RefCounted, the default flags can be used as they're not taken into account.
## If Object is RefCounted, the default is to be a weak reference and let it dispose of itself.
## However if you need to ensure it stays available for Signal management, either:
##	a) set the first call that registers the Signal's object as weak_reference = false
##	b) 
##		1) set weak_reference = false and override flag = true 
##		2) and ensure no other calls use the override flag in the opposite direction.
func register_signal(passed_signal: Signal, weak_reference: bool = true, override: bool = false) -> void:
	if _signaldb.add_signal_to_db(passed_signal, weak_reference, override):
		_printdbg(("Signal " + str(passed_signal) + "added to DB"), true)
	else:
		_printdbg(("Unable to add signal " + str(passed_signal) + " to DB"), true)
		return
	var source = passed_signal.get_object()
	if not source is RefCounted:
		_registration_cleanup(source)
	signal_registered.emit()


func add_signal_to_group() -> void:
	pass

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
