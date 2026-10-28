//
//  AuthService.swift
//  BsConnect
//

import Foundation

// MARK: - Ошибки

enum AuthError: Error, Equatable {
    /// Нет интернета, API недоступен или ошибка сертификата (1 тип: показываем «Повторить»)
    case connection
    /// Сервис временно недоступен (код 2: показываем текст и «Повторить»)
    case serviceUnavailable
    /// Неверный логин или пароль (ответ сервера, не сетевая ошибка)
    case invalidCredentials
}

// MARK: - Модель ответа

private struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let code: Int
    let data: T?
    let message: String?
}

private struct TokenData: Decodable {
    let token: String
}

// MARK: - Хранилище токена (Keychain, шифруется системой)

enum TokenStore {
    private static let service = "ru.bsconnect.auth"
    private static let account = "bearer-token"

    static func save(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Сервис авторизации

final class AuthService {
    /// TODO: вынести в конфиг сборки (Debug/Release)
    static let baseURL = URL(string: "https://BASE_URL_HERE")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// POST /api/v1/cabinet/auth/login (form-data: login, password)
    func login(login: String, password: String) async throws {
        let url = Self.baseURL.appendingPathComponent("api/v1/cabinet/auth/login")
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(
            fields: ["login": login, "password": password],
            boundary: boundary
        )

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.serviceUnavailable }

        let decoded: APIResponse<TokenData>
        do {
            decoded = try JSONDecoder().decode(APIResponse<TokenData>.self, from: data)
        } catch {
            throw AuthError.serviceUnavailable
        }

        guard http.statusCode == 200, decoded.success, let token = decoded.data?.token else {
            // Ошибки из документации: -401 Unauthorized и т.п.
            if decoded.code == -401 { throw AuthError.invalidCredentials }
            throw AuthError.serviceUnavailable
        }

        TokenStore.save(token)
    }

    // MARK: Helpers

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .timedOut,
                 .dnsLookupFailed,
                 .secureConnectionFailed,
                 .serverCertificateUntrusted,
                 .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid,
                 .clientCertificateRejected,
                 .appTransportSecurityRequiresSecureConnection:
                throw AuthError.connection
            default:
                throw AuthError.serviceUnavailable
            }
        }
    }

    private static func formBody(fields: [String: String], boundary: String) -> Data {
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
