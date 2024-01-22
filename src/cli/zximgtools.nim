import std/[parseopt, options]
import ../types
import ../images/[trd, scl, tap, hobeta]


proc echoHelp() =
  echo """
Usage:
  list (ls) image_filename - lists all files in image
  cp - copy file from one image to another
    might be used with paths like:
      src:
        image:/path - by name of the file in the image
        image:number - by ordinal number of the file in the source image
        just path - used to copy file into image as code
      dest:
        image - destination image name
        just path - user to export file as HOBETA
    e.x.
      cp myimage:/screen.c ./ - will export screen.c as a hobeta file
"""

proc echoError(cmd: string) =
  echo """
Error in """,cmd,""" command
  Refer to it's usage help"""


proc parseList(p: var OptParser) =
  var imgname: Option[string]
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      echoError("list")
      return
    of cmdShortOption, cmdLongOption:
      continue
    of cmdArgument:
      imgname = p.key.option
      break
  let img = parseImageInfo(imgname.get)
  case img.`type`:
  of ZXI_TRD:
    let img = TRDImage.open(img.name)
    img.dumpFiles()
  of ZXI_SCL:
    let img = SCLImage.open(img.name)
    img.dumpFiles()
  of ZXI_TAP:
    let img = TAPImage.open(img.name)
    img.dumpFiles()
  of ZXI_HOBETA:
    let img = HOBETAImage.open(img.name)
    img.dumpFiles()
  else:
    raise newException(ValueError, "Неизвестный образ")


proc parseCp(p: var OptParser) =
  var src: Option[string]
  var dest: Option[string]
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      if src.isSome and dest.isSome:
        break
      echoError("cp")
      return
    of cmdShortOption, cmdLongOption:
      continue
    of cmdArgument:
      if src.isNone:
        src = p.key.option
        echo "SRC: ", p.key
      elif dest.isNone:
        dest = p.key.option
        echo "DST: ", p.key
      else:
        break
  let srcImg = parseImageInfo(src.get)
  let destImg = parseImageInfo(dest.get)
  if srcImg.`type` == ZXI_NOTYPE and destImg.`type` == ZXI_NOTYPE:
    echoError("cp")
  else:
    var srcFile: ZXExportData
    case srcImg.`type`
    of ZXI_TRD:
      let img = TRDImage.open(srcImg.name)
      srcFile = img.getFile(srcImg.path)
    of ZXI_SCL:
      let img = SCLImage.open(srcImg.name)
      srcFile = img.getFile(srcImg.path)
    of ZXI_TAP:
      let img = TAPImage.open(srcImg.name)
      srcFile = img.getFile(srcImg.path)
    of ZXI_HOBETA:
      let img = HOBETAImage.open(srcImg.name)
      srcFile = img.getFile(0)
    of ZXI_NOTYPE:
      srcFile = openRaw(srcImg.name)
    case destImg.`type`
    of ZXI_TRD:
      let img = TRDImage.openOrCreate(destImg.name)
      img.addFile(srcFile)
      img.save()
    of ZXI_SCL:
      let img = SCLImage.openOrCreate(destImg.name)
      img.addFile(srcFile)
      img.save()
    of ZXI_TAP:
      let img = TAPImage.openOrCreate(destImg.name)
      img.addFile(srcFile)
      img.save()
    of ZXI_HOBETA, ZXI_NOTYPE:
      let img = newHOBETA(destImg.name)
      img.addFile(srcFile)
      img.save()

proc main() =
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "h", "help":
        echoHelp()
      else:
        echoHelp()
    of cmdArgument:
      case p.key
      of "list", "ls":
        parseList(p)
        break
      of "cp":
        parseCp(p)
        break
      else:
        echoHelp()

when isMainModule:
  main()
