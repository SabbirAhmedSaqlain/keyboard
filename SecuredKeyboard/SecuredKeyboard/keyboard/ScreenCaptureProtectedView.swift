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

    private let secureTextField = UITextField()

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
        secureTextField.isUserInteractionEnabled = false
        secureTextField.isAccessibilityElement = false
        secureTextField.accessibilityElementsHidden = true
        secureTextField.borderStyle = .none
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        secureTextField.text = " "
        secureTextField.isSecureTextEntry = true

        addSubview(secureTextField)
        pin(secureTextField, to: self)

        // Force UIKit to build the secure canvas before we attach content.
        secureTextField.layoutIfNeeded()

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
