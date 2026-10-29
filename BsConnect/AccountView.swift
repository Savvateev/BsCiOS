//
//  AccountView.swift
//  BsConnect
//
//  Created by Pavel Savvateev on 28.10.2026.
//


import SwiftUI

struct AccountView: View {
    let account: Account
    var onPay: () -> Void = {}
    var onPromisedPayment: () -> Void = {}
    /// Доступность обещанного платежа из cabinet/user/services/credit
    var canUsePromisedPayment: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LogoView(size: 72)
                    .padding(.top, 8)

                infoCard

                totalCard

                VStack(spacing: 12) {
                    PrimaryButton(title: "Оплатить") {
                        onPay() // TODO: логика оплаты
                    }
                    SecondaryButton(title: "Обещанный платеж") {
                        onPromisedPayment()
                    }
                    .disabled(!canUsePromisedPayment)
                    .opacity(canUsePromisedPayment ? 1 : 0.4)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Абонент")
        .navigationBarTitleDisplayMode(.inline)
        .backArrow()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("ФИО абонента", account.fullName)
            row("Тарифный план", account.tariffName)
            row("Текущий баланс", account.balance.rubles,
                valueColor: account.balance < 0 ? .appAlert : .appText)
            row("Дата следующего платежа",
                account.nextPaymentDate.map { $0.formatted(date: .long, time: .omitted) } ?? "—")
            row("Доп. подписка ТВ", account.tvSubscription ?? "Не подключена")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appBlue.opacity(0.08))
        )
    }

    private var totalCard: some View {
        VStack(spacing: 14) {
            row("Стоимость тарифа", account.tariffPrice.rubles)
            row("Стоимость подписки", account.subscriptionPrice.rubles)
            Divider()
            HStack {
                Text("Итоговая стоимость")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Text(account.totalCost.rubles)
                    .font(.title3.bold())
                    .foregroundColor(.appBlueText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appOrange, lineWidth: 2)
        )
    }

    private func row(_ title: String, _ value: String, valueColor: Color = .appText) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview("Light") {
    NavigationStack {
        AccountView(account: .mock)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        AccountView(account: .mock)
    }
    .preferredColorScheme(.dark)
}
