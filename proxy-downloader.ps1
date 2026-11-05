$ErrorActionPreference = "Stop"
$YtDlp = Join-Path $PSScriptRoot "yt-dlp.exe"
$CookieFile = Join-Path $PSScriptRoot "cookies.txt"

function Get-ProxyCandidates {
    $found = @()

    foreach ($processName in @("aether", "xray")) {
        $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
        foreach ($proc in $processes) {
            $listeners = @(Get-NetTCPConnection -State Listen -OwningProcess $proc.Id -ErrorAction SilentlyContinue)
            foreach ($port in @($listeners | Select-Object -ExpandProperty LocalPort -Unique)) {
                $found += [pscustomobject]@{
                    Name = if ($processName -eq "aether") { "Aether" } else { "Xray" }
                    Port = [int]$port
                }
            }
        }
    }

    return @($found | Sort-Object Name, Port -Unique)
}

function Get-RouteLabel {
    param([pscustomobject]$Route)

    if ($Route.Name -eq "Direct") {
        return "Direct connection"
    }

    return "{0} port {1}" -f $Route.Name, $Route.Port
}

function Test-Route {
    param([pscustomobject]$Route)

    $curlArgs = @()
    if ($Route.Name -ne "Direct") {
        $proxy = "socks5h://127.0.0.1:$($Route.Port)"
        $curlArgs += @("--proxy", $proxy)
    }

    $curlArgs += @(
        "--connect-timeout", "5",
        "--max-time", "12",
        "-sS",
        "-o", "NUL",
        "-w", "%{http_code}",
        "https://www.youtube.com/generate_204"
    )

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & curl.exe @curlArgs 2>$null
    $curlExit = $LASTEXITCODE
    $timer.Stop()

    $httpCode = ($result | Out-String).Trim()
    $ok = ($curlExit -eq 0 -and $httpCode -match '^(200|204|301|302)$')

    [pscustomobject]@{
        Name = $Route.Name
        Port = $Route.Port
        Milliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds)
        HttpCode = $httpCode
        OK = $ok
    }
}

function Invoke-Download {
    param([pscustomobject]$Route, [string]$Url)

    $ytDlpArgs = @()
    if ($Route.Name -ne "Direct") {
        $proxy = "socks5h://127.0.0.1:$($Route.Port)"
        $ytDlpArgs += @("--proxy", $proxy)
    }

    $ytDlpArgs += @(
        $Url,
        "-S", "res:720,ext:mp4:m4a",
        "--merge-output-format", "mp4",
        "--js-runtimes", "node"
    )

    if (Test-Path $CookieFile) {
        $ytDlpArgs += @("--cookies", $CookieFile)
    }

    $routeLabel = Get-RouteLabel -Route $Route
    Write-Host ""
    Write-Host "Starting download through $routeLabel ..." -ForegroundColor Cyan
    & $YtDlp @ytDlpArgs
    return ($LASTEXITCODE -eq 0)
}

Write-Host "YouTube Proxy Auto Downloader" -ForegroundColor Cyan
Write-Host "--------------------------------"

if (-not (Test-Path $YtDlp)) {
    Write-Host "ERROR: yt-dlp.exe was not found beside this script." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: curl.exe is unavailable." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: Node.js was not found on PATH. Some YouTube formats may fail." -ForegroundColor Yellow
}

while ($true) {
    Write-Host ""
    $candidates = @(Get-ProxyCandidates)

    if ($candidates.Count -eq 0) {
        Write-Host "No Aether or Xray proxy listener was detected. Checking the direct connection instead." -ForegroundColor Yellow
    } else {
        Write-Host "Detected proxy listeners:"
        $candidates | ForEach-Object {
            Write-Host (" - {0}: 127.0.0.1:{1}" -f $_.Name, $_.Port)
        }
    }

    # Always test direct access too, so the downloader can work without a proxy.
    $candidates += [pscustomobject]@{ Name = "Direct"; Port = 0 }

    Write-Host ""
    Write-Host "Testing available routes against YouTube..."
    $tests = @()
    foreach ($candidate in $candidates) {
        $test = Test-Route -Route $candidate
        $tests += $test
        $label = Get-RouteLabel -Route $test
        if ($test.OK) {
            Write-Host ("[OK]   {0} - {1} ms" -f $label, $test.Milliseconds) -ForegroundColor Green
        } else {
            Write-Host ("[FAIL] {0}" -f $label) -ForegroundColor Red
        }
    }

    $working = @(
        $tests | Where-Object OK |
        Group-Object Name |
        ForEach-Object { $_.Group | Sort-Object Milliseconds | Select-Object -First 1 } |
        Sort-Object Milliseconds
    )

    if ($working.Count -eq 0) {
        Write-Host "No route could reach YouTube. Check your internet connection or proxy, then try again." -ForegroundColor Red
    } else {
        if ($working.Count -eq 1) {
            $selected = $working[0]
            Write-Host ("Using the only working route: {0}" -f (Get-RouteLabel -Route $selected))
        } else {
            Write-Host ""
            Write-Host "Choose a route:"
            for ($i = 0; $i -lt $working.Count; $i++) {
                $label = Get-RouteLabel -Route $working[$i]
                Write-Host (" {0}. {1} ({2} ms)" -f ($i + 1), $label, $working[$i].Milliseconds)
            }
            Write-Host " A. Automatically choose the fastest tested route"

            do {
                $choice = (Read-Host "Enter a number or A").Trim()
                if ($choice -match '^[Aa]$') {
                    $selected = $working[0]
                    break
                }
                if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $working.Count) {
                    $selected = $working[[int]$choice - 1]
                    break
                }
                Write-Host "Invalid selection. Try again." -ForegroundColor Yellow
            } while ($true)
        }

        $url = (Read-Host "Paste the YouTube video URL").Trim()
        if ([string]::IsNullOrWhiteSpace($url)) {
            Write-Host "No URL supplied; returning to the menu." -ForegroundColor Yellow
        } else {
            $success = Invoke-Download -Route $selected -Url $url

            if (-not $success) {
                $alternate = @($working | Where-Object { $_.Name -ne $selected.Name } | Select-Object -First 1)
                if ($alternate.Count -gt 0) {
                    $alternateLabel = Get-RouteLabel -Route $alternate[0]
                    Write-Host ""
                    Write-Host ("Download failed. Retrying once through {0}..." -f $alternateLabel) -ForegroundColor Yellow
                    $success = Invoke-Download -Route $alternate[0] -Url $url
                }
            }

            if ($success) {
                Write-Host "Download completed." -ForegroundColor Green
            } else {
                Write-Host "Download failed. Check the proxy logs, yt-dlp output, and video access." -ForegroundColor Red
            }
        }
    }

    do {
        $again = (Read-Host "Would you like to download another video? (Y/N)").Trim()
        if ($again -match '^[Yy]$') {
            break
        }
        if ($again -match '^[Nn]$') {
            Write-Host "Goodbye."
            exit 0
        }
        Write-Host "Please enter Y or N." -ForegroundColor Yellow
    } while ($true)
}
