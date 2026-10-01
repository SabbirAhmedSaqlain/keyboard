import UIKit

/// Watches the system events that should wipe or hide secure input and reports
/// them through one callback. Shared by every secure keyboard component so the
/// observation logic lives in one place.
@MainActor
public final class SecureKeyboardPrivacyMonitor: NSObject {

    public enum Event {
        case screenCaptureStarted
        case screenCaptureEnded
        case screenshotTaken
        case appWillResignActive
        case appDidBecomeActive
        case protectedDataWillBecomeUnavailable
        case protectedDataDidBecomeAvailable
    }

    public var onEvent: ((Event) -> Void)?

    /// Used to find the screen this UI is on. Falls back to every connected
    /// scene while the view is not yet in a window.
    public weak var referenceView: UIView?

    public init(referenceView: UIView? = nil) {
        self.referenceView = referenceView
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(capturedDidChange), name: UIScreen.capturedDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(userDidTakeScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        center.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(protectedDataWillBecomeUnavailable), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        center.addObserver(self, selector: #selector(protectedDataDidBecomeAvailable), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
    }

    /// `true` while the screen is recorded, mirrored or AirPlayed.
    public var isScreenCaptured: Bool {
        if let screen = referenceView?.window?.windowScene?.screen {
            return screen.isCaptured
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.screen.isCaptured }
    }

    public var isProtectedDataAvailable: Bool {
        UIApplication.shared.isProtectedDataAvailable
    }

    @objc private func capturedDidChange() {
        onEvent?(isScreenCaptured ? .screenCaptureStarted : .screenCaptureEnded)
    }

    @objc private func userDidTakeScreenshot() {
        onEvent?(.screenshotTaken)
    }

    @objc private func willResignActive() {
        onEvent?(.appWillResignActive)
    }

    @objc private func didBecomeActive() {
        onEvent?(.appDidBecomeActive)
    }

    @objc private func protectedDataWillBecomeUnavailable() {
        onEvent?(.protectedDataWillBecomeUnavailable)
    }

    @objc private func protectedDataDidBecomeAvailable() {
        onEvent?(.protectedDataDidBecomeAvailable)
    }
}
