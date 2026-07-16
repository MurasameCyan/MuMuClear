#Requires -Version 5.1
<#
.SYNOPSIS
  MuMu + Lawnchair 一键工具（连接 / 安装默认桌面 / 黑屏救援）

.DESCRIPTION
  把改包名后的 Lawnchair（app.lawnchair）装到 MuMu，并设为默认桌面。

  ============================================================
  目录布局（全部相对本脚本所在目录，不写死盘符）
  ============================================================
    <脚本目录>\
      Lawnchair-MuMu.ps1                  # 主入口（本文件）
      Lawnchair_app.lawnchair_signed.apk  # 改包名后的 APK
      Adb\
        adb.exe                           # 便携 ADB
        AdbWinApi.dll / AdbWinUsbApi.dll  # Windows ADB 依赖
      Replace-System-Launcher.ps1         # 旧入口，转发到本脚本
      MuMu-Connect-And-Set-Lawnchair.ps1  # 旧入口，默认只连接

  ============================================================
  快速开始
  ============================================================
  1. 先启动 MuMu，进入安卓系统
  2. 在脚本目录打开 PowerShell：
       cd <脚本目录>
       .\Lawnchair-MuMu.ps1
  3. 等待安装完成；按 Home 应进入 Lawnchair
  4. 数据目录：/data/user/0/app.lawnchair

  若 ExecutionPolicy 拦截：
       powershell -NoProfile -ExecutionPolicy Bypass -File .\Lawnchair-MuMu.ps1

  查看本帮助：
       .\Lawnchair-MuMu.ps1 -Help
       Get-Help .\Lawnchair-MuMu.ps1 -Full

  ============================================================
  常用命令
  ============================================================
  # 默认：自动连 MuMu + 用户安装 + 设默认桌面（推荐）
  .\Lawnchair-MuMu.ps1

  # 只连接，不装包
  .\Lawnchair-MuMu.ps1 -ConnectOnly

  # 指定多开序号（看 MuMu 多开器序号，如 9 号机）
  .\Lawnchair-MuMu.ps1 -Index 9

  # 黑屏救援（卡在 Android 标志 / FallbackHome）
  .\Lawnchair-MuMu.ps1 -RecoverOnly

  # 指定 APK 文件名（相对脚本目录）
  .\Lawnchair-MuMu.ps1 -Apk "Lawnchair_app.lawnchair_signed.apk"

  # 安装后顺便禁用原系统桌面包（可选）
  .\Lawnchair-MuMu.ps1 -DisableStockLauncher -StockLauncher com.android.launcher3

  # 危险：覆盖 /system/priv-app（需与原系统签名一致；testkey 包会黑屏）
  .\Lawnchair-MuMu.ps1 -ForceSystemPrivApp
  .\Lawnchair-MuMu.ps1 -ForceSystemPrivApp -SkipReboot

  ============================================================
  参数说明
  ============================================================
  -Apk                   APK 路径。相对路径相对【脚本目录】，不是当前目录。
                         默认：Lawnchair_app.lawnchair_signed.apk
  -PackageName           包名。默认 app.lawnchair
  -HomeActivity          桌面 Activity。默认 app.lawnchair/.LawnchairLauncher
  -Index                 MuMu 多开序号。-1=自动选在线实例（默认）
  -ConnectOnly           只探测端口并 adb connect，不安装
  -RecoverOnly           黑屏救援：删 priv-app 冲突 + 确保用户包 + 设 HOME + 拉起
  -ForceSystemPrivApp    危险：推到 /system/priv-app/Lawnchair 并尝试系统安装
  -SkipReboot            仅 ForceSystem 时跳过重启
  -DisableStockLauncher  安装后禁用原桌面包（见 -StockLauncher）
  -StockLauncher         要禁用的原桌面包名
  -NoProxyPorts          不连 7555/55xx 代理口，只连配置文件真实端口
  -Help                  打印使用说明后退出

  ConnectOnly / RecoverOnly / ForceSystemPrivApp 三选一，不能同时开。

  ============================================================
  默认模式实际做了什么
  ============================================================
  1) 读 MuMu vms 配置 + 监听端口，自动 adb connect
  2) adb root
  3) 删除 /system/priv-app/Lawnchair（避免签名冲突）
  4) 用户空间 install -r -g 安装 APK
  5) cmd package set-home-activity 设默认桌面
  6) 拉起 Lawnchair 并打印状态

  ============================================================
  为什么不要直接覆盖系统桌面
  ============================================================
  MuMu 原系统 Lawnchair 是官方签名。
  本仓库 APK 是 testkey 重签。
  用重签包覆盖 /system/priv-app 后，重启 PackageManager 扫包失败，
  系统只剩 com.android.settings/.FallbackHome → 黑屏。

  稳定方案：用户安装 + 默认 HOME。
  数据目录仍是：/data/user/0/app.lawnchair

  黑了就跑：
       .\Lawnchair-MuMu.ps1 -RecoverOnly

  ============================================================
  连接原理（自动拿端口）
  ============================================================
  1) 找 MuMu 进程路径，向上找 vms 目录
  2) 读 <vms>\MuMuPlayer-*-N\configs\vm_config.json
     字段：vm.nat.port_forward.adb.host_port
  3) TCP 探测端口是否在线，再 adb connect 127.0.0.1:<port>
  4) 优先选配置端口（通常 16384+），避开 7555 代理口

  ============================================================
  装好后常用 adb
  ============================================================
  # 脚本会设置环境变量 MUMU_ADB_SERIAL
  $adb = ".\Adb\adb.exe"
  $s   = $env:MUMU_ADB_SERIAL   # 例如 127.0.0.1:16672

  & $adb -s $s shell
  & $adb -s $s shell pm path app.lawnchair
  & $adb -s $s shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

  ============================================================
  故障排查
  ============================================================
  adb devices 空白
    -> 先开 MuMu；再 .\Lawnchair-MuMu.ps1 -ConnectOnly
  找不到 adb.exe
    -> 确认 <脚本目录>\Adb\adb.exe 存在
  找不到 APK
    -> 确认 <脚本目录>\Lawnchair_app.lawnchair_signed.apk 存在
  安装失败 UPDATE_INCOMPATIBLE
    -> 脚本会先 uninstall；仍失败就手动：
       .\Adb\adb.exe -s <serial> uninstall app.lawnchair
  黑屏 / FallbackHome
    -> .\Lawnchair-MuMu.ps1 -RecoverOnly
  按 Home 仍回原桌面
    -> 再跑默认安装；或加 -DisableStockLauncher
  ForceSystem 后黑屏
    -> 立刻 -RecoverOnly；不要再对 testkey 包用 ForceSystem

  ============================================================
  旧脚本兼容
  ============================================================
  .\Replace-System-Launcher.ps1
    -> 转发到本脚本（参数原样传递）

  .\MuMu-Connect-And-Set-Lawnchair.ps1
    -> 默认等价 -ConnectOnly
    -> 若带 -Install 或 -SetHome，则走完整安装
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
  [switch]$NoProxyPorts,
  [Alias("h","?")]
  [switch]$Help
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Lawnchair MuMu"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$AdbDir = Join-Path $ScriptDir "Adb"

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "  [X] $m" -ForegroundColor Red }

