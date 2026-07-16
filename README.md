# SecurePINKeyboard

Reusable secure PIN entry UI for iOS apps. The package provides a randomized
numeric keyboard, masked PIN fields, screenshot/screen-recording protection, and
automatic sensitive-input clearing.

Minimum supported version: **iOS 12.0**

## Features

- Swift Package Manager compatible.
- Drop-in `SecurePINEntryViewController`.
- Lower-level `SecurePINKeyboardView` for custom screens.
- Keyboard is always anchored from the bottom of the screen in the packaged
  controller.
- Custom in-app keypad, so the system keyboard is never opened.
- Randomized digit layout with optional shuffle after every tap.
- Masked PIN fields backed by fixed-size byte storage instead of `String`.
- Constant-time PIN comparison.
- Automatic clearing on screenshot, screen capture, app inactivity, device lock,
  and protected-data changes.
- Optional secure text-entry render container to hide sensitive UI from
  screenshots and screen recordings on supported iOS versions.

## Installation

### Xcode

1. Push this repository to GitHub.
2. In your iOS app, open **File > Add Package Dependencies...**
3. Paste the repository URL:

   ```text
   https://github.com/<your-user>/<your-repo>.git
   ```

4. Select the `SecurePINKeyboard` package product.
5. Import it in your app:

   ```swift
   import SecurePINKeyboard
   ```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/<your-user>/<your-repo>.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["SecurePINKeyboard"]
    )
]
```

## Quick Start

Use `SecurePINEntryViewController` when you want the full production screen.
This controller already pins the secure keyboard to the bottom of the screen.

```swift
import UIKit
import SecurePINKeyboard

final class LoginViewController: UIViewController {

    private lazy var pinController: SecurePINEntryViewController = {
        var config = SecurePINConfiguration(
            title: "Create PIN",
            subtitle: "Use this PIN to unlock your account",
            primaryPINTitle: "Enter PIN",
            confirmationPINTitle: "Confirm PIN",
            pinLength: 4,
            mode: .confirmEntry,
            shufflesAfterEachTap: true,
            protectsAgainstScreenCapture: true,
            clearsOnScreenshot: true,
            clearsWhenAppResignsActive: true
        )

        config.accentColor = UIColor(red: 0.13, green: 0.34, blue: 0.95, alpha: 1)

        let controller = SecurePINEntryViewController(configuration: config)
        controller.delegate = self
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(pinController)
        view.addSubview(pinController.view)
        pinController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pinController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pinController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pinController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pinController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        pinController.didMove(toParent: self)
    }
}

extension LoginViewController: SecurePINEntryViewControllerDelegate {

    func securePINEntryViewController(
        _ controller: SecurePINEntryViewController,
        didCompleteWith pin: [UInt8]
    ) {
        // Send the PIN to your verifier or derive a salted verifier.
        // Do not log it. Do not store the raw PIN.
    }

    func securePINEntryViewController(
        _ controller: SecurePINEntryViewController,
        didFailWith error: SecurePINEntryError
    ) {
        // Handle mismatch or locked input state.
    }
}
```

## Single PIN Entry

Use `.singleEntry` if your app verifies the PIN elsewhere and does not need a
confirmation field.

```swift
let controller = SecurePINEntryViewController(
    configuration: SecurePINConfiguration(
        title: "Enter PIN",
        subtitle: "Unlock your session",
        primaryPINTitle: "PIN",
        pinLength: 4,
        mode: .singleEntry
    )
)
```

## Keyboard-Only Usage

If you want to build your own screen, use `SecurePINKeyboardView` directly.
To guarantee the keyboard appears from the bottom, pin its bottom anchor to the
screen or container bottom:

```swift
import SecurePINKeyboard

final class CustomPINViewController: UIViewController, SecurePINKeyboardViewDelegate {

    private let keyboard = SecurePINKeyboardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(keyboard)
        keyboard.delegate = self
        keyboard.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboard.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int) {
        // Append digit to your secure PIN buffer.
    }

    func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView) {
        // Delete the previous digit.
    }
}
```

Keep any PIN input fields above the keyboard by constraining their container to
`keyboard.topAnchor`, not to the screen bottom.

## Screenshot And Screen Recording Protection

The packaged controller hosts sensitive UI in `ScreenCaptureProtectedView`, which
uses a secure text-entry backed render surface. On supported iOS versions, the
PIN fields and keypad should be hidden from screenshots and recordings.

iOS does not provide an official app-level API to disable the screenshot button.
For that reason, the package also listens for screenshot and screen-capture
notifications and clears sensitive input immediately.

## Security Notes

This package reduces common PIN-entry leaks:

- Third-party keyboards cannot see the PIN because the system keyboard is never
  opened.
- Digits are not entered through `UITextField` or `UITextView`.
- PIN data is not stored as a Swift `String`.
- PIN comparison uses constant-time equality.
- Digit positions are randomized.
- Digit mappings are not stored in `UIButton.tag`.
- Input clears on privacy-sensitive lifecycle events.

No mobile UI can protect against every threat. A jailbroken or fully compromised
device can read process memory or capture the framebuffer. A camera that sees the
screen and finger movement can still infer input. Production apps should add
server-side rate limiting, lockout policy, Keychain-backed verification, and a
formal security review.

## Public API

- `SecurePINEntryViewController`
- `SecurePINEntryViewControllerDelegate`
- `SecurePINConfiguration`
- `SecurePINEntryMode`
- `SecurePINEntryError`
- `SecurePINKeyboardView`
- `SecurePINKeyboardViewDelegate`
- `SecurePINInputView`
- `ScreenCaptureProtectedView`

## Releasing On GitHub

1. Commit the package:

   ```bash
   git add Package.swift Sources README.md
   git commit -m "Add SecurePINKeyboard Swift package"
   ```

2. Push to GitHub:

   ```bash
   git remote add origin https://github.com/<your-user>/<your-repo>.git
   git push -u origin main
   ```

3. Tag the first version:

   ```bash
   git tag 1.0.0
   git push origin 1.0.0
   ```

4. Add the GitHub URL to any iOS app through Swift Package Manager.

## Validation

This package was validated with a generic iOS package build:

```bash
xcodebuild -scheme SecurePINKeyboard -destination generic/platform=iOS build
```

The included demo app remains available under `keyboard/`.
