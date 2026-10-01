import UIKit

/// Attaches a slide-up secure keypad to a screen for an inline
/// `SecurePINFieldView` (the login-screen pattern).
///
/// The panel:
/// * slides the keypad in when the field is tapped and out on a second tap,
///   a background tap, or `hide()`;
/// * routes digits into the field's zeroing buffer;
/// * renders the keypad in the screen-capture-protected canvas;
/// * clears the PIN and covers the screen on recording, screenshots, the app
///   going inactive and device lock (each per the configuration).
///
///     let field = SecurePINFieldView(title: "PIN")
///     panel = SecurePINKeyboardPanel(field: field, hostView: view)
///     panel.onComplete = { field in submit(field.copyPINBytes()) }
public final class SecurePINKeyboardPanel: NSObject {

    public let field: SecurePINFieldView
    public let configuration: SecureKeyboardConfiguration
    public private(set) var isVisible = false

    /// Hide the keypad when the user taps outside it and the field.
    public var dismissesOnBackgroundTap = true

    /// Called inside the show / hide animation with the keypad's height
    /// (0 when hidden), so the host can adjust scroll insets alongside it.
    public var onVisibilityChange: ((_ isVisible: Bool, _ keyboardHeight: CGFloat) -> Void)?

    /// Called when the last digit is entered.
    public var onComplete: ((SecurePINFieldView) -> Void)?

    private weak var hostView: UIView?
    private let keyboard: SecurePINKeyboardView
    private let container: UIView
    private let keyboardParent: UIView
    private let shield: SecureKeyboardPrivacyShieldView
    private let privacyMonitor: SecureKeyboardPrivacyMonitor
    private var backgroundTap: UITapGestureRecognizer?

    public init(field: SecurePINFieldView,
                hostView: UIView,
                configuration: SecureKeyboardConfiguration? = nil) {
        let configuration = configuration ?? field.configuration
        self.field = field
        self.configuration = configuration
        self.hostView = hostView
        self.keyboard = SecurePINKeyboardView(configuration: configuration)
        self.shield = SecureKeyboardPrivacyShieldView(configuration: configuration)
        self.privacyMonitor = SecureKeyboardPrivacyMonitor(referenceView: hostView)

        if configuration.protectsAgainstScreenCapture {
            let protected = ScreenCaptureProtectedView()
            container = protected
            keyboardParent = protected.contentView
        } else {
            container = UIView()
            keyboardParent = container
        }
        super.init()

        keyboard.delegate = self
        field.onActivate = { [weak self] _ in self?.toggle() }
        privacyMonitor.onEvent = { [weak self] event in self?.handle(event) }
        shield.onContinue = { [weak self] in self?.refreshShield() }

        install(in: hostView)
    }

    // MARK: Public API

    public func show(animated: Bool = true) {
        guard !isVisible, let hostView else { return }
        if configuration.protectsAgainstScreenCapture && privacyMonitor.isScreenCaptured {
            field.clear()
            shield.show(message: configuration.texts.shieldScreenCapture, allowsContinue: false)
            return
        }
        isVisible = true
        field.isActive = true
        keyboard.reshuffleIfNeeded()

        hostView.layoutIfNeeded()
        let height = container.bounds.height
        container.isHidden = false
        hostView.bringSubviewToFront(container)
        animate(animated, options: .curveEaseOut) {
            self.container.transform = .identity
            self.onVisibilityChange?(true, height)
        }
    }

    public func hide(animated: Bool = true) {
        guard isVisible else { return }
        isVisible = false
        field.isActive = false
        animate(animated, options: .curveEaseIn, animations: {
            self.container.transform = self.hiddenTransform
            self.onVisibilityChange?(false, 0)
        }, completion: {
            if !self.isVisible { self.container.isHidden = true }
        })
    }

    public func toggle() {
        isVisible ? hide() : show()
    }

    /// Wipes the PIN and gives the keypad a fresh layout.
    public func clear() {
        field.clear()
        keyboard.reshuffleIfNeeded()
    }

    // MARK: Setup

    private func install(in hostView: UIView) {
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        hostView.addSubview(container)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        keyboardParent.addSubview(keyboard)

        shield.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(shield)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),

            keyboard.topAnchor.constraint(equalTo: keyboardParent.topAnchor),
            keyboard.leadingAnchor.constraint(equalTo: keyboardParent.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: keyboardParent.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: keyboardParent.bottomAnchor),

            shield.topAnchor.constraint(equalTo: hostView.topAnchor),
            shield.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            shield.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            shield.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])

        hostView.layoutIfNeeded()
        container.transform = hiddenTransform

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        hostView.addGestureRecognizer(tap)
        backgroundTap = tap
    }

    /// Moves the keypad (and its shadow) fully below the host's bottom edge.
    private var hiddenTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: container.bounds.height + 40)
    }

    private func animate(_ animated: Bool,
                         options: UIView.AnimationOptions,
                         animations: @escaping () -> Void,
                         completion: (() -> Void)? = nil) {
        guard animated else {
            animations()
            completion?()
            return
        }
        UIView.animate(withDuration: 0.28, delay: 0, options: [options, .beginFromCurrentState],
                       animations: animations,
                       completion: { _ in completion?() })
    }

    @objc private func backgroundTapped() {
        hide()
    }

    // MARK: Privacy

    private func handle(_ event: SecureKeyboardPrivacyMonitor.Event) {
        let texts = configuration.texts
        switch event {
        case .screenCaptureStarted:
            guard configuration.protectsAgainstScreenCapture else { return }
            clear()
            hide(animated: false)
            shield.show(message: texts.shieldScreenCapture, allowsContinue: false)

        case .screenCaptureEnded, .appDidBecomeActive, .protectedDataDidBecomeAvailable:
            refreshShield()

        case .screenshotTaken:
            guard configuration.clearsOnScreenshot, isVisible || !field.isEmpty else { return }
            clear()
            hide()

        case .appWillResignActive:
            guard configuration.clearsWhenAppResignsActive else { return }
            clear()
            hide(animated: false)
            // Also keeps the PIN screen out of the app-switcher snapshot.
            shield.show(message: texts.shieldAppInactive, allowsContinue: false)

        case .protectedDataWillBecomeUnavailable:
            clear()
            hide(animated: false)
            shield.show(message: texts.shieldDeviceLocked, allowsContinue: false)
        }
    }

    /// Hides the shield unless recording / mirroring is still going on.
    private func refreshShield() {
        if configuration.protectsAgainstScreenCapture && privacyMonitor.isScreenCaptured {
            shield.show(message: configuration.texts.shieldScreenCapture, allowsContinue: false)
        } else {
            shield.hide()
        }
    }
}

extension SecurePINKeyboardPanel: SecurePINKeyboardViewDelegate {

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int) {
        guard !field.isComplete else { return }
        field.append(digit: digit)
        if field.isComplete { onComplete?(field) }
    }

    public func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView) {
        field.deleteBackward()
    }

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapAccessoryKey key: SecureKeyboardAccessoryKey) {
        switch key {
        case .clear: clear()
        case .done: hide()
        case .none: break
        }
    }
}

extension SecurePINKeyboardPanel: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === backgroundTap else { return true }
        guard dismissesOnBackgroundTap, isVisible, let touched = touch.view else { return false }
        // The keypad keys and the field handle their own taps.
        return !touched.isDescendant(of: container) && !touched.isDescendant(of: field)
    }
}
