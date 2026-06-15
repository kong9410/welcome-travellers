class_name EntityTeams
extends RefCounted

enum Id {
	NEUTRAL,
	PLAYER_GUARD,
	PLAYER_MERCENARY,
	ENEMY_BANDIT,
	ENEMY_RAIDER,
}

const LABELS: Dictionary = {
	Id.NEUTRAL: "중립",
	Id.PLAYER_GUARD: "경비",
	Id.PLAYER_MERCENARY: "용병",
	Id.ENEMY_BANDIT: "산적",
	Id.ENEMY_RAIDER: "습격자",
}


static func label_for(team_id: Id) -> String:
	return LABELS.get(team_id, "Unknown")


static func is_player_team(team_id: Id) -> bool:
	return team_id in [Id.PLAYER_GUARD, Id.PLAYER_MERCENARY]


static func is_enemy_team(team_id: Id) -> bool:
	return team_id in [Id.ENEMY_BANDIT, Id.ENEMY_RAIDER]
