#Requires -Version 5.1
# 兼容旧入口：默认只连接；若传了 -Install/-SetHome 则走完整安装
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$target = Join-Path $here "Lawnchair-MuMu.ps1"
if (-not (Test-Path -LiteralPath $target)) { throw "缺少 $target" }

# 旧脚本默认是“只连接”；只有显式 -Install 或 -SetHome 才安装
$hasInstall = $false
foreach ($a in $args) {
  if ("$a" -match '^(?i)-Install$' -or "$a" -match '^(?i)-SetHome$') { $hasInstall = $true; break }
}
if (-not $hasInstall) {
  & $target -ConnectOnly @args
} else {
  # 旧参数 -Install/-SetHome 在新脚本里不需要，过滤掉
  $forward = @()
  foreach ($a in $args) {
    if ("$a" -match '^(?i)-Install$' -or "$a" -match '^(?i)-SetHome$') { continue }
    $forward += $a
  }
  & $target @forward
}
exit $LASTEXITCODE