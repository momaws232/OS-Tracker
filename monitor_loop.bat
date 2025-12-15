@echo off
REM Continuous Windows metrics collection loop
cd /d "%~dp0"
chcp 65001 >nul 2>&1

:loop
python monitor_windows.py 1>nul 2>&1
timeout /t 5 /nobreak >nul 2>&1
goto loop
