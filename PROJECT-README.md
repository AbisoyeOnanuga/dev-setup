# Project Name

## Quick start (developer)
1. Open PowerShell x64.
2. Optional: enable MSVC env:
   `vc x64`

3. Optional: enable sccache clang:
   `$env:CC = "sccache clang"
   $env:CXX = "sccache clang++"`

4. Configure:
   cmake --preset default

5. Build:
   `cmake --build --preset default -- -j 12`

6. Copy compile commands for clangd:
   `Copy-Item build\compile_commands.json . -Force`

## Formatting and linting
- Run `clang-format` via pre-commit or `clang-format -i` on changed files.
- Use clangd with `--clang-tidy` for diagnostics.

## Notes
- Linker: lld is used when `-fuse-ld=lld` is set.
- sccache stats: `sccache --show-stats`