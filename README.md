# C/C++ Dev Setup on Windows

Reusable templates and step-by-step guides for fast C/C++ builds, editor integration, and terminal productivity on Windows.

**Docs in this repo**

| File | Read this when… |
|------|-----------------|
| `README.md` (this file) | Learning what each piece does and how topics fit together |
| `DEVSETUP.md` | Setting up a new Windows machine for the first time |
| `tests.md` | Verifying the toolchain after install or changes |
| `PROJECT-README.md` | Starting a new CMake project — copy into that repo, not read here |

## Quick start

1. Follow [DEVSETUP.md](DEVSETUP.md) to install tools and set `SCCACHE_DIR`.
2. Run `.\check-tools.ps1` to confirm everything is on PATH.
3. Run `.\configure-with-sccache.ps1` from `sample-cpp\` to validate the flow.

## Repository map

What each file is for — the main reference when something’s purpose is unclear.

| File | Why it exists | When to use |
|------|---------------|-------------|
| `check-tools.ps1` | Prints versions of cmake, clang, sccache, rg, etc.; surfaces missing tools | After install, or on any new machine |
| `configure-with-sccache.ps1` | Configures a CMake project with `sccache clang` / `clang++`, exports `compile_commands.json`, optional build | Per CMake project, from the project root |
| `MSVC-wrapper.ps1` | Creates `C:\tools\bin\cl.bat` so sccache can intercept MSVC `cl.exe` | Once per machine — **only** if caching MSVC builds |
| `cl.bat` | The wrapper itself: finds real `cl.exe` via vswhere, forwards through sccache | Lives in `C:\tools\bin` after running `MSVC-wrapper.ps1`; kept in repo as reference |
| `vc-helper.ps1` | Adds a `vc` command to the PowerShell profile to load MSVC env on demand | Once per machine when MSVC builds are needed |
| `CMakePresets.json` | Pins generator and configure flags so `cmake --preset default` is consistent | Copy into new CMake projects |
| `sample-cpp/` | Tiny CMake project to smoke-test sccache, lld, and clangd | After setup, before trusting a real project |
| `PROJECT-README.md` | Boilerplate README for other repos using this workflow | Copy into new projects |

## External tools (install separately)

Not stored in this repo — install via winget, LLVM installer, or Visual Studio.

| Tool | Role in this setup |
|------|-------------------|
| **sccache** | Compile cache — main rebuild speedup |
| **clang / clang++** | Default compiler; wraps cleanly with sccache via `CC`/`CXX` |
| **cmake + ninja** | Build system used by all scripts here |
| **clangd** | C/C++ language server (needs `compile_commands.json`) |
| **clang-format / clang-tidy** | Formatting and static analysis |
| **lld** | Faster linker (`-fuse-ld=lld`) |
| **ripgrep, fd, fzf** | Fast search and fuzzy find in the terminal; Neovim Telescope uses rg/fd automatically |
| **Visual Studio + vswhere** | MSVC toolchain — only when MSVC builds are required |

---

## 1. MSVC wrapper — when it is needed
### Verdict

* When building with clang/clang++ or clang-cl and using sccache via CC/CXX (or a CMake launcher), a wrapper is not required.
* When building with MSVC cl.exe and sccache should intercept cl calls, a wrapper is the practical option on Windows because cl.exe is not a simple executable that can be replaced in place.

### When to use the wrapper

* Use the wrapper only when sccache should cache MSVC cl.exe compilations. For LLVM-based builds, prefer sccache clang/clang++ and skip the wrapper.

### Setup (when required)

This repo ships the wrapper as two files:

* **`cl.bat`** — reference copy; uses vswhere to find `cl.exe`, then runs `sccache` with it.
* **`MSVC-wrapper.ps1`** — installs that wrapper to `C:\tools\bin\cl.bat`.

Run once (Admin optional):

```powershell
.\MSVC-wrapper.ps1
```

Before an MSVC build session, prepend the tools folder to PATH:

```powershell
$env:Path = "C:\tools\bin;$env:Path"
vc x64   # if vc-helper.ps1 was run; loads MSVC env
cmake -S . -B build -G Ninja ...
```

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

* Run `check-tools.ps1` after install to record which tool versions are present.
* Copy `CMakePresets.json` from this repo into each project so `cmake --preset default` always uses the same generator and flags.
* See `configure-with-sccache.ps1` for the standard per-project configure flow.

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

Avoid PATH conflicts between msys64, LLVM, and MSVC by loading MSVC env only in the shell that needs it. Run `vc-helper.ps1` once to install the helper; it adds this to the PowerShell profile:
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
2. Run `configure-with-sccache.ps1` from the project root (sets CC/CXX and configures build).
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