import UIKit

public final class SecurePINEntryViewController: UIViewController {

    public weak var delegate: SecurePINEntryViewControllerDelegate?

    private let configuration: SecurePINConfiguration
    private let primaryField: SecurePINInputView
    private let confirmationField: SecurePINInputView?
    private let keyboard = SecurePINKeyboardView()
    private let protectedContentView = ScreenCaptureProtectedView()
    private let statusPill = UIView()
    private let statusIcon = UIImageView(image: SecurePINStyle.image(named: "lock.fill"))
    private let statusLabel = UILabel()
    private let privacyShield = UIView()
    private let privacyShieldLabel = UILabel()
    private let privacyShieldIcon = UIImageView(image: SecurePINStyle.image(named: "lock.shield"))

    private var activeField: SecurePINInputView?
    private var isInputLocked = false

    public init(configuration: SecurePINConfiguration = SecurePINConfiguration()) {
        self.configuration = configuration
        self.primaryField = SecurePINInputView(
            title: configuration.primaryPINTitle,
            length: configuration.pinLength,
            accentColor: configuration.accentColor
        )
        if configuration.mode == .confirmEntry {
            self.confirmationField = SecurePINInputView(
                title: configuration.confirmationPINTitle,
                length: configuration.pinLength,
                accentColor: configuration.accentColor
            )
        } else {
            self.confirmationField = nil
        }
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        self.configuration = SecurePINConfiguration()
        self.primaryField = SecurePINInputView(title: "Enter PIN")
        self.confirmationField = SecurePINInputView(title: "Confirm PIN")
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = configuration.title
        view.backgroundColor = SecurePINStyle.appBackground

        setupLayout()
        setupPrivacyShield()
        registerPrivacyObservers()

        primaryField.onActivate = { [weak self] field in self?.activate(field) }
        primaryField.onChange = { [weak self] _ in self?.pinChanged() }
        confirmationField?.onActivate = { [weak self] field in self?.activate(field) }
        confirmationField?.onChange = { [weak self] _ in self?.pinChanged() }

        keyboard.delegate = self
        keyboard.shufflesAfterEachTap = configuration.shufflesAfterEachTap

        activate(primaryField)
        refreshPrivacyState()
    }

    public func clearSensitiveInput() {
        clearSensitiveInput(sendsChange: true)
        delegate?.securePINEntryViewControllerDidClearSensitiveInput(self)
    }

    public func lockForPrivacy(reason: String) {
        clearSensitiveInput()
        setPrivacyShield(isVisible: true, reason: reason)
    }

    public func refreshPrivacyState() {
        if configuration.protectsAgainstScreenCapture, UIScreen.main.isCaptured {
            lockForPrivacy(reason: "Screen capture detected. Secure input is hidden.")
            return
        }

        if !UIApplication.shared.isProtectedDataAvailable {
            lockForPrivacy(reason: "Protected data is unavailable. Secure input is hidden.")
            return
        }

        setPrivacyShield(isVisible: false, reason: nil)
    }

    private func setupLayout() {
        protectedContentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(protectedContentView)
        let contentRoot = protectedContentView.contentView
        contentRoot.backgroundColor = SecurePINStyle.appBackground

        let contentScrollView = UIScrollView()
        contentScrollView.alwaysBounceVertical = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.contentInsetAdjustmentBehavior = .never
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(contentScrollView)

        let badge = UIImageView(image: SecurePINStyle.image(named: "lock.shield.fill"))
        badge.tintColor = .white
        badge.contentMode = .scaleAspectFit
        badge.translatesAutoresizingMaskIntoConstraints = false
        let badgeFallback = UILabel()
        badgeFallback.text = "PIN"
        badgeFallback.font = .systemFont(ofSize: 11, weight: .bold)
        badgeFallback.textColor = .white
        badgeFallback.textAlignment = .center
        badgeFallback.translatesAutoresizingMaskIntoConstraints = false
        badgeFallback.isHidden = badge.image != nil

        let badgeContainer = UIView()
        badgeContainer.backgroundColor = configuration.accentColor
        badgeContainer.layer.cornerRadius = 20
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badge)
        badgeContainer.addSubview(badgeFallback)

