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


proc save*(img: HOBETAImage) =
  if img.filesAmount == 0:
    raise newException(IOError, "Образ пуст")
  var header: array[17, byte]
  copyMem(header[0].addr, img.files[0].filename[0].addr, 8)
  header[8] = img.files[0].extension[0].byte
  littleEndian16(header[9].addr, cast[ptr byte](img.files[0].start.addr))
  littleEndian16(header[11].addr, cast[ptr byte](img.files[0].length.addr))
  header[13] = img.files[0].sectorCount
  let crc: uint16 = calcCRC(header[0 .. 14])
  littleEndian16(header[15].addr, cast[ptr byte](crc.addr))
  let file = open(img.name, fmWrite)
  defer:
    file.close()
  discard file.writeBytes(header, 0, header.len)
  discard file.writeBytes(img.data, 0, img.data.len)
