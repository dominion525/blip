# Blip

Find your mouse cursor.

A menu bar utility for macOS that highlights the cursor when you lose it on a multi-display setup. Press a hotkey or double-tap a modifier key and the cursor position lights up. Requires macOS 13 or later.

## Requirements

- macOS 13 or later
- Xcode (for swift build and XCTest)

## Build and run

```
./build.sh
open Blip.app
```

build.sh builds the executable with `swift build -c release`, assembles Blip.app with Info.plist and the resource bundles, and signs it.

A Developer ID Application certificate from the Keychain is used for signing when present; otherwise the app is signed ad hoc. The CODESIGN_IDENTITY environment variable overrides the identity.

```
CODESIGN_IDENTITY="Apple Development" ./build.sh
```

An ad hoc signature changes on every rebuild, so the Input Monitoring permission can become invalid after rebuilding. Signing with a certificate keeps the app identity stable.

## Tests

```
swift test
```

The AppKit-free logic (coordinate math, double-tap detection, effect timing) lives in BlipCore and is verified with XCTest. Drawing and key monitoring are checked by hand.

## Usage

Blip puts a cursor icon in the menu bar and does not appear in the Dock.

```
Menu item          Action
Show Spotlight     Show the effect now
Settings…          Open the settings window (⌘,)
About Blip         Open the About panel
Quit Blip          Quit (⌘Q)
```

Two triggers show the effect; both are configured in the settings window.

- Hotkey (default ⌥⌘Z). Click the field and press the keys. A modifier plus a key, or a function key on its own, can be recorded
- Modifier double-tap (default Left Control). Choose from left or right Control, Shift, Option, and Command, or turn it off

The effect hides itself after 1.2 seconds. While visible it follows the cursor, and the apps underneath stay clickable. With several displays, the effect appears only on the display that contains the cursor and the others are dimmed.

### Effects

```
Name          Appearance
Spotlight     Dims the screen and cuts a ringed hole around the cursor
Zoom          A hole the size of the screen shrinks onto the cursor
Flash         The ring blinks and ripples spread out from the cursor
Focus Lines   Manga-style speed lines point at the cursor and jitter across three frames
```

## Permissions

- The hotkey is registered through Carbon's RegisterEventHotKey (via the KeyboardShortcuts library) and needs no permission
- The modifier double-tap watches key events to tell left from right, which needs the Input Monitoring permission. The OS dialog appears on first launch; enable Blip under System Settings > Privacy & Security > Input Monitoring. Until then the double-tap does nothing and the settings window shows the state
- Showing the effect and reading the cursor position need no permission

## Where settings live

The hotkey, the double-tap modifier, and the selected effect are stored in UserDefaults (local.blip). Launch at login is registered with SMAppService and appears under Login Items in System Settings.

The display language follows the system setting (English and Japanese). It can be changed for Blip alone under System Settings > General > Language & Region > Applications.

## Tunables

Values that are not in the settings window live in `enum Config` in Sources/Blip/main.swift. Edit them and run build.sh again.

```
Name                     Default   Meaning
spotRadius               110       Spot radius (pt)
dimOpacity               0.55      Opacity of the dim layer
ringColor                yellow    Ring color
ringWidth                4         Ring line width (pt)
autoHideSeconds          1.2       Seconds until the effect hides; nil keeps it until triggered again
trackingInterval         1/60      Cursor tracking interval (s)
zoomDuration             0.35      Zoom duration (s)
zoomOvershoot            0.15      Zoom overshoot as a fraction of the spot radius
flashBlinkPeriod         0.2       Flash blink period (s)
flashRingWidthScale      1.5       Ring width multiplier while the Flash ring blinks
flashRippleInterval      0.3       Ripple emission interval (s)
flashRippleLifetime      0.6       Ripple lifetime (s)
flashRippleMaxScale      3         Maximum ripple radius as a multiple of the spot radius
focusLinesCount          150       Number of focus lines
focusLinesInnerRadius    80        Clear radius at the center of the focus lines (pt)
focusLinesInnerJitter    30        Jitter of the focus line tips (pt)
focusLinesWidthRange     6...22    Width of the focus lines at the outer end (pt)
focusLinesFrameCount     3         Number of focus line animation frames
focusLinesFrameInterval  1/12      Focus line frame interval (s)
doubleTapInterval        0.3       Maximum time between the two taps (s)
```

## Layout

```
Package.swift                    SwiftPM manifest; depends on KeyboardShortcuts
Sources/BlipCore/                AppKit-free logic (covered by tests)
Sources/Blip/main.swift          Config, overlay window management, AppDelegate
Sources/Blip/EffectRenderer.swift  Drawing for each effect
Sources/Blip/ModifierTapMonitor.swift  Modifier double-tap monitor (event tap)
Sources/Blip/SettingsWindowController.swift  Settings window
Sources/Blip/Settings.swift      UserDefaults access
Sources/Blip/Resources/          Localizable.strings（en / ja）
Tests/BlipCoreTests/             XCTest
build.sh                         Assembles and signs Blip.app
```

## Limitations

- A modifier pressed together with another key does not count as a tap, so ⌃C and similar combinations never trigger the effect
- The hotkey field does not accept a modifier on its own or Shift plus a key
- The login item is tied to the location of Blip.app. Re-enable it after moving the app
- An ad hoc signed Blip.app opened on another Mac is blocked by Gatekeeper
