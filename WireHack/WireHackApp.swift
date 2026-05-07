import SwiftUI

@main
struct WireHackApp: App {
    @State private var viewModel = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    Task {
                        await checkForUpdates(silent: true)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task {
                        await checkForUpdates(silent: false)
                    }
                }
            }
        }
    }
}
