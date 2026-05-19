import Web3
import metamask_ios_sdk
import Foundation
import UIKit
import Web3ContractABI
import Web3PromiseKit
import BigInt

enum Config {
    static let apiKey: String = {
        let key = Bundle.main.object(forInfoDictionaryKey: "infuraAPIKey") as? String ?? ""
        print("infuraAPIKey = '\(key)'")
        return key
    }()

    static let backendURL = "http://192.168.0.115:8000"
    static let companyAccountAddress = "0x654143739Ea02B50600a961d1bC8AdC4382ea13c"
    static let logisticsAccountAddress = "0xAA30fC6f75Bb7a1fb8196546afaa3Aab7341d69a"

    static let logisticsAccountABI: Data = ABILoader.load("LogisticsAccount")
    static let companyAccountABI: Data = ABILoader.load("CompanyAccount")
}

class Connect {
    static let connection = Connect()

    let metamaskSDK: MetaMaskSDK

    lazy var web3 = Web3(rpcURL: "https://sepolia.infura.io/v3/\(Config.apiKey)")

    let contractAddressStr: String
    let contractAddress: EthereumAddress

    var account: EthereumAddress? {
        guard !metamaskSDK.account.isEmpty,
              let addr = try? EthereumAddress(hex: metamaskSDK.account, eip55: false)
        else {
            return nil
        }
        return addr
    }

    let tag = EthereumQuantityTag(tagType: .latest)

    private init() {
        contractAddressStr = "0xBE71fc0878d6085331B5023ecb7213957c70e8DA"
        contractAddress = try! EthereumAddress(hex: contractAddressStr, eip55: true)
        metamaskSDK = MetaMaskSDK.shared(
            AppMetadata(name: "QR", url: "com.dasha.QRScanner"),
            transport: .deeplinking(dappScheme: "QR"),
            sdkOptions: SDKOptions(
                infuraAPIKey: Config.apiKey,
                readonlyRPCMap: ["0xaa36a7": "https://sepolia.infura.io/v3/\(Config.apiKey)"]))
    }

    let jsonString: Data = ABILoader.load("ProductRegistry")

    lazy var contractPR: DynamicContract = {
        try! web3.eth.Contract(json: jsonString, abiKey: nil, address: contractAddress)
    }()

    lazy var contractCA: DynamicContract = makeCompanyAccountContract(
        at: Config.companyAccountAddress, abi: Config.companyAccountABI)
    lazy var contractLogCA: DynamicContract = makeCompanyAccountContract(
        at: Config.logisticsAccountAddress, abi: Config.logisticsAccountABI)

    private func makeCompanyAccountContract(at address: String, abi: Data) -> DynamicContract {
        let addr = try! EthereumAddress(hex: address, eip55: true)
        let raw = try! JSONSerialization.jsonObject(with: abi) as! [[String: Any]]
        let filtered = raw.filter {
            let t = $0["type"] as? String
            return t != "error" && t != "receive"
        }
        let cleaned = try! JSONSerialization.data(withJSONObject: filtered)
        return try! web3.eth.Contract(json: cleaned, abiKey: nil, address: addr)
    }

    func callFun(input: String, contract: DynamicContract) -> ((ABIEncodable...) -> SolidityInvocation)? {
        return contract[input]
    }

    func warmUp() {
        _ = contractPR
        _ = contractCA
        _ = contractLogCA
    }
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
