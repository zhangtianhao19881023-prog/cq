@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" goto nopy
echo Starting auto-attack helper ...
".venv\Scripts\python.exe" main.py
echo.
echo [process exited]
pause
exit /b 0
:nopy
echo.
echo [!] .venv\Scripts\python.exe not found.
echo     Please run:  python -m pip install -r requirements.txt
echo.
pause
exit /b 1
