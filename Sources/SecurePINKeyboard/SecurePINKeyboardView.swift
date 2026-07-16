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
    private let handle = UIView()

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
        layer.cornerRadius = 26
        SecurePINStyle.applyContinuousCornerCurve(to: layer)
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: -8)
        isMultipleTouchEnabled = false
        accessibilityElementsHidden = true

        handle.backgroundColor = SecurePINStyle.separator.withAlphaComponent(0.55)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(handle)

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            handle.centerXAnchor.constraint(equalTo: centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 42),
            handle.heightAnchor.constraint(equalToConstant: 4),

            stack.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 14),
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
