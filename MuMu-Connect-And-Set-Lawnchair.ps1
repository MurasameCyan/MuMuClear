#Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  .\MuMu-Connect-And-Set-Lawnchair.ps1
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  同目录依赖：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$AdbDir = Join-Path $ScriptDir "Adb"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [X] $msg" -ForegroundColor Red }

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
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $Adb @Args 2>&1
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

function Get-MuMuPortsFromConfig {
  param([string]$VmsRoot, [int]$OnlyIndex = -1)
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch "MuMuPlayer-.*?-(\d+)$") { return }
    $idx = [int]$Matches[1]
    if ($OnlyIndex -ge 0 -and $idx -ne $OnlyIndex) { return }
    $cfgPath = Join-Path $_.FullName "configs\vm_config.json"
    if (-not (Test-Path $cfgPath)) { return }
    try {
      $j = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json
      $port = [int]$j.vm.nat.port_forward.adb.host_port
      if ($port -le 0) { return }
      $logPath = Join-Path $_.FullName "logs\shell.log"
      $logTime = if (Test-Path $logPath) { (Get-Item $logPath).LastWriteTime } else { [datetime]::MinValue }
      $list += [PSCustomObject]@{
        Index = $idx; VM = $_.Name; Port = $port; Source = "vm_config"
        LogTime = $logTime; Serial = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }
  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } | ForEach-Object {
        $ports += [PSCustomObject]@{
          Index = -1; VM = "MuMuNxDevice(pid=$($proc.Id))"; Port = [int]$_.LocalPort
          Source = "listen"; LogTime = Get-Date; Serial = "127.0.0.1:$($_.LocalPort)"
        }
      }
  }
  return $ports | Sort-Object Port -Unique
}

function Test-TcpOpen([string]$HostName, [int]$Port, [int]$TimeoutMs = 400) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect($HostName, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
    if (-not $ok) { $client.Close(); return $false }
    $client.EndConnect($iar) | Out-Null
    $client.Close()
    return $true
  } catch { return $false }
}

Write-Step "查找 adb"
Write-Ok "scriptDir: $ScriptDir"
Write-Ok "adbDir   : $AdbDir"
$adb = Find-Adb
Write-Ok "使用: $adb"

Write-Step "读取 MuMu 实例配置端口"
$vmsRoot = Find-MuMuVmsRoot
if (-not $vmsRoot) {
  Write-Err "未找到 MuMu vms 目录。请先安装/启动 MuMu。"
  exit 1
}
Write-Ok "vms: $vmsRoot"

$configPorts = @(Get-MuMuPortsFromConfig -VmsRoot $vmsRoot -OnlyIndex $Index)
if ($configPorts.Count -eq 0) {
  Write-Warn "配置文件里没有读到端口，尝试扫描监听端口..."
} else {
  Write-Host ""
  Write-Host ("  {0,-6} {1,-22} {2,-8} {3}" -f "Index", "VM", "Port", "LastLog") -ForegroundColor DarkGray
  foreach ($c in $configPorts) {
    $t = if ($c.LogTime -gt [datetime]::MinValue) { $c.LogTime.ToString("yyyy-MM-dd HH:mm") } else { "-" }
    Write-Host ("  {0,-6} {1,-22} {2,-8} {3}" -f $c.Index, $c.VM, $c.Port, $t)
  }
}

$listenPorts = @()
if (-not $NoProxyPorts) { $listenPorts = @(Get-MuMuPortsFromListen) }

$candidates = @{}
foreach ($c in $configPorts) { $candidates[$c.Port] = $c }
foreach ($c in $listenPorts) {
  if (-not $candidates.ContainsKey($c.Port)) { $candidates[$c.Port] = $c }
}
if ($candidates.Count -eq 0) {
  Write-Err "没有可用端口。请确认 MuMu 已启动。"
  exit 1
}

Write-Step "检测哪些端口真正在线"
$live = @()
foreach ($port in ($candidates.Keys | Sort-Object)) {
  $info = $candidates[$port]
  if (Test-TcpOpen -HostName "127.0.0.1" -Port $port) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}
if ($live.Count -eq 0) {
  Write-Err "当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
$null = Invoke-Adb $adb start-server
$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial).Trim()
  if ($out -match "connected|already") {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
Write-Host (Invoke-Adb $adb devices -l)

$primary = $connected |
  Sort-Object `
    @{ Expression = { if ($_.Source -eq "vm_config") { 0 } else { 1 } }; Ascending = $true }, `
    @{ Expression = { if ($_.Port -ge 16384) { 0 } elseif ($_.Port -eq 7555) { 2 } else { 1 } }; Ascending = $true }, `
    @{ Expression = { $_.LogTime }; Descending = $true } |
  Select-Object -First 1

if (-not $primary) {
  Write-Err "连接失败。"
  exit 1
}

$serial = $primary.Serial
Write-Ok "主设备: $serial  (Index=$($primary.Index) $($primary.VM))"
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch "Success") {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    $null = Invoke-Adb $adb -s $serial uninstall $PackageName
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch "Success") {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity).Trim()
  if ($setOut) { Write-Host "  $setOut" }
  $null = Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher).Trim()
  Write-Host "  $d"
}

Write-Step "完成"
Write-Host @"

一键结果:
  主设备序列号 : $serial
  主设备端口   : $($primary.Port)
  在线实例数   : $($connected.Count)

常用命令:
  adb -s $serial shell

"@ -ForegroundColor Green