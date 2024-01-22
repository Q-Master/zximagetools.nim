import std/[tables, endians, strutils]
import ../types
import ./trdutils

type
  TRDDiscType = enum
    TRD_DISC_80_2
    TRD_DISC_80_1
    TRD_DISC_40_2
    TRD_DISC_40_1
  
  TRDFile* = ref object of ZXFile
    startSector*: uint8
    startTrack*: uint8
    sectorCount*: uint8

  TRDImage* = ref object of ZXImage[TRDFile]
    lastTrack: uint8
    lastSector: uint8
    freeSectors: uint16
    discName: string
    discType: TRDDiscType
  

#[
    0x16: 80 tracks, double side
    80 track 2 sided image length is 655360 byte

    0x17: 40 tracks, double side
    40 track 2 sided image length is 327680 byte

    0x18: 80 tracks, single side
    80 track 1 sided image length is 327680 byte

    0x19: 40 tracks, single side
    40 track 1 sided image length is 163840 byte (1×40×16×256)
]#

const trdType80x2 = 0x16.byte
const trdType40x2 = 0x17.byte
const trdType80x1 = 0x18.byte
const trdType40x1 = 0x19.byte
const infosectorOffset = 8*256

let trdTypeMap = {
  TRD_DISC_80_2: trdType80x2,
  TRD_DISC_80_1: trdType80x1,
  TRD_DISC_40_2: trdType40x2,
  TRD_DISC_40_1: trdType40x1
}.toTable()

let trdTypeRevMap = {
  trdType80x2: TRD_DISC_80_2,
  trdType80x1: TRD_DISC_80_1,
  trdType40x2: TRD_DISC_40_2,
  trdType40x1: TRD_DISC_40_1
}.toTable()

let trdSettings = {
  TRD_DISC_80_2: (655360, 2560.uint),
  TRD_DISC_80_1: (327680, 1280.uint),
  TRD_DISC_40_2: (327680, 1280.uint),
  TRD_DISC_40_1: (163840, 640.uint)
}.toTable()


proc newTRD*(name: string = "", trdType: (int | TRDDiscType) = TRD_DISC_80_2): TRDImage =
  result.new
  when trdType is int:
    result.discType = trdTypeRevMap[trdType]
  else:
    result.discType = trdType
  result.discName = name.alignLeft(11)[0 .. 10]
  result.filesAmount = 0
  result.lastTrack = 1
  result.lastSector = 0
  result.freeSectors = uint16(trdSettings[result.discType][1] - 16*result.lastTrack.uint - result.lastSector)
  result.data = newSeq[byte](trdSettings[result.discType][0])
  result.name = name


proc newImg*(_:typedesc[TRDImage], name: string): TRDImage =
  result = newTRD(name)
  result.data[infosectorOffset+231] = 0x10.byte
  result.data[infosectorOffset+227] = trdTypeMap[result.discType]
  result.data[infosectorOffset+225] = result.lastSector 
  result.data[infosectorOffset+226] = result.lastTrack 
  result.data[infosectorOffset+228] = result.filesAmount 
  littleEndian16(result.data[infosectorOffset+229].addr, cast[ptr byte](result.freeSectors.addr))
  copyMem(result.data[infosectorOffset+245].addr, result.discName[0].addr, 11)


proc parseFile(data: openArray[byte]): TRDFile =
  result.new
  result.filename = newString(8)
  copyMem(result.filename[0].addr, data[0].addr, 8)
  result.extension = newString(1)
  result.extension[0] = cast[char](data[8])
  littleEndian16(cast[ptr byte](result.start.addr), data[9].addr)
  littleEndian16(cast[ptr byte](result.length.addr), data[11].addr)
  result.sectorCount = data[13]
  result.startSector = data[14]
  result.startTrack = data[15]
  let dataStart = result.startTrack*4096+result.startSector*256
  var realFileLength: uint16
  case result.extension.toLowerAscii()
  of "b":
    realFileLength = result.sectorCount*256.uint16
    result.ftype = ZXF_PROGRAMM
  of "d":
    realFileLength = result.sectorCount*256.uint16
    if data[9].and(0x01000000) > 0:
      result.ftype = ZXF_NUMBER_ARRAY
    else:
      result.ftype = ZXF_CHARACTER_ARRAY
  else:
    realFileLength = result.length
    result.ftype = ZXF_CODE
  result.offset = dataStart .. dataStart+realFileLength-1


