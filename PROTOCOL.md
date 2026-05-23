# Microsoft Pro IntelliMouse — HID Protocol Reference

Reverse-engineered USB HID feature report protocol for the
**Microsoft Pro IntelliMouse** (USB VID `0x045E`, PID `0x082A`).

This document consolidates findings from:
- [xlanor/intellimouse](https://github.com/xlanor/intellimouse) — Go implementation with USB packet captures
- [namazso/ProIntelliColor](https://github.com/namazso/ProIntelliColor) — C LED color tool
- [k-visscher/intellimouse-ctl](https://github.com/k-visscher/intellimouse-ctl) — original Python library

---

## Device Identification

| Field          | Value    |
|----------------|----------|
| Vendor ID      | `0x045E` (Microsoft) |
| Product ID     | `0x082A` |
| Interface      | `0x01`   |
| Usage Page     | `0xFF07` (vendor-specific) |
| Usage          | `0x0212` |

---

## HID Transport

All configuration uses **HID Feature Reports** via `hid_send_feature_report` /
`hid_get_input_report` (hidapi). A ~50 ms sleep between operations is required
(the mouse needs time to process commands).

### Write (set a property)

```
Byte 0:      0x24          — write report ID
Byte 1:      PROP_CODE     — property being set
Byte 2:      DATA_LEN      — number of data bytes that follow
Bytes 3…:    DATA          — property-specific payload
…padded to 0x49 (73) bytes total with 0x00
```

Send with `hid_send_feature_report`.

### Read (get a property)

**Request** — same format as write, with `DATA_LEN = 0x01` and no data payload:

```
Byte 0:   0x24
Byte 1:   READ_PROP_CODE
Byte 2:   0x01
Bytes 3+: 0x00 …
```

**Response** — received via `hid_get_input_report` into a 0x29 (41) byte buffer:

```
Byte 0:   0x27          — read report ID
Byte 1:   READ_PROP_CODE
Byte 2:   (reserved)
Byte 3:   DATA_LEN      — number of valid data bytes
Bytes 4…: DATA          — property value
```

Extract: `data = response[4 : 4 + response[3]]`

---

## Property Codes

### DPI

| Direction | Code   |
|-----------|--------|
| Write     | `0x96` |
| Read      | `0x97` |

**Write payload** (2 bytes, little-endian uint16):

```
[DPI_LOW, DPI_HIGH]
```

Valid range: 200–16000, multiples of 50.

**Example** — set 1600 DPI (`0x0640`):

```
24 96 02 40 06 00 00 … (73 bytes)
```

**Read response** bytes 4–5: little-endian uint16.

---

### LED (Tail-light) Color

| Direction | Code   |
|-----------|--------|
| Write     | `0xB2` |
| Read      | `0xB3` |

**Write payload** (3 bytes, big-endian RGB):

```
[RED, GREEN, BLUE]
```

**Example** — set orange (`0xFF8000`):

```
24 B2 03 FF 80 00 00 … (73 bytes)
```

**Read response** bytes 4–6: `[RED, GREEN, BLUE]`.

Confirmed by namazso/ProIntelliColor and xlanor/intellimouse.

---

### Polling Rate

| Direction | Code   |
|-----------|--------|
| Write     | `0x83` |
| Read      | `0x84` |

**Write payload** (1 byte):

| Byte | Rate    |
|------|---------|
| `0x00` | 1000 Hz |
| `0x01` | 500 Hz  |
| `0x02` | 125 Hz  |

---

### Lift-Off Distance

| Direction | Code   |
|-----------|--------|
| Write     | `0xB8` |
| Read      | `0xB6` |

**Write payload** (1 byte):

| Byte   | Distance |
|--------|----------|
| `0x00` | 2 mm     |
| `0x01` | 3 mm     |

---

### Button Mapping

| Direction | Code   |
|-----------|--------|
| Write     | `0x88` |
| Read      | `0x89` |

Reverse-engineered by xlanor from USB packet captures of the Windows
"Mouse and Keyboard Center" software.

#### Physical Button IDs

| Button              | ID     |
|---------------------|--------|
| Back (large side)   | `0x04` |
| Middle (wheel click)| `0x03` |

#### Write payload (5 bytes)

```
[BUTTON_ID, ACTION_B3, ACTION_B2, ACTION_B1, ACTION_B0]
```

`ACTION` is a 4-byte big-endian code (see table below).

**Example** — set back button → browser forward:

```
24 88 05 04 09 00 01 05 00 … (73 bytes)
         ^^ ^^^^^^^^^^
         |  action = 0x09000105 (browserForward)
         button_id = 0x04 (back button)
```

#### Read request (special: includes button ID as data byte)

```
24 89 01 BUTTON_ID 00 … (73 bytes)
```

#### Read response bytes 4–8

```
[BUTTON_ID, ACTION_B3, ACTION_B2, ACTION_B1, ACTION_B0]
```

#### Known Action Codes

| Name                  | Code         | Description                    |
|-----------------------|--------------|--------------------------------|
| `actionBackButton`    | `0x09000104` | Browser back                   |
| `actionBrowserForward`| `0x09000105` | Browser forward                |
| `actionMiddleClick`   | `0x09000103` | Middle mouse button click      |
| `actionHorizVertToggle`| `0x09000203`| Toggle H/V scrolling           |
| `actionDpiShift`      | `0x09000204` | Hold for temporary DPI change  |
| `actionIncreaseDpi`   | `0x09000201` | Step DPI up                    |
| `actionDecreaseDpi`   | `0x09000202` | Step DPI down                  |
| `actionKeyCombination`| `0x09000200` | Key combination (see notes)    |
| `actionAlt`           | `0x07000000` | Alt keypress                   |
| `actionCtrl`          | `0x07100000` | Ctrl keypress                  |
| `actionShift`         | `0x07200000` | Shift keypress                 |
| `actionEnter`         | `0x07002800` | Enter keypress                 |

**Key combination encoding notes** (from xlanor reverse engineering):
The upper two bytes `0x0409` appear to be a namespace. Codes `0x0106`–`0x0200`
encode specific key combinations; the exact mapping to HID usage IDs has not
been fully documented. `0x09000200` resets to "no key combination".

---

## Not Yet Documented

- **Custom LOD surface calibration** — the Windows software allows per-surface
  calibration, but the USB protocol for this procedure has not been
  reverse-engineered.
- **Forward button** (`0x05`?) — the smaller forward side button ID is unconfirmed.
- **Key combination full encoding** — partial decode only.
- **Disable button** — the exact code to disable a button is unknown.

---

## References

| Source | Notes |
|--------|-------|
| [xlanor/intellimouse](https://github.com/xlanor/intellimouse) | Go app; `reverse_engineering/` has raw USB captures + README walkthroughs |
| [namazso/ProIntelliColor](https://github.com/namazso/ProIntelliColor) | Single-file C; independently confirms color protocol |
| [k-visscher/intellimouse-ctl](https://github.com/k-visscher/intellimouse-ctl) | Original Python; confirms DPI, color, polling, LOD |
| [badcel/Maus](https://github.com/badcel/Maus) | C# GUI; another independent implementation |
| [linux-hardware.org 045e:082a](https://linux-hardware.org/?id=usb:045e-082a) | Kernel driver info |
