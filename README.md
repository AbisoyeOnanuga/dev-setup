# C/C++ Dev Setup on Windows

Reusable templates and step-by-step guides for fast C/C++ builds, editor integration, and terminal productivity on Windows. Start with the high-ROI items and adopt repeatable templates for new projects. Each section below includes copy-paste PowerShell snippets and brief explanations applicable to any CMake-based project.

## 1. MSVC wrapper — when it is needed
### Verdict

* When building with clang/clang++ or clang-cl and using sccache via CC/CXX (or a CMake launcher), a wrapper is not required.
* When building with MSVC cl.exe and sccache should intercept cl calls, a wrapper is the practical option on Windows because cl.exe is not a simple executable that can be replaced in place.

### When to use the wrapper

* Use the wrapper only when sccache should cache MSVC cl.exe compilations. For LLVM-based builds, prefer sccache clang/clang++ and skip the wrapper.

### Simple wrapper approach (when required)

1. Create a short folder C:\tools\bin.
2. Put a tiny cl.bat wrapper that forwards to sccache and the real cl.exe.
3. Prepend C:\tools\bin to PATH when configuring/building.

### Example wrapper `C:\tools\bin\cl.bat`
    @echo off
    REM wrapper to route cl.exe through sccache
    REM Adjust REAL_CL to the local MSVC cl.exe path if needed
    set REAL_CL="C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.##.#####\bin\Hostx64\x64\cl.exe"
    sccache %REAL_CL% %*

### **Usage** (PowerShell session before configure)
    $env:Path = "C:\tools\bin;$env:Path"
    cmake -S . -B build -G Ninja ...

## 2. Fast linker lld and CMake flags
### Check if lld is present
    lld --version

### Try lld with CMake (Ninja)
    cmake -S . -B build-lld -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"
    cmake --build build-lld -j 12

### Notes

* lld is usually included with LLVM; it’s safe to test on a small module first.
* On Windows with MSVC toolchain, -fuse-ld=lld may require clang-cl or special flags; test before switching large projects.
* With clang-cl, lld often integrates more smoothly.

## 3. Build reproducibility without Docker
###  Simple, practical approach
* Pin tool versions in a dev-setup/versions.txt (CMake, Ninja, LLVM, sccache, Python).
* Commit a dev-setup.ps1 that installs or verifies those versions and sets up PATH/junctions.
* Use CMakePresets.json to store configure flags and generator so every dev runs the same configure command.

### Example CMakePresets.json minimal
    json
    {
        "version": 3,
        "configurePresets": [
                {
                "name": "default",
                "generator": "Ninja",
                "cacheVariables": {
                    "CMAKE_BUILD_TYPE": "RelWithDebInfo",
                    "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
                }
            }
        ]
    }

### Dev setup script idea
* Create dev-setup/install-tools.ps1 that checks versions and creates short junctions (e.g., C:\tools\llvm) to avoid PATH length issues.

## 4. CLI productivity tools and wiring to Telescope
### Install (winget)
    winget install --id BurntSushi.ripgrep
    winget install --id sharkdp.fd
    winget install --id junegunn.fzf

### Neovim minimal plugin list
* `nvim-telescope/telescope.nvim`
* ` nvim-lua/plenary.nvim`
* `nvim-treesitter/nvim-treesitter`
* `nvim-lspconfig`
* `nvim-lua/popup.nvim` (if needed)
**Telescope auto-uses** `rg`/`fd` when they are on PATH; no extra wiring required.

## 5. Toolchain hygiene and vcvars helper
   **Why**: avoid PATH conflicts between msys64, LLVM, and MSVC. Load MSVC env only when needed.

### Add to the PowerShell profile
    function Use-VcVars { param($arch='x64')
        $vswhere = "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe"
        $inst = & $vswhere -latest -products * -property installationPath
        & "$inst\VC\Auxiliary\Build\vcvarsall.bat" $arch    
    }
    Set-Alias vc Use-VcVars
### Workflow
* Use vc in a shell before MSVC builds.
* Keep msys64/mingw64 not at the front of global PATH; use msys shell for MinGW work.

## 6. clangd and compile_commands.json for editor LSP
### For CMake projects

### 1. From project root (where CMakeLists.txt lives):
    cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    Copy-Item build\compile_commands.json . -Force
### 2. Neovim LSP config (init.lua snippet)
    lua
    require('lspconfig').clangd.setup{
        cmd = { "C:\\tools\\llvm\\bin\\clangd.exe", "--background-index", "--clang-tidy" },
        root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git')  
    }

### For Unreal projects
* Use Unreal’s -GenerateClangDatabase or community generator to produce compile_commands.json. Place it in project root or point clangd to the build folder.

### Why this matters
* `compile_commands.json` gives clangd exact include paths and flags so diagnostics, refactors, and code actions are accurate.

## 7. Formatting and linting with clang-format and clang-tidy
### Install check
    powershell
    clang-format --version
    clang-tidy --version

### Minimal .clang-format
    text
    BasedOnStyle: Google
    IndentWidth: 2
    ColumnLimit: 100
### Pre-commit hook (simple)
    Create `.git/hooks/pre-commit`:
    bash
    #!/bin/sh
    git diff --name-only --cached --relative | grep -E '\.(c|cpp|h|hpp)$' | xargs -r clang-format -i
    git add .
### Neovim integration with null-ls
    lua
    local null_ls = require("null-ls")
    null_ls.setup({
    sources = {
            null_ls.builtins.formatting.clang_format,
            null_ls.builtins.diagnostics.clang_check
        },
    })
### clang-tidy
* Run as CI check or via clangd (--clang-tidy flag) for inline diagnostics.

## 8. Per-project checklist
1. Create project folder and add CMakeLists.txt (or Unreal project).
2. Run dev-setup\configure-with-sccache.ps1 from project root (it sets CC/CXX and configures build).
3. Verify sccache --show-stats after first build to confirm caching.
4. Copy build/compile_commands.json to project root for clangd.
5. Open file in Neovim and confirm clangd diagnostics.
6. Add .clang-format and a pre-commit hook.
7. Install rg, fd, fzf and add Telescope to Neovim.
8. If using MSVC with caching, decide whether to use the wrapper; otherwise use the vc helper and prefer the clang toolchain for sccache.

### Learning resources and videos
* Look for short, focused videos (10–20 minutes) on:
    * sccache + CMake + Ninja setup
    * clangd + compile_commands.json for Neovim
    * clang-format + pre-commit integration
    * Using lld with CMake

* Suggested YouTube search terms:
    * sccache cmake ninja windows tutorial
    * clangd compile_commands neovim setup 
    * clang-format pre-commit tutorial 
    * use lld with cmake ninja windows
    (These exact search queries will find concise walkthroughs.)