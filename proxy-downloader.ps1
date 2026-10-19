
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

function Test-Proxy {
    param([string]$Name, [int]$Port)

    $proxy = "socks5h://127.0.0.1:$Port"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    $result = & curl.exe --proxy $proxy --connect-timeout 5 --max-time 12 `
        -sS -o NUL -w "%{http_code}" "https://www.youtube.com/generate_204" 2>$null
    $curlExit = $LASTEXITCODE

    $timer.Stop()
    $httpCode = ($result | Out-String).Trim()
    $ok = ($curlExit -eq 0 -and $httpCode -match '^(200|204|301|302)$')

    [pscustomobject]@{
        Name = $Name
        Port = $Port
        Milliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds)
        HttpCode = $httpCode
        OK = $ok
    }
}

function Invoke-Download {
    param([int]$Port, [string]$Url)

    $proxy = "socks5h://127.0.0.1:$Port"
    $args = @(
        "--proxy", $proxy,
        $Url,
        "-S", "res:720,ext:mp4:m4a",
        "--merge-output-format", "mp4",
        "--js-runtimes", "node"
    )

    if (Test-Path $CookieFile) {
        $args += @("--cookies", $CookieFile)
    }

    Write-Host ""
    Write-Host "Starting download through $proxy ..." -ForegroundColor Cyan
    & $YtDlp @args
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

$candidates = @(Get-ProxyCandidates)

if ($candidates.Count -eq 0) {
    Write-Host "No listening TCP ports were found for aether.exe or xray.exe." -ForegroundColor Red
    Write-Host "Start your proxy client and try again."
    exit 1
}

Write-Host "Detected proxy listeners:"
$candidates | ForEach-Object { Write-Host (" - {0}: 127.0.0.1:{1}" -f $_.Name, $_.Port) }

Write-Host ""
Write-Host "Testing detected proxy routes against YouTube..."
$tests = @()
foreach ($candidate in $candidates) {
    $test = Test-Proxy -Name $candidate.Name -Port $candidate.Port
    $tests += $test
    if ($test.OK) {
        Write-Host ("[OK]   {0} port {1} - {2} ms" -f $test.Name, $test.Port, $test.Milliseconds) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] {0} port {1}" -f $test.Name, $test.Port) -ForegroundColor Red
    }
}

$working = @(
    $tests | Where-Object OK |
    Group-Object Name |
    ForEach-Object { $_.Group | Sort-Object Milliseconds | Select-Object -First 1 }
)

if ($working.Count -eq 0) {
    Write-Host "No detected proxy could reach YouTube. No URL was requested." -ForegroundColor Red
    exit 1
}

# Use the fastest tested port for each proxy application.
$working = @($working | Sort-Object Milliseconds)

if ($working.Count -eq 1) {
    $selected = $working[0]
    Write-Host ("Using the only working route: {0} port {1}" -f $selected.Name, $selected.Port)
} else {
    Write-Host ""
    Write-Host "Choose a proxy:"
    for ($i = 0; $i -lt $working.Count; $i++) {
        Write-Host (" {0}. {1} - port {2} ({3} ms)" -f ($i + 1), $working[$i].Name, $working[$i].Port, $working[$i].Milliseconds)
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
    Write-Host "No URL supplied. Exiting."
    exit 1
}

$success = Invoke-Download -Port $selected.Port -Url $url

if (-not $success) {
    $alternate = @($working | Where-Object { $_.Port -ne $selected.Port } | Select-Object -First 1)
    if ($alternate.Count -gt 0) {
        Write-Host ""
        Write-Host ("Download failed. Retrying once through {0} port {1}..." -f $alternate[0].Name, $alternate[0].Port) -ForegroundColor Yellow
        $success = Invoke-Download -Port $alternate[0].Port -Url $url
    }
}

if ($success) {
    Write-Host "Download completed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Download failed. Check the proxy logs, yt-dlp output, and video access." -ForegroundColor Red
    exit 1
}
