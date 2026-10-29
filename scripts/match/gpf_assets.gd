class_name GpfAssets
extends RefCounted
# Shared lookups for the original GameplayFootball assets (test.ase material naming).


static func material_index(material_name: String) -> int:
	if not material_name.begins_with("mat"):
		return -1
	return int(material_name.substr(3))
