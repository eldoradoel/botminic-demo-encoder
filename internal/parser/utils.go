package parser

import (
	encoder "botminic-demo-encoder/internal/encoder"
	ilog "botminic-demo-encoder/internal/logger"
	common "github.com/markus-wa/demoinfocs-golang/v2/pkg/demoinfocs/common"
	"math"
)

const Pi = 3.14159265358979323846

var bufWeaponMap map[uint64]int32 = make(map[uint64]int32)
var playerLastZ map[uint64]float32 = make(map[uint64]float32)

// Function to handle errors
func checkError(err error) {
	if err != nil {
		ilog.ErrorLogger.Println(err.Error())
	}
}

func parsePlayerInitFrame(player *common.Player) {
	iFrameInit := encoder.FrameInitInfo{
		PlayerName:      player.Name,
		PlayerSteamId64: player.SteamID64,
	}
	iFrameInit.Position[0] = float32(player.Position().X)
	iFrameInit.Position[1] = float32(player.Position().Y)
	iFrameInit.Position[2] = float32(player.Position().Z)
	iFrameInit.Angles[0] = float32(player.ViewDirectionY())
	iFrameInit.Angles[1] = float32(player.ViewDirectionX())

	encoder.InitPlayer(iFrameInit)
	delete(bufWeaponMap, player.SteamID64)
	delete(encoder.PlayerFramesMap, player.SteamID64)

	playerLastZ[player.SteamID64] = float32(player.Position().Z)
}

func normalizeDegree(degree float64) float64 {
	if degree < 0.0 {
		degree = degree + 360.0
	}
	return degree
}

// accept radian, return degree in [0, 360)
func radian2degree(radian float64) float64 {
	return normalizeDegree(radian * 180 / Pi)
}

func parsePlayerFrame(player *common.Player, addonButton int32, tickrate float64, fullsnap bool) {
	iFrameInfo := new(encoder.FrameInfo)
	iFrameInfo.PredictedVelocity[0] = 0.0
	iFrameInfo.PredictedVelocity[1] = 0.0
	iFrameInfo.PredictedVelocity[2] = 0.0
	iFrameInfo.ActualVelocity[0] = float32(player.Velocity().X)
	iFrameInfo.ActualVelocity[1] = float32(player.Velocity().Y)
	iFrameInfo.ActualVelocity[2] = float32(player.Velocity().Z)
	iFrameInfo.PredictedAngles[0] = player.ViewDirectionY()
	iFrameInfo.PredictedAngles[1] = player.ViewDirectionX()
	iFrameInfo.PlayerImpulse = 0
	iFrameInfo.PlayerSeed = 0
	iFrameInfo.PlayerSubtype = 0
	// ----- button encode
	iFrameInfo.PlayerButtons = ButtonConvert(player, addonButton)

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

	// 附加项
	lastIdx := len(encoder.PlayerFramesMap[player.SteamID64]) - 1
	if fullsnap || (lastIdx < 2000 && (lastIdx+1)%100 == 0) || (lastIdx >= 2000 && (lastIdx+1)%100 == 0) {
		iFrameInfo.AdditionalFields |= encoder.FIELDS_ORIGIN
		iFrameInfo.AtOrigin[0] = float32(player.Position().X)
		iFrameInfo.AtOrigin[1] = float32(player.Position().Y)
		iFrameInfo.AtOrigin[2] = float32(player.Position().Z)
		//iFrameInfo.AdditionalFields |= encoder.FIELDS_ANGLES
		//iFrameInfo.AtAngles[0] = float32(player.ViewDirectionY())
		//iFrameInfo.AtAngles[1] = float32(player.ViewDirectionX())
		iFrameInfo.AdditionalFields |= encoder.FIELDS_VELOCITY
		iFrameInfo.AtVelocity[0] = float32(player.Velocity().X)
		iFrameInfo.AtVelocity[1] = float32(player.Velocity().Y)
		iFrameInfo.AtVelocity[2] = float32(player.Velocity().Z)
	}
	// record Z velocity
	deltaZ := float32(player.Position().Z) - playerLastZ[player.SteamID64]
	playerLastZ[player.SteamID64] = float32(player.Position().Z)

	// velocity in Z direction need to be recorded specially
	iFrameInfo.ActualVelocity[2] = deltaZ * float32(tickrate)

	// Since I don't know how to get player's button bits in a tick frame,
	// I have to use *actual vels* and *angles* to generate *predicted vels* approximately
	// This will cause some error, but it's not a big deal

	//lastIdx := len(encoder.PlayerFramesMap[player.SteamID64]) - 1
	if lastIdx >= 0 { // not first frame
		// We assume that actual velocity in tick N
		// is influenced by predicted velocity in tick N-1
		_preVel := &encoder.PlayerFramesMap[player.SteamID64][lastIdx].PredictedVelocity

		// PV = 0.0 when AV(tick N-1) = 0.0 and AV(tick N) = 0.0 ?
		// Note: AV=Actual Velocity, PV=Predicted Velocity
		if !(iFrameInfo.ActualVelocity[0] == 0.0 &&
			iFrameInfo.ActualVelocity[1] == 0.0 &&
			encoder.PlayerFramesMap[player.SteamID64][lastIdx].ActualVelocity[0] == 0.0 &&
			encoder.PlayerFramesMap[player.SteamID64][lastIdx].ActualVelocity[1] == 0.0) {
			var velAngle float64 = 0.0
			if iFrameInfo.ActualVelocity[0] == 0.0 {
				if iFrameInfo.ActualVelocity[1] < 0.0 {
					velAngle = 270.0
				} else {
					velAngle = 90.0
				}
			} else {
				velAngle = radian2degree(math.Atan2(float64(iFrameInfo.ActualVelocity[1]), float64(iFrameInfo.ActualVelocity[0])))
			}
			faceFront := normalizeDegree(float64(iFrameInfo.PredictedAngles[1]))
			deltaAngle := normalizeDegree(velAngle - faceFront)

			const threshold = 30.0
			if 0.0+threshold < deltaAngle && deltaAngle < 180.0-threshold {
				_preVel[1] = -450.0 // left
			}
			if 90.0+threshold < deltaAngle && deltaAngle < 270.0-threshold {
				_preVel[0] = -450.0 // back
			}
			if 180.0+threshold < deltaAngle && deltaAngle < 360.0-threshold {
				_preVel[1] = 450.0 // right
			}
			if 270.0+threshold < deltaAngle || deltaAngle < 90.0-threshold {
				_preVel[0] = 450.0 // front
			}
		}

	}
	encoder.PlayerFramesMap[player.SteamID64] = append(encoder.PlayerFramesMap[player.SteamID64], *iFrameInfo)
}

func saveToRecFile(player *common.Player, roundNum int32, realTick int) {
	if realTick == 64 {
		if player.Team == common.TeamTerrorists {
			encoder.WriteToRecFileIn64Tick(player.Name, player.SteamID64, roundNum, "t")
		} else {
			encoder.WriteToRecFileIn64Tick(player.Name, player.SteamID64, roundNum, "ct")
		}
	} else if realTick == 128 {
		if player.Team == common.TeamTerrorists {
			encoder.WriteToRecFileIn128Tick(player.Name, player.SteamID64, roundNum, "t")
		} else {
			encoder.WriteToRecFileIn128Tick(player.Name, player.SteamID64, roundNum, "ct")
		}
	}
}
