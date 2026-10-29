//
//  AuthService.swift
//  BsConnect
//

import Foundation

// MARK: - Ошибки

enum AuthError: Error, Equatable {
    /// Нет интернета, API недоступен или ошибка сертификата (показываем «Повторить»)
    case connection
    /// Сервис временно недоступен (показываем текст и «Повторить»)
    case serviceUnavailable
    /// Неверные данные: логин/пароль, номер или код из SMS (код -401)
    case invalidCredentials
}

// MARK: - Статус ответа (поле data разбираем отдельно, его формат меняется)

private struct APIStatus: Decodable {
    let success: Bool
    let code: Int
    let message: String?
}

// MARK: - Хранилище токена (Keychain, шифруется системой)

enum TokenStore {
    private static let service = "ru.bsconnect.auth"
    private static let account = "bearer-token"

    /// Токен сохраняем как пришёл с сервера (он уже содержит префикс "Bearer ")
    static func save(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(token.utf8)
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
    static let baseURL = URL(string: "https://api.bsvyazi.ru/api/v1")!
    static let userAgent = "MikbillApiAgent/1.0"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Вход по логину и паролю: POST cabinet/auth/login
    func login(login: String, password: String) async throws {
        let json = try await send(path: "cabinet/auth/login",
                                  fields: ["login": login, "password": password])
        try saveToken(from: json)
    }

    /// Шаг 1, телефон: POST cabinet/auth/phone
    /// Номер уходит в формате 8XXXXXXXXXX (вместо +7 отправляем 8)
    func requestPhoneCode(phone: String) async throws {
        _ = try await send(path: "cabinet/auth/phone", fields: ["phone": phone])
    }

    /// Шаг 2, код из SMS: POST cabinet/auth/phone/otp, в ответ приходит токен
    func confirmPhoneCode(otp: String) async throws {
        let json = try await send(path: "cabinet/auth/phone/otp", fields: ["otp": otp])
        try saveToken(from: json)
    }

    /// Данные абонента: GET cabinet/user, токен в заголовке Authorization
    func fetchUser() async throws -> CabinetUser {
        guard let token = TokenStore.load() else { throw AuthError.invalidCredentials }

        var request = makeRequest(path: "cabinet/user", method: "GET")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.serviceUnavailable
        }
        guard let envelope = try? JSONDecoder().decode(UserEnvelope.self, from: data),
              envelope.success else {
            throw AuthError.serviceUnavailable
        }
        return envelope.data
    }

    // MARK: Helpers

    private func saveToken(from json: [String: Any]) throws {
        guard let data = json["data"] as? [String: Any],
              let token = data["token"] as? String else {
            throw AuthError.serviceUnavailable
        }
        TokenStore.save(token)
    }

    /// Отправляет form-data запрос и проверяет ответ. Возвращает полный JSON ответа.
    private func send(path: String, fields: [String: String]) async throws -> [String: Any] {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = makeRequest(path: path, method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(fields: fields, boundary: boundary)

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.serviceUnavailable }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let status = try? JSONDecoder().decode(APIStatus.self, from: data) else {
            throw AuthError.serviceUnavailable
        }

        guard http.statusCode == 200, status.success else {
            if status.code == -401 { throw AuthError.invalidCredentials }
            throw AuthError.serviceUnavailable
        }
        return json
    }

    /// Общий конструктор запросов: базовый URL и обязательный User-Agent
    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

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

// MARK: - Модель абонента (cabinet/user)

private struct UserEnvelope: Decodable {
    let success: Bool
    let code: Int
    let data: CabinetUser
}

/// Поля, которые нужны экранам. Остальные поля ответа игнорируются.
struct CabinetUser: Decodable {
    let fio: String
    let packet: String              // тарифный план, например "Unlim-130"
    let deposit: String             // текущий баланс
    let nextPaymentDate: String     // дата следующего платежа (поле уточнить)
    let tvSubscriptionName: String? // доп. подписка ТВ (из fee.subscriptions.detailed)
    let tariffPrice: String         // стоимость тарифа (fee.packet.price)
    let subscriptionPrice: String   // стоимость подписки (fee.subscriptions.total)
    let total: String               // итоговая стоимость (fee.total)

    private enum CodingKeys: String, CodingKey {
        case fio, packet, deposit, fee
        case nextPaymentDate = "erec_payment"
    }

    private struct Fee: Decodable {
        let packet: Price
        let subscriptions: Subscriptions
        let total: String

        struct Price: Decodable { let price: String }
        struct Subscriptions: Decodable {
            let total: String
            let detailed: [Item]
            struct Item: Decodable { let name: String }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fio = try c.decode(String.self, forKey: .fio)
        packet = try c.decode(String.self, forKey: .packet)
        deposit = try c.decode(String.self, forKey: .deposit)
        nextPaymentDate = try c.decode(String.self, forKey: .nextPaymentDate)
        let fee = try c.decode(Fee.self, forKey: .fee)
        tariffPrice = fee.packet.price
        subscriptionPrice = fee.subscriptions.total
        total = fee.total
        tvSubscriptionName = fee.subscriptions.detailed.first?.name
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
