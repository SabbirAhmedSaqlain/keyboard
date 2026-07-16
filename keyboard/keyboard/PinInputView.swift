//
//  PinInputView.swift
//  keyboard
//
//  A 4-digit PIN field rendered as masked dot boxes. Digits are never shown
//  on screen; the entered PIN is kept in a fixed-size byte buffer, not String.
//

import UIKit

final class PinInputView: UIView {

    let length = 4

    /// Called whenever the PIN content changes.
    var onChange: ((PinInputView) -> Void)?
    /// Called when the user taps the field to make it active.
    var onActivate: ((PinInputView) -> Void)?

    private let securePin = SecurePinBuffer(capacity: 4)

    var isComplete: Bool { securePin.isFull }
    var isEmpty: Bool { securePin.isEmpty }

    var isActive: Bool = false {
        didSet { updateBoxes() }
    }

    private let titleLabel = UILabel()
    private var boxes: [UIView] = []
    private var dots: [UIView] = []

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func append(digit: Int) {
        let previousCount = securePin.count
        securePin.append(digit: digit)
        notifyChangeIfNeeded(previousCount: previousCount)
    }

    func deleteBackward() {
        let previousCount = securePin.count
        securePin.removeLast()
        notifyChangeIfNeeded(previousCount: previousCount)
    }

    func clear(sendsChange: Bool = true) {
        let previousCount = securePin.count
        securePin.removeAll()
        if sendsChange {
            notifyChangeIfNeeded(previousCount: previousCount)
        } else if previousCount != securePin.count {
            updateBoxes()
        }
    }

    func securelyMatches(_ other: PinInputView) -> Bool {
        guard isComplete, other.isComplete else { return false }
        return securePin.constantTimeEquals(other.securePin)
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        let boxStack = UIStackView()
        boxStack.axis = .horizontal
        boxStack.distribution = .fillEqually
        boxStack.spacing = 12

        for _ in 0..<length {
            let box = UIView()
            box.backgroundColor = .secondarySystemBackground
            box.layer.cornerRadius = 12
            box.layer.borderWidth = 1.5
            box.layer.borderColor = UIColor.clear.cgColor
            box.heightAnchor.constraint(equalToConstant: 56).isActive = true

            let dot = UIView()
            dot.backgroundColor = .label
            dot.layer.cornerRadius = 6
            dot.isHidden = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: box.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12)
            ])

            boxes.append(box)
            dots.append(dot)
            boxStack.addArrangedSubview(box)
        }

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, boxStack])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true
        accessibilityLabel = titleLabel.text
        accessibilityTraits = [.button, .updatesFrequently]
        updateAccessibilityValue()
    }

    @objc private func tapped() {
        onActivate?(self)
    }

    private func updateBoxes() {
        for (index, dot) in dots.enumerated() {
            dot.isHidden = index >= securePin.count
        }
        for (index, box) in boxes.enumerated() {
            let isCurrent = isActive && index == min(securePin.count, length - 1)
            box.layer.borderColor = isCurrent ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        }
        updateAccessibilityValue()
    }

    private func notifyChangeIfNeeded(previousCount: Int) {
        guard previousCount != securePin.count else { return }
        updateBoxes()
        onChange?(self)
    }

    private func updateAccessibilityValue() {
        accessibilityValue = "\(securePin.count) of \(length) digits entered"
    }
}
