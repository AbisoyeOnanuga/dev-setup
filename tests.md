# Smoke tests

Run after first setup or when changing tools. See [Repository map](README.md#repository-map) for what each script does.

## Toolchain (clang + sccache)

```powershell
cd sample-cpp
$env:CC = "sccache clang"; $env:CXX = "sccache clang++"
cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build -j 4
sccache --show-stats
```

## lld linker

```powershell
cmake -S . -B build-lld -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"
cmake --build build-lld -j 4
```

## clangd

Copy `build/compile_commands.json` to the project root. Open a C++ file in Neovim or another editor with clangd; verify diagnostics and go-to-definition.
