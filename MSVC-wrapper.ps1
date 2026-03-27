# Create wrapper folder
New-Item -ItemType Directory -Path "C:\tools\bin" -Force | Out-Null

# Wrapper batch file content
$wrapper = @'
@echo off
REM cl.bat wrapper to route MSVC cl.exe through sccache
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
'@

$wrapperPath = "C:\tools\bin\cl.bat"
Set-Content -Path $wrapperPath -Value $wrapper -Encoding ASCII
Write-Host "Created wrapper at $wrapperPath"

# Session helper to prepend tools folder to PATH
Write-Host "To use the wrapper for this session run:"
Write-Host '  $env:Path = "C:\tools\bin;$env:Path"'
Write-Host "Or add C:\tools\bin to your User PATH if you want it persistent."
