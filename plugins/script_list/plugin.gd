@tool
extends EditorPlugin

const EXCLUDE_FOLDERS: Array[String] = ["android"]


## Injects a "Project Scripts" panel into the Script Editor's left side,
## above the built-in open-scripts list, inside a resizable VSplitContainer.

# ── UI references ────────────────────────────────────────────
var _panel: VBoxContainer = null
var _tree: Tree = null
var _search_bar: LineEdit = null
var _count_label: Label = null
var _context_menu: PopupMenu = null

# ── Injection book-keeping ───────────────────────────────────
var _wrapper: VSplitContainer = null
var _original_left: Control = null
var _injected: bool = false
var _retry_timer: SceneTreeTimer = null

# ── Data / options ───────────────────────────────────────────
var _scripts: Array[String] = []
var _flat_view: bool = false
var _include_addons: bool = true


# ═══════════════════════════════════════════════════════════════
#  Lifecycle
# ═══════════════════════════════════════════════════════════════

func _enter_tree() -> void:
	_build_panel()

	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs != null and not fs.filesystem_changed.is_connected(_refresh):
		fs.filesystem_changed.connect(_refresh)

	call_deferred("_inject_into_script_editor")
	call_deferred("_refresh")


func _exit_tree() -> void:
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs != null and fs.filesystem_changed.is_connected(_refresh):
		fs.filesystem_changed.disconnect(_refresh)

	_eject_from_script_editor()

	if is_instance_valid(_panel):
		_panel.queue_free()

	_panel = null
	_tree = null
	_search_bar = null
	_count_label = null
	_context_menu = null
	_retry_timer = null


# ═══════════════════════════════════════════════════════════════
#  Injection / Ejection
# ═══════════════════════════════════════════════════════════════

func _inject_into_script_editor() -> void:
	if _injected:
		return
	if not is_instance_valid(_panel):
		return

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor == null:
		_schedule_retry()
		return

	var hsplit: HSplitContainer = _find_main_hsplit(script_editor)
	if hsplit == null or hsplit.get_child_count() < 2:
		_schedule_retry()
		return

	_original_left = hsplit.get_child(0) as Control
	if _original_left == null:
		push_warning("ScriptList: could not locate the left panel.")
		return

	_wrapper = VSplitContainer.new()
	_wrapper.name = "ScriptListVSplit"
	_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var idx: int = _original_left.get_index()
	hsplit.remove_child(_original_left)

	_wrapper.add_child(_panel)
	_wrapper.add_child(_original_left)

	hsplit.add_child(_wrapper)
	hsplit.move_child(_wrapper, idx)

	_injected = true


func _schedule_retry() -> void:
	if _retry_timer != null:
		return
	_retry_timer = get_tree().create_timer(0.5)
	_retry_timer.timeout.connect(func() -> void:
		_retry_timer = null
		_inject_into_script_editor()
	)


func _eject_from_script_editor() -> void:
	if not _injected:
		return
	if not is_instance_valid(_wrapper):
		_injected = false
		return

	var hsplit: Node = _wrapper.get_parent()
	var idx: int = _wrapper.get_index()

	if is_instance_valid(_panel) and _panel.get_parent() == _wrapper:
		_wrapper.remove_child(_panel)
	if is_instance_valid(_original_left) and _original_left.get_parent() == _wrapper:
		_wrapper.remove_child(_original_left)

	if hsplit != null:
		hsplit.remove_child(_wrapper)

	_wrapper.queue_free()
	_wrapper = null

	if is_instance_valid(_original_left) and hsplit != null:
		hsplit.add_child(_original_left)
		(hsplit as Control).move_child(_original_left, idx)

	_original_left = null
	_injected = false


func _find_main_hsplit(script_editor: ScriptEditor) -> HSplitContainer:
	for child: Node in script_editor.get_children():
		if child is VBoxContainer:
			for grandchild: Node in child.get_children():
				if grandchild is HSplitContainer:
					return grandchild as HSplitContainer
	return null


# ═══════════════════════════════════════════════════════════════
#  Panel Construction
# ═══════════════════════════════════════════════════════════════

func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "ProjectScripts"
	_panel.custom_minimum_size = Vector2(0, 120)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Title ──
	var title: Label = Label.new()
	title.text = "  Project Scripts"
	title.add_theme_font_size_override("font_size", 13)
	_panel.add_child(title)

	# ── Toolbar (search + refresh) ──
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 2)

	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "Filter..."
	_search_bar.clear_button_enabled = true
	_search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_bar.text_changed.connect(_on_filter_changed)
	toolbar.add_child(_search_bar)

	var refresh_btn: Button = Button.new()
	refresh_btn.flat = true
	refresh_btn.tooltip_text = "Refresh"
	var reload_icon: Texture2D = _editor_icon("Reload")
	if reload_icon != null:
		refresh_btn.icon = reload_icon
	else:
		refresh_btn.text = "↻"
	refresh_btn.pressed.connect(_refresh)
	toolbar.add_child(refresh_btn)

	_panel.add_child(toolbar)

	# ── Options row ──
	var options: HBoxContainer = HBoxContainer.new()
	options.add_theme_constant_override("separation", 6)

	var flat_cb: CheckButton = CheckButton.new()
	flat_cb.text = "Flat"
	flat_cb.tooltip_text = "Toggle flat list / folder tree"
	flat_cb.toggled.connect(func(on: bool) -> void:
		_flat_view = on
		_populate()
	)
	options.add_child(flat_cb)

	var addons_cb: CheckButton = CheckButton.new()
	addons_cb.text = "Addons"
	addons_cb.button_pressed = true
	addons_cb.tooltip_text = "Include scripts inside addons/"
	addons_cb.toggled.connect(func(on: bool) -> void:
		_include_addons = on
		_refresh()
	)
	options.add_child(addons_cb)

	_panel.add_child(options)

	# ── Count label ──
	_count_label = Label.new()
	_count_label.text = "Scanning…"
	_count_label.add_theme_font_size_override("font_size", 11)
	_panel.add_child(_count_label)

	_panel.add_child(HSeparator.new())

	# ── Tree ──
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.allow_search = true
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_mouse_selected.connect(_on_item_mouse_selected)
	_panel.add_child(_tree)

	# ── Context menu ──
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Open Script", 0)
	_context_menu.add_separator()
	_context_menu.add_item("Copy Path", 1)
	_context_menu.add_item("Show in FileSystem", 2)
	_context_menu.id_pressed.connect(_on_context_id)
	_panel.add_child(_context_menu)


