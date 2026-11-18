extends SceneTree

const Service = preload("res://scripts/scenes/public_project_service.gd")
const Catalog = preload("res://scripts/scenes/underwater_catalog.gd")
const Technology = preload("res://scripts/scenes/water_technology.gd")
const ResultPanel = preload("res://scripts/scenes/public_project_result_panel.gd")
const DISK_PATHS := ["user://sea_chapter_v1.json", "user://sea_chapter_v1.json.tmp", "user://sea_chapter_v1.json.bak", "user://sea_chapter_v1.json.bak.pending", "user://sea_chapter_v1.json.tmp.recover"]

# The fake host persists JSON through the real GameManager validator. No player files are written.
class TransactionHost extends Node:
	var game: Node
	var resources: Dictionary = Catalog.resources()
	var public_project: Dictionary = Service.defaults()
	var technology = Technology.new()
	var dive_archive := Catalog.archive_defaults()
	var tide_table := false
	var dive_core := false
	var dive_sonar := true
	var net_expansion := 0
	var saved: Dictionary = {}
	var fail_next := false
	var real_disk := false
	var writes := 0
	var service = Service.new()

	func _round_state() -> Dictionary:
		var state := {
			"wood": 0, "scrap": 0, "water": 0, "fiber": 0, "rope": 0,
			"raft_tiles": 1, "core_level": 1, "collectors": 0, "orders_completed": 0,
			"pending_water": 0, "pending_fiber": 0, "production_elapsed": 0.0, "debris_elapsed": 0.0,
			"automated_collecting": false, "workshop_built": false, "resident": false,
			"resident_working": false, "partner": false, "blueprint": false, "tide_table": false,
			"delegated": false, "neighbor_surveyed": false, "guide_seen_pickup": false,
			"guide_seen_claim": false, "building_slots": ["core"], "player_foot": [0, 0],
			"debris": [], "result": "", "at_salt": false, "salt": 0, "salt_elapsed": 0.0,
			"filter_blueprint": false, "filter_built": false, "salt_nodes": [], "at_wreck": false,
			"wreck_scrap": 0, "wreck_nodes": [], "wreck_elapsed": 0.0, "hazard_elapsed": 0.0,
			"wreck_hp": 3, "sail_loadout": "", "dive_shoal": true, "dive_archived": false,
			"equipment": Catalog.equipment(), "core_reward_claimed": false,
			"dive_workshop_unlocked": false, "dive_workshop_built": false,
			"node_states": Catalog.defaults(1000.0), "net_expansion": net_expansion,
			"resources": resources.duplicate(true), "public_project": public_project.duplicate(true),
			"technology": technology.state.duplicate(true), "dive_core": dive_core, "dive_sonar": dive_sonar,
			"dive_archive": dive_archive.duplicate(true), "species_records": Catalog.species_records()
		}
		return state

	func _restore_round(state: Dictionary) -> void:
		dive_archive = state.get("dive_archive", Catalog.archive_defaults()).duplicate(true)
		resources = state.resources.duplicate(true)
		public_project = state.public_project.duplicate(true)
		technology.state = state.technology.duplicate(true)
		dive_core = state.dive_core
		dive_sonar = state.dive_sonar
		net_expansion = int(state.net_expansion)

	func _cache_round() -> bool:
		writes += 1
		if fail_next:
			fail_next = false
			return false
		var decoded: Dictionary = game._read_sea_text(JSON.stringify({"version": 11, "state": _round_state()}))
		if decoded.is_empty(): return false
		if real_disk and not game.save_sea_state(_round_state()): return false
		saved = decoded.duplicate(true)
		return true

	func _refresh_dive_ui() -> void:
		pass

	func _refresh_public_project_service() -> void:
		pass

var checks := 0
var failures := 0
var game: Node
var hosts: Array[TransactionHost] = []
var recovery_quarantines: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func same(actual: Variant, expected: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(actual, "", true, true)) == JSON.parse_string(JSON.stringify(expected, "", true, true))

func host_with(stock: int = 20) -> TransactionHost:
	var host := TransactionHost.new()
	host.game = game
	host.service.host = host
	host.technology.host = host
	for id in Catalog.ITEMS: host.resources[id] = stock
	root.add_child(host)
	hosts.append(host)
	check(host._cache_round(), "假宿主初始状态经真实v9解析持久化")
	return host

