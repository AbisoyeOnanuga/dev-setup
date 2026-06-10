@echo off
REM cl.bat — routes MSVC cl.exe through sccache (finds cl via vswhere).
REM Installed to C:\tools\bin by MSVC-wrapper.ps1. Reference copy kept in repo.
REM Find latest Visual Studio installation path using vswhere
setlocal
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VSROOT=%%i
if "%VSROOT%"=="" (
  echo ERROR: vswhere did not find Visual Studio installation.
  exit /b 1
)
REM Adjust host/target path if needed; prefer x64 host
set REAL_CL="%VSROOT%\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe"
for /f "delims=" %%p in ('dir /b /s %REAL_CL% 2^>nul') do set REAL_CL_PATH=%%p
if "%REAL_CL_PATH%"=="" (
  echo ERROR: cl.exe not found under VS installation.
  exit /b 1
)
REM Run sccache with the real cl.exe
sccache "%REAL_CL_PATH%" %*
endlocal
