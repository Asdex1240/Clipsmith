import SwiftUI

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: ParameterUnit
    var defaultValue: Double?

    private static let defaultTolerance = 1e-6

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
            HStack(spacing: Design.Spacing.tight) {
                Text(title)
                Spacer()
                valueField
                resetButton
            }
            Slider(value: $value, in: range)
                .accessibilityLabel(title)
        }
    }

    private var valueField: some View {
        HStack(spacing: Design.Spacing.hairline) {
            TextField(
                title, value: displayBinding,
                format: .number.precision(.fractionLength(unit.fractionDigits))
            )
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: Design.Size.valueField)
            Text(unit.suffix.trimmingCharacters(in: .whitespaces))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var resetButton: some View {
        Button {
            guard let defaultValue else { return }
            value = defaultValue
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.borderless)
        .opacity(resetOpacity)
        .disabled(isAtDefault)
        .accessibilityHidden(isAtDefault)
        .accessibilityLabel(localized("inspector.reset"))
        .help(localized("inspector.reset"))
    }

    private var displayBinding: Binding<Double> {
        Binding(
            get: { unit.displayValue(value) },
            set: { value = unit.value(fromDisplay: $0, in: range) }
        )
    }

    private var isAtDefault: Bool {
        guard let defaultValue else { return true }
        return abs(value - defaultValue) < Self.defaultTolerance
    }

    private var resetOpacity: Double {
        if isAtDefault { return 0 }
        return 1
    }
}

#Preview {
    @Previewable @State var value = 0.4
    ParameterSlider(
        title: "Volume", value: $value, range: 0...1, unit: .percent, defaultValue: 1
    )
    .padding()
    .frame(width: 260)
}
