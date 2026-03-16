@echo off
setlocal enabledelayedexpansion

echo ===========================================================
echo   Local AI Moderation - Qwen3-VL Installer
echo ===========================================================
echo.

:: Determine install directory relative to where this script lives
set "SCRIPT_DIR=%~dp0"
set "AI_DIR=%SCRIPT_DIR%ai-model"

echo All files will be installed to: %AI_DIR%
echo.

:: Ask user which model to install
echo Which Qwen3-VL model would you like to install?
echo   1) Qwen3-VL-2B-Instruct  (smallest,  ~4GB VRAM)
echo   2) Qwen3-VL-4B-Instruct  (small,     ~8GB VRAM)
echo   3) Qwen3-VL-8B-Instruct  (medium,   ~16GB VRAM, better accuracy)
echo   4) Qwen3-VL-32B-Instruct (large,    ~64GB VRAM, best accuracy)
echo.
set /p MODEL_CHOICE="Enter 1, 2, 3, or 4: "

if "%MODEL_CHOICE%"=="1" (
    set "MODEL_NAME=Qwen/Qwen3-VL-2B-Instruct"
    echo Selected: Qwen3-VL-2B-Instruct
) else if "%MODEL_CHOICE%"=="2" (
    set "MODEL_NAME=Qwen/Qwen3-VL-4B-Instruct"
    echo Selected: Qwen3-VL-4B-Instruct
) else if "%MODEL_CHOICE%"=="3" (
    set "MODEL_NAME=Qwen/Qwen3-VL-8B-Instruct"
    echo Selected: Qwen3-VL-8B-Instruct
) else if "%MODEL_CHOICE%"=="4" (
    set "MODEL_NAME=Qwen/Qwen3-VL-32B-Instruct"
    echo Selected: Qwen3-VL-32B-Instruct
) else (
    echo Invalid choice. Please enter 1, 2, 3, or 4.
    pause
    exit /b 1
)
echo.

:: Create ai-model directory
if not exist "%AI_DIR%" mkdir "%AI_DIR%"

:: ---- Install pyenv-win locally ----
set "PYENV_ROOT=%AI_DIR%\.pyenv"
set "PYENV=%PYENV_ROOT%\pyenv-win"
set "PATH=%PYENV%\bin;%PYENV%\shims;%PATH%"
set "PYENV_HOME=%PYENV%"

if not exist "%PYENV%\bin\pyenv.bat" (
    echo Installing pyenv-win locally...
    if not exist "%PYENV_ROOT%" mkdir "%PYENV_ROOT%"
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/pyenv-win/pyenv-win/archive/refs/heads/master.zip' -OutFile '%AI_DIR%\pyenv-win.zip'"
    if errorlevel 1 (
        echo ERROR: Failed to download pyenv-win.
        pause
        exit /b 1
    )
    powershell -Command "Expand-Archive -Path '%AI_DIR%\pyenv-win.zip' -DestinationPath '%PYENV_ROOT%\temp' -Force"
    if errorlevel 1 (
        echo ERROR: Failed to extract pyenv-win.
        pause
        exit /b 1
    )
    :: Move contents from extracted folder
    xcopy /E /Y /Q "%PYENV_ROOT%\temp\pyenv-win-master\*" "%PYENV_ROOT%\" >nul
    rd /S /Q "%PYENV_ROOT%\temp" 2>nul
    del "%AI_DIR%\pyenv-win.zip" 2>nul
    echo pyenv-win installed to %PYENV_ROOT%
) else (
    echo pyenv-win already installed.
)
echo.

:: ---- Install Python 3.11 via pyenv ----
set "PYTHON_VERSION=3.11.9"
echo Installing Python %PYTHON_VERSION% via pyenv (localized)...

call "%PYENV%\bin\pyenv.bat" install %PYTHON_VERSION% --skip-existing
if errorlevel 1 (
    echo ERROR: Failed to install Python %PYTHON_VERSION%.
    pause
    exit /b 1
)

call "%PYENV%\bin\pyenv.bat" local %PYTHON_VERSION%
echo Python %PYTHON_VERSION% installed.
echo.

:: Get the path to the installed Python
for /f "tokens=*" %%i in ('call "%PYENV%\bin\pyenv.bat" which python') do set "PYENV_PYTHON=%%i"

:: ---- Create virtual environment ----
set "VENV_DIR=%AI_DIR%\venv"
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo Creating virtual environment...
    "%PYENV_PYTHON%" -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo Virtual environment created.
) else (
    echo Virtual environment already exists.
)
echo.

:: ---- Activate venv and install dependencies ----
call "%VENV_DIR%\Scripts\activate.bat"

echo Upgrading pip...
python -m pip install --upgrade pip

echo.
echo Installing PyTorch...
:: Check for NVIDIA GPU
nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo No NVIDIA GPU detected. Installing CPU-only PyTorch...
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
) else (
    echo NVIDIA GPU detected. Installing CUDA-enabled PyTorch...
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
)

echo.
echo Installing other dependencies...
pip install "transformers>=4.57.0" accelerate Pillow

echo.
echo Downloading model: %MODEL_NAME%
echo This may take a while depending on your internet connection...

python "%SCRIPT_DIR%download_model.py" "%MODEL_NAME%" "%AI_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to download the model.
    echo If you need authentication, run: pip install huggingface_hub ^&^& huggingface-cli login
    pause
    exit /b 1
)

echo.
echo ===========================================================
echo   Installation complete!
echo ===========================================================
echo.
echo Model installed to: %AI_DIR%\model
echo.
echo To start the local moderation server, run: run.bat
echo Then set sightengineApiUser to "local" in config.js
echo.
pause
