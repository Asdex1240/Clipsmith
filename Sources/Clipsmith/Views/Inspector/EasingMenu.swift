import SwiftUI

struct EasingMenu: View {
    let easing: Easing
    let onChange: (Easing) -> Void

    var body: some View {
        Menu {
            ForEach(Easing.allCases, id: \.self) { option in
                Toggle(
                    Self.title(of: option),
                    isOn: Binding(get: { easing == option }, set: { _ in onChange(option) }))
            }
        } label: {
            Image(systemName: Self.symbol(of: easing))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("\(localized("easing.title")): \(Self.title(of: easing))")
    }

    static func title(of easing: Easing) -> String {
        switch easing {
        case .linear: return localized("easing.linear")
        case .easeIn: return localized("easing.easeIn")
        case .easeOut: return localized("easing.easeOut")
        case .easeInOut: return localized("easing.easeInOut")
        }
    }

    private static func symbol(of easing: Easing) -> String {
        switch easing {
        case .linear: return "chart.line.uptrend.xyaxis"
        case .easeIn: return "arrow.up.right"
        case .easeOut: return "arrow.down.right"
        case .easeInOut: return "scribble.variable"
        }
    }
}

#Preview {
    EasingMenu(easing: .easeInOut, onChange: { _ in })
        .padding()
}
