extends Control

export var show_blueprint = false
export var campaign_map = true
export var take_enemy_hq = true
export var control_all_towers = false
export var multiplayer_map = false

var terrain
var underground
var units
var fog_controller
var map_layer_back
var map_layer_front

var mouse_dragging = false
var pos
var game_size
var scale
var root

var sX = 0
var sY = 0
var k = 0.90
var target = Vector2(0,0)

var shake_timer = Timer.new()
var shakes = 0
export var shakes_max = 5
export var shake_time = 0.25
export var shake_boundary = 5
var shake_initial_position
var temp_delta = 0

var panning = false
var current_player = 0
var camera_follow = true

const MAP_STEP = 0.01
const NEAR_THRESHOLD = 20
const NEAR_SCREEN_THRESHOLD = 0.2
const PAN_THRESHOLD = 20
const GEN_GRASS = 6
const GEN_FLOWERS = 3
const GEN_STONES = 6
const PAN_SPEED = 2

# this shoudl be in main settings (see abstract_map)
const MAP_MAX_X = 96
const MAP_MAX_Y = 96

var map_file = File.new()
var campaign

var tileset
var map_movable = preload('res://terrain/terrain_movable.xscn')
var map_non_movable = preload('res://terrain/terrain_non-movable.xscn')
var wave = preload('res://terrain/wave.xscn')
var underground_rock = preload('res://terrain/underground.xscn')
var map_city_small = [
	preload('res://terrain/city/city_small_1.xscn'),
	preload('res://terrain/city/city_small_2.xscn'),
	preload('res://terrain/city/city_small_3.xscn'),
	preload('res://terrain/city/city_small_4.xscn'),
	preload('res://terrain/city/city_small_5.xscn'),
	preload('res://terrain/city/city_small_6.xscn')]
var map_city_big = [
	preload('res://terrain/city/city_big_1.xscn'),
	preload('res://terrain/city/city_big_2.xscn'),
	preload('res://terrain/city/city_big_3.xscn'),
	preload('res://terrain/city/city_big_4.xscn')]
var map_statue = preload('res://terrain/city/city_statue.xscn')
var map_buildings = [
	preload('res://buildings/bunker_blue.xscn'),
	preload('res://buildings/bunker_red.xscn'),
	preload('res://buildings/barrack.xscn'),
	preload('res://buildings/factory.xscn'),
	preload('res://buildings/airport.xscn'),
	preload('res://buildings/tower.xscn'),
	preload('res://buildings/fence.xscn')]
var map_units = [
	preload('res://units/soldier_blue.xscn'),
	preload('res://units/tank_blue.xscn'),
	preload('res://units/helicopter_blue.xscn'),
	preload('res://units/soldier_red.xscn'),
	preload('res://units/tank_red.xscn'),
	preload('res://units/helicopter_red.xscn')]

var is_dead = false
var do_cinematic_pan = false

func _input(event):
	if self.is_dead:
		return

	pos = terrain.get_pos()
	if event.type == InputEvent.MOUSE_BUTTON:
		if event.button_index == BUTTON_LEFT:
			if not show_blueprint || (self.root.dependency_container.workshop.movement_mode && self.root.dependency_container.workshop.is_working && not self.root.dependency_container.workshop.is_suspended):
				mouse_dragging = event.pressed
		if event.button_index == BUTTON_RIGHT && show_blueprint && self.root.dependency_container.workshop.is_working && not self.root.dependency_container.workshop.is_suspended:
			mouse_dragging = event.pressed

	if (event.type == InputEvent.MOUSE_MOTION):
		if (mouse_dragging):
			if not show_blueprint and self.root.dependency_container.hud_dead_zone.is_dead_zone(event.x, event.y):
				return

			pos.x = pos.x + event.relative_x / scale.x
			pos.y = pos.y + event.relative_y / scale.y
			self.set_map_pos_global(pos)

	if not show_blueprint && event.type == InputEvent.KEY && event.scancode == KEY_P:
		self.do_cinematic_pan = event.pressed

