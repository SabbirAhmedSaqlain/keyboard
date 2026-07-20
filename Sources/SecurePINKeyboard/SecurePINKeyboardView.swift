import UIKit

public protocol SecurePINKeyboardViewDelegate: AnyObject {
    func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int)
    func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView)
}

public final class SecurePINKeyboardView: UIView {

    public weak var delegate: SecurePINKeyboardViewDelegate?
    public var shufflesAfterEachTap = true

    private var digitButtons: [UIButton] = []
    private var digitByButton: [ObjectIdentifier: Int] = [:]
    private var backspaceButton = UIButton(type: .custom)
    private let stack = UIStackView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { shuffle() }
    }

    public func shuffle() {
        var generator = SystemRandomNumberGenerator()
        let digits = Array(0...9).shuffled(using: &generator)
        digitByButton.removeAll(keepingCapacity: true)
        for (button, digit) in zip(digitButtons, digits) {
            button.setTitle("\(digit)", for: .normal)
            digitByButton[ObjectIdentifier(button)] = digit
        }
    }

    private func setup() {
        backgroundColor = SecurePINStyle.surface
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: -8)
        isMultipleTouchEnabled = false
        accessibilityElementsHidden = true

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])

        for row in 0..<4 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 12
            stack.addArrangedSubview(rowStack)

            for col in 0..<3 {
                let index = row * 3 + col
                if index < 9 || index == 10 {
                    let button = makeKeyButton()
                    button.addTarget(self, action: #selector(digitTapped(_:)), for: .touchUpInside)
                    digitButtons.append(button)
                    rowStack.addArrangedSubview(button)
                } else if index == 9 {
                    rowStack.addArrangedSubview(UIView())
                } else {
                    backspaceButton = makeKeyButton()
                    if let image = SecurePINStyle.image(named: "delete.left") {
                        backspaceButton.setImage(image, for: .normal)
                        backspaceButton.tintColor = SecurePINStyle.primaryText
                    } else {
                        backspaceButton.setTitle("Del", for: .normal)
                    }
                    backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
                    rowStack.addArrangedSubview(backspaceButton)
                }
            }
        }
    }

    private func makeKeyButton() -> UIButton {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: 30, weight: .semibold)
        button.setTitleColor(SecurePINStyle.primaryText, for: .normal)
        button.setTitleColor(SecurePINStyle.primaryText, for: .highlighted)
        button.backgroundColor = SecurePINStyle.elevatedSurface
        button.layer.cornerRadius = 16
        SecurePINStyle.applyContinuousCornerCurve(to: button.layer)
        button.layer.borderWidth = 1
        button.layer.borderColor = SecurePINStyle.separator.withAlphaComponent(0.25).cgColor
        button.isExclusiveTouch = true
        button.isMultipleTouchEnabled = false
        button.isAccessibilityElement = false
        button.accessibilityLabel = nil
        button.accessibilityValue = nil
        button.tag = -1
        return button
    }

    @objc private func digitTapped(_ sender: UIButton) {
        guard let digit = digitByButton[ObjectIdentifier(sender)] else { return }
        delegate?.securePINKeyboardView(self, didTapDigit: digit)
        if shufflesAfterEachTap { shuffle() }
    }

    @objc private func backspaceTapped() {
        delegate?.securePINKeyboardViewDidTapBackspace(self)
        if shufflesAfterEachTap { shuffle() }
    }
}

/// Drop-in replacement for the legacy `SeucreKeyboard` (`KonaCustomKeyboard`).
///
/// It installs a shuffled `SecurePINKeyboardView` as the `inputView` of one or
/// more PIN text fields, so the system keyboard never appears. Each registered
/// field stays the source of truth for its `text`, meaning all existing
/// validation (fired through `.editingChanged` / `DfsTextField.textDidChange`)
/// keeps working unchanged. Digits are routed to whichever registered field is
/// currently the first responder, so screens with multiple PIN fields (e.g.
/// Change PIN, Set PIN) are supported automatically.
public final class SecurePINKeyboardCoordinator: NSObject {

    private let keyboard = SecurePINKeyboardView()
    private var fields: [UITextField] = []
    private var boxByField: [ObjectIdentifier: SecurePINBoxView] = [:]
    private var isObservingScreenCapture = false
    private let keyboardHeight: CGFloat

    public init(shufflesAfterEachTap: Bool = false, height: CGFloat = 320) {
        self.keyboardHeight = height
        super.init()
        keyboard.delegate = self
        keyboard.shufflesAfterEachTap = shufflesAfterEachTap
        keyboard.frame = CGRect(x: 0,
                                y: 0,
                                width: UIScreen.main.bounds.width,
                                height: keyboardHeight)
        keyboard.autoresizingMask = [.flexibleWidth]
        keyboard.translatesAutoresizingMaskIntoConstraints = true
        startScreenCaptureObservation()
    }

