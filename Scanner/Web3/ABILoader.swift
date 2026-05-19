import Foundation

enum ABILoader {
    static func load(_ name: String) -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("ABI resource missing from bundle: \(name).json")
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            fatalError("ABI resource unreadable: \(name).json — \(error)")
        }
    }
}
