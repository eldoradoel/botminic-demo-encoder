package encoder

import (
	"bytes"
	"encoding/binary"
	"math"
	"os"
)

func PathExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

func WriteToBuf(key uint64, data interface{}) {
	if bufMap[key] == nil {
		bufMap[key] = new(bytes.Buffer)
	} else {
		binary.Write(bufMap[key], binary.LittleEndian, data)
		// bufMap[key].Reset()
	}
}

func GetAngleDiff(current float32, previous float32) float32 {
	var different float64 = float64(current - previous)
	return float32(different - 360.0*math.Floor((different+180.0)/360.0))
}

func AngleNormalize(flAngle float32) float32 {
	if flAngle > 180.0 {
		return flAngle - 360.0
	} else if flAngle < -180.0 {
		return flAngle + 360.0
	}
	return flAngle
}
