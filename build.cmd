@echo off
setlocal
:: Globals
set OUTEXE=%~dp0depends.exe
set CFLAGS=/nologo /W3 /WX- /O2 /Ob2 /Oi /Oy /GL /DWIN32 /D_NDEBUG /D_CRT_SECURE_NO_WARNINGS /GF /Gm- /MD /GS- /Gy /fp:precise /Zc:wchar_t /Zc:forScope
set LDFLAGS=/nologo /OPT:REF /OPT:ICF /LTCG
set TOOLSDIR=%~dp0tools\
set OBJDIR=%~dp0obj\
set BUILD_PLATFORM=
set BUILD_CMD=
goto ArgsLoop

:PrintUsage
:: build.bat help
echo Usage: %0 [x86^|x64] [clean^|test]
echo.
echo x86^|x64     Platform to build depends-launcher for.
echo clean       Cleanup all files output during builds.
echo test        Build our test programs and run depends-launcher against them.
endlocal
exit /B 0

:SetupDepends
:: Download our necessary depends.exe files.

if not exist "%~dp0x86\depends.exe" ((echo Setting up x86 Dependency Walker..) && (call "%TOOLSDIR%setup_depends.bat" x86))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0x64\depends.exe" ((echo Setting up amd64 Dependency Walker..) && (call "%TOOLSDIR%setup_depends.bat" amd64))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0x64\depends.exe" ((echo Setting up ia64 Dependency Walker..) && (call "%TOOLSDIR%setup_depends.bat" ia64))
if ERRORLEVEL 1 goto SilentError

if not exist "%~dp0depends.ico" ((echo Extracting depends icon..) && (call "%TOOLSDIR%extract_icon.bat" "%~dp0x86\depends.exe"))
if ERRORLEVEL 1 goto SilentError

goto :EOF

:SetupObj
:: Create our obj folder if it doesn't exist.
if not exist "%~dp0obj" ((echo Making obj folder..) && (mkdir "%~dp0obj"))
goto :EOF

:SetupInstall
echo Setting up registry files..
set ESCAPED_EXE=%OUTEXE:\=\\%

echo Windows Registry Editor Version 5.00>"%~dp0install.reg"
echo.>>"%~dp0install.reg"
echo [HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies]>>"%~dp0install.reg"
echo @="View &Dependencies">>"%~dp0install.reg"
echo.>>"%~dp0install.reg"
echo [HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies\command]>>"%~dp0install.reg"
echo @="\"%ESCAPED_EXE%\" \"%%1\" %%*">>"%~dp0install.reg"

echo Windows Registry Editor Version 5.00>"%~dp0uninstall.reg"
echo.>>"%~dp0uninstall.reg"
echo [-HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies]>>"%~dp0uninstall.reg"
echo [-HKEY_CLASSES_ROOT\exefile\shell\ViewDependencies\command]>>"%~dp0uninstall.reg"

goto :EOF

:Setup
:: Various setup tasks.
call :SetupObj
call :SetupDepends
if ERRORLEVEL 1 goto SilentError
echo.
call :SetupInstall
echo.
goto :EOF

:BuildTest
:: Build the test executable under a specified platform.
set _SUFFIX=
if "%~1"=="x86" set _SUFFIX=32
if "%~1"=="x64" set _SUFFIX=64
call "%TOOLSDIR%cl.bat" %~1 /nologo /Ox /Os /c /MD "/Fo%OBJDIR%noop%_SUFFIX%.obj" "%~dp0tests\noop.c"
if ERRORLEVEL 1 goto SilentError
call "%TOOLSDIR%link.bat" %~1 /nologo /SUBSYSTEM:CONSOLE /MACHINE:%~1 "/OUT:%~dp0tests\noop%_SUFFIX%.exe" "%OBJDIR%noop%_SUFFIX%.obj" kernel32.lib
if ERRORLEVEL 1 goto SilentError
goto :EOF

