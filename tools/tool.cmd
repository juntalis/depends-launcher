@echo off
set TOOL_NAME=
set _TESTLEVEL=
set _TESTCMDLINE=%_TOOLCMDLINE%

if not exist "%~dp0..\obj" mkdir "%~dp0..\obj"

call "%~dp0platform.cmd" %*
if errorlevel 1 exit /B %ERRORLEVEL%

call "%~dp0vcenv.cmd"
if errorlevel 1 exit /B %ERRORLEVEL%

if "%~1"=="x86" shift /1
if "%~1"=="x64" shift /1
if "%~1"=="ia64" shift /1

if /i "%_TOOLCMDLINE%"=="rc.exe" goto SetupRC
if /i "%_TOOLCMDLINE%"=="link.exe" goto SetupLink

:SetupCL
set TOOL_NAME=Compiler
goto TestTool

:SetupRC
set TOOL_NAME=Resource Compiler
set "_TESTCMDLINE=%_TOOLCMDLINE% /?"
goto TestTool

:SetupLink
set TOOL_NAME=Linker
set _TESTLEVEL=1100
set "_TESTCMDLINE=%_TOOLCMDLINE% missing.obj"

:TestTool
call %_TESTCMDLINE%>nul 2>nul
if defined _TESTLEVEL if errorlevel %_TESTLEVEL% call verify>nul 2>nul
if errorlevel 1 exit /B %ERRORLEVEL%

:ProcessArgLoop
if "%~1x"=="x" goto FinishArgsLoop
set _TOOLCMDLINE=%_TOOLCMDLINE% "%~1"
shift /1

goto ProcessArgLoop

:FinishArgsLoop
echo %TOOL_NAME% Target: %TARGET_PLATFORM%
