extends RefCounted

const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const MAX_SEQ := 1000000000
var host: Variant
var preview_state: Dictionary = {}
var inventory_version := 0
var revision := 0
var busy := false
var queued := false
var running := false
var bag_save_failed := false
var _last_token := ""
var _last_token_receipt: Dictionary = {}

static func defaults() -> Dictionary:
	return {"epoch": "", "donation_seq": 0, "bag_seq": 0, "pending_bag": null, "last_donation": null, "last_bag": null}

static func new_epoch() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func amounts_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != Catalog.ITEMS.size(): return false
	for id in Catalog.ITEMS:
		if not Catalog.integer(value.get(id), Catalog.RESOURCE_LIMIT): return false
	return true

static func normalize_amounts(value: Dictionary) -> void:
	for id in Catalog.ITEMS: value[id] = int(value[id])

static func _id(epoch: String, kind: String, seq: int) -> String:
	return "%s:%s:%d" % [epoch, kind, seq]

static func _bag_number(id: Variant, epoch: String, high: int) -> int:
	if not id is String: return 0
	var parts: PackedStringArray = id.split(":")
	if parts.size() != 3 or parts[0] != epoch or parts[1] != "bag" or not parts[2].is_valid_int(): return 0
	var n := int(parts[2])
	return n if n > 0 and n <= high and id == _id(epoch, "bag", n) else 0

static func valid(state: Dictionary) -> bool:
	var p: Variant = state.get("public_project")
	if not p is Dictionary or p.size() != 6: return false
	for key in defaults():
		if not p.has(key): return false
	if not p.epoch is String: return false
	if p.epoch != "":
		if p.epoch.length() != 32: return false
		for c in p.epoch:
			if c not in "0123456789abcdef": return false
	for key in ["donation_seq", "bag_seq"]:
		if not Catalog.integer(p[key], MAX_SEQ): return false
		p[key] = int(p[key])
	if p.epoch == "" and (p.donation_seq != 0 or p.bag_seq != 0): return false
	if (p.donation_seq == 0) != (p.last_donation == null): return false
	var pending: Variant = p.pending_bag
	var last: Variant = p.last_bag
	if p.bag_seq == 0 and (pending != null or last != null): return false
	if p.bag_seq > 0 and pending == null and last == null: return false
	if pending != null and p.bag_seq > 1 and last == null: return false
	for bag in [pending, last]:
		if bag == null: continue
		var is_pending: bool = bag == pending
		if not bag is Dictionary or bag.size() != 6: return false
		var n := _bag_number(bag.get("bag_id"), p.epoch, p.bag_seq)
		if n == 0 or (is_pending and n != p.bag_seq): return false
		if not is_pending and n != p.bag_seq - (1 if pending != null else 0): return false
		var op_key := "deposit_operation_id" if is_pending else "operation_id"
		if bag.get(op_key) != String(bag.bag_id) + ":deposit": return false
		if not amounts_valid(bag.get("items")) or not bag.get("new_core") is bool: return false
		normalize_amounts(bag.items)
		var weight := 0
		for id in Catalog.ITEMS: weight += int(bag.items[id]) * int(Catalog.ITEMS[id][1])
		if weight > Catalog.BASE_CAPACITY + int(state.get("net_expansion", 0)) * 4 or (weight == 0 and not bag.new_core): return false
		if is_pending:
			if bag.get("origin") not in Catalog.POOLS or not Catalog.integer(bag.get("lost_count"), Catalog.RESOURCE_LIMIT): return false
			bag.lost_count = int(bag.lost_count)
			if bag.new_core and (not state.get("dive_sonar", false) or state.get("dive_core", false)): return false
		else:
			if not amounts_valid(bag.get("before")) or not amounts_valid(bag.get("after")): return false
			normalize_amounts(bag.before)
			normalize_amounts(bag.after)
			for id in Catalog.ITEMS:
				if bag.before[id] + bag.items[id] != bag.after[id]: return false
			if bag.new_core and not state.get("dive_core", false): return false
	if pending != null and last != null and _bag_number(last.bag_id, p.epoch, p.bag_seq) >= p.bag_seq: return false
	var d: Variant = p.last_donation
	if d != null:
		if not d is Dictionary or d.size() != 6 or not Catalog.integer(d.get("seq"), MAX_SEQ) or d.get("seq") != p.donation_seq or d.get("operation_id") != _id(p.epoch, "donation", p.donation_seq): return false
		for key in ["requested", "before", "after"]:
			if not amounts_valid(d.get(key)): return false
			normalize_amounts(d[key])
		var total := 0
		for id in Catalog.ITEMS:
			if d.before[id] - d.requested[id] != d.after[id]: return false
			total += int(d.requested[id])
		if total == 0 or not d.get("related_bag_id") is String: return false
		if d.related_bag_id != "" and _bag_number(d.related_bag_id, p.epoch, p.bag_seq) == 0: return false
		d.seq = int(d.seq)
	return true

