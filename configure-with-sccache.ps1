<#
.SYNOPSIS
  Configure a CMake project to use sccache + Ninja and optionally build it.

.DESCRIPTION
  - Verifies sccache, clang/clang++, cmake, and ninja are available.
  - Sets CC/CXX to "sccache clang" / "sccache clang++".
  - Runs cmake configure with Ninja and exports compile_commands.json.
  - Optionally runs the build and prints sccache stats.

.PARAMETER Build
  If $true, runs the build after configure. Default: $true.

.PARAMETER BuildDir
  Relative or absolute path for the build directory. Default: "build".

.PARAMETER Generator
  CMake generator to use. Default: "Ninja".

.PARAMETER BuildType
  CMake build type. Default: "RelWithDebInfo".

.PARAMETER Jobs
  Parallel jobs for the build. Default: 12.

.EXAMPLE
  .\configure-with-sccache.ps1 -Build $true -Jobs 8
#>

param(
  [bool]$Build = $true,
  [string]$BuildDir = "build",
  [string]$Generator = "Ninja",
  [string]$BuildType = "RelWithDebInfo",
  [int]$Jobs = 12
)

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  exit 1
}

Write-Host "=== sccache + CMake helper ===" -ForegroundColor Cyan

# 1) Basic checks
$tools = @{
  "sccache" = "sccache --version";
  "clang"   = "clang --version";
  "clang++" = "clang++ --version";
  "cmake"   = "cmake --version";
  "ninja"   = "ninja --version";
}

foreach ($t in $tools.Keys) {
  try {
    & cmd /c $tools[$t] > $null 2>&1
  } catch {
    Write-Host "Missing or not on PATH: $t" -ForegroundColor Yellow
    $missing += $t
  }
}

if ($missing) {
  Write-Host "One or more required tools are missing: $($missing -join ', ')" -ForegroundColor Yellow
  Write-Host "Install them or add to PATH, then re-run this script." -ForegroundColor Yellow
  Fail "Prerequisites not satisfied."
}

# 2) Ensure we are in a project folder with CMakeLists.txt
if (-not (Test-Path "./CMakeLists.txt")) {
  Write-Host "No CMakeLists.txt found in current directory: $(Get-Location)" -ForegroundColor Yellow
  Write-Host "Change directory to your project root (where CMakeLists.txt will live) and re-run." -ForegroundColor Yellow
  Fail "CMakeLists.txt missing."
}

# 3) Prepare build directory
$absBuildDir = Resolve-Path -LiteralPath $BuildDir -ErrorAction SilentlyContinue
if (-not $absBuildDir) {
  New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
  $absBuildDir = Resolve-Path -LiteralPath $BuildDir
}
Write-Host "Using build directory:" $absBuildDir

# 4) Set sccache wrappers for this session
# Use sccache clang/clang++ for LLVM toolchain. For MSVC, see notes below.
$env:CC  = "sccache clang"
$env:CXX = "sccache clang++"
Write-Host "Set CC and CXX to sccache wrappers for this session."

# 5) Run CMake configure
$cmakeArgs = @(
  "-S", ".",
  "-B", $absBuildDir,
  "-G", $Generator,
  "-DCMAKE_BUILD_TYPE=$BuildType",
  "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
)
Write-Host "Running cmake configure..."
$cmakeCmd = "cmake " + ($cmakeArgs -join " ")
Write-Host $cmakeCmd
$cfg = & cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
  Write-Host "CMake configure failed." -ForegroundColor Red
  Fail "CMake configure error."
}

# 6) Optionally build
if ($Build) {
  Write-Host "Building with $Jobs parallel jobs..."
  $buildCmd = "cmake --build $absBuildDir -- -j $Jobs"
  Write-Host $buildCmd
  & cmake --build $absBuildDir -- -j $Jobs
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    Fail "Build error."
  }
}

# 7) Ensure compile_commands.json is available at project root (clangd convenience)
$compileInBuild = Join-Path $absBuildDir "compile_commands.json"
$compileAtRoot = Join-Path (Get-Location) "compile_commands.json"
if (Test-Path $compileInBuild) {
  try {
    Copy-Item -Path $compileInBuild -Destination $compileAtRoot -Force
    Write-Host "Copied compile_commands.json to project root."
  } catch {
    Write-Host "Could not copy compile_commands.json to project root. You can point clangd to the build folder instead." -ForegroundColor Yellow
  }
} else {
  Write-Host "No compile_commands.json found in build directory." -ForegroundColor Yellow
}

# 8) Show sccache stats
Write-Host "`n=== sccache stats ===" -ForegroundColor Cyan
& sccache --show-stats

Write-Host "`nDone." -ForegroundColor Green

# Notes for MSVC users:
# - sccache can wrap cl.exe but requires a wrapper or using the compiler launcher support in CMake.
# - If you build with MSVC (cl.exe), prefer running this script from a Developer Command Prompt or call vcvarsall.bat first:
#   & 'C:\Path\To\VC\Auxiliary\Build\vcvarsall.bat' x64
# - For MSVC + sccache advanced setup, ask for the wrapper steps (this script uses clang wrappers by default).
