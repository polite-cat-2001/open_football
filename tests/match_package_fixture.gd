extends RefCounted
# Test helper: build a real match package from the game database so the C++
# runtime can start without touching SQLite. Shared by the GpfRuntime headless
# checks (the shipping path builds the same package in prematch/gpf_slice).


static func build(data_root: String = "", home_id: int = 3, away_id: int = 8,
		options: Dictionary = {}) -> Dictionary:
	var catalog := TeamCatalog.new()
	if not catalog.load_data_root(data_root):
		push_error("MatchPackageFixture: " + catalog.error)
		return {}
	var builder := MatchPackage.new()
	var package := builder.build_from_ids(catalog, home_id, away_id, options)
	if package.is_empty():
		push_error("MatchPackageFixture: " + builder.error)
	return package
