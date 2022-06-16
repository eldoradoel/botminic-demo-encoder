package encoder

type FrameInitInfo struct {
	PlayerName      string
	PlayerSteamId64 uint64
}

// replay frame
type FrameInfo struct {
	Origin        [3]float32
	Angle         [2]float32
	PlayerButtons int32
	EntityFlag    int32
	MoveType      int32
	CSWeaponID    int32
	// event_bomb_planted
	Site int32
	// event_item_drop
	ItemDropped int32
	// event_player_death
	Victim   int32
	Attacker int32
	HitGroup int32
	// props
	Health     int32
	Armor      int32
	HasDefuser int32
	HasHelmet  int32
}
