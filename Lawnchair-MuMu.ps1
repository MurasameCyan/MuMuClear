#Requires -Version 5.1
<#
.SYNOPSIS
  MuMu + Lawnchair 一键工具（连接 / 安装默认桌面 / 黑屏救援）

.DESCRIPTION
  同目录依赖：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk

  默认模式（推荐）：
    1) 自动探测 MuMu ADB 端口并连接
    2) 删除 /system/priv-app/Lawnchair 冲突
    3) 用户安装 Lawnchair_app.lawnchair_signed.apk
    4) 设为默认 HOME

  注意：testkey 重签包不要覆盖系统 priv-app，否则会 FallbackHome 黑屏。

.USAGE
  # 默认：连接 + 安装 + 设默认桌面
  .\Lawnchair-MuMu.ps1

  # 只连接，不装包
  .\Lawnchair-MuMu.ps1 -ConnectOnly

  # 指定多开序号
  .\Lawnchair-MuMu.ps1 -Index 9

  # 黑屏救援
  .\Lawnchair-MuMu.ps1 -RecoverOnly

  # 危险：系统 priv-app 覆盖（需签名一致）
  .\Lawnchair-MuMu.ps1 -ForceSystemPrivApp
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,
  [switch]$ConnectOnly,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Lawnchair MuMu"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$AdbDir = Join-Path $ScriptDir "Adb"

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "  [X] $m" -ForegroundColor Red }

function Resolve-ScriptPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if ([IO.Path]::IsPathRooted($Path)) { return $Path }
  return [IO.Path]::GetFullPath((Join-Path $ScriptDir $Path))
}

function Find-Adb {
  foreach ($p in @((Join-Path $AdbDir "adb.exe"), (Join-Path $ScriptDir "adb.exe"))) {
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请放到脚本同目录 Adb\adb.exe"
}

function Invoke-Adb {
  param([string]$AdbPath, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $AdbPath @Args 2>&1
    ($out | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { "$_" }
    }) -join "`n"
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Test-MuMuVmsRoot([string]$VmsPath) {
  if (-not $VmsPath -or -not (Test-Path -LiteralPath $VmsPath)) { return $false }
  return [bool](Get-ChildItem -LiteralPath $VmsPath -Directory -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like "MuMuPlayer-*" -and
      (Test-Path (Join-Path $_.FullName "configs\vm_config.json"))
    } | Select-Object -First 1)
}

function Find-MuMuVmsRoot {
  foreach ($name in @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-MuMuVmsRoot $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @("MuMu\vms", "Netease\MuMu\vms", "Netease\MuMuPlayer\vms")) {
      $cand = Join-Path $root $rel
      if (Test-MuMuVmsRoot $cand) { return $cand }
    }
  }
  return $null
}

function Get-ConfigPorts([string]$VmsRoot, [int]$OnlyIndex) {
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch "MuMuPlayer-.*?-(\d+)$") { return }
    $idx = [int]$Matches[1]
    if ($OnlyIndex -ge 0 -and $idx -ne $OnlyIndex) { return }
    $cfg = Join-Path $_.FullName "configs\vm_config.json"
    if (-not (Test-Path $cfg)) { return }
    try {
      $j = Get-Content -Raw -LiteralPath $cfg | ConvertFrom-Json
      $port = [int]$j.vm.nat.port_forward.adb.host_port
      if ($port -le 0) { return }
      $log = Join-Path $_.FullName "logs\shell.log"
      $logTime = if (Test-Path $log) { (Get-Item $log).LastWriteTime } else { [datetime]::MinValue }
      $list += [PSCustomObject]@{
        Index = $idx; VM = $_.Name; Port = $port; LogTime = $logTime
        Serial = "127.0.0.1:$port"; Source = "vm_config"
      }
    } catch {}
  }
  return $list | Sort-Object Index
}

function Get-ListenPorts {
  $out = @()
  Get-Process MuMuNxDevice -ErrorAction SilentlyContinue | ForEach-Object {
    $proc = $_
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        $_.LocalPort -eq 7555 -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } | ForEach-Object {
        $out += [PSCustomObject]@{
          Index = -1; VM = "MuMuNxDevice"; Port = [int]$_.LocalPort; LogTime = Get-Date
          Serial = "127.0.0.1:$($_.LocalPort)"; Source = "listen"
        }
      }
  }
  return $out
}

