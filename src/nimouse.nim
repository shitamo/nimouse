## nimouse — CLI for Microsoft IntelliMouse devices.
## Usage:
##   nimouse list
##   nimouse get <index> [--dpi] [--color] [--polling-rate] [--lift-off-distance]
##                       [--back-button] [--middle-button] [--all]
##   nimouse set <index> [--dpi=N] [--color=COLOR] [--polling-rate=N]
##                       [--lift-off-distance=N] [--back-button=ACTION]
##                       [--middle-button=ACTION]
##   nimouse button-actions
##   nimouse config-save [--index=N]
##   nimouse config-load [--index=N]
##
## Shell completion:  source <(nimouse --help-syntax bash)

import std/[json, strutils, sequtils, terminal]
import cligen
import intellimouse, pro_intellimouse, classic_intellimouse, config, colors

# ── helpers ──────────────────────────────────────────────────────────────────

proc allDevices(): seq[IntelliMouse] =
  ProIntelliMouse.enumerate().mapIt(IntelliMouse(it)) &
  ClassicIntelliMouse.enumerate().mapIt(IntelliMouse(it))

proc deviceAt(index: int): IntelliMouse =
  let devs = allDevices()
  if devs.len == 0:
    error "no IntelliMouse devices found"
    quit 1
  if index notin 0 ..< devs.len:
    error "device index " & $index & " out of range (found " & $devs.len & " device(s))"
    quit 1
  devs[index]

# ── list ─────────────────────────────────────────────────────────────────────

proc list(json = false): int =
  ## List connected IntelliMouse devices and their indices.
  let devs = allDevices()
  if json:
    var arr = newJArray()
    for i, d in devs:
      arr.add(%*{"index": i, "name": d.deviceName(), "path": d.path})
    echo arr.pretty()
    return 0
  if devs.len == 0:
    warn "no IntelliMouse devices found"
    return 1
  for i, d in devs:
    styledWrite(stdout, styleBright, fgCyan, $i, resetStyle)
    stdout.write(". ")
    heading d.deviceName()
    stdout.writeLine("   path: " & d.path)
  0

# ── get ───────────────────────────────────────────────────────────────────────

proc get(index = 0,
         dpi             = false,
         color           = false,
         pollingRate     = false,
         liftOffDistance = false,
         backButton      = false,
         middleButton    = false,
         all             = false,
         json            = false): int =
  ## Get settings from a device.
  ## Pass --all to read every supported setting (default when no flags given).
  let anyFlag = dpi or color or pollingRate or liftOffDistance or backButton or middleButton
  let showAll = all or not anyFlag
  let d = deviceAt(index)
  d.open()
  defer: d.close()

  var results: seq[(string, string)]

  if d of ProIntelliMouse:
    let m = ProIntelliMouse(d)
    if showAll or dpi:
      results.add ("dpi", $m.getDpi())
    if showAll or color:
      let c = m.getColor()
      results.add ("color", colorHex(c) & "  " & colorPreview(c))
    if showAll or pollingRate:
      results.add ("polling rate", $m.getPollingRate() & " Hz")
    if showAll or liftOffDistance:
      results.add ("lift-off distance", $m.getLiftOffDistance() & " mm")
    if showAll or backButton:
      results.add ("back button", $m.getButtonAction(ProButton.backButton))
    if showAll or middleButton:
      results.add ("middle button", $m.getButtonAction(ProButton.middleButton))

  elif d of ClassicIntelliMouse:
    let m = ClassicIntelliMouse(d)
    if showAll or dpi:
      results.add ("dpi", $m.getDpi())
    if color or pollingRate or liftOffDistance or backButton or middleButton:
      warn "Classic IntelliMouse only supports --dpi"

  if json:
    var obj = newJObject()
    for (k, v) in results:
      let clean = v.split("  ")[0]  # strip ANSI color preview
      obj[k.replace(" ", "_")] = %clean
    echo obj.pretty()
  else:
    heading d.deviceName() & ":"
    for (k, v) in results:
      label "  " & k & ": "
      value v
  0

# ── set ───────────────────────────────────────────────────────────────────────

proc parseButtonAction(s: string): ButtonAction =
  ## Parses a button action name (case-insensitive, underscores/hyphens ignored).
  ## Run `nimouse button-actions` to list all valid names.
  let norm = s.toLowerAscii.replace("-", "").replace("_", "")
  for a in ButtonAction:
    if ($a).toLowerAscii.replace("action", "") == norm or
       ($a).toLowerAscii == norm:
      return a
  raise newException(ValueError,
    "unknown button action \"" & s & "\". Run `nimouse button-actions` to list valid names.")

