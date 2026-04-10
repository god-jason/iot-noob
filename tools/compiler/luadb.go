package main

import (
	"bytes"
	"encoding/binary"
	"os"
	"path/filepath"
)

var magic = []byte{0x5A, 0xA5, 0x5A, 0xA5}

const version = 2

type LuaDB struct {
	buf   bytes.Buffer
	Files []string
}

func (l *LuaDB) writeBytes(typ uint8, bytes []byte) {
	_ = l.buf.WriteByte(typ)
	_ = l.buf.WriteByte(uint8(len(bytes)))
	l.buf.Write(bytes)
}

func (l *LuaDB) writeUint16(typ uint8, value uint16) {
	_ = l.buf.WriteByte(typ)
	_ = l.buf.WriteByte(2)
	_ = binary.Write(&l.buf, binary.LittleEndian, value)
}

func (l *LuaDB) writeUint32(typ uint8, value uint32) {
	_ = l.buf.WriteByte(typ)
	_ = l.buf.WriteByte(4)
	_ = binary.Write(&l.buf, binary.LittleEndian, value)
}

func (l *LuaDB) write(bytes []byte) {
	l.buf.Write(bytes)
}

func (l *LuaDB) Bytes() []byte {
	return l.buf.Bytes()
}

func (l *LuaDB) Package(filename string) error {

	//Magic
	l.writeBytes(0x01, magic)

	//版本号 2
	l.writeUint16(0x02, version)

	//包头长度，固定值
	l.writeUint32(0x03, 0x18)

	//文件数量
	l.writeUint16(0x04, uint16(len(l.Files)))

	//CRC校验 TODO 实际算了
	l.writeBytes(0xFE, []byte{0xFF, 0xFF})

	//依次打包文件
	//头
	l.writeBytes(0x01, magic)
	for _, file := range l.Files {

		//文件名（luadb不支持多级目录）
		l.writeBytes(0x02, []byte(filepath.Base(file)))

		//读取文件内容，打包
		bs, err := os.ReadFile(file)
		if err != nil {
			return err
		}

		//长度
		l.writeUint32(0x03, uint32(len(bs)))

		//CRC检验
		l.writeBytes(0xFE, []byte{0xFF, 0xFF})

		//文件内容
		l.write(bs)
	}

	//写入文件
	return os.WriteFile(filename, l.Bytes(), 0666)
}
