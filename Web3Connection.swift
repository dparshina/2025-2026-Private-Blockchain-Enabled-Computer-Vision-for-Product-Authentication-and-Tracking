import Web3
import metamask_ios_sdk
import Foundation
import Web3ContractABI
import Web3PromiseKit
import BigInt

enum Config {
    static let apiKey: String = {
        let key = Bundle.main.object(forInfoDictionaryKey: "infuraAPIKey") as? String ?? ""
        print("infuraAPIKey = '\(key)'")
        return key
    }()
}


class Connect {
    static let connection = Connect()
    
    let metamaskSDK: MetaMaskSDK
    
    lazy var web3 = Web3(rpcURL: "https://sepolia.infura.io/v3/\(Config.apiKey)")
    
    let contractAddressStr: String
    let contractAddress: EthereumAddress
    var account: EthereumAddress? {
        guard !metamaskSDK.account.isEmpty,
              let addr = try? EthereumAddress(hex: metamaskSDK.account, eip55: true)
        else {
            return nil
        }
        return addr
    }


    let tag = EthereumQuantityTag(tagType: .latest)
    
    private init() {
        contractAddressStr = "0x1063e0243C496D5338Af0cee053094DDE24C5340"
        contractAddress = try! EthereumAddress(hex: contractAddressStr, eip55: true)
        metamaskSDK = MetaMaskSDK.shared(
            AppMetadata(name: "QR", url: "com.dasha.QRScanner"),
            transport: .deeplinking(dappScheme: "QR"),
            sdkOptions: SDKOptions(
                infuraAPIKey: Config.apiKey,
                readonlyRPCMap: ["0xaa36a7": "https://sepolia.infura.io/v3/\(Config.apiKey)"]))
    }
    
    let jsonString = """
        [{"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":true,"internalType":"address","name":"employee","type":"address"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"CertificateAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":true,"internalType":"address","name":"employee","type":"address"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"CertificateDeleted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":false,"internalType":"string","name":"conditionType","type":"string"},{"indexed":false,"internalType":"int256","name":"value","type":"int256"}],"name":"ConditionLogged","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":true,"internalType":"address","name":"employee","type":"address"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"ProductAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":true,"internalType":"address","name":"employee","type":"address"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"ProductDeleted","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":false,"internalType":"address","name":"from","type":"address"},{"indexed":false,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"string","name":"location","type":"string"}],"name":"ProductPath","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"uint256","name":"productId","type":"uint256"},{"indexed":true,"internalType":"address","name":"manf","type":"address"},{"indexed":false,"internalType":"address","name":"verifier","type":"address"},{"indexed":false,"internalType":"bool","name":"isValid","type":"bool"}],"name":"ProductVerified","type":"event"},{"inputs":[],"name":"PHYSICAL_NONCE","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"logisticsAddress","type":"address"}],"name":"addLogisticsProvider","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"addManufacturer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"employee","type":"address"},{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"string","name":"certificateURL","type":"string"}],"name":"addProductCertificate","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"employee","type":"address"},{"internalType":"string","name":"name","type":"string"},{"internalType":"string","name":"serialNumber","type":"string"},{"internalType":"string","name":"origin","type":"string"},{"internalType":"string","name":"destination","type":"string"},{"internalType":"uint256","name":"mass","type":"uint256"},{"internalType":"address","name":"recipient","type":"address"}],"name":"addProductInfo","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"changeStatus","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"logisticsAddress","type":"address"}],"name":"checkLogisticsProvider","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"checkManufacturer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"logisticsAddress","type":"address"}],"name":"deleteLogisticsProvider","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"deleteManufacturer","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"employee","type":"address"},{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"uint256","name":"index","type":"uint256"}],"name":"deleteProductCertificate","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"employee","type":"address"},{"internalType":"uint256","name":"productId","type":"uint256"}],"name":"deleteProductInfo","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"getConditionLogs","outputs":[{"components":[{"internalType":"string","name":"conditionType","type":"string"},{"internalType":"int256","name":"value","type":"int256"},{"internalType":"string","name":"unit","type":"string"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"internalType":"struct ProductRegistry.ConditionLog[]","name":"","type":"tuple[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"getProductInfo","outputs":[{"internalType":"string","name":"","type":"string"},{"internalType":"string","name":"","type":"string"},{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"string","name":"","type":"string"},{"internalType":"enum ProductRegistry.ProductStatus","name":"","type":"uint8"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"string[]","name":"","type":"string[]"},{"internalType":"address","name":"","type":"address"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"}],"name":"getProductPathHistory","outputs":[{"components":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"string","name":"location","type":"string"},{"internalType":"string","name":"note","type":"string"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"internalType":"struct ProductRegistry.PathRecord[]","name":"","type":"tuple[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"manA","type":"address"},{"internalType":"uint256","name":"offset","type":"uint256"},{"internalType":"uint256","name":"limit","type":"uint256"}],"name":"getProductsByManufacturerPaginated","outputs":[{"components":[{"internalType":"string","name":"name","type":"string"},{"internalType":"string","name":"serialNumber","type":"string"},{"internalType":"address","name":"manufacturer","type":"address"},{"internalType":"string","name":"origin","type":"string"},{"internalType":"string","name":"destination","type":"string"},{"internalType":"enum ProductRegistry.ProductStatus","name":"status","type":"uint8"},{"internalType":"uint256","name":"mass","type":"uint256"},{"internalType":"string[]","name":"certificats","type":"string[]"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"timestamp","type":"uint256"}],"internalType":"struct ProductRegistry.Product[]","name":"result","type":"tuple[]"},{"internalType":"uint256","name":"total","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"offset","type":"uint256"},{"internalType":"uint256","name":"limit","type":"uint256"}],"name":"getProductsByUserPaginated","outputs":[{"components":[{"internalType":"address","name":"manufacturer","type":"address"},{"internalType":"uint256","name":"productId","type":"uint256"}],"internalType":"struct ProductRegistry.ProductRef[]","name":"result","type":"tuple[]"},{"internalType":"uint256","name":"total","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"},{"internalType":"string","name":"conditionType","type":"string"},{"internalType":"int256","name":"value","type":"int256"},{"internalType":"string","name":"unit","type":"string"}],"name":"logCondition","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"string","name":"location","type":"string"},{"internalType":"string","name":"note","type":"string"}],"name":"logPathHistory","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"productId","type":"uint256"},{"internalType":"address","name":"manufacturerAddress","type":"address"},{"internalType":"bytes","name":"hiddenSignature","type":"bytes"}],"name":"verifyProduct","outputs":[],"stateMutability":"nonpayable","type":"function"}]
        """.data(using: .utf8)!

