import Foundation
import Web3
import Web3ContractABI

extension Connect {

    func addManufacturer(manufacturerAddress: EthereumAddress) async throws -> String {
        guard let call = callFun(input: "addManufacturer", contract: contractPR)?(manufacturerAddress) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransaction(call: call)
    }

    func deleteManufacturer(manufacturerAddress: EthereumAddress) async throws -> String {
        guard let call = callFun(input: "deleteManufacturer", contract: contractPR)?(manufacturerAddress) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransaction(call: call)
    }

    func addLogisticsProvider(logisticsAddress: EthereumAddress) async throws -> String {
        guard let call = callFun(input: "addLogisticsProvider", contract: contractPR)?(logisticsAddress) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransaction(call: call)
    }

    func deleteLogisticsProvider(logisticsAddress: EthereumAddress) async throws -> String {
        guard let call = callFun(input: "deleteLogisticsProvider", contract: contractPR)?(logisticsAddress) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransaction(call: call)
    }
}
