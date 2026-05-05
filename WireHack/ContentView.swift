import SwiftUI

struct ContentView: View {
    @State private var url: String = ""
    @State private var isDownloading: Bool = false
    @State private var status: String = "Ready"
    @State private var errorMessage: String? = nil
    @State private var outputDirectory: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    @State private var selectedFormat: DownloadFormat = .nativeAudio
    
    var body: some View {
        VStack(spacing: 20) {
            header
            
            VStack(alignment: .leading, spacing: 16) {
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("https://www.youtube.com/watch?v=...", text: $url)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .disabled(isDownloading)
                }

                // Format Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $selectedFormat) {
                        ForEach(DownloadFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDownloading)
                }

                // Output Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text(outputDirectory?.lastPathComponent ?? "Choose folder...")
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Choose...") {
                            selectOutputDirectory()
                        }
                        .disabled(isDownloading)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Button(action: startDownload) {
                HStack {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(isDownloading ? "Downloading..." : "Download")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isDownloading || url.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.down.to.line")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("WireHack") // Renamed structurally for the UI
                    .font(.headline)
                Text("yt-dlp wrapper")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Output Destination"
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }

    private func startDownload() {
        guard !url.isEmpty else { return }
        
        isDownloading = true
        status = "Initializing..."
        errorMessage = nil
        
        Task {
            do {
                try await YTDLPService.shared.downloadMedia(url: url, format: selectedFormat, downloadFolder: outputDirectory?.path) { output in
                    // In a more complex version, we'd parse progress here
                }
                status = "Finished! Check your destination folder."
                url = ""
            } catch {
                errorMessage = error.localizedDescription
                status = "Failed"
            }
            isDownloading = false
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
}
