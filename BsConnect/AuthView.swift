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
    @State private var phone = ""
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

                PrimaryButton(title: isLoading ? "Вход..." : buttonTitle) {
                    handleSubmit()
                }
                .disabled(isLoading)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("Повторить") { handleSubmit() }
        } message: {
            if let message = alertMessage { Text(message) }
        }
    }

    // MARK: Ошибки

    private var alertTitle: String {
        authError == .invalidCredentials ? "Неверный логин или пароль" : "Ошибка"
    }

    private var alertMessage: String? {
        switch authError {
        case .connection:
            return "Нет подключения к интернету или сервер недоступен. Проверьте соединение и повторите."
        case .serviceUnavailable:
            return "Сервис временно недоступен. Повторите попытку позже."
        case .invalidCredentials, .none:
            return nil
        }
    }

    // MARK: Вход

    private func loginWithPassword() {
        isLoading = true
        Task {
            do {
                try await authService.login(login: login, password: password)
                await MainActor.run {
                    isLoading = false
                    onAuthorized()
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

    // MARK: Subviews

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
            TextField("+7 (___) ___-__-__", text: $phone)
                .keyboardType(.phonePad)
                .textFieldStyle(AppTextFieldStyle())
                .disabled(isSmsSent)

            if isSmsSent {
                TextField("Код из SMS", text: $smsCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(AppTextFieldStyle())

                Button("Отправить код повторно") {
                    // TODO: логика повторной отправки SMS
                }
                .font(.footnote)
                .foregroundColor(.appBlue)
            }
        }
    }

    private var buttonTitle: String {
        switch method {
        case .login: return "Войти"
        case .phone: return isSmsSent ? "Подтвердить" : "Получить код"
        }
    }

    private func handleSubmit() {
        switch method {
        case .login:
            loginWithPassword()
        case .phone:
            if isSmsSent { onAuthorized() } else { isSmsSent = true }
        }
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

#Preview {
    NavigationStack { AuthView() }
}
