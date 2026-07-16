//
//  DashboardViewController.swift
//  keyboard
//
//  Dashboard shown on launch. Two 4-digit PIN fields at the top, driven
//  exclusively by the custom SecureKeyboardView pinned to the bottom.
//

import UIKit

final class DashboardViewController: UIViewController {

    private let pinField = PinInputView(title: "Enter PIN")
    private let confirmField = PinInputView(title: "Confirm PIN")
    private let keyboard = SecureKeyboardView()
    private let statusLabel = UILabel()

    private var activeField: PinInputView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Dashboard"

        setupLayout()

        pinField.onActivate = { [weak self] field in self?.activate(field) }
        confirmField.onActivate = { [weak self] field in self?.activate(field) }
        pinField.onChange = { [weak self] _ in self?.pinChanged() }
        confirmField.onChange = { [weak self] _ in self?.pinChanged() }
        keyboard.delegate = self

        activate(pinField)
    }

    private func setupLayout() {
        let header = UILabel()
        header.text = "Dashboard"
        header.font = .systemFont(ofSize: 32, weight: .bold)

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Enter a 4-digit PIN using the secure keyboard below."

        let contentStack = UIStackView(arrangedSubviews: [header, pinField, confirmField, statusLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.setCustomSpacing(32, after: header)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func activate(_ field: PinInputView) {
        activeField = field
        pinField.isActive = field === pinField
        confirmField.isActive = field === confirmField
    }

    private func pinChanged() {
        guard pinField.isComplete, confirmField.isComplete else {
            statusLabel.textColor = .secondaryLabel
            statusLabel.text = "Enter a 4-digit PIN using the secure keyboard below."
            return
        }
        if pinField.pin == confirmField.pin {
            statusLabel.textColor = .systemGreen
            statusLabel.text = "PINs match."
        } else {
            statusLabel.textColor = .systemRed
            statusLabel.text = "PINs do not match."
        }
    }
}

extension DashboardViewController: SecureKeyboardDelegate {

    func secureKeyboard(_ keyboard: SecureKeyboardView, didTapDigit digit: Int) {
        guard let field = activeField else { return }
        field.append(digit: digit)
        // Auto-advance to the confirm field once the first PIN is complete.
        if field === pinField, field.isComplete {
            activate(confirmField)
        }
    }

    func secureKeyboardDidTapBackspace(_ keyboard: SecureKeyboardView) {
        guard let field = activeField else { return }
        if field.pin.isEmpty, field === confirmField {
            activate(pinField)
            pinField.deleteBackward()
        } else {
            field.deleteBackward()
        }
    }
}
