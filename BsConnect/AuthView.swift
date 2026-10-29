//
//  AuthView.swift
//  BsConnect
//
//  Created by Pavel Savvateev on 28.10.2026.
//


import SwiftUI

struct AuthView: View {
    enum Method: String, CaseIterable, Identifiable {
        case login = "Логин"
        case phone = "Телефон"
        var id: String { rawValue }
    }

    var onAuthorized: () -> Void = {}

    @State private var method: Method = .login
    @State private var login = ""
    @State private var password = ""
    @State private var phoneDigits = ""   // 10 цифр после +7, первая всегда 9
    @State private var smsCode = ""
    @State private var isSmsSent = false
    @State private var isLoading = false
    @State private var authError: AuthError?
    @State private var showAlert = false

    private let authService = AuthService()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("logo_w_text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220)
                        .accessibilityLabel("Логотип")

                    Text("Личный кабинет абонента")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.top, 40)

                Picker("Способ входа", selection: $method) {
                    ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 16) {
                    switch method {
                    case .login:
                        loginFields
                    case .phone:
                        phoneFields
                    }
                }

                PrimaryButton(title: isLoading ? "Загрузка..." : buttonTitle) {
                    handleSubmit()
                }
                .disabled(isLoading || !canSubmit)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            if authError == .invalidCredentials {
                // Неверные данные: повторять с теми же значениями нет смысла, даём исправить
                Button("OK", role: .cancel) { clearInvalidInput() }
            } else {
                Button("Повторить") { handleSubmit() }
            }
        } message: {
            if let message = alertMessage { Text(message) }
        }
        .onChange(of: phoneDigits) { value in
            let cleaned = Self.sanitizePhone(value)
            if cleaned != value { phoneDigits = cleaned }
        }
        .onChange(of: smsCode) { value in
            let formatted = Self.formatSmsCode(value)
            if formatted != value { smsCode = formatted }
        }
    }

    // MARK: Поля

    private var loginFields: some View {
        VStack(spacing: 16) {
            TextField("Логин", text: $login)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(AppTextFieldStyle())

            SecureField("Пароль", text: $password)
                .textFieldStyle(AppTextFieldStyle())
        }
    }

    private var phoneFields: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                // +7 всегда на месте, пользователь вводит только остальные цифры
                Text("+7")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appText)

                TextField("9XX XXX-XX-XX", text: $phoneDigits)
                    .keyboardType(.numberPad)
                    .disabled(isSmsSent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBlue.opacity(0.6), lineWidth: 1)
            )

            if isSmsSent {
                TextField("xx-xx-xx-xx", text: $smsCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(AppTextFieldStyle())

                Button("Отправить код повторно") {
                    requestCode()
                }
                .font(.footnote)
                .foregroundColor(.appBlueText)
                .disabled(isLoading)
            }
        }
    }

    // MARK: Состояние кнопки

    private var buttonTitle: String {
        switch method {
        case .login: return "Войти"
        case .phone: return isSmsSent ? "Подтвердить" : "Получить код"
        }
    }

    private var isPhoneValid: Bool {
        phoneDigits.count == 10 && phoneDigits.first == "9"
    }

    private var canSubmit: Bool {
        switch method {
        case .login:
            return true
        case .phone:
            return isSmsSent ? !smsCode.isEmpty : isPhoneValid
        }
    }

    // MARK: Действия

    private func handleSubmit() {
        switch method {
        case .login:
            loginWithPassword()
        case .phone:
            if isSmsSent { confirmCode() } else { requestCode() }
        }
    }

    private func loginWithPassword() {
        perform({ try await authService.login(login: login, password: password) }) {
            onAuthorized()
        }
    }

    /// Отправляем номер как 8XXXXXXXXXX: вместо +7 уходит цифра 8
    private func requestCode() {
        let phone = "8" + phoneDigits
        perform({ try await authService.requestPhoneCode(phone: phone) }) {
            isSmsSent = true
        }
    }

    private func confirmCode() {
        let code = smsCode   // уже в формате xx-xx-xx-xx
        perform({ try await authService.confirmPhoneCode(otp: code) }) {
            onAuthorized()
        }
    }

    /// Общий запуск запроса: индикатор загрузки и показ ошибок
    private func perform(_ action: @escaping () async throws -> Void,
                         onSuccess: @escaping () -> Void) {
        isLoading = true
        Task {
            do {
                try await action()
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    authError = (error as? AuthError) ?? .serviceUnavailable
                    showAlert = true
                }
            }
        }
    }

    private func clearInvalidInput() {
        switch method {
        case .login: password = ""
        case .phone: if isSmsSent { smsCode = "" }
        }
    }

    // MARK: Ошибки

    private var alertTitle: String {
        guard authError == .invalidCredentials else { return "Ошибка" }
        switch method {
        case .login: return "Неверный логин или пароль"
        case .phone: return isSmsSent ? "Код неверный" : "Неверный номер телефона"
        }
    }

    private var alertMessage: String? {
        switch authError {
        case .connection:
            return "Нет подключения к интернету или сервер недоступен. Проверьте соединение и повторите."
        case .serviceUnavailable:
            return "Сервис временно недоступен. Повторите попытку позже."
        case .invalidCredentials:
            return method == .phone && isSmsSent ? "Попробуйте еще" : nil
        case .none:
            return nil
        }
    }

    // MARK: Ввод номера

    /// Код из SMS: максимум 8 цифр в формате xx-xx-xx-xx
    static func formatSmsCode(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(8))
        var result = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { result.append("-") }
            result.append(ch)
        }
        return result
    }

    /// Оставляет только 10 цифр после +7, первая цифра всегда 9.
    /// Если вставили номер с кодом страны (7 или 8 в начале), код убираем.
    static func sanitizePhone(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if let first = digits.first, first == "7" || first == "8" {
            digits.removeFirst()
        }
        if let first = digits.first, first != "9" {
            return ""
        }
        return String(digits.prefix(10))
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBlue.opacity(0.6), lineWidth: 1)
            )
    }
}

#Preview("Light") {
    NavigationStack { AuthView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack { AuthView() }
        .preferredColorScheme(.dark)
}
