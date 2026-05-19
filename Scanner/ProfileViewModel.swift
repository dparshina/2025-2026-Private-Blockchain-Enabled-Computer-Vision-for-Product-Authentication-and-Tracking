import Foundation

@MainActor
final class ProfileViewModel {
    private(set) var role: WalletRole?
    private let web3: Web3Service

    var onChanged: (() -> Void)?

    init(web3: Web3Service = Connect.connection) {
        self.web3 = web3
    }

    var account: String {
        web3.account?.hex(eip55: false) ?? ""
    }

    func setRole(_ role: WalletRole?) {
        self.role = role
        onChanged?()
    }

    func load() async {
        let acc = account
        guard !acc.isEmpty
        else {
            return
        }
        let resolved = await web3.resolveRole(for: acc)
        self.role = resolved
        onChanged?()
    }
}
