package parser

import (
	"botminic-demo-encoder/internal/encoder"
	ilog "botminic-demo-encoder/internal/logger"
	"github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs/common"
)

const Pi = 3.14159265358979323846
const MOVETYPE_WALK = 2 /**< Player only - moving on the ground */

var bufWeaponMap = make(map[uint64]int32)
var bufZoomLevelMap = make(map[uint64]int)

// Function to handle errors
func checkError(err error) {
	if err != nil {
		ilog.ErrorLogger.Println(err.Error())
	}
}

func parsePlayerInitFrame(player *common.Player, realTick int) {
	iFrameInit := encoder.FrameInitInfo{
		PlayerName:      player.Name,
		PlayerSteamId64: player.SteamID64,
	}

	encoder.InitPlayer(iFrameInit, realTick)

	delete(bufWeaponMap, player.SteamID64)
	delete(bufZoomLevelMap, player.SteamID64)
	delete(encoder.PlayerFramesMap, player.SteamID64)
}

func parsePlayerFrame(player *common.Player, addonButton int32, roundNum int, eventBombPlanted EventBombPlanted, itemDropped int32) {
	iFrameInfo := new(encoder.FrameInfo)
	iFrameInfo.Origin[0] = float32(player.Position().X)
	iFrameInfo.Origin[1] = float32(player.Position().Y)
	iFrameInfo.Origin[2] = float32(player.Position().Z)
	iFrameInfo.Angle[0] = player.ViewDirectionY()
	iFrameInfo.Angle[1] = player.ViewDirectionX()

	// ----- button encode
	iFrameInfo.PlayerButtons = ButtonConvert(player, addonButton)

	if player.Entity.Property("m_fFlags") != nil {
		iFrameInfo.EntityFlag = int32(player.Entity.Property("m_fFlags").Value().IntVal)
	}

	iFrameInfo.MoveType = MOVETYPE_WALK

	// ---- weapon encode
	var currWeaponID int32 = 0
	if player.ActiveWeapon() != nil {
		currWeaponID = int32(WeaponStr2ID(player.ActiveWeapon().String()))
	}

	if len(encoder.PlayerFramesMap[player.SteamID64]) == 0 {
		iFrameInfo.CSWeaponID = currWeaponID
		bufWeaponMap[player.SteamID64] = currWeaponID
	} else if currWeaponID == bufWeaponMap[player.SteamID64] {
		iFrameInfo.CSWeaponID = int32(CSWeapon_NONE)
	} else {
		iFrameInfo.CSWeaponID = currWeaponID
		bufWeaponMap[player.SteamID64] = currWeaponID
	}

	// ---- event_bomb_planted
	if eventBombPlanted.BombPlanted {
		iFrameInfo.BombPlanted = 1
		iFrameInfo.Site = eventBombPlanted.Site
	} else {
		iFrameInfo.BombPlanted = 0
		iFrameInfo.Site = 0
	}

	if itemDropped != -1 {
		iFrameInfo.ItemDropped = itemDropped
	} else {
		iFrameInfo.ItemDropped = -1
	}

	encoder.PlayerFramesMap[player.SteamID64] = append(encoder.PlayerFramesMap[player.SteamID64], *iFrameInfo)
}

func saveToRecFile(player *common.Player, roundNum int32) {
	if player.Team == common.TeamTerrorists {
		encoder.WriteToRecFile(player.Name, player.SteamID64, roundNum, "t")
	} else {
		encoder.WriteToRecFile(player.Name, player.SteamID64, roundNum, "ct")
	}
}
