extends Node
## Thin input adapter for the player.
## Currently a stub — skill hotbar system removed in pivot to zombie survival.
## Movement and attack input are handled directly in player.gd.

var _player: Node3D = null


func setup(player: Node3D) -> void:
	_player = player
