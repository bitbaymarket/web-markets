@echo off
setlocal

echo ===========================================================
echo   Local AI Moderation Server - Launcher
echo ===========================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "AI_DIR=%SCRIPT_DIR%ai-model"
set "VENV_DIR=%AI_DIR%\venv"

:: Check if venv exists
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo ERROR: Virtual environment not found at %VENV_DIR%
    echo Please run install.bat first.
    pause
    exit /b 1
)

:: Check if model exists
if not exist "%AI_DIR%\model" (
    echo ERROR: Model not found at %AI_DIR%\model
    echo Please run install.bat first.
    pause
    exit /b 1
)

:: Activate venv and run server
call "%VENV_DIR%\Scripts\activate.bat"
echo Starting local moderation server on port 10000...
echo.
python "%SCRIPT_DIR%local_model_server.py"

pause
