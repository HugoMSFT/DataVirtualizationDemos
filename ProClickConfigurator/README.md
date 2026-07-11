# Pro Click Mini Configurator

A lightweight, unofficial Windows and macOS configurator for the Razer Pro
Click Mini. It talks directly to the 2.4 GHz receiver for verified hardware
settings and onboard button assignments, including the HyperShift layer.

## Features

- Read and set DPI from 100 to 12,000.
- Configure one to five onboard DPI stages and the active stage.
- Select 125, 500, or 1,000 Hz polling.
- Read battery level and configure sleep time and the low-battery threshold.
- Read and assign seven onboard controls to common mouse, editing, navigation,
  Windows, and media actions.
- Read and configure the mouse's onboard HyperShift layer.
- Save assignments and settings as named, reusable local presets.
- Select all seven controls directly on the Pro Click Mini product photo.
- Keep normal left click locked while allowing a separate HyperShift action.
- Run as a portable, self-contained application without installing .NET.

## Important hardware boundary

Razer does not publish a Synapse CLI or a device-configuration API. The public
Chroma SDK controls lighting only, and the Pro Click Mini has no Chroma
lighting. This app therefore uses the receiver's HID feature-report protocol.

The receiver protocol exposes DPI, DPI stages, polling, battery, idle timeout,
low-battery threshold, firmware, and a ten-byte onboard assignment record. The
assignment command was verified directly against this receiver for all seven
controls on both the primary and HyperShift layers, including write/read-back.

| Setting | Saved to mouse | Saved locally | Requires app running |
| --- | :---: | :---: | :---: |
| DPI and DPI stages | Yes | Yes | No |
| Polling rate | Yes | Yes | No |
| Sleep and battery warning | Yes | Yes | No |
| Button assignments | Yes | Yes | No |
| HyperShift layer | Yes | Yes | No |

The **Apply to mouse** button writes performance, power, primary assignments,
and HyperShift assignments, then reads each setting back. **Save preset** keeps
a named local copy that can be loaded again later. The current startup profile
and named presets are stored under:

```text
Windows: %LOCALAPPDATA%\ProClickConfigurator
macOS:   ~/Library/Application Support/ProClickConfigurator
```

## Requirements

- Windows 10/11 x64, macOS 12 or later on Apple Silicon, or macOS 12 or later
  on Intel
- Razer Pro Click Mini connected through its 2.4 GHz receiver

Bluetooth configuration is not implemented because no equivalent
vendor-feature interface has been verified for that mode.

## Portable packages

The self-contained packages do not require an installer or a separate .NET
runtime:

- `ProClickConfigurator-win-x64.zip`
- `ProClickConfigurator-osx-arm64.app.tar.gz`
- `ProClickConfigurator-osx-x64.app.tar.gz`

Extract the package for the computer's architecture. On macOS, double-click the
`.tar.gz`, then right-click **Pro Click Mini Configurator.app** and select
**Open** the first time because the portable build is unsigned. If macOS blocks
receiver access, allow the app under **System Settings > Privacy & Security >
Input Monitoring**, then reopen it.

## Build and run

Building from source requires the .NET 8 SDK. From this directory:

```powershell
dotnet run --project .\src\ProClickConfigurator\ProClickConfigurator.csproj
dotnet test .\ProClickConfigurator.sln
```

To produce all three self-contained packages, install Python 3 and run:

```powershell
.\scripts\publish-portable.ps1
```

The packages are written to `artifacts\portable`.

## Using assignments and HyperShift

1. Click a numbered control on the mouse photo.
2. Choose its primary and HyperShift actions.
3. Assign **HyperShift modifier** as the primary action of one pressable button.
4. Select **Apply to mouse** to write both layers to onboard memory.
5. Optionally name and save the configuration as a reusable preset.

The normal left-click action is locked for safety. Its HyperShift-layer action
remains configurable.

Select **Read from mouse** before editing to import the assignments currently
stored by Synapse or another configurator. If an onboard action is not in this
app's supported catalog, the app leaves all assignments untouched rather than
silently replacing it. Wheel tilt cannot be a held HyperShift modifier because
it is a momentary control.

If Synapse is running and a setting changes back, close Synapse before applying
the profile; both applications can compete for the same feature-report state.

## Research and implementation notes

See [docs/protocol.md](docs/protocol.md) for command details, sources, and the
distinction between verified behavior and unsupported Synapse functionality.

This project is not affiliated with or endorsed by Razer Inc. Razer, Synapse,
HyperShift, and Pro Click Mini are trademarks of their respective owner.
