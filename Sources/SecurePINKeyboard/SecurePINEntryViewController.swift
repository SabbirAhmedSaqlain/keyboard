import UIKit

public enum SecurePINEntryError: Error, Equatable {
    case confirmationMismatch
    case inputLocked
}

@MainActor
public protocol SecurePINEntryViewControllerDelegate: AnyObject {
    /// `pin` holds one digit (0-9) per byte. Call `secureWipe()` on it when done.
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didCompleteWith pin: [UInt8])
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError)
    func securePINEntryViewControllerDidClearSensitiveInput(_ controller: SecurePINEntryViewController)
}

public extension SecurePINEntryViewControllerDelegate {
    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError) {}
    func securePINEntryViewControllerDidClearSensitiveInput(_ controller: SecurePINEntryViewController) {}
}

/// Full-screen PIN entry with a built-in secure keypad.
///
/// `configuration.entryMode` picks between asking once (`.singleEntry`) and
/// asking twice and comparing in constant time (`.confirmEntry`, for set /
/// change PIN). The whole screen is rendered in the capture-protected canvas.
public final class SecurePINEntryViewController: UIViewController {

    public weak var delegate: SecurePINEntryViewControllerDelegate?
    public let configuration: SecureKeyboardConfiguration

    private let primaryField: SecurePINFieldView
    private let confirmationField: SecurePINFieldView?
    private let keyboard: SecurePINKeyboardView
    private let protectedContentView = ScreenCaptureProtectedView()
    private let statusPill = UIView()
    private let statusIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let statusLabel = UILabel()
    private let shield: SecureKeyboardPrivacyShieldView
    private let privacyMonitor = SecureKeyboardPrivacyMonitor()

    private var activeField: SecurePINFieldView?
    private var isInputLocked = false

