//
//  ViewController.swift
//  SecuredKeyboard
//
//  Created by admin  on 1/10/26.
//

import UIKit

/// Accent colours offered by the demo settings.
enum DemoAccent: Int, CaseIterable {
    case indigo, teal, orange, pink

    var title: String {
        switch self {
        case .indigo: return "Indigo"
        case .teal: return "Teal"
        case .orange: return "Orange"
        case .pink: return "Pink"
        }
    }

    var color: UIColor {
        switch self {
        case .indigo: return UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)
        case .teal: return .systemTeal
        case .orange: return .systemOrange
        case .pink: return .systemPink
        }
    }
}

/// Demo home: launches each secure keyboard component and edits the shared
/// configuration through `SecureKeyboard.configure(...)`.
class ViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case demos, configuration, result
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

    private enum Setting: Int, CaseIterable {
        case pinLength, shuffle, fieldStyle, accessoryKey, accent
        case haptics, captureProtection, clearOnScreenshot, clearOnInactive
        case reset
    }

    private let pinLengths = [4, 5, 6]
    private var accent: DemoAccent = .indigo
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
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .demos: return Demo.allCases.count
        case .configuration: return Setting.allCases.count
        case .result: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .demos: return "Demos"
        case .configuration: return "SecureKeyboard.configure(...)"
        case .result: return "Last result"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .configuration:
            return "Each control calls SecureKeyboard.configure with just the value it changes. Open a demo to see the result."
        default:
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
            content.imageProperties.tintColor = accent.color
            cell.accessoryType = .disclosureIndicator

        case .configuration:
            configureSettingCell(cell, content: &content, setting: Setting(rawValue: indexPath.row)!)

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
        switch Section(rawValue: indexPath.section)! {
        case .demos:
            open(Demo(rawValue: indexPath.row)!)
        case .configuration where Setting(rawValue: indexPath.row) == .reset:
            SecureKeyboard.resetConfiguration()
            accent = .indigo
            tableView.reloadData()
        default:
            break
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

    // MARK: Settings

    private func configureSettingCell(_ cell: UITableViewCell,
                                      content: inout UIListContentConfiguration,
                                      setting: Setting) {
        content = UIListContentConfiguration.cell()
        cell.selectionStyle = .none
        let config = SecureKeyboard.configuration

        switch setting {
        case .pinLength:
            content.text = "PIN length"
            cell.accessoryView = segmented(pinLengths.map(String.init),
                                           selected: pinLengths.firstIndex(of: config.pinLength) ?? 0) { [unowned self] index in
                SecureKeyboard.configure(pinLength: self.pinLengths[index])
            }

        case .shuffle:
            content.text = "Shuffle"
            let modes: [SecureKeyboardShuffleMode] = [.never, .onAppear, .afterEachTap]
            cell.accessoryView = segmented(["Off", "On open", "Each tap"],
                                           selected: modes.firstIndex(of: config.shuffleMode) ?? 0) { index in
                SecureKeyboard.configure(shuffleMode: modes[index])
            }

        case .fieldStyle:
            content.text = "PIN style"
            let styles: [SecurePINFieldStyle] = [.singleBox, .separateBoxes]
            cell.accessoryView = segmented(["One box", "Boxes"],
                                           selected: styles.firstIndex(of: config.fieldStyle) ?? 0) { index in
                SecureKeyboard.configure(fieldStyle: styles[index])
            }

        case .accessoryKey:
            content.text = "Extra key"
            let keys: [SecureKeyboardAccessoryKey] = [.none, .clear, .done]
            cell.accessoryView = segmented(["None", "Clear", "Done"],
                                           selected: keys.firstIndex(of: config.accessoryKey) ?? 0) { index in
                SecureKeyboard.configure(accessoryKey: keys[index])
            }

        case .accent:
            content.text = "Accent"
            cell.accessoryView = segmented(DemoAccent.allCases.map(\.title), selected: accent.rawValue) { [unowned self] index in
                self.accent = DemoAccent(rawValue: index)!
                SecureKeyboard.configure(accentColor: self.accent.color)
                self.tableView.reloadSections(IndexSet(integer: Section.demos.rawValue), with: .none)
            }

        case .haptics:
            content.text = "Haptic feedback"
            cell.accessoryView = toggle(config.hapticFeedback) { SecureKeyboard.configure(hapticFeedback: $0) }

        case .captureProtection:
            content.text = "Hide from screen capture"
            cell.accessoryView = toggle(config.protectsAgainstScreenCapture) {
                SecureKeyboard.configure(protectsAgainstScreenCapture: $0)
            }

        case .clearOnScreenshot:
            content.text = "Clear on screenshot"
            cell.accessoryView = toggle(config.clearsOnScreenshot) { SecureKeyboard.configure(clearsOnScreenshot: $0) }

        case .clearOnInactive:
            content.text = "Clear when app inactive"
            cell.accessoryView = toggle(config.clearsWhenAppResignsActive) {
                SecureKeyboard.configure(clearsWhenAppResignsActive: $0)
            }

        case .reset:
            content.text = "Reset to defaults"
            content.textProperties.color = .systemRed
            cell.selectionStyle = .default
        }
    }

    private func segmented(_ titles: [String], selected: Int, onChange: @escaping (Int) -> Void) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.selectedSegmentIndex = selected
        control.addAction(UIAction { action in
            guard let control = action.sender as? UISegmentedControl else { return }
            onChange(control.selectedSegmentIndex)
        }, for: .valueChanged)
        control.sizeToFit()
        return control
    }

    private func toggle(_ isOn: Bool, onChange: @escaping (Bool) -> Void) -> UISwitch {
        let control = UISwitch()
        control.isOn = isOn
        control.addAction(UIAction { action in
            guard let control = action.sender as? UISwitch else { return }
            onChange(control.isOn)
        }, for: .valueChanged)
        return control
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
