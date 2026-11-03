@echo off
setlocal
set "ROOT=%~dp0..\.."
if not exist "%ROOT%\build\flushtools.dll" (
  echo Build FlushTools first with build.bat from the repository root.
  exit /b 1
)
if not exist "%ROOT%\build\c_example" mkdir "%ROOT%\build\c_example"
cl /nologo /W4 /I"%ROOT%\include" "%~dp0main.c" "%ROOT%\build\flushtools.lib" /Fe:"%ROOT%\build\c_example\c_example.exe"
if errorlevel 1 exit /b 1
set "PATH=%ROOT%\build;%PATH%"
"%ROOT%\build\c_example\c_example.exe"
exit /b %ERRORLEVEL%
