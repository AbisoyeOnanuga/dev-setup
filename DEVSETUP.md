# First-time setup on a new machine

Ordered checklist for a fresh Windows install. For what each file does, see the [Repository map](README.md#repository-map) in README.

## 1. Install tools

```powershell
winget install --id LLVM.LLVM
winget install --id Kitware.CMake
winget install --id Ninja-build.Ninja
winget install --id Mozilla.sccache
winget install --id BurntSushi.ripgrep
winget install --id sharkdp.fd
winget install --id junegunn.fzf
```

Also install Python 3.x. Install Visual Studio Build Tools when MSVC builds are required (provides `cl.exe` and vswhere).

## 2. Persistent environment

```powershell
New-Item -ItemType Directory -Path "C:\sccache" -Force
setx SCCACHE_DIR "C:\sccache"
setx SCCACHE_CACHE_SIZE "20G"
```

## 3. Verify tools

```powershell
cd path\to\dev-setup
.\check-tools.ps1
```

Fix anything reported missing before continuing.

## 4. Optional — MSVC + sccache caching

Skip this when using clang + sccache only (the default in `configure-with-sccache.ps1`).

```powershell
.\MSVC-wrapper.ps1          # installs cl.bat to C:\tools\bin
```

Add `C:\tools\bin` to User PATH (see README §1), or prepend per session:

```powershell
$env:Path = "C:\tools\bin;$env:Path"
```

## 5. Optional — MSVC shell helper

```powershell
.\vc-helper.ps1             # adds `vc` command to PowerShell profile
```

In a new shell: `vc x64` before MSVC builds.

## 6. Smoke test

```powershell
cd sample-cpp
..\configure-with-sccache.ps1
```

Confirm `sccache --show-stats` shows cache activity. Full test commands: [tests.md](tests.md).

## 7. Use on real projects

1. Copy `CMakePresets.json` and `PROJECT-README.md` into the new project.
2. From the project root, run `path\to\dev-setup\configure-with-sccache.ps1`.
