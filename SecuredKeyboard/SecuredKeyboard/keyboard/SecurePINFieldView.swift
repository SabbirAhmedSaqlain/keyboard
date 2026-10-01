import UIKit

/// Shows the PIN being typed as masked dots, in either `fieldStyle`.
///
/// Two usage modes:
/// * **Buffered** — the view owns the PIN in a zeroing `SecurePINBuffer`
///   (`append` / `deleteBackward` / `copyPINBytes`). Used by
///   `SecurePINKeyboardPanel` and `SecurePINEntryViewController`.
/// * **Display-only** — something else owns the PIN and the view only mirrors
///   how many digits exist (`setFilledCount`). Used by
///   `SecurePINTextFieldCoordinator`.
public final class SecurePINFieldView: UIView {

    /// Called after every digit added / removed / cleared.
    public var onChange: ((SecurePINFieldView) -> Void)?
    /// Called when the field is tapped.
    public var onActivate: ((SecurePINFieldView) -> Void)?

    public let length: Int
    public let configuration: SecureKeyboardConfiguration

    /// Optional caption above the box; `nil` / empty collapses it.
    public var title: String? {
        didSet { applyTitle() }
    }

    /// Highlights the border of the field receiving input.
    public var isActive = false {
        didSet {
            guard isActive != oldValue else { return }
            updateAppearance()
        }
    }

    public var count: Int { displayCount }
    public var isComplete: Bool { displayCount == length }
    public var isEmpty: Bool { displayCount == 0 }

    /// Top of the box itself, below any title. Align this with a view the
    /// field visually replaces so the title sits above it.
    public var boxTopAnchor: NSLayoutYAxisAnchor { boxContainer.topAnchor }

    private let buffer: SecurePINBuffer
    private var displayCount = 0
    private var isShowingError = false

    private let titleLabel = UILabel()
    private let boxContainer = UIView()
    private var boxes: [UIView] = []
    private var dots: [UIView] = []

    public init(title: String? = nil,
                length: Int? = nil,
                configuration: SecureKeyboardConfiguration = SecureKeyboard.configuration) {
        let resolvedLength = max(1, min(length ?? configuration.pinLength, SecureKeyboardConfiguration.maximumPINLength))
        self.length = resolvedLength
        self.configuration = configuration
        self.buffer = SecurePINBuffer(capacity: resolvedLength)
        self.title = title
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.configuration = SecureKeyboard.configuration
        self.length = configuration.pinLength
        self.buffer = SecurePINBuffer(capacity: configuration.pinLength)
        super.init(coder: coder)
        setup()
    }

    // MARK: Buffered API

    public func append(digit: Int) {
        let previous = buffer.count
        buffer.append(digit: digit)
        bufferChanged(from: previous)
    }

    public func deleteBackward() {
        let previous = buffer.count
        buffer.removeLast()
        bufferChanged(from: previous)
    }

    /// Wipes the PIN. `sendsChange: false` updates the UI without `onChange`.
    public func clear(sendsChange: Bool = true) {
        let previous = buffer.count
        buffer.removeAll()
        displayCount = 0
        isShowingError = false
        updateAppearance()
        if sendsChange && previous != 0 { onChange?(self) }
    }

    /// A copy of the digits (0-9 per byte). Call `secureWipe()` on it when done.
    public func copyPINBytes() -> [UInt8] {
        buffer.copyBytes()
    }

    /// Constant-time comparison of two complete PINs.
    public func securelyMatches(_ other: SecurePINFieldView) -> Bool {
        guard isComplete, other.isComplete else { return false }
        return buffer.constantTimeEquals(other.buffer)
    }

    // MARK: Display-only API

    public func setFilledCount(_ count: Int) {
        let clamped = max(0, min(count, length))
        guard clamped != displayCount else { return }
        displayCount = clamped
        isShowingError = false
        updateAppearance()
    }

    // MARK: Feedback

