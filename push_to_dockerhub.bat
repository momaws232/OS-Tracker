@echo off
REM ============================================================================
REM Push System Monitor Images to Docker Hub
REM One-time setup script to build and push images
REM ============================================================================

echo.
echo ================================================================
echo  Docker Hub Image Publisher
echo ================================================================
echo.

REM Prompt for Docker Hub username
set /p DOCKERHUB_USERNAME="Enter your Docker Hub username: "

if "%DOCKERHUB_USERNAME%"=="" (
    echo [ERROR] Username cannot be empty!
    pause
    exit /b 1
)

echo.
echo Using Docker Hub username: %DOCKERHUB_USERNAME%
echo.

REM Login to Docker Hub
echo [1/5] Logging into Docker Hub...
echo Please enter your Docker Hub password when prompted:
docker login -u %DOCKERHUB_USERNAME%
if %errorLevel% neq 0 (
    echo [ERROR] Docker Hub login failed!
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  IMPORTANT: Create Docker Hub Repositories First!
echo ================================================================
echo.
echo Before pushing, you need to create 2 repositories on Docker Hub:
echo.
echo 1. Go to: https://hub.docker.com/repository/create
echo 2. Create repository: system-monitor-dashboard (Public)
echo 3. Create repository: system-monitor-bash (Public)
echo.
echo Press any key once you've created both repositories...
pause >nul

echo.
echo [2/5] Building dashboard image...
cd system-monitor
docker build -f docker/Dockerfile.dashboard -t %DOCKERHUB_USERNAME%/system-monitor-dashboard:latest .
if %errorLevel% neq 0 (
    echo [ERROR] Failed to build dashboard image!
    pause
    exit /b 1
)

echo.
echo [3/5] Building bash monitor image...
docker build -f docker/Dockerfile.bash-monitor -t %DOCKERHUB_USERNAME%/system-monitor-bash:latest .
if %errorLevel% neq 0 (
    echo [ERROR] Failed to build bash monitor image!
    pause
    exit /b 1
)

echo.
echo [4/5] Pushing dashboard image to Docker Hub...
docker push %DOCKERHUB_USERNAME%/system-monitor-dashboard:latest
if %errorLevel% neq 0 (
    echo [ERROR] Failed to push dashboard image!
    pause
    exit /b 1
)

echo.
echo [5/5] Pushing bash monitor image to Docker Hub...
docker push %DOCKERHUB_USERNAME%/system-monitor-bash:latest
if %errorLevel% neq 0 (
    echo [ERROR] Failed to push bash monitor image!
    pause
    exit /b 1
)

cd ..

echo.
echo ================================================================
echo  SUCCESS! Images pushed to Docker Hub
echo ================================================================
echo.
echo  Your images are now available at:
echo  - https://hub.docker.com/r/%DOCKERHUB_USERNAME%/system-monitor-dashboard
echo  - https://hub.docker.com/r/%DOCKERHUB_USERNAME%/system-monitor-bash
echo.
echo  Next steps:
echo  1. Update docker-compose files with your username
echo  2. Run quick_start.bat to pull and run images
echo.

REM Save username to config file for future use
echo %DOCKERHUB_USERNAME% > dockerhub_username.txt
echo Username saved to dockerhub_username.txt for future reference
echo.

pause