proc setSettings(index = 0,
         dpi              = -1,
         color            = "",
         pollingRate      = -1,
         liftOffDistance  = -1,
         backButton       = "",
         middleButton     = ""): int =
  ## Set one or more settings on a device.
  ## COLOR: hex (0xFF0000, #FF0000), named (red green blue white purple cyan
  ##        yellow orange pink off), or decimal.
  ## BACK-BUTTON / MIDDLE-BUTTON: action name — run `nimouse button-actions`
  ##        to list all valid values (e.g. browserForward, dpiShift, middleClick).
  let d = deviceAt(index)
  d.open()
  defer: d.close()
  var changed = 0

  if d of ProIntelliMouse:
    let m = ProIntelliMouse(d)
    if dpi != -1:
      m.setDpi(dpi); inc changed
    if color != "":
      m.setColor(parseColor(color)); inc changed
    if pollingRate != -1:
      m.setPollingRate(pollingRate); inc changed
    if liftOffDistance != -1:
      m.setLiftOffDistance(liftOffDistance); inc changed
    if backButton != "":
      m.setButtonAction(ProButton.backButton, parseButtonAction(backButton)); inc changed
    if middleButton != "":
      m.setButtonAction(ProButton.middleButton, parseButtonAction(middleButton)); inc changed

  elif d of ClassicIntelliMouse:
    let m = ClassicIntelliMouse(d)
    if dpi != -1:
      m.setDpi(dpi); inc changed
    if color != "" or pollingRate != -1 or liftOffDistance != -1 or
       backButton != "" or middleButton != "":
      warn "Classic IntelliMouse only supports --dpi; other flags ignored"

  if changed == 0:
    warn "no settings specified — nothing changed"
    return 1
  0

# ── button-actions ────────────────────────────────────────────────────────────

proc buttonActions(): int =
  ## List all valid button action names for use with --back-button / --middle-button.
  heading "Available button actions:"
  for a in ButtonAction:
    label "  "
    value ($a).replace("action", "")
  0

# ── config-save ───────────────────────────────────────────────────────────────

proc configSave(index = 0): int =
  ## Read current settings from a device and save them to ~/.config/nimouse/config.ini.
  let d = deviceAt(index)
  d.open()
  defer: d.close()

  var cfg = loadConfig()
  cfg.defaultIndex = index

  if d of ProIntelliMouse:
    let m = ProIntelliMouse(d)
    cfg.proDpi             = m.getDpi()
    cfg.proPollingRate     = m.getPollingRate()
    cfg.proLiftOffDistance = m.getLiftOffDistance()
    cfg.proColor           = m.getColor()
  elif d of ClassicIntelliMouse:
    cfg.classicDpi = ClassicIntelliMouse(d).getDpi()

  saveConfig(cfg)
  let path = configPath()
  heading "saved to " & path
  0

# ── config-load ───────────────────────────────────────────────────────────────

proc configLoad(index = 0): int =
  ## Apply saved config settings to a device.
  let cfg = loadConfig()
  let idx  = if index == 0: cfg.defaultIndex else: index
  let d = deviceAt(idx)
  d.open()
  defer: d.close()
  var applied = 0

  if d of ProIntelliMouse:
    let m = ProIntelliMouse(d)
    m.setDpi(cfg.proDpi);                   inc applied
    m.setPollingRate(cfg.proPollingRate);    inc applied
    m.setLiftOffDistance(cfg.proLiftOffDistance); inc applied
    m.setColor(cfg.proColor);               inc applied
  elif d of ClassicIntelliMouse:
    ClassicIntelliMouse(d).setDpi(cfg.classicDpi); inc applied

  heading $applied & " setting(s) applied from " & configPath()
  0

# ── dispatch ──────────────────────────────────────────────────────────────────

when isMainModule:
  dispatchMulti(
    [list,          doc = "list connected devices and their indices"],
    [get,           doc = "get settings from a device"],
    [setSettings,   cmdName = "set", doc = "set settings on a device"],
    [buttonActions, cmdName = "button-actions",
                    doc = "list valid action names for --back-button / --middle-button"],
    [configSave,    cmdName = "config-save",
                    doc = "save current device settings to ~/.config/nimouse/config.ini"],
    [configLoad,    cmdName = "config-load",
                    doc = "apply saved settings from ~/.config/nimouse/config.ini to a device"],
  )