# ═══════════════════════════════════════════════════════════════
#  Scanning
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	if not is_instance_valid(_tree):
		return
	_scripts.clear()
	_scan("res://")
	_scripts.sort()
	_populate()


func _scan(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry: String = dir.get_next()

	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full: String = path.path_join(entry)

		if dir.current_is_dir():
			if (entry != "addons" or _include_addons) and EXCLUDE_FOLDERS.count(entry) < 1:
				_scan(full)
		elif entry.get_extension() == "gd":
			_scripts.append(full)

		entry = dir.get_next()

	dir.list_dir_end()


# ═══════════════════════════════════════════════════════════════
#  Tree population
# ═══════════════════════════════════════════════════════════════

func _populate() -> void:
	if not is_instance_valid(_tree):
		return
	if not is_instance_valid(_search_bar):
		return
	if not is_instance_valid(_count_label):
		return

	_tree.clear()
	var root: TreeItem = _tree.create_item()

	var filter: String = _search_bar.text.strip_edges().to_lower()
	var visible: Array[String] = []

	for s: String in _scripts:
		if filter.is_empty() or s.to_lower().contains(filter):
			visible.append(s)

	if _flat_view:
		_populate_flat(root, visible)
	else:
		_populate_hierarchy(root, visible)

	_count_label.text = "%d script%s" % [
		visible.size(),
		"" if visible.size() == 1 else "s",
	]


func _populate_flat(root: TreeItem, list: Array[String]) -> void:
	var icon: Texture2D = _editor_icon("GDScript")

	for path: String in list:
		var item: TreeItem = _tree.create_item(root)
		item.set_text(0, path.get_file())
		item.set_tooltip_text(0, path)
		item.set_metadata(0, path)
		if icon != null:
			item.set_icon(0, icon)


func _populate_hierarchy(root: TreeItem, list: Array[String]) -> void:
	var script_icon: Texture2D = _editor_icon("GDScript")
	var folder_icon: Texture2D = _editor_icon("Folder")
	var folders: Dictionary = {}

	for path: String in list:
		var rel: String = path.trim_prefix("res://")
		var parts: PackedStringArray = rel.split("/")
		var parent: TreeItem = root
		var dir_key: String = "res://"

		var i: int = 0
		while i < parts.size() - 1:
			dir_key = dir_key.path_join(parts[i])
			if not folders.has(dir_key):
				var fi: TreeItem = _tree.create_item(parent)
				fi.set_text(0, parts[i])
				fi.set_selectable(0, false)
				if folder_icon != null:
					fi.set_icon(0, folder_icon)
				folders[dir_key] = fi
			parent = folders[dir_key] as TreeItem
			i += 1

		var si: TreeItem = _tree.create_item(parent)
		si.set_text(0, parts[-1])
		si.set_tooltip_text(0, path)
		si.set_metadata(0, path)
		if script_icon != null:
			si.set_icon(0, script_icon)


# ═══════════════════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════════════════

func _editor_icon(icon_name: String) -> Texture2D:
	var theme: Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(icon_name, &"EditorIcons"):
		return theme.get_icon(icon_name, &"EditorIcons")
	return null


func _open_script(path: String) -> void:
	if path.is_empty():
		return
	var scr: Resource = load(path)
	if scr is Script:
		EditorInterface.edit_script(scr as Script)
		EditorInterface.set_main_screen_editor("Script")


func _selected_path() -> String:
	if not is_instance_valid(_tree):
		return ""
	var sel: TreeItem = _tree.get_selected()
	if sel != null:
		var m: Variant = sel.get_metadata(0)
		if m is String:
			return m as String
	return ""


# ═══════════════════════════════════════════════════════════════
#  Callbacks
# ═══════════════════════════════════════════════════════════════

func _on_filter_changed(_text: String) -> void:
	_populate()


func _on_item_activated() -> void:
	_open_script(_selected_path())


func _on_item_mouse_selected(pos: Vector2, btn: int) -> void:
	if btn != MOUSE_BUTTON_RIGHT:
		return
	if _selected_path().is_empty():
		return
	if not is_instance_valid(_context_menu):
		return
	if not is_instance_valid(_tree):
		return
	_context_menu.position = Vector2i(_tree.get_screen_position() + pos)
	_context_menu.reset_size()
	_context_menu.popup()


func _on_context_id(id: int) -> void:
	var path: String = _selected_path()
	if path.is_empty():
		return
	match id:
		0:
			_open_script(path)
		1:
			DisplayServer.clipboard_set(path)
		2:
			EditorInterface.get_file_system_dock().navigate_to_path(path)
