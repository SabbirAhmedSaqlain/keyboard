import UIKit

enum SecurePINStyle {

    static let defaultAccent = UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)

    static var appBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .systemGroupedBackground
        }
        return UIColor(red: 242 / 255, green: 243 / 255, blue: 247 / 255, alpha: 1)
    }

    static var surface: UIColor {
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        return .white
    }

    static var elevatedSurface: UIColor {
        if #available(iOS 13.0, *) {
            return .secondarySystemGroupedBackground
        }
        return UIColor(red: 246 / 255, green: 247 / 255, blue: 250 / 255, alpha: 1)
    }

    static var primaryText: UIColor {
        if #available(iOS 13.0, *) {
            return .label
        }
        return .black
    }

    static var secondaryText: UIColor {
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        return UIColor(white: 0.42, alpha: 1)
    }

    static var separator: UIColor {
        if #available(iOS 13.0, *) {
            return .separator
        }
        return UIColor(white: 0.82, alpha: 1)
    }

    static func applyContinuousCornerCurve(to layer: CALayer) {
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
    }

    static func image(named systemName: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: systemName)
        }
        return nil
    }
}
