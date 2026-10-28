//
//  PromisedPaymentView.swift
//  BsConnect
//
//  Created by Pavel Savvateev on 28.10.2026.
//


import SwiftUI

struct PromisedPaymentView: View {
    let amount: Double
    var onConnect: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LogoView(size: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Обещанный платеж")
                    .font(.title2.bold())
                    .foregroundColor(.appBlueText)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Заказом услуги ОБЕЩАННЫЙ ПЛАТЕЖ вы подтверждаете ваше согласие оплатить в полном объеме абонплату за текущий месяц в размере ")
                        .foregroundColor(.appText)
                    + Text(amount.rubles)
                        .bold()
                        .foregroundColor(.appText)
                }
                .font(.body)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appOrange.opacity(0.15))
                )

                Text("Услуга предоставляется на срок не более 3х дней и доступна 1 раз в течение 1 календарного месяца.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appAlert)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appAlert, lineWidth: 1.5)
                    )

                PrimaryButton(title: "Подключить услугу", color: .appBlue) {
                    onConnect() // TODO: логика подключения обещанного платежа
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .backArrow()
    }
}

#Preview("Light") {
    NavigationStack {
        PromisedPaymentView(amount: 789)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        PromisedPaymentView(amount: 789)
    }
    .preferredColorScheme(.dark)
}
