import Foundation
import Web3
import Web3ContractABI
import metamask_ios_sdk

extension Connect {

    func ensureConnectedWallet() async -> EthereumAddress? {
        if let acct = account { return acct }
        _ = await metamaskSDK.connect()
        return account
    }

    func switchToSepolia() async throws {
        let request = EthereumRequest(method: .switchEthereumChain, params: [["chainId": "0xaa36a7"]])
        let result = await metamaskSDK.request(request)
        print("switchToSepolia result: \(result)")
        try result.get()
    }

    func sign(userHash: String) async throws -> String {

        if metamaskSDK.account.isEmpty {
            print("[wallet] account empty before sign — reconnecting…")
            _ = await metamaskSDK.connect()
        }
        var address = metamaskSDK.account
        guard !address.isEmpty else {
            throw Web3Error.walletNotConnected
        }

        func makeRequest(_ addr: String) -> EthereumRequest<[String]> {
            EthereumRequest(method: .personalSign, params: [userHash, addr])
        }

        var result = await metamaskSDK.request(makeRequest(address))

        if case .failure(let err) = result {
            print("[wallet] sign failed (\(err)); attempting reconnect + retry")
            _ = await metamaskSDK.connect()
            address = metamaskSDK.account
            guard !address.isEmpty else { throw Web3Error.walletNotConnected }
            result = await metamaskSDK.request(makeRequest(address))
        }

        switch result {
        case let .success(signature):
            return signature as! String
        case let .failure(error):
            throw error
        }
    }

    func sendingTransaction(call: any SolidityInvocation) async throws -> String {
        if metamaskSDK.account.isEmpty {
            let connectResult = await metamaskSDK.connect()
            print("connect result: \(connectResult)")
        }

        try await switchToSepolia()

        guard let rawData = call.encodeABI()?.hex() else {
            throw InvocationError.encodingError
        }

        let tx = Transaction(to: contractAddressStr, from: metamaskSDK.account, value: "0x0", data: rawData)
        let request: EthereumRequest<[Transaction]> = .init(id: TimestampGenerator.timestamp(), method: .ethSendTransaction, params: [tx])

        let sdkResult = await metamaskSDK.request(request)
        let txHash = try sdkResult.get()
        return txHash
    }

    func sendingTransactionSA(call: any SolidityInvocation, money: String, contractAddress: String) async throws -> String {
        if metamaskSDK.account.isEmpty {
            _ = await metamaskSDK.connect()
        }
        try await switchToSepolia()

        guard !metamaskSDK.account.isEmpty else {
            throw InvocationError.encodingError
        }
        guard let rawData = call.encodeABI()?.hex() else {
            throw InvocationError.encodingError
        }

        let tx = Transaction(
            to: contractAddress,
            from: metamaskSDK.account,
            value: money,
            data: rawData
        )
        let request: EthereumRequest<[Transaction]> = .init(
            id: TimestampGenerator.timestamp(),
            method: .ethSendTransaction,
            params: [tx]
        )
        return try await metamaskSDK.request(request).get()
    }
}