func __do_panning(diff_x, diff_y):
	if diff_x > -PAN_THRESHOLD && diff_x < PAN_THRESHOLD && diff_y > -PAN_THRESHOLD && diff_y < PAN_THRESHOLD:
		return false

	return true

func _process(delta):
	if not pos == target:
		temp_delta += delta
		if temp_delta > MAP_STEP:
			var diff_x = target.x - self.sX
			var diff_y = target.y - self.sY

			panning = self.__do_panning(diff_x, diff_y)
			if diff_x > -NEAR_THRESHOLD && diff_x < NEAR_THRESHOLD && diff_y > -NEAR_THRESHOLD && diff_y < NEAR_THRESHOLD:
				target = pos
			else:
				self.sX = self.sX + diff_x * temp_delta;
				self.sY = self.sY + diff_y * temp_delta;
				var new_pos = Vector2(self.sX, self.sY)

				terrain.set_pos(new_pos)
				fog_controller.move_cloud(new_pos)
				underground.set_pos(new_pos)

			temp_delta = 0
	else:
		panning = false

	if self.do_cinematic_pan:
		self.set_map_pos_global(Vector2(self.sX - PAN_SPEED, self.sY))

func move_to(target):
	if not mouse_dragging:
		self.target = target;

func set_map_pos_global(position):
	self.target = position
	self.sX = position.x
	self.sY = position.y
	self.underground.set_pos(position)
	self.terrain.set_pos(position)
	self.fog_controller.move_cloud(position)

func set_map_pos(position):
	self.game_size = self.root.get_size()
	position = self.terrain.map_to_world(position*Vector2(-1,-1)) + Vector2(self.game_size.x/(2*self.scale.x), self.game_size.y/(2*self.scale.y))
	self.set_map_pos_global(position)

func move_to_map(target):
	if not root.settings['camera_follow']:
		return

	if not self.camera_follow && fog_controller.is_fogged(target.x, target.y):
		return

	if not mouse_dragging:
		game_size = root.get_size()
		var target_position = terrain.map_to_world(target*Vector2(-1,-1)) + Vector2(game_size.x/(2*scale.x),game_size.y/(2*scale.y))
		var diff_x = target_position.x - self.sX
		var diff_y = target_position.y - self.sY
		var near_x = game_size.x * (NEAR_SCREEN_THRESHOLD / scale.x)
		var near_y = game_size.y * (NEAR_SCREEN_THRESHOLD / scale.y)

		if diff_x > -near_x && diff_x < near_x && diff_y > -near_y && diff_y < near_y:
			return
		self.target = target_position
		self.panning = true

func shake_camera():
	if root.settings['shake_enabled'] and not mouse_dragging:
		shakes = 0
		shake_initial_position = terrain.get_pos()
		self.do_single_shake()

func do_single_shake():
	if shakes < shakes_max:
		var distance_x = randi() % shake_boundary
		var distance_y = randi() % shake_boundary
		if randf() <= 0.5:
			distance_x = -distance_x
		if randf() <= 0.5:
			distance_y = -distance_y

		pos = Vector2(shake_initial_position) + Vector2(distance_x, distance_y)
		target = pos
		underground.set_pos(pos)
		terrain.set_pos(pos)
		shakes += 1
		shake_timer.start()
	else:
		pos = shake_initial_position
		target = pos
		underground.set_pos(shake_initial_position)
		terrain.set_pos(shake_initial_position)


