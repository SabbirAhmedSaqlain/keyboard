import UIKit

public enum SecurePINEntryMode {
    case singleEntry
    case confirmEntry
}

public struct SecurePINConfiguration {
    public static let defaultAccentColor = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)

    public var title: String
    public var subtitle: String
    public var primaryPINTitle: String
    public var confirmationPINTitle: String
    public var pinLength: Int
    public var mode: SecurePINEntryMode
    public var shufflesAfterEachTap: Bool
    public var protectsAgainstScreenCapture: Bool
    public var clearsOnScreenshot: Bool
    public var clearsWhenAppResignsActive: Bool
    public var accentColor: UIColor

    public init(
        title: String = "Secure PIN",
        subtitle: String = "Enter your secure code",
        primaryPINTitle: String = "Enter PIN",
        confirmationPINTitle: String = "Confirm PIN",
        pinLength: Int = 4,
        mode: SecurePINEntryMode = .confirmEntry,
        shufflesAfterEachTap: Bool = true,
        protectsAgainstScreenCapture: Bool = true,
        clearsOnScreenshot: Bool = true,
        clearsWhenAppResignsActive: Bool = true,
        accentColor: UIColor = SecurePINConfiguration.defaultAccentColor
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryPINTitle = primaryPINTitle
        self.confirmationPINTitle = confirmationPINTitle
        self.pinLength = max(1, min(pinLength, 12))
        self.mode = mode
        self.shufflesAfterEachTap = shufflesAfterEachTap
        self.protectsAgainstScreenCapture = protectsAgainstScreenCapture
        self.clearsOnScreenshot = clearsOnScreenshot
        self.clearsWhenAppResignsActive = clearsWhenAppResignsActive
        self.accentColor = accentColor
    }
}

public enum SecurePINEntryError: Error, Equatable {
    case confirmationMismatch
    case inputLocked
}

public protocol SecurePINEntryViewControllerDelegate: AnyObject {
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didCompleteWith pin: [UInt8])
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError)
    func securePINEntryViewControllerDidClearSensitiveInput(_ controller: SecurePINEntryViewController)
}

public extension SecurePINEntryViewControllerDelegate {
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError) {}
    func securePINEntryViewControllerDidClearSensitiveInput(_ controller: SecurePINEntryViewController) {}
}
