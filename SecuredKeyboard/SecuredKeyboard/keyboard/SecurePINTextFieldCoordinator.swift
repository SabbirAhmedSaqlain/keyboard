import UIKit

/// Drop-in secure keyboard for existing `UITextField`-based PIN screens.
///
/// Each registered field gets the secure keypad as its `inputView` (so the
/// system keyboard never appears) and a display-only `SecurePINFieldView`
/// laid over it. The text field stays first responder and the source of truth
/// for `text`, so existing `.editingChanged` / delegate validation keeps
/// working. Digits go to whichever registered field is first responder, so
/// screens with several PIN fields (change PIN, set PIN) work automatically.
///
/// Note: the PIN lives in `UITextField.text` (a `String`) in this mode. Prefer
/// `SecurePINKeyboardPanel` or `SecurePINEntryViewController` for new screens;
/// they keep it in a zeroing buffer.
///
///     coordinator = SecurePINTextFieldCoordinator()
///     coordinator.register(currentPINField, title: "Current PIN")
///     coordinator.register(newPINField, title: "New PIN")
public final class SecurePINTextFieldCoordinator: NSObject {

    public let configuration: SecureKeyboardConfiguration

    private let keyboard: SecurePINKeyboardView
    private let inputContainer: UIInputView
    private let privacyMonitor = SecureKeyboardPrivacyMonitor()
    private var fields: [UITextField] = []
    private var overlayByField: [ObjectIdentifier: SecurePINFieldView] = [:]
    private var maxLengthByField: [ObjectIdentifier: Int] = [:]

    public init(configuration: SecureKeyboardConfiguration = SecureKeyboard.configuration) {
        self.configuration = configuration
        self.keyboard = SecurePINKeyboardView(configuration: configuration)
        self.inputContainer = UIInputView(frame: .zero, inputViewStyle: .default)
        super.init()

        keyboard.delegate = self
        buildInputView()
        privacyMonitor.onEvent = { [weak self] event in self?.handle(event) }
    }

    /// Installs the secure keypad on `textField` and overlays the PIN display.
    ///
    /// - Parameters:
    ///   - title: Caption drawn above the field (needs room above it), or `nil`.
    ///   - maxLength: Digits accepted; defaults to `configuration.pinLength`.
    @discardableResult
    public func register(_ textField: UITextField,
                         title: String? = nil,
                         maxLength: Int? = nil) -> SecurePINTextFieldCoordinator {
        let id = ObjectIdentifier(textField)
        guard overlayByField[id] == nil else { return self }

        let length = maxLength ?? configuration.pinLength
        textField.inputView = inputContainer
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        // The overlay renders the PIN; hide the field's own text and caret.
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.addTarget(self, action: #selector(fieldTextChanged(_:)), for: .editingChanged)
        textField.addTarget(self, action: #selector(fieldEditingDidBegin(_:)), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(fieldEditingDidEnd(_:)), for: .editingDidEnd)

        let overlay = SecurePINFieldView(title: title, length: length, configuration: configuration)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onActivate = { [weak textField] _ in textField?.becomeFirstResponder() }

        if let container = textField.superview {
            container.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
                overlay.boxTopAnchor.constraint(equalTo: textField.topAnchor)
            ])
        }
        overlay.setFilledCount(textField.text?.count ?? 0)

        if privacyMonitor.referenceView == nil {
            privacyMonitor.referenceView = textField
        }
        fields.append(textField)
        overlayByField[id] = overlay
        maxLengthByField[id] = length
        return self
    }

    /// Clears every registered field and gives the keypad a fresh layout.
    public func clearAll() {
        for field in fields where !(field.text ?? "").isEmpty {
            field.text = ""
            field.sendActions(for: .editingChanged)
        }
        keyboard.reshuffleIfNeeded()
    }

    /// Shows the error state on one field's overlay (e.g. wrong PIN).
    public func showError(on textField: UITextField, shake: Bool = true) {
        overlayByField[ObjectIdentifier(textField)]?.showError(shake: shake)
    }

    // MARK: Private

    private func buildInputView() {
        inputContainer.allowsSelfSizing = true
        inputContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let parent: UIView
        if configuration.protectsAgainstScreenCapture {
            let protected = ScreenCaptureProtectedView()
            protected.translatesAutoresizingMaskIntoConstraints = false
            inputContainer.addSubview(protected)
            pin(protected, to: inputContainer)
            parent = protected.contentView
        } else {
            parent = inputContainer
        }
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(keyboard)
        pin(keyboard, to: parent)
    }

    private func pin(_ view: UIView, to target: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: target.topAnchor),
            view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])
    }

    private func activeField() -> UITextField? {
        fields.first { $0.isFirstResponder }
    }

    @objc private func fieldTextChanged(_ field: UITextField) {
        overlayByField[ObjectIdentifier(field)]?.setFilledCount(field.text?.count ?? 0)
    }

    @objc private func fieldEditingDidBegin(_ field: UITextField) {
        if configuration.protectsAgainstScreenCapture && privacyMonitor.isScreenCaptured {
            field.resignFirstResponder()
            return
        }
        for (id, overlay) in overlayByField {
            overlay.isActive = id == ObjectIdentifier(field)
        }
    }

    @objc private func fieldEditingDidEnd(_ field: UITextField) {
        overlayByField[ObjectIdentifier(field)]?.isActive = false
    }

    private func handle(_ event: SecureKeyboardPrivacyMonitor.Event) {
        switch event {
        case .screenCaptureStarted:
            guard configuration.protectsAgainstScreenCapture else { return }
            clearAll()
            activeField()?.resignFirstResponder()
        case .screenshotTaken:
            if configuration.clearsOnScreenshot { clearAll() }
        case .appWillResignActive:
            if configuration.clearsWhenAppResignsActive { clearAll() }
        case .protectedDataWillBecomeUnavailable:
            clearAll()
            activeField()?.resignFirstResponder()
        case .screenCaptureEnded, .appDidBecomeActive, .protectedDataDidBecomeAvailable:
            break
        }
    }
}

extension SecurePINTextFieldCoordinator: SecurePINKeyboardViewDelegate {

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int) {
        guard let field = activeField() else { return }
        let limit = maxLengthByField[ObjectIdentifier(field)] ?? configuration.pinLength
        guard (field.text?.count ?? 0) < limit else { return }
        field.insertText("\(digit)")
    }

    public func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView) {
        guard let field = activeField(), field.text?.isEmpty == false else { return }
        field.deleteBackward()
    }

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapAccessoryKey key: SecureKeyboardAccessoryKey) {
        guard let field = activeField() else { return }
        switch key {
        case .clear:
            guard field.text?.isEmpty == false else { return }
            field.text = ""
            field.sendActions(for: .editingChanged)
        case .done:
            field.resignFirstResponder()
        case .none:
            break
        }
    }
}
