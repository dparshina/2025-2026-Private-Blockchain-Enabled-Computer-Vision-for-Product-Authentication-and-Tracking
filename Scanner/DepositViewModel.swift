import Foundation
import BigInt

struct BalanceState {
    var balanceSep: String
    var network: String
    var isBalanceHidden: Bool
}

@MainActor
final class DepositViewModel {
    private(set) var state = BalanceState(
        balanceSep: "...",
        network: "Sepolia Testnet",
        isBalanceHidden: false
    )

    private let web3: Web3Service
    var onStateChanged: (() -> Void)?

    init(web3: Web3Service = Connect.connection) {
        self.web3 = web3
    }

    func toggleHidden() {
        state.isBalanceHidden.toggle()
        onStateChanged?()
    }

    func load() {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let wei = try await web3.getDeposit()
                let formatted = formatWei(wei)
                await MainActor.run {
                    self.state.balanceSep = formatted
                    self.onStateChanged?()
                }
            } catch {
                print("Failed to load balance:", error)
            }
        }
    }
}
