@echo off
chcp 65001 >nul
cd /d "%~dp0"
set TIANHAO_STEALTH=1
set TIANHAO_WINDOW_TITLE=RuntimeHost
if not exist ".venv\Scripts\pythonw.exe" goto nopy
if not exist ".venv\Scripts\RuntimeHost.exe" copy /y ".venv\Scripts\pythonw.exe" ".venv\Scripts\RuntimeHost.exe" >nul
start "" ".venv\Scripts\RuntimeHost.exe" main.py
exit /b 0
:nopy
echo missing .venv\Scripts\pythonw.exe
pause
exit /b 1