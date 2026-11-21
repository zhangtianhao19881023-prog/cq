@echo off
chcp 65001 >nul
set "SRC=%~dp0"
set "DEST=%LOCALAPPDATA%\RuntimeHost"
if not exist "%DEST%" mkdir "%DEST%"
xcopy "%SRC%*" "%DEST%\" /E /I /Y >nul
set TIANHAO_STEALTH=1
set TIANHAO_WINDOW_TITLE=RuntimeHost
start "" "%DEST%\RuntimeHost.exe"
exit /b 0