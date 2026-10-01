# SecurePINKeyboard

A Swift package that adds secure PIN entry to an iOS app: a randomized numeric
keypad, masked PIN fields, screenshot and screen-recording blocking, automatic
clearing of sensitive input, and a ready-made settings page.

Minimum supported version: **iOS 14.0** · UIKit · Swift 5.9+ (Xcode 15+)

For the full design, see [report.md](report.md).

## Features

- **Screenshot blocking.** `ScreenshotProtectedViewController` renders a whole
  screen, or the whole app, inside UIKit's secure canvas, so screenshots,
  screen recordings and mirroring show it blank.
- **Custom keypad.** The system keyboard is never opened, so third-party
  keyboards can't log the input.
- **Randomized digit layout**: fixed, shuffled when the keypad opens, or
  shuffled after every tap.
- **PIN storage that wipes itself.** Digits are kept as bytes, never as a
  `String`, and are zeroed on clear and on deinit. PINs are compared in
  constant time.
- **Privacy shield.** The PIN is cleared and the screen is covered on
  screenshot, screen recording, app inactivity and device lock.
- **One-call configuration** with `SecureKeyboard.configure(...)`.
- **Ready-made settings page** (`SecureKeyboardSettingsViewController`) that
  you can open from your own Configure button.

## Installation

### Xcode

1. **File › Add Package Dependencies…**
2. Enter the repository URL (or click **Add Local…** and choose this folder):

   ```text
   https://github.com/<your-org>/<your-repo>.git
   ```

3. Add the **SecurePINKeyboard** product to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/<your-repo>.git", from: "2.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["SecurePINKeyboard"])
]
```

Then add `import SecurePINKeyboard` to each file that uses it.

## Quick start

### 1. Configure once and block screenshots app-wide

```swift
import SecurePINKeyboard

func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }

    SecureKeyboard.configure(pinLength: 6,
                             shuffleMode: .afterEachTap,
                             preventsScreenshots: true,
                             accentColor: .systemTeal)

    let navigation = UINavigationController(rootViewController: HomeViewController())
    let window = UIWindow(windowScene: windowScene)
    // Everything pushed on this stack is blank in screenshots and recordings.
    window.rootViewController = ScreenshotProtectedViewController(rootViewController: navigation)
    window.makeKeyAndVisible()
    self.window = window
}
```

To protect only one screen, wrap it before you push it:

```swift
navigationController?.pushViewController(
    ScreenshotProtectedViewController(rootViewController: loginViewController),
    animated: true)
```

> iOS has no public API that stops the user from taking a screenshot. This
> package makes the screenshot useless: protected content is captured as blank.
> UIKit draws modally presented controllers outside the container, so wrap
> those too, or push them instead.

### 2. Add a Configure button

```swift
navigationItem.rightBarButtonItem = UIBarButtonItem(
    title: "Configure",
    image: UIImage(systemName: "gearshape"),
    primaryAction: UIAction { [weak self] _ in
        self?.navigationController?.pushViewController(
            SecureKeyboardSettingsViewController(), animated: true)
    })
```

You can also present it modally with a Done button:
`SecureKeyboardSettingsViewController.present(from: self)`. Each control on the
page calls `SecureKeyboard.configure(...)`, so changes apply to every keyboard
opened afterwards. You can also customize `pinLengthOptions`, `accentOptions`
and `onChange`.

### 3. Ask for a PIN

**Full screen** (`SecurePINEntryViewController`):

```swift
let config = SecureKeyboard.configure(applyGlobally: false,
                                      entryMode: .confirmEntry,
                                      texts: SecureKeyboardTexts(title: "Set PIN"))
let entry = SecurePINEntryViewController(configuration: config)
entry.delegate = self
navigationController?.pushViewController(entry, animated: true)

func securePINEntryViewController(_ controller: SecurePINEntryViewController,
                                  didCompleteWith pin: [UInt8]) {
    var pin = pin
    defer { pin.secureWipe() }   // never log or store the raw PIN
    verify(pin)
    controller.close()
}
```

**Inline field with a slide-up keypad** (`SecurePINKeyboardPanel`, for a
login-screen layout):

```swift
let field = SecurePINFieldView(title: "PIN")
panel = SecurePINKeyboardPanel(field: field, hostView: view)
panel.onComplete = { field in
    var pin = field.copyPINBytes()
    defer { pin.secureWipe() }
    verify(pin)
}
```

**Existing `UITextField`s** (`SecurePINTextFieldCoordinator`):

```swift
coordinator.register(currentPINField, title: "Current PIN")
coordinator.register(newPINField, title: "New PIN")
```

**Keypad only** (`SecurePINKeyboardView`): set a
`SecurePINKeyboardViewDelegate` and pin the view to the bottom of your screen.

## Public API

| Type | Purpose |
| --- | --- |
| `SecureKeyboard` | Global `configuration`, `configure(...)`, `resetConfiguration()`, `configurationDidChangeNotification` |
| `SecureKeyboardConfiguration` | Every setting: behaviour, security, theme, keypad, field, texts |
| `ScreenshotProtectedViewController` | Container that blanks its screen in screenshots and recordings |
| `ScreenCaptureProtectedView` | View-level version of the same protection |
| `SecureKeyboardSettingsViewController` | Ready-made settings page |
| `SecurePINEntryViewController` (+ delegate) | Full-screen single or confirm PIN entry |
| `SecurePINKeyboardPanel` | Slide-up keypad for an inline field |
| `SecurePINTextFieldCoordinator` | Secure keypad for existing text fields |
| `SecurePINFieldView` | Masked PIN display with a zeroing buffer |
| `SecurePINKeyboardView` (+ delegate) | The keypad itself |
| `SecureKeyboardPrivacyMonitor`, `SecureKeyboardPrivacyShieldView` | Privacy events and the cover view |

## Demo app

`SecuredKeyboard/SecuredKeyboard.xcodeproj` uses this package as a local
dependency. The home screen has a **Configure Keyboard** button and one demo
for each component. The whole app runs inside a
`ScreenshotProtectedViewController`.

## Releasing

```bash
git tag 2.0.0
git push origin 2.0.0
```

Version 2.0.0 replaces the 1.x API (`SecurePINConfiguration`,
`SecurePINInputView`, `SecurePINStyle`). Migrate those to
`SecureKeyboardConfiguration` and `SecurePINFieldView`.

## Security notes

No mobile UI can protect against everything. A jailbroken or compromised
device can read process memory or the framebuffer, and a camera pointed at
the screen can still see the input. The screenshot blocking uses UIKit's
secure text-entry rendering, which is undocumented behaviour. If iOS changes
it, `isProtectionAvailable` becomes `false` and content is shown unprotected
rather than hidden. Pair this package with server-side rate limiting, lockout
and Keychain-backed verification.
