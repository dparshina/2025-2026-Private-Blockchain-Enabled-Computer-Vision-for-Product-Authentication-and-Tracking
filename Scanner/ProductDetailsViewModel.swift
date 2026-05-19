import Foundation
import Web3
import BigInt

@MainActor
final class ProductDetailsViewModel {
    let productId: BigUInt
    let manufacturerAddress: EthereumAddress
    let role: WalletRole?
    private let web3: Web3Service

    private(set) var product: ProductInfo?
    private(set) var status: UInt?

    private(set) var logConditionDone = false
    private(set) var pathOrDeliverDone = false

    var onLoaded: (() -> Void)?
    var onStatusChanged: (() -> Void)?
    var onLogisticsAvailabilityChanged: (() -> Void)?

    init(productId: BigUInt,
         manufacturerAddress: EthereumAddress,
         role: WalletRole?,
         web3: Web3Service = Connect.connection) {
        self.productId = productId
        self.manufacturerAddress = manufacturerAddress
        self.role = role
        self.web3 = web3
    }

    var isLogistics: Bool {
        role == .logistics_admin || role == .logistics_emp
    }
    var canConfirmReceipt: Bool {
        role == .recipient && status == 3
    }

    func load() {
        Task.detached { [weak self] in
            guard let self else { return }
            let info = await self.web3.getProductInfo(productID: self.productId, manufacturerAccountAddress: self.manufacturerAddress)
            print(info)
            let parsed = ProductInfo(dict: info)
            await MainActor.run {
                self.product = parsed
                self.status = parsed.status
                self.onLoaded?()
            }
        }
    }

    func markDelivered() async throws {
        guard let employee = await web3.ensureConnectedWallet()
        else {
            throw Web3Error.walletNotConnected
        }
        _ = try await web3.changeStatus(
            companyAccount: Config.logisticsAccountAddress,
            employee: employee,
            productId: productId,
            manufacturerAddress: manufacturerAddress
        )
        status = 3
        pathOrDeliverDone = true
        onStatusChanged?()
        onLogisticsAvailabilityChanged?()
    }

    func logPath(toAddress: String, location: String, note: String) async throws {
        let to = try EthereumAddress(hex: toAddress, eip55: false)
        guard let employee = await web3.ensureConnectedWallet()
        else {
            throw Web3Error.walletNotConnected
        }
        _ = try await web3.logPathHistory(
            companyAccount: Config.logisticsAccountAddress,
            employee: employee,
            productId: productId,
            manufacturerAddress: manufacturerAddress,
            to: to,
            location: location,
            note: note
        )
        pathOrDeliverDone = true
        onLogisticsAvailabilityChanged?()
    }

    func markLogConditionDone() {
        logConditionDone = true
        onLogisticsAvailabilityChanged?()
    }

    func submitVerification(isValid: Bool) async throws {
        guard let role, role != .recipient
        else {
            return
        }
        guard let employee = await web3.ensureConnectedWallet()
        else {
            throw Web3Error.walletNotConnected
        }
        let companyAccount: String
        switch role {
        case .logistics_admin, .logistics_emp:
            companyAccount = Config.logisticsAccountAddress
        default:
            companyAccount = manufacturerAddress.hex(eip55: true)
        }
        _ = try await web3.verifyProductEvent(
            companyAccount: companyAccount,
            employee: employee,
            productId: productId,
            manufacturerAddress: manufacturerAddress,
            isValid: isValid
        )
    }

    func confirmReceipt() async throws {
        _ = await web3.ensureConnectedWallet()
        _ = try await web3.confirmReceipt(productId: productId, manufacturerAddress: manufacturerAddress)
        status = 4
        onStatusChanged?()
    }

    static func statusName(_ s: UInt) -> String {
        switch s {
        case 0: return "Awaiting"
        case 1: return "Initialized"
        case 2: return "In Transit"
        case 3: return "Delivered"
        case 4: return "Received"
        default: return "Unknown"
        }
    }
}
