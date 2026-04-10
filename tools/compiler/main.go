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
	l4 := make([]byte, 4)
	l2 := make([]byte, 2)

	//Magic
	TLD(buf, 0x01, magic)

	//版本号 2
	binary.LittleEndian.PutUint16(l2, 2)
	TLD(buf, 0x02, l2)

	//包头长度，固定值
	binary.LittleEndian.PutUint32(l4, 0x18)
	TLD(buf, 0x03, l4)

	//文件数量
	binary.LittleEndian.PutUint16(l2, uint16(len(files)))
	TLD(buf, 0x04, l2) //TODO 按实际数量

	//CRC校验 TODO 实际算了
	TLD(buf, 0xFE, []byte{0xFF, 0xFF})

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
		binary.LittleEndian.PutUint32(l4, uint32(len(bs)))
		TLD(buf, 0x03, l4)

		//CRC检验
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
