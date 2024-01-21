func roundToSize*(size: uint, round: uint = 256): uint =
  let diff = size.mod(round)
  if diff > 0:
    size + round - diff
  else:
    size

func addSectors*(track: uint, sector: uint, additional_sectors: uint): (uint8, uint8) =
  let total_sectors = track * 16 + sector + additional_sectors
  let new_track = total_sectors.div(16)
  let new_sector = total_sectors.mod(16)
  result = (new_track.uint8, new_sector.uint8)
