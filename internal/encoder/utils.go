package encoder

import (
	"bytes"
	"encoding/binary"
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