func amounts(id: String = "", count: Variant = 0) -> Dictionary:
	var result := Catalog.resources()
	if id != "": result[id] = count
	return result

func read(state: Dictionary, version: Variant = 9) -> Dictionary:
	return game._read_sea_text(JSON.stringify({"version": version, "state": state}))

func donation_tests() -> void:
	var host := host_with()
	var before := host._round_state()
	var request := Catalog.resources()
	var index := 1
	for id in request:
		request[id] = index
		index += 1
	var draft: Dictionary = host.service.preview(request, true)
	check(draft.has("token") and same(host._round_state(), before), "六资源预览只读无永久扣料")
	if not draft.has("token"): return
	var result: Dictionary = host.service.confirm(draft.token, true)
	check(result.get("ok", false), "六资源确认成功")
	for id in request:
		check(host.resources[id] == 20 - request[id] and host.saved.resources[id] == host.resources[id], "六资源永久扣料 " + id)
	var committed := host._round_state()
	var writes := host.writes
	result = host.service.confirm(draft.token, true)
	check(result.get("ok", false) and result.get("duplicate", false) and host.writes == writes and same(host._round_state(), committed), "重复token返回原回执且不重扣不重存")
	var restarted := host_with(0)
	restarted._restore_round(host.saved)
	check(not restarted.service.confirm(draft.token, true).get("ok", false) and same(restarted._round_state(), committed), "重启不恢复预览token且不重扣")
	check(host.public_project.last_donation.requested == request and host.public_project.donation_seq == 1, "回执完整保存六资源实际扣料")
	var view: Dictionary = host.service.snapshot()
	check(view.get("contract_version") == 2 and view.donation.rows.size() == 6 and view.donation.status == "completed", "业务快照显示六资源完成")

	var invalid: Array[Dictionary] = [amounts(), amounts("coral", -1), amounts("coral", 0.5), amounts("coral", true), amounts("coral", "1"), amounts("coral", 21), amounts("unknown", 1)]
	var missing := amounts("coral", 1)
	missing.erase("shell")
	invalid.append(missing)
	var replacement := amounts("coral", 1)
	replacement.erase("shell")
	replacement.unknown = 0
	invalid.append(replacement)
	for bad in invalid:
		before = host._round_state()
		check(host.service.preview(bad, true).has("error") and same(host._round_state(), before), "拒绝零/负/小数/bool/未知/缺项/超余额 " + str(bad))
	check(host.service.preview(amounts("pearl", 2), false).has("error"), "珍珠2未主动选择不能预览")
	draft = host.service.preview(amounts("pearl", 2), true)
	before = host._round_state()
	check(draft.has("token"), "珍珠2主动选择允许预览")
	if draft.has("token"):
		check(not host.service.confirm(draft.token, false).get("ok", false) and same(host._round_state(), before), "珍珠2未二次确认不扣料")
		check(host.service.confirm(draft.token, true).get("ok", false) and host.resources.pearl == before.resources.pearl - 2, "珍珠2额外确认后永久扣2")

func invalidation_tests() -> void:
	var host := host_with()
	var draft: Dictionary = host.service.preview(amounts("coral", 1), false)
	host.service.invalidate_preview()
	check(not host.service.confirm(draft.token, false).get("ok", false) and host.resources.coral == 20, "库存版本变化使token失效")
	draft = host.service.preview(amounts("coral", 1), false)
	host.resources.shell += 1
	check(not host.service.confirm(draft.token, false).get("ok", false) and host.resources.coral == 20, "未显式失效但库存余额变化也拒绝")
	draft = host.service.preview(amounts("coral", 1), false)
	check(host.service.seal_bag(["shell"], false, "shoal", 0), "预览后封袋成功")
	check(not host.service.confirm(draft.token, false).get("ok", false) and host.resources.coral == 20, "待袋变化使旧token失效")
	draft = host.service.preview(amounts("coral", 1), false)
	var stale: Dictionary = draft.duplicate(true)
	check(host.service.deposit_bag(), "待袋入库成功")
	# Preserve the stale draft deliberately to exercise the identity guard independently of invalidation.
	host.service.preview_state = stale
	host.service.inventory_version = int(stale.version)
	host.resources = stale.before.duplicate(true)
	check(not host.service.confirm(stale.token, false).get("ok", false), "即使版本与余额一致待袋身份变化仍拒绝")

