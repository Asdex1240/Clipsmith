import SwiftUI

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: ParameterUnit
    var defaultValue: Double?

    private static let defaultTolerance = 1e-6
    private static let scrubStartDistance: CGFloat = 3

    @State private var isEditing = false
    @State private var scrubStart: Double?
    @FocusState private var isFocused: Bool

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

    @ViewBuilder
    private var valueField: some View {
        if isEditing {
            editableField
        } else {
            Text(unit.text(for: value))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .onTapGesture { beginEditing() }
                .gesture(scrubGesture)
                .help(localized("inspector.value.edit"))
                .accessibilityLabel(title)
                .accessibilityValue(unit.text(for: value))
                .accessibilityAddTraits(.isButton)
        }
    }

    private var editableField: some View {
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
            .focused($isFocused)
            .onSubmit { isEditing = false }
            .onChange(of: isFocused) {
                if !isFocused { isEditing = false }
            }
            Text(unit.suffix.trimmingCharacters(in: .whitespaces))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var scrubSpeed: ScrubSpeed {
        if NSEvent.modifierFlags.contains(.option) { return .fine }
        return .normal
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: Self.scrubStartDistance)
            .onChanged { drag in
                let start = scrubStart ?? value
                scrubStart = start
                value = ValueScrubber.value(
                    startingAt: start, dragging: drag.translation.width, in: range,
                    speed: scrubSpeed)
            }
            .onEnded { _ in scrubStart = nil }
    }

    private func beginEditing() {
        isEditing = true
        isFocused = true
    }

    private var resetButton: some View {
        Button {
            guard let defaultValue else { return }
            value = defaultValue
        } label: {
            Image(systemName: "arrow.counterclockwise").minimumHitTarget()
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
