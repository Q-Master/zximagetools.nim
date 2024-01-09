import std/[tables, endians]
import ../types

type
  TAPFile* = ref object of ZXFile
    sectorCount: uint8

  TAPImage* = ref object of ZXImage[TAPFile]

proc newTAP*(): TAPImage =
  result.new

proc calcCRC(data: openArray[byte]): uint8 =
  var crc: uint8 = 0
  for x in data:
    crc = crc xor x
  return crc

proc parseFile(data: openArray[byte], offset: var uint): TAPFile =
  result.new
  result.ftype = ZXF_CODE
  var datablock: bool = false
  while true:
    let length: uint16 = 0
    littleEndian16(cast[ptr byte](length.addr), data[offset].addr)
    case data[offset+2]
    of 0x00:
      result.ftype = ZXFileType(data[offset+3])
      result.filename = newString(10)
      copyMem(result.filename[0].addr, data[offset+4].addr, 10)
      littleEndian16(cast[ptr byte](result.length.addr), data[offset+14].addr)
      littleEndian16(cast[ptr byte](result.start.addr), data[offset+16].addr)
    of 0xff:
      result.offset = offset+3 .. offset+3+length-2
      datablock = true
    else:
      raise newException(ValueError, "Неверный тип данных в потоке")
    if data[offset+2+length-1] != calcCRC(data[offset+2 .. offset+length]):
        raise newException(ValueError, "Ошибка контрольной суммы блока")
    offset += length.uint + 2
    if datablock:
      break


proc open*(_: typedesc[TAPImage], data: openArray[byte]): TAPImage =
  result.new
  result.data = @data
  var offset = 0.uint
  while offset < data.len.uint:
    result.files.add(parseFile(data, offset))
    result.filesAmount += 1


proc dumpFiles*(img: TAPImage) =
  echo "filename","\t","start","\t","length"
  for f in img.files:
    echo f.filename, "\t", f.start, "\t", f.length
