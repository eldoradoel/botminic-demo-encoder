package parser

type TickPlayer struct {
	tick    int
	steamid uint64
}

type EventBombPlanted struct {
	BombPlanted bool
	Site        int32
}
