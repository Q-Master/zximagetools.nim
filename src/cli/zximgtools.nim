import std/[parseopt, options, strutils, unicode]
import ../types
import ../images/[trd, scl, tap]

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
    var fnameExt = imgname.get.rsplit(".", maxsplit=1)
    case fnameExt[1].toLower()
    of "trd":
      let img = TRDImage.open(imgname.get)
      img.dumpFiles()
    of "scl":
      let img = SCLImage.open(imgname.get)
      img.dumpFiles()
    of "tap":
      let img = TAPImage.open(imgname.get)
      img.dumpFiles()


when isMainModule:
  main()
