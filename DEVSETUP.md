# Dev Setup Bootstrap

## One-time installs
1. Install LLVM (clang, clangd, clang-format, clang-tidy, lld).
2. Install CMake and Ninja.
3. Install sccache.
4. Install Python 3.x.
5. Install CLI helpers: ripgrep, fd, fzf (optional but recommended).
6. Install Visual Studio Installer (for vswhere) when MSVC builds are required.

## Persistent environment
- Add `C:\tools\bin` to User PATH (for cl wrapper).
- Set SCCACHE_DIR:
  setx SCCACHE_DIR "C:\sccache"
  setx SCCACHE_CACHE_SIZE "20G"

## Quick verification
Open PowerShell x64 and run:

# MSVC wrapper script and session helper
**Purpose**: let sccache intercept cl.exe calls on Windows when MSVC builds are required. Use this only when MSVC build caching is needed; otherwise prefer sccache clang/clang++ and skip the wrapper.

### What it does
* Creates a short folder C:\tools\bin.
* Writes a small cl.bat wrapper that finds the real cl.exe via vswhere, then runs sccache with the real cl.exe and forwards all arguments.
* Shows how to prepend C:\tools\bin to PATH for the current session.

### Create wrapper script (run as Administrator once)
Save and run `MSVC-wrapper.ps1` snippet to create the wrapper and a helper to use it
### How to use in a build session
    powershell
    # In the shell used for configure/build
    $env:Path = "C:\tools\bin;$env:Path"
    # Optionally load MSVC env if needed
    & 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat' x64
    # Then configure/build with CMake as usual
    cmake -S . -B build -G Ninja ...
    cmake --build build -j 12

## Persisting the wrapper in PATH
**Add `C:\tools\bin` to the User PATH (recommended)** — this avoids the system PATH length limit and keeps the change scoped to the user account.

Run this in an **elevated or normal PowerShell** (no reboot required for new shells after logging out/in or restarting the terminal):

    powershell
    # Add to User PATH (safe, persistent)
    $tools = "C:\tools\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$tools*") {
        $new = if ([string]::IsNullOrEmpty($userPath)) { $tools } else { "$userPath;$tools" }
        [Environment]::SetEnvironmentVariable("Path",$new,"User")
        Write-Host "Added $tools to User PATH."
    } else {
        Write-Host "$tools already in User PATH."
    }

**Verify** in a new PowerShell window:

    powershell
    where cl.bat
    where sccache

If where finds `cl.bat` under `C:\tools\bin`, the wrapper is active for new shells. To apply the change in the current shell immediately, run:

    powershell
    $env:Path = "C:\tools\bin;$env:Path"

## PowerShell profile and adding the vc helper
### What the vc helper does  
It runs `vcvarsall.bat` for the Visual Studio install found by `vswhere`, loading MSVC environment variables into the current shell so `cl`, `link`, and other MSVC tools work without permanently modifying PATH.

### Create or edit the PowerShell profile and add the helper  
Open PowerShell (x64) and run `vc-helper.ps1` to create the profile if missing and append the helper:
### Use it in a session
1. Open a **new PowerShell (x64)** window.
2. Run:

        powershell
        vc x64
        This loads MSVC environment variables into that shell.
3. Then configure/build in the same shell.

### Notes
* The wrapper locates cl.exe via vswhere. When multiple MSVC versions are installed, hardcode a path instead.
* Test on a small project first. To avoid permanent PATH changes, only prepend C:\tools\bin in the session.

## dev-README for the dev-setup folder
**Purpose**: a single reference for commands and templates reused across projects.

### **dev-README content** (copy into `dev-setup/README.md`)
    markdown
    # Dev Setup Quick Reference

    ## One-time global setup
    - Install tools: LLVM, Ninja, CMake, sccache, ripgrep, fd, fzf.
    - Create sccache cache dir:
        ```powershell
        New-Item -ItemType Directory -Path "C:\sccache" -Force
        setx SCCACHE_DIR "C:\sccache"
        setx SCCACHE_CACHE_SIZE "20G"

## Per-project quick start (CMake)
### 1. Open PowerShell and cd to project root (where CMakeLists.txt will live).
### 2. For session-only sccache usage:
    powershell
    $env:CC = "sccache clang"
    $env:CXX = "sccache clang++"
### 3. Configure and build:
    powershell
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    cmake --build build -j 12
### 4. Copy compile commands for clangd:
    powershell
    Copy-Item build\compile_commands.json . -Force
### 5. Verify sccache:
    powershell
    sccache --show-stats

## MSVC caching
### * Use the wrapper in C:\tools\bin\cl.bat and prepend C:\tools\bin to PATH for the session.
### * Load MSVC env before building:
    powershell
    & 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat' x64
## Useful files in this folder
* `configure-with-sccache.ps1` — configure and optionally build a CMake project with sccache.
* `sample-cpp` — tiny CMake project to test toolchain, lld, clangd, clang-format.
* `vc-helper.ps1` — PowerShell snippet to add to the profile for loading vcvars.

## Tiny sample CMake project to test everything
**Purpose**: a minimal project to validate sccache, lld, clangd, clang-format, and the wrapper.

**Folder** `dev-setup/sample-cpp` with these two files.
* CMakeLists.txt
* main.cpp

### How to test
    powershell
    cd dev-setup\sample-cpp
    
    # Option A: use clang + sccache
    $env:CC = "sccache clang"
    $env:CXX = "sccache clang++"
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    cmake --build build -j 12
    sccache --show-stats
    
    # Option B: test lld linker
    cmake -S . -B build-lld -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"
    cmake --build build-lld -j 12

After configure, copy `build/compile_commands.json` to project root for clangd.

## For Unreal Engine projects
* Unreal uses UnrealBuildTool (UBT). To get caching:
  * Global: set SCCACHE_DIR and SCCACHE_CACHE_SIZE as above.
  * UBT: configure environment or BuildConfiguration.xml to use clang/clang-cl or ensure UBT invokes compilers through sccache. Test on a small module first.

## Script to check all tool versions
**Purpose**: one command to verify installed tool versions and spot missing tools.
Save as `dev-setup/check-tools.ps1` and run from PowerShell.

### How to run
1. Open **PowerShell (x64)** (Start → PowerShell → Windows PowerShell (x64) or Windows Terminal with x64 profile).
2. If execution policy blocks scripts once:

         powershell
         Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
3. Run:

         powershell
         cd path\to\dev-setup
         .\check-tools.ps1

## How to create or get CMakePresets.json
**Purpose**: pin generator and common configure flags so every dev uses the same configure command.
Minimal example put in project root as `CMakePresets.json`
### How to use
    powershell
    cmake --preset default
    cmake --build --preset default -- -j 12
### Why use presets
* Single source of truth for generator and flags.
* Easier onboarding: new devs run cmake --preset default and get the same configure behavior.

## Final checklist and next steps

### Repository contents

* `cl.bat` — wrapper created by `MSVC-wrapper.ps1` when run.
* `README.md` — quick reference (see content above).
* `vc-helper.ps1` — snippet to add to the PowerShell profile.
* `sample-cpp/` — minimal test project.
* `check-tools.ps1` — tool version checker.
* `configure-with-sccache.ps1` — CMake configure helper with sccache.

### Recommended setup order

1. Run the wrapper creation script once as Admin to create `C:\tools\bin\cl.bat` when MSVC caching is needed.
2. Add the vc helper to the PowerShell profile.
3. Validate with the sample project using the sccache flow and with lld.
4. Run `.\check-tools.ps1` to confirm tool versions.