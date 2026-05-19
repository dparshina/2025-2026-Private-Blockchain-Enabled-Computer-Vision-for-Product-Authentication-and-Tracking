import Foundation

enum Web3Error: LocalizedError {
    case walletNotConnected
    case encodingFailed
    case invalidBackendResponse(endpoint: String, status: Int, body: String?)
    case backendError(detail: String)
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .walletNotConnected:
            return "Wallet not connected."
        case .encodingFailed:
            return "Failed to encode transaction."
        case .invalidBackendResponse(let endpoint, let status, let body):
            return "Invalid response from \(endpoint) (HTTP \(status))" + (body.map { ": \($0)" } ?? "")
        case .backendError(let detail):
            return detail
        case .notAuthorized:
            return "Only manufacturer or logistics admins can perform this action."
        }
    }
}
