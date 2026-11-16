class_name CareerScoutActionsModal
extends CareerScoutingModal
# Prototype career/scouting/ScoutActionsModal.svelte: the scout's action card —
# view the scout report, send him to another region, recall him, dismiss him,
# or cancel. Disabled rows keep focus like the prototype's disabled buttons but
# do nothing on confirm.

const ROWS := [
	{"id": "report", "label": "View scout report", "ticket": "A"},
	{"id": "move", "label": "Send to another region", "ticket": "A"},
	{"id": "recall", "label": "Recall scout", "ticket": "A"},
	{"id": "dismiss", "label": "Dismiss scout", "ticket": "A"},
	{"id": "cancel", "label": "Cancel", "ticket": "B"},
]


func setup_scout(scout: Dictionary, has_report: bool, can_recall: bool) -> void:
	var rows: Array = []
	for data in ROWS:
		var row: Dictionary = (data as Dictionary).duplicate(true)
		if row["id"] == "report":
			row["enabled"] = has_report
		elif row["id"] == "recall":
			row["enabled"] = can_recall
		rows.append(row)
	setup("%s: choose an action" % str(scout.get("name", "")), "", rows)
