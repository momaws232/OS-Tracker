@echo off
REM ============================================================================
REM Solution 1 - Continuous Monitor + Dashboard
REM Runs metrics collection in background + Dashboard in Docker
REM ============================================================================

echo.
echo ================================================================
echo  Solution 1: Host Agent + Container Dashboard
echo ================================================================
echo.

echo [1/4] Cleaning old metrics...
if exist "data\metrics\*.json" (
    del /q "data\metrics\*.json" 2>nul
    echo Old metrics deleted successfully
) else (
    echo No old metrics found
)

REM Create data directory if it doesn't exist
if not exist "data\metrics" mkdir "data\metrics"

echo.
echo [2/4] Generating fresh metrics for this device...
python monitor_windows.py
if %errorLevel% neq 0 (
    echo [ERROR] Failed to generate metrics
    echo Make sure Python and dependencies are installed:
    echo    pip install psutil wmi
    pause
    exit /b 1
)
echo Fresh metrics generated!

echo.
echo [3/4] Starting dashboard container...
docker-compose -f docker-compose-solution1.yml up -d
if %errorLevel% neq 0 (
    echo [ERROR] Failed to start dashboard container
    echo Make sure Docker Desktop is running!
    pause
    exit /b 1
)

echo.
echo [4/5] Starting WSL Docker monitor...
docker-compose -f docker-compose-bash.yml up -d
if %errorLevel% neq 0 (
    echo [WARNING] WSL Docker monitor failed to start
    echo WSL metrics will not be available
) else (
    echo WSL Docker monitor started!
)

echo.
echo [5/5] Starting continuous Windows metrics collection...
echo Running in background (PowerShell window will minimize)
echo.

REM Start metrics collection in a minimized PowerShell window (suppress all output to avoid Unicode errors)
start /min powershell -WindowStyle Minimized -Command "& { cd '%~dp0' ; while ($true) { python monitor_windows.py 2>&1 | Out-Null ; Start-Sleep -Seconds 5 } }"

echo.
echo ================================================================
echo  SUCCESS! Solution 1 is running with YOUR device metrics
echo ================================================================
echo.
echo  Metrics Collection: Running in background (every 5 seconds)
echo  Dashboard URL:      http://localhost:8080
echo.
echo  Management Commands:
echo  --------------------
echo  View logs:       docker logs -f system-monitor-dashboard
echo  Stop dashboard:  docker-compose -f docker-compose-solution1.yml down
echo  Stop metrics:    Close the minimized PowerShell window
echo.
echo  Opening dashboard in browser...
timeout /t 2 >nul
start http://localhost:8080
echo.
pause