func generate_map():
	var temp = null
	var temp2 = null
	var cells_to_change = []
	var cell
	randomize()

	#map elements count
	var city_small_elements_count = map_city_small.size()
	var city_big_elements_count = map_city_big.size()
	var neigbours = 0

	for x in range(MAP_MAX_X):
		for y in range(MAP_MAX_Y):

			var terrain_cell = terrain.get_cell(x, y)
			# underground
			if terrain_cell > -1:
				self.generate_underground(x, y)
			else:
				self.generate_wave(x, y)


			if terrain_cell == self.tileset.TERRAIN_PLAIN or terrain_cell == self.tileset.TERRAIN_DIRT:
				# bridges
				neigbours = count_neighbours_in_binary(x, y, [-1])

				if neigbours == 10:
					cells_to_change.append({x=x, y=y, type=55})
					temp = null
				elif neigbours == 20:
					cells_to_change.append({x=x, y=y, type=56})
					temp = null
				elif not terrain_cell == self.tileset.TERRAIN_DIRT:
					# plain
					cells_to_change.append({x=x, y=y, type=1})
					# grass, flowers, log
					if ( randi() % 10 ) <= GEN_GRASS:
						temp = map_movable.instance()
						temp.set_frame(randi()%2)
					if ( randi() % 10 ) <= GEN_FLOWERS:
						temp2 = map_movable.instance()
						temp2.set_frame(2 + (randi()%7))
				else:
					# dirt
					cells_to_change.append({x=x, y=y, type=0})
					if ( randi() % 10 ) <= GEN_STONES:
						temp = map_movable.instance()
						temp.set_frame(16 + (randi()%8))
			if temp:
				temp.set_pos(terrain.map_to_world(Vector2(x, y)))
				map_layer_back.add_child(temp)
				temp = null
			if temp2:
				temp2.set_pos(terrain.map_to_world(Vector2(x, y)))
				map_layer_back.add_child(temp2)
				temp2 = null

			# forest
			if terrain_cell == self.tileset.TERRAIN_FOREST:
				temp = map_non_movable.instance()
				temp.set_frame(randi()%5)
				cells_to_change.append({x=x, y=y, type=1})

			# mountains
			if terrain_cell == self.tileset.TERRAIN_MOUNTAINS:
				temp = map_non_movable.instance()
				temp.set_frame(8 + (randi()%4))
				cells_to_change.append({x=x, y=y, type=1})

			# city
			if terrain_cell == self.tileset.TERRAIN_CITY || terrain_cell == self.tileset.TERRAIN_CITY_DESTROYED:
				# have road near or have less than 5 neighbours
				if count_neighbours(x,y,[self.tileset.TERRAIN_ROAD,self.tileset.TERRAIN_DIRT_ROAD, self.tileset.TERRAIN_BRIDGE, self.tileset.TERRAIN_RIVER]) > 0 or count_neighbours(x,y,[self.tileset.TERRAIN_CITY]) < 5:
					temp = map_city_small[randi() % city_small_elements_count].instance()
				else:
					# no roads and not alone
					temp = map_city_big[randi() % city_big_elements_count].instance()
				if terrain_cell == self.tileset.TERRAIN_CITY_DESTROYED:
					temp.set_damage()

			# special buildings
			if terrain_cell == self.tileset.TERRAIN_STATUE:
				temp = map_statue.instance()

			if terrain_cell == self.tileset.TERRAIN_SPAWN:
				cells_to_change.append({x=x, y=y, type=13})

			# military buildings
			if terrain_cell == self.tileset.TERRAIN_HQ_BLUE: # HQ blue
				temp = map_buildings[0].instance()
			if terrain_cell == self.tileset.TERRAIN_HQ_RED: # HQ red
				temp = map_buildings[1].instance()
			if terrain_cell == self.tileset.TERRAIN_BARRACKS_FREE: # barrack
				temp = map_buildings[2].instance()
			if terrain_cell == self.tileset.TERRAIN_FACTORY_FREE: # factory
				temp = map_buildings[3].instance()
			if terrain_cell == self.tileset.TERRAIN_AIRPORT_FREE: # airport
				temp = map_buildings[4].instance()
			if terrain_cell == self.tileset.TERRAIN_TOWER_FREE: # tower
				temp = map_buildings[5].instance()
			if terrain_cell == self.tileset.TERRAIN_BARRACKS_RED: # barrack
				temp = map_buildings[2].instance()
				temp.player = 1
			if terrain_cell == self.tileset.TERRAIN_FACTORY_RED: # factory
				temp = map_buildings[3].instance()
				temp.player = 1
			if terrain_cell == self.tileset.TERRAIN_AIRPORT_RED: # airport
				temp = map_buildings[4].instance()
				temp.player = 1
			if terrain_cell == self.tileset.TERRAIN_TOWER_RED: # tower
				temp = map_buildings[5].instance()
				temp.player = 1
			if terrain_cell == self.tileset.TERRAIN_BARRACKS_BLUE: # barrack
				temp = map_buildings[2].instance()
				temp.player = 0
			if terrain_cell == self.tileset.TERRAIN_FACTORY_BLUE: # factory
				temp = map_buildings[3].instance()
				temp.player = 0
			if terrain_cell == self.tileset.TERRAIN_AIRPORT_BLUE: # airport
				temp = map_buildings[4].instance()
				temp.player = 0
			if terrain_cell == self.tileset.TERRAIN_TOWER_BLUE: # tower
				temp = map_buildings[5].instance()
				temp.player = 0
			if terrain_cell == self.tileset.TERRAIN_FENCE: # fence
				temp = map_buildings[6].instance()

			if temp:
				temp.set_pos(terrain.map_to_world(Vector2(x,y)))
				map_layer_front.add_child(temp)
				self.find_spawn_for_building(x, y, temp)
				if temp.group == 'building':
					temp.claim(temp.player, 0)
				temp = 1
				if count_neighbours(x,y,[0]) >= count_neighbours(x,y,[1]):
					temp = 0
				cells_to_change.append({x=x, y=y, type=temp})
				temp = null

			# roads
			if terrain_cell == self.tileset.TERRAIN_ROAD: # city road
				cells_to_change.append({x=x, y=y, type=self.build_sprite_path(x, y, [self.tileset.TERRAIN_ROAD, self.tileset.TERRAIN_BRIDGE])})
			if terrain_cell == self.tileset.TERRAIN_DIRT_ROAD: # dirt road
				cells_to_change.append({x=x, y=y ,type=self.build_sprite_path(x ,y, [self.tileset.TERRAIN_DIRT_ROAD, self.tileset.TERRAIN_BRIDGE])})
			if terrain_cell == self.tileset.TERRAIN_RIVER: # river
				cells_to_change.append({x=x, y=y, type=self.build_sprite_path(x, y, [self.tileset.TERRAIN_RIVER, self.tileset.TERRAIN_BRIDGE])})
			if terrain_cell == self.tileset.TERRAIN_BRIDGE: # bridge
				cells_to_change.append({x=x, y=y, type=self.build_sprite_path(x, y, [self.tileset.TERRAIN_BRIDGE, self.tileset.TERRAIN_RIVER])})

			if units.get_cell(x,y) > -1:
				self.spawn_unit(x,y,units.get_cell(x,y))

	for cell in cells_to_change:
		if(cell.type > -1):
			terrain.set_cell(cell.x,cell.y,cell.type)
	for fence in get_tree().get_nodes_in_group("terrain_fence"):
		fence.connect_with_neighbours()
	units.hide()
	fog_controller.clear_fog()
	return