:BuildTests
:: Build our test executables under both platforms.
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
set CL_CMD="%TOOLSDIR%cl.bat"
set LINK_CMD="%TOOLSDIR%link.bat"
set RC_CMD="%TOOLSDIR%rc.bat"
if "%BUILD_PLATFORM%x"=="x" if "%PROCESSOR_ARCHITECTURE%"=="X86" if not defined PROCESSOR_ARCHITEW6432 set BUILD_PLATFORM=x86
if "%BUILD_PLATFORM%x"=="x" if "%PROCESSOR_ARCHITECTURE%"=="IA64" set BUILD_PLATFORM=x64
if "%BUILD_PLATFORM%x"=="x" if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set BUILD_PLATFORM=x64
if "%BUILD_PLATFORM%x"=="x" if "%PROCESSOR_ARCHITEW6432%"=="IA64" set BUILD_PLATFORM=x64
if "%BUILD_PLATFORM%x"=="x" if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set BUILD_PLATFORM=x64
if not "%BUILD_PLATFORM%x"=="x" ((set CL_CMD=%CL_CMD% %BUILD_PLATFORM%) && (set "LINK_CMD=%LINK_CMD% %BUILD_PLATFORM% /MACHINE:%BUILD_PLATFORM%") && (set "RC_CMD=%RC_CMD% %BUILD_PLATFORM%"))

if "%BUILD_PLATFORM%"=="x86" set CFLAGS=%CFLAGS% /arch:SSE2

call %CL_CMD% %CFLAGS% /c "/Fo%OBJDIR%depends-launcher.obj" "%~dp0depends-launcher.c"
if ERRORLEVEL 1 goto SilentError

call %RC_CMD% /nologo "/fo%OBJDIR%depends-launcher.res" "%~dp0depends-launcher.rc"
if ERRORLEVEL 1 goto SilentError

call %LINK_CMD% %LDFLAGS% "/OUT:%OUTEXE%" "%OBJDIR%depends-launcher.obj" "%OBJDIR%depends-launcher.res"
if ERRORLEVEL 1 goto SilentError

goto :EOF

:SetPlatform
:: Set our platform
if not "%BUILD_PLATFORM%x"=="x" ((set "ERRMSG=You can only specify one platform.") && (goto ErrorMessage))
set BUILD_PLATFORM=%1
set HANDLED=1
goto :EOF

:SetCmd
:: Set our build command.
if not "%BUILD_CMD%x"=="x" ((set "ERRMSG=You cannot specify test and clean at the same time.") && (goto ErrorMessage))
set BUILD_CMD=%1
set HANDLED=1
goto :EOF

:BuildCmd
:: Build our program.
echo Starting build..
call :Setup
if ERRORLEVEL 1 goto SilentError

call :BuildExe
if ERRORLEVEL 1 goto SilentError
goto :EOF

:CleanCmd
:: When clean is specified
echo Running clean..
if exist "%OBJDIR%" rmdir /S /Q "%OBJDIR%"
if exist "%~dp0tests\*.exe" del /f /q "%~dp0tests\*.exe"
if exist "%OUTEXE%" del /f /q "%OUTEXE%"
if exist "%~dp0*.ico" del /f /q "%~dp0*.ico"
if exist "%~dp0*.reg" del /f /q "%~dp0*.reg"
endlocal
goto :EOF

:TestCmd
:: When test is specified
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
:: Process cmd line arguments
if "%~1x"=="x" goto ArgsDone
set HANDLED=0
if "%~1"=="help" goto PrintUsage

if "%~1"=="x86" call :SetPlatform x86
if ERRORLEVEL 1 goto SilentError

if "%~1"=="x64" call :SetPlatform x64
if ERRORLEVEL 1 goto SilentError

if "%~1"=="clean" call :SetCmd clean
if ERRORLEVEL 1 goto SilentError

if "%~1"=="test" call :SetCmd test
if ERRORLEVEL 1 goto SilentError

if not "%HANDLED%"=="1"  ((set "ERRMSG=Unknown argument specified: %1") && (goto ErrorMessage))

shift /1
goto ArgsLoop

:ArgsDone
:: Argument processing is done. Time for the actual work.
if "%BUILD_CMD%"=="clean" goto CleanCmd
if "%BUILD_CMD%"=="test" goto TestCmd
call :BuildCmd
endlocal
goto :EOF

:ErrorMessage
:: Exit with an error message.
echo ERROR: %ERRMSG%
endlocal
exit /B 1

:SilentError
:: Exit silently with an error.
endlocal
exit /B %ERRORLEVEL%
