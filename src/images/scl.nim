import std/[tables, endians]
import ../types

type
  SCLFile* = ref object of ZXFile
    sectorCount: uint8

  SCLImage* = ref object of ZXImage[SCLFile]


const fileSignature = @['S'.byte,'I'.byte,'N'.byte,'C'.byte,'L'.byte,'A'.byte,'I'.byte,'R'.byte]

proc newSCL*(): SCLImage =
  result.new


proc parseFile(data: openArray[byte], dataStart: var uint): SCLFile =
  result.new
  result.filename = newString(8)
  copyMem(result.filename[0].addr, data[0].addr, 8)
  result.extension = newString(1)
  result.extension[0] = cast[char](data[8])
  littleEndian16(cast[ptr byte](result.start.addr), data[9].addr)
  littleEndian16(cast[ptr byte](result.length.addr), data[11].addr)
  result.sectorCount = data[13]
  result.offset = dataStart .. dataStart+result.sectorCount*256
  dataStart += result.sectorCount*256


proc open*(_: typedesc[SCLImage], data: openArray[byte]): SCLImage =
  if data[0 .. 7] != fileSignature:
    raise newException(ValueError, "Неизвестный формат диска")
  result.new
  result.data = @data
  result.filesAmount = data[8]
  var offset = 9.uint
  var dataStart = result.filesAmount.uint*14+offset
  while result.files.len < result.filesAmount.int:
    result.files.add(parseFile(data[offset .. offset+13], dataStart))
    offset += 14


proc dumpFiles*(img: SCLImage) =
  echo "filename","\t","start","\t","length"
  for f in img.files:
    echo f.filename, ".", f.extension, "\t", f.start, "\t", f.length


proc getFile*(img: SCLImage, num: uint): ZXExportData =
  if num > img.filesAmount:
    raise newException(ValueError, "Номер файла слишком велик")
  let header = img.files[num]
  result = newExportData(header, img.data[header.offset])
