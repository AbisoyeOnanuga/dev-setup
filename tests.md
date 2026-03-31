
## Toolchain test
    # clang + sccache test
    cd dev-setup\sample-cpp
    $env:CC="sccache clang"; $env:CXX="sccache clang++"
    cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    cmake --build build -j 4
    sccache --show-stats

## lld test
    cmake -S . -B build-lld -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"
    cmake --build build-lld -j 4

## clangd test
Copy `build/compile_commands.json` to project root and open a C++ file in Neovim or Rider; verify diagnostics and go-to-definition.