function Show-Usage {
  $lines = @(
    "============================================================",
    "Lawnchair-MuMu.ps1 使用说明",
    "============================================================",
    "",
    "目录布局（相对脚本目录）：",
    "  Adb\adb.exe",
    "  Lawnchair_app.lawnchair_signed.apk",
    "  Lawnchair-MuMu.ps1",
    "",
    "快速开始：",
    "  1. 启动 MuMu",
    "  2. cd 到脚本目录",
    "  3. .\Lawnchair-MuMu.ps1   # 安装后自动防卡住校验",
    "",
    "常用命令：",
    "  .\Lawnchair-MuMu.ps1                  # 连接+安装+默认桌面（推荐）",
    "  .\Lawnchair-MuMu.ps1 -ConnectOnly     # 只连接",
    "  .\Lawnchair-MuMu.ps1 -RecoverOnly     # 黑屏救援",
    "  .\Lawnchair-MuMu.ps1 -Index 9         # 指定多开",
    "  .\Lawnchair-MuMu.ps1 -Apk xxx.apk     # 指定 APK（相对脚本目录）",
    "  .\Lawnchair-MuMu.ps1 -DisableStockLauncher",
    "  .\Lawnchair-MuMu.ps1 -ForceSystemPrivApp   # 危险，testkey 易黑屏",
    "  .\Lawnchair-MuMu.ps1 -Help",
    "",
    "参数：",
    "  -Apk -PackageName -HomeActivity -Index",
    "  -ConnectOnly -RecoverOnly -ForceSystemPrivApp -SkipReboot",
    "  -DisableStockLauncher -StockLauncher -NoProxyPorts -Help",
    "",
    "默认流程：",
    "  自动连 MuMu -> root -> 删 priv-app 冲突 -> 用户安装 -> 设 HOME -> 防卡住救援",
    "",
    "黑屏原因：",
    "  testkey 包覆盖 /system/priv-app 会导致 FallbackHome。",
    "  默认模式用【用户安装】，稳定。数据目录 /data/user/0/app.lawnchair",
    "",
    "黑了就跑：",
    "  .\Lawnchair-MuMu.ps1 -RecoverOnly",
    "",
    "更完整的说明写在脚本顶部注释里：",
    "  Get-Content .\Lawnchair-MuMu.ps1 -TotalCount 160",
    "  或 Get-Help .\Lawnchair-MuMu.ps1 -Full"
  )
  Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Green
}

