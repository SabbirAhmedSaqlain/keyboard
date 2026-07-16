//
//  DashboardViewController.swift
//  keyboard
//
//  Dashboard shown on launch. Two 4-digit PIN fields at the top, driven
//  exclusively by the custom SecureKeyboardView pinned to the bottom.
//

import UIKit

final class DashboardViewController: UIViewController {

    private let pinField = PinInputView(title: "Enter PIN")
    private let confirmField = PinInputView(title: "Confirm PIN")
    private let keyboard = SecureKeyboardView()
    private let statusPill = UIView()
    private let statusIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let statusLabel = UILabel()
    private let protectedContentView = ScreenCaptureProtectedView()
    private let privacyShield = UIView()
    private let privacyShieldLabel = UILabel()
    private let privacyShieldIcon = UIImageView(image: UIImage(systemName: "lock.shield"))

    private var activeField: PinInputView?
    private var isInputLocked = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Secure PIN"

        setupLayout()
        setupPrivacyShield()
        registerPrivacyObservers()

        pinField.onActivate = { [weak self] field in self?.activate(field) }
        confirmField.onActivate = { [weak self] field in self?.activate(field) }
        pinField.onChange = { [weak self] _ in self?.pinChanged() }
        confirmField.onChange = { [weak self] _ in self?.pinChanged() }
        keyboard.delegate = self

        activate(pinField)
        refreshPrivacyState()
    }

    private func setupLayout() {
        protectedContentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(protectedContentView)
        let contentRoot = protectedContentView.contentView
        contentRoot.backgroundColor = .systemGroupedBackground

        let contentScrollView = UIScrollView()
        contentScrollView.alwaysBounceVertical = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.contentInsetAdjustmentBehavior = .never
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(contentScrollView)

        let badge = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        badge.tintColor = .white
        badge.contentMode = .scaleAspectFit
        badge.translatesAutoresizingMaskIntoConstraints = false

        let badgeContainer = UIView()
        badgeContainer.backgroundColor = .systemIndigo
        badgeContainer.layer.cornerRadius = 20
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badge)

        let titleLabel = UILabel()
        titleLabel.text = "Secure PIN"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Create a 4-digit code"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
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
        pinPanel.layer.borderWidth = 1
        pinPanel.layer.borderColor = UIColor.separator.withAlphaComponent(0.45).cgColor
        pinPanel.translatesAutoresizingMaskIntoConstraints = false

        statusPill.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.10)
        statusPill.layer.cornerRadius = 14
        statusPill.layer.cornerCurve = .continuous
        statusPill.translatesAutoresizingMaskIntoConstraints = false

        statusIcon.tintColor = .systemIndigo
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .systemIndigo
        statusLabel.numberOfLines = 0
        statusLabel.text = "Ready"

        let statusStack = UIStackView(arrangedSubviews: [statusIcon, statusLabel])
        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusStack)

        let fieldStack = UIStackView(arrangedSubviews: [pinField, confirmField, statusPill])
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
        privacyShield.backgroundColor = .systemBackground
        privacyShield.isHidden = true
        privacyShield.translatesAutoresizingMaskIntoConstraints = false
        privacyShield.accessibilityViewIsModal = true
        privacyShield.isAccessibilityElement = true
        privacyShield.accessibilityLabel = "Secure input hidden"
        view.addSubview(privacyShield)

        privacyShieldIcon.tintColor = .label
        privacyShieldIcon.contentMode = .scaleAspectFit
        privacyShieldIcon.translatesAutoresizingMaskIntoConstraints = false
        privacyShieldIcon.setContentHuggingPriority(.required, for: .vertical)

        privacyShieldLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        privacyShieldLabel.textAlignment = .center
        privacyShieldLabel.textColor = .label
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
    }

    private func activate(_ field: PinInputView) {
        guard !isInputLocked else { return }
        setActiveField(field)
    }

    private func setActiveField(_ field: PinInputView) {
        activeField = field
        pinField.isActive = field === pinField
        confirmField.isActive = field === confirmField
    }

    private func pinChanged() {
        guard pinField.isComplete, confirmField.isComplete else {
            setStatus("Ready", color: .systemIndigo, iconName: "lock.fill")
            return
        }
        let pinsMatch = pinField.securelyMatches(confirmField)
        clearSensitiveInput(sendsChange: false)

        if pinsMatch {
            setStatus("PINs match", color: .systemGreen, iconName: "checkmark.circle.fill")
        } else {
            setStatus("PINs do not match", color: .systemRed, iconName: "xmark.circle.fill")
        }
    }

    func lockForPrivacy(reason: String) {
        clearSensitiveInput()
        setPrivacyShield(isVisible: true, reason: reason)
    }

    func refreshPrivacyState() {
        if UIScreen.main.isCaptured {
            lockForPrivacy(reason: "Screen capture detected. Secure input is hidden.")
            return
        }

        if !UIApplication.shared.isProtectedDataAvailable {
            lockForPrivacy(reason: "Protected data is unavailable. Secure input is hidden.")
            return
        }

        setPrivacyShield(isVisible: false, reason: nil)
    }

    private func clearSensitiveInput(sendsChange: Bool = true) {
        pinField.clear(sendsChange: sendsChange)
        confirmField.clear(sendsChange: sendsChange)
        setActiveField(pinField)
        keyboard.shuffle()
        if sendsChange {
            pinChanged()
        }
    }

    private func setPrivacyShield(isVisible: Bool, reason: String?) {
        isInputLocked = isVisible
        pinField.isUserInteractionEnabled = !isVisible
        confirmField.isUserInteractionEnabled = !isVisible
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
        statusIcon.image = UIImage(systemName: iconName)
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
        lockForPrivacy(reason: "Screenshot detected. Secure input was cleared.")
    }
}

extension DashboardViewController: SecureKeyboardDelegate {

    func secureKeyboard(_ keyboard: SecureKeyboardView, didTapDigit digit: Int) {
        guard !isInputLocked else { return }
        guard let field = activeField else { return }
        field.append(digit: digit)
        // Auto-advance to the confirm field once the first PIN is complete.
        if field === pinField, field.isComplete {
            activate(confirmField)
        }
    }

    func secureKeyboardDidTapBackspace(_ keyboard: SecureKeyboardView) {
        guard !isInputLocked else { return }
        guard let field = activeField else { return }
        if field.isEmpty, field === confirmField {
            activate(pinField)
            pinField.deleteBackward()
        } else {
            field.deleteBackward()
        }
    }
}
