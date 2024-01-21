import std/[tables, endians, strutils]
import ../types

type
  TAPFile* = ref object of ZXFile

  TAPImage* = ref object of ZXImage[TAPFile]


proc newTAP*(name: string): TAPImage =
  result.new
  result.name = name


proc newImg*(_:typedesc[TAPImage], name: string): TAPImage =
  result = newTAP(name)


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
      case result.ftype:
      of ZXF_PROGRAMM:
        result.extension = "B"
      of ZXF_CODE:
        result.extension = "C"
      of ZXF_CHARACTER_ARRAY, ZXF_NUMBER_ARRAY:
        result.extension = "D"
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


proc getFile*(img: TAPImage, num: uint): ZXExportData =
  if num > img.filesAmount:
    raise newException(ValueError, "Номер файла слишком велик")
  let header = img.files[num]
  result = newExportData(header, img.data[header.offset])


proc addHeader(img: TAPImage, file: TAPFile) =
  var header: array[19, byte]
  header[0] = 0x13.byte
  header[1] = 0x00.byte
  header[2] = 0x00.byte
  header[3] = file.ftype.byte
  copyMem(header[4].addr, file.filename[0].addr, 10)
  littleEndian16(header[14].addr, cast[ptr byte](file.length.addr))
  littleEndian16(header[16].addr, cast[ptr byte](file.start.addr))
  header[18] = calcCRC(header[2 .. header.high-1])
  img.data.add(header)

proc addFile*(img: TAPImage, file: ZXExportData) =
  var f = TAPFile()
  f.filename = file.header.filename.alignLeft(10)[0 .. 10]
  f.extension = file.header.extension
  f.start = file.header.start
  f.length = file.header.length
  f.ftype = file.header.ftype
  img.addHeader(f)
  let startOffset: uint = img.data.high.uint + 3
  f.offset = startOffset .. startOffset+file.data.len.uint-1
  var data: seq[byte] = newSeq[byte](file.data.len+2+2)
  littleEndian16(data[0].addr, cast[ptr byte](f.length.addr))
  data[2] = 0xff.byte
  copyMem(data[3].addr, file.data[0].addr, file.data.len)
  data[data.high] = calcCRC(data[2 .. data.high])
  img.data.add(data)
  img.files.add(f)
  img.filesAmount.inc


proc save*(img: TAPImage) =
  let file = open(img.name, fmWrite)
  defer:
    file.close()
  discard file.writeBytes(img.data, 0, img.data.high)
