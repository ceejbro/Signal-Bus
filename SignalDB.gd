extends Resource
class_name SignalDB

var debug
var data: Dictionary = {
	"signaldb": {},
	"sourcedb": {},
}
var _signaltemplate = {
	"strongsourceids": [],
	"sources": [],
	"refsources": [],
	"weakrefsources": [],
	"stronglistenerids": [],
	"listeners": [],
	"reflisteners": [],
	"weakreflisteners": [],
}
var _sourcetemplate = {
	"always_weak": true,
	"as_source": [],
	"as_listener": [],
}


func _init() -> void:
	debug = SignalBus.debug

func _get_unique_elements(passed_array: Array, null_allowed: bool = true) -> Array:
	var temparray = passed_array.duplicate()
	temparray.sort()
	var previous = null
	var item_index = 0
	if not temparray.has(null):
		for element in temparray:
			if element == previous:
				temparray[item_index] = null
			else:
				previous = element
			item_index += 1
		temparray.filter(func(element): return true if element != null else false)
	else:
		for element in temparray:
			if item_index == 0:
				previous = element
				item_index += 1
				continue
			if element == previous:
				temparray[item_index] = null
			else:
				previous = element
			item_index += 1
		temparray.filter(func(element): return true if element != null else false)
		if null_allowed:
			temparray.append(null)
	return temparray
	

func add_signal_to_db(passed_signal, weak_reference) -> bool:
	var signal_name: String = passed_signal.get_name()
	if signal_name == "":
		if debug:
			printerr("Unable to use SignalBus for anonymous signals...")
		return false
	var source = passed_signal.get_object()
	var sourceid = passed_signal.get_object_id()
	var where: String = "sources"
	if not data.signaldb.find_key(signal_name):
		data.signaldb[signal_name] = _signaltemplate.duplicate()
	var sigdb = data.signaldb[signal_name]

	if source is RefCounted:
		where = "ref" + where
		if weak_reference:
			source = sourceid
			where = "weak" + where
	else:
		weak_reference = false	
	
	if sigdb[where].has(source):
		if debug:
			printerr(
				"SignalDB already contains an entry for ",
				source,
				" in ",
				signal_name,
				"'s sources..."
			)
		return false
	if not weak_reference and not sigdb.strongsourceids.has(sourceid):
		sigdb.strongsourceids.append(sourceid)
	sigdb[where].append(source)
	_add_source_to_sourcedb(sourceid, signal_name, weak_reference)
	return true


func add_listener_to_db(
	connect_to, signal_name, flags, weak_reference, debug: bool = false
) -> bool:
	return true


func _add_source_to_sourcedb(sourceid, signal_name, weak_reference) -> void:
	if not data.sourcedb.find_key(sourceid):
		data.sourcedb[sourceid] = _sourcetemplate.duplicate()
	data.sourcedb[sourceid].as_source.append(signal_name)
	if data.sourcedb[sourceid].always_weak:
		if not weak_reference:
			data.sourcedb[sourceid].always_weak = false


func _add_listener_to_sourcedb(sourceid, signal_name, weak_reference) -> void:
	if not data.sourcedb.find_key(sourceid):
		data.sourcedb[sourceid] = _sourcetemplate.duplicate()
	data.sourcedb[sourceid].as_listener.append(signal_name)
	if data.sourcedb[sourceid].always_weak:
		if not weak_reference:
			data.sourcedb[sourceid].always_weak = false

func _purge_sourceid(sourceid) -> void:
	var valid: bool = is_instance_id_valid(sourceid)
	var from_id = null
	if valid:
		from_id = instance_from_id(sourceid)
	
	for signal_name in data.sourcedb[sourceid].as_source:
		if data.sourcedb[sourceid].always_weak:
			data.signaldb[signal_name].weakrefsources.erase(sourceid)
		else:
			data.signaldb[signal_name].weakrefsources.erase(sourceid)
			data.signaldb[signal_name].strongsourceids.erase(sourceid)
			if valid and from_id is RefCounted:
				data.signaldb[signal_name].refsources.erase(from_id)
			elif valid and not from_id is RefCounted:
				data.signaldb[signal_name].sources.erase(from_id)
			elif not valid:
				data.signaldb[signal_name].sources.filter(func(element): return is_instance_valid(element))
				data.signaldb[signal_name].refsources.filter(func(element): return is_instance_valid(element))

	for signal_name in data.sourcedb[sourceid].as_listener:
		data.signaldb[signal_name].stronglistenerids.erase(sourceid)
		data.signaldb[signal_name].weakreflisteners.erase(sourceid)
		if valid and from_id is RefCounted:
			data.signaldb[signal_name].reflisteners.erase(from_id)
		elif valid and not from_id is RefCounted:
			data.signaldb[signal_name].listeners.erase(from_id)
		elif not valid:
			data.signaldb[signal_name].listeners.filter(func(element): return is_instance_valid(element))
			data.signaldb[signal_name].listeners.filter(func(element): return is_instance_valid(element))


func _validate_references(signal_name: String, sources: bool, listeners: bool):
	if debug:
		print("Validating Listeners...")
	if listeners:
		var invalid_ref = data.signaldb[signal_name].weakreflisteners.filter(
			func(ref): return not is_instance_id_valid(ref)
		)
		data.signaldb[signal_name].weakreflisteners = data.signaldb[signal_name].weakreflisteners.filter(
			func(ref): return is_instance_id_valid(ref)
		)
		var invalid_id = data.signaldb[signal_name].stronglistenerids.filter(
			func(ref): return is_instance_id_valid(ref)
		)
	if debug:
		print("Validating Sources...")
	if sources:
		var invalid_ref = data.signaldb[signal_name].weakrefsources.filter(
			func(ref): return not is_instance_id_valid(ref)
		)
		data.signaldb[signal_name].weakrefsources = data.signaldb[signal_name].weakrefsources.filter(
			func(ref): return is_instance_id_valid(ref)
		)
		var invalid_id = data.signaldb[signal_name].strongsourceids.filter(
			func(ref): return is_instance_id_valid(ref)
		)


func connect_to_listeners(passed_signal, signal_name):
	_validate_references(signal_name, false, true)
	for signal_listener in data.signaldb[signal_name].listeners:
		passed_signal.connect(signal_listener)


func connect_to_sources():
	pass
