import UIKit

/// Container that renders another view controller inside the secure canvas,
/// so screenshots, screen recordings and mirroring show that whole screen
/// blank.
///
/// iOS offers no API to stop the user from taking a screenshot; this makes
/// the screenshot useless instead. Wrap the window's root to protect the
/// whole app, or wrap a single screen before pushing it:
///
///     window.rootViewController = ScreenshotProtectedViewController(
///         rootViewController: UINavigationController(rootViewController: home))
///
///     navigationController?.pushViewController(
///         ScreenshotProtectedViewController(rootViewController: login), animated: true)
///
/// View controllers presented *modally* from inside the container are drawn by
/// UIKit outside of it; wrap those too (or push them) to keep them protected.
@MainActor
public final class ScreenshotProtectedViewController: UIViewController {

    public let rootViewController: UIViewController

    /// Whether the content is currently in the secure canvas. When the
    /// container follows the global configuration this tracks
    /// `SecureKeyboard.configuration.preventsScreenshots`.
    public var isProtectionEnabled: Bool {
        didSet {
            guard isProtectionEnabled != oldValue, isViewLoaded else { return }
            attachContent()
        }
    }

    /// `false` if UIKit's secure canvas could not be found on this iOS
    /// version, in which case content is shown unprotected rather than hidden.
    public var isProtectionAvailable: Bool { protectedView.isProtected }

    private let followsConfiguration: Bool
    private let protectedView = ScreenCaptureProtectedView()

    /// - Parameter isProtectionEnabled: A fixed value, or `nil` (default) to
    ///   follow `SecureKeyboard.configuration.preventsScreenshots` live.
    public init(rootViewController: UIViewController, isProtectionEnabled: Bool? = nil) {
        self.rootViewController = rootViewController
        self.followsConfiguration = isProtectionEnabled == nil
        self.isProtectionEnabled = isProtectionEnabled ?? SecureKeyboard.configuration.preventsScreenshots
        super.init(nibName: nil, bundle: nil)

        if followsConfiguration {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(configurationDidChange),
                                                   name: SecureKeyboard.configurationDidChangeNotification,
                                                   object: nil)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported; use init(rootViewController:)")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        protectedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(protectedView)
        pin(protectedView, to: view)

        addChild(rootViewController)
        attachContent()
        rootViewController.didMove(toParent: self)
    }

    @objc private func configurationDidChange() {
        isProtectionEnabled = SecureKeyboard.configuration.preventsScreenshots
    }

    /// Moves the child's view into (or out of) the secure canvas.
    private func attachContent() {
        let content = rootViewController.view!
        let parent = isProtectionEnabled ? protectedView.contentView : view!
        guard content.superview !== parent else { return }

        content.removeFromSuperview()
        content.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(content)
        pin(content, to: parent)
        protectedView.isHidden = !isProtectionEnabled
    }

    private func pin(_ view: UIView, to target: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: target.topAnchor),
            view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])
    }

    // MARK: Forwarding to the wrapped controller

    public override var navigationItem: UINavigationItem { rootViewController.navigationItem }
    public override var title: String? {
        get { rootViewController.title }
        set { rootViewController.title = newValue }
    }
    public override var hidesBottomBarWhenPushed: Bool {
        get { rootViewController.hidesBottomBarWhenPushed }
        set { rootViewController.hidesBottomBarWhenPushed = newValue }
    }
    public override var childForStatusBarStyle: UIViewController? { rootViewController }
    public override var childForStatusBarHidden: UIViewController? { rootViewController }
    public override var childForHomeIndicatorAutoHidden: UIViewController? { rootViewController }
    public override var childForScreenEdgesDeferringSystemGestures: UIViewController? { rootViewController }
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        rootViewController.supportedInterfaceOrientations
    }
}