func invalidate_preview() -> void:
	inventory_version += 1
	preview_state.clear()

func clear_draft() -> void:
	preview_state.clear()

func bag_items() -> Dictionary:
	return host.public_project.pending_bag.items.duplicate(true) if host.public_project.pending_bag != null else Catalog.resources()

func deficits(items: Dictionary = {}) -> Dictionary:
	var result := Catalog.resources()
	var incoming := bag_items() if items.is_empty() else items
	for id in result: result[id] = maxi(0, int(host.resources[id]) + int(incoming.get(id, 0)) - Catalog.RESOURCE_LIMIT)
	return result

func context() -> Dictionary:
	return {"balances": host.resources.duplicate(true), "deficits": deficits(), "bag_items": bag_items()}

func _related_bag_id() -> String:
	var p: Dictionary = host.public_project
	if p.pending_bag != null: return p.pending_bag.bag_id
	return ""

func preview(amounts: Dictionary, pearl_selected: bool) -> Dictionary:
	clear_draft()
	if not amounts_valid(amounts): return {"error": "请输入六种资源的合法整数数量。"}
	var after: Dictionary = host.resources.duplicate(true)
	var total := 0
	for id in Catalog.ITEMS:
		if amounts[id] > after[id]: return {"error": "所选数量超过基地库存。"}
		after[id] = int(after[id]) - int(amounts[id])
		total += int(amounts[id])
	if total == 0: return {"error": "请至少选择一件材料。"}
	if amounts.pearl > 0 and not pearl_selected: return {"error": "请先主动选择深水珍珠。"}
	var epoch: String = host.public_project.epoch
	if epoch == "": epoch = new_epoch()
	var token := new_epoch()
	var remaining := Catalog.resources()
	var incoming := bag_items()
	for id in remaining: remaining[id] = maxi(0, int(after[id]) + int(incoming[id]) - Catalog.RESOURCE_LIMIT)
	preview_state = {"token": token, "amounts": amounts.duplicate(true), "before": host.resources.duplicate(true), "after": after, "bag_items": incoming, "deficits": remaining, "version": inventory_version, "bag_id": _related_bag_id(), "epoch": epoch, "operation_id": _id(epoch, "donation", int(host.public_project.donation_seq) + 1)}
	return preview_state.duplicate(true)

func confirm(token: String, pearl_confirmed: bool) -> Dictionary:
	if token == _last_token and not _last_token_receipt.is_empty() and host.public_project.last_donation == _last_token_receipt:
		return {"ok": true, "receipt": _last_token_receipt.duplicate(true), "duplicate": true}
	if busy or preview_state.is_empty() or token != preview_state.token: return {"ok": false, "error": "确认已失效，请重新预览。"}
	var draft := preview_state.duplicate(true)
	if draft.version != inventory_version or draft.before != host.resources or draft.bag_id != _related_bag_id():
		clear_draft()
		return {"ok": false, "error": "库存或待袋已变化，请重新预览。"}
	if draft.amounts.pearl > 0 and not pearl_confirmed: return {"ok": false, "error": "请额外确认珍珠永久消耗。"}
	if host.public_project.donation_seq >= MAX_SEQ: return {"ok": false, "error": "投料序号已用尽。"}
	busy = true
	var before: Dictionary = host._round_state().duplicate(true)
	host.resources = draft.after.duplicate(true)
	host.public_project.epoch = draft.epoch
	host.public_project.donation_seq += 1
	var receipt := {"operation_id": draft.operation_id, "seq": host.public_project.donation_seq, "requested": draft.amounts, "before": draft.before, "after": draft.after, "related_bag_id": draft.bag_id}
	host.public_project.last_donation = receipt
	var saved: bool = host._cache_round()
	if not saved: host._restore_round(before)
	busy = false
	clear_draft()
	if not saved: return {"ok": false, "error": "投料保存失败，整笔未生效；请重新预览。"}
	_last_token = token
	_last_token_receipt = receipt.duplicate(true)
	queue_recheck()
	return {"ok": true, "receipt": receipt.duplicate(true)}

