import std/[os]

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
    filesAmount* : uint8
    files*: seq[T]
    data*: seq[byte]


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
    return T.open(data)
  else:
    raise newException(ValueError, "File is empty")
