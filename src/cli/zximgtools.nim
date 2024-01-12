import std/[parseopt, options, strutils, unicode]
import ../types
import ../images/[trd, scl, tap, hobeta]

proc echoHelp() =
  echo """
Usage:
  list image_filename - lists all files in image
  cp - copy file from one image to another
    might be used with paths like:
      image:/path - by name of the file in the image
      image:number - by ordinal number of the file in the source image
      just path - used to copy file into image as code or export file as HOBETA
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


proc parseCp(p: var OptParser) =
  var src: Option[string]
  var dest: Option[string]
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      echoError("cp")
      return
    of cmdShortOption, cmdLongOption:
      continue
    of cmdArgument:
      if src.isNone:
        src = p.key.option
      elif dest.isNone:
        dest = p.key.option
      else:
        break


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
      of "list":
        parseList(p)
        break
      of "cp":
        parseCp(p)
        break
      else:
        echoHelp()

when isMainModule:
  main()
