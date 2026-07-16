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
# 本脚本在 tool\ 下，主入口在上一级
$target = Join-Path (Split-Path -Parent $here) "Lawnchair-MuMu.ps1"
if (-not (Test-Path -LiteralPath $target)) {
  # 兼容：若仍与本文件同目录
  $target = Join-Path $here "Lawnchair-MuMu.ps1"
}
if (-not (Test-Path -LiteralPath $target)) { throw "缺少 Lawnchair-MuMu.ps1（应在 tool 的上一级目录）" }
& $target @args
exit $LASTEXITCODE