import std/[tables, endians]
import ../types

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
  TRD_DISC_80_2: (655360, 2560),
  TRD_DISC_80_1: (327680, 1280),
  TRD_DISC_40_2: (327680, 1280),
  TRD_DISC_40_1: (163840, 640)
}.toTable()


proc newTRD*(trdType: (int | TRDDiscType) = TRD_DISC_80_2, name: string = ""): TRDImage =
  result.new
  when trdType is int:
    result.discType = trdTypeRevMap[trdType]
  else:
    result.discType = trdType
  result.discName = name
  result.filesAmount = 0
  result.lastTrack = 1
  result.lastSector = 0
  result.freeSectors = trdSettings[result.disk_type][1] - 16*result.lastTrack - result.lastSector
  result.data = newSeq[byte](trdSettings[result.disk_type][0])


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
  result.offset = dataStart .. dataStart+result.sectorCount*256


proc open*(_: typedesc[TRDImage], data: openArray[byte]): TRDImage =
  let infosectorOffset = 8*256
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
    result.files.add(parseFile(data[offset .. offset+16]))
    offset += 16


proc dumpFiles*(img: TRDImage) =
  echo "filename","\t","start","\t","length"
  for f in img.files:
    case f.filename[0]
    of 0x00.char:
      continue
    of 0x01.char:
      echo "DELETED"
    else:
      echo f.filename, ".", f.extension, "\t", f.start, "\t", f.length
