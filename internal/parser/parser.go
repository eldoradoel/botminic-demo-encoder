package parser

import (
	"math"
	"os"

	ilog "botminic-demo-encoder/internal/logger"
	dem "github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs"
	events "github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs/events"
)

func Start(filePath string) {

	iFile, err := os.Open(filePath)
	checkError(err)

	iParser := dem.NewParser(iFile)
	defer iParser.Close()

	// 处理特殊event构成的button表示
	var buttonTickMap = make(map[TickPlayer]int32)
	var bombPlantedTickMap = make(map[TickPlayer]EventBombPlanted)
	var itemDropTickMap = make(map[TickPlayer]int32)
	var roundstart = false
	var matchstart = false
	var roundNum = 0
	var realTick = 0
	iParserHeader, err := iParser.ParseHeader()
	if err == nil {
		ilog.InfoLogger.Printf("demo实际Tick为：%d", int(math.Floor(iParserHeader.FrameRate()+0.5)))
		ilog.InfoLogger.Printf("demo演示地图为: %s", iParserHeader.MapName)
		realTick = int(math.Floor(iParserHeader.FrameRate() + 0.5))
		ilog.InfoLogger.Println(iParserHeader.FrameRate())
	}

	iParser.RegisterEventHandler(func(e events.FrameDone) {
		gs := iParser.GameState()
		currentTick := gs.IngameTick()

		if roundstart && matchstart {
			tPlayers := gs.TeamTerrorists().Members()
			ctPlayers := gs.TeamCounterTerrorists().Members()
			Players := append(tPlayers, ctPlayers...)
			for _, player := range Players {
				if player != nil && player.IsAlive() {
					var addonButton int32 = 0
					key := TickPlayer{currentTick, player.SteamID64}
					if val, ok := buttonTickMap[key]; ok {
						addonButton = val
						delete(buttonTickMap, key)
					}

					var eventBombPlant EventBombPlanted
					if val, ok := bombPlantedTickMap[key]; ok {
						eventBombPlant = val
						delete(bombPlantedTickMap, key)
					}

					var itemDropped int32 = -1
					if val, ok := itemDropTickMap[key]; ok {
						itemDropped = val
						delete(itemDropTickMap, key)
					}

					// 不处理>3回合
					//if roundNum > 3 {
					//	return
					//}

					parsePlayerFrame(player, addonButton, roundNum, eventBombPlant, itemDropped)
				}
			}
		}
	})

	iParser.RegisterEventHandler(func(e events.MatchStartedChanged) {
		if e.NewIsStarted && !matchstart {
			matchstart = true
			ilog.InfoLogger.Println("比赛开始")
		}
	})

	iParser.RegisterEventHandler(func(e events.AnnouncementWinPanelMatch) {
		if matchstart {
			matchstart = false
			gs := iParser.GameState()
			tPlayers := gs.TeamTerrorists().Members()
			ctPlayers := gs.TeamCounterTerrorists().Members()
			Players := append(tPlayers, ctPlayers...)
			for _, player := range Players {
				if player != nil {
					// save to rec file
					saveToRecFile(player, int32(roundNum))
				}
			}
			ilog.InfoLogger.Println("比赛结束")
		}
	})

	iParser.RegisterEventHandler(func(e events.RoundStart) {
		roundstart = true
		roundNum++
		ilog.InfoLogger.Printf("回合开始: %d tick: %d", roundNum, iParser.GameState().IngameTick())
		// 初始化录像文件
		gs := iParser.GameState()
		tPlayers := gs.TeamTerrorists().Members()
		ctPlayers := gs.TeamCounterTerrorists().Members()
		Players := append(tPlayers, ctPlayers...)
		for _, player := range Players {
			if player != nil {
				// parse player
				parsePlayerInitFrame(player, realTick)
			}
		}
	})

	iParser.RegisterEventHandler(func(e events.RoundEnd) {
		if matchstart {
			roundstart = false
			ilog.InfoLogger.Printf("回合结束: %d tick: %d", roundNum, iParser.GameState().IngameTick())
			// 结束录像文件
			gs := iParser.GameState()
			tPlayers := gs.TeamTerrorists().Members()
			ctPlayers := gs.TeamCounterTerrorists().Members()
			Players := append(tPlayers, ctPlayers...)
			for _, player := range Players {
				if player != nil {
					saveToRecFile(player, int32(roundNum))
				}
			}
		}
	})

	//开火cmd
	iParser.RegisterEventHandler(func(e events.WeaponFire) {
		gs := iParser.GameState()
		currentTick := gs.IngameTick()
		key := TickPlayer{currentTick, e.Shooter.SteamID64}
		if _, ok := buttonTickMap[key]; ok {
			buttonTickMap[key] |= IN_ATTACK
		} else {
			buttonTickMap[key] = IN_ATTACK
		}
	})

	//跳跃cmd
	iParser.RegisterEventHandler(func(e events.PlayerJump) {
		gs := iParser.GameState()
		currentTick := gs.IngameTick()
		key := TickPlayer{currentTick, e.Player.SteamID64}
		if _, ok := buttonTickMap[key]; ok {
			buttonTickMap[key] |= IN_JUMP
		} else {
			buttonTickMap[key] = IN_JUMP
		}
	})

	iParser.RegisterEventHandler(func(e events.BombPlanted) {
		gs := iParser.GameState()
		currentTick := gs.IngameTick()
		key := TickPlayer{currentTick, e.Player.SteamID64}

		var event EventBombPlanted
		event.BombPlanted = true
		if e.Site == 'A' {
			event.Site = 0
		} else {
			event.Site = 1
		}

		bombPlantedTickMap[key] = event
	})

	iParser.RegisterEventHandler(func(e events.ItemDrop) {
		gs := iParser.GameState()
		currentTick := gs.IngameTick()
		if e.Player != nil {
			key := TickPlayer{currentTick, e.Player.SteamID64}
			itemDropTickMap[key] = int32(e.Player.EntityID)
		}
	})

	err = iParser.ParseToEnd()
	checkError(err)
}
