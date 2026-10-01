import UIKit

/// Ready-made settings page that edits `SecureKeyboard.configuration`.
///
/// Every control calls `SecureKeyboard.configure(...)` with just the value it
/// changes, so the new settings apply to every secure keyboard opened
/// afterwards. Push it from your own "Configure" button:
///
///     @objc func configureTapped() {
///         navigationController?.pushViewController(SecureKeyboardSettingsViewController(), animated: true)
///     }
///
/// or use `SecureKeyboardSettingsViewController.present(from:)`, which wraps it
/// in a navigation controller with a Done button.
@MainActor
public final class SecureKeyboardSettingsViewController: UITableViewController {

    /// One choice in the accent colour row.
    public struct AccentOption {
        public var title: String
        public var color: UIColor

        public init(title: String, color: UIColor) {
            self.title = title
            self.color = color
        }

        public static let defaults: [AccentOption] = [
            AccentOption(title: "Indigo", color: SecureKeyboardConfiguration().accentColor),
            AccentOption(title: "Teal", color: .systemTeal),
            AccentOption(title: "Orange", color: .systemOrange),
            AccentOption(title: "Pink", color: .systemPink)
        ]
    }

    /// PIN lengths offered in the PIN length row.
    public var pinLengthOptions: [Int] = [4, 5, 6] {
        didSet { if isViewLoaded { tableView.reloadData() } }
    }

    /// Colours offered in the accent row.
    public var accentOptions: [AccentOption] = AccentOption.defaults {
        didSet { if isViewLoaded { tableView.reloadData() } }
    }

    /// Called after every change with the new app-wide configuration.
    public var onChange: ((SecureKeyboardConfiguration) -> Void)?

    private var renderedAccent: UIColor?

    private enum Section: Int, CaseIterable {
        case behaviour, appearance, security, reset

        var title: String? {
            switch self {
            case .behaviour: return "Behaviour"
            case .appearance: return "Appearance"
            case .security: return "Security"
            case .reset: return nil
            }
        }

        var footer: String? {
            switch self {
            case .security:
                return "Block screenshots blanks every screen hosted in a ScreenshotProtectedViewController in screenshots and recordings. iOS cannot stop the screenshot itself."
            default:
                return nil
            }
        }

        var rows: [Row] {
            switch self {
            case .behaviour: return [.pinLength, .shuffle, .accessoryKey, .haptics]
            case .appearance: return [.fieldStyle, .accent]
            case .security: return [.preventScreenshots, .captureProtection, .clearOnScreenshot, .clearOnInactive]
            case .reset: return [.reset]
            }
        }
    }

    private enum Row {
        case pinLength, shuffle, accessoryKey, haptics
        case fieldStyle, accent
        case preventScreenshots, captureProtection, clearOnScreenshot, clearOnInactive
        case reset
    }

    public init() {
        super.init(style: .insetGrouped)
        title = "Keyboard Settings"
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        title = "Keyboard Settings"
    }

    /// Presents the page modally inside a navigation controller with a Done
    /// button.
    @discardableResult
    public static func present(from presenter: UIViewController,
                               animated: Bool = true) -> SecureKeyboardSettingsViewController {
        let settings = SecureKeyboardSettingsViewController()
        settings.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak settings] _ in settings?.dismiss(animated: true) }
        )
        let navigation = UINavigationController(rootViewController: settings)
        presenter.present(navigation, animated: animated)
        return settings
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(configurationDidChange),
                                               name: SecureKeyboard.configurationDidChangeNotification,
                                               object: nil)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc private func configurationDidChange() {
        // Controls already show the value they just set; rebuild only when the
        // tint every control uses changed, so switches finish animating.
        let accent = SecureKeyboard.configuration.accentColor
        if !accent.isEqual(renderedAccent) { tableView.reloadData() }
        onChange?(SecureKeyboard.configuration)
    }

    // MARK: Table

    public override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section)!.rows.count
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)!.title
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section(rawValue: section)!.footer
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.cell()
        cell.selectionStyle = .none
        let config = SecureKeyboard.configuration
        renderedAccent = config.accentColor

        switch Section(rawValue: indexPath.section)!.rows[indexPath.row] {
        case .pinLength:
            content.text = "PIN length"
            let lengths = pinLengthOptions
            cell.accessoryView = segmented(lengths.map(String.init),
                                           selected: lengths.firstIndex(of: config.pinLength) ?? UISegmentedControl.noSegment) { index in
                SecureKeyboard.configure(pinLength: lengths[index])
            }

        case .shuffle:
            content.text = "Shuffle"
            let modes: [SecureKeyboardShuffleMode] = [.never, .onAppear, .afterEachTap]
            cell.accessoryView = segmented(["Off", "On open", "Each tap"],
                                           selected: modes.firstIndex(of: config.shuffleMode) ?? 0) { index in
                SecureKeyboard.configure(shuffleMode: modes[index])
            }

        case .accessoryKey:
            content.text = "Extra key"
            let keys: [SecureKeyboardAccessoryKey] = [.none, .clear, .done]
            cell.accessoryView = segmented(["None", "Clear", "Done"],
                                           selected: keys.firstIndex(of: config.accessoryKey) ?? 0) { index in
                SecureKeyboard.configure(accessoryKey: keys[index])
            }

        case .haptics:
            content.text = "Haptic feedback"
            cell.accessoryView = toggle(config.hapticFeedback) { SecureKeyboard.configure(hapticFeedback: $0) }

        case .fieldStyle:
            content.text = "PIN style"
            let styles: [SecurePINFieldStyle] = [.singleBox, .separateBoxes]
            cell.accessoryView = segmented(["One box", "Boxes"],
                                           selected: styles.firstIndex(of: config.fieldStyle) ?? 0) { index in
                SecureKeyboard.configure(fieldStyle: styles[index])
            }

        case .accent:
            content.text = "Accent"
            let options = accentOptions
            let selected = options.firstIndex { $0.color.isEqual(config.accentColor) } ?? UISegmentedControl.noSegment
            cell.accessoryView = segmented(options.map(\.title), selected: selected) { index in
                SecureKeyboard.configure(accentColor: options[index].color)
            }

        case .preventScreenshots:
            content.text = "Block screenshots"
            content.secondaryText = "Whole screen is blank when captured"
            cell.accessoryView = toggle(config.preventsScreenshots) { SecureKeyboard.configure(preventsScreenshots: $0) }

        case .captureProtection:
            content.text = "Hide keypad from capture"
            content.secondaryText = "Keypad blank; input hidden while recording"
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
            content.textProperties.alignment = .center
            cell.selectionStyle = .default
        }

        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section)!.rows[indexPath.row] == .reset {
            SecureKeyboard.resetConfiguration()
            tableView.reloadData()
        }
    }

    // MARK: Controls

    private func segmented(_ titles: [String], selected: Int, onChange: @escaping (Int) -> Void) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.selectedSegmentIndex = selected
        control.selectedSegmentTintColor = SecureKeyboard.configuration.accentColor
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
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
        control.onTintColor = SecureKeyboard.configuration.accentColor
        control.addAction(UIAction { action in
            guard let control = action.sender as? UISwitch else { return }
            onChange(control.isOn)
        }, for: .valueChanged)
        return control
    }
}
