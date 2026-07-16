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
        view.backgroundColor = .systemBackground
        title = "Dashboard"

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

        let contentScrollView = UIScrollView()
        contentScrollView.alwaysBounceVertical = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.contentInsetAdjustmentBehavior = .never
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(contentScrollView)

        let header = UILabel()
        header.text = "Dashboard"
        header.font = .systemFont(ofSize: 32, weight: .bold)
        header.adjustsFontForContentSizeCategory = true

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Enter a 4-digit PIN using the secure keyboard below."

        let contentStack = UIStackView(arrangedSubviews: [header, pinField, confirmField, statusLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.setCustomSpacing(32, after: header)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        contentRoot.addSubview(keyboard)

        let keyboardPreferredHeight = keyboard.heightAnchor.constraint(equalToConstant: 320)
        keyboardPreferredHeight.priority = .defaultHigh
        let keyboardMaxHeight = keyboard.heightAnchor.constraint(lessThanOrEqualTo: contentRoot.heightAnchor, multiplier: 0.44)
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

            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor, constant: -20),

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
            statusLabel.textColor = .secondaryLabel
            statusLabel.text = "Enter a 4-digit PIN using the secure keyboard below."
            return
        }
        let pinsMatch = pinField.securelyMatches(confirmField)
        clearSensitiveInput(sendsChange: false)

        if pinsMatch {
            statusLabel.textColor = .systemGreen
            statusLabel.text = "PINs match. Secure input was cleared."
        } else {
            statusLabel.textColor = .systemRed
            statusLabel.text = "PINs do not match. Secure input was cleared."
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
