@echo off

if defined INCLUDE goto :EOF

call "%~dp0find-msvc.cmd" 14 8
if errorlevel 1 goto Error

echo Setting up VC environment for compiling:  %TARGET_PLATFORM%
call "%VCROOT%\vcvarsall.bat" %TARGET_PLATFORM%
if errorlevel 1 goto ErrorExec

goto :EOF

:Error
echo ERROR: Could not detect vcvarsall.bat location.
echo.
echo Possible solution:
echo   Set VCROOT to the location of your VC directory.
echo.
echo Example:
echo   SET VCROOT=C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC
exit /B 1
:ErrorExec
echo ERROR: Failed running the following:
echo.
echo   "%VCROOT%\vcvarsall.bat" %TARGET_PLATFORM%