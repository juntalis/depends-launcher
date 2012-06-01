@ECHO OFF
if not "%VCROOT%x"=="x" ((call "%VCROOT%\vcvarsall.bat" %TARGET_PLATFORM%>nul 2>nul) && (goto :EOF))
if not "%VS100COMNTOOLS%x"=="x" ((call "%VS100COMNTOOLS%\..\..\VC\vcvarsall.bat" %TARGET_PLATFORM%>nul 2>nul) && (goto :EOF))
if not "%VS90COMNTOOLS%x"=="x" ((call "%VS90COMNTOOLS%\..\..\VC\vcvarsall.bat" %TARGET_PLATFORM%>nul 2>nul) && (goto :EOF))
if not "%VS80COMNTOOLS%x"=="x" ((call "%VS80COMNTOOLS%\..\..\VC\vcvarsall.bat" %TARGET_PLATFORM%>nul 2>nul) && (goto :EOF))
echo ERROR: Could not detect vcvarsall.bat location.
echo.
echo Possible solution:
echo   Set VCROOT to the location of your VC directory.
echo.
echo Example:
echo   SET VCROOT=C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC
exit /B 1