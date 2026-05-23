## Color parsing utilities and terminal color helpers.

import std/[strutils, sequtils, tables, terminal]

const namedColors* = {
  "red":     0xFF0000,
  "green":   0x00FF00,
  "blue":    0x0000FF,
  "white":   0xFFFFFF,
  "purple":  0xFF00FF,
  "cyan":    0x00FFFF,
  "yellow":  0xFFFF00,
  "orange":  0xFF8000,
  "pink":    0xFF69B4,
  "off":     0x000000,
}.toTable

proc parseColor*(s: string): int =
  ## Accepts: "0xFF0000", "#FF0000", "FF0000" (hex), named colors, or decimal ints.
  let s = s.strip()
  try:
    if s.startsWith("0x") or s.startsWith("0X"):
      result = fromHex[int](s[2..^1])
    elif s.startsWith("#"):
      result = fromHex[int](s[1..^1])
    elif s.toLowerAscii in namedColors:
      result = namedColors[s.toLowerAscii]
    else:
      result = parseInt(s)
  except ValueError:
    raise newException(ValueError,
      "invalid color \"" & s & "\": use hex (0xFF0000, #FF0000), a named color (" &
      toSeq(namedColors.keys).join(", ") & "), or a decimal integer")
  result = result and 0xFFFFFF

proc colorHex*(c: int): string =
  ## Returns color as "#RRGGBB" string.
  "#" & toHex(c and 0xFFFFFF, 6)

proc colorPreview*(c: int): string =
  ## Returns a terminal-colored block for visual preview (truecolor terminals).
  let r = (c shr 16) and 0xFF
  let g = (c shr 8)  and 0xFF
  let b =  c         and 0xFF
  "\e[38;2;" & $r & ";" & $g & ";" & $b & "m██\e[0m"

# ── styled output helpers ────────────────────────────────────────────────────

proc label*(s: string) =
  styledWrite(stdout, styleBright, fgWhite, s, resetStyle)

proc value*(s: string) =
  styledWriteLine(stdout, fgCyan, s, resetStyle)

proc heading*(s: string) =
  styledWriteLine(stdout, styleBright, fgGreen, s, resetStyle)

proc warn*(s: string) =
  styledWriteLine(stderr, fgYellow, "warning: " & s, resetStyle)

proc error*(s: string) =
  styledWriteLine(stderr, fgRed, "error: " & s, resetStyle)
