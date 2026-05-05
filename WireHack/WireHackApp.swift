import SwiftUI

@main
struct WireHackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
