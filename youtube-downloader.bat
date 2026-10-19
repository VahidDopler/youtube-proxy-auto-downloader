<CodeBlock language="batch" editable>
@echo off
setlocal
title YouTube Proxy Auto Downloader


powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0proxy-downloader.ps1"

echo.
pause
endlocal
</CodeBlock>
