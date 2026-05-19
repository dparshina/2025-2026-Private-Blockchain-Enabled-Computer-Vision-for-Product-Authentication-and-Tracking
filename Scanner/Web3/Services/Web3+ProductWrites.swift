import Foundation
import Web3ContractABI
import Web3
import BigInt

extension Connect {

    func sendAAUserOp(endpoint: String, requestBody: [String: Any]) async throws -> String {
        let estGasURL = URL(string: "\(Config.backendURL)\(endpoint)")!
        var estGasRequest = URLRequest(url: estGasURL)
        estGasRequest.httpMethod = "POST"
        estGasRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        estGasRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        let (estGasData, estGasResp) = try await URLSession.shared.data(for: estGasRequest)

        let statusCode = (estGasResp as? HTTPURLResponse)?.statusCode ?? -1
        let bodyString = String(data: estGasData, encoding: .utf8) ?? "<non-utf8>"
        print("estGas \(endpoint) → HTTP \(statusCode): \(bodyString)")

        guard let estGasResponse = try JSONSerialization.jsonObject(with: estGasData, options: []) as? [String: Any],
              var op = estGasResponse["op"] as? [String: Any],
              let userHash = estGasResponse["userHash"] as? String else {
            let detail = (try? JSONSerialization.jsonObject(with: estGasData) as? [String: Any])?["detail"] as? String
            if let detail = detail {
                throw Web3Error.backendError(detail: detail)
            }
            throw Web3Error.invalidBackendResponse(endpoint: endpoint, status: statusCode, body: bodyString)
        }

        let signature = try await sign(userHash: userHash)
        op["signature"] = signature

        let sendOpURL = URL(string: "\(Config.backendURL)/sendUserOp")!
        var sendOpRequest = URLRequest(url: sendOpURL)
        sendOpRequest.httpMethod = "POST"
        sendOpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let sendOpBody: [String: Any] = ["op": op]
        sendOpRequest.httpBody = try JSONSerialization.data(withJSONObject: sendOpBody, options: [])

        let (sendOpData, sendOpResp) = try await URLSession.shared.data(for: sendOpRequest)
        let sendOpStatus = (sendOpResp as? HTTPURLResponse)?.statusCode ?? -1
        let sendOpBodyStr = String(data: sendOpData, encoding: .utf8) ?? "<non-utf8>"

        guard let sendOpResponse = try JSONSerialization.jsonObject(with: sendOpData, options: []) as? [String: Any],
              let opHash = sendOpResponse["opHash"] as? String else {

            if let errorResponse = try? JSONSerialization.jsonObject(with: sendOpData) as? [String: Any],
               let detail = errorResponse["detail"] as? String {
                throw Web3Error.backendError(detail: detail)
            }
            throw Web3Error.invalidBackendResponse(endpoint: "/sendUserOp", status: sendOpStatus, body: sendOpBodyStr)
        }

        return opHash
    }

    func addProductInfo(companyAccount: String, employee: EthereumAddress, name: String, serialNumber: String, origin: String, destination: String, mass: BigUInt, recipient: EthereumAddress) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "name": name,
            "serialNumber": serialNumber,
            "origin": origin,
            "destination": destination,
            "mass": Int(mass),
            "recipient": recipient.hex(eip55: true)
        ]
        return try await sendAAUserOp(endpoint: "/addProductInfo/estGas", requestBody: requestBody)
    }

    func deleteProductInfo(companyAccount: String, employee: EthereumAddress, productId: BigUInt) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId)
        ]
        return try await sendAAUserOp(endpoint: "/deleteProductInfo/estGas", requestBody: requestBody)
    }

    func addProductPublicKey(companyAccount: String, employee: EthereumAddress, productId: BigUInt, publicKeyCompressed: String) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "publicKeyCompressed": publicKeyCompressed
        ]
        return try await sendAAUserOp(endpoint: "/addProductPublicKey/estGas", requestBody: requestBody)
    }

    func addProductCertificate(companyAccount: String, employee: EthereumAddress, productId: BigUInt, certificateURL: String) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "certificateURL": certificateURL
        ]
        print("sending user op")
        return try await sendAAUserOp(endpoint: "/addProductCertificate/estGas", requestBody: requestBody)
    }

    func deleteProductCertificate(companyAccount: String, employee: EthereumAddress, productId: BigUInt, index: BigUInt) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "index": Int(index)
        ]
        return try await sendAAUserOp(endpoint: "/deleteProductCertificate/estGas", requestBody: requestBody)
    }

    func changeStatus(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true)
        ]
        return try await sendAAUserOp(endpoint: "/changeStatus/estGas", requestBody: requestBody)
    }

    func logPathHistory(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, to: EthereumAddress, location: String, note: String) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true),
            "to": to.hex(eip55: true),
            "location": location,
            "note": note
        ]
        return try await sendAAUserOp(endpoint: "/logPathHistory/estGas", requestBody: requestBody)
    }

    func logCondition(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, conditionType: String, value: Int, unit: String) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true),
            "conditionType": conditionType,
            "value": value,
            "unit": unit
        ]
        return try await sendAAUserOp(endpoint: "/logCondition/estGas", requestBody: requestBody)
    }

    func verifyProductEvent(companyAccount: String, employee: EthereumAddress, productId: BigUInt, manufacturerAddress: EthereumAddress, isValid: Bool) async throws -> String {
        let requestBody: [String: Any] = [
            "companyAccount": companyAccount,
            "employee": employee.hex(eip55: true),
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true),
            "isValid": isValid
        ]
        return try await sendAAUserOp(endpoint: "/verifyProductEvent/estGas", requestBody: requestBody)
    }

    func confirmReceipt(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> String {
        guard let call = callFun(input: "changeStatus", contract: contractPR)?(productId, manufacturerAddress)
        else { throw InvocationError.encodingError }
        return try await sendingTransaction(call: call)
    }
}
