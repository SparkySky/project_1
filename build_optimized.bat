@echo off
REM Optimized Build Script for MYSafeZone
REM This script builds the smallest possible APK/AAB

echo ======================================
echo MYSafeZone Optimized Build Script
echo ======================================
echo.

REM Clean previous builds
echo [1/5] Cleaning previous builds...
call flutter clean
if errorlevel 1 goto :error

REM Get dependencies
echo.
echo [2/5] Getting dependencies...
call flutter pub get
if errorlevel 1 goto :error

REM Analyze APK size (optional)
echo.
echo [3/5] Would you like to analyze current APK size? (y/n)
set /p analyze="Enter choice: "
if /i "%analyze%"=="y" (
    echo Analyzing APK size...
    call flutter build apk --analyze-size --target-platform android-arm64
)

REM Choose build type
echo.
echo [4/5] Choose build type:
echo 1. APK (Split by density - recommended for direct install)
echo 2. App Bundle (Smallest size - recommended for Play Store)
echo 3. Single APK (Largest size - for testing)
set /p choice="Enter choice (1-3): "

if "%choice%"=="1" goto :build_apk_split
if "%choice%"=="2" goto :build_bundle
if "%choice%"=="3" goto :build_apk_single

:build_apk_split
echo.
echo Building optimized split APKs...
call flutter build apk --release --split-per-abi --tree-shake-icons --target-platform android-arm64
if errorlevel 1 goto :error
goto :success

:build_bundle
echo.
echo Building optimized App Bundle...
call flutter build appbundle --release --tree-shake-icons --target-platform android-arm64
if errorlevel 1 goto :error
goto :success

:build_apk_single
echo.
echo Building single APK...
call flutter build apk --release --tree-shake-icons --target-platform android-arm64
if errorlevel 1 goto :error
goto :success

:success
echo.
echo ======================================
echo [5/5] Build completed successfully!
echo ======================================
echo.
echo Output location:
if "%choice%"=="2" (
    echo build\app\outputs\bundle\release\
) else (
    echo build\app\outputs\apk\release\
)
echo.
echo Size optimization tips applied:
echo - ProGuard/R8 minification enabled
echo - Resource shrinking enabled
echo - Icon tree shaking enabled
echo - Split by screen density ^(if selected^)
echo - Single ABI ^(arm64-v8a only^)
echo.
pause
exit /b 0

:error
echo.
echo ======================================
echo Build failed! Check errors above.
echo ======================================
echo.
pause
exit /b 1