func count_neighbours(x, y, type):
	var counted = 0
	var tiles = 1

	for cx in range(x-tiles, x+tiles+1):
		for cy in range(y-tiles, y+tiles+1):
			for t in type:
				if terrain.get_cell(cx,cy) == t:
					counted = counted + 1

	return counted

func count_neighbours_in_binary(x, y, type):
	var counted = 0

	if terrain.get_cell(x, y-1) in type:
		counted += 2
	if terrain.get_cell(x+1, y) in type:
		counted += 4
	if terrain.get_cell(x, y+1) in type:
		counted += 8
	if terrain.get_cell(x-1, y) in type:
		counted += 16

	return counted

func find_spawn_for_building(x, y, building):
	if building.group != "building":
		return
	if building.can_spawn == false:
		return
	self.look_for_spawn(x, y, 1, 0, building)
	self.look_for_spawn(x, y, 0, 1, building)
	self.look_for_spawn(x, y, -1, 0, building)
	self.look_for_spawn(x, y, 0, -1, building)

func look_for_spawn(x, y, offset_x, offset_y, building):
	var cell = terrain.get_cell(x + offset_x, y + offset_y)
	if cell == self.tileset.TERRAIN_SPAWN:
		building.spawn_point_position = Vector2(offset_x, offset_y)
		building.spawn_point = Vector2(x + offset_x, y + offset_y)

