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
    @State private var account = Account.mock

    var body: some View {
        NavigationStack(path: $path) {
            AuthView(onAuthorized: {
                // TODO: логика: после успешной авторизации
                path = [.account]
            })
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .account:
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
    }
}

// MARK: - Модель (моки, позже заменим на данные с сервера)

struct Account {
    var fullName: String
    var tariffName: String
    var balance: Double
    var nextPaymentDate: Date
    var tvSubscription: String?
    var tariffPrice: Double
    var subscriptionPrice: Double

    var totalCost: Double { tariffPrice + subscriptionPrice }

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
