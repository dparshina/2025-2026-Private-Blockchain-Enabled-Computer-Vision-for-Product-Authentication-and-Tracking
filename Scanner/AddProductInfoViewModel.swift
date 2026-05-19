import UIKit
import Web3
import BigInt

@MainActor
final class AddProductInfoViewModel {
    struct Field {
        let label: String
        var value: String
        let placeholder: String
        let keyboardType: UIKeyboardType
    }

    enum ValidationError: LocalizedError {
        case emptyFields
        case invalidMass
        case invalidRecipient
        case noAccount

        var errorDescription: String? {
            switch self {
            case .emptyFields:
                return "Please fill in all fields"
            case .invalidMass:
                return "Mass must be a whole number"
            case .invalidRecipient:
                return "Recipient address is invalid"
            case .noAccount:
                return "No connected account"
            }
        }
    }

    private(set) var fields: [Field] = [
        Field(label: "Product name", value: "", placeholder: "Enter product name",       keyboardType: .default),
        Field(label: "Serial number", value: "", placeholder: "Enter serial number",      keyboardType: .default),
        Field(label: "Origin", value: "", placeholder: "Enter origin", keyboardType: .default),
        Field(label: "Destination", value: "", placeholder: "Enter destination",        keyboardType: .default),
        Field(label: "Mass", value: "", placeholder: "Enter mass (kg)", keyboardType: .numberPad),
        Field(label: "Recipient", value: "", placeholder: "Enter recipient address",  keyboardType: .default),
    ]

    private let web3: Web3Service

    init(web3: Web3Service = Connect.connection) {
        self.web3 = web3
    }

    func updateValue(at index: Int, _ value: String) {
        guard fields.indices.contains(index) else { return }
        fields[index].value = value
    }

    func submit() async throws {
        let trimmed = fields.map {
            $0.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard trimmed.allSatisfy({ !$0.isEmpty })
        else {
            throw ValidationError.emptyFields
        }

        guard let mass = BigUInt(trimmed[4])
        else {
            throw ValidationError.invalidMass
        }
        guard let recipient = try? EthereumAddress(hex: trimmed[5], eip55: false)
        else {
            throw ValidationError.invalidRecipient
        }
        guard let employee = web3.account
        else {
            throw ValidationError.noAccount
        }

        let opHash = try await web3.addProductInfo(
            companyAccount: Config.companyAccountAddress,
            employee: employee,
            name: trimmed[0],
            serialNumber: trimmed[1],
            origin: trimmed[2],
            destination: trimmed[3],
            mass: mass,
            recipient: recipient
        )
        print("Successfully sent UserOp. Op Hash: \(opHash)")
    }
}