func failure_tests() -> void:
	var host := host_with()
	var before := host._round_state()
	var saved := host.saved.duplicate(true)
	var draft: Dictionary = host.service.preview(amounts("coral", 3), false)
	host.fail_next = true
	check(not host.service.confirm(draft.token, false).get("ok", false), "注入投料保存失败")
	check(same(host._round_state(), before) and same(host.saved, saved), "投料失败库存/epoch/序号/回执全部恢复")
	check(not host.service.confirm(draft.token, false).get("ok", false), "投料失败旧token失效")
	draft = host.service.preview(amounts("coral", 3), false)
	check(host.service.confirm(draft.token, false).get("ok", false) and host.resources.coral == 17, "重新预览后投料可成功")

	host = host_with(Catalog.RESOURCE_LIMIT)
	before = host._round_state()
	host.fail_next = true
	check(not host.service.seal_bag(["coral"], true, "shoal", 2) and same(host._round_state(), before), "封袋写失败不留幽灵袋与序号")
	check(host.service.seal_bag(["coral"], true, "shoal", 2), "满仓返航袋与核心持久封存成功")
	check(host.resources == before.resources and not host.dive_core and not host.technology.state.manual.shoal, "封袋不加库存不解锁manual/core")
	var pending: Dictionary = host.public_project.pending_bag.duplicate(true)
	check(same(host.saved.public_project.pending_bag, pending) and pending.lost_count == 2 and pending.origin == "shoal", "持久pending保留材料核心来源和损失")
	var restarted := host_with(0)
	restarted._restore_round(host.saved)
	check(same(restarted.public_project.pending_bag, pending) and not restarted.dive_core, "重启恢复原袋与未获得核心")
	before = host._round_state()
	check(not host.service.deposit_bag() and same(host._round_state(), before), "满仓直接入库拒绝且袋不变")
	check(not host.service.seal_bag(["shell"], false, "shoal", 0), "已有pending禁止覆盖袋")
	var view: Dictionary = host.service.snapshot()
	check(view.bag.status == "capacity_short" and view.bag.rows[0].actual == null, "满仓快照不伪造入库实际量")

	draft = host.service.preview(amounts("coral", 1), false)
	check(host.service.confirm(draft.token, false).get("ok", false), "投料腾出一格已永久提交")
	host.fail_next = true
	await process_frame
	check(host.resources.coral == Catalog.RESOURCE_LIMIT - 1 and host.public_project.donation_seq == 1, "自动入库保存失败不回滚已提交投料")
	check(same(host.public_project.pending_bag, pending) and not host.dive_core and not host.technology.state.manual.shoal, "入库失败材料/core/manual同回滚且保留原袋")
	check(host.saved.resources.coral == Catalog.RESOURCE_LIMIT - 1 and same(host.saved.public_project.pending_bag, pending), "入库失败持久档仍为投料后原袋")
	view = host.service.snapshot()
	check(view.donation.status == "completed" and view.bag.status == "save_failed", "投料成功与袋保存失败独立显示")
	var writes := host.writes
	check(host.service.confirm(draft.token, false).get("duplicate", false) and host.writes == writes and host.resources.coral == Catalog.RESOURCE_LIMIT - 1, "入库失败后重复确认不再扣料")
	check(host.service.deposit_bag(), "恢复保存后可手动重试原袋入库")
	check(host.resources.coral == Catalog.RESOURCE_LIMIT and host.public_project.pending_bag == null and host.public_project.donation_seq == 1, "入库重试只加原袋一次不重复投料")
	check(host.dive_core and host.technology.state.manual.shoal and host.saved.dive_core and host.saved.technology.manual.shoal, "入库成功core/manual与材料同持久提交")
	check(host.public_project.last_bag.bag_id == pending.bag_id and host.public_project.last_bag.operation_id == pending.deposit_operation_id, "入库回执保留原袋事务身份")
	before = host._round_state()
	writes = host.writes
	check(host.service.deposit_bag() and same(host._round_state(), before) and host.writes == writes, "重复入库空操作不重复奖励")

