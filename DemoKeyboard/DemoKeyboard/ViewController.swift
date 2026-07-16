//
//  ViewController.swift
//  DemoKeyboard
//
//  Created by Sabbir on 7/16/26.
//

import UIKit
import SecurePINKeyboard

final class ViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let openKeyboardButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 247 / 255, green: 248 / 255, blue: 251 / 255, alpha: 1)

        titleLabel.text = "DemoKeyboard"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = UIColor(red: 20 / 255, green: 25 / 255, blue: 34 / 255, alpha: 1)
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Tap the button to test the SecurePINKeyboard package. The PIN screen should open with its custom keyboard fixed at the bottom."
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 88 / 255, green: 95 / 255, blue: 105 / 255, alpha: 1)
        subtitleLabel.numberOfLines = 0

        statusLabel.text = "No PIN entered yet."
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = UIColor(red: 52 / 255, green: 61 / 255, blue: 75 / 255, alpha: 1)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        configurePrimaryButton(openKeyboardButton, title: "Open Secure PIN Keyboard")
        openKeyboardButton.addTarget(self, action: #selector(openKeyboardTapped), for: .touchUpInside)

        configureSecondaryButton(clearButton, title: "Clear Result")
        clearButton.addTarget(self, action: #selector(clearResultTapped), for: .touchUpInside)

        let statusCard = UIView()
        statusCard.backgroundColor = .white
        statusCard.layer.cornerRadius = 12
        statusCard.layer.borderWidth = 1
        statusCard.layer.borderColor = UIColor(red: 224 / 255, green: 228 / 255, blue: 236 / 255, alpha: 1).cgColor
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            statusCard,
            openKeyboardButton,
            clearButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            statusCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            statusLabel.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 18),
            statusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -18),

            openKeyboardButton.heightAnchor.constraint(equalToConstant: 52),
            clearButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func configurePrimaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor(red: 42 / 255, green: 91 / 255, blue: 215 / 255, alpha: 1)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }

    private func configureSecondaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(red: 42 / 255, green: 91 / 255, blue: 215 / 255, alpha: 1), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 42 / 255, green: 91 / 255, blue: 215 / 255, alpha: 0.28).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }

    @objc private func openKeyboardTapped() {
        let configuration = SecurePINConfiguration(
            title: "Secure PIN",
            subtitle: "Enter and confirm a 4-digit PIN.",
            primaryPINTitle: "Enter PIN",
            confirmationPINTitle: "Confirm PIN",
            pinLength: 4,
            mode: .confirmEntry,
            shufflesAfterEachTap: true,
            protectsAgainstScreenCapture: true,
            clearsOnScreenshot: true,
            clearsWhenAppResignsActive: true,
            accentColor: UIColor(red: 42 / 255, green: 91 / 255, blue: 215 / 255, alpha: 1)
        )

        let controller = SecurePINEntryViewController(configuration: configuration)
        controller.delegate = self

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .fullScreen
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissKeyboardDemo)
        )

        present(navigationController, animated: true)
    }

    @objc private func clearResultTapped() {
        statusLabel.text = "No PIN entered yet."
    }

    @objc private func dismissKeyboardDemo() {
        dismiss(animated: true)
    }
}

extension ViewController: SecurePINEntryViewControllerDelegate {

    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didCompleteWith pin: [UInt8]) {
        statusLabel.text = "PIN completed with \(pin.count) digits."
        dismiss(animated: true)
    }

    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError) {
        switch error {
        case .confirmationMismatch:
            statusLabel.text = "Confirmation did not match. Try again."
        case .inputLocked:
            statusLabel.text = "Input locked for privacy."
        }
    }

    func securePINEntryViewControllerDidClearSensitiveInput(_ controller: SecurePINEntryViewController) {
        statusLabel.text = "Secure input was cleared."
    }
}
