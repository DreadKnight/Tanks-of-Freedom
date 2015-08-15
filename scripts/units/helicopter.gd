extends "behaviours.gd"

func _init():
	type = 2
	type_name = 'helicopter'

	life = 10
	max_life = 10
	attack = 8
	max_ap = 8
	attack_ap = 1
	max_attacks_number = 1
	ap = 8
	attacks_number = 1
	visibility = 4
	self.set_flip_h(randi()%2)

func can_capture_building(building):
	return false

