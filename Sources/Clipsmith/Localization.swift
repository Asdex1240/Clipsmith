import Foundation

extension Bundle {
    private static let resourceBundleName = "Clipsmith_Clipsmith.bundle"

    static let clipsmith: Bundle = {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName)
        return packaged.flatMap { Bundle(url: $0) } ?? Bundle.module
    }()
}

func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .clipsmith)
}
