@echo off
setlocal
rem Globals
set "OUTEXE=%~dp0depends.exe"
set CFLAGS=/nologo /W3 /WX- /O2 /Ob2 /Oi /Oy /GL /DWIN32 /D_NDEBUG /D_CRT_SECURE_NO_WARNINGS /GF /Gm- /MT /GS- /Gy /fp:precise /Zc:wchar_t /Zc:forScope /EHs-c-
set LDFLAGS=/nologo /OPT:REF /OPT:ICF /LTCG /LARGEADDRESSAWARE /SUBSYSTEM:WINDOWS
set "TOOLSDIR=%~dp0tools"
set "OBJDIR=%~dp0obj"
set TARGET_PLATFORM=
set BUILD_PLATFORM=
set BUILD_CMD=
goto ArgsLoop

:PrintUsage
rem build.cmd help
echo Usage: %0 [x86^|x64] [clean^|test]
echo.
echo x86^|x64     Platform to build depends-launcher for.
echo clean       Cleanup all files output during builds.
echo test        Build our test programs and run depends-launcher against them.
endlocal
exit /B 0

:SetupDepends
rem Download our necessary depends.exe files.

if not exist "%~dp0x86\depends.exe" ((echo Setting up x86 Dependency Walker..) && (call "%TOOLSDIR%\setup_depends.cmd" "%~dp0" x86))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0amd64\depends.exe" ((echo Setting up amd64 Dependency Walker..) && (call "%TOOLSDIR%\setup_depends.cmd" "%~dp0" amd64))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0ia64\depends.exe" ((echo Setting up ia64 Dependency Walker..) && (call "%TOOLSDIR%\setup_depends.cmd" "%~dp0" ia64))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0depends.ico" ((echo Extracting depends icon..) && (call "%TOOLSDIR%\extract_icon.bat" "%~dp0x86\depends.exe"))
if ERRORLEVEL 1 goto SilentError

goto :EOF

:SetupObj
rem Create our obj folder if it doesn't exist or clean obj files if it does.
if exist "%~dp0obj\*.obj" call del /F /Q "%~dp0obj\*.obj"
if exist "%~dp0obj\*.log" call del /F /Q "%~dp0obj\*.log"
if exist "%~dp0obj\*.log" call del /F /Q "%~dp0obj\*.res"
if exist "%~dp0obj" goto :EOF
echo Creating obj folder..
call mkdir "%~dp0obj"
if ERRORLEVEL 1 exit /B %ERRORLEVEL%
goto :EOF

:SetupInstall
echo Setting up registry files..
set "ESCAPED_EXE=%OUTEXE:\=\\%"

echo Windows Registry Editor Version 5.00>"%~dp0install.reg"
echo.>>"%~dp0install.reg"
echo [HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies]>>"%~dp0install.reg"
echo @="View &Dependencies">>"%~dp0install.reg"
echo.>>"%~dp0install.reg"
echo [HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies\command]>>"%~dp0install.reg"
echo @="\"%ESCAPED_EXE%\" \"^%1\" ^%*">>"%~dp0install.reg"

echo Windows Registry Editor Version 5.00>"%~dp0uninstall.reg"
echo.>>"%~dp0uninstall.reg"
echo [-HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies]>>"%~dp0uninstall.reg"
echo [-HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies\command]>>"%~dp0uninstall.reg"

goto :EOF

:Setup
rem Various setup tasks.
call :SetupObj
call :SetupDepends
if ERRORLEVEL 1 goto SilentError
echo.
call :SetupInstall
echo.
goto :EOF

:BuildTest
rem Build the test executable under a specified platform.
set _SUFFIX=
if "%~1"=="x86" set _SUFFIX=32
if "%~1"=="x64" set _SUFFIX=64

if exist "%OBJDIR%\noop%_SUFFIX%.obj" call del /F /Q %OBJDIR%\noop%_SUFFIX%.obj">nul 2>nul

call "%TOOLSDIR%\cl.cmd" %~1 /nologo /Ox /Os /c /MD "/Fo%OBJDIR%\noop%_SUFFIX%.obj" "%~dp0tests\noop.c"
if ERRORLEVEL 1 goto SilentError

call "%TOOLSDIR%\link.cmd" %~1 /nologo /SUBSYSTEM:CONSOLE /MACHINE:%~1 "/OUT:%~dp0tests\noop%_SUFFIX%.exe" "%OBJDIR%\noop%_SUFFIX%.obj" kernel32.lib
if ERRORLEVEL 1 goto SilentError
goto :EOF

:BuildTests
rem Build our test executables under both platforms.
echo Building x86 test executable..
call :BuildTest x86
if ERRORLEVEL 1 goto SilentError
echo.

echo Building x64 test executable..
call :BuildTest x64
if ERRORLEVEL 1 goto SilentError
echo.
goto :EOF

