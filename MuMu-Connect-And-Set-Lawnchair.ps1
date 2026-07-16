#Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  # 仅自动探测端口并连接
  .\MuMu-Connect-And-Set-Lawnchair.ps1

  # 连接 + 安装 + 设为默认桌面
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome

  # 指定 APK（相对路径默认相对脚本目录）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 只连某个多开序号（如 9 号机）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  依赖同目录布局：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,              # -1 = 自动连接所有在线实例
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts          # 不连 7555 等代理端口，只连配置文件里的真实端口
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
}

function Test-MuMuVmsRoot([string]$VmsPath) {
  if (-not $VmsPath -or -not (Test-Path -LiteralPath $VmsPath)) { return $false }
  return [bool](Get-ChildItem -LiteralPath $VmsPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { #Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  # 仅自动探测端口并连接
  .\MuMu-Connect-And-Set-Lawnchair.ps1

  # 连接 + 安装 + 设为默认桌面
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome

  # 指定 APK（相对路径默认相对脚本目录）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 只连某个多开序号（如 9 号机）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  依赖同目录布局：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,              # -1 = 自动连接所有在线实例
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts          # 不连 7555 等代理端口，只连配置文件里的真实端口
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
}

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @("MuMu\vms", "Netease\MuMu\vms", "Netease\MuMuPlayer\vms")) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-MuMuPortsFromConfig {
  param([string]$VmsRoot, [int]$OnlyIndex = -1)

  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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
        Index   = $idx
        VM      = $_.Name
        Port    = $port
        Source  = "vm_config"
        LogTime = $logTime
        Serial  = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  # 从 MuMuNxDevice 进程监听端口里找可能的 adb 口（兜底）
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }

  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        # MuMu 真实 adb 多在 16384+；代理口常见 7555 / 55xx
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } |
      ForEach-Object {
        $ports += [PSCustomObject]@{
          Index   = -1
          VM      = "MuMuNxDevice(pid=$($proc.Id))"
          Port    = [int]$_.LocalPort
          Source  = "listen"
          LogTime = Get-Date
          Serial  = "127.0.0.1:$($_.LocalPort)"
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
  } catch {
    return $false
  }
}

function Invoke-Adb {
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $Adb @Args 2>&1
}

# ---------------- main ----------------
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
if (-not $NoProxyPorts) {
  $listenPorts = @(Get-MuMuPortsFromListen)
}

# 合并候选：配置口优先，再加监听口
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
  $open = Test-TcpOpen -HostName "127.0.0.1" -Port $port
  if ($open) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}

if ($live.Count -eq 0) {
  Write-Err "配置里有端口，但当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
Invoke-Adb $adb start-server | Out-Null

$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial | Out-String).Trim()
  if ($out -match 'connected|already') {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
$devOut = Invoke-Adb $adb devices -l | Out-String
Write-Host $devOut

# 选主设备：配置文件端口 > 16384+ 真实端口 > 最近日志；避开 7555/55xx 代理口
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

# 导出给后续手动用
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray
Write-Host "  之后可直接: adb -s $serial shell ..." -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath | Out-String).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch 'Success') {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    Invoke-Adb $adb -s $serial uninstall $PackageName | Out-Null
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath | Out-String).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch 'Success') {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity | Out-String).Trim()
  if ($setOut) { Write-Host "  $setOut" }

  # 触发 Home 选择（若系统仍要确认）
  Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null

  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | Out-String).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher | Out-String).Trim()
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
  adb -s $serial install -r .\Lawnchair_app.lawnchair_signed.apk
  adb -s $serial shell cmd package set-home-activity $HomeActivity

"@ -ForegroundColor Green
.Name -like 'MuMuPlayer-*' -and (Test-Path (Join-Path #Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  # 仅自动探测端口并连接
  .\MuMu-Connect-And-Set-Lawnchair.ps1

  # 连接 + 安装 + 设为默认桌面
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome

  # 指定 APK（相对路径默认相对脚本目录）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 只连某个多开序号（如 9 号机）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  依赖同目录布局：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,              # -1 = 自动连接所有在线实例
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts          # 不连 7555 等代理端口，只连配置文件里的真实端口
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
}

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @("MuMu\vms", "Netease\MuMu\vms", "Netease\MuMuPlayer\vms")) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-MuMuPortsFromConfig {
  param([string]$VmsRoot, [int]$OnlyIndex = -1)

  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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
        Index   = $idx
        VM      = $_.Name
        Port    = $port
        Source  = "vm_config"
        LogTime = $logTime
        Serial  = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  # 从 MuMuNxDevice 进程监听端口里找可能的 adb 口（兜底）
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }

  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        # MuMu 真实 adb 多在 16384+；代理口常见 7555 / 55xx
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } |
      ForEach-Object {
        $ports += [PSCustomObject]@{
          Index   = -1
          VM      = "MuMuNxDevice(pid=$($proc.Id))"
          Port    = [int]$_.LocalPort
          Source  = "listen"
          LogTime = Get-Date
          Serial  = "127.0.0.1:$($_.LocalPort)"
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
  } catch {
    return $false
  }
}

