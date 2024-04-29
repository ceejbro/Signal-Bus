extends Resource
class_name SignalDB

var data: Dictionary = {
	"signaldb": {},
	"sourcedb": {},
}
var _signaltemplate = {
	"sources": [],
	"refsources": [],
	"listeners":  [],
	"reflisteners": [],
}
var _sourcetemplate = {
	
}

func _init() -> void:
	pass

func add_signal_to_db(passed_signal, weak_reference, debug: bool = false) -> bool:
	var signal_name: String = passed_signal.get_name()
	if signal_name == "":
		if debug:
			printerr("Unable to use SignalBus for anonymous signals...")
		return false
	var source = passed_signal.get_object()
	var sourceid = passed_signal.get_object_id()
	var where: String = "sources"
	var _signaldb = data.signaldb

	if source is RefCounted:
		if weak_reference:
			source = weakref(source)
			where = "ref" + where
	if not _signaldb.find_key(signal_name):
		_signaldb[signal_name] = _signaltemplate.duplicate()
	elif _signaldb[signal_name][where].has(source):
		if debug:
			printerr("SignalDB already contains an entry for ", source, " in ", signal_name, "'s sources...")
		return false
	_signaldb[signal_name][where].append(source)
	return true

func add_listener_to_db(connect_to, signal_name, flags, weak_reference, debug: bool = false) -> bool:
	return true

func _add_source_to_db(sourceid) -> void:
	pass

func _add_listener_to_db(sourceid) -> void:
	pass

func _validate_references(signal_name: String, sources: bool, listeners: bool):
	if listeners:
		data.signaldb[signal_name].reflisteners = data.signaldb[signal_name].reflisteners.filter(func(ref): is_instance_valid(ref))
	if sources:
		data.signaldb[signal_name].refsources = data.signaldb[signal_name].refsources.filter(func(ref): is_instance_valid(ref))

func connect_to_listeners(passed_signal, signal_name):
	_validate_references(signal_name, false, true)
	for signal_listener in data.signaldb[signal_name].listeners:
		passed_signal.connect(signal_listener)

func connect_to_sources():
	pass