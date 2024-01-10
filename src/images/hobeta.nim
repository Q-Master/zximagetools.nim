import std/[endians]
import ../types
from ./trd import nil

type
  HOBETAImage* = ref object of ZXImage[trd.TRDFile]


proc calcCRC(data: openArray[byte]): uint16 =
  result = 0
  var i: uint16 = 0
  for d in data:
    result += d.uint16*257+i.uint16
    i.inc


proc newHOBETA*(): HOBETAImage =
  result.new


proc open*(_: typedesc[HOBETAImage], data: openArray[byte]): HOBETAImage =
  let crc: uint16 = 0
  littleEndian16(cast[ptr byte](crc.addr), data[15].addr)
  if crc != calcCRC(data[0 .. 14]):
    raise newException(ValueError, "Ошибка контрольной суммы")
  result.new
  result.data = @data
  result.filesAmount = 1
  var file = trd.TRDFile.new
  file.filename = newString(8)
  copyMem(file.filename[0].addr, data[0].addr, 8)
  file.extension = newString(1)
  file.extension[0] = cast[char](data[8])
  littleEndian16(cast[ptr byte](file.start.addr), data[9].addr)
  littleEndian16(cast[ptr byte](file.length.addr), data[11].addr)
  file.sectorCount = data[13]
  file.offset = 17.uint .. data.high.uint
  result.files.add(file)


proc dumpFiles*(img: HOBETAImage) =
  echo "filename","\t","start","\t","length"
  for f in img.files:
    echo f.filename, ".", f.extension, "\t", f.start, "\t", f.length
