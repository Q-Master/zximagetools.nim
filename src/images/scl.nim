import std/[tables, endians, strutils]
import ../types
import ./trdutils

type
  SCLFile* = ref object of ZXFile
    sectorCount: uint8

  SCLImage* = ref object of ZXImage[SCLFile]


const fileSignature = @['S'.byte,'I'.byte,'N'.byte,'C'.byte,'L'.byte,'A'.byte,'I'.byte,'R'.byte]


proc newSCL*(name: string): SCLImage =
  result.new
  result.name = name


proc newImg*(_:typedesc[SCLImage], name: string): SCLImage =
  result = newSCL(name)


proc parseFile(data: openArray[byte], dataStart: var uint): SCLFile =
  result.new
  result.filename = newString(8)
  copyMem(result.filename[0].addr, data[0].addr, 8)
  result.extension = newString(1)
  result.extension[0] = cast[char](data[8])
  littleEndian16(cast[ptr byte](result.start.addr), data[9].addr)
  littleEndian16(cast[ptr byte](result.length.addr), data[11].addr)
  result.sectorCount = data[13]
  result.offset = dataStart .. dataStart+result.length
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


proc addFile*(img: SCLImage, file: ZXExportData) =
  if img.filesAmount > 128:
    raise newException(IOError, "В каталоге недостаточно места")
  let realFileSize = roundToSize(file.data.len.uint)
  let sectorSize = realFileSize.div(256)
  if sectorSize > 255:
    raise newException(IOError, "Размер файла слишком велик")
  var f = SCLFile()
  f.filename = file.header.filename.alignLeft(8)[0 .. 8]
  f.extension = file.header.extension
  f.start = file.header.start
  f.length = file.header.length
  f.ftype = file.header.ftype
  f.sectorCount = sectorSize.uint8
  let startOffset: uint = img.data.high.uint
  f.offset = startOffset .. startOffset+realFileSize
  img.data.add(file.data)
  img.files.add(f)
  img.filesAmount.inc
