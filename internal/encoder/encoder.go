package encoder

import (
	"bytes"
	"os"
	"strconv"
	"time"

	ilog "botminic-demo-encoder/internal/logger"
)

const __MAGIC__ int32 = -559038737
const __FORMAT_VERSION__ int8 = 2
const FIELDS_ORIGIN int32 = 1 << 0
const FIELDS_ANGLES int32 = 1 << 1
const FIELDS_VELOCITY int32 = 1 << 2

var bufMap map[uint64]*bytes.Buffer = make(map[uint64]*bytes.Buffer)
var PlayerFramesMap map[uint64][]FrameInfo = make(map[uint64][]FrameInfo)

var saveDir string = "./output"

func init() {
	if ok, _ := PathExists(saveDir); !ok {
		os.Mkdir(saveDir, os.ModePerm)
		ilog.InfoLogger.Println("未找到保存目录，已创建：", saveDir)
	} else {
		ilog.InfoLogger.Println("保存目录存在：", saveDir)
	}
}

func InitPlayer(initFrame FrameInitInfo) {
	if bufMap[initFrame.PlayerSteamId64] == nil {
		bufMap[initFrame.PlayerSteamId64] = new(bytes.Buffer)
	} else {
		bufMap[initFrame.PlayerSteamId64].Reset()
	}
	// step.1 MAGIC NUMBER
	WriteToBuf(initFrame.PlayerSteamId64, __MAGIC__)

	// step.2 VERSION
	WriteToBuf(initFrame.PlayerSteamId64, __FORMAT_VERSION__)

	// step.3 timestamp
	WriteToBuf(initFrame.PlayerSteamId64, int32(time.Now().Unix()))

	// step.4 name length
	WriteToBuf(initFrame.PlayerSteamId64, int8(len(initFrame.PlayerName)))

	// step.5 name
	WriteToBuf(initFrame.PlayerSteamId64, []byte(initFrame.PlayerName))

	// step.6 initial position
	//for idx := 0; idx < 3; idx++ {
	//	WriteToBuf(initFrame.PlayerSteamId64, float32(initFrame.Position[idx]))
	//}

	// step.7 initial angle
	//for idx := 0; idx < 2; idx++ {
	//	WriteToBuf(initFrame.PlayerSteamId64, initFrame.Angles[idx])
	//}
	ilog.InfoLogger.Println("初始化成功: ", initFrame.PlayerName)
}

func WriteToRecFileTick(playerName string, playerSteamId64 uint64, roundNum int32, subdir string) {
	subDir := saveDir + "/round" + strconv.Itoa(int(roundNum)) + "/" + subdir
	if ok, _ := PathExists(subDir); !ok {
		os.MkdirAll(subDir, os.ModePerm)
	}
	fileName := subDir + "/" + strconv.FormatUint(playerSteamId64, 10) + ".rec"
	file, err := os.Create(fileName) // 创建文件, "binbin"是文件名字
	if err != nil {
		ilog.ErrorLogger.Println("文件创建失败", err.Error())
		return
	}
	defer file.Close()

	// step.8 tick count
	var tickCount int32 = int32(len(PlayerFramesMap[playerSteamId64]))

	WriteToBuf(playerSteamId64, tickCount)

	// step.9 bookmark count
	//WriteToBuf(playerSteamId64, int32(0))

	// step.10 all bookmark
	// ignore

	// step.11 all tick frame
	for _, frame := range PlayerFramesMap[playerSteamId64] {
		//WriteToBuf(playerSteamId64, frame.PlayerButtons)
		//WriteToBuf(playerSteamId64, frame.PlayerImpulse)
		for idx := 0; idx < 3; idx++ {
			WriteToBuf(playerSteamId64, frame.ActualVelocity[idx])
		}
		//for idx := 0; idx < 3; idx++ {
		//	WriteToBuf(playerSteamId64, frame.PredictedVelocity[idx])
		//}
		for idx := 0; idx < 2; idx++ {
			WriteToBuf(playerSteamId64, frame.PredictedAngles[idx])
		}
		WriteToBuf(playerSteamId64, frame.PlayerButtons)
		WriteToBuf(playerSteamId64, frame.CSWeaponID)
		WriteToBuf(playerSteamId64, frame.EntityFlay)
		WriteToBuf(playerSteamId64, frame.MoveType)
		//WriteToBuf(playerSteamId64, frame.PlayerSubtype)
		//WriteToBuf(playerSteamId64, frame.PlayerSeed)
		//WriteToBuf(playerSteamId64, frame.AdditionalFields)
		// 附加信息
		//if frame.AdditionalFields&FIELDS_ORIGIN != 0 {
		//	for idx := 0; idx < 3; idx++ {
		//		WriteToBuf(playerSteamId64, frame.AtOrigin[idx])
		//	}
		//}
		//if frame.AdditionalFields&FIELDS_ANGLES != 0 {
		//	for idx := 0; idx < 3; idx++ {
		//		WriteToBuf(playerSteamId64, frame.AtAngles[idx])
		//	}
		//}
		//if frame.AdditionalFields&FIELDS_VELOCITY != 0 {
		//	for idx := 0; idx < 3; idx++ {
		//		WriteToBuf(playerSteamId64, frame.AtVelocity[idx])
		//	}
		//}
	}

	delete(PlayerFramesMap, playerSteamId64)
	file.Write(bufMap[playerSteamId64].Bytes())
	ilog.InfoLogger.Printf("[第%d回合] [%s] 录像保存成功: %d.rec\n", roundNum, playerName, playerSteamId64)
}
