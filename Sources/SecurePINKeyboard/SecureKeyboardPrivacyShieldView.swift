import UIKit

/// Full-cover overlay shown while secure input is hidden (screen recording,
/// screenshot, app inactive, device locked).
public final class SecureKeyboardPrivacyShieldView: UIView {

    /// Called when the user taps the continue button.
    public var onContinue: (() -> Void)?

    private let iconView = UIImageView(image: UIImage(systemName: "lock.shield"))
    private let messageLabel = UILabel()
    private let continueButton = UIButton(type: .system)

    public init(configuration: SecureKeyboardConfiguration? = nil) {
        // `nil` = the app-wide `SecureKeyboard.configuration`.
        let configuration = configuration ?? SecureKeyboard.configuration
        super.init(frame: .zero)
        setup(configuration: configuration)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(configuration: SecureKeyboard.configuration)
    }

    /// Shows the shield with `message`. The continue button is offered only
    /// when the cause has passed (e.g. a screenshot), not while recording.
    public func show(message: String, allowsContinue: Bool) {
        messageLabel.text = message
        accessibilityValue = message
        continueButton.isHidden = !allowsContinue
        isHidden = false
        superview?.bringSubviewToFront(self)
    }

    public func hide() {
        isHidden = true
    }

    private func setup(configuration: SecureKeyboardConfiguration) {
        backgroundColor = .systemBackground
        isHidden = true
        accessibilityViewIsModal = true
        isAccessibilityElement = false
        accessibilityLabel = "Secure input hidden"

        iconView.tintColor = configuration.accentColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        messageLabel.textAlignment = .center
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0

        continueButton.setTitle(configuration.texts.shieldContinueTitle, for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        continueButton.tintColor = configuration.accentColor
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel, continueButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])
    }

    @objc private func continueTapped() {
        onContinue?()
    }
}