    lazy var contract: DynamicContract = {
        let contract = try! web3.eth.Contract(json: jsonString, abiKey: nil, address: contractAddress)
        return contract
    }()

    func callFun(input: String, contract: DynamicContract) -> ((ABIEncodable...) -> SolidityInvocation)? {
        return contract[input]
    }
    
    func switchToSepolia() async throws {
        let request = EthereumRequest(method: .switchEthereumChain, params: [["chainId": "0xaa36a7"]])
        let result = await metamaskSDK.request(request)
//        try result.get()
    }

    
    func sendingTransaction(call: any SolidityInvocation) async throws -> String{
        
        try await switchToSepolia()
        
        guard let rawData = call.encodeABI()?.hex() else {
            throw InvocationError.encodingError
        }
        
        let tx = Transaction(to: contractAddressStr, from: metamaskSDK.account, value: "0x0", data: rawData)

        let request: EthereumRequest<[Transaction]> = .init(id: TimestampGenerator.timestamp(), method: .ethSendTransaction, params: [tx])

        let sdkResult = await metamaskSDK.request(request)
        let txHash    = try sdkResult.get()
        return txHash
    }
    
    
    func checkManufacturer(_ address: EthereumAddress) -> Bool {
        guard let invocation = callFun(input: "checkManufacturer", contract: contract)?(address) else {
            return false
        }
        
        do {
            let result = try invocation.call().wait()
            return (result[""] as? Bool) ?? (result["0"] as? Bool) ?? false
        } catch {
            print("Error (checkManufacturer): \(error)")
            return false
        }
    }

    func checkLogisticsProvider(_ address: EthereumAddress) -> Bool {
        guard let invocation = callFun(input: "checkLogisticsProvider", contract: contract)?(address) else {
            return false
        }
        
        do {
            let result = try invocation.call().wait()
            return (result[""] as? Bool) ?? (result["0"] as? Bool) ?? false
        } catch {
            print("Error (checkLogistics): \(error)")
            return false
        }
    }
    
    
    func resolveRole(for address: String) async -> WalletRole {
        guard let addr = try? EthereumAddress(hex: address, eip55: true)
        else {
            return .recipient
        }
        if checkManufacturer(addr) {
            return .manufacturer
        }
        if checkLogisticsProvider(addr) {
            return .logistics
        }
        return .recipient
    }
    
    func addProductInfo(employee: EthereumAddress, name: String, serialNumber: String, origin: String, destination: String, mass: BigUInt, recipient: EthereumAddress) async throws -> String {
            let call = callFun(input: "addProductInfo", contract: contract)!(employee, name, serialNumber, origin, destination, mass, recipient)
            return try await sendingTransaction(call: call)
        }

    func deleteProductInfo(employee: EthereumAddress, productId: BigUInt) async throws -> String {
        let call = callFun(input: "deleteProductInfo", contract: contract)!(employee, productId)
        return try await sendingTransaction(call: call)
    }
    
    func addProductCertificate(employee: EthereumAddress, productId: BigUInt, certificateURL: String) async throws -> String {
            let call = callFun(input: "addProductCertificate", contract: contract)!(employee, productId, certificateURL)
            return try await sendingTransaction(call: call)
    }

    func deleteProductCertificate(employee: EthereumAddress, productId: BigUInt, index: BigUInt) async throws -> String {
        let call = callFun(input: "deleteProductCertificate", contract: contract)!(employee, productId, index)
        return try await sendingTransaction(call: call)
    }
    
    func getProductsByManufacturerPaginated(manufacturerAddress: EthereumAddress, offset: BigUInt, limit: BigUInt) -> ([[String: Any]], total: BigUInt) {
        do {
            let result = try callFun(input: "getProductsByManufacturerPaginated", contract: contract)!(manufacturerAddress, offset, limit).call().wait()
            let products = (result["result"] as? [[String: Any]]) ?? []
            let total = (result["total"]  as? BigUInt) ?? 0
                return (products, total)
        }
        catch {
            print("Error (getProductsByManufacturerPaginated): \(error)")
            return ([], 0)
        }
    }
    


}

struct Product_: Decodable{
    var name: String
    var serialNumber: String
    var manufacturer: BigUInt
    var origin: String
    var destination: String
    var mass: BigUInt
    var certificats: [String]
    var timestamp: BigUInt
}



struct Transaction: metamask_ios_sdk.CodableData {
    let to: String
    let from: String
    let value: String
    let data: String?

    init(to: String, from: String, value: String, data: String? = nil) {
        self.to = to
        self.from = from
        self.value = value
        self.data = data
    }
}

