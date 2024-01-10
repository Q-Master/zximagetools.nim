import std/[parseopt, options, strutils, unicode]
import ../types
import ../images/[trd, scl, tap, hobeta]

proc echoHelp() =
  echo """
Usage:
  -i:image_filename
"""

proc main() =
  var imgname: Option[string]
  for kind, key, value in getopt():
    case kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case key
      of "i":
        imgname = value.option
      of "h", "help":
        echoHelp()
    of cmdArgument:
      echoHelp()
  if imgname.isSome:
    let fnameExt = imgname.get.rsplit(".", maxsplit=1)
    let ext = fnameExt[1].toLower()
    case ext
    of "trd":
      let img = TRDImage.open(imgname.get)
      img.dumpFiles()
    of "scl":
      let img = SCLImage.open(imgname.get)
      img.dumpFiles()
    of "tap":
      let img = TAPImage.open(imgname.get)
      img.dumpFiles()
    else:
      if ext.startsWith('$') or ext.startsWith('!'):
        let img = HOBETAImage.open(imgname.get)
        img.dumpFiles()
      else:
        raise newException(ValueError, "Неизвестный образ")

when isMainModule:
  main()
