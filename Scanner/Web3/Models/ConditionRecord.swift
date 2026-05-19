import Foundation
import BigInt

struct ConditionRecord {
    let type: String
    let value: BigInt
    let unit: String
    let timestamp: TimeInterval

    init?(tuple: [String: Any]) {
        guard let type = tuple["conditionType"] as? String,
              let unit = tuple["unit"] as? String,
              let ts = tuple["timestamp"] as? BigUInt
        else { return nil }
        let v = (tuple["value"] as? BigInt) ?? (tuple["value"] as? BigUInt).map { BigInt($0) } ?? 0
        self.type = type
        self.value = v
        self.unit = unit
        self.timestamp = TimeInterval(ts)
    }
}
