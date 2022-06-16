package parser

type TickPlayer struct {
	tick    int
	steamid uint64
}

type EventBombPlanted struct {
	BombPlanted bool
	Site        int32
}

type EventPlayerDeath struct {
	Killed   bool
	Victim   int32
	Attacker int32
	HitGroup int32
}
