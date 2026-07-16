# Secure PIN Keyboard

This project is an iOS UIKit demo for collecting a 4-digit PIN without using the
system keyboard. It uses a custom randomized keypad, masked PIN boxes, a
screen-capture-protected render container, aggressive input clearing, and
screen/privacy lifecycle hardening.

The goal is high-assurance PIN entry inside this app. No mobile UI can honestly
promise absolute security against a compromised device, a malicious OS, or a
camera pointed at the screen.

## How It Works

On launch, `SceneDelegate` installs `DashboardViewController` as the root screen.
The dashboard owns two `PinInputView` fields and one `SecureKeyboardView`.

The system keyboard is never shown:

- There is no `UITextField` or `UITextView` in the PIN path.
- Tapping a PIN field only changes which custom field is active.
- Tapping a keypad button sends a digit to the active field through
  `SecureKeyboardDelegate`.

The keypad is randomized:

- `SecureKeyboardView.shuffle()` assigns digits `0...9` to ten button positions.
- It uses `SystemRandomNumberGenerator`.
- It shuffles when the keyboard appears and again after every digit/backspace.
- Buttons use `.custom` styling with identical normal and highlighted states.
- Buttons are single-touch/exclusive-touch to avoid multi-tap ambiguity.

The PIN field is masked:

- `PinInputView` renders only filled dots.
- Digits are never rendered in the PIN boxes.
- The entered PIN is not stored as a Swift `String`.

Sensitive input is stored in `SecurePinBuffer`:

- Fixed-size `[UInt8]` storage.
- No string interpolation of the full PIN.
- Constant-time equality check for PIN comparison.
- Explicit zeroing on delete, clear, and deinit.
- Immediate clearing after the two PIN entries are compared.

The sensitive UI is hosted by `ScreenCaptureProtectedView`:

- The PIN fields and keypad render inside a secure text-entry backed surface.
- On supported iOS versions, screenshots and screen recordings should hide that
  protected content instead of capturing the digits/keypad.
- The app still listens for screenshot/screen-capture notifications and clears
  PIN buffers as a fallback.

Privacy events wipe and cover the UI:

- App resigns active.
- App enters background.
- Protected data becomes unavailable.
- Screen recording or mirroring is detected.
- A screenshot notification is received.

When one of those events happens, the app clears both PIN buffers, reshuffles the
keypad, disables input, and shows a privacy shield over the screen.

## Why This Is More Secure

This design reduces several common PIN-entry leaks:

- Third-party keyboard extensions cannot see the PIN because the system keyboard
  is not used.
- Text input hooks, autocorrect, prediction, and text-field analytics do not get
  a PIN value because the app does not use text-input controls.
- The PIN is not written to disk, `UserDefaults`, pasteboard, or logs.
- Screenshots and recordings are protected by a secure render surface where iOS
  supports that behavior.
- Randomized key positions make fixed-coordinate shoulder-surfing, smudge, and
  heat-map attacks less useful.
- Per-tap reshuffling prevents one tap location from having a stable meaning
  during the same entry session.
- No press highlight, haptic, or animation reveals which key was pressed.
- Button digit mappings are not stored in `UIButton.tag`.
- Digit labels are hidden from accessibility metadata to avoid leaking the
  current randomized layout through UI inspection.
- PIN bytes are cleared immediately after comparison and on lifecycle/privacy
  transitions.

## Security Limits

This is hardened, but it is not magic:

- If someone can see both the screen and the finger movement clearly, they may
  still infer the digit because the visual keypad must show digits to be usable.
- iOS does not provide an official app-level "disable screenshots" API. This app
  uses the secure text-entry render-surface technique, which should hide the
  protected content on current iOS versions, and then clears input when screenshot
  or capture notifications arrive.
- A jailbroken or fully compromised device can read process memory or capture the
  framebuffer.
- The demo compares two entered PINs. A production app should never store a raw
  PIN; use a salted verifier, server-side verification, Secure Enclave-backed
  keys where appropriate, Keychain protection, rate limiting, and lockout policy.
- Hiding digit labels from accessibility metadata improves confidentiality but
  reduces accessibility. A production app needs a separate accessible secure
  entry design and a documented risk decision.

## Key Files

- `keyboard/keyboard/SecureKeyboardView.swift` - randomized custom keypad.
- `keyboard/keyboard/PinInputView.swift` - masked PIN display backed by secure
  byte storage.
- `keyboard/keyboard/SecurePinBuffer.swift` - fixed-size zeroing PIN buffer.
- `keyboard/keyboard/ScreenCaptureProtectedView.swift` - secure render container
  for screenshot and screen-recording protection.
- `keyboard/keyboard/DashboardViewController.swift` - PIN flow, comparison,
  lifecycle privacy observers, and privacy shield.
- `keyboard/keyboard/SceneDelegate.swift` - app lifecycle hooks that clear and
  cover sensitive input.

## Production Hardening Checklist

Before using this for a real authentication flow:

- Add server-side rate limiting and account lockout.
- Store only a salted verifier or use server-side verification.
- Use Keychain with the strongest access-control class that fits the product.
- Add jailbreak/root compromise detection as a risk signal.
- Add telemetry for security events without logging PIN data.
- Perform manual QA for app switcher snapshots, screen recording, AirPlay,
  VoiceOver, Switch Control, and external keyboard/pointer behavior.
- Run a third-party mobile security review before shipping.
