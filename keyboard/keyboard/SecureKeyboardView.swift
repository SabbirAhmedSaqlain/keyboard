//
//  SecureKeyboardView.swift
//  keyboard
//
//  Custom in-app numeric keyboard designed so taps can't be tracked:
//  - Never uses the system keyboard (no third-party keyboard / keylogger exposure)
//  - Digit positions are shuffled every time it appears AND after every tap,
//    so touch coordinates never map to a fixed digit
//  - No highlight, animation, or haptic on press, so an observer or screen
//    recording gets no visual feedback about which key was hit
//  - Digit labels are not exposed through accessibility metadata
//

import UIKit

protocol SecureKeyboardDelegate: AnyObject {
    func secureKeyboard(_ keyboard: SecureKeyboardView, didTapDigit digit: Int)
    func secureKeyboardDidTapBackspace(_ keyboard: SecureKeyboardView)
}

final class SecureKeyboardView: UIView {

    weak var delegate: SecureKeyboardDelegate?

    /// Re-shuffles digit positions after every single tap. Maximum privacy.
    var shufflesAfterEachTap = true

    private var digitButtons: [UIButton] = []
    private var digitByButton: [ObjectIdentifier: Int] = [:]
    private var backspaceButton = UIButton(type: .custom)
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { shuffle() }
    }

    private func setup() {
        backgroundColor = UIColor.secondarySystemBackground
        isMultipleTouchEnabled = false
        accessibilityElementsHidden = true

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        // 4 rows x 3 columns; 10 digit slots + blank + backspace
        for row in 0..<4 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 8
            stack.addArrangedSubview(rowStack)

            for col in 0..<3 {
                let index = row * 3 + col
                if index < 9 || index == 10 {
                    let button = makeKeyButton()
                    button.addTarget(self, action: #selector(digitTapped(_:)), for: .touchUpInside)
                    digitButtons.append(button)
                    rowStack.addArrangedSubview(button)
                } else if index == 9 {
                    // bottom-left: empty spacer
                    rowStack.addArrangedSubview(UIView())
                } else {
                    // bottom-right: backspace
                    backspaceButton = makeKeyButton()
                    backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
                    backspaceButton.tintColor = .label
                    backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
                    rowStack.addArrangedSubview(backspaceButton)
                }
            }
        }
    }

    private func makeKeyButton() -> UIButton {
        let button = UIButton(type: .custom) // .custom: no system highlight/dim on press
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.setTitleColor(.label, for: .highlighted) // identical pressed state
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 10
        button.adjustsImageWhenHighlighted = false
        button.showsTouchWhenHighlighted = false
        button.isExclusiveTouch = true
        button.isMultipleTouchEnabled = false
        button.isAccessibilityElement = false
        button.accessibilityLabel = nil
        button.accessibilityValue = nil
        button.tag = -1
        return button
    }

    /// Assigns digits 0-9 to random key positions.
    func shuffle() {
        var generator = SystemRandomNumberGenerator()
        let digits = Array(0...9).shuffled(using: &generator)
        digitByButton.removeAll(keepingCapacity: true)
        for (button, digit) in zip(digitButtons, digits) {
            button.setTitle("\(digit)", for: .normal)
            digitByButton[ObjectIdentifier(button)] = digit
        }
    }

    @objc private func digitTapped(_ sender: UIButton) {
        guard let digit = digitByButton[ObjectIdentifier(sender)] else { return }
        delegate?.secureKeyboard(self, didTapDigit: digit)
        if shufflesAfterEachTap { shuffle() }
    }

    @objc private func backspaceTapped() {
        delegate?.secureKeyboardDidTapBackspace(self)
        if shufflesAfterEachTap { shuffle() }
    }
}
