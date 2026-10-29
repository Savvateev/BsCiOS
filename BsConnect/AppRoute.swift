//
//  AppRoute.swift
//  BsConnect
//
//  Created by Pavel Savvateev on 28.10.2026.
//


import SwiftUI

enum AppRoute: Hashable {
    case account
    case promisedPayment
}

struct AppRoot: View {
    @State private var path: [AppRoute] = []
    @State private var account = Account.empty   // пустые данные, не моки: до загрузки ничего фейкового не покажется
    @State private var loadError: AuthError?
    private let authService = AuthService()

    var body: some View {
        NavigationStack(path: $path) {
            AuthView(onAuthorized: {
                loadUser()
            })
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .account:
                    let _ = debugLog("AccountView получил fio=\(account.fullName), total=\(account.totalCost)")
                    AccountView(
                        account: account,
                        onPromisedPayment: { path.append(.promisedPayment) }
                    )
                case .promisedPayment:
                    PromisedPaymentView(amount: account.totalCost)
                }
            }
        }
        .tint(.appBlue)
        .alert("Ошибка", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
            Button("Повторить") { loadUser() }
        } message: {
            Text("Сервис временно недоступен. Повторите попытку позже.")
        }
    }

    /// После входа загружаем данные абонента и открываем экран абонента
    private func loadUser() {
        Task {
            do {
                let user = try await authService.fetchUser()
                await MainActor.run {
                    account = Account(user: user)
                    #if DEBUG
                    print("[Account] fio=\(account.fullName) tariff=\(account.tariffName) balance=\(account.balance) total=\(account.totalCost) tv=\(account.tvSubscription ?? "-")")
                    #endif
                    path = [.account]
                }
            } catch {
                await MainActor.run {
                    loadError = (error as? AuthError) ?? .serviceUnavailable
                }
            }
        }
    }
}

// MARK: - Модель (моки, позже заменим на данные с сервера)

struct Account {
    var fullName: String
    var tariffName: String
    var balance: Double
    var nextPaymentDate: Date?
    var tvSubscription: String?
    var tariffPrice: Double
    var subscriptionPrice: Double
    /// Итог из API (fee.total). Если не задан, считаем сумму тарифа и подписки.
    var serverTotal: Double?

    var totalCost: Double { serverTotal ?? (tariffPrice + subscriptionPrice) }

    /// Перевод ответа API в модель экрана. Суммы приходят строками.
    init(user: CabinetUser) {
        fullName = user.fio
        tariffName = user.packet
        balance = Double(user.deposit) ?? 0
        nextPaymentDate = Self.parseDate(user.nextPaymentDate)
        tvSubscription = user.tvSubscriptionName
        tariffPrice = Double(user.tariffPrice) ?? 0
        subscriptionPrice = Double(user.subscriptionPrice) ?? 0
        serverTotal = Double(user.total)
    }

    init(fullName: String, tariffName: String, balance: Double, nextPaymentDate: Date?,
         tvSubscription: String?, tariffPrice: Double, subscriptionPrice: Double) {
        self.fullName = fullName
        self.tariffName = tariffName
        self.balance = balance
        self.nextPaymentDate = nextPaymentDate
        self.tvSubscription = tvSubscription
        self.tariffPrice = tariffPrice
        self.subscriptionPrice = subscriptionPrice
    }

    private static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd-MM-yyyy"
        return f.date(from: text)
    }

    static let empty = Account(
        fullName: "", tariffName: "", balance: 0, nextPaymentDate: nil,
        tvSubscription: nil, tariffPrice: 0, subscriptionPrice: 0
    )

    /// Только для превью в Canvas, в приложении не используется
    static let mock = Account(
        fullName: "Иванов Иван Иванович",
        tariffName: "Безлимит 500",
        balance: 350.0,
        nextPaymentDate: Calendar.current.date(byAdding: .day, value: 12, to: .now) ?? .now,
        tvSubscription: "ТВ Премиум",
        tariffPrice: 590.0,
        subscriptionPrice: 199.0
    )
}

/// Печатает только в DEBUG-сборке
@discardableResult
func debugLog(_ message: @autoclosure () -> String) -> Bool {
    #if DEBUG
    print("[App] \(message())")
    #endif
    return true
}
