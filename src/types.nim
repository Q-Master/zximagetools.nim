import std/[os, strutils, sequtils]

type
  ZXFileType* = enum
    ZXF_PROGRAMM = 0
    ZXF_NUMBER_ARRAY = 1
    ZXF_CHARACTER_ARRAY = 2
    ZXF_CODE = 3

  ZXFile* {.inheritable.} = ref object
    offset*: HSlice[uint, uint]
    ftype*: ZXFileType
    filename*: string
    extension*: string
    start*: uint16
    length*: uint16

  ZXImage*[T] {.inheritable.} = ref object
    name*: string
    filesAmount* : uint8
    files*: seq[T]
    data*: seq[byte]
  
  ZXExportData* = ref object
    header*: ZXFile
    data*: seq[byte]
  
  ZXImageType* = enum
    ZXI_NOTYPE
    ZXI_TRD
    ZXI_SCL
    ZXI_TAP
    ZXI_HOBETA

  ZXImagePathType* = enum
    ZXIP_STRING
    ZXIP_NUM

  ZXImagePath* = ref object
    case pathType*: ZXImagePathType
    of ZXIP_STRING:
      path*: string
    of ZXIP_NUM:
      num*: uint

  ZXImageInfo* = ref object
    `type`*: ZXImageType
    name*: string
    path*: ZXImagePath



proc open*[T](_: typedesc[T], filename: string): T =
  let file = open(filename, fmRead)
  defer:
    file.close()
  mixin open
  let size = file.getFileSize()
  if size > 0:
    var data = newSeq[byte](size)
    var currSize = size
    while currSize > 0:
      currSize -= file.readBytes(data, size-currSize, currSize)
    result = T.open(data)
    result.name = filename
  else:
    raise newException(IOError, "File is empty")


proc openOrCreate*[T](_: typedesc[T], filename: string): T =
  mixin newImg
  try:
    result = T.open(filename)
  except IOError:
    result = T.newImg(filename)


proc openRAW*(filename: string): ZXExportData =
  let file = open(filename, fmRead)
  defer:
    file.close()
  let size = file.getFileSize()
  if size > 0 and size < 65536:
    var data = newSeq[byte](size)
    var currSize = size
    while currSize > 0:
      currSize -= file.readBytes(data, size-currSize, currSize)
    let fnameExt = filename.rsplit(".", maxsplit=1)
    result.data = data
    result.header.ftype = ZXF_CODE
    result.header.filename = fnameExt[0]
    result.header.extension = fnameExt[1][0 .. 0]
    result.header.start = 0
    result.header.length = size.uint16
    result.header.offset = 0.uint .. size.uint-1
  else:
    raise newException(IOError, "File is too big")


proc getFile*[T](img: T, name: string): ZXExportData =
  mixin getFile
  var i: uint = 0
  for f in img.files:
    let fname = f.filename.strip(leading = false) & "." & f.extension
    if fname == name:
      return img.getFile(i)
    i.inc()
  raise newException(ValueError, "Файл с именем " & name & " отсутствует")


proc getFile*[T](img: T, path: ZXImagePath): ZXExportData =
  mixin getFile
  case path.pathType
  of ZXIP_NUM:
    return getFile(img, path.num)
  of ZXIP_STRING:
    return getFile(img, path.path)


proc newExportData*(header: ZXFile, data: openArray[byte]): ZXExportData =
  result.new
  result.header = header
  result.data = @data


proc parseImageInfo*(imgname: string): ZXImageInfo =
  result.new
  var hasDash = false
  when defined(windows):
    hasDash = imgname.find(":", 2)
  else:
    hasDash = ':' in imgname
  if hasDash:
    let namePath = imgname.rsplit(":", maxsplit=1)
    result.name = namePath[0]
    let path = namePath[1].strip()
    if all(path, isDigit):
      result.path = ZXImagePath(pathType: ZXIP_NUM, num: parseBiggestUInt(path))
    else:
      result.path = ZXImagePath(pathType: ZXIP_STRING, path: path)
  else:
    result.name = imgname
  let fnameExt = result.name.rsplit(".", maxsplit=1)
  let ext = fnameExt[1].toLower()
  case ext
  of "trd":
    result.`type` = ZXI_TRD
  of "scl":
    result.`type` = ZXI_SCL
  of "tap":
    result.`type` = ZXI_TAP
  else:
    if ext.startsWith('$') or ext.startsWith('!'):
      result.`type` = ZXI_HOBETA
    else:
      result.`type` = ZXI_NOTYPE
