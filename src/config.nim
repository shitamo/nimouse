## Persistent configuration (~/.config/nimouse/config.ini).
## Stores per-device defaults so settings can be saved and restored.

import std/[os, parsecfg, strutils, strformat]

type
  IntelliMouseConfig* = object
    defaultIndex*:        int   ## device index used when --index is omitted
    proDpi*:              int
    proPollingRate*:      int   ## Hz: 125, 500, or 1000
    proLiftOffDistance*:  int   ## mm: 2 or 3
    proColor*:            int   ## packed 24-bit RGB
    classicDpi*:          int

const defaults* = IntelliMouseConfig(
  defaultIndex:        0,
  proDpi:              800,
  proPollingRate:      1000,
  proLiftOffDistance:  2,
  proColor:            0xFFFFFF,
  classicDpi:          1600,
)

proc configPath*(): string =
  let base = getEnv("XDG_CONFIG_HOME",
                    getHomeDir() / ".config")
  base / "nimouse" / "config.ini"

proc getInt(cfg: parsecfg.Config, section, key: string, fallback: int): int =
  let s = cfg.getSectionValue(section, key, $fallback)
  try: parseInt(s)
  except ValueError: fallback

proc loadConfig*(): IntelliMouseConfig =
  result = defaults
  let path = configPath()
  if not fileExists(path): return
  let cfg = parsecfg.loadConfig(path)
  result.defaultIndex       = cfg.getInt("defaults", "index",              defaults.defaultIndex)
  result.proDpi             = cfg.getInt("pro",      "dpi",                defaults.proDpi)
  result.proPollingRate     = cfg.getInt("pro",      "polling_rate",        defaults.proPollingRate)
  result.proLiftOffDistance = cfg.getInt("pro",      "lift_off_distance",   defaults.proLiftOffDistance)
  result.proColor           = cfg.getInt("pro",      "color",               defaults.proColor)
  result.classicDpi         = cfg.getInt("classic",  "dpi",                 defaults.classicDpi)

proc saveConfig*(cfg: IntelliMouseConfig) =
  let path = configPath()
  createDir(path.parentDir())
  let content = &"""
[defaults]
index = {cfg.defaultIndex}

[pro]
dpi = {cfg.proDpi}
polling_rate = {cfg.proPollingRate}
lift_off_distance = {cfg.proLiftOffDistance}
color = {cfg.proColor}

[classic]
dpi = {cfg.classicDpi}
"""
  writeFile(path, content)