proc open*(_: typedesc[TRDImage], data: openArray[byte]): TRDImage =
  if data[infosectorOffset+231] != 0x10:
    raise newException(ValueError, "Неизвестный формат диска")
  let discTypeRaw = data[infosectorOffset+227]
  if not trdTypeRevMap.hasKey(discTypeRaw):
    raise newException(ValueError, "Неизвестный формат диска")
  let discType = trdTypeRevMap[discTypeRaw]
  let imgSize = trdSettings[discType][0]
  if imgSize != data.len:
    raise newException(ValueError, "Неизвестный размер диска")
  result.new
  result.data = @data
  result.lastSector = data[infosectorOffset+225]
  result.lastTrack = data[infosectorOffset+226]
  result.discType = discType
  result.filesAmount = data[infosectorOffset+228]
  littleEndian16(cast[ptr byte](result.freeSectors.addr), data[infosectorOffset+229].addr)
  result.discName = newString(11)
  copyMem(result.discName[0].addr, data[infosectorOffset+245].addr, 11)
  var offset = 0
  while result.files.len < 128:
    result.files.add(parseFile(data[offset .. offset+15]))
    offset += 16


proc dumpFiles*(img: TRDImage) =
  echo img.name
  echo "Files: ", img.filesAmount
  echo "filename","\t","start","\t","length"
  for f in img.files:
    case f.filename[0]
    of 0x00.char:
      continue
    of 0x01.char:
      echo "DELETED"
    else:
      echo f.filename, ".", f.extension, "\t", f.start, "\t", f.length


proc getFile*(img: TRDImage, num: uint): ZXExportData =
  if num > img.filesAmount:
    raise newException(ValueError, "Номер файла слишком велик")
  let header = img.files[num]
  result = newExportData(header, img.data[header.offset])


proc updateHeader(img: TRDImage, f: TRDFile, no: uint) =
  let offset = no*16
  copyMem(img.data[offset].addr, f.filename[0].addr, 8)
  img.data[offset+8] = cast[byte](f.extension[0])
  littleEndian16(img.data[offset+9].addr, cast[ptr byte](f.start.addr))
  littleEndian16(img.data[offset+11].addr, cast[ptr byte](f.length.addr))
  img.data[offset+13] = f.sectorCount
  img.data[offset+14] = f.startSector
  img.data[offset+15] = f.startTrack 

proc addFile*(img: TRDImage, file: ZXExportData) =
  if img.filesAmount > 128:
    raise newException(IOError, "В каталоге недостаточно места")
  let realFileSize = roundToSize(file.data.len.uint)
  let sectorSize = realFileSize.div(256)
  if sectorSize > 255:
    raise newException(IOError, "Размер файла слишком велик")
  if img.freeSectors < sectorSize:
    raise newException(IOError, "На диске недостаточно места")
  var f = TRDFile()
  f.filename = file.header.filename.alignLeft(8)[0 .. 7]
  f.extension = file.header.extension
  f.start = file.header.start
  f.length = file.header.length
  f.ftype = file.header.ftype
  f.startTrack = img.lastTrack
  f.startSector = img.lastSector
  f.sectorCount = sectorSize.uint8
  let startOffset: uint = f.startTrack*16*256+f.startSector
  f.offset = startOffset .. startOffset+file.data.high.uint
  img.updateHeader(f, img.filesAmount)
  (img.lastTrack, img.lastSector) = addSectors(img.lastTrack, img.lastSector, sectorSize)
  img.data[f.offset] = file.data
  img.files.add(f)
  img.filesAmount.inc
  img.data[infosectorOffset+225] = img.lastSector
  img.data[infosectorOffset+226] = img.lastTrack
  img.data[infosectorOffset+228] = img.filesAmount
  littleEndian16(img.data[infosectorOffset+229].addr, cast[ptr byte](img.freeSectors.addr))


proc save*(img: TRDImage) =
  let file = open(img.name, fmWrite)
  defer:
    file.close()
  discard file.writeBytes(img.data, 0, img.data.len)
