package main

import (
	iparser "botminic-demo-encoder/internal/parser"
	"flag"
)

func readArgs() string {
	var filepath string
	flag.StringVar(&filepath, "file", "", "demo file path")
	flag.Parse()
	return filepath
}

func main() {
	iparser.Start(readArgs())
}