func seal_bag(items: Array, new_core: bool, origin: String, lost_count: int) -> bool:
	if busy or host.public_project.pending_bag != null or origin not in Catalog.POOLS or not Catalog.integer(lost_count, Catalog.RESOURCE_LIMIT): return false
	var counts := Catalog.resources()
	for id in items:
		if not counts.has(id): return false
		counts[id] += 1
	if items.is_empty() and not new_core: return host._cache_round()
	if host.public_project.bag_seq >= MAX_SEQ: return false
	var before: Dictionary = host._round_state().duplicate(true)
	busy = true
	if host.public_project.epoch == "": host.public_project.epoch = new_epoch()
	host.public_project.bag_seq += 1
	var id := _id(host.public_project.epoch, "bag", host.public_project.bag_seq)
	host.public_project.pending_bag = {"bag_id": id, "deposit_operation_id": id + ":deposit", "items": counts, "new_core": new_core, "origin": origin, "lost_count": lost_count}
	var saved: bool = host._cache_round()
	if not saved: host._restore_round(before)
	busy = false
	if saved:
		invalidate_preview()
		bag_save_failed = false
	return saved

func deposit_bag() -> bool:
	if busy: return false
	var bag: Variant = host.public_project.pending_bag
	if bag == null: return true
	for amount in deficits().values():
		if amount > 0: return false
	busy = true
	var before: Dictionary = host._round_state().duplicate(true)
	var stock: Dictionary = host.resources.duplicate(true)
	var items: Array = []
	for id in Catalog.ITEMS:
		host.resources[id] = int(host.resources[id]) + int(bag.items[id])
		for i in int(bag.items[id]): items.append(id)
	if bag.new_core: host.dive_core = true
	host.technology.record_manual(items)
	host.public_project.last_bag = {"bag_id": bag.bag_id, "operation_id": bag.deposit_operation_id, "items": bag.items.duplicate(true), "new_core": bag.new_core, "before": stock, "after": host.resources.duplicate(true)}
	host.public_project.pending_bag = null
	var saved: bool = host._cache_round()
	if not saved: host._restore_round(before)
	busy = false
	bag_save_failed = not saved
	if saved: invalidate_preview()
	return saved

func queue_recheck() -> void:
	if queued or running: return
	queued = true
	_run_recheck.call_deferred()

func _run_recheck() -> void:
	queued = false
	if not is_instance_valid(host) or busy or running: return
	running = true
	deposit_bag()
	running = false
	host._refresh_dive_ui()
	host._refresh_public_project_service()

func snapshot() -> Dictionary:
	revision += 1
	var p: Dictionary = host.public_project
	var d: Variant = p.last_donation
	var b: Variant = p.pending_bag if p.pending_bag != null else p.last_bag
	if b != null and d != null and d.related_bag_id != b.bag_id:
		if p.pending_bag != null:
			d = null
		else:
			b = null
	if d == null and b == null: return {}
	var donation_rows: Array = []
	if d != null:
		for id in Catalog.ITEMS:
			if d.requested[id] > 0: donation_rows.append({"id": id, "name": Catalog.ITEMS[id][0], "requested": int(d.requested[id]), "actual": int(d.requested[id]), "before": int(d.before[id]), "after": int(d.after[id])})
	var bag := {"status": "not_applicable", "rows": [], "deficits": [], "core": null, "independent": true}
	if b != null:
		var complete: bool = p.pending_bag == null
		bag["status"] = "completed" if complete else ("save_failed" if bag_save_failed else "processing")
		bag["bag_id"] = b.bag_id
		bag["operation_id"] = b.operation_id if complete else b.deposit_operation_id
		for id in Catalog.ITEMS:
			if b.items[id] > 0: bag.rows.append({"id": id, "name": Catalog.ITEMS[id][0], "amount": int(b.items[id]), "actual": int(b.items[id]) if complete else null, "after": int(b.after[id]) if complete else null})
		if b.new_core: bag.core = {"id": "echo_core", "name": "回声核心", "amount": 1}
		if not complete:
			var missing := deficits()
			for id in missing:
				if missing[id] > 0: bag.deficits.append({"id": id, "name": Catalog.ITEMS[id][0], "amount": missing[id]})
			if not bag.deficits.is_empty(): bag.status = "capacity_short"
	var view_id: String = d.operation_id if d != null else bag.operation_id
	if d != null and b != null: view_id += ":view:" + String(b.bag_id)
	return {"contract_version": 2, "operation_id": view_id, "revision": revision, "purpose": "donation" if d != null else "bag", "donation": {"status": "completed" if d != null else "not_applicable", "rows": donation_rows}, "bag": bag, "production": {"status": "not_applicable", "claimable": 0, "space_needed": 0, "progress": null, "reasons": []}, "latest_balances": host.resources.duplicate(true), "available_actions": {"retry_bag": true, "check_bag": true, "continue_space": true, "recheck_edit": true, "return_base": true, "details": true}}
