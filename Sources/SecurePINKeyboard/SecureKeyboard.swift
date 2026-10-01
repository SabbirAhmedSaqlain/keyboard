import UIKit

/// Entry point of the secure keyboard module.
///
/// Every component (`SecurePINKeyboardView`, `SecurePINFieldView`,
/// `SecurePINKeyboardPanel`, `SecurePINTextFieldCoordinator`,
/// `SecurePINEntryViewController`, `ScreenshotProtectedViewController`,
/// `SecureKeyboardSettingsViewController`) reads `SecureKeyboard.configuration` unless
/// it is handed its own configuration, so one call to `configure(...)` at app
/// launch themes and tunes all of them.
@MainActor
public enum SecureKeyboard {

    /// Posted after the app-wide `configuration` changes (via `configure` with
    /// `applyGlobally: true` or `resetConfiguration()`).
    public static let configurationDidChangeNotification = Notification.Name("SecureKeyboardConfigurationDidChange")

    /// The configuration components use by default.
    public private(set) static var configuration = SecureKeyboardConfiguration() {
        didSet { NotificationCenter.default.post(name: configurationDidChangeNotification, object: nil) }
    }

    /// Customises the secure keyboard from a single place.
    ///
    /// Every parameter is optional: `nil` keeps the current value, so you only
    /// pass what you want to change.
    ///
    ///     SecureKeyboard.configure(pinLength: 6,
    ///                              shuffleMode: .afterEachTap,
    ///                              accentColor: .systemTeal)
    ///
    /// - Parameter applyGlobally: `true` (default) stores the result as the
    ///   app-wide default. Pass `false` to get a customised copy for a single
    ///   screen without touching the default:
    ///
    ///       let sixDigit = SecureKeyboard.configure(applyGlobally: false, pinLength: 6)
    ///       let entry = SecurePINEntryViewController(configuration: sixDigit)
    ///
    /// - Returns: The resulting configuration.
    @discardableResult
    public static func configure(
        applyGlobally: Bool = true,
        // Behaviour
        pinLength: Int? = nil,
        entryMode: SecurePINEntryMode? = nil,
        shuffleMode: SecureKeyboardShuffleMode? = nil,
        hapticFeedback: Bool? = nil,
        accessoryKey: SecureKeyboardAccessoryKey? = nil,
        // Security
        protectsAgainstScreenCapture: Bool? = nil,
        preventsScreenshots: Bool? = nil,
        clearsOnScreenshot: Bool? = nil,
        clearsWhenAppResignsActive: Bool? = nil,
        // Theme
        accentColor: UIColor? = nil,
        errorColor: UIColor? = nil,
        successColor: UIColor? = nil,
        // Keypad
        keyboardHeight: CGFloat? = nil,
        keyboardBackgroundColor: UIColor? = nil,
        keyBackgroundColor: UIColor? = nil,
        keyHighlightColor: UIColor? = nil,
        keyTextColor: UIColor? = nil,
        keyFont: UIFont? = nil,
        keyCornerRadius: CGFloat? = nil,
        keyBorderColor: UIColor? = nil,
        keyBorderWidth: CGFloat? = nil,
        keySpacing: CGFloat? = nil,
        rowSpacing: CGFloat? = nil,
        keyboardInsets: UIEdgeInsets? = nil,
        backspaceImage: UIImage? = nil,
        // PIN field
        fieldStyle: SecurePINFieldStyle? = nil,
        fieldHeight: CGFloat? = nil,
        fieldCornerRadius: CGFloat? = nil,
        fieldBackgroundColor: UIColor? = nil,
        fieldBorderColor: UIColor? = nil,
        fieldActiveBorderColor: UIColor? = nil,
        showsFieldIcon: Bool? = nil,
        fieldIcon: UIImage? = nil,
        dotSize: CGFloat? = nil,
        filledDotColor: UIColor? = nil,
        emptyDotColor: UIColor? = nil,
        fieldTitleFont: UIFont? = nil,
        fieldTitleColor: UIColor? = nil,
        // Texts
        texts: SecureKeyboardTexts? = nil
    ) -> SecureKeyboardConfiguration {
        var config = configuration

        if let pinLength { config.pinLength = pinLength }
        if let entryMode { config.entryMode = entryMode }
        if let shuffleMode { config.shuffleMode = shuffleMode }
        if let hapticFeedback { config.hapticFeedback = hapticFeedback }
        if let accessoryKey { config.accessoryKey = accessoryKey }

        if let protectsAgainstScreenCapture { config.protectsAgainstScreenCapture = protectsAgainstScreenCapture }
        if let preventsScreenshots { config.preventsScreenshots = preventsScreenshots }
        if let clearsOnScreenshot { config.clearsOnScreenshot = clearsOnScreenshot }
        if let clearsWhenAppResignsActive { config.clearsWhenAppResignsActive = clearsWhenAppResignsActive }

        if let accentColor { config.accentColor = accentColor }
        if let errorColor { config.errorColor = errorColor }
        if let successColor { config.successColor = successColor }

        if let keyboardHeight { config.keyboardHeight = keyboardHeight }
        if let keyboardBackgroundColor { config.keyboardBackgroundColor = keyboardBackgroundColor }
        if let keyBackgroundColor { config.keyBackgroundColor = keyBackgroundColor }
        if let keyHighlightColor { config.keyHighlightColor = keyHighlightColor }
        if let keyTextColor { config.keyTextColor = keyTextColor }
        if let keyFont { config.keyFont = keyFont }
        if let keyCornerRadius { config.keyCornerRadius = keyCornerRadius }
        if let keyBorderColor { config.keyBorderColor = keyBorderColor }
        if let keyBorderWidth { config.keyBorderWidth = keyBorderWidth }
        if let keySpacing { config.keySpacing = keySpacing }
        if let rowSpacing { config.rowSpacing = rowSpacing }
        if let keyboardInsets { config.keyboardInsets = keyboardInsets }
        if let backspaceImage { config.backspaceImage = backspaceImage }

        if let fieldStyle { config.fieldStyle = fieldStyle }
        if let fieldHeight { config.fieldHeight = fieldHeight }
        if let fieldCornerRadius { config.fieldCornerRadius = fieldCornerRadius }
        if let fieldBackgroundColor { config.fieldBackgroundColor = fieldBackgroundColor }
        if let fieldBorderColor { config.fieldBorderColor = fieldBorderColor }
        if let fieldActiveBorderColor { config.fieldActiveBorderColor = fieldActiveBorderColor }
        if let showsFieldIcon { config.showsFieldIcon = showsFieldIcon }
        if let fieldIcon { config.fieldIcon = fieldIcon }
        if let dotSize { config.dotSize = dotSize }
        if let filledDotColor { config.filledDotColor = filledDotColor }
        if let emptyDotColor { config.emptyDotColor = emptyDotColor }
        if let fieldTitleFont { config.fieldTitleFont = fieldTitleFont }
        if let fieldTitleColor { config.fieldTitleColor = fieldTitleColor }

        if let texts { config.texts = texts }

        if applyGlobally {
            configuration = config
        }
        return config
    }

    /// Restores every parameter to its default value.
    public static func resetConfiguration() {
        configuration = SecureKeyboardConfiguration()
    }
}
