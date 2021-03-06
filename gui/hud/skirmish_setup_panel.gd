
var bag

var panel = preload("res://gui/hud/skirmish_maps_selected_map.xscn").instance()
var current_container

var map_name_label
var player_0_button
var player_0_button_label
var player_1_button
var player_1_button_label
var turn_cap_button
var turn_cap_button_label
var back_button
var play_button

var connected_object = null
var connected_back_method = null
var connected_play_method = null

var connected_map_name = null

func _init_bag(bag):
    self.bag = bag
    self.bind_hud()
    self.connect_buttons()
    self.refresh_labels()

func bind_hud():
    self.map_name_label = self.panel.get_node("controls/map_name")
    self.player_0_button = self.panel.get_node("controls/blue_player")
    self.player_0_button_label = self.player_0_button.get_node("Label")
    self.player_1_button = self.panel.get_node("controls/red_player")
    self.player_1_button_label = self.player_1_button.get_node("Label")
    self.turn_cap_button = self.panel.get_node("controls/turns_cap")
    self.turn_cap_button_label = self.turn_cap_button.get_node("Label")
    self.back_button = self.panel.get_node("controls/back")
    self.play_button = self.panel.get_node("controls/play")

func connect_buttons():
    self.player_0_button.connect("pressed", self, "toggle_player", [0])
    self.player_1_button.connect("pressed", self, "toggle_player", [1])
    self.turn_cap_button.connect("pressed", self, "toggle_turns_cap")
    self.back_button.connect("pressed", self, "back_button_pressed")
    self.play_button.connect("pressed", self, "play_button_pressed")

func refresh_labels():
    if self.bag.root.settings['turns_cap'] > 0:
        self.turn_cap_button_label.set_text(str(self.bag.root.settings['turns_cap']))
    else:
        self.turn_cap_button_label.set_text("OFF")
    self.set_player_button_state(0, self.player_0_button_label)
    self.set_player_button_state(1, self.player_1_button_label)

func set_map_name(map_name, map_label):
    self.connected_map_name = map_name
    self.map_name_label.set_text(map_label)

func attach_panel(container_node):
    if self.current_container != null:
        self.detach_panel()
    self.current_container = container_node
    self.current_container.add_child(self.panel)
    self.refresh_labels()

func is_attached_to(container_node):
    return self.current_container == container_node

func detach_panel():
    if self.current_container != null:
        self.current_container.remove_child(self.panel)
        self.current_container = null
    self.disconnect()

func connect(object, back_method, play_method):
    self.connected_object = object
    self.connected_back_method = back_method
    self.connected_play_method = play_method

func disconnect():
    self.connected_object = null
    self.connected_back_method = null
    self.connected_play_method = null

func back_button_pressed():
    if self.connected_object != null:
        self.connected_object.call(self.connected_back_method)

func play_button_pressed():
    if self.connected_object != null:
        self.connected_object.call(self.connected_play_method, self.connected_map_name)

func toggle_player(player):
    self.bag.root.settings['cpu_' + str(player)] = not self.bag.root.settings['cpu_' + str(player)]
    self.refresh_labels()
    self.bag.root.write_settings_to_file()

func toggle_turns_cap():
    var turns_cap_modifer = 25

    if self.bag.root.settings['turns_cap'] >= 100:
        self.bag.root.settings['turns_cap'] = 0
    else:
        self.bag.root.settings['turns_cap'] = self.bag.root.settings['turns_cap'] + turns_cap_modifer
    self.refresh_labels()
    self.bag.root.write_settings_to_file()

func set_player_button_state(player, button_label):
    var label
    if self.bag.root.settings['cpu_' + str(player)]:
        label = "CPU"
    else:
        label = "HUMAN"

    button_label.set_text(label)
