import XCTest
@testable import Clipsmith

final class LocalizationAuditTests: XCTestCase {
    private var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Clipsmith")
    }

    func testEveryKeyUsedInCodeIsTranslatedInBothLanguages() throws {
        let defined = try definedKeys(for: "en")
        let used = try keysReferencedInCode(knownPrefixes: prefixes(of: defined))

        let missing = used.subtracting(defined).sorted()

        XCTAssertEqual(missing, [], "Keys used in code but missing from Localizable.strings")
    }

    func testEveryTranslatedKeyIsUsedInCode() throws {
        let defined = try definedKeys(for: "en")
        let used = try keysReferencedInCode(knownPrefixes: prefixes(of: defined))

        let unused = defined.subtracting(used).sorted()

        XCTAssertEqual(unused, [], "Keys in Localizable.strings that no code references")
    }

    func testNoTranslationIsEmpty() throws {
        for language in ["en", "es"] {
            let table = try translations(for: language)
            let empty = table.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()

            XCTAssertEqual(empty, [], "Empty \(language) translations")
        }
    }

    func testFormatPlaceholdersMatchBetweenLanguages() throws {
        let english = try translations(for: "en")
        let spanish = try translations(for: "es")

        for (key, englishText) in english {
            XCTAssertEqual(placeholders(in: englishText), placeholders(in: spanish[key] ?? ""), "Placeholders differ for \(key)")
        }
    }

    private func translations(for language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language)
        )
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }

    private func definedKeys(for language: String) throws -> Set<String> {
        Set(try translations(for: language).keys)
    }

    private func prefixes(of keys: Set<String>) -> Set<String> {
        Set(keys.compactMap { $0.split(separator: ".").first.map(String.init) })
    }

    private func keysReferencedInCode(knownPrefixes: Set<String>) throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: #""([A-Za-z]+(?:\.[A-Za-z0-9]+)+)""#)
        var found = Set<String>()
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sourcesDirectory, includingPropertiesForKeys: nil))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
                let key = String(text[keyRange])
                if let prefix = key.split(separator: ".").first, knownPrefixes.contains(String(prefix)) {
                    found.insert(key)
                }
            }
        }
        return found
    }

    private func placeholders(in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"%(?:\d+\$)?[@dfs]"#)
        let range = NSRange(text.startIndex..., in: text)
        return (regex?.matches(in: text, range: range) ?? []).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
}
