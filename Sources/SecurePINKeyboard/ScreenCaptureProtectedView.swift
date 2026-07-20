import UIKit

/// Hosts content inside UIKit's secure text-field canvas so screenshots /
/// screen recordings render those regions as black / empty.
public final class ScreenCaptureProtectedView: UIView {

    public let contentView = UIView()

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
        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Force UIKit to build the secure canvas before we attach content.
        secureTextField.layoutIfNeeded()

        if let canvas = secureTextField.subviews.first {
            canvas.isUserInteractionEnabled = true
            canvas.backgroundColor = .clear
            canvas.addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: secureTextField.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: secureTextField.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: secureTextField.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: secureTextField.bottomAnchor)
            ])
        } else {
            addSubview(contentView)
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: topAnchor),
                contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        DispatchQueue.main.async { [weak self] in
            self?.secureTextField.isSecureTextEntry = true
        }
    }
}
