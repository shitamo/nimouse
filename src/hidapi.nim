## Nim FFI bindings for the hidapi C library.
## Bundles a minimal hidapi header (hidapi_minimal.h) so libhidapi-dev headers
## are not required at compile time, but the shared library must be installed.
##
## Linux:   sudo apt install libhidapi-dev   (or pacman -S hidapi on Arch)
## macOS:   brew install hidapi
## Windows: grab the release DLL from github.com/libusb/hidapi/releases

import std/os

when defined(linux):
  # Link against the versioned .so directly since the -dev symlink may not be installed
  {.passL: "-L/usr/lib/x86_64-linux-gnu -l:libhidapi-hidraw.so.0".}
elif defined(macosx):
  {.passL: "-lhidapi".}
elif defined(windows):
  {.passL: "-lhidapi".}

# Point the C compiler at our bundled minimal header
{.passC: "-I" & currentSourcePath().splitPath.head.}

const hidapiHeader = "hidapi_minimal.h"

type
  HidDevice* {.importc: "hid_device",
               header: hidapiHeader.} = object

  HidDeviceInfo* {.importc: "struct hid_device_info",
                   header: hidapiHeader.} = object
    path*               {.importc.}: cstring
    vendor_id*          {.importc.}: cushort
    product_id*         {.importc.}: cushort
    serial_number       {.importc.}: pointer    ## wchar_t* — not used
    release_number      {.importc.}: cushort
    manufacturer_string {.importc.}: pointer    ## wchar_t* — not used
    product_string      {.importc.}: pointer    ## wchar_t* — not used
    usage_page*         {.importc.}: cushort
    usage*              {.importc.}: cushort
    interface_number*   {.importc.}: cint
    next*               {.importc.}: ptr HidDeviceInfo
    bus_type            {.importc.}: cint

proc hidInit*(): cint
  {.importc: "hid_init", header: hidapiHeader.}

proc hidExit*(): cint
  {.importc: "hid_exit", header: hidapiHeader.}

proc hidOpenPath*(path: cstring): ptr HidDevice
  {.importc: "hid_open_path", header: hidapiHeader.}

proc hidClose*(dev: ptr HidDevice)
  {.importc: "hid_close", header: hidapiHeader.}

proc hidEnumerate*(vid, pid: cushort): ptr HidDeviceInfo
  {.importc: "hid_enumerate", header: hidapiHeader.}

proc hidFreeEnumeration*(devs: ptr HidDeviceInfo)
  {.importc: "hid_free_enumeration", header: hidapiHeader.}

proc hidSendFeatureReport*(dev: ptr HidDevice, data: ptr uint8, length: csize_t): cint
  {.importc: "hid_send_feature_report", header: hidapiHeader.}

proc hidGetInputReport*(dev: ptr HidDevice, data: ptr uint8, length: csize_t): cint
  {.importc: "hid_get_input_report", header: hidapiHeader.}

proc hidError*(dev: ptr HidDevice): pointer
  {.importc: "hid_error", header: hidapiHeader.}
