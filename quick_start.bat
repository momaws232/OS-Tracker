@echo off
REM ============================================================================
REM Quick Start - System Monitor
REM Downloads the project and runs it automatically
REM ============================================================================

echo.
echo ================================================================
echo  System Monitor - Quick Start Installer
echo ================================================================
echo.

echo [1/5] Checking prerequisites...

REM Check if Git is installed
git --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Git is not installed!
    echo Please download from: https://git-scm.com/downloads
    pause
    exit /b 1
)

REM Check if Python is installed
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Python is not installed!
    echo Please download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Check if Docker is running
docker ps >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Docker is not running!
    echo Please start Docker Desktop
    pause
    exit /b 1
)

echo All prerequisites found!

echo.
echo [2/5] Downloading project from GitHub...
if exist "system-monitor" (
    echo Removing old installation...
    rmdir /s /q system-monitor
)

git clone -b main https://github.com/Asserali/os-rep.git system-monitor
if %errorLevel% neq 0 (
    echo [ERROR] Failed to download project
    pause
    exit /b 1
)

cd system-monitor

echo.
echo [3/5] Installing Python dependencies...
pip install psutil wmi
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [4/5] Building Docker image...
docker-compose -f docker-compose-solution1.yml build
if %errorLevel% neq 0 (
    echo [ERROR] Failed to build Docker image
    pause
    exit /b 1
)

echo.
echo [5/5] Starting the monitor...
call run_solution1.bat