function Invoke-Adb {
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $Adb @Args 2>&1
}

# ---------------- main ----------------
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
if (-not $NoProxyPorts) {
  $listenPorts = @(Get-MuMuPortsFromListen)
}

# 合并候选：配置口优先，再加监听口
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
  $open = Test-TcpOpen -HostName "127.0.0.1" -Port $port
  if ($open) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}

if ($live.Count -eq 0) {
  Write-Err "配置里有端口，但当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
Invoke-Adb $adb start-server | Out-Null

$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial | Out-String).Trim()
  if ($out -match 'connected|already') {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
$devOut = Invoke-Adb $adb devices -l | Out-String
Write-Host $devOut

# 选主设备：配置文件端口 > 16384+ 真实端口 > 最近日志；避开 7555/55xx 代理口
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

# 导出给后续手动用
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray
Write-Host "  之后可直接: adb -s $serial shell ..." -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath | Out-String).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch 'Success') {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    Invoke-Adb $adb -s $serial uninstall $PackageName | Out-Null
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath | Out-String).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch 'Success') {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity | Out-String).Trim()
  if ($setOut) { Write-Host "  $setOut" }

  # 触发 Home 选择（若系统仍要确认）
  Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null

  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | Out-String).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher | Out-String).Trim()
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
  adb -s $serial install -r .\Lawnchair_app.lawnchair_signed.apk
  adb -s $serial shell cmd package set-home-activity $HomeActivity

"@ -ForegroundColor Green
.FullName 'configs\vm_config.json')) } |
    Select-Object -First 1)
}

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { #Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  # 仅自动探测端口并连接
  .\MuMu-Connect-And-Set-Lawnchair.ps1

  # 连接 + 安装 + 设为默认桌面
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome

  # 指定 APK（相对路径默认相对脚本目录）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 只连某个多开序号（如 9 号机）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  依赖同目录布局：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,              # -1 = 自动连接所有在线实例
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts          # 不连 7555 等代理端口，只连配置文件里的真实端口
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
}

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @("MuMu\vms", "Netease\MuMu\vms", "Netease\MuMuPlayer\vms")) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-MuMuPortsFromConfig {
  param([string]$VmsRoot, [int]$OnlyIndex = -1)

  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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
        Index   = $idx
        VM      = $_.Name
        Port    = $port
        Source  = "vm_config"
        LogTime = $logTime
        Serial  = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  # 从 MuMuNxDevice 进程监听端口里找可能的 adb 口（兜底）
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }

  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        # MuMu 真实 adb 多在 16384+；代理口常见 7555 / 55xx
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } |
      ForEach-Object {
        $ports += [PSCustomObject]@{
          Index   = -1
          VM      = "MuMuNxDevice(pid=$($proc.Id))"
          Port    = [int]$_.LocalPort
          Source  = "listen"
          LogTime = Get-Date
          Serial  = "127.0.0.1:$($_.LocalPort)"
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
  } catch {
    return $false
  }
}

function Invoke-Adb {
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $Adb @Args 2>&1
}

# ---------------- main ----------------
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
if (-not $NoProxyPorts) {
  $listenPorts = @(Get-MuMuPortsFromListen)
}

# 合并候选：配置口优先，再加监听口
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
  $open = Test-TcpOpen -HostName "127.0.0.1" -Port $port
  if ($open) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}

if ($live.Count -eq 0) {
  Write-Err "配置里有端口，但当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
Invoke-Adb $adb start-server | Out-Null

$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial | Out-String).Trim()
  if ($out -match 'connected|already') {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
$devOut = Invoke-Adb $adb devices -l | Out-String
Write-Host $devOut

# 选主设备：配置文件端口 > 16384+ 真实端口 > 最近日志；避开 7555/55xx 代理口
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

# 导出给后续手动用
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray
Write-Host "  之后可直接: adb -s $serial shell ..." -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath | Out-String).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch 'Success') {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    Invoke-Adb $adb -s $serial uninstall $PackageName | Out-Null
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath | Out-String).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch 'Success') {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity | Out-String).Trim()
  if ($setOut) { Write-Host "  $setOut" }

  # 触发 Home 选择（若系统仍要确认）
  Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null

  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | Out-String).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher | Out-String).Trim()
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
  adb -s $serial install -r .\Lawnchair_app.lawnchair_signed.apk
  adb -s $serial shell cmd package set-home-activity $HomeActivity