# GDScript has no try/finally: the caller always runs cleanup after this body,
# and each fixture is cleared before the next case (check never aborts).
func clear_disk_fixtures() -> void:
	for path in recovery_quarantines:
		if FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(path) == OK, "清理本次恢复隔离文件 " + path)
	recovery_quarantines.clear()
	for path in DISK_PATHS:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			var marker := absolute.path_join("transaction-blocker")
			if FileAccess.file_exists(marker): check(DirAccess.remove_absolute(marker) == OK, "清理目录阻塞标记")
			check(DirAccess.remove_absolute(absolute) == OK, "清理故障目录 " + path)
		elif FileAccess.file_exists(path):
			check(DirAccess.remove_absolute(absolute) == OK, "清理测试存档 " + path)

func block_disk_path(path: String) -> void:
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path)) == OK, "建立目录阻塞 " + path)
	var marker := FileAccess.open(path.path_join("transaction-blocker"), FileAccess.WRITE)
	check(marker != null, "阻塞目录保持非空 " + path)
	if marker != null:
		marker.store_string("test-only")
		marker.close()

func disk_failure_case(stage: String, blocked: String, message: String) -> void:
	clear_disk_fixtures()
	var host := host_with()
	host.real_disk = true
	check(host._cache_round(), stage + "真实基线保存")
	var before := host._round_state()
	var main_text := FileAccess.get_file_as_string(DISK_PATHS[0])
	var draft: Dictionary = host.service.preview(amounts("coral", 3), false)
	block_disk_path(blocked)
	check(not host.service.confirm(draft.token, false).get("ok", false), stage + "真实保存返回失败")
	check(game.sea_save_error == message, stage + "故障阶段准确报错")
	check(same(host._round_state(), before) and same(host.saved, before) and same(game.water_activity_state, before), stage + "库存/epoch/序号/回执/内存缓存完整回滚")
	check(FileAccess.get_file_as_string(DISK_PATHS[0]) == main_text, stage + "主档逐字未变")
	check(not host.service.confirm(draft.token, false).get("ok", false), stage + "失败token不能复用")
	clear_disk_fixtures()
	check(host._cache_round(), stage + "清障后恢复基线")
	draft = host.service.preview(amounts("coral", 3), false)
	check(host.service.confirm(draft.token, false).get("ok", false), stage + "新预览可成功提交")
	check(same(game._read_sea_file(DISK_PATHS[0]), host._round_state()), stage + "磁盘与提交状态一致")

func write_disk_fixture(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "写入隔离测试夹具 " + path)
	if file != null:
		file.store_string(text)
		file.close()

func remember_quarantine(bad_text: String) -> String:
	var message: String = game.sea_save_error
	var marker := "坏主档隔离路径："
	check(message.contains(marker), "成功恢复提示包含坏主档隔离路径")
	if not message.contains(marker): return ""
	var path := message.get_slice(marker, 1)
	check(path.begins_with(ProjectSettings.globalize_path(DISK_PATHS[0]) + ".corrupt."), "隔离路径属于本次测试主档")
	if not path.begins_with(ProjectSettings.globalize_path(DISK_PATHS[0]) + ".corrupt."): return ""
	recovery_quarantines.append(path)
	check(FileAccess.get_file_as_string(path) == bad_text, "坏主档逐字隔离未进入备份轮换")
	return path

