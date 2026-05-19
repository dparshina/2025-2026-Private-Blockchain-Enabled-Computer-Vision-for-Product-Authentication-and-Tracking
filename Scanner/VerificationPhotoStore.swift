import Foundation
import BigInt
import Web3

enum VerificationPhotoStore {
    static func upload(jpeg: Data, productId: BigUInt, manufacturerAddress: EthereumAddress) async throws -> Bool {
        guard let url = URL(string: "\(Config.backendURL)/decodeAndVerifyQR") else {
            throw NSError(domain: "VerificationPhotoStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad backend URL."])
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("productId", String(productId))
        appendField("manufacturerAddress", manufacturerAddress.hex(eip55: true))
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"qr.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
            throw NSError(domain: "VerificationPhotoStore", code: status,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        struct R: Decodable { let isValid: Bool }
        let decoded = try JSONDecoder().decode(R.self, from: data)
        return decoded.isValid
    }
}
