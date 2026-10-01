import UIKit

/// How the digit keys are laid out.
public enum SecureKeyboardShuffleMode {
    /// Fixed phone-pad order (1-9, 0).
    case never
    /// A new random order every time the keyboard appears or is cleared.
    case onAppear
    /// A new random order after every key press.
    case afterEachTap
}

/// What the PIN being typed looks like.
public enum SecurePINFieldStyle {
    /// One rounded box with an optional icon and centred dots (login design).
    case singleBox
    /// One box per digit, each showing a dot once filled.
    case separateBoxes
}

/// The key in the bottom-left corner of the keypad.
public enum SecureKeyboardAccessoryKey {
    case none
    /// Clears the whole PIN.
    case clear
    /// Hides the keyboard / ends editing.
    case done
}

/// Whether `SecurePINEntryViewController` asks for the PIN once or twice.
public enum SecurePINEntryMode {
    case singleEntry
    case confirmEntry
}

/// Every user-facing string used by the secure keyboard components.
public struct SecureKeyboardTexts {
    public var title: String
    public var subtitle: String
    public var primaryPINTitle: String
    public var confirmationPINTitle: String
    public var statusReady: String
    public var statusEntered: String
    public var statusMatched: String
    public var statusMismatch: String
    public var clearKeyTitle: String
    public var doneKeyTitle: String
    public var shieldScreenCapture: String
    public var shieldScreenshot: String
    public var shieldAppInactive: String
    public var shieldDeviceLocked: String
    public var shieldContinueTitle: String

    public init(
        title: String = "Secure PIN",
        subtitle: String = "Enter your secure code",
        primaryPINTitle: String = "Enter PIN",
        confirmationPINTitle: String = "Confirm PIN",
        statusReady: String = "Ready",
        statusEntered: String = "PIN entered",
        statusMatched: String = "PINs match",
        statusMismatch: String = "PINs do not match",
        clearKeyTitle: String = "Clear",
        doneKeyTitle: String = "Done",
        shieldScreenCapture: String = "Screen capture detected. Secure input is hidden.",
        shieldScreenshot: String = "Screenshot detected. Secure input was cleared.",
        shieldAppInactive: String = "App inactive. Secure input was cleared.",
        shieldDeviceLocked: String = "Device lock detected. Secure input was cleared.",
        shieldContinueTitle: String = "Continue"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryPINTitle = primaryPINTitle
        self.confirmationPINTitle = confirmationPINTitle
        self.statusReady = statusReady
        self.statusEntered = statusEntered
        self.statusMatched = statusMatched
        self.statusMismatch = statusMismatch
        self.clearKeyTitle = clearKeyTitle
        self.doneKeyTitle = doneKeyTitle
        self.shieldScreenCapture = shieldScreenCapture
        self.shieldScreenshot = shieldScreenshot
        self.shieldAppInactive = shieldAppInactive
        self.shieldDeviceLocked = shieldDeviceLocked
        self.shieldContinueTitle = shieldContinueTitle
    }
}

/// All tunable parameters of the secure keyboard, in one value.
///
/// The defaults below are the single source of truth. Change them app-wide
/// through `SecureKeyboard.configure(...)`, or pass a modified copy to an
/// individual component's `init(configuration:)`.
public struct SecureKeyboardConfiguration {

    nonisolated public static let maximumPINLength = 12

    // MARK: Behaviour

    /// Number of digits, clamped to 1...12.
    public var pinLength: Int = 4 {
        didSet { pinLength = max(1, min(pinLength, Self.maximumPINLength)) }
    }
    public var entryMode: SecurePINEntryMode = .singleEntry
    public var shuffleMode: SecureKeyboardShuffleMode = .onAppear
    public var hapticFeedback: Bool = true
    public var accessoryKey: SecureKeyboardAccessoryKey = .none

    // MARK: Security

    /// Renders the keypad inside the secure text-entry canvas so screenshots
    /// and recordings show it blank, and hides input while the screen is
    /// being recorded / mirrored.
    public var protectsAgainstScreenCapture: Bool = true
    public var clearsOnScreenshot: Bool = true
    public var clearsWhenAppResignsActive: Bool = true

    // MARK: Theme

    public var accentColor: UIColor = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)
    public var errorColor: UIColor = .systemRed
    public var successColor: UIColor = .systemGreen

    // MARK: Keypad

    /// Height of the keypad above the bottom safe area.
    public var keyboardHeight: CGFloat = 300
    public var keyboardBackgroundColor: UIColor = .systemBackground
    public var keyBackgroundColor: UIColor = .secondarySystemBackground
    public var keyHighlightColor: UIColor = .systemGray4
    public var keyTextColor: UIColor = .label
    public var keyFont: UIFont = .systemFont(ofSize: 30, weight: .semibold)
    public var keyCornerRadius: CGFloat = 16
    public var keyBorderColor: UIColor = UIColor.separator.withAlphaComponent(0.25)
    public var keyBorderWidth: CGFloat = 1
    public var keySpacing: CGFloat = 12
    public var rowSpacing: CGFloat = 10
    public var keyboardInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
    public var backspaceImage: UIImage? = UIImage(systemName: "delete.left")

    // MARK: PIN field

    public var fieldStyle: SecurePINFieldStyle = .singleBox
    public var fieldHeight: CGFloat = 60
    public var fieldCornerRadius: CGFloat = 12
    public var fieldBackgroundColor: UIColor = .secondarySystemGroupedBackground
    public var fieldBorderColor: UIColor = .systemGray4
    /// Border of the field that is receiving input; `nil` uses `accentColor`.
    public var fieldActiveBorderColor: UIColor?
    public var showsFieldIcon: Bool = true
    public var fieldIcon: UIImage? = UIImage(systemName: "lock.fill")
    public var dotSize: CGFloat = 12
    public var filledDotColor: UIColor = .label
    public var emptyDotColor: UIColor = .systemGray4
    public var fieldTitleFont: UIFont = .systemFont(ofSize: 14, weight: .semibold)
    public var fieldTitleColor: UIColor = .secondaryLabel

    // MARK: Texts

    public var texts = SecureKeyboardTexts()

    public init() {}

    var resolvedActiveBorderColor: UIColor {
        fieldActiveBorderColor ?? accentColor
    }
}