func build_sprite_path(x, y, type):
	var neighbours = count_neighbours_in_binary(x, y, type)

	# road
	if type[0] == self.tileset.TERRAIN_ROAD:
		if neighbours in [10,2,8]:
			return 19
		if neighbours in [20,16,4]:
			return 20
		if neighbours == 24:
			return 21
		if neighbours == 12:
			return 22
		if neighbours == 18:
			return 23
		if neighbours == 6:
			return 24
		if neighbours == 26:
			return 25
		if neighbours == 28:
			return 26
		if neighbours == 14:
			return 27
		if neighbours == 22:
			return 28
		if neighbours == 30:
			return 29

	# coutry road
	if type[0] == self.tileset.TERRAIN_DIRT_ROAD:
		if neighbours in [10,2,8]:
			return 36
		if neighbours in [20,16,4]:
			return 37
		if neighbours == 24:
			return 38
		if neighbours == 12:
			return 39
		if neighbours == 18:
			return 40
		if neighbours == 6:
			return 41
		if neighbours == 26:
			return 42
		if neighbours == 28:
			return 43
		if neighbours == 14:
			return 44
		if neighbours == 22:
			return 45
		if neighbours == 30:
			return 46

	# road mix
	if type[0] == 16:
		if neighbours == 2:
			return 32
		if neighbours == 16:
			return 33
		if neighbours == 8:
			return 34
		if neighbours == 4:
			return 35

	# river
	if type[0] == self.tileset.TERRAIN_RIVER:
		if neighbours in [10,2,8]:
			if randi() % 4 > 2:
				return 47
			else:
				return 53
		if neighbours in [20,16,4]:
			if randi() % 4 > 2:
				return 48
			else:
				return 54
		if neighbours == 24:
			return 49
		if neighbours == 12:
			return 50
		if neighbours == 18:
			return 51
		if neighbours == 6:
			return 52

	# bridge
	if type[0] == self.tileset.TERRAIN_BRIDGE:
		if neighbours in [10,2,8]:
			return 31
		if neighbours in [20,16,4]:
			return 30

	# nothing to change
	return false

func spawn_unit(x, y, type):
	var temp = map_units[type].instance()
	temp.set_pos(terrain.map_to_world(Vector2(x,y)))
	map_layer_front.add_child(temp)
	temp = null
	return

func generate_underground(x, y):
	var temp = null
	var neighbours = count_neighbours_in_binary(x, y, [-1])

	temp = underground_rock.instance()
	temp.set_frame(0)
	if neighbours in [10]:
		temp.set_frame(1)
	if neighbours in [20]:
		temp.set_frame(2)
	temp.set_pos(terrain.map_to_world(Vector2(x+1,y+1)))
	underground.add_child(temp)
	temp = null

func generate_wave(x, y):
	var generate = false
	var temp = null

	for cx in range(x-2, x+2):
		for cy in range(y-2, y+2):
			if terrain.get_cell(cx, cy) > -1:
				generate = true

	if generate:
		temp = wave.instance()
		temp.set_pos(terrain.map_to_world(Vector2(x+1,y+1)))
		underground.add_child(temp)
		temp = null
		return true

	return false

func set_default_zoom():
	self.scale = Vector2(2, 2)

func save_map(file_name):
	var temp_data = []
	var temp_terrain = -1
	var temp_unit = -1

	file_name = str(file_name)

	for x in range(MAP_MAX_X):
		for y in range(MAP_MAX_Y):
			if terrain.get_cell(x, y) > -1:
				temp_terrain = terrain.get_cell(x, y)

			if units.get_cell(x, y) > -1:
				temp_unit = units.get_cell(x, y)

			if temp_terrain > -1 or temp_unit > -1:
				temp_data.append({
					x=x,y=y,
					terrain=temp_terrain,
					unit=temp_unit
				})

			temp_terrain = -1
			temp_unit = -1

	if self.check_file_name(file_name):
		self.store_map_in_binary_file(file_name, temp_data)
		self.store_map_in_plain_file(file_name, temp_data)
		#print('ToF: map saved to file')
		return true
	else:
		#print('ToF: wrong file name')
		return false

