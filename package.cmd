@echo off
setlocal
goto main

:build
setlocal
pushd "%~dp0"
set "BUILD=%~dp0build.cmd"

if exist "%~dp0%~2.zip" del /F /Q "%~dp0%~2.zip">nul 2>nul

call "%BUILD%" clean
if errorlevel 1 exit /B %ERRORLEVEL%

call "%BUILD%" %~1
if errorlevel 1 exit /B %ERRORLEVEL%

call 7z a -tzip "%~dp0%~2.zip" depends.exe README.md setup.cmd tools -mx9 -mmt
if errorlevel 1 exit /B %ERRORLEVEL%

popd
endlocal
goto :EOF



:main
call :build x86 win32
if errorlevel 1 exit /B %ERRORLEVEL%

call :build x64 win64
if errorlevel 1 exit /B %ERRORLEVEL%
