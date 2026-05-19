import Foundation
import UIKit
import Web3
import BigInt

extension Connect {

    func generateProductQR(productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> (qrImage: UIImage, publicKey: String) {
        let prepareBody: [String: Any] = [
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true)
        ]
        let prepareURL = URL(string: "\(Config.backendURL)/prepareQRMessage")!
        var prepareReq = URLRequest(url: prepareURL)
        prepareReq.httpMethod = "POST"
        prepareReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prepareReq.httpBody = try JSONSerialization.data(withJSONObject: prepareBody)
        let (prepareData, prepareResp) = try await URLSession.shared.data(for: prepareReq)
        let prepareStatus = (prepareResp as? HTTPURLResponse)?.statusCode ?? -1
        guard let prepareJson = try JSONSerialization.jsonObject(with: prepareData) as? [String: Any],
              let messageHash = prepareJson["messageHash"] as? String else {
            let detail = (try? JSONSerialization.jsonObject(with: prepareData) as? [String: Any])?["detail"] as? String
            if let detail = detail {
                throw Web3Error.backendError(detail: detail)
            }
            throw Web3Error.invalidBackendResponse(
                endpoint: "/prepareQRMessage",
                status: prepareStatus,
                body: String(data: prepareData, encoding: .utf8)
            )
        }

        let signature = try await sign(userHash: messageHash)

        let genBody: [String: Any] = [
            "productId": Int(productId),
            "manufacturerAddress": manufacturerAddress.hex(eip55: true),
            "signature": signature
        ]
        let genURL = URL(string: "\(Config.backendURL)/generateQR")!
        var genReq = URLRequest(url: genURL)
        genReq.httpMethod = "POST"
        genReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        genReq.httpBody = try JSONSerialization.data(withJSONObject: genBody)
        let (genData, genResp) = try await URLSession.shared.data(for: genReq)
        let genStatus = (genResp as? HTTPURLResponse)?.statusCode ?? -1
        guard let genJson = try JSONSerialization.jsonObject(with: genData) as? [String: Any],
              let b64 = genJson["qr_image_base64"] as? String,
              let pubKey = genJson["publicKeyCompressed"] as? String,
              let imgData = Data(base64Encoded: b64),
              let image = UIImage(data: imgData) else {
            let detail = (try? JSONSerialization.jsonObject(with: genData) as? [String: Any])?["detail"] as? String
            if let detail = detail {
                throw Web3Error.backendError(detail: detail)
            }
            throw Web3Error.invalidBackendResponse(
                endpoint: "/generateQR",
                status: genStatus,
                body: String(data: genData, encoding: .utf8)
            )
        }
        return (image, pubKey)
    }
}
