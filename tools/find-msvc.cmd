@echo off
rem Usage: find-msvc.cmd MinimumVersion MaximumVersion
rem                      DesiredVersion
rem 
rem Given a range of versions to search for, this script attempts to locate a 
rem valid Visual Studio installation based upon the current set of environment 
rem variables. If a valid installation is found, this script sets the 
rem environment variable "VCROOT" to  Drive:\Path\To\VS\VC. On success, we 
rem should be able to call %VCROOT%\vcvarsall.bat.
rem
rem Versions use the VSXX0COMNTOOLS environment variable: (13 is replaced with 14)
rem 
rem     VS 2015 => 14
rem     VS 2013 => 12
rem     VS 2012 => 11
rem     VS 2010 => 10
rem     VS 2008 => 9
rem     VS 2005 => 8
rem 
rem Example
rem     call find-msvc.cmd 8 14
rem     if errorlevel 1 exit /B %ERRORLEVEL%
rem     call "%VCROOT%\vcvarsall.bat" x86
rem
rem or
rem     call find-msvc.cmd 14 8
rem     if errorlevel 1 exit /B %ERRORLEVEL%
rem     call "%VCROOT%\vcvarsall.bat" amd64
rem
rem or
rem     call find-msvc.cmd 10
rem     if errorlevel 1 exit /B %ERRORLEVEL%
rem     call "%VCROOT%\vcvarsall.bat" x86
rem
rem TODO: Add the ability to specify a preferred version. (A version to search
rem       for, even after the script discovered a working installation. if not
rem       found, the script will fall back onthe valid installation it did find)
setlocal

:forkcheck
rem Since this batch file executes self executes, it's important that we make
rem sure there's no chance of it repeating its previous logic, which would
rem result in an infinite recursively executing script. (fork bomb for lack
rem of a better term) This could've easily been handled with a simple "if 
rem defined" guard, but I felt like tracking the nesting level for shits and
rem giggles.
rem 
rem Since each nested invocation of the script will copy the previous
rem environment before localizing it, (line 27: setlocal) the value of 
rem CMD_FORK_LEVEL will steadily increment with each nesting level. When an
rem invocation has completd its execution of the script, it will return to
rem the previous nesting level, and revert back to the previous environment.
rem This will have the effect of CMD_FORK_LEVEL's value decrementing by one.
if not defined CMD_FORK_LEVEL (
	set /A CMD_FORK_LEVEL=1
) else (
	set /A CMD_FORK_LEVEL=%CMD_FORK_LEVEL% + 1
)
if %CMD_FORK_LEVEL% GTR 1 goto forked

:getopts
rem Figure out the minimum and maximum version numbers, as well as the
rem direction that we'll be searching in.
set _VC_STEP_VERSION_=1
if "%~1x"=="x" set _VC_MIN_VERSION_=8
if "%~2x"=="x" set _VC_MAX_VERSION_=14
if not defined _VC_MIN_VERSION_ set _VC_MIN_VERSION_=%~1
if not defined _VC_MAX_VERSION_ set _VC_MAX_VERSION_=%~2
if "%_VC_MIN_VERSION_%"=="13" set _VC_MIN_VERSION_=14
if "%_VC_MAX_VERSION_%"=="13" set _VC_MAX_VERSION_=14
if %_VC_MIN_VERSION_% GTR %_VC_MAX_VERSION_% set /A _VC_STEP_VERSION_=-1
goto main

:forked
if not "%VCVERS%x"=="x" goto forked_cleanup
call set "TESTVERS=%%VS%~10COMNTOOLS%%"
if "%TESTVERS%x"=="x" goto forked_cleanup
if not exist "%TESTVERS%" goto forked_cleanup
endlocal & set VCVERS=%~1
goto :EOF
:forked_cleanup
endlocal
goto :EOF

:dirname
rem Get the dirname of the second argument and set the variable who's
rem name was specified in the first argument.
call set %~1=%%~dp2
call set %~1=%%%~1:~0,-1%%
goto :EOF

:main
rem We'll start by finding the first existing install of msvc
set VCVERS=
set VCYEAR=
set VCROOT=
for /L %%V in (%_VC_MIN_VERSION_%,%_VC_STEP_VERSION_%,%_VC_MAX_VERSION_%) do @call "%~f0" %%~V
if "%VCVERS%x"=="x" goto notfound
endlocal & set VCVERS=%VCVERS%

:vcyear
rem Based on the version, we can figure out the year.
rem 14 => VS 2015
rem 12 => VS 2013
rem 11 => VS 2012
rem 10 => VS 2010
rem 9  => VS 2008
rem 8  => VS 2005
if "%VCVERS%"=="8"  set VCYEAR=2005
if "%VCVERS%"=="9"  set VCYEAR=2008
if "%VCVERS%"=="10" set VCYEAR=2010
if "%VCVERS%"=="11" set VCYEAR=2012
if "%VCVERS%"=="12" set VCYEAR=2013
if "%VCVERS%"=="13" set VCYEAR=2015
if "%VCVERS%"=="14" set VCYEAR=2015

:vcroot
rem Finally, let's determine the root folder for this VC installation.
call set VCROOT=%%VS%VCVERS%0COMNTOOLS%%
if "%VCROOT:~-1%"=="\" set VCROOT=%VCROOT:~0,-1%
rem VCROOT=VSDir\Common7\Tools
call :dirname VCROOT "%VCROOT%"
rem VCROOT=VSDir\Common7
call :dirname VCROOT "%VCROOT%"
rem VCROOT=VSDir
set VCROOT=%VCROOT%\VC
goto :EOF

:notfound
echo Could not locate a valid MSVC version.
endlocal
exit /B 1
