# check-tools.ps1
$tools = @{
  "cmake"        = { & cmake --version 2>&1 }
  "ninja"        = { & ninja --version 2>&1 }
  "clang"        = { & clang --version 2>&1 }
  "clang++"      = { & clang++ --version 2>&1 }
  "clangd"       = { & clangd --version 2>&1 }
  "clang-format" = { & clang-format --version 2>&1 }
  "clang-tidy"   = { & clang-tidy --version 2>&1 }
  "lld"          = { & lld --version 2>&1 }
  "sccache"      = { & sccache --version 2>&1 }
  "python"       = { & python --version 2>&1 }
  "rg (ripgrep)" = { & rg --version 2>&1 }
  "fd"           = { & fd --version 2>&1 }
  "fzf"          = { & fzf --version 2>&1 }
  "vswhere"      = { & "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe" -version 2>&1 }
}

Write-Host "Checking tool versions..." -ForegroundColor Cyan

foreach ($name in $tools.Keys) {
  Write-Host "`n== $name ==" -ForegroundColor Green
  try {
    $out = & $tools[$name]
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($out)) {
      Write-Host "Not found or returned no output." -ForegroundColor Yellow
    } else {
      Write-Host $out
    }
  } catch {
    Write-Host "Not found or error running $name: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host "`nDone." -ForegroundColor Cyan
