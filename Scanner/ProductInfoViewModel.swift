import UIKit
import Web3
import BigInt

@MainActor
final class ProductInfoViewModel {
    private(set) var product: ProductInfo
    private(set) var pathRecords: [PathRecord] = []
    private(set) var conditions: [ConditionRecord] = []

    let role: WalletRole?
    private let web3: Web3Service

    var onProductChanged: (() -> Void)?
    var onPathChanged: (() -> Void)?
    var onConditionsChanged: (() -> Void)?
    var onCertificatesChanged: (() -> Void)?
    var onStatusChanged: ((BigUInt, UInt) -> Void)?

    init(product: ProductInfo, role: WalletRole?, web3: Web3Service = Connect.connection) {
        self.product = product
        self.role = role
        self.web3 = web3
    }

    var productId: BigUInt { product.id }
    var status: UInt { product.status }
    var certificates: [String] { product.certificates }
    var hasPublicKey: Bool { !product.publicKey.isEmpty }
    var canManageCertificates: Bool { role == .manufacturer_cert_emp }

    var manufacturerAddress: EthereumAddress {
        (try? EthereumAddress(hex: Config.companyAccountAddress, eip55: false))
            ?? (try! EthereumAddress(hex: "0x0000000000000000000000000000000000000000", eip55: false))
    }

    func daysInTransit() -> Int {
        let now = Date().timeIntervalSince1970
        let end: TimeInterval = (status == 3 && !pathRecords.isEmpty)
            ? pathRecords.last!.timestamp
            : now
        guard product.timestamp > 0, end > product.timestamp else { return 0 }
        return Int((end - product.timestamp) / 86_400)
    }

    func load() async {
        do {
            async let pathTask = web3.fetchPathHistory(productId: productId, manufacturerAddress: manufacturerAddress)
            async let condTask = web3.fetchConditionLogs(productId: productId, manufacturerAddress: manufacturerAddress)
            let info = web3.getProductInfo(productID: productId, manufacturerAccountAddress: manufacturerAddress)
            let (path, cond) = try await (pathTask, condTask)
            self.pathRecords = path
            self.conditions = cond
            if let pk = info["publicKey"] as? String, !pk.isEmpty {
                product.publicKey = pk
            } else if let pkd = info["publicKey"] as? Data, !pkd.isEmpty {
                product.publicKey = pkd.map { String(format: "%02x", $0) }.joined()
            }
            if let s = info["status"] as? UInt {
                product.status = s
                onStatusChanged?(productId, s)
            }
            onPathChanged?()
            onConditionsChanged?()
            onProductChanged?()
        } catch {
            print("loadOnChainData failed: \(error)")
        }
    }

    func changeStatus() async throws {
        guard let account = await web3.ensureConnectedWallet() else {
            throw Web3Error.walletNotConnected
        }
        let addr = try EthereumAddress(hex: Config.companyAccountAddress, eip55: false)
        _ = try await web3.changeStatus(
            companyAccount: Config.companyAccountAddress,
            employee: account,
            productId: productId,
            manufacturerAddress: addr
        )
        let newStatus: UInt = status + 1
        product.status = newStatus
        onProductChanged?()
        onStatusChanged?(productId, newStatus)
    }

    func logPath(toAddress: String, location: String, note: String) async throws {
        let to = try EthereumAddress(hex: toAddress, eip55: false)
        let manu = try EthereumAddress(hex: Config.companyAccountAddress, eip55: false)
        guard let employee = await web3.ensureConnectedWallet() else {
            throw Web3Error.walletNotConnected
        }
        _ = try await web3.logPathHistory(
            companyAccount: Config.companyAccountAddress,
            employee: employee,
            productId: productId,
            manufacturerAddress: manu,
            to: to,
            location: location,
            note: note
        )
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        await load()
    }

    func generateQR() async throws -> (image: UIImage, publicKey: String) {
        let (image, pubKey) = try await web3.generateProductQR(
            productId: productId,
            manufacturerAddress: manufacturerAddress
        )
        return (image, pubKey)
    }

    func submitPublicKey(_ pubKey: String) async throws {
        guard let employee = web3.account else {
            throw Web3Error.walletNotConnected
        }
        _ = try await web3.addProductPublicKey(
            companyAccount: Config.companyAccountAddress,
            employee: employee,
            productId: productId,
            publicKeyCompressed: pubKey
        )

        try? await Task.sleep(nanoseconds: 3_500_000_000)
        await load()
    }

    func uploadCertificate(data: Data, filename: String, mime: String) async throws {
        guard let employee = web3.account else {
            throw Web3Error.walletNotConnected
        }
        let uploaded = try await Pinata.uploadData(data, filename: filename, mime: mime)
        let onchain = "ipfs://\(uploaded.cid)"
        CertificateCache.warm(cid: uploaded.cid, data: data, filename: filename)
        _ = try await web3.addProductCertificate(
            companyAccount: Config.companyAccountAddress,
            employee: employee,
            productId: productId,
            certificateURL: onchain
        )
        try? await Task.sleep(nanoseconds: 3_800_000_000)
        product.certificates.append(onchain)
        onCertificatesChanged?()
    }

    func deleteCertificate(at index: Int) async throws {
        guard index < product.certificates.count, let employee = web3.account else { return }
        let url = product.certificates[index]
        let cid = Pinata.extractCID(from: url)
        _ = try await web3.deleteProductCertificate(
            companyAccount: Config.companyAccountAddress,
            employee: employee,
            productId: productId,
            index: BigUInt(index)
        )
        try? await Task.sleep(nanoseconds: 3_800_000_000)
        try? await Pinata.unpin(cid: cid)
        CertificateCache.evict(cid: cid)
        product.certificates.remove(at: index)
        onCertificatesChanged?()
    }
}
