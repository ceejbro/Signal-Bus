@tool
extends Node

var property
var method

func _get_property_list() -> Array:
	return [
		{
			name = "property",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_ENUM,
			hint_string = get_parent().get_signal_list().map(func(dict): return dict.name).reduce(func(accum, dict): return accum + "," + dict),
		},
		{
			name = "method",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_ENUM,
			hint_string = get_parent().get_script().get_script_method_list().map(func(dict): return dict.name).reduce(func(accum, dict): return accum + "," + dict),
		},
	]
