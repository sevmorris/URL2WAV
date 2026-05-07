import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 20) {
            header

            VStack(alignment: .leading, spacing: 16) {
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste or drop URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("https://www.youtube.com/watch?v=...", text: $viewModel.url)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .disabled(viewModel.isDownloading)
                }

                // Format Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.selectedFormat) {
                        ForEach(DownloadFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isDownloading)
                }

                // Output Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(viewModel.outputDirectory?.lastPathComponent ?? "Choose folder...")
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose...") {
                            viewModel.selectOutputDirectory()
                        }
                        .disabled(viewModel.isDownloading)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Button(action: viewModel.primaryButtonTap) {
                HStack {
                    if viewModel.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(viewModel.primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isDownloading ? .red : .orange)
            .disabled(!viewModel.canTriggerPrimary)
            .keyboardShortcut(.return, modifiers: [])

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else {
                Text(viewModel.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
        .dropDestination(for: URL.self) { items, _ in
            guard let dropped = items.first else { return false }
            viewModel.acceptIncomingURL(dropped.absoluteString, replaceExisting: true)
            return true
        }
        .task {
            // One-shot clipboard auto-fill: if the field is empty and the
            // pasteboard holds a plausible URL, prefill it as a convenience.
            if viewModel.url.isEmpty,
               let s = NSPasteboard.general.string(forType: .string) {
                viewModel.acceptIncomingURL(s, replaceExisting: false)
            }
        }
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
                Text("WireHack")
                    .font(.headline)
                Text("yt-dlp wrapper")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
    ContentView(viewModel: ContentViewModel())
}
