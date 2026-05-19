import Foundation
import Web3
import Web3ContractABI
import Web3PromiseKit
import BigInt

extension Connect {

    func getProductInfo(productID: BigUInt, manufacturerAccountAddress: EthereumAddress) -> [String: Any] {
        do {
            let calldata = ProductSel.productInfo + abiEncodeUInt(productID) + abiEncodeAddress(manufacturerAccountAddress)
            let bytes = try rawCall(data: calldata)
            let reader = ABIReader(bytes: bytes)

            let tupleStart = reader.offset(at: 0)
            return decodeProduct(reader: reader, tupleStart: tupleStart)
        } catch {
            print("Error (getProductInfo): \(error)")
            return [:]
        }
    }

    func getProductsByManufacturerPaginated(manufacturerAddress: EthereumAddress, offset: BigUInt, limit: BigUInt) -> ([[String: Any]], total: BigUInt) {
        return rawProductList(selector: ProductSel.manufacturerPaginated, address: manufacturerAddress, offset: offset, limit: limit, tag: "getProductsByManufacturerPaginated")
    }

    func getProductsByUserPaginated(userAddress: EthereumAddress, offset: BigUInt, limit: BigUInt) -> ([[String: Any]], total: BigUInt) {
        return rawProductList(selector: ProductSel.userPaginated, address: userAddress, offset: offset, limit: limit, tag: "getProductsByUserPaginated")
    }

    func getProductPublicKey(productId: BigUInt, manufacturerAddress: EthereumAddress) -> Data? {
        do {
            let result = try callFun(input: "getProductPublicKey", contract: contractPR)!(productId, manufacturerAddress).call().wait()
            let raw = result[""] ?? result["_0"]
            if let data = raw as? Data { return data.isEmpty ? nil : data }
            if let bytes = raw as? [UInt8] { return bytes.isEmpty ? nil : Data(bytes) }
            return nil
        } catch {
            print("Error (getProductPublicKey): \(error)")
            return nil
        }
    }

