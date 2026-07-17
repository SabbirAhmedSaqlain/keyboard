# How to Set Up and Use This Keyboard

## Set Up

### Xcode

1. In your iOS app, open **File > Add Package Dependencies...**
2. Paste this repository's URL:

   ```text
   https://github.com/<your-user>/<your-repo>.git
   ```

3. Select the `SecurePINKeyboard` package product.
4. Import it in your app:

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

## Use

Use `SecurePINEntryViewController` for the full PIN entry screen. It pins the
secure keyboard to the bottom of the screen.

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
        // Send the PIN to your verifier. Do not log or store the raw PIN.
    }

    func securePINEntryViewController(
        _ controller: SecurePINEntryViewController,
        didFailWith error: SecurePINEntryError
    ) {
        // Handle mismatch or locked input state.
    }
}
```

Use `.singleEntry` if your app verifies the PIN elsewhere and does not need a
confirmation field:

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

To build your own screen, use `SecurePINKeyboardView` directly and pin its
bottom anchor to the screen or container bottom:

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


##  Top Security Features:

- Custom in-app keypad, so third-party keyboards never receive the PIN.
- Randomised digit layout, with optional reshuffle after every tap.
- Masked PIN boxes, so digits are never displayed on screen.
- Byte-backed input buffer that clears and zeroes sensitive values.
- Screen capture and lifecycle protections that can hide or clear sensitive input.