function Test-TcpOpen([int]$Port, [int]$TimeoutMs = 400) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
    if (-not $ok) { $client.Close(); return $false }
    $client.EndConnect($iar) | Out-Null
    $client.Close()
    return $true
  } catch { return $false }
}

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex, [switch]$NoProxy) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @()
  if (-not $NoProxy) { $listen = @(Get-ListenPorts) }

  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  if ($cfgPorts.Count -gt 0) {
    Write-Host ("  {0,-6} {1,-22} {2}" -f "Index", "VM", "Port") -ForegroundColor DarkGray
    foreach ($c in $cfgPorts) {
      Write-Host ("  {0,-6} {1,-22} {2}" -f $c.Index, $c.VM, $c.Port)
    }
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial) [$($map[$port].Source)]"
      $live += $map[$port]
    } else {
      Write-Host "  [ ] 未开放: 127.0.0.1:$port" -ForegroundColor DarkGray
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match "connected|already") {
      Write-Ok $msg
      $connected += $item
    } else {
      Write-Warn "$($item.Serial) -> $msg"
    }
  }

  $primary = $connected |
    Sort-Object `
      @{ Expression = { if ($_.Source -eq "vm_config") { 0 } else { 1 } } }, `
      @{ Expression = { if ($_.Port -ge 16384) { 0 } elseif ($_.Port -eq 7555) { 2 } else { 1 } } }, `
      @{ Expression = { $_.LogTime }; Descending = $true } |
    Select-Object -First 1

  if (-not $primary) { throw "connect 失败" }
  Write-Ok "主设备 $($primary.Serial) Index=$($primary.Index)"
  return $primary
}

function Wait-Device([string]$AdbPath, [string]$Serial, [int]$TimeoutSec = 90) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if ($Serial -match "^127\.0\.0\.1:") { $null = Invoke-Adb $AdbPath connect $Serial }
    if ((Invoke-Adb $AdbPath -s $Serial get-state).Trim() -eq "device") { return $true }
    Start-Sleep -Seconds 2
  }
  return $false
}

function Ensure-Root([string]$AdbPath, [string]$Serial) {
  Write-Step "adb root"
  $null = Invoke-Adb $AdbPath -s $Serial root
  Start-Sleep -Seconds 2
  if (-not (Wait-Device $AdbPath $Serial 60)) { throw "root 后设备掉线" }
  $id = (Invoke-Adb $AdbPath -s $Serial shell id).Trim()
  if ($id -notmatch "uid=0") { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path -LiteralPath $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path -LiteralPath $ApkPath).Path

  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch "Success") { throw "安装失败: $out" }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Set-DefaultHome([string]$AdbPath, [string]$Serial) {
  Write-Step "设为默认桌面"
  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
  $resolved = (Invoke-Adb $AdbPath -s $Serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
  Write-Host "  HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) { Write-Ok "已是默认桌面" }
  else { Write-Warn "若未切换成功，请在模拟器弹窗选择 Lawnchair → 始终" }
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch "package:") {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path -LiteralPath $ApkPath)) { throw "需要 APK: $ApkPath" }
    $full = (Resolve-Path -LiteralPath $ApkPath).Path
    $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
    Write-Host "  $out"
  } else {
    Write-Ok "已有包: $path"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $start = (Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity -W").Trim()
  Write-Host "  $start"
  Show-Status $AdbPath $Serial
}

function Install-ForceSystem([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "危险模式: ForceSystemPrivApp"
  Write-Warn "testkey 重签包在 MuMu 上重启后常扫包失败并黑屏。仅在签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path -LiteralPath $ApkPath).Path

  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch "Success") {
    throw "系统 priv-app 安装失败，已中止。请改用默认用户安装模式。"
  }
  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
}

function Show-Status([string]$AdbPath, [string]$Serial) {
  Write-Step "状态"
  $pkgPath = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  $homeInfo = (Invoke-Adb $AdbPath -s $Serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
  $focus = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys window | grep mCurrentFocus").Trim()
  Write-Host "  pm path : $pkgPath"
  Write-Host "  HOME    : $homeInfo"
  Write-Host "  focus   : $focus"
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match "LawnchairLauncher") {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match "FallbackHome") {
    Write-Err "仍卡在 FallbackHome"
  }
}

try {
  if (($ConnectOnly.IsPresent -and $RecoverOnly.IsPresent) -or
      ($ConnectOnly.IsPresent -and $ForceSystemPrivApp.IsPresent) -or
      ($RecoverOnly.IsPresent -and $ForceSystemPrivApp.IsPresent)) {
    throw "ConnectOnly / RecoverOnly / ForceSystemPrivApp 只能选一个"
  }

  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not $ConnectOnly) {
    if (-not (Test-Path -LiteralPath $apkPath)) {
      throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    }
    Write-Ok "apk: $apkPath"
  }

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index -NoProxy:$NoProxyPorts
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  $env:MUMU_ADB_PORT = "$($dev.Port)"
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  Write-Step "当前 devices"
  Write-Host (Invoke-Adb $adb devices -l)

  if ($ConnectOnly) {
    Write-Step "完成（仅连接）"
    Write-Host @"

主设备: $serial
端口  : $($dev.Port)

之后可用:
  & "$adb" -s $serial shell

"@ -ForegroundColor Green
    exit 0
  }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
    if (-not $SkipReboot) {
      Write-Step "reboot（ForceSystem 模式）"
      $null = Invoke-Adb $adb -s $serial reboot
      Start-Sleep 8
      $ok = $false
      $deadline = (Get-Date).AddSeconds(120)
      while ((Get-Date) -lt $deadline) {
        $null = Invoke-Adb $adb connect $serial
        if ((Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim() -eq "1") {
          $ok = $true
          break
        }
        Start-Sleep 3
      }
      if (-not $ok) {
        Write-Warn "等待启动超时"
      } else {
        $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
        if ($homeInfo -match "FallbackHome") {
          Write-Warn "检测到 FallbackHome，自动救援"
          Recover-FallbackHome $adb $serial $apkPath
        }
      }
    }
  } else {
    # 默认推荐：用户安装 + 默认 HOME
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if ($DisableStockLauncher) {
    Write-Step "禁用原系统桌面: $StockLauncher"
    $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher).Trim()
    Write-Host "  $d"
  }

  Set-DefaultHome $adb $serial
  Show-Status $adb $serial

  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

常用:
  .\Lawnchair-MuMu.ps1              # 默认安装
  .\Lawnchair-MuMu.ps1 -ConnectOnly # 只连接
  .\Lawnchair-MuMu.ps1 -RecoverOnly # 黑屏救援

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}