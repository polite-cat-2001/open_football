class_name CareerTransfers
extends RefCounted
# Transfer lists that are not offers or contract talks: shortlist, the player's
# own "listed for transfer" status, the sent-offer rows and the transfer
# history. Port of server/career/actions.py (shortlist, transfer status) and
# the sent-offer / history blocks of the app's transfer centre snapshot.

const LISTED_STATUSES := ["transfer", "loan", "blocked"]
const CLEAR_WORDS := ["", "none", "clear"]

const OFFER_STATUS_LABELS := {
	"pending": "Pending",
	"counter": "Counter offer",
	"accepted": "Accepted",
	"refused": "Refused",
	"withdrawn": "Withdrawn",
	"expired": "Expired",
}
const KIND_LABELS := {"transfer": "Transfer", "loan": "Loan", "free_agent": "Free agent"}
# Every feed row becomes a node tree plus a face and two crests, so the model
# hands over the newest deals: the club's own history whole, the AI market
# trimmed to fill the rest of the limit.
# shortcut: an AI-heavy career loses its oldest AI deals on screen,
# add paging (or reuse the row nodes) if the full market archive is ever wanted.
const HISTORY_LIMIT := 200
const CONTRACT_STATUS_LABELS := {
	"pending": "In talks",
	"counter": "Counter offer",
	"accepted": "Agreed",
	"signed": "Signed",
}


static func toggle_shortlist(career: Career, catalog: TeamCatalog, player_id) -> Dictionary:
	var key := str(player_id)
	if catalog != null and (not key.is_valid_int() \
			or catalog.career_player(int(key), false).is_empty()):
		return {"ok": false, "error": "player not found", "shortlisted": false}
	var entries: Array = career.shortlist
	if entries.has(key):
		entries.erase(key)
		career.shortlist = entries
		_journal(career, "shortlist.removed", {"player_id": key})
		return {"ok": true, "error": "", "shortlisted": false}
	entries.append(key)
	career.shortlist = entries
	_journal(career, "shortlist.added", {"player_id": key})
	return {"ok": true, "error": "", "shortlisted": true}


static func set_status(career: Career, catalog: TeamCatalog, player_id, status) -> Dictionary:
	# The prototype's client toggles: sending the status a player already has
	# clears it (see state/squad.svelte.js applyTransferStatus).
	var key := str(player_id)
	if not career.player_ids.has(key):
		return {"ok": false, "error": "player is not in this squad", "status": ""}
	var normalized := str(status if status != null else "").strip_edges().to_lower()
	var transfers: Dictionary = career.player_transfers
	var current := str(transfers.get(key, ""))
	if CLEAR_WORDS.has(normalized):
		transfers.erase(key)
		career.player_transfers = transfers
		_journal(career, "player.transfer_status", {"player_id": key, "status": "none"})
		return {"ok": true, "error": "", "status": ""}
	if not LISTED_STATUSES.has(normalized):
		return {"ok": false, "error": "unknown transfer status", "status": current}
	var next := "" if normalized == current else normalized
	if next.is_empty():
		transfers.erase(key)
	else:
		transfers[key] = next
	career.player_transfers = transfers
	_journal(career, "player.transfer_status", {
		"player_id": key,
		"status": next if not next.is_empty() else "none",
	})
	return {"ok": true, "error": "", "status": next}


static func shortlist_rows(career: Career, catalog: TeamCatalog) -> Array:
	var rows: Array = []
	for player_id in career.shortlist:
		var item := CareerSearch.profile(catalog, career, player_id)
		if item.is_empty():
			continue
		item["shortlisted"] = true
		rows.append(item)
	return rows


static func listed_rows(career: Career, catalog: TeamCatalog) -> Array:
	var rows: Array = []
	for player_id in career.player_ids:
		var status := str(career.player_transfers.get(str(player_id), ""))
		if not LISTED_STATUSES.has(status):
			continue
		var item := CareerSearch.profile(catalog, career, player_id)
		if item.is_empty():
			continue
		item["status"] = status
		item["listed_for_transfer"] = status in ["transfer", "loan"]
		rows.append(item)
	return rows


static func sent_offer_rows(career: Career, catalog: TeamCatalog) -> Array:
	var rows: Array = []
	var offers: Array = career.transfer_offers
	for index in range(offers.size() - 1, -1, -1):
		var offer = offers[index]
		if not (offer is Dictionary):
			continue
		var view := CareerTransferOffers.view(career, offer)
		var player := CareerSearch.profile(catalog, career, offer.get("player_id"))
		rows.append({
			"offer_id": str(view.get("offer_id", "")),
			"player": player,
			"offer": view,
			"kind_label": kind_label(view.get("kind")),
			"status_label": offer_status_label(view.get("status")),
			"contract_status_label": contract_status_label(view.get("contract_status")),
			"fee": int(view.get("amount", 0)),
			"due": view.get("due"),
			"can_accept_counter": bool(view.get("can_accept_counter", false)),
			"can_withdraw": bool(view.get("can_withdraw", false)),
			"can_reoffer": bool(view.get("can_offer_again", false)),
			"can_negotiate": bool(view.get("can_negotiate", false)),
		})
	return rows


