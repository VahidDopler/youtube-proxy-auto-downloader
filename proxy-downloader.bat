
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title YouTube Smart Proxy Downloader

echo ==========================================
echo       YouTube Smart Proxy Downloader
echo ==========================================
echo.

REM Discover listening ports
set "AETHER_PORT="
set "XRAY_PORT="

for /f %%P in ('powershell -NoProfile -Command "$p=Get-Process aether -ErrorAction SilentlyContinue; if($p){Get-NetTCPConnection -State Listen -OwningProcess $p.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort -Unique | Select-Object -First 1}" 2^>nul') do set "AETHER_PORT=%%P"

for /f %%P in ('powershell -NoProfile -Command "$p=Get-Process xray -ErrorAction SilentlyContinue; if($p){Get-NetTCPConnection -State Listen -OwningProcess $p.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort -Unique | Select-Object -First 1}" 2^>nul') do set "XRAY_PORT=%%P"

if defined AETHER_PORT (
    echo [FOUND] Aether: !AETHER_PORT!
) else (
    echo [INFO] Aether unavailable.
)

if defined XRAY_PORT (
    echo [FOUND] Xray: !XRAY_PORT!
) else (
    echo [INFO] Xray unavailable.
)

if not defined AETHER_PORT if not defined XRAY_PORT (
    echo [ERROR] No proxy process found.
    exit /b 1
)

REM Test connectivity and latency
echo.
echo Testing YouTube through available proxies...
echo.

set "AETHER_TIME="
set "XRAY_TIME="

if defined AETHER_PORT (
    call :TEST_PROXY Aether !AETHER_PORT!
    set "AETHER_TIME=!TEST_TIME!"
)

if defined XRAY_PORT (
    call :TEST_PROXY Xray !XRAY_PORT!
    set "XRAY_TIME=!TEST_TIME!"
)

if not defined AETHER_TIME if not defined XRAY_TIME (
    echo.
    echo [ERROR] YouTube is unreachable through both proxies.
    echo Exiting without asking for a URL.
    exit /b 1
)

REM Select mode
echo.
echo ==========================================
echo Select proxy mode:
echo.
echo [1] Automatic - choose lowest latency
echo [2] Manual    - choose proxy yourself
echo ==========================================
choice /c 12 /n /m "Your choice (1 or 2): "

if errorlevel 2 goto MANUAL
goto AUTOMATIC

:AUTOMATIC
set "FIRST="
set "SECOND="

if defined AETHER_TIME if not defined XRAY_TIME (
    set "FIRST=Aether"
    set "SECOND=Xray"
)

if defined XRAY_TIME if not defined AETHER_TIME (
    set "FIRST=Xray"
    set "SECOND=Aether"
)

if defined AETHER_TIME if defined XRAY_TIME (
    for /f %%R in ('powershell -NoProfile -Command "if ([double]::Parse('!AETHER_TIME!', [cultureinfo]::InvariantCulture) -le [double]::Parse('!XRAY_TIME!', [cultureinfo]::InvariantCulture)) { 'Aether' } else { 'Xray' }"') do set "FIRST=%%R"

    if "!FIRST!"=="Aether" (
        set "SECOND=Xray"
    ) else (
        set "SECOND=Aether"
    )
)

echo.
echo [AUTO] Fastest proxy: !FIRST!
echo.

goto GET_URL

:MANUAL
echo.
echo Available proxies:

if defined AETHER_TIME echo [A] Aether - !AETHER_TIME! seconds
if defined XRAY_TIME echo [X] Xray   - !XRAY_TIME! seconds

if defined AETHER_TIME if not defined XRAY_TIME (
    set "FIRST=Aether"
    set "SECOND=Xray"
    echo Only Aether passed the connectivity test.
    goto GET_URL
)

if defined XRAY_TIME if not defined AETHER_TIME (
    set "FIRST=Xray"
    set "SECOND=Aether"
    echo Only Xray passed the connectivity test.
    goto GET_URL
)

choice /c AX /n /m "Choose Aether (A) or Xray (X): "
if errorlevel 2 (
    set "FIRST=Xray"
    set "SECOND=Aether"
) else (
    set "FIRST=Aether"
    set "SECOND=Xray"
)