func store_map_in_binary_file(file_name, data):
	var the_file = map_file.open("user://" + file_name + ".map", File.WRITE)
	map_file.store_var(data)
	map_file.close()
	if file_name != "restore_map":
		self.root.dependency_container.map_list.store_map(file_name)
		self.root.dependency_container.controllers.menu_controller.update_custom_maps_count_label()

func store_map_in_plain_file(file_name, data):
	var the_file = map_file.open("user://" + file_name + ".gd", File.WRITE)
	map_file.store_line("var map_data = [")
	var cell_line
	var cell
	for cell in data:
		cell_line = "'x': " + str(cell.x) + ", "
		cell_line += "'y': " + str(cell.y) + ", "
		cell_line += "'terrain': " + str(cell.terrain) + ", "
		cell_line += "'unit': " + str(cell.unit)
		map_file.store_line("	{" + cell_line + "},")
	map_file.store_line("]")
	map_file.close()

func check_file_name(name):
	# we need to check here for unusual charracters
	# and trim spaces, convert to lower case etc
	# allowed: [a-z] and "-"
	# and can not name 'settings' !!!
	if name == "" || name == "settings":
		return false

	var validator = RegEx.new()
	validator.compile("^([a-zA-Z0-9-_]*)$")
	validator.find(name)
	var matches = validator.get_captures()

	if matches[1] != name:
		return false

	return true

func load_map(file_name):
	var file_path = "user://"+file_name+".map"
	return self.load_map_from_file(file_path)

func load_campaign_map(file_name):
	var campaign_map = self.campaign.get_map_data(file_name)
	self.fill_map_from_data_array(campaign_map.map_data)

func load_map_from_file(file_path):
	var temp_data

	if map_file.file_exists(file_path):
		map_file.open(file_path, File.READ)
		temp_data = map_file.get_var()
		self.fill_map_from_data_array(temp_data)
		#print('ToF: map ' + file_path + ' loaded from file')
		map_file.close()
		return true
	else:
		#print('ToF: map file not exists!')
		return false

func fill_map_from_data_array(data):
	var cell
	self.init_nodes()
	if not self.show_blueprint:
		underground.clear()
	terrain.clear()
	units.clear()
	for cell in data:
		if cell.terrain > -1:
			terrain.set_cell(cell.x, cell.y, cell.terrain)

		if cell.unit > -1:
			units.set_cell(cell.x, cell.y, cell.unit)
	units.raise()

func fill(width, height):
	var offset_x = 0
	var offset_y = 0

	terrain.clear()
	units.clear()
	offset_x = (MAP_MAX_X*0.5) - (width*0.5)
	offset_y = (MAP_MAX_Y*0.5) - (height*0.5)

	for x in range(width):
		for y in range(height):
			terrain.set_cell(x+offset_x, y+offset_y, 1)

func clear_layer(layer):
	if layer == 0:
		units.clear()
		terrain.clear()
	if layer == 1:
		units.clear()

func init_background():
	#print('background generate..')
	for x in range(MAP_MAX_X):
		for y in range(MAP_MAX_Y):
			underground.set_cell(x,y,3)

func init_nodes():
	underground = self.get_node("underground")
	terrain = self.get_node("terrain")
	units = terrain.get_node("units")
	map_layer_back = terrain.get_node("back")
	map_layer_front = terrain.get_node("front")

func _ready():
	root = get_node("/root/game")
	self.init_nodes()
	fog_controller = preload('fog_controller.gd').new(self, terrain)
	fog_controller.init_node()
	self.tileset = self.root.dependency_container.map_tiles

	if root:
		scale = root.scale_root.get_scale()
	else:
		self.set_default_zoom()
	pos = terrain.get_pos()

	shake_timer.set_wait_time(shake_time / shakes_max)
	shake_timer.set_one_shot(true)
	shake_timer.set_autostart(false)
	shake_timer.connect('timeout', self, 'do_single_shake')
	self.add_child(shake_timer)

	# where the magic happens
	if show_blueprint:
		self.init_background()
	else:
		self.generate_map()

	set_process_input(true)
	set_process(true)

