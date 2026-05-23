## Pro IntelliMouse (2019) support: DPI, LED color, polling rate, lift-off distance.

import std/strutils
import intellimouse

const proParams* = DeviceParams(
  vid:            0x045E,
  pid:            0x082A,
  iface:          1,
  usagePage:      0xFF07,
  usage:          0x0212,
  writeReportId:  0x24,
  writeReportLen: 0x49,
  readReportId:   0x27,
  readReportLen:  0x29,
)

# HID property codes (reverse-engineered from xlanor/intellimouse and namazso/ProIntelliColor)
const
  ProDistanceWriteProp = 0xB8'u8
  ProDistanceReadProp  = ProDistanceWriteProp - 0x02
  ProPollingWriteProp  = 0x83'u8
  ProPollingReadProp   = ProPollingWriteProp + 0x01
  ProColorWriteProp    = 0xB2'u8
  ProColorReadProp     = ProColorWriteProp + 0x01
  ProButtonWriteProp   = 0x88'u8
  ProButtonReadProp    = ProButtonWriteProp + 0x01
  ProDpiWriteProp      = 0x96'u8
  ProDpiReadProp       = ProDpiWriteProp + 0x01

const
  pollingEncoding  = [(0x02'u8, 125), (0x01'u8, 500), (0x00'u8, 1000)]
  distanceEncoding = [(0x00'u8, 2),   (0x01'u8, 3)]

type
  ProButton* = enum
    ## Physical button that can be remapped on the Pro IntelliMouse.
    ## Byte IDs are from USB packet captures (xlanor/intellimouse reverse engineering).
    backButton   = 0x04  ## large thumb button, left side (default: browser back)
    middleButton = 0x03  ## scroll-wheel click (default: middle click)

  ButtonAction* = enum
    ## Action to assign to a remappable button.
    ## Protocol codes are in buttonActionCode[]. Source: xlanor/intellimouse.
    actionBackButton       ## browser back navigation
    actionBrowserForward   ## browser forward navigation
    actionMiddleClick      ## middle mouse button click
    actionHorizVertToggle  ## toggle horizontal/vertical scrolling
    actionDpiShift         ## hold for temporary DPI change
    actionIncreaseDpi      ## step DPI up
    actionDecreaseDpi      ## step DPI down
    actionKeyCombination   ## key combination
    actionAlt              ## send Alt keypress
    actionCtrl             ## send Ctrl keypress
    actionShift            ## send Shift keypress
    actionEnter            ## send Enter keypress

## Maps each ButtonAction to its 4-byte big-endian HID protocol code.
const buttonActionCode*: array[ButtonAction, uint32] = [
  0x09000104'u32,  # actionBackButton
  0x09000105'u32,  # actionBrowserForward
  0x09000103'u32,  # actionMiddleClick
  0x09000203'u32,  # actionHorizVertToggle
  0x09000204'u32,  # actionDpiShift
  0x09000201'u32,  # actionIncreaseDpi
  0x09000202'u32,  # actionDecreaseDpi
  0x09000200'u32,  # actionKeyCombination
  0x07000000'u32,  # actionAlt
  0x07100000'u32,  # actionCtrl
  0x07200000'u32,  # actionShift
  0x07002800'u32,  # actionEnter
]

type ProIntelliMouse* = ref object of IntelliMouse

proc enumerate*(_: typedesc[ProIntelliMouse]): seq[ProIntelliMouse] =
  for path in enumeratePaths(proParams):
    result.add ProIntelliMouse(params: proParams, path: path)

method deviceName*(m: ProIntelliMouse): string = "Microsoft Pro IntelliMouse"

# ── DPI ──────────────────────────────────────────────────────────────────────

proc getDpi*(m: ProIntelliMouse): int =
  ## Returns DPI (200–16000, multiples of 50).
  let raw = m.readProperty(ProDpiReadProp)
  int(raw[0]) or (int(raw[1]) shl 8)  # little-endian uint16

proc setDpi*(m: ProIntelliMouse, dpi: int) =
  ## Sets DPI. Must be a multiple of 50 in the range 200–16000.
  if dpi mod 50 != 0 or dpi notin 200..16000:
    raise newException(ValueError,
      "DPI must be a multiple of 50 in the range 200–16000, got " & $dpi)
  m.writeProperty(ProDpiWriteProp, [uint8(dpi and 0xFF), uint8((dpi shr 8) and 0xFF)])

# ── LED color ────────────────────────────────────────────────────────────────

proc getColor*(m: ProIntelliMouse): int =
  ## Returns the tail-light color as a packed 24-bit RGB integer.
  let raw = m.readProperty(ProColorReadProp)
  (int(raw[0]) shl 16) or (int(raw[1]) shl 8) or int(raw[2])

proc setColor*(m: ProIntelliMouse, color: int) =
  ## Sets the tail-light color. Accepts a packed 24-bit RGB integer.
  let c = color and 0xFFFFFF
  m.writeProperty(ProColorWriteProp,
    [uint8((c shr 16) and 0xFF), uint8((c shr 8) and 0xFF), uint8(c and 0xFF)])

# ── polling rate ─────────────────────────────────────────────────────────────

proc getPollingRate*(m: ProIntelliMouse): int =
  ## Returns the polling rate in Hz (125, 500, or 1000).
  let code = m.readProperty(ProPollingReadProp)[0]
  for (enc, hz) in pollingEncoding:
    if enc == code: return hz
  raise newException(IOError, "unknown polling rate code: " & $code)

proc setPollingRate*(m: ProIntelliMouse, rate: int) =
  ## Sets the polling rate. Must be 125, 500, or 1000 Hz.
  if rate notin [125, 500, 1000]:
    raise newException(ValueError,
      "polling rate must be 125, 500, or 1000 Hz, got " & $rate)
  for (enc, hz) in pollingEncoding:
    if hz == rate:
      m.writeProperty(ProPollingWriteProp, [enc])
      return

# ── lift-off distance ─────────────────────────────────────────────────────────

proc getLiftOffDistance*(m: ProIntelliMouse): int =
  ## Returns the lift-off distance in mm (2 or 3).
  let code = m.readProperty(ProDistanceReadProp)[0]
  for (enc, mm) in distanceEncoding:
    if enc == code: return mm
  raise newException(IOError, "unknown lift-off distance code: " & $code)

proc setLiftOffDistance*(m: ProIntelliMouse, mm: int) =
  ## Sets the lift-off distance. Must be 2 or 3 mm.
  if mm notin [2, 3]:
    raise newException(ValueError,
      "lift-off distance must be 2 or 3 mm, got " & $mm)
  for (enc, dist) in distanceEncoding:
    if dist == mm:
      m.writeProperty(ProDistanceWriteProp, [enc])
      return

# ── button mapping ───────────────────────────────────────────────────────────
# Protocol reverse-engineered by xlanor (github.com/xlanor/intellimouse).
# Write: [0x24, 0x88, 0x05, button_id, action_b3, action_b2, action_b1, action_b0, ...]
# Read:  send [0x24, 0x89, 0x01, button_id, ...]
#        response bytes [4..8]: [button_id, action_b3, action_b2, action_b1, action_b0]

proc getButtonAction*(m: ProIntelliMouse, button: ProButton): ButtonAction =
  ## Returns the action currently assigned to the given physical button.
  let raw = m.readProperty(ProButtonReadProp, [uint8(ord(button))])
  if raw.len < 5:
    raise newException(IOError, "unexpected response length reading button mapping")
  let code = (uint32(raw[1]) shl 24) or (uint32(raw[2]) shl 16) or
             (uint32(raw[3]) shl 8)  or  uint32(raw[4])
  for action in ButtonAction:
    if buttonActionCode[action] == code: return action
  raise newException(IOError, "unknown button action code: 0x" & toHex(int(code), 8))

proc setButtonAction*(m: ProIntelliMouse, button: ProButton, action: ButtonAction) =
  ## Assigns an action to a physical button.
  let code = buttonActionCode[action]
  m.writeProperty(ProButtonWriteProp, [
    uint8(ord(button)),
    uint8((code shr 24) and 0xFF),
    uint8((code shr 16) and 0xFF),
    uint8((code shr 8)  and 0xFF),
    uint8( code         and 0xFF),
  ])

# ── surface LOD calibration (protocol unknown) ────────────────────────────────

proc calibrateLiftOff*(m: ProIntelliMouse) =
  ## Custom per-surface LOD calibration — USB protocol not yet documented.
  raise newException(CatchableError,
    "LOD calibration protocol has not been reverse-engineered; " &
    "use set --lift-off-distance to set 2 or 3 mm instead")

# ── describe ─────────────────────────────────────────────────────────────────

method describe*(m: ProIntelliMouse): string =
  "color:             0x" & toHex(m.getColor(), 6) & "\n" &
  "dpi:               " & $m.getDpi() & "\n" &
  "polling rate:      " & $m.getPollingRate() & " Hz\n" &
  "lift-off distance: " & $m.getLiftOffDistance() & " mm\n" &
  "back button:       " & $m.getButtonAction(backButton) & "\n" &
  "middle button:     " & $m.getButtonAction(middleButton)
