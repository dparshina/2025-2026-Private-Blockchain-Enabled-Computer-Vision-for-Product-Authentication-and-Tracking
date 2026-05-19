import Foundation
import Web3
import BigInt

struct OnChainProduct {
    let id: BigUInt
    let name: String
    let serialNumber: String
    let manufacturer: EthereumAddress
    let origin: String
    let destination: String
    let status: UInt
    let mass: BigUInt
    let certificates: [String]
    let recipient: EthereumAddress
    let timestamp: TimeInterval

    init?(tuple: [String: Any]) {
        guard let id = tuple["id"] as? BigUInt,
              let name = tuple["name"] as? String,
              let serialNumber = tuple["serialNumber"] as? String,
              let manufacturer = tuple["manufacturer"] as? EthereumAddress,
              let origin = tuple["origin"] as? String,
              let destination = tuple["destination"] as? String,
              let mass = tuple["mass"] as? BigUInt,
              let recipient = tuple["recipient"] as? EthereumAddress,
              let ts = tuple["timestamp"] as? BigUInt
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.serialNumber = serialNumber
        self.manufacturer = manufacturer
        self.origin = origin
        self.destination = destination
        self.mass = mass
        self.recipient = recipient
        self.timestamp = TimeInterval(ts)

        if let s = tuple["status"] as? UInt8 {
            self.status = UInt(s)
        } else if let s = tuple["status"] as? UInt {
            self.status = s
        } else {
            self.status = 0
        }

        self.certificates = (tuple["certificates"] as? [String])
            ?? (tuple["certificats"] as? [String])
            ?? []
    }
}
