@echo off
rem FlushTools build for Windows. Run from a shell where `odin` is on PATH.
rem   build.bat         -> build\flushtools.dll + build\flushtools.lib
rem   build.bat test    -> run Odin unit tests
setlocal
if /I "%1"=="test" (
  odin test tests -vet -strict-style
  exit /b %ERRORLEVEL%
)
if not exist build mkdir build
odin build src -build-mode:dll -out:build\flushtools.dll -o:speed -vet -strict-style
exit /b %ERRORLEVEL%
