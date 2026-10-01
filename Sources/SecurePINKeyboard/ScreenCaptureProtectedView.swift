import UIKit

/// Hosts content inside UIKit's secure text-field canvas so screenshots and
/// screen recordings render those regions blank.
///
/// Add your views to `contentView`. If UIKit's private canvas cannot be found
/// (layout changes between iOS versions), content falls back to a normal,
/// unprotected container instead of disappearing; check `isProtected`.
public final class ScreenCaptureProtectedView: UIView {

    public let contentView = UIView()
    public private(set) var isProtected = false

    private let secureTextField = SecureCanvasTextField()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let contentPoint = contentView.convert(point, from: self)
        if contentView.bounds.contains(contentPoint),
           let hitView = contentView.hitTest(contentPoint, with: event) {
            return hitView
        }
        return nil
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        clipsToBounds = false

        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false

        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.backgroundColor = .clear
        // Must stay enabled: UITableView (and others) skip tap-up selection
        // when an ancestor has interaction disabled. Its own gestures are
        // stripped and `hitTest` routes touches to `contentView`, so the field
        // itself never handles a touch.
        secureTextField.isUserInteractionEnabled = true
        secureTextField.isAccessibilityElement = false
        secureTextField.accessibilityElementsHidden = true
        secureTextField.borderStyle = .none
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        secureTextField.text = " "
        secureTextField.isSecureTextEntry = true
        // The hosted content decides the size, never the text field's own
        // intrinsic height.
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            secureTextField.setContentHuggingPriority(.fittingSizeLevel, for: axis)
            secureTextField.setContentCompressionResistancePriority(.fittingSizeLevel, for: axis)
        }

        addSubview(secureTextField)
        pin(secureTextField, to: self)

        // Force UIKit to build the secure canvas before we attach content.
        secureTextField.layoutIfNeeded()
        secureTextField.stripTextInteractions()

        if let canvas = secureCanvas() {
            canvas.isUserInteractionEnabled = true
            canvas.backgroundColor = .clear
            canvas.addSubview(contentView)
            pin(contentView, to: secureTextField)
            isProtected = true
        } else {
            addSubview(contentView)
            pin(contentView, to: self)
        }
    }

    /// The private `_UITextLayoutCanvasView` (name varies by iOS version).
    private func secureCanvas() -> UIView? {
        let subviews = secureTextField.subviews
        return subviews.first { String(describing: type(of: $0)).contains("Canvas") } ?? subviews.first
    }

    private func pin(_ view: UIView, to target: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: target.topAnchor),
            view.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])
    }
}

/// Secure-entry text field used only for its capture-proof canvas.
///
/// UIKit collects gesture recognizers from every ancestor of the touched
/// view, even ones with `isUserInteractionEnabled = false`. A text field's
/// tap / loupe / drag / context-menu recognizers would therefore sit above all
/// hosted content and cancel its touches (table rows never get selected, tap
/// gestures never fire). `stripTextInteractions()` removes them for good; the
/// capture protection comes from `isSecureTextEntry` alone.
private final class SecureCanvasTextField: UITextField {

    private var isStripped = false

    /// Removes every interaction and gesture recognizer and drops any UIKit
    /// tries to add later (it re-installs some on trait or state changes).
    func stripTextInteractions() {
        isStripped = true
        removeTextInteractions()
    }

    private func removeTextInteractions() {
        for interaction in interactions {
            removeInteraction(interaction)
        }
        for recognizer in gestureRecognizers ?? [] {
            removeGestureRecognizer(recognizer)
        }
    }

    // UIKit re-installs some recognizers through private paths that bypass
    // the overrides below; sweep them again whenever the field lays out.
    override func layoutSubviews() {
        super.layoutSubviews()
        if isStripped { removeTextInteractions() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isStripped { removeTextInteractions() }
    }

    override func addInteraction(_ interaction: UIInteraction) {
        guard !isStripped else { return }
        super.addInteraction(interaction)
    }

    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        guard !isStripped else { return }
        super.addGestureRecognizer(gestureRecognizer)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override var canBecomeFirstResponder: Bool { false }
}
