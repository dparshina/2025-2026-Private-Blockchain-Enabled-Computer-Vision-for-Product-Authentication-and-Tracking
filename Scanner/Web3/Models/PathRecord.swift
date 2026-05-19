import Foundation
import Web3
import BigInt

struct PathRecord {
    let from: EthereumAddress
    let to: EthereumAddress
    let location: String
    let note: String
    let timestamp: TimeInterval

    init?(tuple: [String: Any]) {
        guard let from = tuple["from"] as? EthereumAddress,
              let to = tuple["to"] as? EthereumAddress,
              let location = tuple["location"] as? String,
              let note = tuple["note"] as? String,
              let ts = tuple["timestamp"] as? BigUInt
        else { return nil }
        self.from = from
        self.to = to
        self.location = location
        self.note = note
        self.timestamp = TimeInterval(ts)
    }
}
