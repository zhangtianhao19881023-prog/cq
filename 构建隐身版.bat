@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" goto nopy
".venv\Scripts\python.exe" -m PyInstaller --noconfirm --clean --onefile --windowed --uac-admin --name RuntimeHost main.py
if errorlevel 1 goto fail
if not exist "dist\RuntimeHost" mkdir "dist\RuntimeHost"
copy /y "dist\RuntimeHost.exe" "dist\RuntimeHost\RuntimeHost.exe" >nul
copy /y "clients.json" "dist\RuntimeHost\clients.json" >nul
copy /y "config.json" "dist\RuntimeHost\config.json" >nul
if exist "dm.dll" copy /y "dm.dll" "dist\RuntimeHost\dm.dll" >nul
if exist "授权.txt" copy /y "授权.txt" "dist\RuntimeHost\授权.txt" >nul
copy /y "安装到LocalAppData并启动.bat" "dist\RuntimeHost\安装到LocalAppData并启动.bat" >nul
echo done: dist\RuntimeHost
pause
exit /b 0
:nopy
echo missing .venv\Scripts\python.exe
pause
exit /b 1
:fail
echo build failed
pause
exit /b 1