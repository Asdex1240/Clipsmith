import Foundation

func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
