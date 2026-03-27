# Ensure profile exists
if (-not (Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

# Append vc helper if not already present
$helper = @'
function Use-VcVars { param($arch='x64')
  $vswhere = "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe"
  $inst = & $vswhere -latest -products * -property installationPath
  if (-not $inst) { Write-Host "Visual Studio not found via vswhere" -ForegroundColor Yellow; return }
  & "$inst\VC\Auxiliary\Build\vcvarsall.bat" $arch
}
Set-Alias vc Use-VcVars
'@

if (-not (Select-String -Path $PROFILE -Pattern "function Use-VcVars" -Quiet)) {
  Add-Content -Path $PROFILE -Value $helper
  Write-Host "vc helper added to $PROFILE"
} else {
  Write-Host "vc helper already present in profile"
}

<# Usage
In a new shell when you need MSVC
vc x64
Then build as usual
#>