        let titleLabel = UILabel()
        titleLabel.text = configuration.title
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = SecurePINStyle.primaryText
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = configuration.subtitle
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = SecurePINStyle.secondaryText
        subtitleLabel.numberOfLines = 0

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        let headerStack = UIStackView(arrangedSubviews: [badgeContainer, titleStack])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 14

        let pinPanel = UIView()
        pinPanel.backgroundColor = SecurePINStyle.surface
        pinPanel.layer.cornerRadius = 18
        SecurePINStyle.applyContinuousCornerCurve(to: pinPanel.layer)
        pinPanel.layer.borderWidth = 1
        pinPanel.layer.borderColor = SecurePINStyle.separator.withAlphaComponent(0.45).cgColor
        pinPanel.translatesAutoresizingMaskIntoConstraints = false

        statusPill.backgroundColor = configuration.accentColor.withAlphaComponent(0.10)
        statusPill.layer.cornerRadius = 14
        SecurePINStyle.applyContinuousCornerCurve(to: statusPill.layer)
        statusPill.translatesAutoresizingMaskIntoConstraints = false

        statusIcon.tintColor = configuration.accentColor
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = configuration.accentColor
        statusLabel.numberOfLines = 0
        statusLabel.text = "Ready"

        let statusStack = UIStackView(arrangedSubviews: [statusIcon, statusLabel])
        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusStack)

        var fieldViews: [UIView] = [primaryField]
        if let confirmationField {
            fieldViews.append(confirmationField)
        }
        fieldViews.append(statusPill)

        let fieldStack = UIStackView(arrangedSubviews: fieldViews)
        fieldStack.axis = .vertical
        fieldStack.spacing = 18
        fieldStack.translatesAutoresizingMaskIntoConstraints = false
        pinPanel.addSubview(fieldStack)

        let contentStack = UIStackView(arrangedSubviews: [headerStack, pinPanel])
        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(keyboard)

        let keyboardPreferredHeight = keyboard.heightAnchor.constraint(equalToConstant: 340)
        keyboardPreferredHeight.priority = .defaultHigh
        let keyboardMaxHeight = keyboard.heightAnchor.constraint(lessThanOrEqualTo: contentRoot.heightAnchor, multiplier: 0.46)
        keyboardMaxHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            protectedContentView.topAnchor.constraint(equalTo: view.topAnchor),
            protectedContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            protectedContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            protectedContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentScrollView.topAnchor.constraint(equalTo: contentRoot.safeAreaLayoutGuide.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: contentRoot.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: contentRoot.trailingAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: keyboard.topAnchor),

            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor, constant: 34),
            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            badgeContainer.widthAnchor.constraint(equalToConstant: 48),
            badgeContainer.heightAnchor.constraint(equalToConstant: 48),
            badge.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),
            badgeFallback.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeFallback.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badgeFallback.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 4),
            badgeFallback.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -4),

            fieldStack.topAnchor.constraint(equalTo: pinPanel.topAnchor, constant: 22),
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
            keyboardPreferredHeight,
            keyboardMaxHeight
        ])
    }

    private func setupPrivacyShield() {
        privacyShield.backgroundColor = SecurePINStyle.surface
        privacyShield.isHidden = true
        privacyShield.translatesAutoresizingMaskIntoConstraints = false
        privacyShield.accessibilityViewIsModal = true
        privacyShield.isAccessibilityElement = true
        privacyShield.accessibilityLabel = "Secure input hidden"
        view.addSubview(privacyShield)

        privacyShieldIcon.tintColor = SecurePINStyle.primaryText
        privacyShieldIcon.contentMode = .scaleAspectFit
        privacyShieldIcon.translatesAutoresizingMaskIntoConstraints = false
        privacyShieldIcon.setContentHuggingPriority(.required, for: .vertical)

        privacyShieldLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        privacyShieldLabel.textAlignment = .center
        privacyShieldLabel.textColor = SecurePINStyle.primaryText
        privacyShieldLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [privacyShieldIcon, privacyShieldLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        privacyShield.addSubview(stack)

        NSLayoutConstraint.activate([
            privacyShield.topAnchor.constraint(equalTo: view.topAnchor),
            privacyShield.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            privacyShield.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            privacyShield.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            privacyShieldIcon.widthAnchor.constraint(equalToConstant: 44),
            privacyShieldIcon.heightAnchor.constraint(equalToConstant: 44),

            stack.centerXAnchor.constraint(equalTo: privacyShield.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: privacyShield.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: privacyShield.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: privacyShield.trailingAnchor, constant: -32)
        ])
    }

    private func registerPrivacyObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screenCaptureStateChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(protectedDataWillBecomeUnavailable), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        center.addObserver(self, selector: #selector(protectedDataDidBecomeAvailable), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        center.addObserver(self, selector: #selector(userDidTakeScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        center.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        if configuration.clearsWhenAppResignsActive {
            center.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        }
    }

    private func activate(_ field: SecurePINInputView) {
        guard !isInputLocked else { return }
        setActiveField(field)
    }

    private func setActiveField(_ field: SecurePINInputView) {
        activeField = field
        primaryField.isActive = field === primaryField
        confirmationField?.isActive = field === confirmationField
    }

    private func pinChanged() {
        switch configuration.mode {
        case .singleEntry:
            guard primaryField.isComplete else {
                setStatus("Ready", color: configuration.accentColor, iconName: "lock.fill")
                return
            }
            let pin = primaryField.copyPINBytes()
            clearSensitiveInput(sendsChange: false)
            setStatus("PIN entered", color: .systemGreen, iconName: "checkmark.circle.fill")
            delegate?.securePINEntryViewController(self, didCompleteWith: pin)

        case .confirmEntry:
            guard let confirmationField else { return }
            guard primaryField.isComplete, confirmationField.isComplete else {
                setStatus("Ready", color: configuration.accentColor, iconName: "lock.fill")
                return
            }

            if primaryField.securelyMatches(confirmationField) {
                let pin = primaryField.copyPINBytes()
                clearSensitiveInput(sendsChange: false)
                setStatus("PINs match", color: .systemGreen, iconName: "checkmark.circle.fill")
                delegate?.securePINEntryViewController(self, didCompleteWith: pin)
            } else {
                clearSensitiveInput(sendsChange: false)
                setStatus("PINs do not match", color: .systemRed, iconName: "xmark.circle.fill")
                delegate?.securePINEntryViewController(self, didFailWith: .confirmationMismatch)
            }
        }
    }

    private func clearSensitiveInput(sendsChange: Bool) {
        primaryField.clear(sendsChange: sendsChange)
        confirmationField?.clear(sendsChange: sendsChange)
        setActiveField(primaryField)
        keyboard.shuffle()
        if sendsChange {
            pinChanged()
        }
    }

    private func setPrivacyShield(isVisible: Bool, reason: String?) {
        isInputLocked = isVisible
        primaryField.isUserInteractionEnabled = !isVisible
        confirmationField?.isUserInteractionEnabled = !isVisible
        keyboard.isUserInteractionEnabled = !isVisible

        if let reason {
            privacyShieldLabel.text = reason
            privacyShield.accessibilityValue = reason
        }

        privacyShield.isHidden = !isVisible
        if isVisible {
            view.bringSubviewToFront(privacyShield)
        }
    }

    private func setStatus(_ text: String, color: UIColor, iconName: String) {
        statusLabel.text = text
        statusLabel.textColor = color
        statusIcon.image = SecurePINStyle.image(named: iconName)
        statusIcon.tintColor = color
        statusPill.backgroundColor = color.withAlphaComponent(0.10)
    }

    @objc private func screenCaptureStateChanged() {
        refreshPrivacyState()
    }

    @objc private func protectedDataWillBecomeUnavailable() {
        lockForPrivacy(reason: "Device lock detected. Secure input was cleared.")
    }

    @objc private func protectedDataDidBecomeAvailable() {
        refreshPrivacyState()
    }

    @objc private func userDidTakeScreenshot() {
        guard configuration.clearsOnScreenshot else { return }
        lockForPrivacy(reason: "Screenshot detected. Secure input was cleared.")
    }

    @objc private func appWillResignActive() {
        lockForPrivacy(reason: "App inactive. Secure input was cleared.")
    }

    @objc private func appDidBecomeActive() {
        refreshPrivacyState()
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
}