function Resolve-ScriptPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if ([IO.Path]::IsPathRooted($Path)) { return $Path }
  return [IO.Path]::GetFullPath((Join-Path $ScriptDir $Path))
}

function Find-Adb {
  foreach ($p in @((Join-Path $AdbDir "adb.exe"), (Join-Path $ScriptDir "adb.exe"))) {
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请放到脚本同目录 Adb\adb.exe`n也可运行: .\Lawnchair-MuMu.ps1 -Help"
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
  if (-not $vms) { throw "未找到 MuMu vms 目录。先启动 MuMu，或查看: .\Lawnchair-MuMu.ps1 -Help" }
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
  else { Write-Warn "若未切换成功，请在模拟器弹窗选择 Lawnchair -> 始终" }
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
    return $true
  }
  if ($homeInfo -match "FallbackHome") {
    Write-Warn "检测到 FallbackHome 黑屏状态"
  } else {
    Write-Warn "桌面尚未就绪"
  }
  return $false
}

function Test-IsFallbackHome([string]$AdbPath, [string]$Serial) {
  $homeInfo = (Invoke-Adb $AdbPath -s $Serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
  $focus = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys window | grep mCurrentFocus").Trim()
  return ($homeInfo -match "FallbackHome") -or ($focus -match "FallbackHome")
}

function Ensure-HomeReady([string]$AdbPath, [string]$Serial, [string]$ApkPath, [int]$MaxTries = 2) {
  Write-Step "防卡住校验（安装后自动救援）"
  for ($i = 1; $i -le $MaxTries; $i++) {
    # 清系统冲突 + 确保用户包 + HOME + 拉起
    Ensure-Root $AdbPath $Serial
    Remove-SystemPrivAppConflict $AdbPath $Serial

    $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
    if ($path -notmatch "package:") {
      Write-Warn "第 $i 次：包不存在，重新安装"
      $full = (Resolve-Path -LiteralPath $ApkPath).Path
      $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
      $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
      Write-Host "  $out"
      if ($out -notmatch "Success") { throw "防卡住安装失败: $out" }
    } else {
      Write-Ok "第 $i 次：已有包 $path"
    }

    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
    $null = Invoke-Adb $AdbPath -s $Serial shell "am force-stop $PackageName"
    $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
    Start-Sleep -Seconds 2
    $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
    Start-Sleep -Seconds 1

    if (Show-Status $AdbPath $Serial) { return $true }

    if (Test-IsFallbackHome $AdbPath $Serial) {
      Write-Warn "第 $i 次仍 FallbackHome，执行完整救援..."
      Recover-FallbackHome $AdbPath $Serial $ApkPath
      Start-Sleep -Seconds 1
      if (Show-Status $AdbPath $Serial) { return $true }
    }
  }
  return (Show-Status $AdbPath $Serial)
}

try {
  if ($Help) {
    Show-Usage
    exit 0
  }

  if (($ConnectOnly.IsPresent -and $RecoverOnly.IsPresent) -or
      ($ConnectOnly.IsPresent -and $ForceSystemPrivApp.IsPresent) -or
      ($RecoverOnly.IsPresent -and $ForceSystemPrivApp.IsPresent)) {
    throw "ConnectOnly / RecoverOnly / ForceSystemPrivApp 只能选一个。查看: .\Lawnchair-MuMu.ps1 -Help"
  }

  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not $ConnectOnly) {
    if (-not (Test-Path -LiteralPath $apkPath)) {
      throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk`n查看: .\Lawnchair-MuMu.ps1 -Help"
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
    Write-Host ""
    Write-Host "主设备: $serial" -ForegroundColor Green
    Write-Host "端口  : $($dev.Port)" -ForegroundColor Green
    # 连接后也探测是否卡在 FallbackHome，给提示
    if (Test-IsFallbackHome $adb $serial) {
      Write-Warn "当前设备卡在 FallbackHome。请运行: .\Lawnchair-MuMu.ps1 -RecoverOnly"
    }
    Write-Host ""
    Write-Host "之后可用:" -ForegroundColor Green
    Write-Host "  & `"$adb`" -s $serial shell"
    Write-Host "  .\Lawnchair-MuMu.ps1            # 继续安装默认桌面（含防卡住）"
    Write-Host "  .\Lawnchair-MuMu.ps1 -RecoverOnly"
    Write-Host "  .\Lawnchair-MuMu.ps1 -Help"
    exit 0
  }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    $null = Ensure-HomeReady $adb $serial $apkPath 2
    exit 0
  }

  # 若一上来就卡 FallbackHome，先救一次再继续安装
  if (Test-IsFallbackHome $adb $serial) {
    Write-Warn "连接后发现 FallbackHome，先自动救援"
    Recover-FallbackHome $adb $serial $apkPath
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
      }
    }
  } else {
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

  # 关键：替换完成后强制跑防卡住流程，防止 FallbackHome 黑屏
  $ready = Ensure-HomeReady $adb $serial $apkPath 2
  if (-not $ready) {
    throw "安装完成但仍卡在 FallbackHome，请检查 APK 签名/包名，或手动: .\Lawnchair-MuMu.ps1 -RecoverOnly"
  }

  Write-Step "完成"
  Write-Host ""
  Write-Host "设备: $serial" -ForegroundColor Green
  Write-Host "包名: $PackageName" -ForegroundColor Green
  Write-Host "数据: /data/user/0/$PackageName" -ForegroundColor Green
  Write-Host ("模式: " + $(if ($ForceSystemPrivApp) { "ForceSystemPrivApp(危险)" } else { "用户安装 + 默认HOME(推荐)" })) -ForegroundColor Green
  Write-Host "防卡住: 已自动校验/救援通过" -ForegroundColor Green
  Write-Host ""
  Write-Host "常用:" -ForegroundColor Green
  Write-Host "  .\Lawnchair-MuMu.ps1              # 默认安装（含防卡住）"
  Write-Host "  .\Lawnchair-MuMu.ps1 -ConnectOnly # 只连接"
  Write-Host "  .\Lawnchair-MuMu.ps1 -RecoverOnly # 黑屏救援"
  Write-Host "  .\Lawnchair-MuMu.ps1 -Help        # 使用说明"
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  Write-Host "  查看用法: .\Lawnchair-MuMu.ps1 -Help" -ForegroundColor Yellow
  Write-Host "  黑屏救援: .\Lawnchair-MuMu.ps1 -RecoverOnly" -ForegroundColor Yellow
  exit 1
}