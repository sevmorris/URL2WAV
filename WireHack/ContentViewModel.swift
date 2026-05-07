import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ContentViewModel {
    var url: String = ""
    var isDownloading: Bool = false
    var status: String = "Ready"
    var errorMessage: String? = nil
    var selectedFormat: DownloadFormat = .nativeAudio

    var outputDirectoryPath: String {
        didSet { UserDefaults.standard.set(outputDirectoryPath, forKey: Self.outputKey) }
    }

    private static let outputKey = "outputDirectoryPath"
    private var downloadTask: Task<Void, Never>?

    init() {
        outputDirectoryPath = UserDefaults.standard.string(forKey: Self.outputKey) ?? ""
    }

    var outputDirectory: URL? {
        if outputDirectoryPath.isEmpty {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        }
        return URL(fileURLWithPath: outputDirectoryPath)
    }

    var primaryButtonTitle: String { isDownloading ? "Cancel" : "Download" }

    var canTriggerPrimary: Bool {
        isDownloading || !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func primaryButtonTap() {
        if isDownloading {
            downloadTask?.cancel()
        } else {
            startDownload()
        }
    }

    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Output Destination"
        if panel.runModal() == .OK, let chosen = panel.url {
            outputDirectoryPath = chosen.path
        }
    }

    /// Accepts a string from drag-and-drop or clipboard. Sets `url` only if it
    /// looks like an http(s) URL and the field is currently empty (auto-fill)
    /// or the user explicitly dropped onto the field.
    func acceptIncomingURL(_ raw: String, replaceExisting: Bool) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return }
        if replaceExisting || url.isEmpty {
            url = trimmed
        }
    }

    private func startDownload() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isDownloading = true
        status = "Initializing..."
        errorMessage = nil

        let format = selectedFormat
        let destPath = outputDirectory?.path
        let destLabel = outputDirectory?.lastPathComponent ?? "destination"

        downloadTask = Task {
            defer {
                isDownloading = false
                downloadTask = nil
            }
            do {
                try await YTDLPService.shared.downloadMedia(
                    url: trimmed,
                    format: format,
                    downloadFolder: destPath
                ) { [weak self] line in
                    Task { @MainActor in self?.status = line }
                }
                status = "Finished — saved to \(destLabel)"
                url = ""
            } catch is CancellationError {
                status = "Cancelled"
            } catch YTDLPError.cancelled {
                status = "Cancelled"
            } catch {
                errorMessage = error.localizedDescription
                status = "Failed"
            }
        }
    }
}
