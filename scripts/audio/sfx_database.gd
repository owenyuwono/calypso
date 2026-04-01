class_name SfxDatabase
extends RefCounted
## Static SFX definitions mapping string keys to audio stream metadata.

const DATA: Dictionary = {
	# --- Combat ---
	"combat_hit_sword": {
		"path": "res://assets/audio/sfx/combat/hit_sword.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.1,
	},
	"combat_hit_axe": {
		"path": "res://assets/audio/sfx/combat/hit_axe.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.1,
	},
	"combat_hit_mace": {
		"path": "res://assets/audio/sfx/combat/hit_mace.ogg",
		"volume_db": 2.0,
		"pitch_variance": 0.08,
	},
	"combat_hit_dagger": {
		"path": "res://assets/audio/sfx/combat/hit_dagger.ogg",
		"volume_db": -2.0,
		"pitch_variance": 0.12,
	},
	"combat_hit_staff": {
		"path": "res://assets/audio/sfx/combat/hit_staff.ogg",
		"volume_db": -1.0,
		"pitch_variance": 0.1,
	},
	"combat_hit_generic": {
		"path": "res://assets/audio/sfx/combat/hit_generic.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.1,
	},
	"combat_death": {
		"path": "res://assets/audio/sfx/combat/monster_death.ogg",
		"volume_db": 2.0,
		"pitch_variance": 0.05,
	},
	"combat_hurt": {
		"path": "res://assets/audio/sfx/combat/entity_hurt.ogg",
		"volume_db": -2.0,
		"pitch_variance": 0.15,
	},
	"combat_skill": {
		"path": "res://assets/audio/sfx/combat/skill_activate.ogg",
		"volume_db": 1.0,
		"pitch_variance": 0.05,
	},
	"combat_loop": {
		"path": "res://assets/audio/sfx/combat/combat_loop.ogg",
		"volume_db": -6.0,
		"pitch_variance": 0.0,
	},
	"combat_block": {
		"path": "res://assets/audio/sfx/combat/hit_mace.ogg",
		"volume_db": -1.0,
		"pitch_variance": 0.15,
	},
	"combat_parry": {
		"path": "res://assets/audio/sfx/combat/skill_activate.ogg",
		"volume_db": 2.0,
		"pitch_variance": 0.05,
	},
	"combat_guard_break": {
		"path": "res://assets/audio/sfx/combat/entity_hurt.ogg",
		"volume_db": 1.0,
		"pitch_variance": 0.1,
	},

	# --- Gathering ---
	"gather_tree_chop": {
		"path": "res://assets/audio/sfx/gathering/tree_chop.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.1,
	},
	"gather_rock_mine": {
		"path": "res://assets/audio/sfx/gathering/rock_mine.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.1,
	},
	"gather_fishing_cast": {
		"path": "res://assets/audio/sfx/gathering/fishing_cast.ogg",
		"volume_db": -2.0,
		"pitch_variance": 0.08,
	},
	"gather_tree_fall": {
		"path": "res://assets/audio/sfx/gathering/tree_fall.ogg",
		"volume_db": 4.0,
		"pitch_variance": 0.05,
	},
	"gather_rock_break": {
		"path": "res://assets/audio/sfx/gathering/rock_break.ogg",
		"volume_db": 2.0,
		"pitch_variance": 0.08,
	},
	"gather_fish_catch": {
		"path": "res://assets/audio/sfx/gathering/fishing_catch.ogg",
		"volume_db": -1.0,
		"pitch_variance": 0.1,
	},

	# --- Movement ---
	"footstep_stone": {
		"path": "res://assets/audio/sfx/movement/footstep_stone.ogg",
		"volume_db": -8.0,
		"pitch_variance": 0.05,
	},
	"footstep_grass": {
		"path": "res://assets/audio/sfx/movement/footstep_grass.ogg",
		"volume_db": -10.0,
		"pitch_variance": 0.05,
	},
	"footstep_dirt": {
		"path": "res://assets/audio/sfx/movement/footstep_dirt.ogg",
		"volume_db": -9.0,
		"pitch_variance": 0.05,
	},

	# --- Presence ---
	"presence_monster_idle": {
		"path": "res://assets/audio/sfx/presence/monster_idle.ogg",
		"volume_db": -12.0,
		"pitch_variance": 0.02,
	},
	"presence_npc_ambient": {
		"path": "res://assets/audio/sfx/presence/npc_ambient.ogg",
		"volume_db": -16.0,
		"pitch_variance": 0.02,
	},

	# --- UI ---
	"ui_panel_open": {
		"path": "res://assets/audio/sfx/ui/panel_open.ogg",
		"volume_db": -4.0,
		"pitch_variance": 0.0,
	},
	"ui_panel_close": {
		"path": "res://assets/audio/sfx/ui/panel_close.ogg",
		"volume_db": -4.0,
		"pitch_variance": 0.0,
	},
	"ui_button_click": {
		"path": "res://assets/audio/sfx/ui/button_click.ogg",
		"volume_db": -6.0,
		"pitch_variance": 0.0,
	},
	"ui_level_up": {
		"path": "res://assets/audio/sfx/ui/level_up.ogg",
		"volume_db": 0.0,
		"pitch_variance": 0.0,
	},
	"ui_item_equip": {
		"path": "res://assets/audio/sfx/ui/item_equip.ogg",
		"volume_db": -4.0,
		"pitch_variance": 0.05,
	},
	"ui_buy_sell": {
		"path": "res://assets/audio/sfx/ui/buy_sell.ogg",
		"volume_db": -2.0,
		"pitch_variance": 0.05,
	},
	"ui_craft_complete": {
		"path": "res://assets/audio/sfx/ui/craft_complete.ogg",
		"volume_db": -2.0,
		"pitch_variance": 0.0,
	},

	# --- Ambient ---
	"ambient_fountain": {
		"path": "res://assets/audio/ambient/fountain_loop.ogg",
		"volume_db": -6.0,
		"pitch_variance": 0.0,
	},
	"ambient_forge": {
		"path": "res://assets/audio/ambient/forge_hammer_loop.ogg",
		"volume_db": -4.0,
		"pitch_variance": 0.0,
	},
	"ambient_market": {
		"path": "res://assets/audio/ambient/market_chatter_loop.ogg",
		"volume_db": -8.0,
		"pitch_variance": 0.0,
	},
	"ambient_birds_day": {
		"path": "res://assets/audio/ambient/birds_day.ogg",
		"volume_db": -6.0,
		"pitch_variance": 0.0,
	},
	"ambient_crickets_night": {
		"path": "res://assets/audio/ambient/crickets_night.ogg",
		"volume_db": -6.0,
		"pitch_variance": 0.0,
	},
	"ambient_wind_field": {
		"path": "res://assets/audio/ambient/wind_field.ogg",
		"volume_db": -4.0,
		"pitch_variance": 0.0,
	},
}

static func get_sfx(key: String) -> Dictionary:
	return DATA.get(key, {})