    /// Turns the border `errorColor` until the next edit; optionally shakes.
    public func showError(shake: Bool = true) {
        isShowingError = true
        updateAppearance()
        guard shake else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-12, 12, -9, 9, -5, 5, 0]
        boxContainer.layer.add(animation, forKey: "shake")
    }

    // MARK: Private

    private func bufferChanged(from previous: Int) {
        guard previous != buffer.count else { return }
        displayCount = buffer.count
        isShowingError = false
        updateAppearance()
        onChange?(self)
    }

    private func setup() {
        backgroundColor = .clear

        titleLabel.font = configuration.fieldTitleFont
        titleLabel.textColor = configuration.fieldTitleColor
        titleLabel.numberOfLines = 1
        applyTitle()

        boxContainer.translatesAutoresizingMaskIntoConstraints = false
        boxContainer.heightAnchor.constraint(equalToConstant: configuration.fieldHeight).isActive = true

        switch configuration.fieldStyle {
        case .singleBox: buildSingleBox()
        case .separateBoxes: buildSeparateBoxes()
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, boxContainer])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true
        accessibilityTraits = [.button, .updatesFrequently]
        updateAppearance()
    }

    private func buildSingleBox() {
        let box = makeBox()
        boxContainer.addSubview(box)
        boxes = [box]

        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.alignment = .center
        dotsStack.spacing = length <= 6 ? 22 : 10
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(dotsStack)

        for _ in 0..<length {
            let dot = makeDot()
            dots.append(dot)
            dotsStack.addArrangedSubview(dot)
        }

        var constraints = [
            box.topAnchor.constraint(equalTo: boxContainer.topAnchor),
            box.leadingAnchor.constraint(equalTo: boxContainer.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: boxContainer.trailingAnchor),
            box.bottomAnchor.constraint(equalTo: boxContainer.bottomAnchor),
            dotsStack.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            dotsStack.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ]

        if configuration.showsFieldIcon, let icon = configuration.fieldIcon {
            let iconView = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))
            iconView.tintColor = .secondaryLabel
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(iconView)
            constraints += [
                iconView.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
                iconView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20),
                dotsStack.leadingAnchor.constraint(greaterThanOrEqualTo: iconView.trailingAnchor, constant: 8)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func buildSeparateBoxes() {
        let boxStack = UIStackView()
        boxStack.axis = .horizontal
        boxStack.distribution = .fillEqually
        boxStack.spacing = length <= 6 ? 12 : 6
        boxStack.translatesAutoresizingMaskIntoConstraints = false
        boxContainer.addSubview(boxStack)

        for _ in 0..<length {
            let box = makeBox()
            let dot = makeDot()
            box.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: box.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: box.centerYAnchor)
            ])
            boxes.append(box)
            dots.append(dot)
            boxStack.addArrangedSubview(box)
        }

        NSLayoutConstraint.activate([
            boxStack.topAnchor.constraint(equalTo: boxContainer.topAnchor),
            boxStack.leadingAnchor.constraint(equalTo: boxContainer.leadingAnchor),
            boxStack.trailingAnchor.constraint(equalTo: boxContainer.trailingAnchor),
            boxStack.bottomAnchor.constraint(equalTo: boxContainer.bottomAnchor)
        ])
    }

    private func makeBox() -> UIView {
        let box = UIView()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.backgroundColor = configuration.fieldBackgroundColor
        box.layer.cornerRadius = configuration.fieldCornerRadius
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1.5
        return box
    }

    private func makeDot() -> UIView {
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = configuration.dotSize / 2
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: configuration.dotSize),
            dot.heightAnchor.constraint(equalToConstant: configuration.dotSize)
        ])
        return dot
    }

    private func applyTitle() {
        titleLabel.text = title
        titleLabel.isHidden = title?.isEmpty ?? true
        accessibilityLabel = title ?? "PIN"
    }

    private func updateAppearance() {
        let inactive = configuration.fieldBorderColor
        let active = configuration.resolvedActiveBorderColor

        switch configuration.fieldStyle {
        case .singleBox:
            for (index, dot) in dots.enumerated() {
                dot.backgroundColor = index < displayCount ? configuration.filledDotColor : configuration.emptyDotColor
            }
            let border = isShowingError ? configuration.errorColor : (isActive ? active : inactive)
            boxes.first?.layer.borderColor = border.cgColor

        case .separateBoxes:
            let currentIndex = min(displayCount, length - 1)
            for (index, box) in boxes.enumerated() {
                let isFilled = index < displayCount
                dots[index].backgroundColor = configuration.filledDotColor
                dots[index].isHidden = !isFilled
                box.backgroundColor = isFilled
                    ? configuration.accentColor.withAlphaComponent(0.08)
                    : configuration.fieldBackgroundColor
                let border: UIColor
                if isShowingError {
                    border = configuration.errorColor
                } else if isActive && index == currentIndex {
                    border = active
                } else {
                    border = inactive
                }
                box.layer.borderColor = border.cgColor
            }
        }
        accessibilityValue = "\(displayCount) of \(length) digits entered"
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor borders do not follow light / dark changes on their own.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }

    @objc private func tapped() {
        onActivate?(self)
    }
}