"@ -ForegroundColor Green
.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-MuMuVmsRoot $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { #Requires -Version 5.1
<#
.SYNOPSIS
  自动获取 MuMu 模拟器 ADB 端口，连接设备，可选安装并设为默认桌面 Lawnchair。

.USAGE
  # 仅自动探测端口并连接
  .\MuMu-Connect-And-Set-Lawnchair.ps1

  # 连接 + 安装 + 设为默认桌面
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome

  # 指定 APK（相对路径默认相对脚本目录）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Install -SetHome -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 只连某个多开序号（如 9 号机）
  .\MuMu-Connect-And-Set-Lawnchair.ps1 -Index 9 -Install -SetHome

.NOTES
  依赖同目录布局：
    <scriptDir>\Adb\adb.exe
    <scriptDir>\Lawnchair_app.lawnchair_signed.apk
#>
[CmdletBinding()]
param(
  [string]$Apk = "Lawnchair_app.lawnchair_signed.apk",
  [string]$PackageName = "app.lawnchair",
  [string]$HomeActivity = "app.lawnchair/.LawnchairLauncher",
  [int]$Index = -1,              # -1 = 自动连接所有在线实例
  [switch]$Install,
  [switch]$SetHome,
  [switch]$DisableStockLauncher,
  [string]$StockLauncher = "com.google.android.apps.nexuslauncher",
  [switch]$NoProxyPorts          # 不连 7555 等代理端口，只连配置文件里的真实端口
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu ADB Auto Connect"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
}

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @("MuMu\vms", "Netease\MuMu\vms", "Netease\MuMuPlayer\vms")) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-MuMuPortsFromConfig {
  param([string]$VmsRoot, [int]$OnlyIndex = -1)

  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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
        Index   = $idx
        VM      = $_.Name
        Port    = $port
        Source  = "vm_config"
        LogTime = $logTime
        Serial  = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  # 从 MuMuNxDevice 进程监听端口里找可能的 adb 口（兜底）
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }

  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        # MuMu 真实 adb 多在 16384+；代理口常见 7555 / 55xx
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } |
      ForEach-Object {
        $ports += [PSCustomObject]@{
          Index   = -1
          VM      = "MuMuNxDevice(pid=$($proc.Id))"
          Port    = [int]$_.LocalPort
          Source  = "listen"
          LogTime = Get-Date
          Serial  = "127.0.0.1:$($_.LocalPort)"
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
  } catch {
    return $false
  }
}

function Invoke-Adb {
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $Adb @Args 2>&1
}

# ---------------- main ----------------
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
if (-not $NoProxyPorts) {
  $listenPorts = @(Get-MuMuPortsFromListen)
}

# 合并候选：配置口优先，再加监听口
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
  $open = Test-TcpOpen -HostName "127.0.0.1" -Port $port
  if ($open) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}

if ($live.Count -eq 0) {
  Write-Err "配置里有端口，但当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
Invoke-Adb $adb start-server | Out-Null

$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial | Out-String).Trim()
  if ($out -match 'connected|already') {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
$devOut = Invoke-Adb $adb devices -l | Out-String
Write-Host $devOut

# 选主设备：配置文件端口 > 16384+ 真实端口 > 最近日志；避开 7555/55xx 代理口
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

# 导出给后续手动用
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray
Write-Host "  之后可直接: adb -s $serial shell ..." -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath | Out-String).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch 'Success') {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    Invoke-Adb $adb -s $serial uninstall $PackageName | Out-Null
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath | Out-String).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch 'Success') {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity | Out-String).Trim()
  if ($setOut) { Write-Host "  $setOut" }

  # 触发 Home 选择（若系统仍要确认）
  Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null

  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | Out-String).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher | Out-String).Trim()
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
  adb -s $serial install -r .\Lawnchair_app.lawnchair_signed.apk
  adb -s $serial shell cmd package set-home-activity $HomeActivity

"@ -ForegroundColor Green
 }
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
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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
        Index   = $idx
        VM      = $_.Name
        Port    = $port
        Source  = "vm_config"
        LogTime = $logTime
        Serial  = "127.0.0.1:$port"
      }
    } catch {
      Write-Warn "解析失败: $cfgPath"
    }
  }
  return $list | Sort-Object Index
}

