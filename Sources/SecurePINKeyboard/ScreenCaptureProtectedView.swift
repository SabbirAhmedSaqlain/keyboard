import UIKit

public final class ScreenCaptureProtectedView: UIView {

    public let contentView = UIView()

    private let secureTextField = UITextField(frame: .zero)

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
        if let hitView = contentView.hitTest(contentPoint, with: event) {
            return hitView
        }
        return super.hitTest(point, with: event)
    }

    private func setup() {
        backgroundColor = SecurePINStyle.surface
        contentView.backgroundColor = SecurePINStyle.surface

        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = true
        secureTextField.isAccessibilityElement = false
        secureTextField.accessibilityElementsHidden = true
        secureTextField.backgroundColor = .clear
        secureTextField.borderStyle = .none
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        secureTextField.text = " "
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        secureTextField.layoutIfNeeded()

        guard let protectedCanvas = secureTextField.subviews.first else {
            installUnprotectedFallback()
            return
        }

        protectedCanvas.backgroundColor = SecurePINStyle.surface
        protectedCanvas.isUserInteractionEnabled = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        protectedCanvas.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: secureTextField.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: secureTextField.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: secureTextField.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: secureTextField.bottomAnchor)
        ])
    }

    private func installUnprotectedFallback() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
