## Classic IntelliMouse (2017) support: DPI only.

import intellimouse

const classicParams* = DeviceParams(
  vid:            0x045E,
  pid:            0x0823,
  iface:          1,
  usagePage:      0x000C,
  usage:          0x0001,
  writeReportId:  0x24,
  writeReportLen: 0x20,
  readReportId:   0x27,
  readReportLen:  0x20,
)

const
  ClassicDpiWriteProp = 0x96'u8
  ClassicDpiReadProp  = ClassicDpiWriteProp + 0x01

type ClassicIntelliMouse* = ref object of IntelliMouse

proc enumerate*(_: typedesc[ClassicIntelliMouse]): seq[ClassicIntelliMouse] =
  for path in enumeratePaths(classicParams):
    result.add ClassicIntelliMouse(params: classicParams, path: path)

method deviceName*(m: ClassicIntelliMouse): string = "Microsoft Classic IntelliMouse"

# ── DPI ──────────────────────────────────────────────────────────────────────

proc getDpi*(m: ClassicIntelliMouse): int =
  ## Returns DPI (400–3200, multiples of 200).
  # Response bytes: [skip, lo, hi, ...]
  let raw = m.readProperty(ClassicDpiReadProp)
  int(raw[1]) or (int(raw[2]) shl 8)  # skip raw[0], little-endian uint16

proc setDpi*(m: ClassicIntelliMouse, dpi: int) =
  ## Sets DPI. Must be a multiple of 200 in the range 400–3200.
  if dpi mod 200 != 0 or dpi notin 400..3200:
    raise newException(ValueError,
      "DPI must be a multiple of 200 in the range 400–3200, got " & $dpi)
  m.writeProperty(ClassicDpiWriteProp,
    [0x00'u8, uint8(dpi and 0xFF), uint8((dpi shr 8) and 0xFF)])

# ── unimplemented ─────────────────────────────────────────────────────────────

proc setButtonMapping*(m: ClassicIntelliMouse, mapping: openArray[int]) =
  ## TODO: custom button mapping — USB protocol not yet documented.
  raise newException(CatchableError,
    "button mapping is not yet implemented; the USB protocol has not been reverse-engineered")

# ── describe ─────────────────────────────────────────────────────────────────

method describe*(m: ClassicIntelliMouse): string =
  "dpi: " & $m.getDpi()
