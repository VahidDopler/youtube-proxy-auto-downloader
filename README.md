# YouTube Proxy Auto Downloader

A small Windows command-line helper that routes yt-dlp downloads through a local SOCKS5 proxy exposed by Aether/WhiteAether or Xray. It checks the detected routes, lets you select one (or automatically chooses the fastest route), then passes a video URL to yt-dlp.

This repository contains a PowerShell script and a batch launcher. It is not a browser app or a proxy client: you need to install yt-dlp, FFmpeg, Node.js, and run your own supported proxy client.

## What it does

- Looks for running `aether.exe` and `xray.exe` processes and enumerates their listening TCP ports.
- Tests each discovered port by making a short request to YouTube through `socks5h://127.0.0.1:<port>`.
- Keeps the fastest working port per proxy application.
- If both Aether and Xray have a working route, asks you to choose or lets you select the fastest route.
- Prompts for a YouTube video URL and starts yt-dlp through the selected route.
- If the download fails and another proxy application's route passed the test, retries once through that route.
- Sorts formats to prefer MP4 video and M4A audio up to 720p, and asks FFmpeg to merge separate streams into MP4 when available.
- Adds Node.js as yt-dlp's JavaScript runtime and automatically uses a local `cookies.txt` file when one exists beside the script.

The proxy check only confirms that a route can reach YouTube at that moment. It cannot guarantee the full download will succeed. The script treats every listening TCP port owned by the detected process as a SOCKS5 port, so configure the proxy application to expose a SOCKS5 listener.

## Requirements

- Windows 10 or 11 with PowerShell
- A running Aether/WhiteAether or Xray client exposing a local SOCKS5 listener
- [yt-dlp for Windows](https://github.com/yt-dlp/yt-dlp/releases/latest)
- [FFmpeg](https://ffmpeg.org/download.html) (including `ffmpeg.exe` and `ffprobe.exe`) for merging separate video/audio streams
- [Node.js](https://nodejs.org/) for YouTube's JavaScript challenge support
- `curl.exe` (included with current Windows versions)

## Install

1. Download this repository using **Code → Download ZIP**, then extract it; or clone it:
   ```powershell
   git clone https://github.com/VahidDopler/youtube-proxy-auto-downloader.git
   ```
2. Download the Windows `yt-dlp.exe` release and put it in the same folder as `youtube-downloader.bat` and `proxy-downloader.ps1`.
3. Install FFmpeg and Node.js. Make sure `ffmpeg.exe`, `ffprobe.exe`, and `node.exe` are on your Windows `PATH`. Alternatively, put FFmpeg's executables in the same folder as `yt-dlp.exe`.
4. Start Aether/WhiteAether or Xray and confirm its local SOCKS5 listener is enabled.
5. Double-click `youtube-downloader.bat`. If Windows asks, allow the script to run. The launcher invokes PowerShell with `-ExecutionPolicy Bypass` for this script only; it does not change the machine-wide execution policy.
6. Choose a listed route or enter `A` for automatic fastest-route selection, then paste the video URL.

Downloads are saved to yt-dlp's current default location (normally the folder from which the launcher is run).

## Create and use a YouTube `cookies.txt`

Cookies are optional. Use them only when you are signed in to an account that is allowed to access the video and you have permission to save that content. Cookies do not grant permission or bypass YouTube restrictions. A cookie file contains active login credentials; anyone who gets it may be able to use your signed-in session.

### Recommended: export only YouTube cookies from your browser

1. Open Chrome, Edge, or Firefox and sign in to the YouTube account whose access you are authorized to use.
2. Install a reputable cookie exporter that saves locally in Netscape format. For Chrome or Edge, one option is [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc); its [source and privacy details](https://github.com/kairi003/Get-cookies.txt-Locally) are available on GitHub. For Firefox, use the [cookies.txt add-on](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/). Check an extension's current permissions and publisher before installing it. Avoid similarly named Chrome extensions that do not say **LOCALLY**.
3. Open `youtube.com` in the same browser profile where you are signed in.
4. Open the cookie-export extension while on YouTube. Export cookies for the current site (or YouTube only), in **Netscape** format. Do not choose an “all sites” export if a site-only export is available.
5. Save the exported file as `cookies.txt` in the same folder as `proxy-downloader.ps1` and `youtube-downloader.bat`. If Windows hides file extensions, make sure the name did not become `cookies.txt.txt`.
6. Run the launcher again. The script detects that file and passes it to yt-dlp automatically; there is no extra prompt or command-line option.
7. If the file stops working, sign in again and export a fresh copy. Do not edit cookie values by hand.

A valid Netscape cookie file normally begins with `# Netscape HTTP Cookie File` or `# HTTP Cookie File`. Exporting all sites creates a much more sensitive file than exporting YouTube alone.

### Alternative: let yt-dlp export browser cookies

If you already have yt-dlp installed, its documented `--cookies-from-browser` option can write cookies to a file. Example for Chrome:

```powershell
.\yt-dlp.exe --cookies-from-browser chrome --cookies .\cookies.txt
```

This method may export cookies for **all sites** in that browser profile, not just YouTube, so the resulting file is especially sensitive. Keep it private and use a dedicated browser profile if you choose this method.

### Protect and remove the file

- Never commit, upload, email, or share `cookies.txt`; do not paste its contents into an issue or chat.
- The repository's `.gitignore` excludes `cookies.txt`, `cookies*.txt`, and `*.cookies`, but still check GitHub's changed-files list before committing.
- Store it only on a device you control. Delete it when it is no longer needed, then sign out of the browser session or revoke sessions in your Google Account security settings if you think the file was exposed.
- If you do not need account authentication, remove the file; without it, the script runs yt-dlp without cookies.

## Format and output notes

The script uses yt-dlp's format sorting preference `res:720,ext:mp4:m4a`, then requests an MP4 merge container. This is a preference, not a guarantee: the formats available for a particular video, account, and yt-dlp version can vary. FFmpeg merges separate streams without re-encoding in the normal case. If FFmpeg is unavailable, yt-dlp may be unable to combine separate video and audio streams.

## Troubleshooting

| Problem | Things to check |
| --- | --- |
| “yt-dlp.exe was not found” | Put `yt-dlp.exe` beside the batch and PowerShell files. |
| No proxy listeners detected | Start Aether/Xray; confirm the process is named `aether.exe` or `xray.exe` and has a TCP listener. |
| Proxy detected but test fails | Confirm that listener is SOCKS5, and check the proxy's route, DNS, firewall, and logs. |
| Download fails after a successful test | A short test does not test a full transfer. Check yt-dlp's error output and proxy logs; choose the alternate route if offered. |
| FFmpeg merge error | Install a current FFmpeg build and put its `bin` folder on `PATH`, or put `ffmpeg.exe` and `ffprobe.exe` beside `yt-dlp.exe`. |
| JavaScript challenge or format errors | Update yt-dlp and make sure Node.js is available on `PATH`. |
| Login-required or account access error | Confirm the account can view the content, then export a fresh YouTube cookie file. Keep the browser and downloader on the same network/proxy route when possible. |
| Cookie file is ignored | Check the filename is exactly `cookies.txt` and that it sits beside `proxy-downloader.ps1`. |

## Responsible use

Only download videos you own or are otherwise authorized to save. Follow YouTube's terms, copyright law, and any rights or restrictions that apply to the content. Do not use this tool to bypass paywalls, access controls, or account restrictions.

## License

A `LICENSE` file is included. See it for the terms that apply to this repository.
