import UIKit
import SecurePINKeyboard

/// Login-style screen: an inline `SecurePINFieldView` with the keypad
/// sliding up from the bottom via `SecurePINKeyboardPanel`.
final class InlinePINDemoViewController: UIViewController {

    var onResult: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let pinField = SecurePINFieldView(title: "PIN")
    private let loginButton = UIButton(type: .system)
    private let messageLabel = UILabel()
    private var panel: SecurePINKeyboardPanel?

    /// Demo-only accepted PIN: 1234…, as long as the configured length.
    private var acceptedPIN: [UInt8] {
        (0..<pinField.length).map { UInt8(($0 + 1) % 10) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        setupLayout()

        pinField.onChange = { [weak self] _ in self?.pinChanged() }

        let panel = SecurePINKeyboardPanel(field: pinField, hostView: view)
        panel.onVisibilityChange = { [weak self] _, height in
            self?.adjustForKeyboard(height: height)
        }
        self.panel = panel
        pinChanged()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        panel?.show()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        panel?.hide(animated: false)
        panel?.clear()
    }

    private func setupLayout() {
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let avatar = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        avatar.tintColor = SecureKeyboard.configuration.accentColor
        avatar.contentMode = .scaleAspectFit
        avatar.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "Welcome back"
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textAlignment = .center

        let hintLabel = UILabel()
        let hint = acceptedPIN.map(String.init).joined()
        hintLabel.text = "Tap the PIN box to show or hide the keypad.\nDemo PIN: \(hint)"
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "Log in"
        buttonConfig.baseBackgroundColor = SecureKeyboard.configuration.accentColor
        buttonConfig.cornerStyle = .large
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        loginButton.configuration = buttonConfig
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [avatar, nameLabel, hintLabel, pinField, loginButton, messageLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: hintLabel)
        stack.setCustomSpacing(24, after: pinField)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            avatar.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    /// Keeps the login button visible above the keypad.
    private func adjustForKeyboard(height: CGFloat) {
        let inset = max(0, height - view.safeAreaInsets.bottom)
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
        guard height > 0 else { return }
        view.layoutIfNeeded()
        let buttonBottom = loginButton.convert(loginButton.bounds, to: scrollView).maxY + 12
        let visibleHeight = scrollView.bounds.height - height
        let offset = max(-scrollView.adjustedContentInset.top, buttonBottom - visibleHeight)
        if offset > scrollView.contentOffset.y {
            scrollView.contentOffset.y = offset
        }
    }

    private func pinChanged() {
        loginButton.isEnabled = pinField.isComplete
        if !pinField.isEmpty { messageLabel.text = nil }
    }

    @objc private func loginTapped() {
        guard pinField.isComplete else { return }
        var pin = pinField.copyPINBytes()
        defer { pin.secureWipe() }

        if pin == acceptedPIN {
            panel?.hide()
            panel?.clear()
            messageLabel.textColor = SecureKeyboard.configuration.successColor
            messageLabel.text = "Logged in"
            onResult?("Logged in with \(pin.count)-digit PIN\(DemoDebug.reveal(pin))")
        } else {
            panel?.clear()
            pinField.showError()
            messageLabel.textColor = SecureKeyboard.configuration.errorColor
            messageLabel.text = "Wrong PIN. Try again."
        }
    }
}
