@echo off
setlocal
goto main

:ensure_arch
if exist "%~dp0%~1\depends.exe" goto :EOF
echo Setting up %~1 Dependency Walker..
call "%~dp0tools\setup_depends.cmd" "%~dp0" %~1
if errorlevel 1 goto ensure_arch_error
goto :EOF
:ensure_arch_error
echo ERROR: Failed to download/unzip the %~1 Dependency Walker!
exit /B 1

:main
set /A FAILED_COUNT=0

call :ensure_arch x86
if errorlevel 1 set /A FAILED_COUNT=%FAILED_COUNT% + 1

call :ensure_arch amd64
if errorlevel 1 set /A FAILED_COUNT=%FAILED_COUNT% + 1

call :ensure_arch ia64
if errorlevel 1 set /A FAILED_COUNT=%FAILED_COUNT% + 1

if %FAILED_COUNT% GTR 0 goto failures
echo Successfully setup all 3 targeted versions of depends!
pause
goto :EOF

:failures
echo Failed setting up %FAILED_COUNT%/3 platforms.
pause
