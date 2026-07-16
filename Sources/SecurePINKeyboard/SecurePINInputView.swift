import UIKit

public final class SecurePINInputView: UIView {

    public let length: Int
    public var onChange: ((SecurePINInputView) -> Void)?
    public var onActivate: ((SecurePINInputView) -> Void)?

    private let securePin: SecurePINBuffer
    private let accentColor: UIColor
    private let titleLabel = UILabel()
    private var boxes: [UIView] = []
    private var dots: [UIView] = []

    public var isComplete: Bool { securePin.isFull }
    public var isEmpty: Bool { securePin.isEmpty }

    public var isActive: Bool = false {
        didSet { updateBoxes() }
    }

    public init(title: String, length: Int = 4, accentColor: UIColor = SecurePINConfiguration.defaultAccentColor) {
        self.length = max(1, min(length, 12))
        self.securePin = SecurePINBuffer(capacity: max(1, min(length, 12)))
        self.accentColor = accentColor
        super.init(frame: .zero)
        titleLabel.text = title
        setup()
    }

    public required init?(coder: NSCoder) {
        self.length = 4
        self.securePin = SecurePINBuffer(capacity: 4)
        self.accentColor = SecurePINConfiguration.defaultAccentColor
        super.init(coder: coder)
        setup()
    }

    public func append(digit: Int) {
        let previousCount = securePin.count
        securePin.append(digit: digit)
        notifyChangeIfNeeded(previousCount: previousCount)
    }

    public func deleteBackward() {
        let previousCount = securePin.count
        securePin.removeLast()
        notifyChangeIfNeeded(previousCount: previousCount)
    }

    public func clear(sendsChange: Bool = true) {
        let previousCount = securePin.count
        securePin.removeAll()
        if sendsChange {
            notifyChangeIfNeeded(previousCount: previousCount)
        } else if previousCount != securePin.count {
            updateBoxes()
        }
    }

    public func securelyMatches(_ other: SecurePINInputView) -> Bool {
        guard isComplete, other.isComplete else { return false }
        return securePin.constantTimeEquals(other.securePin)
    }

    public func copyPINBytes() -> [UInt8] {
        securePin.copyBytes()
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = SecurePINStyle.secondaryText
        titleLabel.text = titleLabel.text?.uppercased()

        let boxStack = UIStackView()
        boxStack.axis = .horizontal
        boxStack.distribution = .fillEqually
        boxStack.spacing = 12

        for _ in 0..<length {
            let box = UIView()
            box.backgroundColor = SecurePINStyle.elevatedSurface
            box.layer.cornerRadius = 14
            SecurePINStyle.applyContinuousCornerCurve(to: box.layer)
            box.layer.borderWidth = 1.5
            box.layer.borderColor = SecurePINStyle.separator.withAlphaComponent(0.35).cgColor
            box.heightAnchor.constraint(equalToConstant: 58).isActive = true

            let dot = UIView()
            dot.backgroundColor = accentColor
            dot.layer.cornerRadius = 5.5
            dot.isHidden = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: box.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: box.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 11),
                dot.heightAnchor.constraint(equalToConstant: 11)
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
            let isFilled = index < securePin.count
            box.backgroundColor = isFilled ? accentColor.withAlphaComponent(0.08) : SecurePINStyle.elevatedSurface
            box.layer.borderColor = isCurrent ? accentColor.cgColor : SecurePINStyle.separator.withAlphaComponent(0.35).cgColor
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
