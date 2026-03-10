@tool
extends PanelContainer

# ── Node references (built in _ready) ──────────────────────────────────────

var vbox: VBoxContainer

# Keystore fields
var keystore_path_edit: LineEdit
var browse_button: Button
var keystore_pass_edit: LineEdit
var keystore_pass_confirm_edit: LineEdit

# Key fields
var alias_edit: LineEdit
var key_pass_edit: LineEdit
var key_pass_confirm_edit: LineEdit
var validity_spin: SpinBox
var key_size_option: OptionButton

# Distinguished‑name fields
var cn_edit: LineEdit   # Common Name
var ou_edit: LineEdit   # Organizational Unit
var o_edit: LineEdit    # Organization
var l_edit: LineEdit    # Locality / City
var st_edit: LineEdit   # State / Province
var c_edit: LineEdit    # Country Code (2 letters)

# Action
var generate_button: Button
var status_label: RichTextLabel

# File dialog
var file_dialog: FileDialog

# ── Helpers to build UI rows ───────────────────────────────────────────────

func _add_section(title: String) -> void:
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(lbl)


func _add_field(label_text: String, placeholder: String = "", secret: bool = false, tooltip: String = "") -> LineEdit:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 130
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.secret = secret
	if tooltip != "":
		edit.tooltip_text = tooltip
		lbl.tooltip_text = tooltip
	hbox.add_child(edit)
	vbox.add_child(hbox)
	return edit


func _add_spin(label_text: String, min_val: float, max_val: float, default_val: float, step: float = 1.0) -> SpinBox:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 130
	hbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)
	vbox.add_child(hbox)
	return spin


func _add_option(label_text: String, items: PackedStringArray, default_index: int = 0) -> OptionButton:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 130
	hbox.add_child(lbl)
	var opt := OptionButton.new()
	for item in items:
		opt.add_item(item)
	opt.selected = default_index
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(opt)
	vbox.add_child(hbox)
	return opt


# ── _ready ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	vbox = $ScrollContainer/MarginContainer/VBox

	# ── Title ──
	var title_label := Label.new()
	title_label.text = "🔑  Keystore Creator"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# ── Keystore File ──
	_add_section("Keystore File")

	# Path row with browse button
	var path_hbox := HBoxContainer.new()
	path_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path_lbl := Label.new()
	path_lbl.text = "Save Path"
	path_lbl.custom_minimum_size.x = 130
	path_hbox.add_child(path_lbl)
	keystore_path_edit = LineEdit.new()
	keystore_path_edit.placeholder_text = "/path/to/my-release-key.keystore"
	keystore_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_hbox.add_child(keystore_path_edit)
	browse_button = Button.new()
	browse_button.text = "Browse…"
	browse_button.pressed.connect(_on_browse_pressed)
	path_hbox.add_child(browse_button)
	vbox.add_child(path_hbox)

	keystore_pass_edit = _add_field("Password", "min 6 characters", true, "Keystore password (min 6 chars)")
	keystore_pass_confirm_edit = _add_field("Confirm Pass", "re‑enter password", true)

	# ── Key Settings ──
	_add_section("Key Settings")
	alias_edit = _add_field("Alias", "my-key-alias", false, "Alias name for the key entry")
	key_pass_edit = _add_field("Key Password", "min 6 characters", true, "Key password (min 6 chars)")
	key_pass_confirm_edit = _add_field("Confirm Key Pass", "re‑enter password", true)
	validity_spin = _add_spin("Validity (years)", 1, 100, 25)
	key_size_option = _add_option("Key Size", PackedStringArray(["2048", "4096"]), 0)

	# ── Distinguished Name (DN) ──
	_add_section("Certificate Owner (DN)")
	cn_edit = _add_field("Common Name", "John Doe", false, "CN – your name or company")
	ou_edit = _add_field("Org. Unit", "Mobile", false, "OU – department")
	o_edit  = _add_field("Organization", "My Company", false, "O – company name")
	l_edit  = _add_field("City", "San Francisco", false, "L – city / locality")
	st_edit = _add_field("State", "California", false, "ST – state or province")
	c_edit  = _add_field("Country Code", "US", false, "C – two‑letter country code (ISO 3166)")

	# ── Generate Button ──
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	vbox.add_child(spacer)

	generate_button = Button.new()
	generate_button.text = "Generate Keystore"
	generate_button.custom_minimum_size.y = 40
	generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_button)

	# ── Status ──
	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	status_label.custom_minimum_size.y = 60
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(status_label)

	# ── File dialog (hidden until needed) ──
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Save Keystore As…"
	file_dialog.filters = PackedStringArray(["*.keystore ; Keystore files", "*.jks ; Java Keystore"])
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	_set_status("")


# ── Callbacks ──────────────────────────────────────────────────────────────

func _on_browse_pressed() -> void:
	file_dialog.popup_centered(Vector2i(700, 500))


func _on_file_selected(path: String) -> void:
	keystore_path_edit.text = path


func _set_status(msg: String, error: bool = false) -> void:
	if msg == "":
		status_label.text = ""
		return
	if error:
		status_label.text = "[color=red]❌  " + msg + "[/color]"
	else:
		status_label.text = "[color=green]✅  " + msg + "[/color]"


func _set_status_info(msg: String) -> void:
	status_label.text = "[color=yellow]⏳  " + msg + "[/color]"


# ── Validation ─────────────────────────────────────────────────────────────

