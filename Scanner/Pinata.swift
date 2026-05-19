import Foundation
import UniformTypeIdentifiers

enum Pinata {
    static let gateway = "https://gateway.pinata.cloud"

    struct UploadResponse: Decodable {
        let cid: String
        let url: String
    }

    struct IdByCidResponse: Decodable {
        let id: String
        let cid: String
        let name: String?
    }

    static func upload(fileURL: URL) async throws -> UploadResponse {
        let filename = fileURL.lastPathComponent
        let mime = mimeType(for: fileURL)
        let data = try Data(contentsOf: fileURL)
        return try await uploadData(data, filename: filename, mime: mime)
    }

    static func uploadData(_ data: Data, filename: String, mime: String) async throws -> UploadResponse {
        guard let url = URL(string: "\(Config.backendURL)/uploadCertificate")
        else {
            throw NSError(domain: "Pinata", code: 1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let msg = String(data: respData, encoding: .utf8) ?? "HTTP \(status)"
            throw NSError(domain: "Pinata", code: status, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(UploadResponse.self, from: respData)
    }

    static func unpin(cid: String) async throws {
        let fileId = try await fileId(forCID: cid)
        guard let url = URL(string: "\(Config.backendURL)/certificate/\(fileId)") else {
            throw NSError(domain: "Pinata", code: 1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 30
        let (_, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw NSError(domain: "Pinata", code: status)
        }
    }

    static func fileId(forCID cid: String) async throws -> String {
        guard let url = URL(string: "\(Config.backendURL)/certificate/id-by-cid/\(cid)") else {
            throw NSError(domain: "Pinata", code: 1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
            throw NSError(domain: "Pinata", code: status, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(IdByCidResponse.self, from: data).id
    }

    static func extractCID(from certificateURL: String) -> String {
        if certificateURL.hasPrefix("ipfs://") {
            return String(certificateURL.dropFirst("ipfs://".count))
        }
        if let range = certificateURL.range(of: "/ipfs/") {
            return String(certificateURL[range.upperBound...])
        }
        return certificateURL
    }

    static func gatewayURL(from certificateURL: String) -> URL? {
        let cid = extractCID(from: certificateURL)
        return URL(string: "\(Config.backendURL)/certificate/\(cid)")
    }

    private static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}

enum CertificateCache {
    private static let dir: URL = {
        let url = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("certificates", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func existingFile(cid: String) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
        for name in entries where name.hasPrefix(cid + ".") {
            return dir.appendingPathComponent(name)
        }
        return nil
    }

    static func file(forCertificate certificateURL: String) async throws -> URL {
        let cid = Pinata.extractCID(from: certificateURL)
        if let existing = existingFile(cid: cid) {
            return existing
        }

        guard let fetchURL = Pinata.gatewayURL(from: certificateURL)
        else {
            throw NSError(domain: "CertificateCache", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad URL"])
        }
        let (data, resp) = try await URLSession.shared.data(from: fetchURL)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw NSError(domain: "CertificateCache", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
        }
        let ext = inferExtension(response: resp, fallback: certificateURL)
        let dest = dir.appendingPathComponent("\(cid).\(ext)")
        try data.write(to: dest, options: .atomic)
        return dest
    }

    static func warm(cid: String, data: Data, filename: String) {
        if existingFile(cid: cid) != nil {
            return
        }
        let ext = (filename as NSString).pathExtension
        let safeExt = ext.isEmpty ? "bin" : ext
        let dest = dir.appendingPathComponent("\(cid).\(safeExt)")
        try? data.write(to: dest, options: .atomic)
    }

    static func evict(cid: String) {
        guard let url = existingFile(cid: cid) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func prefetch(certificateURLs: [String]) {
        let pending = certificateURLs.filter {
            existingFile(cid: Pinata.extractCID(from: $0)) == nil
        }
        guard !pending.isEmpty
        else {
            return
        }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) {
                group in
                for cert in pending {
                    group.addTask {
                        _ = try? await file(forCertificate: cert)
                    }
                }
            }
        }
    }

    static func inferExtension(response: URLResponse, fallback: String) -> String {
        if let mime = response.mimeType,
           let type = UTType(mimeType: mime),
           let ext = type.preferredFilenameExtension {
            return ext
        }
        let path = (fallback as NSString).pathExtension
        return path.isEmpty ? "pdf" : path
    }
}
