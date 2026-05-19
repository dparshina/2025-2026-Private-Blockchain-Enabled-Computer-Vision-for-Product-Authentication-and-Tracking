import Foundation
import Web3
import Web3ContractABI
import BigInt

extension Connect {

    func resolveDepositAccount() throws -> (contract: DynamicContract, address: String) {
        guard let acct = account,
              let manuAddr = try? EthereumAddress(hex: Config.companyAccountAddress, eip55: true),
              let logAddr  = try? EthereumAddress(hex: Config.logisticsAccountAddress, eip55: true)
        else { throw Web3Error.notAuthorized }

        if checkManufacturer(manufacturer: manuAddr, employee: acct) == "admin" {
            return (contractCA, Config.companyAccountAddress)
        }
        if checkLogisticsProvider(logistics: logAddr, employee: acct) == "admin" {
            return (contractLogCA, Config.logisticsAccountAddress)
        }
        throw Web3Error.notAuthorized
    }

    func addDeposit(money: BigUInt) async throws -> String {
        let acct = try resolveDepositAccount()
        let valueHex = "0x" + String(money, radix: 16)
        guard let builder = callFun(input: "addDeposit", contract: acct.contract) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransactionSA(call: builder(), money: valueHex, contractAddress: acct.address)
    }

    func getDeposit() async throws -> BigUInt {
        let acct = try resolveDepositAccount()
        guard let call = callFun(input: "getDeposit", contract: acct.contract) else { return 0 }
        return try await withCheckedThrowingContinuation { cont in
            call().call { response, error in
                if let error = error {
                    cont.resume(throwing: error); return
                }
                let value = response?[""] as? BigUInt
                         ?? response?["_0"] as? BigUInt
                         ?? 0
                cont.resume(returning: value)
            }
        }
    }

    func withdrawDeposit(withdrawTo: String, money: BigUInt) async throws -> String {
        let acct = try resolveDepositAccount()
        let addr = try EthereumAddress(hex: withdrawTo, eip55: false)
        guard let call = callFun(input: "withdrawDepositTo", contract: acct.contract)?(addr, money) else {
            throw InvocationError.encodingError
        }
        return try await sendingTransactionSA(call: call, money: "0x0", contractAddress: acct.address)
    }
}
