import std/[endians, strutils]
import ../types
import ./trdutils
from ./trd import nil

type
  HOBETAImage* = ref object of ZXImage[trd.TRDFile]


proc calcCRC(data: openArray[byte]): uint16 =
  result = 0
  var i: uint16 = 0
  for d in data:
    result += d.uint16*257+i.uint16
    i.inc


proc newHOBETA*(name: string): HOBETAImage =
  result.new
  result.name = name


proc newImg*(_:typedesc[HOBETAImage], name: string): HOBETAImage =
  result = newHOBETA(name)


proc open*(_: typedesc[HOBETAImage], data: openArray[byte]): HOBETAImage =
  let crc: uint16 = 0
  littleEndian16(cast[ptr byte](crc.addr), data[15].addr)
  if crc != calcCRC(data[0 .. 14]):
    raise newException(ValueError, "Ошибка контрольной суммы")
  result.new
  result.data = @data[17.uint .. data.high]
  result.filesAmount = 1
  var file = trd.TRDFile.new
  file.filename = newString(8)
  copyMem(file.filename[0].addr, data[0].addr, 8)
  file.extension = newString(1)
  file.extension[0] = cast[char](data[8])
  littleEndian16(cast[ptr byte](file.start.addr), data[9].addr)
  littleEndian16(cast[ptr byte](file.length.addr), data[11].addr)
  file.sectorCount = data[13]
  file.offset = 0.uint .. result.data.high.uint
  result.files.add(file)


proc dumpFiles*(img: HOBETAImage) =
  echo "filename","\t","start","\t","length"
  for f in img.files:
    echo f.filename, ".", f.extension, "\t", f.start, "\t", f.length


proc getFile*(img: HOBETAImage, num: uint): ZXExportData =
  let header = img.files[0]
  result = newExportData(header, img.data[header.offset])


proc getFile*[T: HOBETAImage](img: T, name: string): ZXExportData =
  return img.getFile(0)


proc addFile*(img: HOBETAImage, file: ZXExportData) =
  if img.filesAmount > 0:
    raise newException(IOError, "В каталоге недостаточно места")
  let realFileSize = roundToSize(file.data.len.uint)
  let sectorSize = realFileSize.div(256)
  if sectorSize > 255:
    raise newException(IOError, "Размер файла слишком велик")
  var f = trd.TRDFile()
  f.filename = file.header.filename.alignLeft(8)[0 .. 8]
  f.extension = file.header.extension
  f.start = file.header.start
  f.length = file.header.length
  f.ftype = file.header.ftype
  f.sectorCount = sectorSize.uint8
  f.offset = 0.uint .. file.data.high.uint
  img.data = file.data
  img.files.add(f)
  img.filesAmount.inc
  