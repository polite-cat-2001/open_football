class_name NetworkValidation
extends RefCounted
# Pure validation/filtering for the LAN setup forms. Mirrors the original
# NetworkJoinPage::IsValidAddress plus the shell's port/name rules; no runtime
# or UI dependency, so headless tests can exercise it directly.

const NAME_MAX := 16
const ADDRESS_MAX := 64
const PORT_MAX := 65535

const ADDRESS_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
const NAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _"
const PORT_CHARS := "0123456789"


static func allowed_chars(mode: String) -> String:
	match mode:
		"address":
			return ADDRESS_CHARS
		"name":
			return NAME_CHARS
		"port":
			return PORT_CHARS
	return ""


static func is_valid_port(text: String) -> bool:
	if text.is_empty() or text.length() > 5:
		return false
	for i in text.length():
		if text[i] < "0" or text[i] > "9":
			return false
	var port := int(text)
	return port >= 1 and port <= PORT_MAX


static func is_valid_name(text: String) -> bool:
	var value := text.strip_edges()
	if value.is_empty() or value.length() > NAME_MAX:
		return false
	for i in value.length():
		if NAME_CHARS.find(value[i]) < 0:
			return false
	return true


static func is_valid_address(text: String) -> bool:
	var value := text.strip_edges()
	if value.is_empty() or value.length() > ADDRESS_MAX:
		return false
	var only_digits_and_dots := true
	for i in value.length():
		var c := value[i]
		if c < "0" or c > "9":
			if c != ".":
				only_digits_and_dots = false
				break
	if only_digits_and_dots:
		return _is_valid_ipv4(value)
	return _is_valid_hostname(value)


static func filter(text: String, mode: String) -> String:
	var allowed := allowed_chars(mode)
	var limit := ADDRESS_MAX
	match mode:
		"name":
			limit = NAME_MAX
		"port":
			limit = 5
	var result := ""
	for i in text.length():
		var c := text[i]
		if allowed.find(c) >= 0:
			result += c
		if result.length() >= limit:
			break
	return result


static func _is_valid_ipv4(text: String) -> bool:
	var parts := text.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if part.is_empty() or part.length() > 3:
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
	return true


static func _is_valid_hostname(text: String) -> bool:
	var labels := text.split(".")
	for label in labels:
		if label.is_empty() or label.length() > 63:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
		for i in label.length():
			var c := label[i]
			var ok := (c >= "0" and c <= "9") or (c >= "a" and c <= "z") \
				or (c >= "A" and c <= "Z") or c == "-"
			if not ok:
				return false
	return true
