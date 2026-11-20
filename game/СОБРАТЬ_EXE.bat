@echo off
rem Собирает build\ДРАГМЕТ.exe (нужен Godot 4.7.2 и шаблоны экспорта: python tools\get_templates.py)
cd /d "%~dp0"
if not exist build mkdir build
"C:\Program Files\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" "build\ДРАГМЕТ.exe"
pause