func recovery_disk_tests() -> void:
	clear_disk_fixtures()
	var host := host_with()
	var state := host._round_state()
	var backup_text := JSON.stringify({"version": 11, "state": state})
	var bad_text := "{broken-main"
	for malformed: String in [bad_text, "{broken-pending", "{broken-backup", "", "{\"version\":11,\"state\":", "[1, 2"]:
		var before_cache: Dictionary = game.water_activity_state.duplicate(true)
		var before_error: String = game.sea_save_error
		write_disk_fixture(DISK_PATHS[0], malformed)
		check(game._read_sea_text(malformed).is_empty() and game._read_sea_file(DISK_PATHS[0]).is_empty(), "malformed JSON文本与磁盘读取均静默拒绝 " + malformed)
		check(FileAccess.get_file_as_string(DISK_PATHS[0]) == malformed and same(game.water_activity_state, before_cache) and game.sea_save_error == before_error, "malformed JSON读取不改原文缓存或提示")
	write_disk_fixture(DISK_PATHS[0], bad_text)
	write_disk_fixture(DISK_PATHS[2], backup_text)
	var cached: Dictionary = game.water_activity_state.duplicate(true)
	check(game.can_recover_sea_save() and same(game.water_activity_state, cached), "恢复查询只读且坏主档有效备份可恢复")
	check(not game.save_sea_state(state), "普通保存仍拒绝坏主档，不隐式恢复")
	check(FileAccess.get_file_as_string(DISK_PATHS[0]) == bad_text and FileAccess.get_file_as_string(DISK_PATHS[2]) == backup_text and same(game.water_activity_state, cached), "普通保存拒绝时坏主档备份和缓存保留")
	block_disk_path(DISK_PATHS[4])
	check(not game.recover_sea_save() and game.sea_save_error == "海上恢复临时文件写入失败，原档与备份保留。", "恢复临时写入失败明确报错")
	check(FileAccess.get_file_as_string(DISK_PATHS[0]) == bad_text and FileAccess.get_file_as_string(DISK_PATHS[2]) == backup_text and same(game.water_activity_state, cached), "恢复写失败不移动坏主档、不消费备份、不改缓存")
	clear_disk_fixtures()
	write_disk_fixture(DISK_PATHS[0], bad_text)
	write_disk_fixture(DISK_PATHS[2], backup_text)
	check(game.recover_sea_save(), "显式恢复备份成功")
	var first_path := remember_quarantine(bad_text)
	check(same(game._read_sea_file(DISK_PATHS[0]), state) and same(game.water_activity_state, state), "恢复提交后磁盘与缓存同步")
	check(FileAccess.get_file_as_string(DISK_PATHS[2]) == backup_text and not FileAccess.file_exists(DISK_PATHS[3]), "恢复不消费有效bak也不将坏主档轮换至pending")
	check(not game.can_recover_sea_save() and not game.recover_sea_save(), "有效主档不显示恢复且拒绝再次恢复")
	var pending_state := state.duplicate(true)
	pending_state.resources.coral += 1
	var pending_text := JSON.stringify({"version": 11, "state": pending_state})
	write_disk_fixture(DISK_PATHS[0], bad_text)
	check(game.can_recover_sea_save(), "查询备份后允许用户确认")
	write_disk_fixture(DISK_PATHS[3], pending_text)
	check(game.recover_sea_save(), "确认恢复时现读有效pending优先于bak")
	var second_path := remember_quarantine(bad_text)
	check(first_path != second_path and FileAccess.get_file_as_string(first_path) == bad_text, "重复恢复使用唯一隔离路径不覆盖前次坏档")
	check(same(game.water_activity_state, pending_state) and same(game._read_sea_file(DISK_PATHS[0]), pending_state), "恢复使用确认时现读pending而非查询时缓存")
	check(FileAccess.get_file_as_string(DISK_PATHS[2]) == backup_text and FileAccess.get_file_as_string(DISK_PATHS[3]) == pending_text, "恢复成功两个有效来源逐字保留")
	clear_disk_fixtures()
	write_disk_fixture(DISK_PATHS[2], backup_text)
	write_disk_fixture(DISK_PATHS[3], pending_text)
	block_disk_path(DISK_PATHS[0])
	cached = game.water_activity_state.duplicate(true)
	check(not game.recover_sea_save() and game.sea_save_error.begins_with("海上恢复置换失败"), "恢复提交被目录阻塞返回失败")
	check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DISK_PATHS[0])) and FileAccess.get_file_as_string(DISK_PATHS[2]) == backup_text and FileAccess.get_file_as_string(DISK_PATHS[3]) == pending_text and same(game.water_activity_state, cached), "恢复提交失败不覆盖新占位、不消费来源、不改缓存")
	check(not game._read_sea_file(DISK_PATHS[4]).is_empty(), "提交失败保留已校验独立恢复临时文件")
	clear_disk_fixtures()
	write_disk_fixture(DISK_PATHS[0], bad_text)
	write_disk_fixture(DISK_PATHS[2], backup_text)
	write_disk_fixture(DISK_PATHS[3], "{broken-pending")
	check(game.can_recover_sea_save() and game.recover_sea_save(), "无效pending回退有效bak")
	remember_quarantine(bad_text)
	check(same(game.water_activity_state, state) and FileAccess.get_file_as_string(DISK_PATHS[3]) == "{broken-pending", "回退bak不改写无效pending")
	clear_disk_fixtures()
	write_disk_fixture(DISK_PATHS[0], bad_text)
	write_disk_fixture(DISK_PATHS[2], backup_text)
	check(game.can_recover_sea_save(), "备份失效前查询可恢复")
	write_disk_fixture(DISK_PATHS[2], "{broken-backup")
	cached = game.water_activity_state.duplicate(true)
	check(not game.can_recover_sea_save() and not game.recover_sea_save(), "查询后备份失效，确认现读必须拒绝而非使用旧来源")
	check(FileAccess.get_file_as_string(DISK_PATHS[0]) == bad_text and FileAccess.get_file_as_string(DISK_PATHS[2]) == "{broken-backup" and same(game.water_activity_state, cached), "无有效源失败保留坏档与缓存")
	clear_disk_fixtures()

