# URL2WAV

A simple macOS utility to download audio from URLs (YouTube, Soundcloud, etc.) and convert them to WAV format using `yt-dlp`.

## Requirements
*   **yt-dlp**: Must be installed at `/opt/homebrew/bin/yt-dlp`.
*   **ffmpeg**: Required by `yt-dlp` for audio extraction.

## Usage
1.  Open `URL2WAV.xcodeproj` in Xcode.
2.  Build and Run (Cmd+R).
3.  Paste a URL and click **Grab WAV**.
4.  The result will be saved in your **Downloads** folder.

## Technical Details
*   Built with SwiftUI.
*   Uses `Process` to wrap `yt-dlp`.
*   Command used: `yt-dlp -x --audio-format wav --audio-quality 0 -P ~/Downloads --no-playlist <URL>`
