import Foundation
import Web3
import BigInt
import UIKit

protocol Web3Service: AnyObject {

    var account: EthereumAddress? { get }
    func switchToSepolia() async throws
    func sign(userHash: String) async throws -> String
    func ensureConnectedWallet() async -> EthereumAddress?

    func warmUp()

    func checkManufacturer(manufacturer: EthereumAddress, employee: EthereumAddress) -> String
    func checkLogisticsProvider(logistics: EthereumAddress, employee: EthereumAddress) -> String
    func resolveRole(for address: String) async -> WalletRole

    func getProductInfo(productID: BigUInt, manufacturerAccountAddress: EthereumAddress) -> [String: Any]
    func getProductsByManufacturerPaginated(manufacturerAddress: EthereumAddress, offset: BigUInt, limit: BigUInt) -> ([[String: Any]], total: BigUInt)
    func getProductsByUserPaginated(userAddress: EthereumAddress, offset: BigUInt, limit: BigUInt) -> ([[String: Any]], total: BigUInt)
    func fetchPathHistory(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> [PathRecord]
    func fetchConditionLogs(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> [ConditionRecord]

    func addProductInfo(companyAccount: String, employee: EthereumAddress, name: String, serialNumber: String, origin: String, destination: String, mass: BigUInt, recipient: EthereumAddress) async throws -> String
    func deleteProductInfo(companyAccount: String, employee: EthereumAddress, productId: BigUInt) async throws -> String
    func addProductCertificate(companyAccount: String, employee: EthereumAddress, productId: BigUInt, certificateURL: String) async throws -> String
    func addProductPublicKey(companyAccount: String, employee: EthereumAddress, productId: BigUInt, publicKeyCompressed: String) async throws -> String
    func deleteProductCertificate(companyAccount: String, employee: EthereumAddress, productId: BigUInt, index: BigUInt) async throws -> String
    func changeStatus(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> String
    func logPathHistory(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, to: EthereumAddress, location: String, note: String) async throws -> String
    func logCondition(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, conditionType: String, value: Int, unit: String) async throws -> String
    func verifyProductEvent(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, isValid: Bool) async throws -> String
    func confirmReceipt(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> String

    func addManufacturer(manufacturerAddress: EthereumAddress) async throws -> String
    func deleteManufacturer(manufacturerAddress: EthereumAddress) async throws -> String
    func addLogisticsProvider(logisticsAddress: EthereumAddress) async throws -> String
    func deleteLogisticsProvider(logisticsAddress: EthereumAddress) async throws -> String

    func generateProductQR(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> (qrImage: UIImage, publicKey: String)

    func addDeposit(money: BigUInt) async throws -> String
    func getDeposit() async throws -> BigUInt
    func withdrawDeposit(withdrawTo: String, money: BigUInt) async throws -> String
}

extension Connect: Web3Service {}
