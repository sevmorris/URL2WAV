import Foundation

enum DownloadFormat: String, CaseIterable, Identifiable {
    case nativeAudio = "Native Audio Only"
    case nativeVideo = "Native Video"
    
    var id: String { self.rawValue }
    
    var ytDlpFormatArg: String {
        switch self {
        case .nativeAudio: return "ba"
        case .nativeVideo: return "best"
        }
    }
}

enum YTDLPError: LocalizedError {
    case notFound
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "yt-dlp not found at /opt/homebrew/bin/yt-dlp."
        case .executionFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

class YTDLPService {
    static let shared = YTDLPService()
    
    private let ytDlpPath = "/opt/homebrew/bin/yt-dlp"
    
    func downloadMedia(url: String, format: DownloadFormat, downloadFolder: String? = nil, onProgress: @escaping (String) -> Void) async throws {
        guard FileManager.default.fileExists(atPath: ytDlpPath) else {
            throw YTDLPError.notFound
        }
        
        let destinationFolder = downloadFolder ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "/tmp"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        // Use the native format arguments and output template, completely bypassing ffmpeg transcoding.
        // The output template ensures yt-dlp uses the server-provided extension automatically.
        process.arguments = [
            "-f", format.ytDlpFormatArg,
            "-P", destinationFolder,
            "-o", "%(title)s.%(ext)s",
            "--no-playlist",
            url
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw YTDLPError.executionFailed(errorMessage)
        }
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        onProgress(output)
    }
}
