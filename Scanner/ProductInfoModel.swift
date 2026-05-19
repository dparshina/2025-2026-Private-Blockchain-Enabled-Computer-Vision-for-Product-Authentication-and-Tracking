import Foundation
import BigInt

struct ProductInfo {
    var id: BigUInt
    var name: String
    var serialNumber: String
    var origin: String
    var destination: String
    var mass: String
    var recipient: String
    var manufacturer: String
    var status: UInt
    var timestamp: TimeInterval
    var publicKey: String
    var certificates: [String]

    init(dict: [String: Any]) {
        self.id = dict["id"] as? BigUInt ?? 0
        self.name = dict["name"] as? String ?? "Unit"
        self.serialNumber = dict["serialNumber"] as? String ?? "—"
        self.origin = dict["origin"] as? String ?? "—"
        self.destination = dict["destination"] as? String ?? "—"
        if let mass = dict["mass"] as? BigUInt {
            self.mass = "\(mass) kg"
        } else if let mass = dict["mass"] as? Int {
            self.mass = "\(mass) kg"
        } else {
            self.mass = "—"
        }
        self.recipient = dict["recipient"] as? String ?? "—"
        self.manufacturer = dict["manufacturer"] as? String ?? "—"
        self.status = (dict["status"] as? UInt) ?? 0
        self.timestamp = (dict["timestamp"] as? TimeInterval) ?? 0
        if let publicKeyString = dict["publicKey"] as? String {
            self.publicKey = publicKeyString
        } else if let publicKeyData = dict["publicKey"] as? Data {
            self.publicKey = publicKeyData.isEmpty ? "" : publicKeyData.map { String(format: "%02x", $0) }.joined()
        } else {
            self.publicKey = ""
        }
        self.certificates = (dict["certificates"] as? [String])
            ?? (dict["certificats"] as? [String])
            ?? []
    }
}
