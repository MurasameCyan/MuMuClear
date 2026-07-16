#Requires -Version 5.1
<#
.SYNOPSIS
  兼容旧入口：转发到 Lawnchair-MuMu.ps1

.USAGE
  .\Replace-System-Launcher.ps1
  .\Replace-System-Launcher.ps1 -RecoverOnly
  .\Replace-System-Launcher.ps1 -Help
#>
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$target = Join-Path $here "Lawnchair-MuMu.ps1"
if (-not (Test-Path -LiteralPath $target)) { throw "缺少 $target" }
& $target @args
exit $LASTEXITCODE