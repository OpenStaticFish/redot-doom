class_name Arsenal
extends RefCounted

const WEAPONS = [
	{"id": "fist", "name": "IRON FIST", "ammo": "", "cost": 0, "delay": 0.42, "damage": 35, "pellets": 1, "spread": 0.0, "range": 2.5},
	{"id": "pistol", "name": "SERVICE PISTOL", "ammo": "bullets", "cost": 1, "delay": 0.27, "damage": 18, "pellets": 1, "spread": 0.009, "range": 90.0},
	{"id": "shotgun", "name": "PUMP SHOTGUN", "ammo": "shells", "cost": 1, "delay": 0.78, "damage": 13, "pellets": 7, "spread": 0.057, "range": 65.0},
	{"id": "chaingun", "name": "ROTARY CANNON", "ammo": "bullets", "cost": 1, "delay": 0.095, "damage": 17, "pellets": 1, "spread": 0.021, "range": 85.0},
	{"id": "launcher", "name": "ROCKET LAUNCHER", "ammo": "rockets", "cost": 1, "delay": 0.72, "damage": 125, "pellets": 1, "spread": 0.0, "range": 90.0},
	{"id": "plasma", "name": "ARC PLASMA RIFLE", "ammo": "cells", "cost": 1, "delay": 0.115, "damage": 28, "pellets": 1, "spread": 0.015, "range": 90.0}
]
const AMMO_MAX = {"bullets": 400, "shells": 100, "rockets": 50, "cells": 400}

static func definition(index: int) -> Dictionary:
	return WEAPONS[clampi(index, 0, WEAPONS.size() - 1)]
