import UIKit

public protocol SecurePINKeyboardViewDelegate: AnyObject {
    func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapDigit digit: Int)
    func securePINKeyboardViewDidTapBackspace(_ keyboard: SecurePINKeyboardView)
    func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapAccessoryKey key: SecureKeyboardAccessoryKey)
}

public extension SecurePINKeyboardViewDelegate {
    func securePINKeyboardView(_ keyboard: SecurePINKeyboardView, didTapAccessoryKey key: SecureKeyboardAccessoryKey) {}
}

/// Numeric keypad with optionally shuffled digits.
///
/// Digits are not exposed to accessibility and the key → digit map is held
/// privately, so the layout cannot be read from the view hierarchy.
public final class SecurePINKeyboardView: UIView {

    public weak var delegate: SecurePINKeyboardViewDelegate?
    public let configuration: SecureKeyboardConfiguration

    private var digitButtons: [SecurePINKeyButton] = []
    private var digitByButton: [ObjectIdentifier: Int] = [:]
    private let stack = UIStackView()
    private lazy var haptics = UIImpactFeedbackGenerator(style: .light)

    public init(configuration: SecureKeyboardConfiguration = SecureKeyboard.configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.configuration = SecureKeyboard.configuration
        super.init(coder: coder)
        setup()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { reshuffleIfNeeded() }
    }

    /// Applies a new random layout unless `shuffleMode` is `.never`.
    /// Call after clearing input so a fresh attempt gets a fresh layout.
    public func reshuffleIfNeeded() {
        guard configuration.shuffleMode != .never else { return }
        var generator = SystemRandomNumberGenerator()
        assignDigits(Array(0...9).shuffled(using: &generator))
    }

    private func assignDigits(_ digits: [Int]) {
        digitByButton.removeAll(keepingCapacity: true)
        for (button, digit) in zip(digitButtons, digits) {
            UIView.performWithoutAnimation {
                button.setTitle("\(digit)", for: .normal)
                button.layoutIfNeeded()
            }
            digitByButton[ObjectIdentifier(button)] = digit
        }
    }

    private func setup() {
        backgroundColor = configuration.keyboardBackgroundColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: -8)
        isMultipleTouchEnabled = false
        accessibilityElementsHidden = true

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = configuration.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // The keypad is `keyboardHeight` tall above the bottom safe area; the
        // host only pins edges and the home-indicator area is added on top.
        let insets = configuration.keyboardInsets
        let keysHeight = stack.heightAnchor.constraint(
            equalToConstant: max(0, configuration.keyboardHeight - insets.top - insets.bottom))
        keysHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -insets.bottom),
            keysHeight
        ])

        // 1 2 3 / 4 5 6 / 7 8 9 / accessory 0 backspace
        for row in 0..<4 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = configuration.keySpacing
            stack.addArrangedSubview(rowStack)

            for col in 0..<3 {
                let index = row * 3 + col
                switch index {
                case 9:
                    rowStack.addArrangedSubview(makeAccessoryKey())
                case 11:
                    rowStack.addArrangedSubview(makeBackspaceKey())
                default:
                    let button = makeKeyButton()
                    button.addTarget(self, action: #selector(digitTapped(_:)), for: .touchUpInside)
                    digitButtons.append(button)
                    rowStack.addArrangedSubview(button)
                }
            }
        }

        assignDigits([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
    }

    private func makeKeyButton() -> SecurePINKeyButton {
        let button = SecurePINKeyButton(normalColor: configuration.keyBackgroundColor,
                                        highlightedColor: configuration.keyHighlightColor)
        button.titleLabel?.font = configuration.keyFont
        button.setTitleColor(configuration.keyTextColor, for: .normal)
        button.setTitleColor(configuration.keyTextColor, for: .highlighted)
        button.tintColor = configuration.keyTextColor
        button.layer.cornerRadius = configuration.keyCornerRadius
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = configuration.keyBorderWidth
        button.layer.borderColor = configuration.keyBorderColor.cgColor
        button.isExclusiveTouch = true
        button.isMultipleTouchEnabled = false
        button.isAccessibilityElement = false
        return button
    }

    private func makeBackspaceKey() -> UIButton {
        let button = makeKeyButton()
        if let image = configuration.backspaceImage {
            button.setImage(image, for: .normal)
            button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold), forImageIn: .normal)
        } else {
            button.setTitle("Del", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        }
        button.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        return button
    }

    private func makeAccessoryKey() -> UIView {
        let title: String
        switch configuration.accessoryKey {
        case .none: return UIView()
        case .clear: title = configuration.texts.clearKeyTitle
        case .done: title = configuration.texts.doneKeyTitle
        }
        let button = makeKeyButton()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setTitleColor(configuration.accentColor, for: .normal)
        button.addTarget(self, action: #selector(accessoryTapped), for: .touchUpInside)
        return button
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor borders do not follow light / dark changes on their own.
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        for case let button as SecurePINKeyButton in stack.arrangedSubviews.flatMap({ ($0 as? UIStackView)?.arrangedSubviews ?? [] }) {
            button.layer.borderColor = configuration.keyBorderColor.cgColor
        }
    }

    private func keyPressed() {
        if configuration.hapticFeedback { haptics.impactOccurred() }
    }

    @objc private func digitTapped(_ sender: UIButton) {
        guard let digit = digitByButton[ObjectIdentifier(sender)] else { return }
        keyPressed()
        delegate?.securePINKeyboardView(self, didTapDigit: digit)
        if configuration.shuffleMode == .afterEachTap { reshuffleIfNeeded() }
    }

    @objc private func backspaceTapped() {
        keyPressed()
        delegate?.securePINKeyboardViewDidTapBackspace(self)
        if configuration.shuffleMode == .afterEachTap { reshuffleIfNeeded() }
    }

    @objc private func accessoryTapped() {
        keyPressed()
        delegate?.securePINKeyboardView(self, didTapAccessoryKey: configuration.accessoryKey)
    }
}

/// Key that swaps its background while pressed.
final class SecurePINKeyButton: UIButton {

    private let normalColor: UIColor
    private let highlightedColor: UIColor

    init(normalColor: UIColor, highlightedColor: UIColor) {
        self.normalColor = normalColor
        self.highlightedColor = highlightedColor
        super.init(frame: .zero)
        backgroundColor = normalColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? highlightedColor : normalColor }
    }
}
