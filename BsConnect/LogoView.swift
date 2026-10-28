//
//  LogoView.swift
//  BsConnect
//
//  Created by Pavel Savvateev on 28.10.2026.
//


import SwiftUI
import UIKit

extension Color {
    /// Цвет, который сам меняется в светлой и тёмной теме
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    // MARK: Брендовые (одинаковые в обеих темах)

    static let appBlue   = Color(hex: "#016994")
    static let appOrange = Color(hex: "#f7a339")

    // MARK: Адаптивные

    static let appBackground = Color(light: .white, dark: .black)

    static let appText = Color(light: .black, dark: .white)

    static let appTextSecondary = Color(
        light: UIColor.black.withAlphaComponent(0.6),
        dark: UIColor.white.withAlphaComponent(0.6)
    )

    /// Синий для текста и иконок: на тёмном фоне светлее, чтобы читался
    static let appBlueText = Color(
        light: UIColor(red: 0.004, green: 0.412, blue: 0.580, alpha: 1), // #016994
        dark: UIColor(red: 0.30, green: 0.71, blue: 0.88, alpha: 1)      // #4DB6E0
    )

    /// Alert color: светлая тема #D32F2F (заглушка, замените на брендбук), тёмная — светлее для контраста
    static let appAlert = Color(
        light: UIColor(red: 0.827, green: 0.184, blue: 0.184, alpha: 1), // #D32F2F
        dark: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1)       // #FF6B6B
    )
}

// MARK: - Logo

struct LogoView: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
//            RoundedRectangle(cornerRadius: size * 0.25)
//                .stroke(Color.appBlue, lineWidth: 2)           // рамка вместо синей плитки
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)   // тот же размер, что был у антенны
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Логотип")
    }
}

// MARK: - Кнопки

struct PrimaryButton: View {
    let title: String
    var color: Color = .appBlue
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    var color: Color = .appOrange
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 2)
                )
                .foregroundColor(color)
        }
    }
}

// MARK: - Кнопка «назад» со стрелкой

struct BackArrowModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.appBlueText)
                    }
                    .accessibilityLabel("Назад")
                }
            }
    }
}

extension View {
    func backArrow() -> some View { modifier(BackArrowModifier()) }
}

// MARK: - Форматирование

extension Double {
    var rubles: String {
        self.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU")))
    }
}