static func history_rows(career: Career, catalog: TeamCatalog) -> Array:
	# One feed from both ledgers: the club's own deals (`transfer_history`) and
	# the AI market (`world_transfers`). They cannot double-count - the world
	# market never trades with the own club - so this is a plain union. The cap
	# trims the AI side only, so the club's own history stays whole.
	var entries := _ledger(career, "transfer_history")
	var market := _ledger(career, "world_transfers")
	market.sort_custom(_newest_first)
	# `resize` would pad a short market with nulls, so only ever shrink it.
	var room := maxi(0, HISTORY_LIMIT - entries.size())
	if market.size() > room:
		market.resize(room)
	entries.append_array(market)
	entries.sort_custom(_newest_first)
	var roles := {}
	if catalog != null:
		var ids: Array = []
		for record in entries:
			ids.append(record.get("player_id", ""))
		roles = catalog.career_player_roles(ids)
	var rows: Array = []
	for record in entries:
		rows.append(_history_row(roles, catalog, record))
	return rows


static func _ledger(career: Career, key: String) -> Array:
	# Read the stored value, not the property: its getter would write an empty
	# list into the save, and a read model must not change the save.
	var value = career.data.get(key)
	if not (value is Array):
		return []
	var records: Array = []
	for record in value:
		if record is Dictionary:
			records.append(record)
	return records


static func _newest_first(a: Dictionary, b: Dictionary) -> bool:
	var left := str(a.get("date", "")).substr(0, 10)
	var right := str(b.get("date", "")).substr(0, 10)
	if left != right:
		return left > right
	return _record_id(a) > _record_id(b)


static func _record_id(record: Dictionary) -> String:
	var id := str(record.get("offer_id", "")) if record.get("offer_id") != null else ""
	if id.is_empty():
		id = str(record.get("id", ""))
	return id if not id.is_empty() else str(record.get("player_id", ""))


static func _history_row(roles: Dictionary, catalog: TeamCatalog,
		record: Dictionary) -> Dictionary:
	var player_id := str(record.get("player_id", ""))
	# The AI ledger stores the name itself; the club's own records carry only the
	# id and read the profile.
	var player: Dictionary = {}
	if str(record.get("player_name", "")).is_empty() and catalog != null \
			and player_id.is_valid_int():
		player = catalog.career_player(int(player_id), false)
	var role := str(player.get("role", ""))
	if role.is_empty() and player_id.is_valid_int():
		role = str(roles.get(int(player_id), ""))
	var from_club := _club(catalog, record.get("from_club_id"))
	var to_club := _club(catalog, record.get("to_club_id"))
	return {
		"id": _record_id(record),
		"player_id": player_id,
		"player_name": str(record.get("player_name", player.get("name", ""))),
		"photo": int(player_id) if player_id.is_valid_int() else 0,
		"role": role,
		"overall": roundf(float(record.get("overall", player.get("overall", 0.0))) * 10.0) / 10.0,
		"from_club_id": record.get("from_club_id"),
		"from_club_name": str(from_club.get("name", "")),
		"from_club_logo": CareerSearch.club_logo(from_club),
		"to_club_id": record.get("to_club_id"),
		"to_club_name": str(to_club.get("name", "")),
		"to_club_logo": CareerSearch.club_logo(to_club),
		"fee": int(record.get("fee", 0)),
		"kind": str(record.get("kind", "transfer")),
		"kind_label": kind_label(record.get("kind")),
		# A world deal is applied when it is recorded, so it has no status.
		"status": str(record.get("status", "completed")),
		"date": str(record.get("date", "")).substr(0, 10),
	}


static func offer_status_label(status) -> String:
	return str(OFFER_STATUS_LABELS.get(str(status), str(status)))


static func kind_label(kind) -> String:
	return str(KIND_LABELS.get(str(kind), str(kind)))


static func contract_status_label(status) -> String:
	if status == null:
		return ""
	return str(CONTRACT_STATUS_LABELS.get(str(status), ""))


static func _club(catalog: TeamCatalog, club_id) -> Dictionary:
	var key := str(club_id) if club_id != null else ""
	if catalog == null or not key.is_valid_int():
		return {}
	return catalog.career_club(int(key))


static func _journal(career: Career, kind: String, payload: Dictionary) -> void:
	career.journal.append({
		"seq": career.journal.size() + 1,
		"type": kind,
		"payload": payload,
	})