func real_disk_tests() -> void:
	# Explicit opt-in prevents a parallel smoke suite from touching its shared save.
	if not "--transaction-disk" in OS.get_cmdline_user_args():
		print("SKIP: real disk faults require --transaction-disk and a fresh Cun-PublicTransaction-* custom user directory")
		return
	var custom := String(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not custom.begins_with("Cun-PublicTransaction-"):
		check(false, "真实磁盘故障必须使用专属Cun-PublicTransaction-*用户目录")
		return
	for path in DISK_PATHS:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			check(false, "真实磁盘测试拒绝覆盖已有文件 " + path)
			return
	var cached: Dictionary = game.water_activity_state.duplicate(true)
	var error: String = game.sea_save_error
	disk_failure_case("临时写入", DISK_PATHS[1], "海上存档临时文件写入失败，进度未提交。")
	disk_failure_case("主档备份", DISK_PATHS[3], "海上存档备份失败，旧档保留。")
	clear_disk_fixtures()
	var host := host_with()
	host.real_disk = true
	var before := host._round_state()
	var draft: Dictionary = host.service.preview(amounts("coral", 2), false)
	var replacement_cache: Dictionary = game.water_activity_state.duplicate(true)
	block_disk_path(DISK_PATHS[0])
	check(not host.service.confirm(draft.token, false).get("ok", false), "置换被主档目录阻塞返回失败")
	check(game.sea_save_error == "海上存档置换失败，旧档或备份保留。", "置换失败准确报错")
	check(same(host._round_state(), before) and same(game.water_activity_state, replacement_cache), "首次置换失败事务与GameManager缓存不变")
	check(not FileAccess.file_exists(DISK_PATHS[0]) and not game._read_sea_file(DISK_PATHS[1]).is_empty(), "置换失败未生成主档且临时文件仍可校验")
	clear_disk_fixtures()
	check(host._cache_round(), "备份整理告警建立真实主档")
	var old_text := FileAccess.get_file_as_string(DISK_PATHS[0])
	block_disk_path(DISK_PATHS[2])
	draft = host.service.preview(amounts("coral", 2), false)
	check(host.service.confirm(draft.token, false).get("ok", false), "备份整理失败仍返回提交成功")
	check(game.sea_save_error == "海上进度已保存，临时备份仍保留。", "备份目录阻塞只产生整理告警")
	check(host.resources.coral == 18 and host.public_project.donation_seq == 1 and same(game.water_activity_state, host._round_state()), "整理告警不得回滚已提交投料与缓存")
	check(same(game._read_sea_file(DISK_PATHS[0]), host._round_state()) and FileAccess.get_file_as_string(DISK_PATHS[3]) == old_text, "整理告警新主档提交且pending保留旧主档")
	var writes := host.writes
	check(host.service.confirm(draft.token, false).get("duplicate", false) and writes == host.writes, "整理告警后重复确认不重扣重写")
	game.load_sea_save()
	check(same(game.water_activity_state, host._round_state()) and game.sea_save_error == "", "告警后重载采用已提交主档")
	recovery_disk_tests()
	# The equivalent of finally: no early return after fixture creation.
	clear_disk_fixtures()
	game.water_activity_state = cached
	game.sea_save_error = error
	for path in DISK_PATHS:
		check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)), "最终清障 " + path)

