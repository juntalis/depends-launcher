@ECHO OFF
if not exist "%~dp0..\obj" mkdir "%~dp0..\obj"
call "%~dp0platform.bat" %*
call "%~dp0vcenv.bat"
if "%~1"=="x86" shift /1
if "%~1"=="x64" shift /1
goto ProcessArgLoop
:ProcessArgLoop
if "%~1x"=="x" goto :EOF
set _TOOLCMDLINE=%_TOOLCMDLINE% "%~1"
shift /1
goto ProcessArgLoop