func _validate() -> String:
	# Returns empty string on success, or an error message.
	if keystore_path_edit.text.strip_edges() == "":
		return "Keystore save path is required."

	var ks_path := keystore_path_edit.text.strip_edges()
	if not ks_path.ends_with(".keystore") and not ks_path.ends_with(".jks"):
		return "File should end with .keystore or .jks"

	if keystore_pass_edit.text.length() < 6:
		return "Keystore password must be at least 6 characters."

	if keystore_pass_edit.text != keystore_pass_confirm_edit.text:
		return "Keystore passwords do not match."

	if alias_edit.text.strip_edges() == "":
		return "Key alias is required."

	if key_pass_edit.text.length() < 6:
		return "Key password must be at least 6 characters."

	if key_pass_edit.text != key_pass_confirm_edit.text:
		return "Key passwords do not match."

	if c_edit.text.strip_edges().length() != 0 and c_edit.text.strip_edges().length() != 2:
		return "Country code must be exactly 2 letters (e.g. US)."

	return ""


# ── Keystore generation ───────────────────────────────────────────────────

func _build_dname() -> String:
	var parts: PackedStringArray = []

	if cn_edit.text.strip_edges() != "":
		parts.append("CN=" + cn_edit.text.strip_edges())
	if ou_edit.text.strip_edges() != "":
		parts.append("OU=" + ou_edit.text.strip_edges())
	if o_edit.text.strip_edges() != "":
		parts.append("O=" + o_edit.text.strip_edges())
	if l_edit.text.strip_edges() != "":
		parts.append("L=" + l_edit.text.strip_edges())
	if st_edit.text.strip_edges() != "":
		parts.append("ST=" + st_edit.text.strip_edges())
	if c_edit.text.strip_edges() != "":
		parts.append("C=" + c_edit.text.strip_edges().to_upper())

	if parts.size() == 0:
		return "CN=Unknown"

	return ", ".join(parts)


func _find_keytool() -> String:
	# Try to locate keytool.  It ships with every JDK.
	# 1. Check JAVA_HOME
	var java_home := OS.get_environment("JAVA_HOME")
	if java_home != "":
		var candidate: String
		if OS.get_name() == "Windows":
			candidate = java_home.path_join("bin").path_join("keytool.exe")
		else:
			candidate = java_home.path_join("bin").path_join("keytool")
		if FileAccess.file_exists(candidate):
			return candidate

	# 2. Assume it's on PATH
	return "keytool"


func _on_generate_pressed() -> void:
	# Validate
	var err := _validate()
	if err != "":
		_set_status(err, true)
		return

	_set_status_info("Generating keystore…")
	generate_button.disabled = true

	# Build the arguments to keytool
	var ks_path: String = keystore_path_edit.text.strip_edges()
	var ks_pass: String = keystore_pass_edit.text
	var alias_name: String = alias_edit.text.strip_edges()
	var key_pass: String = key_pass_edit.text
	var validity_days: int = int(validity_spin.value) * 365
	var key_size_str: String = key_size_option.get_item_text(key_size_option.selected)
	var dname: String = _build_dname()

	# Check if file already exists
	if FileAccess.file_exists(ks_path):
		_set_status("File already exists. Delete it first or choose another path.", true)
		generate_button.disabled = false
		return

	var keytool_path := _find_keytool()

	var args: PackedStringArray = [
		"-genkeypair",
		"-v",
		"-storetype", "JKS",
		"-keyalg", "RSA",
		"-keysize", key_size_str,
		"-validity", str(validity_days),
		"-keystore", ks_path,
		"-alias", alias_name,
		"-storepass", ks_pass,
		"-keypass", key_pass,
		"-dname", dname,
	]

	# Print command (without passwords) for debugging
	var safe_args := args.duplicate()
	for i in range(safe_args.size()):
		if safe_args[i] == "-storepass" or safe_args[i] == "-keypass":
			if i + 1 < safe_args.size():
				safe_args[i + 1] = "******"
	print("[KeystoreCreator] Running: ", keytool_path, " ", " ".join(safe_args))

	var output: Array = []
	var exit_code := OS.execute(keytool_path, args, output, true, false)

	generate_button.disabled = false

	var stdout_text: String = ""
	if output.size() > 0:
		stdout_text = str(output[0])

	if exit_code == 0:
		_set_status("Keystore created successfully!\n" + ks_path)
		print("[KeystoreCreator] Success: ", stdout_text)
		_show_summary_dialog(ks_path, alias_name, dname, key_size_str, int(validity_spin.value))
	elif exit_code == -1:
		_set_status("Could not execute keytool. Make sure a JDK is installed\nand JAVA_HOME is set or keytool is on your PATH.", true)
		print("[KeystoreCreator] Failed to execute keytool.")
	else:
		_set_status("keytool exited with code " + str(exit_code) + ".\n" + stdout_text, true)
		print("[KeystoreCreator] Error: ", stdout_text)


# ── Success summary popup ─────────────────────────────────────────────────

func _show_summary_dialog(ks_path: String, alias_name: String, dname: String, key_size: String, years: int) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Keystore Created"
	dialog.dialog_text = (
		"Your release keystore has been created successfully!\n\n"
		+ "  Path:       " + ks_path + "\n"
		+ "  Alias:      " + alias_name + "\n"
		+ "  Key Size:   " + key_size + " bits (RSA)\n"
		+ "  Validity:   " + str(years) + " years\n"
		+ "  DN:         " + dname + "\n\n"
		+ "Keep your keystore and passwords safe.\n"
		+ "You will need them every time you publish an update."
	)
	dialog.min_size = Vector2i(500, 280)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