    /// Installs the secure keyboard as the field's input view and overlays a
    /// generic `SecurePINBoxView` (the same design used by the login screen) on
    /// top of the field. The real `DfsTextField` stays the first responder and
    /// source of truth for its `text`, so all existing validation (fired through
    /// `.editingChanged` / `textFieldDidEndEditing`) keeps working unchanged; the
    /// box only renders the entered-digit dots. The `delegate` parameter is
    /// accepted for source-compatibility with the legacy API and is ignored.
    @discardableResult
    public func registerTextField(_ textField: UITextField,
                                  title: String? = nil,
                                  delegate: UITextFieldDelegate? = nil) -> SecurePINKeyboardCoordinator {
        guard boxByField[ObjectIdentifier(textField)] == nil else { return self }

        textField.inputView = keyboard
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        // The generic box renders the PIN; hide the field's own text / caret.
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.addTarget(self, action: #selector(fieldTextChanged(_:)), for: .editingChanged)
        textField.addTarget(self, action: #selector(fieldEditingDidBegin(_:)), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(fieldEditingDidEnd(_:)), for: .editingDidEnd)

        let boxTitle = title ?? String.getLocalizedString(key: "NAGAD_PIN")
        let box = SecurePINBoxView(title: boxTitle, length: maxLength(for: textField))
        box.translatesAutoresizingMaskIntoConstraints = false
        box.onActivate = { [weak textField] in textField?.becomeFirstResponder() }

        if let container = textField.superview {
            container.addSubview(box)
            NSLayoutConstraint.activate([
                box.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                box.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
                box.boxTopAnchor.constraint(equalTo: textField.topAnchor)
            ])
        }
        box.setFilledCount(textField.text?.count ?? 0)

        fields.append(textField)
        boxByField[ObjectIdentifier(textField)] = box
        return self
    }

    @objc private func fieldTextChanged(_ field: UITextField) {
        boxByField[ObjectIdentifier(field)]?.setFilledCount(field.text?.count ?? 0)
    }

    @objc private func fieldEditingDidBegin(_ field: UITextField) {
        for (identifier, box) in boxByField {
            box.isActive = (identifier == ObjectIdentifier(field))
        }
    }

    @objc private func fieldEditingDidEnd(_ field: UITextField) {
        boxByField[ObjectIdentifier(field)]?.isActive = false
    }

    /// Clears every registered field's text and reshuffles the keys.
    public func clearAll() {
        for field in fields {
            field.text = ""
            field.sendActions(for: .editingChanged)
        }
        keyboard.shuffle()
    }

    private func activeField() -> UITextField? {
        fields.first(where: { $0.isFirstResponder })
    }

    private func maxLength(for field: UITextField) -> Int {
        let configured = (field as? DfsTextField)?.maxLength ?? Int.max
        return configured == Int.max ? AppConfig.dfsPinLength : configured
    }

    private func startScreenCaptureObservation() {
        guard !isObservingScreenCapture else { return }
        isObservingScreenCapture = true
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(handleScreenCaptureStateChanged),
                           name: UIScreen.capturedDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleUserDidTakeScreenshot),
                           name: UIApplication.userDidTakeScreenshotNotification,
                           object: nil)
    }

    @objc private func handleScreenCaptureStateChanged() {
        if UIScreen.main.isCaptured { clearAll() }
    }

    @objc private func handleUserDidTakeScreenshot() {
        clearAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension SecurePINKeyboardCoordinator: SecurePINKeyboardViewDelegate {

    public func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int) {
        guard let field = activeField() else { return }
        let currentCount = field.text?.count ?? 0
        guard currentCount < maxLength(for: field) else { return }
        field.insertText("\(digit)")
    }

    public func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView) {
        guard let field = activeField() else { return }
        guard (field.text?.isEmpty == false) else { return }
        field.deleteBackward()
    }
}

/// Generic PIN input box matching the login screen design: a white rounded box
/// with a solid lock icon on the left and centred masked dots.
///
/// It supports two usage modes:
/// * **Buffered** — the box owns the PIN (`append` / `deleteBackward` /
///   `copyPINBytes`), used directly by screens like `LoginViewController`.
/// * **Display-only** — an external `UITextField` owns the PIN and the box only
///   mirrors how many digits are entered (`setFilledCount`), used by
///   `SecurePINKeyboardCoordinator`.
public final class SecurePINBoxView: UIView {

    public var onChange: (() -> Void)?
    public var onActivate: (() -> Void)?

    /// Optional caption rendered on top of the white box. When `nil`/empty the
    /// caption collapses and the view is just the box (used by screens that
    /// already show their own title).
    public var title: String? {
        didSet {
            titleLabel.text = title
            titleLabel.isHidden = (title?.isEmpty ?? true)
        }
    }

    public let length: Int
    private var storage: [UInt8]
    private(set) public var count = 0
    private var displayCount = 0

