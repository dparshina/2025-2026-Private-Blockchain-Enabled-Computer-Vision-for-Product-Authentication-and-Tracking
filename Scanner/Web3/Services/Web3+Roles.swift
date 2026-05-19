import Foundation
import Web3

extension Connect {

    func checkManufacturer(manufacturer: EthereumAddress, employee: EthereumAddress) -> String {
        guard let call = callFun(input: "checkManufacturer", contract: contractPR)?(manufacturer, employee)
        else {
            return "unknown"
        }

        do {
            let result = try call.call().wait()

            return (result["_1"] as? String)
                ?? (result[""] as? String)
                ?? "unknown"
        } catch {
            print("Error (checkManufacturer): \(error)")
            return "unknown"
        }
    }

    func checkLogisticsProvider(logistics: EthereumAddress, employee: EthereumAddress) -> String {
        guard let call = callFun(input: "checkLogisticsProvider", contract: contractPR)?(logistics, employee)
        else {
            return "unknown"
        }

        do {
            let result = try call.call().wait()
            return (result["_1"] as? String)
                ?? (result[""] as? String)
                ?? "unknown"
        } catch {
            print("Error (checkLogistics): \(error)")
            return "unknown"
        }
    }

    func resolveRole(for address: String) async -> WalletRole {

        guard let addr = try? EthereumAddress(hex: address, eip55: false),
              let comp = try? EthereumAddress(hex: Config.companyAccountAddress, eip55: false),
              let log  = try? EthereumAddress(hex: Config.logisticsAccountAddress, eip55: false)
        else {
            return .recipient
        }

        return await Task.detached(priority: .userInitiated) { [self] in
            let manuResol = checkManufacturer(manufacturer: comp, employee: addr)
            let logResol = checkLogisticsProvider(logistics: log, employee: addr)
            if manuResol == "employee" {
                return .manufacturer_emp
            }
            else if manuResol == "cert_responsible" {
                return .manufacturer_cert_emp
            }
            else if manuResol == "admin" {
                return .manufacturer_admin
            }
            else if logResol == "admin" {
                return .logistics_admin
            }
            else if logResol == "employee" {
                return .logistics_emp
            }
            else {
                return .recipient
            }
        }.value
    }
}