func panel_snapshot(panel: PanelContainer, host: TransactionHost, new_operation: bool, label: String) -> Dictionary:
	var view: Dictionary = host.service.snapshot()
	check(not read(host._round_state()).is_empty(), label + "由合法真实历史生成")
	check(panel.set_snapshot(view, new_operation) and panel._valid, label + "Panel接受service.snapshot v2")
	check(same(panel.snapshot, view), label + "Panel展示未改写快照")
	return view

func receipt_view_tests() -> void:
	var panel := ResultPanel.new()
	root.add_child(panel)
	var host := host_with()
	check(host.service.seal_bag(["coral"], false, "shoal", 0) and host.service.deposit_bag(), "视图建立旧completed袋")
	var view := panel_snapshot(panel, host, true, "旧completed袋")
	var old_id: String = view.operation_id
	check(view.donation.status == "not_applicable" and view.bag.status == "completed" and panel.main_action == "return_base", "旧袋独立完成无虚构投料")
	var draft: Dictionary = host.service.preview(amounts("shell", 1), false)
	check(host.service.confirm(draft.token, false).get("ok", false), "旧袋完成后新独立投料")
	view = panel_snapshot(panel, host, true, "新独立投料")
	check(view.operation_id != old_id and view.bag.status == "not_applicable" and view.bag.rows.is_empty() and not panel._cards.bag.root.visible, "独立投料不复用旧completed袋")
	old_id = view.operation_id
	check(host.service.seal_bag(["shell"], false, "shoal", 0), "独立投料后封新袋")
	view = panel_snapshot(panel, host, true, "后续新袋")
	check(view.operation_id != old_id and view.donation.status == "not_applicable" and view.donation.rows.is_empty() and not panel._cards.donation.root.visible, "新袋不复用上笔独立投料")
	await process_frame
	# A separate legal history: full stock -> sealed bag -> donation -> failed deposit.
	host = host_with(Catalog.RESOURCE_LIMIT)
	check(host.service.seal_bag(["coral"], true, "shoal", 0), "关联回执封袋")
	draft = host.service.preview(amounts("coral", 1), false)
	check(host.service.confirm(draft.token, false).get("ok", false), "关联袋投料完成")
	host.fail_next = true
	await process_frame
	view = panel_snapshot(panel, host, true, "关联袋入库失败")
	var failed := view.duplicate(true)
	check(view.donation.status == "completed" and view.bag.status == "save_failed" and view.bag.rows[0].actual == null and panel.main_action == "retry_bag", "投料已完成但袋失败不伪造实际量且可重试")
	check(panel._cards.donation.root.visible and panel._cards.bag.root.visible and not panel._cards.production.root.visible, "关联结果两事务独立显示无虚构生产")
	check(host.service.deposit_bag(), "关联袋保存恢复后成功")
	view = panel_snapshot(panel, host, false, "关联袋失败后成功")
	check(view.operation_id == failed.operation_id and view.revision > failed.revision and view.donation == failed.donation and view.bag.bag_id == failed.bag.bag_id, "同一关联视图递增版本保留已完成投料历史")
	check(view.bag.status == "completed" and view.bag.rows[0].actual == 1 and view.bag.core != null and panel.main_action == "return_base", "袋成功显示真实入库和核心并返回基地")
	panel.free()