    public init(configuration: SecureKeyboardConfiguration? = nil) {
        // `nil` = the app-wide `SecureKeyboard.configuration`.
        let configuration = configuration ?? SecureKeyboard.configuration
        self.configuration = configuration
        self.primaryField = SecurePINFieldView(title: configuration.texts.primaryPINTitle, configuration: configuration)
        if configuration.entryMode == .confirmEntry {
            self.confirmationField = SecurePINFieldView(title: configuration.texts.confirmationPINTitle, configuration: configuration)
        } else {
            self.confirmationField = nil
        }
        self.keyboard = SecurePINKeyboardView(configuration: configuration)
        self.shield = SecureKeyboardPrivacyShieldView(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported; use init(configuration:)")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        setupLayout()
        setupShield()

        for field in [primaryField, confirmationField].compactMap({ $0 }) {
            field.onActivate = { [weak self] field in self?.activate(field) }
            field.onChange = { [weak self] _ in self?.pinChanged() }
        }
        keyboard.delegate = self
        privacyMonitor.referenceView = view
        privacyMonitor.onEvent = { [weak self] event in self?.handle(event) }

        activate(primaryField)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshPrivacyState()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearSensitiveInput(sendsChange: false)
    }

    /// Wipes everything typed so far and starts over at the first field.
    public func clearSensitiveInput() {
        clearSensitiveInput(sendsChange: true)
        delegate?.securePINEntryViewControllerDidClearSensitiveInput(self)
    }

    /// Clears the input and covers the screen with `reason`.
    public func lockForPrivacy(reason: String, allowsContinue: Bool = false) {
        clearSensitiveInput()
        setInputLocked(true)
        shield.show(message: reason, allowsContinue: allowsContinue)
    }

    /// Removes the cover unless recording or device lock still require it.
    public func refreshPrivacyState() {
        if configuration.protectsAgainstScreenCapture && privacyMonitor.isScreenCaptured {
            lockForPrivacy(reason: configuration.texts.shieldScreenCapture)
        } else if !privacyMonitor.isProtectedDataAvailable {
            lockForPrivacy(reason: configuration.texts.shieldDeviceLocked)
        } else {
            setInputLocked(false)
            shield.hide()
        }
    }

    /// Pops when pushed, dismisses when presented.
    public func close() {
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: Layout

    private func setupLayout() {
        protectedContentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(protectedContentView)
        let contentRoot = protectedContentView.contentView
        contentRoot.backgroundColor = .systemGroupedBackground

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(scrollView)

        let badge = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        badge.tintColor = .white
        badge.contentMode = .scaleAspectFit
        badge.translatesAutoresizingMaskIntoConstraints = false

        let badgeContainer = UIView()
        badgeContainer.backgroundColor = configuration.accentColor
        badgeContainer.layer.cornerRadius = 14
        badgeContainer.layer.cornerCurve = .continuous
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badge)

        let titleLabel = UILabel()
        titleLabel.text = configuration.texts.title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = configuration.texts.subtitle
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let headerStack = UIStackView(arrangedSubviews: [badgeContainer, titleStack])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 14

        let pinPanel = UIView()
        pinPanel.backgroundColor = .systemBackground
        pinPanel.layer.cornerRadius = 18
        pinPanel.layer.cornerCurve = .continuous
        pinPanel.translatesAutoresizingMaskIntoConstraints = false

        statusPill.layer.cornerRadius = 14
        statusPill.layer.cornerCurve = .continuous
        statusPill.translatesAutoresizingMaskIntoConstraints = false

        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.numberOfLines = 0

        let statusStack = UIStackView(arrangedSubviews: [statusIcon, statusLabel])
        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusStack)
        setReadyStatus()

        let fieldStack = UIStackView(arrangedSubviews: [primaryField, confirmationField, statusPill].compactMap { $0 })
        fieldStack.axis = .vertical
        fieldStack.spacing = 18
        fieldStack.translatesAutoresizingMaskIntoConstraints = false
        pinPanel.addSubview(fieldStack)

        let contentStack = UIStackView(arrangedSubviews: [headerStack, pinPanel])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(keyboard)
        // Leave room for the PIN on short screens / landscape.
        let keyboardMaxHeight = keyboard.heightAnchor.constraint(lessThanOrEqualTo: contentRoot.heightAnchor, multiplier: 0.55)

        NSLayoutConstraint.activate([
            protectedContentView.topAnchor.constraint(equalTo: view.topAnchor),
            protectedContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            protectedContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            protectedContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: contentRoot.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentRoot.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentRoot.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboard.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            badgeContainer.widthAnchor.constraint(equalToConstant: 48),
            badgeContainer.heightAnchor.constraint(equalToConstant: 48),
            badge.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),

            fieldStack.topAnchor.constraint(equalTo: pinPanel.topAnchor, constant: 20),
            fieldStack.leadingAnchor.constraint(equalTo: pinPanel.leadingAnchor, constant: 18),
            fieldStack.trailingAnchor.constraint(equalTo: pinPanel.trailingAnchor, constant: -18),
            fieldStack.bottomAnchor.constraint(equalTo: pinPanel.bottomAnchor, constant: -18),

            statusStack.topAnchor.constraint(equalTo: statusPill.topAnchor, constant: 9),
            statusStack.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 12),
            statusStack.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -12),
            statusStack.bottomAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: -9),
            statusIcon.widthAnchor.constraint(equalToConstant: 14),
            statusIcon.heightAnchor.constraint(equalToConstant: 14),

            keyboard.leadingAnchor.constraint(equalTo: contentRoot.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: contentRoot.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: contentRoot.bottomAnchor),
            keyboardMaxHeight
        ])
    }

    private func setupShield() {
        shield.translatesAutoresizingMaskIntoConstraints = false
        shield.onContinue = { [weak self] in self?.refreshPrivacyState() }
        view.addSubview(shield)
        NSLayoutConstraint.activate([
            shield.topAnchor.constraint(equalTo: view.topAnchor),
            shield.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shield.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shield.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: Input

    private func activate(_ field: SecurePINFieldView) {
        guard !isInputLocked else { return }
        activeField = field
        primaryField.isActive = field === primaryField
        confirmationField?.isActive = field === confirmationField
    }

    private func pinChanged() {
        switch configuration.entryMode {
        case .singleEntry:
            guard primaryField.isComplete else { return setReadyStatus() }
            let pin = primaryField.copyPINBytes()
            clearSensitiveInput(sendsChange: false)
            setStatus(configuration.texts.statusEntered, color: configuration.successColor, iconName: "checkmark.circle.fill")
            delegate?.securePINEntryViewController(self, didCompleteWith: pin)

        case .confirmEntry:
            guard let confirmationField, primaryField.isComplete, confirmationField.isComplete else {
                return setReadyStatus()
            }
            if primaryField.securelyMatches(confirmationField) {
                let pin = primaryField.copyPINBytes()
                clearSensitiveInput(sendsChange: false)
                setStatus(configuration.texts.statusMatched, color: configuration.successColor, iconName: "checkmark.circle.fill")
                delegate?.securePINEntryViewController(self, didCompleteWith: pin)
            } else {
                clearSensitiveInput(sendsChange: false)
                primaryField.showError()
                confirmationField.showError()
                setStatus(configuration.texts.statusMismatch, color: configuration.errorColor, iconName: "xmark.circle.fill")
                delegate?.securePINEntryViewController(self, didFailWith: .confirmationMismatch)
            }
        }
    }

    private func clearSensitiveInput(sendsChange: Bool) {
        primaryField.clear(sendsChange: false)
        confirmationField?.clear(sendsChange: false)
        isInputLocked = false
        activate(primaryField)
        keyboard.reshuffleIfNeeded()
        if sendsChange { setReadyStatus() }
    }

    private func setInputLocked(_ locked: Bool) {
        isInputLocked = locked
        primaryField.isUserInteractionEnabled = !locked
        confirmationField?.isUserInteractionEnabled = !locked
        keyboard.isUserInteractionEnabled = !locked
    }

    private func setReadyStatus() {
        setStatus(configuration.texts.statusReady, color: configuration.accentColor, iconName: "lock.fill")
    }

    private func setStatus(_ text: String, color: UIColor, iconName: String) {
        statusLabel.text = text
        statusLabel.textColor = color
        statusIcon.image = UIImage(systemName: iconName)
        statusIcon.tintColor = color
        statusPill.backgroundColor = color.withAlphaComponent(0.10)
    }

    // MARK: Privacy

    private func handle(_ event: SecureKeyboardPrivacyMonitor.Event) {
        let texts = configuration.texts
        switch event {
        case .screenCaptureStarted, .screenCaptureEnded, .appDidBecomeActive, .protectedDataDidBecomeAvailable:
            refreshPrivacyState()
        case .screenshotTaken:
            guard configuration.clearsOnScreenshot else { return }
            lockForPrivacy(reason: texts.shieldScreenshot, allowsContinue: true)
        case .appWillResignActive:
            guard configuration.clearsWhenAppResignsActive else { return }
            lockForPrivacy(reason: texts.shieldAppInactive)
        case .protectedDataWillBecomeUnavailable:
            lockForPrivacy(reason: texts.shieldDeviceLocked)
        }
    }
}

extension SecurePINEntryViewController: SecurePINKeyboardViewDelegate {

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int) {
        guard !isInputLocked else {
            delegate?.securePINEntryViewController(self, didFailWith: .inputLocked)
            return
        }
        guard let field = activeField else { return }
        field.append(digit: digit)
        if field === primaryField, field.isComplete, let confirmationField {
            activate(confirmationField)
        }
    }

    public func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView) {
        guard !isInputLocked else {
            delegate?.securePINEntryViewController(self, didFailWith: .inputLocked)
            return
        }
        guard let field = activeField else { return }
        if field.isEmpty, field === confirmationField {
            activate(primaryField)
            primaryField.deleteBackward()
        } else {
            field.deleteBackward()
        }
    }

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapAccessoryKey key: SecureKeyboardAccessoryKey) {
        switch key {
        case .clear: clearSensitiveInput()
        case .done: close()
        case .none: break
        }
    }
}
