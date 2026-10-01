//
//  ViewController.swift
//  SecuredKeyboard
//
//  Created by admin  on 1/10/26.
//

import UIKit
import SecurePINKeyboard

/// Demo home: launches each secure keyboard component. The Configure button
/// opens the package's `SecureKeyboardSettingsViewController`, which edits the
/// shared configuration through `SecureKeyboard.configure(...)`.
class ViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case demos, result
    }

    private enum Demo: Int, CaseIterable {
        case inlineLogin, enterPIN, setPIN, textFields

        var title: String {
            switch self {
            case .inlineLogin: return "Login screen"
            case .enterPIN: return "Enter PIN"
            case .setPIN: return "Set new PIN"
            case .textFields: return "Change PIN"
            }
        }

        var subtitle: String {
            switch self {
            case .inlineLogin: return "Inline PIN box + slide-up keypad (SecurePINKeyboardPanel)"
            case .enterPIN: return "Full screen, single entry (SecurePINEntryViewController)"
            case .setPIN: return "Full screen, enter + confirm (SecurePINEntryViewController)"
            case .textFields: return "Existing UITextFields (SecurePINTextFieldCoordinator)"
            }
        }

        var icon: String {
            switch self {
            case .inlineLogin: return "person.crop.circle"
            case .enterPIN: return "lock.square"
            case .setPIN: return "lock.rotation"
            case .textFields: return "rectangle.and.pencil.and.ellipsis"
            }
        }
    }

    private let configureButton = UIButton(type: .system)
    private var lastResult = "No PIN entered yet"

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Secure Keyboard"
        setupConfigureButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pick up accent changes made on the settings page.
        updateConfigureButton()
        tableView.reloadData()
    }

    // MARK: Configure button

    private func setupConfigureButton() {
        configureButton.addTarget(self, action: #selector(configureTapped), for: .touchUpInside)
        configureButton.translatesAutoresizingMaskIntoConstraints = false
        updateConfigureButton()

        let header = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 76))
        header.preservesSuperviewLayoutMargins = true
        header.addSubview(configureButton)
        NSLayoutConstraint.activate([
            configureButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            configureButton.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            configureButton.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
            configureButton.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8)
        ])
        tableView.tableHeaderView = header
    }

    private func updateConfigureButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Configure Keyboard"
        config.image = UIImage(systemName: "gearshape.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = SecureKeyboard.configuration.accentColor
        config.cornerStyle = .large
        configureButton.configuration = config
    }

    @objc private func configureTapped() {
        // Pushed (not presented) so it stays inside the screenshot-protected container.
        navigationController?.pushViewController(SecureKeyboardSettingsViewController(), animated: true)
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .demos: return Demo.allCases.count
        case .result: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .demos: return "Demos"
        case .result: return "Last result"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .demos:
            return "Screenshots and recordings of this app come out blank while \"Block screenshots\" is on."
        case .result:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()

        switch Section(rawValue: indexPath.section)! {
        case .demos:
            let demo = Demo(rawValue: indexPath.row)!
            content.text = demo.title
            content.secondaryText = demo.subtitle
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: demo.icon)
            content.imageProperties.tintColor = SecureKeyboard.configuration.accentColor
            cell.accessoryType = .disclosureIndicator

        case .result:
            content = UIListContentConfiguration.cell()
            content.text = lastResult
            content.textProperties.color = .secondaryLabel
            cell.selectionStyle = .none
        }

        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .demos {
            open(Demo(rawValue: indexPath.row)!)
        }
    }

    // MARK: Demos

    private func open(_ demo: Demo) {
        let viewController: UIViewController
        switch demo {
        case .inlineLogin:
            let login = InlinePINDemoViewController()
            login.onResult = { [weak self] in self?.showResult($0) }
            viewController = login

        case .enterPIN:
            let config = SecureKeyboard.configure(
                applyGlobally: false,
                entryMode: .singleEntry,
                texts: SecureKeyboardTexts(title: "Enter PIN",
                                           subtitle: "Confirm it's you to continue",
                                           primaryPINTitle: "PIN")
            )
            let entry = SecurePINEntryViewController(configuration: config)
            entry.delegate = self
            viewController = entry

        case .setPIN:
            let config = SecureKeyboard.configure(
                applyGlobally: false,
                entryMode: .confirmEntry,
                texts: SecureKeyboardTexts(title: "Set new PIN",
                                           subtitle: "Choose a PIN and enter it again",
                                           primaryPINTitle: "New PIN",
                                           confirmationPINTitle: "Confirm new PIN")
            )
            let entry = SecurePINEntryViewController(configuration: config)
            entry.delegate = self
            viewController = entry

        case .textFields:
            let changePIN = TextFieldPINDemoViewController()
            changePIN.onResult = { [weak self] in self?.showResult($0) }
            viewController = changePIN
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showResult(_ text: String) {
        lastResult = text
        tableView.reloadSections(IndexSet(integer: Section.result.rawValue), with: .none)
    }
}

extension ViewController: SecurePINEntryViewControllerDelegate {

    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didCompleteWith pin: [UInt8]) {
        var pin = pin
        let kind = controller.configuration.entryMode == .confirmEntry ? "New PIN set" : "PIN entered"
        showResult("\(kind): \(pin.count) digits\(DemoDebug.reveal(pin))")
        pin.secureWipe()
        controller.close()
    }

    func securePINEntryViewController(_ controller: SecurePINEntryViewController, didFailWith error: SecurePINEntryError) {
        if error == .confirmationMismatch {
            showResult("PINs did not match")
        }
    }
}

/// Demo-only: shows the digits in Debug builds so the keypad can be checked.
/// A real app must never display or log the PIN.
enum DemoDebug {
    static func reveal(_ pin: [UInt8]) -> String {
        #if DEBUG
        return " (debug: \(pin.map(String.init).joined()))"
        #else
        return ""
        #endif
    }
}
