@echo off
setlocal
set "_BUILDLOG=%~dp0..\obj\%~n0.log"
set "_TOOLCMDLINE=%~n0.exe"
call "%~dp0tool.cmd" %*
if errorlevel 1 goto Error

call %_TOOLCMDLINE%>>"%_BUILDLOG%" 2>&1
if errorlevel 1 set _ERRCODE=%ERRORLEVEL% &goto Error

endlocal
goto :EOF

:Error
echo Error occurred running:
echo    %_TOOLCMDLINE%
if exist "%_BUILDLOG%" goto ErrorExec
echo.
echo Error: Could not located executable.
exit /B /1

:ErrorExec
echo.
type "%_BUILDLOG%"
exit /B %_ERRCODE%