func schema_tests() -> void:
	var host := host_with()
	var base := host._round_state()
	check(Service.valid(base.duplicate(true)) and not read(base).is_empty(), "默认公共工程严格schema合法")
	for version in range(1, 9):
		var legacy := base.duplicate(true)
		legacy.erase("public_project")
		var migrated := read(legacy, version)
		check(not migrated.is_empty() and migrated.get("public_project") == Service.defaults(), "v%d迁移补齐v9公共工程默认" % version)
		legacy.public_project = {"illegal_legacy_field": true}
		migrated = read(legacy, version)
		check(not migrated.is_empty() and migrated.get("public_project") == Service.defaults(), "v%d不信任旧版注入公共工程" % version)
	var bad := base.duplicate(true)
	bad.erase("public_project")
	check(read(bad).is_empty() and not Service.valid(bad), "v9缺少public_project必须拒绝不自动补齐")
	for key in Service.defaults():
		bad = base.duplicate(true)
		bad.public_project.erase(key)
		check(read(bad).is_empty() and not Service.valid(bad), "v9拒绝缺少公共工程字段 " + key)
	for value: Variant in [null, false, [], "state", {"extra": 1}]:
		bad = base.duplicate(true)
		bad.public_project = value
		check(read(bad).is_empty() and not Service.valid(bad), "v9拒绝非法公共工程结构 " + str(value))
	bad = base.duplicate(true)
	bad.public_project.extra = 0
	check(read(bad).is_empty(), "v9拒绝公共工程额外字段")
	for field in ["donation_seq", "bag_seq"]:
		for value: Variant in [-1, true, 0.5, "1", 1000000001]:
			bad = base.duplicate(true)
			bad.public_project[field] = value
			check(read(bad).is_empty() and not Service.valid(bad), "v9拒绝非法序号 " + field + ":" + str(value))
	for value: Variant in [true, "x", "ABCDEF0123456789abcdef0123456789ab", "g".repeat(32)]:
		bad = base.duplicate(true)
		bad.public_project.epoch = value
		check(read(bad).is_empty(), "v9拒绝非法epoch " + str(value))
	check(host.service.seal_bag(["coral"], true, "shoal", 0), "schema建立合法待袋")
	var pending_state := host._round_state()
	check(not read(pending_state).is_empty(), "v9合法待袋可重读")
	for field in pending_state.public_project.pending_bag:
		bad = pending_state.duplicate(true)
		bad.public_project.pending_bag.erase(field)
		check(read(bad).is_empty(), "v9待袋严格必填 " + field)
	for field in ["bag_id", "deposit_operation_id", "origin", "new_core", "lost_count", "items"]:
		bad = pending_state.duplicate(true)
		bad.public_project.pending_bag[field] = {"bag_id": "wrong", "deposit_operation_id": "wrong", "origin": "unknown", "new_core": 1, "lost_count": true, "items": amounts("coral", -1)}[field]
		check(read(bad).is_empty(), "v9拒绝非法待袋 " + field)
	bad = pending_state.duplicate(true)
	bad.public_project.pending_bag.items.coral = Catalog.BASE_CAPACITY + 1
	check(read(bad).is_empty(), "v9拒绝超网袋重量")
	bad = pending_state.duplicate(true)
	bad.dive_sonar = false
	check(read(bad).is_empty(), "v9拒绝未解声呐的核心待袋")
	check(host.service.deposit_bag(), "schema建立合法入库回执")
	var draft: Dictionary = host.service.preview(amounts("coral", 1), false)
	check(host.service.confirm(draft.token, false).get("ok", false), "schema建立合法投料回执")
	var receipts := host._round_state()
	check(not read(receipts).is_empty(), "v9合法投料与袋回执可重读")
	for receipt_key in ["last_donation", "last_bag"]:
		for field in receipts.public_project[receipt_key]:
			bad = receipts.duplicate(true)
			bad.public_project[receipt_key].erase(field)
			check(read(bad).is_empty(), "v9回执严格必填 " + receipt_key + "." + field)
		bad = receipts.duplicate(true)
		bad.public_project[receipt_key].after.coral += 1
		check(read(bad).is_empty(), "v9拒绝回执算术不一致 " + receipt_key)
		bad = receipts.duplicate(true)
		bad.public_project[receipt_key].operation_id = "wrong"
		check(read(bad).is_empty(), "v9拒绝回执操作身份不一致 " + receipt_key)
	for value: Variant in [true, 0, 12, 9.5, "9"]:
		check(read(base, value).is_empty(), "拒绝非法存档版本 " + str(value))

func run() -> void:
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		print("FAIL: 必须从use_custom_user_dir隔离工程运行公共工程事务测试")
		quit(2)
		return
	game = root.get_node("GameManager")
	donation_tests()
	invalidation_tests()
	await failure_tests()
	schema_tests()
	await receipt_view_tests()
	real_disk_tests()
	await process_frame
	for host in hosts:
		host.service.host = null
		host.technology.host = null
		host.free()
	hosts.clear()
	print("RESULT: public_project_transaction checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
