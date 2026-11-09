class_name CareerSession
extends RefCounted
# In-process handoff between the career entry screens and the hub. Scenes are
# replaced, so the loaded career rides here instead of in scene properties.

static var career: Career = null
static var catalog: TeamCatalog = null
static var store: CareerSaveStore = null


static func clear() -> void:
	career = null
	catalog = null
	store = null
