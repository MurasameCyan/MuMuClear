#Requires -Version 5.1
<#
.SYNOPSIS
  兼容旧入口：默认只连接；-Install/-SetHome 时完整安装

.USAGE
  .\MuMu-Connect-And-Set-Lawnchair.ps1
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Help
#>
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
# 本脚本在 tool\ 下，主入口在上一级
$target = Join-Path (Split-Path -Parent $here) "Lawnchair-MuMu.ps1"
if (-not (Test-Path -LiteralPath $target)) {
  # 兼容：若仍与本文件同目录
  $target = Join-Path $here "Lawnchair-MuMu.ps1"
}
if (-not (Test-Path -LiteralPath $target)) { throw "缺少 Lawnchair-MuMu.ps1（应在 tool 的上一级目录）" }

$hasInstall = $false
foreach ($a in $args) {
  if ("$a" -match '^(?i)-Install$' -or "$a" -match '^(?i)-SetHome$') { $hasInstall = $true; break }
}
if (-not $hasInstall) {
  & $target -ConnectOnly @args
} else {
  $forward = @()
  foreach ($a in $args) {
    if ("$a" -match '^(?i)-Install$' -or "$a" -match '^(?i)-SetHome$') { continue }
    $forward += $a
  }
  & $target @forward
}
exit $LASTEXITCODE