import SwiftUI

struct CanvasPicker: View {
    let store: ProjectStore
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(store.project.canvas.summary, systemImage: "aspectratio")
                .monospacedDigit()
        }
        .help(localized("canvas.help"))
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            CanvasSettings(store: store)
        }
    }
}

private struct CanvasSettings: View {
    let store: ProjectStore
    @State private var widthText = ""
    @State private var heightText = ""

    private static let width: CGFloat = 300
    private static let fieldWidth: CGFloat = 72
    private static let resolutionOptions: [ExportResolution] = [.hd720, .hd1080, .qhd1440, .uhd4K]

    private var canvas: CanvasFormat { store.project.canvas }

    private func checkmarkOpacity(for preset: CanvasFormat) -> Double {
        if preset.aspectLabel == canvas.aspectLabel { return 1 }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.comfortable) {
            Text(localized("canvas.title")).font(.headline)
            Text(localized("canvas.hint")).font(.caption).foregroundStyle(.secondary)
            presets
            Divider()
            resolutionPicker
            customSize
            Divider()
            Toggle(localized("canvas.autoFit"), isOn: autoFitBinding)
        }
        .padding(Design.Spacing.spacious)
        .frame(width: Self.width)
        .onAppear(perform: syncFields)
        .onChange(of: store.project.canvas) { syncFields() }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
            ForEach(CanvasFormat.presets) { preset in
                let resized = preset.scaled(toShortSide: canvas.shortSide)
                Button {
                    store.setCanvas(resized)
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                            .opacity(checkmarkOpacity(for: preset))
                        Text(preset.aspectLabel ?? "")
                        Spacer()
                        Text("\(resized.width)×\(resized.height)").foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resolutionPicker: some View {
        Picker(localized("canvas.resolution"), selection: resolutionBinding) {
            ForEach(Self.resolutionOptions) { Text($0.title).tag(Optional($0)) }
            Text(localized("canvas.custom")).tag(Optional<ExportResolution>.none)
        }
    }

    private var customSize: some View {
        HStack {
            Text(localized("canvas.customSize"))
            Spacer()
            TextField("", text: $widthText).frame(width: Self.fieldWidth)
            Text("×")
            TextField("", text: $heightText).frame(width: Self.fieldWidth)
            Button(localized("canvas.apply"), action: applyCustomSize)
                .disabled(parsedCustomSize == nil)
        }
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .onSubmit(applyCustomSize)
    }

    private var resolutionBinding: Binding<ExportResolution?> {
        Binding(
            get: { Self.resolutionOptions.first { $0.shortSide == canvas.shortSide } },
            set: { option in
                guard let side = option?.shortSide else { return }
                store.setCanvas(canvas.scaled(toShortSide: side))
            }
        )
    }

    private var autoFitBinding: Binding<Bool> {
        Binding(get: { store.project.autoFitCanvas }, set: store.setAutoFitCanvas)
    }

    private var parsedCustomSize: CanvasFormat? {
        guard let width = Int(widthText), let height = Int(heightText),
            width > 0, height > 0
        else { return nil }
        return CanvasFormat(width: width, height: height)
    }

    private func applyCustomSize() {
        guard let format = parsedCustomSize else { return }
        store.setCanvas(format)
        syncFields()
    }

    private func syncFields() {
        widthText = String(canvas.width)
        heightText = String(canvas.height)
    }
}

#Preview {
    CanvasPicker(store: PreviewFixtures.store())
        .padding()
}