REM If manually chosen proxy failed the initial test,
REM use the working proxy instead.
if "!FIRST!"=="Aether" if not defined AETHER_TIME (
    echo [WARN] Aether failed the test; using Xray.
    set "FIRST=Xray"
)

if "!FIRST!"=="Xray" if not defined XRAY_TIME (
    echo [WARN] Xray failed the test; using Aether.
    set "FIRST=Aether"
)

:GET_URL
echo.
set "URL="
set /p "URL=Enter YouTube URL: "

if not defined URL (
    echo [ERROR] No URL entered.
    exit /b 1
)

REM Download with the selected proxy
echo.
echo ==========================================
echo Downloading through !FIRST!...
echo ==========================================
call :DOWNLOAD_PROXY "!FIRST!"

if "!DOWNLOAD_RESULT!"=="0" goto SUCCESS

echo.
echo [WARN] Download failed using !FIRST!.
echo Checking the alternate proxy before retrying...

REM Determine whether the alternate proxy is available
if "!SECOND!"=="Aether" (
    if not defined AETHER_PORT goto BOTH_FAILED
    call :TEST_PROXY Aether !AETHER_PORT!
) else (
    if not defined XRAY_PORT goto BOTH_FAILED
    call :TEST_PROXY Xray !XRAY_PORT!
)

if not defined TEST_TIME (
    echo [FAIL] Alternate proxy cannot reach YouTube.
    goto BOTH_FAILED
)

echo.
echo [RETRY] Switching to !SECOND!...
call :DOWNLOAD_PROXY "!SECOND!"

if "!DOWNLOAD_RESULT!"=="0" goto SUCCESS

echo.
echo [ERROR] Download failed through both attempts.
goto END

:SUCCESS
echo.
echo ==========================================
echo [OK] Download completed successfully.
echo ==========================================
goto END

:BOTH_FAILED
echo.
echo [ERROR] No usable alternate proxy.
echo Download could not be completed.
goto END

:TEST_PROXY
set "TEST_TIME="
set "TEST_CODE="

if /i "%~1"=="Aether" (
    set "TEST_PORT=!AETHER_PORT!"
) else (
    set "TEST_PORT=!XRAY_PORT!"
)

echo Testing %~1 on port !TEST_PORT!...

for /f "tokens=1,2" %%A in ('curl.exe --silent --output NUL --connect-timeout 5 --max-time 10 --write-out "%%{time_total} %%{http_code}" --proxy "socks5h://127.0.0.1:!TEST_PORT!" "https://www.youtube.com/generate_204" 2^>nul') do (
    set "CURL_TIME=%%A"
    set "CURL_CODE=%%B"
)

if defined CURL_CODE (
    if !CURL_CODE! GEQ 200 if !CURL_CODE! LSS 400 (
        set "TEST_TIME=!CURL_TIME!"
        echo [OK] %~1: !TEST_TIME! seconds ^(HTTP !CURL_CODE!^)
    ) else (
        echo [FAIL] %~1: HTTP !CURL_CODE!
    )
) else (
    echo [FAIL] %~1: connection failed or timed out.
)

set "CURL_TIME="
set "CURL_CODE="
exit /b

:DOWNLOAD_PROXY
set "DOWNLOAD_NAME=%~1"

if /i "!DOWNLOAD_NAME!"=="Aether" (
    set "DOWNLOAD_PORT=!AETHER_PORT!"
) else (
    set "DOWNLOAD_PORT=!XRAY_PORT!"
)

echo.
echo Proxy: !DOWNLOAD_NAME! - port !DOWNLOAD_PORT!
echo.

yt-dlp.exe ^
    --proxy "socks5://127.0.0.1:!DOWNLOAD_PORT!" ^
    "%URL%" ^
    -S "res:720,ext:mp4:m4a" ^
    --merge-output-format mp4 ^
    --cookies "./cookies.txt" ^
    --js-runtimes node

set "DOWNLOAD_RESULT=!errorlevel!"
exit /b

:END
echo.
pause
exit /b
