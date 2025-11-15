@echo off
REM Unified test script for students to test their sender implementation (Windows)
REM Usage: test_sender.bat <your_sender.py>

setlocal enabledelayedexpansion

REM Check if sender file is provided
if "%~1"=="" (
    echo [ERROR] No sender file specified
    echo Usage: test_sender.bat ^<your_sender.py^>
    echo Example: test_sender.bat my_tcp_tahoe.py
    exit /b 1
)

set SENDER_FILE=%~1

REM Check if sender file exists
if not exist "%SENDER_FILE%" (
    echo [ERROR] Sender file '%SENDER_FILE%' not found
    exit /b 1
)

echo ==========================================
echo ECS 152A - Testing Your Sender Implementation
echo ==========================================
echo [INFO] Sender file: %SENDER_FILE%

REM Pre-flight checks
echo.
echo ==========================================
echo Step 1/5: Pre-flight Checks
echo ==========================================

REM Check if Docker is installed
echo [INFO] Checking Docker installation...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop. See SETUP.md for instructions.
    exit /b 1
)
echo [SUCCESS] Docker is installed

REM Check if Docker daemon is running
echo [INFO] Checking if Docker daemon is running...
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker daemon is not running
    echo Please start Docker Desktop from the Start menu
    exit /b 1
)
echo [SUCCESS] Docker daemon is running

REM Check if container exists
echo [INFO] Checking if simulator container exists...
docker ps -a --format "{{.Names}}" | findstr /x "ecs152a-simulator" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Simulator container not found
    echo [INFO] Starting simulator for the first time...
    call start_sim.bat
    timeout /t 5 /nobreak >nul
) else (
    REM Container exists, check if it's running
    docker ps --format "{{.Names}}" | findstr /x "ecs152a-simulator" >nul 2>&1
    if errorlevel 1 (
        echo [WARNING] Simulator container exists but is not running
        echo [INFO] Starting simulator...
        docker start ecs152a-simulator >nul 2>&1
        timeout /t 3 /nobreak >nul
    ) else (
        echo [INFO] Simulator container is already running
    )
)

REM Restart receiver to reset state
echo.
echo ==========================================
echo Step 2/5: Preparing Test Environment
echo ==========================================
echo [INFO] Restarting receiver to reset state...
docker restart ecs152a-simulator >nul 2>&1
timeout /t 3 /nobreak >nul
echo [SUCCESS] Receiver restarted and ready

REM Copy sender file into container
echo [INFO] Copying your sender file into container...
docker cp "%SENDER_FILE%" ecs152a-simulator:/app/sender.py >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to copy sender file into container
    exit /b 1
)
echo [SUCCESS] Sender file copied

REM Ensure test file is in container
echo [INFO] Copying test file (file.mp3) into container...
if exist "file.mp3" (
    docker cp file.mp3 ecs152a-simulator:/hdd/ >nul 2>&1
) else if exist "hdd\file.mp3" (
    docker cp hdd\file.mp3 ecs152a-simulator:/hdd/ >nul 2>&1
) else (
    echo [ERROR] Test file (file.mp3) not found in docker\ or docker\hdd\
    exit /b 1
)
echo [SUCCESS] Test file ready

REM Remove old output file if exists
docker exec ecs152a-simulator rm -f /hdd/file2.mp3 >nul 2>&1

REM Run the sender
echo.
echo ==========================================
echo Step 3/3: Running Your Sender
echo ==========================================
echo [INFO] Executing your sender implementation...
echo.

REM Run sender and capture exit code
docker exec ecs152a-simulator python3 /app/sender.py 2>&1
set SENDER_EXIT_CODE=%errorlevel%
echo.

if not %SENDER_EXIT_CODE%==0 (
    echo [ERROR] Sender exited with error code %SENDER_EXIT_CODE%
    echo [WARNING] Check the output above for error messages
    exit /b 1
)

REM Display metrics info
echo.
echo ==========================================
echo Performance Metrics
echo ==========================================
echo [INFO] Check the output above for metrics (CSV format):
echo   throughput,delay,jitter,score
echo.
echo [SUCCESS] Test completed successfully!
echo.

endlocal
