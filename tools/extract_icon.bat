@echo off
cscript //nologo //e:vbscript "%~dp0IconSiphon.vbs" %*
if ERRORLEVEL 1 exit /B %ERRORLEVEL%
if exist "%~dp0..\depends_129.ico" del /f /q "%~dp0..\depends_129.ico"
move /Y "%~dp0..\depends_128.ico" "%~dp0..\depends.ico">nul 2>nul