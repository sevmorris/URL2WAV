import Foundation

enum DownloadFormat: String, CaseIterable, Identifiable {
    case nativeAudio = "Audio"
    case nativeVideo = "Video"

    var id: String { rawValue }

    var ytDlpFormatArg: String {
        switch self {
        case .nativeAudio: return "ba"
        case .nativeVideo: return "best"
        }
    }
}

enum YTDLPError: LocalizedError {
    case notFound(searched: [String])
    case executionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notFound(let paths):
            return "yt-dlp not found. Looked in: \(paths.joined(separator: ", ")). Install with: brew install yt-dlp"
        case .executionFailed(let message):
            return "Download failed: \(message)"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

final class YTDLPService {
    static let shared = YTDLPService()

    // Searched in order. Covers Apple Silicon Homebrew, Intel Homebrew, MacPorts,
    // pipx user installs, and the system path.
    private static let candidatePaths: [String] = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/opt/local/bin/yt-dlp",
        (NSString(string: "~/.local/bin/yt-dlp") as NSString).expandingTildeInPath,
        "/usr/bin/yt-dlp"
    ]

    private func resolveBinary() throws -> String {
        let fm = FileManager.default
        for path in Self.candidatePaths where fm.isExecutableFile(atPath: path) {
            return path
        }
        throw YTDLPError.notFound(searched: Self.candidatePaths)
    }

    /// Streams yt-dlp output line-by-line via `onProgress`. Cancels by terminating
    /// the child process when the surrounding `Task` is cancelled.
    func downloadMedia(
        url: String,
        format: DownloadFormat,
        downloadFolder: String? = nil,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws {
        let binary = try resolveBinary()

        let destination = downloadFolder
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSTemporaryDirectory()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "-f", format.ytDlpFormatArg,
            "-P", destination,
            "-o", "%(title)s.%(ext)s",
            "--no-playlist",
            "--newline",
            url
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Tail recent stderr for the failure message — yt-dlp's actionable error
        // is usually within the last few hundred bytes.
        let stderrTail = StderrTail()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Drain both pipes concurrently. Reading only one to EOF before the
        // other deadlocks the child once its sibling pipe buffer fills.
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            forEachLine(in: data) { onProgress($0) }
        }
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrTail.append(data)
            forEachLine(in: data) { onProgress($0) }
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    if proc.terminationReason == .uncaughtSignal {
                        cont.resume(throwing: YTDLPError.cancelled)
                    } else if proc.terminationStatus == 0 {
                        cont.resume(returning: ())
                    } else {
                        let tail = stderrTail.snapshot().trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = tail.isEmpty
                            ? "yt-dlp exited with code \(proc.terminationStatus)"
                            : tail
                        cont.resume(throwing: YTDLPError.executionFailed(msg))
                    }
                }

                do {
                    try process.run()
                } catch {
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

private func forEachLine(in data: Data, _ body: (String) -> Void) {
    guard let chunk = String(data: data, encoding: .utf8) else { return }
    // yt-dlp progress can use either \n (with --newline) or \r. Split on both.
    for raw in chunk.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
        let line = String(raw).trimmingCharacters(in: .whitespaces)
        if !line.isEmpty { body(line) }
    }
}

private final class StderrTail: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let cap = 8 * 1024

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        buffer.append(data)
        if buffer.count > cap {
            buffer.removeFirst(buffer.count - cap)
        }
    }

    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: buffer, encoding: .utf8) ?? ""
    }
}