:BuildExe
set CL_CMD="%TOOLSDIR%\cl.cmd"
set RC_CMD="%TOOLSDIR%\rc.cmd"
set LINK_CMD="%TOOLSDIR%\link.cmd"

rem Ensure a build platform is set
if defined BUILD_PLATFORM goto BuildExe_Build
set "PARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "PARCH=%PROCESSOR_ARCHITEW6432%"
if /i "%PARCH%"=="IA64" set BUILD_PLATFORM=ia64 & goto BuildExe_Build
if /i "%PARCH%"=="x86" set BUILD_PLATFORM=x86 & goto BuildExe_Build
if "%PARCH:~-2%"=="64" set BUILD_PLATFORM=x64 & goto BuildExe_Build
set ERRMSG=Unknown processor architecture detected: %PARCH%!
goto ErrorMessage

:BuildExe_Build
set CL_CMD=%CL_CMD% %BUILD_PLATFORM%
set RC_CMD=%RC_CMD% %BUILD_PLATFORM%
set LINK_CMD=%LINK_CMD% %BUILD_PLATFORM% /MACHINE:%BUILD_PLATFORM%
if "%BUILD_PLATFORM%"=="x86" set "CFLAGS=%CFLAGS% /arch:SSE2"

call %CL_CMD% %CFLAGS% /c "/Fo%OBJDIR%\depends-launcher.obj" "%~dp0depends-launcher.c"
if ERRORLEVEL 1 goto SilentError

call %RC_CMD% /nologo "/fo%OBJDIR%\depends-launcher.res" "%~dp0depends-launcher.rc"
if ERRORLEVEL 1 goto SilentError

call %LINK_CMD% %LDFLAGS% "/OUT:%OUTEXE%" "%OBJDIR%\depends-launcher.obj" "%OBJDIR%\depends-launcher.res"
if ERRORLEVEL 1 goto SilentError

goto :EOF

:HandleVar
rem Set our platform
if defined %~1 set "ERRMSG=You can only specify one %~1." & goto ErrorMessage
call set "%~1=%~2"
set HANDLED=1
goto :EOF

:BuildCmd
rem Build our program.
echo Starting build..
call :Setup
if ERRORLEVEL 1 goto SilentError

call :BuildExe
if ERRORLEVEL 1 goto SilentError
goto :EOF

:CleanCmd
rem When clean is specified
echo Running clean..
if exist "%OUTEXE%" call del /F /Q "%OUTEXE%">nul 2>nul
if exist "%OBJDIR%" call rmdir /S /Q "%OBJDIR%">nul 2>nul
if exist "%~dp0*.ico" call del /F /Q "%~dp0*.ico">nul 2>nul
if exist "%~dp0*.reg" call del /F /Q "%~dp0*.reg">nul 2>nul
if exist "%~dp0tests\*.exe" call del /F /Q "%~dp0tests\*.exe">nul 2>nul
endlocal
goto :EOF

:TestCmd
rem When test is specified
call :Setup
if ERRORLEVEL 1 goto SilentError

if not exist "%OUTEXE%" call :BuildExe
if ERRORLEVEL 1 goto SilentError

call :BuildTests
if ERRORLEVEL 1 goto SilentError

echo Running tests..
"%OUTEXE%" "%~dp0tests\noop32.exe" "%~dp0tests\noop64.exe"
if ERRORLEVEL 1 ((set "ERRMSG=Error occurred while attempting to run depends-launcher.exe against our tests.") && (goto ErrorMessage))

endlocal
goto :EOF

:ArgsLoop
rem Process cmd line arguments
set HANDLED=
if "%~1x"=="x" goto ArgsDone
if "%~1"=="help" goto PrintUsage

if "%~1"=="x86" call :HandleVar BUILD_PLATFORM x86
if ERRORLEVEL 1 goto SilentError

if "%~1"=="x64" call :HandleVar BUILD_PLATFORM x64
if ERRORLEVEL 1 goto SilentError

if "%~1"=="clean" call :HandleVar BUILD_CMD CleanCmd
if ERRORLEVEL 1 goto SilentError

if "%~1"=="test" call :HandleVar BUILD_CMD TestCmd
if ERRORLEVEL 1 goto SilentError

if not defined HANDLED ((set "ERRMSG=Unknown argument specified: %~1") && (goto ErrorMessage))

shift /1
goto ArgsLoop

:ArgsDone
rem Argument processing is done. Time for the actual work.
if not defined BUILD_CMD set BUILD_CMD=BuildCmd
goto %BUILD_CMD%
endlocal
goto :EOF

:ErrorMessage
rem Exit with an error message.
echo ERROR: %ERRMSG%
endlocal
exit /B 1

:SilentError
rem Exit silently with an error.
endlocal
exit /B %ERRORLEVEL%
