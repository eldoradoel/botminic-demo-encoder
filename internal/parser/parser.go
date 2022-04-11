package parser

import (
	"os"

	ilog "botminic-demo-encoder/internal/logger"
	dem "github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs"
	events "github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs/events"
)

type TickPlayer struct {
	tick    int
	steamid uint64
}

func Start(filePath string) {

	var validRound = getValidRoundNum(filePath)
	iFile, err := os.Open(filePath)
	checkError(err)

	iParser := dem.NewParser(iFile)
	defer iParser.Close()

	// 处理特殊event构成的button表示
	var buttonTickMap map[TickPlayer]int32 = make(map[TickPlayer]int32)
	var roundstart bool = false
	var matchstart bool = false
	var roundNum int = 0

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
					parsePlayerFrame(player, addonButton, iParser.TickRate(), false)
				}
			}
		}
	})

	iParser.RegisterEventHandler(func(e events.MatchStartedChanged) {
		if e.NewIsStarted && !matchstart {
			matchstart = true
			roundNum = 0
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
		if matchstart && roundNum < validRound {
			roundstart = true
			roundNum++
			ilog.InfoLogger.Printf("回合开始: %d tick: %d", roundNum, iParser.GameState().IngameTick())
			// 初始化录像文件
			// 写入所有选手的初始位置和角度
			gs := iParser.GameState()
			tPlayers := gs.TeamTerrorists().Members()
			ctPlayers := gs.TeamCounterTerrorists().Members()
			Players := append(tPlayers, ctPlayers...)
			for _, player := range Players {
				if player != nil {
					// parse player
					parsePlayerInitFrame(player)
				}
			}
		}
	})

	iParser.RegisterEventHandler(func(e events.RoundEnd) {
		if matchstart && roundNum < validRound {
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

	err = iParser.ParseToEnd()
	checkError(err)
}
