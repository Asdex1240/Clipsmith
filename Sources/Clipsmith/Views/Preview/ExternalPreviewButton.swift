import SwiftUI

struct ExternalPreviewButton: View {
    private static let symbol = "rectangle.on.rectangle"

    let controller: ExternalPreviewController

    var body: some View {
        if controller.isShowing || controller.candidates.count < 2 {
            toggle
        } else {
            displayMenu
        }
    }

    private var toggle: some View {
        Toggle(isOn: Binding(get: { controller.isShowing }, set: { _ in controller.toggle() })) {
            Label(localized("preview.external"), systemImage: Self.symbol)
        }
        .toggleStyle(.button)
        .help(helpText)
    }

    private var displayMenu: some View {
        Menu {
            ForEach(controller.candidates) { display in
                Button(display.name) { controller.show(on: display) }
            }
        } label: {
            Label(localized("preview.external"), systemImage: Self.symbol)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(localized("preview.external.help"))
    }

    private var helpText: String {
        if controller.isShowing { return localized("preview.external.stop") }
        return localized("preview.external.help")
    }
}

#Preview {
    ExternalPreviewButton(
        controller: ExternalPreviewController(
            monitor: DisplayMonitor(), makeContentView: NSView.init)
    )
    .padding()
}
