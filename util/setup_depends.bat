@echo off
setlocal
rem Starting variables.
set _URL=
set _ROOTDIR=%~dp0..\

rem Make sure prefix was specified.
set _PREFIX=%1
if "%_PREFIX%x"=="x" ((set "ERRMSG=No platform specified.") && (goto ErrorMsg))

rem Set our output files/folders.
set _OBJFILE=%_ROOTDIR%obj\%_PREFIX%.zip
set _OUTDIR=%_ROOTDIR%%_PREFIX%

rem Figure out url to use
if "%_PREFIX%"=="x86" set _URL=http://www.dependencywalker.com/depends22_x86.zip
if "%_PREFIX%"=="amd64" set _URL=http://www.dependencywalker.com/depends22_x64.zip
if "%_PREFIX%"=="ia64" set _URL=http://www.dependencywalker.com/depends22_ia64.zip
if "%_URL%x"=="x" ((set "ERRMSG=Could not figure out the url to download.") && (goto ErrorMsg))

rem Download our file.
call "%~dp0wget.bat" "%_URL%" "%_OBJFILE%"
if ERRORLEVEL 1 ((set "ERRMSG=An error occurred while downloading %_URL%..") && (goto ErrorMsg))

rem Unzip our file
call "%~dp0unzip.bat" "%_OBJFILE%" "%_OUTDIR%"
if ERRORLEVEL 1 ((set "ERRMSG=An error occurred while unzipping %_OBJFILE%..") && (goto ErrorMsg))

rem Delete the .zip file we downloaded
del /f /q "%_OBJFILE%"

endlocal
goto :EOF
:ErrorMsg
echo ERROR: %ERRMSG%
endlocal
EXIT /B 1