    private let titleLabel = UILabel()
    private let boxView = UIView()
    private let lockImageView = UIImageView()
    private let dotsStack = UIStackView()
    private var dots: [UIView] = []

    private let emptyDotColor = UIColor(white: 0.78, alpha: 1)
    private let filledDotColor = UIColor(white: 0.1, alpha: 1)
    private let inactiveBorderColor = UIColor(white: 0.85, alpha: 1)

    /// When `true`, the box border uses `ThemeUtility.currentTheme.primaryColor`
    /// (resolved from `themeID`); otherwise the inactive gray border is used.
    public var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else { return }
            updateBorderColor()
        }
    }

    public var isComplete: Bool { count == length }
    public var isEmpty: Bool { count == 0 }

    /// Top anchor of the inner white box. Align this to the field the box
    /// visually replaces so any caption sits above the field.
    public var boxTopAnchor: NSLayoutYAxisAnchor { boxView.topAnchor }

    public init(title: String? = nil, length: Int = 4) {
        self.length = max(1, min(length, 12))
        self.storage = Array(repeating: 0, count: max(1, min(length, 12)))
        super.init(frame: .zero)
        self.title = title
        setup()
    }

    public required init?(coder: NSCoder) {
        self.length = 4
        self.storage = Array(repeating: 0, count: 4)
        super.init(coder: coder)
        setup()
    }

    deinit {
        clear(sendsChange: false)
    }

    // MARK: Buffered API (box owns the PIN)

    public func append(digit: Int) {
        guard count < length, (0...9).contains(digit) else { return }
        storage[count] = UInt8(digit)
        count += 1
        displayCount = count
        updateDots()
        onChange?()
    }

    public func deleteBackward() {
        guard count > 0 else { return }
        count -= 1
        storage[count] = 0
        displayCount = count
        updateDots()
        onChange?()
    }

    public func clear(sendsChange: Bool = true) {
        if count == 0 && displayCount == 0 {
            if sendsChange { onChange?() }
            return
        }
        storage.withUnsafeMutableBytes { bytes in
            if let base = bytes.baseAddress {
                _ = memset(base, 0, bytes.count)
            }
        }
        count = 0
        displayCount = 0
        updateDots()
        if sendsChange { onChange?() }
    }

    public func copyPINBytes() -> [UInt8] {
        Array(storage.prefix(count))
    }

    // MARK: Display-only API (external field owns the PIN)

    public func setFilledCount(_ n: Int) {
        displayCount = max(0, min(n, length))
        updateDots()
    }

    // MARK: Setup

    private func setup() {
        backgroundColor = .clear

        titleLabel.text = title
        titleLabel.isHidden = (title?.isEmpty ?? true)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.4, alpha: 1)
        titleLabel.numberOfLines = 1

        boxView.backgroundColor = .white
        boxView.layer.cornerRadius = 12
        boxView.layer.borderWidth = 1
        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        updateBorderColor()

        lockImageView.image = UIImage(named: "ic_pin_solid")?.withRenderingMode(.alwaysTemplate)
        lockImageView.tintColor = UIColor(white: 0.55, alpha: 1)
        lockImageView.contentMode = .scaleAspectFit
        lockImageView.translatesAutoresizingMaskIntoConstraints = false
        boxView.addSubview(lockImageView)

        dotsStack.axis = .horizontal
        dotsStack.alignment = .center
        dotsStack.distribution = .equalSpacing
        dotsStack.spacing = 22
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        boxView.addSubview(dotsStack)

        for _ in 0..<length {
            let dot = UIView()
            dot.backgroundColor = emptyDotColor
            dot.layer.cornerRadius = 6
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12)
            ])
            dots.append(dot)
            dotsStack.addArrangedSubview(dot)
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, boxView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            lockImageView.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 16),
            lockImageView.centerYAnchor.constraint(equalTo: boxView.centerYAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 20),
            lockImageView.heightAnchor.constraint(equalToConstant: 20),

            dotsStack.centerXAnchor.constraint(equalTo: boxView.centerXAnchor),
            dotsStack.centerYAnchor.constraint(equalTo: boxView.centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title ?? "PIN"
        updateDots()
    }

    @objc private func handleTap() {
        onActivate?()
    }

    private func updateBorderColor() {
        let color: UIColor
        if isActive {
            // ThemeUtility.currentTheme already resolves by themeID (Basic / Islamic).
            color = ThemeUtility.currentTheme.primaryColor
        } else {
            color = inactiveBorderColor
        }
        boxView.layer.borderColor = color.cgColor
    }

    private func updateDots() {
        for (index, dot) in dots.enumerated() {
            dot.backgroundColor = index < displayCount ? filledDotColor : emptyDotColor
        }
        accessibilityValue = "\(displayCount) of \(length) digits entered"
    }
}
