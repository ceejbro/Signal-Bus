extends Resource
class_name SignalDB

var _debug
var _group_mode
var _unique_group_label
# Main data dictionary containing the database for signals -> sources and the reverse sources -> signals.
# Keys for the signaldb are by Signal name as string. Values take the form of _signaltemplate.
# Keys for the sourcedb are by Object IDs as int. Values take the form of _sourcetemplate.
var data: Dictionary = {
	"signaldb": {},
	"sourcedb": {},
}

# Template dictionary format for signal entries in data.signaldb. Each key is an array of ints corresponding to
# the Object IDs of the source or listening Object.
var _signaltemplate = {
	"sourceids": [],
	"listenerids": [],
}

# Template dictionary format for source entries in data.sourcedb. The first key is where a strong reference to a
# RefCounted or its descendants is kept if the appropriate flags are in the registering function call. If the Object
# is not to retain a strong reference or is not a descendant of RefCounted, this value should be null.
# The remaining keys are an array of strings corresponding to the Signal names where this Object is the source or 
# listener.
var _sourcetemplate = {
	"resource_strong_reference": null,
	"as_source": [],
	"as_listener": [],
}

func _init(debug_mode: bool = true, group_mode: bool = true, group_label: String = "SignalManager") -> void:
	_debug = debug_mode
	_group_mode = group_mode
	_unique_group_label = group_label


# Debug printing function. Toggled from the main SignalBus scene export variable 'Debug.'
func _printdbg(message: String, error: bool = false) -> void:
	if _debug:
		if error:
			printerr(message)
		else:
			print(message)

# Internal function for finding unique elements in an array even if the array includes null as an entry.
# Function does not alter the original array but returns a copy of the unique values as an array.
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
	
# External function for setting up the signal's DB entry and validating
func add_signal_to_db(passed_signal, weak_reference, override) -> bool:
	var signal_name: String = passed_signal.get_name()
	if signal_name == "":
		if _debug:
			printerr("Unable to use SignalBus for anonymous signals...")
		return false
	var source = passed_signal.get_object()
	var sourceid = passed_signal.get_object_id()
	if _group_mode:
		#group stuff
		return true
	else:
		if not data.signaldb.find_key(signal_name):
			data.signaldb[signal_name] = _signaltemplate.duplicate()
		var sigdb = data.signaldb[signal_name].sourceids

		if not source is RefCounted: 
			weak_reference = false
		
		if sigdb.has(source):
			_printdbg("SignalDB already contains an entry for " + source + " in " + signal_name + "'s sources...", true)
			return false
		sigdb.append(sourceid)
		_add_source_to_sourcedb(source, sourceid, signal_name, weak_reference, override)
	return true

func add_listener_to_db(
	connect_to, signal_name, flags, weak_reference, debug: bool = false
) -> bool:
	return true


func _add_source_to_sourcedb(source, sourceid, signal_name, weak_reference, override) -> void:
	var just_initialized = false
	if not data.sourcedb.find_key(sourceid):
		data.sourcedb[sourceid] = _sourcetemplate.duplicate()
		just_initialized = true
	data.sourcedb[sourceid].as_source.append(signal_name)
	if data.sourcedb[sourceid].resource_strong_reference:
		if weak_reference and override:
			data.sourcedb[sourceid].resource_strong_reference = null
	else:
		if not weak_reference and just_initialized:
			data.sourcedb[sourceid].resource_strong_reference = source
		if not weak_reference and override:
			data.sourcedb[sourceid].resource_strong_reference = source

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
	_printdbg("Validating Listeners...")
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
	_printdbg("Validating Sources...")
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
