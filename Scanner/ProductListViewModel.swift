import Foundation
import Web3
import BigInt

enum ProductListSource {
    case user(EthereumAddress)
    case manufacturer(EthereumAddress)
}

@MainActor
final class ProductListViewModel {
    let source: ProductListSource
    private let web3: Web3Service

    private(set) var products: [[String: Any]] = []
    private(set) var total: BigUInt = 0
    private(set) var offset: BigUInt = 0
    private(set) var isLoading = false

    var onChanged: (() -> Void)?

    init(source: ProductListSource, web3: Web3Service = Connect.connection) {
        self.source = source
        self.web3 = web3
    }

    var hasMore: Bool {
        products.count < total
    }

    func reset() {
        products.removeAll()
        offset = 0
        total = 0
        isLoading = false
        onChanged?()
    }

    func loadPage(limit: BigUInt) {
        guard !isLoading, offset <= total || total == 0
        else {
            return
        }
        isLoading = true
        onChanged?()

        Task {
            let result: ([[String: Any]], total: BigUInt)
            switch source {
            case .user(let addr):
                result = web3.getProductsByUserPaginated(userAddress: addr, offset: offset, limit: limit)
            case .manufacturer(let addr):
                result = web3.getProductsByManufacturerPaginated(manufacturerAddress: addr, offset: offset, limit: limit)
            }
            self.total = result.total
            self.offset += BigUInt(result.0.count)
            self.products.append(contentsOf: result.0)
            self.isLoading = false
            self.onChanged?()
        }
    }

    func updateStatus(productId: BigUInt, newStatus: UInt) {
        guard let idx = products.firstIndex(where: {
            ($0["id"] as? BigUInt) == productId })
        else {
            return
        }
        products[idx]["status"] = newStatus
        onChanged?()
    }

    func deleteProduct(at index: Int) async throws {
        guard products.indices.contains(index),
              let productId = products[index]["id"] as? BigUInt,
              let account = web3.account
        else {
            throw Web3Error.walletNotConnected
        }
        _ = try await web3.deleteProductInfo(
            companyAccount: Config.companyAccountAddress,
            employee: account,
            productId: productId
        )
        try? await Task.sleep(nanoseconds: 3_800_000_000)
    }
}
