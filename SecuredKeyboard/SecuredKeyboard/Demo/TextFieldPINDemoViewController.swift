import UIKit
import SecurePINKeyboard

/// Change-PIN screen built from plain `UITextField`s, made secure by
/// registering them with `SecurePINTextFieldCoordinator`.
final class TextFieldPINDemoViewController: UIViewController {

    var onResult: ((String) -> Void)?

    private let coordinator = SecurePINTextFieldCoordinator()
    private let currentField = UITextField()
    private let newField = UITextField()
    private let confirmField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let messageLabel = UILabel()

    private var fields: [UITextField] { [currentField, newField, confirmField] }
    private var pinLength: Int { coordinator.configuration.pinLength }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Change PIN"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        setupLayout()

        coordinator.register(currentField, title: "Current PIN")
        coordinator.register(newField, title: "New PIN")
        coordinator.register(confirmField, title: "Confirm new PIN")

        for field in fields {
            field.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        textChanged()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        currentField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
        coordinator.clearAll()
    }

    private func setupLayout() {
        let fieldHeight = coordinator.configuration.fieldHeight
        for field in fields {
            field.borderStyle = .none
            field.translatesAutoresizingMaskIntoConstraints = false
            field.heightAnchor.constraint(equalToConstant: fieldHeight).isActive = true
        }

        let introLabel = UILabel()
        introLabel.text = "These are ordinary UITextFields. The coordinator swaps in the secure keypad and draws the masked PIN over each one."
        introLabel.font = .systemFont(ofSize: 15)
        introLabel.textColor = .secondaryLabel
        introLabel.numberOfLines = 0

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "Save"
        buttonConfig.baseBackgroundColor = coordinator.configuration.accentColor
        buttonConfig.cornerStyle = .large
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        saveButton.configuration = buttonConfig
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Each overlay draws its title ~26pt above its field, so leave room.
        let stack = UIStackView(arrangedSubviews: [introLabel, currentField, newField, confirmField, saveButton, messageLabel])
        stack.axis = .vertical
        stack.spacing = 44
        stack.setCustomSpacing(28, after: confirmField)
        stack.setCustomSpacing(16, after: saveButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
    }

    /// Moves to the next field once one is full; after the last, hides the
    /// keypad so Save is visible.
    @objc private func fieldChanged(_ field: UITextField) {
        textChanged()
        guard field.isFirstResponder, field.text?.count == pinLength,
              let index = fields.firstIndex(of: field) else { return }
        if index + 1 < fields.count {
            fields[index + 1].becomeFirstResponder()
        } else {
            field.resignFirstResponder()
        }
    }

    private func textChanged() {
        saveButton.isEnabled = fields.allSatisfy { $0.text?.count == pinLength }
        messageLabel.text = nil
    }

    @objc private func backgroundTapped() {
        view.endEditing(true)
    }

    @objc private func saveTapped() {
        let current = currentField.text ?? ""
        let new = newField.text ?? ""
        let confirm = confirmField.text ?? ""

        if new != confirm {
            fail("New PINs do not match.", on: confirmField)
        } else if new == current {
            fail("New PIN must be different from the current PIN.", on: newField)
        } else {
            view.endEditing(true)
            onResult?("PIN changed: \(new.count) digits\(DemoDebug.reveal(new.compactMap { UInt8(String($0)) }))")
            coordinator.clearAll()
            messageLabel.textColor = coordinator.configuration.successColor
            messageLabel.text = "PIN changed"
        }
    }

    private func fail(_ message: String, on field: UITextField) {
        field.text = ""
        field.sendActions(for: .editingChanged)
        coordinator.showError(on: field)
        field.becomeFirstResponder()
        messageLabel.textColor = coordinator.configuration.errorColor
        messageLabel.text = message
    }
}
