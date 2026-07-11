# Protocol and API research

Research date: **2026-07-11**

## Synapse and public APIs

No documented Razer Synapse 3 or Synapse 4 command-line interface or public API
was found for DPI, polling, button mapping, HyperShift, onboard settings, or
battery telemetry. Razer's public developer surface is the Chroma SDK, which is
for lighting effects rather than device configuration. The Pro Click Mini has
no Chroma lighting, so that SDK does not provide a useful integration path.

The configurator does not automate the Synapse UI or call undocumented Synapse
services. Both approaches would be brittle across updates. It uses Windows HID
feature reports directly instead.

## Verified device interface

| Field | Value |
| --- | --- |
| USB vendor ID | `0x1532` |
| Receiver product ID | `0x009A` |
| Windows collection | `MI_00`, usage page `0x01`, usage `0x02` |
| Feature report ID | `0x00` |
| Feature report payload | 90 bytes, plus the Windows report-ID byte |
| Device transaction ID | `0x1F` |

Only receiver mode is targeted. There is no wired data mode on this AA-powered
mouse, and no Bluetooth vendor-feature path has been verified.

## Report layout

The 90-byte report used by OpenRazer and independently exercised against the
receiver is:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 1 | Status |
| 1 | 1 | Transaction ID |
| 2 | 2 | Remaining packets, big-endian |
| 4 | 1 | Protocol type |
| 5 | 1 | Argument size |
| 6 | 1 | Command class |
| 7 | 1 | Command ID |
| 8 | 80 | Arguments |
| 88 | 1 | XOR checksum of bytes 2 through 87 |
| 89 | 1 | Reserved |

Windows `HidD_SetFeature` and `HidD_GetFeature` receive a 91-byte buffer whose
first byte is report ID `0x00`. Mouse collections can reject a read/write
`CreateFile`; opening with zero desired access still permits feature reports,
which is the fallback used by this project.

## Implemented commands

| Operation | Class | Get | Set | Argument notes |
| --- | ---: | ---: | ---: | --- |
| Current DPI X/Y | `0x04` | `0x85` | `0x05` | 7-byte payload, variable store `0x01` |
| DPI stages | `0x04` | `0x86` | `0x06` | 38-byte payload, one to five stages |
| Polling rate | `0x00` | `0x85` | `0x05` | `01`=1000, `02`=500, `08`=125 Hz |
| Battery level | `0x07` | `0x80` | - | Raw level in argument 1, scaled from 0-255 |
| Charging state | `0x07` | `0x84` | - | Receiver firmware reports unsupported on this AA mouse |
| Idle timeout | `0x07` | `0x83` | `0x03` | Big-endian seconds, 60-900 |
| Low-battery threshold | `0x07` | `0x81` | `0x01` | Raw fraction of 255, constrained to 5-25% |
| Firmware version | `0x00` | `0x81` | - | Major and minor bytes |
| Button assignment | `0x02` | `0x8C` | `0x0C` | Profile, button, layer, function, and up to five data bytes |

The receiver returns status `0x04` when the mouse radio is asleep. The app
retries and then asks the user to wake the mouse rather than treating the
receiver as absent.

## Button mappings and HyperShift

OpenRazer does not expose button mapping for this model, but two independent
protocol implementations document the same generic Razer command family.
Read-only probes against receiver `0x009A` confirmed it and returned the custom
Synapse assignments already stored on the test mouse.

The request uses class `0x02`, get ID `0x8C`, set ID `0x0C`, transaction ID
`0x1F`, and a declared request size of `0x50`. The receiver returns a ten-byte
record:

| Argument | Meaning |
| ---: | --- |
| 0 | Persistent profile (`0x01`) |
| 1 | Button ID |
| 2 | Layer metadata; request selector is `0x00` primary or `0x01` HyperShift |
| 3 | Function ID |
| 4 | Function-data size (`0`-`5`) |
| 5-9 | Function data |

Verified source IDs are `01` left, `02` right, `03` wheel click, `04` side
back, `05` side forward, `09` tilt left, and `0A` tilt right. Verified function
IDs include `00` disabled, `01` mouse button, `02` keyboard shortcut, `0A`
consumer/media key, and `0C` HyperShift modifier. Keyboard data is a modifier
bitmask plus USB HID keyboard usage. Media data uses the two-byte consumer-page
usage observed on this receiver.

The response's layer byte is not a reliable echo on untouched records, so the
implementation identifies the requested layer from the request and validates
the echoed profile and button instead. Every write is immediately read back.
A complete unchanged primary/HyperShift profile was written and verified on the
physical Pro Click Mini before enabling this path in the app.

If any record contains an unsupported function, assignment import is rejected
as a unit and **Apply to mouse** leaves onboard assignments unchanged. This
prevents an unknown Synapse action from being replaced by a default.

## Sources

- [Razer Pro Click Mini product page](https://www.razer.com/mena-en/productivity/razer-pro-click-mini)
- [Razer Pro Click Mini support](https://mysupport.razer.com/app/answers/detail/a_id/5763/~/razer-pro-click-mini-%7C-rz01-03990-support-%26-faqs)
- [Razer Synapse 4](https://www.razer.com/synapse-4)
- [OpenRazer device ID](https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/driver/razermouse_driver.h)
- [OpenRazer report structure and checksum](https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/driver/razercommon.h)
- [OpenRazer command payloads](https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/driver/razerchromacommon.c)
- [OpenRazer Pro Click Mini capability class](https://github.com/openrazer/openrazer/blob/6820f9da169d354bc7e6e93a0aa8683a6bb75792/daemon/openrazer_daemon/hardware/mouse.py)
- [OpenSnek USB protocol: button function records](https://github.com/gh123man/OpenSnek/blob/c7f353cbe4baf45929bef5532c53192a4fcd47ea/docs/protocol/USB_PROTOCOL.md)
- [ClickSync Razer assignment codec](https://github.com/Nuitfanee/ClickSync/blob/9c3ad10baa964c507ea0714e72bb9c47b3d591c2/src/protocols/protocol_api_razer.js)
- [Microsoft: Opening HID collections](https://learn.microsoft.com/windows-hardware/drivers/hid/opening-hid-collections)

OpenRazer is used as a protocol reference; this project contains an independent
C# implementation rather than copied driver code.