function Get-MuMuPortsFromListen {
  # 从 MuMuNxDevice 进程监听端口里找可能的 adb 口（兜底）
  $procs = Get-Process MuMuNxDevice -ErrorAction SilentlyContinue
  if (-not $procs) { return @() }

  $ports = @()
  foreach ($proc in $procs) {
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        # MuMu 真实 adb 多在 16384+；代理口常见 7555 / 55xx
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        ($_.LocalPort -eq 7555) -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } |
      ForEach-Object {
        $ports += [PSCustomObject]@{
          Index   = -1
          VM      = "MuMuNxDevice(pid=$($proc.Id))"
          Port    = [int]$_.LocalPort
          Source  = "listen"
          LogTime = Get-Date
          Serial  = "127.0.0.1:$($_.LocalPort)"
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
  } catch {
    return $false
  }
}

function Invoke-Adb {
  param([string]$Adb, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $Adb @Args 2>&1
}

# ---------------- main ----------------
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
if (-not $NoProxyPorts) {
  $listenPorts = @(Get-MuMuPortsFromListen)
}

# 合并候选：配置口优先，再加监听口
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
  $open = Test-TcpOpen -HostName "127.0.0.1" -Port $port
  if ($open) {
    Write-Ok "端口开放: $($info.Serial)  [$($info.Source)] $($info.VM)"
    $live += $info
  } else {
    Write-Host "  [ ] 未开放: $($info.Serial)  $($info.VM)" -ForegroundColor DarkGray
  }
}

if ($live.Count -eq 0) {
  Write-Err "配置里有端口，但当前没有在线实例。请先打开 MuMu 模拟器。"
  exit 1
}

Write-Step "连接 adb"
Invoke-Adb $adb start-server | Out-Null

$connected = @()
foreach ($item in $live) {
  $out = (Invoke-Adb $adb connect $item.Serial | Out-String).Trim()
  if ($out -match 'connected|already') {
    Write-Ok "$($item.Serial) -> $out"
    $connected += $item
  } else {
    Write-Warn "$($item.Serial) -> $out"
  }
}

Start-Sleep -Milliseconds 500
Write-Step "当前 devices"
$devOut = Invoke-Adb $adb devices -l | Out-String
Write-Host $devOut

# 选主设备：配置文件端口 > 16384+ 真实端口 > 最近日志；避开 7555/55xx 代理口
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

# 导出给后续手动用
$env:MUMU_ADB_SERIAL = $serial
$env:MUMU_ADB_PORT = "$($primary.Port)"
Write-Host "  环境变量已设置: MUMU_ADB_SERIAL=$serial" -ForegroundColor DarkGray
Write-Host "  之后可直接: adb -s $serial shell ..." -ForegroundColor DarkGray

if ($Install) {
  Write-Step "安装 Lawnchair"
  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    Write-Err "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
    exit 1
  }
  Write-Ok "apk: $apkPath"

  $installOut = (Invoke-Adb $adb -s $serial install -r $apkPath | Out-String).Trim()
  Write-Host "  $installOut"
  if ($installOut -notmatch 'Success') {
    Write-Warn "安装可能失败，尝试先卸载再装..."
    Invoke-Adb $adb -s $serial uninstall $PackageName | Out-Null
    $installOut = (Invoke-Adb $adb -s $serial install $apkPath | Out-String).Trim()
    Write-Host "  $installOut"
    if ($installOut -notmatch 'Success') {
      Write-Err "安装失败"
      exit 1
    }
  }
  Write-Ok "安装成功"
}

if ($SetHome) {
  Write-Step "设为默认桌面"
  $setOut = (Invoke-Adb $adb -s $serial shell cmd package set-home-activity $HomeActivity | Out-String).Trim()
  if ($setOut) { Write-Host "  $setOut" }

  # 触发 Home 选择（若系统仍要确认）
  Invoke-Adb $adb -s $serial shell am start -a android.intent.action.MAIN -c android.intent.category.HOME | Out-Null

  $resolved = (Invoke-Adb $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | Out-String).Trim()
  Write-Host "  当前 HOME: $resolved"
  if ($resolved -match [regex]::Escape($PackageName)) {
    Write-Ok "已是默认桌面"
  } else {
    Write-Warn "若未切换成功，请在模拟器弹窗中选择 Lawnchair → 始终"
  }
}

if ($DisableStockLauncher) {
  Write-Step "禁用原系统桌面: $StockLauncher"
  $d = (Invoke-Adb $adb -s $serial shell pm disable-user --user 0 $StockLauncher | Out-String).Trim()
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
  adb -s $serial install -r .\Lawnchair_app.lawnchair_signed.apk
  adb -s $serial shell cmd package set-home-activity $HomeActivity

"@ -ForegroundColor Green
