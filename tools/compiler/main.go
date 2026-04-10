package main

import (
	"bytes"
	"encoding/binary"
	"os"
	"path/filepath"
)

// TLD 格式，Type Length Data，名字简单粗暴
func TLD(buf bytes.Buffer, typ uint8, bytes []byte) {
	_ = buf.WriteByte(typ)
	_ = buf.WriteByte(uint8(len(bytes)))
	buf.Write(bytes)
}

var magic = []byte{0x5A, 0xA5, 0x5A, 0xA5}

func pack(files []string) error {
	buf := bytes.Buffer{}

	//Magic
	TLD(buf, 0x01, magic)
	//版本号 2
	TLD(buf, 0x02, []byte{0x00, 0x02})
	//包头长度，固定值
	TLD(buf, 0x03, []byte{0x00, 0x00, 0x00, 0x12})

	l := make([]byte, 2)
	binary.BigEndian.PutUint16(l, uint16(len(files)))

	//文件数量
	TLD(buf, 0x04, l) //TODO 按实际数量
	//CRC校验（无用）
	TLD(buf, 0xFE, []byte{0xFF, 0xFF})

	ln := make([]byte, 4)

	//依次打包文件
	//头
	TLD(buf, 0x01, magic)
	for _, file := range files {

		//文件名（luadb不支持多级目录）
		TLD(buf, 0x02, []byte(filepath.Base(file)))

		//读取文件内容，打包
		bs, err := os.ReadFile(file)
		if err != nil {
			return err
		}

		//长度
		binary.LittleEndian.PutUint32(ln, uint32(len(bs)))
		TLD(buf, 0x03, ln)

		//CRC检验（无用）
		TLD(buf, 0xFE, []byte{0xFF, 0xFF})

		//文件内容
		buf.Write(bs)
	}

	//写入文件
	return os.WriteFile("script.bin", buf.Bytes(), 0666)
}

func main() {
	//TODO 解析工程文件，遍历源文件，打包

}
