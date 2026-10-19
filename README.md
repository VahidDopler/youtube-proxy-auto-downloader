
# YouTube Proxy Auto Downloader

A Windows utility for downloading YouTube videos through a local SOCKS5 proxy provided by Aether/WhiteAether or Xray.

## Features

- Detects local listening ports belonging to `aether.exe` and `xray.exe`.
- Stops before asking for a video URL when no supported proxy listener is detected.
- Tests each detected proxy's access to YouTube.
- Supports manual proxy selection or automatic selection based on measured response time.
- Retries a failed download once through the alternate proxy, if that proxy passed its initial test.
- Targets up to 720p and prefers MP4 video with M4A audio.
- Uses FFmpeg to merge separate audio and video streams when needed.
- Supports optional YouTube cookies and the Node.js JavaScript runtime.

## Requirements

- Windows 10 or Windows 11
- [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases/latest)
- [FFmpeg](https://ffmpeg.org/download.html), including `ffmpeg.exe` and `ffprobe.exe`
- [Node.js](https://nodejs.org/)
- `curl.exe` (included with modern Windows versions)
- A running Aether/WhiteAether or Xray client with a local SOCKS5 listener

### Installation

1. Download or clone this repository.
2. Place `yt-dlp.exe` beside `youtube-downloader.bat`.
3. Install Node.js and FFmpeg.
4. Ensure `node`, `curl`, and FFmpeg are available on your `PATH`, or follow the project's executable-location instructions.
5. Start your proxy client.
6. Run `youtube-downloader.bat` and follow the prompts.

## Optional cookies setup

Public videos may not require cookies. Cookies can help yt-dlp access content your account is authorized to view.

For better separation from your everyday browsing:

1. Create a dedicated browser profile.
2. Sign in to YouTube in that profile only if needed.
3. Use a reputable browser extension to export the required YouTube cookies in Netscape `cookies.txt` format.
4. Save the file as `cookies.txt` beside the downloader.
5. Keep the file private and delete it when you no longer need it.

A separate browser profile is **not anonymity**. Services can still associate activity with a signed-in account and other signals. Valid session cookies can grant access to your account, so treat `cookies.txt` like a password.

**Never commit or share `cookies.txt`.** The `.gitignore` file excludes it from Git. Check the files list before pushing changes. Use cookies only for accounts and content you are authorized to access.

If you do not need cookies, configure the downloader to omit the `--cookies` option.

## Quality and output

The downloader is intended to select formats up to 720p, prefer MP4/M4A, and merge streams into an MP4 container when possible. Available formats depend on the video. Normal stream merging does not require re-encoding.

## Troubleshooting

- **No proxy detected:** Start your proxy application and verify that its process name and listener match the script's detection rules.
- **Proxy test failed:** Check the local SOCKS5 port, connection status, DNS/routing, and access to YouTube through that route.
- **SOCKS server failure during download:** A successful connectivity check does not guarantee that the proxy can sustain a full download. Review the proxy logs or try the alternate route.
- **FFmpeg not found:** Add FFmpeg's `bin` directory to `PATH` or place its executables beside `yt-dlp.exe`.
- **JavaScript challenge errors:** Update yt-dlp and verify that Node.js is installed and available on `PATH`.
- **Authentication errors:** Check account access and export a fresh cookie file from the dedicated browser profile.

## Security and responsible use

- Never commit cookies, browser profiles, or downloaded media.
- Keep yt-dlp and its dependencies updated.
- Respect copyright, YouTube's terms, and applicable law. Download only content you are permitted to save.

## License

No license is included yet. Add a license file if you want to specify how others may use, modify, or redistribute this project.