    func fetchPathHistory(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> [PathRecord] {
        guard let invocation = callFun(input: "getProductPathHistory", contract: contractPR)?(productId, manufacturerAddress) else {
            throw InvocationError.encodingError
        }
        return try await withCheckedThrowingContinuation { cont in
            invocation.call { response, error in
                if let error = error { cont.resume(throwing: error); return }
                let raw = (response?[""] ?? response?["_0"]) as? [[String: Any]] ?? []
                cont.resume(returning: raw.compactMap(PathRecord.init(tuple:)))
            }
        }
    }

    func fetchConditionLogs(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> [ConditionRecord] {
        guard let invocation = callFun(input: "getConditionLogs", contract: contractPR)?(productId, manufacturerAddress) else {
            throw InvocationError.encodingError
        }
        return try await withCheckedThrowingContinuation { cont in
            invocation.call { response, error in
                if let error = error { cont.resume(throwing: error); return }
                let raw = (response?[""] ?? response?["_0"]) as? [[String: Any]] ?? []
                cont.resume(returning: raw.compactMap(ConditionRecord.init(tuple:)))
            }
        }
    }

    private func rawCall(data: [UInt8]) throws -> [UInt8] {
        let call = EthereumCall(from: nil, to: contractAddress, gas: nil, gasPrice: nil, value: nil, data: EthereumData(data))
        let result = try web3.eth.call(call: call, block: .latest).wait()
        return result.bytes
    }

    private func rawProductList(selector: [UInt8], address: EthereumAddress, offset: BigUInt, limit: BigUInt, tag: String) -> ([[String: Any]], total: BigUInt) {
        do {
            let calldata = selector + abiEncodeAddress(address) + abiEncodeUInt(offset) + abiEncodeUInt(limit)
            let bytes = try rawCall(data: calldata)
            let reader = ABIReader(bytes: bytes)
            let arrStart = reader.offset(at: 0)
            let total = reader.uint(at: 32)
            let count = reader.offset(at: arrStart)
            let bodyStart = arrStart + 32
            var products: [[String: Any]] = []
            products.reserveCapacity(count)
            for i in 0..<count {
                let elemRel = reader.offset(at: bodyStart + i * 32)
                let tupleStart = bodyStart + elemRel
                products.append(decodeProduct(reader: reader, tupleStart: tupleStart))
            }
            return (products, total)
        } catch {
            print("Error (\(tag)): \(error)")
            return ([], 0)
        }
    }

    private func decodeProduct(reader: ABIReader, tupleStart: Int) -> [String: Any] {
        let id = reader.uint(at: tupleStart + 0 * 32)
        let nameOff = reader.offset(at: tupleStart + 1 * 32) + tupleStart
        let serialOff = reader.offset(at: tupleStart + 2 * 32) + tupleStart
        let manufacturer = reader.address(at: tupleStart + 3 * 32)
        let originOff = reader.offset(at: tupleStart + 4 * 32) + tupleStart
        let destOff = reader.offset(at: tupleStart + 5 * 32) + tupleStart
        let status = reader.uint(at: tupleStart + 6 * 32)
        let mass = reader.uint(at: tupleStart + 7 * 32)
        let certsOff = reader.offset(at: tupleStart + 8 * 32) + tupleStart
        let recipient = reader.address(at: tupleStart + 9 * 32)
        let pkOff = reader.offset(at: tupleStart + 10 * 32) + tupleStart
        let timestamp = reader.uint(at: tupleStart + 11 * 32)

        let publicKey = reader.bytes(at: pkOff)

        return [
            "id": id,
            "name": reader.string(at: nameOff),
            "serialNumber": reader.string(at: serialOff),
            "manufacturer": manufacturer,
            "origin": reader.string(at: originOff),
            "destination": reader.string(at: destOff),
            "status": UInt(status),
            "mass": Int(mass),
            "certificats": reader.stringArray(at: certsOff),
            "recipient": recipient,
            "publicKey": publicKey,
            "timestamp": TimeInterval(timestamp),
        ]
    }
}

private enum ProductSel {
    static let manufacturerPaginated: [UInt8] = [0x3d, 0x32, 0xb6, 0x19]
    static let userPaginated: [UInt8] = [0x0e, 0x01, 0x61, 0x3d]
    static let productInfo: [UInt8] = [0xf5, 0x92, 0x9a, 0x3d]
}

private func abiEncodeUInt(_ value: BigUInt) -> [UInt8] {
    let bytes = value.serialize()
    if bytes.count >= 32 {
        return Array(bytes.suffix(32))
    }
    return [UInt8](repeating: 0, count: 32 - bytes.count) + Array(bytes)
}

private func abiEncodeAddress(_ addr: EthereumAddress) -> [UInt8] {
    let raw = addr.rawAddress
    return [UInt8](repeating: 0, count: 12) + raw
}

private struct ABIReader {
    let bytes: [UInt8]

    func word(at i: Int) -> [UInt8] {
        Array(bytes[i..<(i + 32)])
    }

    func uint(at i: Int) -> BigUInt {
        BigUInt(Data(word(at: i)))
    }

    func offset(at i: Int) -> Int {
        Int(uint(at: i))
    }

    func address(at i: Int) -> String {
        let suffix = Array(bytes[(i + 12)..<(i + 32)])
        return "0x" + suffix.map { String(format: "%02x", $0) }.joined()
    }

    func string(at start: Int) -> String {
        let len = offset(at: start)
        if len == 0 {
            return ""
        }
        let payload = Array(bytes[(start + 32)..<(start + 32 + len)])
        return String(bytes: payload, encoding: .utf8) ?? ""
    }

    func bytes(at start: Int) -> Data {
        let len = offset(at: start)
        if len == 0 {
            return Data()
        }
        return Data(bytes[(start + 32)..<(start + 32 + len)])
    }

    func stringArray(at start: Int) -> [String] {
        let n = offset(at: start)
        if n == 0 {
            return []
        }
        let bodyStart = start + 32
        var out: [String] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let rel = offset(at: bodyStart + i * 32)
            out.append(string(at: bodyStart + rel))
        }
        return out
    }
}
