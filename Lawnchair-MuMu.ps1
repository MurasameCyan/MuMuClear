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

  # 特权安装（修复点击图标“未安装”）：priv-app + privapp XML + recents overlay
  .\Lawnchair-MuMu.ps1 -PrivilegedInstall
  # 兼容旧开关名（同 PrivilegedInstall）
  .\Lawnchair-MuMu.ps1 -ForceSystemPrivApp

  ============================================================
  参数说明
  ============================================================
  -Apk                   APK 路径。相对路径相对【脚本目录】，不是当前目录。
                         默认：Lawnchair_app.lawnchair_signed.apk
  -PackageName           包名。默认 app.lawnchair
  -HomeActivity          桌面 Activity。默认 app.lawnchair/.LawnchairLauncher
  -Index                 MuMu 多开序号。-1=自动选在线实例（默认）
  -ConnectOnly           只探测端口并 adb connect，不安装
  -RecoverOnly           黑屏/回滚：重启 -> 清 priv-app/overlay -> 用户安装 -> 设 HOME
  -PrivilegedInstall     推荐修复“未安装”：系统 priv-app + recents overlay + 重启
  -ForceSystemPrivApp    兼容别名，等价 -PrivilegedInstall
  -SkipReboot            跳过重启（特权安装几乎总是需要重启，慎用）
  -UserInstallOnly       仅用户空间安装（会“未安装”，仅调试用）
  -DisableStockLauncher  安装后禁用原桌面包（见 -StockLauncher）
  -StockLauncher         要禁用的原桌面包名
  -NoProxyPorts          不连 7555/55xx 代理口，只连配置文件真实端口
  -Help                  打印使用说明后退出

  ConnectOnly / RecoverOnly / PrivilegedInstall 三选一，不能同时开。

  ============================================================
  默认模式实际做了什么（PrivilegedInstall）
  ============================================================
  1) 读 MuMu vms 配置 + 监听端口，自动 adb connect
  2) adb root
  3) 安装 static RRO：config_recentsComponentName=app.lawnchair/...RecentsActivity
  4) 写入 /system/etc/permissions/privapp-permissions-app.lawnchair.xml
  5) 推送 APK 到 /system/priv-app/app.lawnchair/（SYSTEM+PRIVILEGED）
  6) 重启，PackageManager 授予 MANAGE_ACTIVITY_TASKS 等
  7) set-home-activity + 拉起 Lawnchair
  数据目录仍是：/data/user/0/app.lawnchair

  ============================================================
  为什么用户安装会“未安装”
  ============================================================
  Lawnchair 16 Quickstep 启动图标会带 remoteAnimationAdapter。
  这需要 android.permission.MANAGE_ACTIVITY_TASKS（signature|recents）
  与 CONTROL_REMOTE_APP_TRANSITION_ANIMATIONS（signature|privileged|recents）。
  用户安装无法获得这些权限 → SecurityException → 误报“未安装该应用”。
  修复：系统 priv-app + recents overlay（把 Lawnchair 标为 recents 组件）。

  旧的裸 ForceSystem（无 path、无 privapp XML、无 recents）会 FallbackHome。
  本脚本的 -PrivilegedInstall 是实测可用路径。

  ============================================================
  TouchInteractionService 崩：No layoutter found
  ============================================================
  MuMu 大屏/平板类 profile 上，Lawnchair 16 会硬开
  FeatureFlags.ENABLE_TASKBAR_NAVBAR_UNIFICATION=true，
  于是 isTaskbarEnabled 恒 true；但 isTaskbarPresent=false 且
  isPhoneMode=false 时，getUiLayoutter 抛 IllegalStateException
  "No layoutter found"，TouchInteractionService 起不来，
  焦点常卡在 NotificationShade。

  交付 APK（Lawnchair_app.lawnchair_signed.apk）已对 classes.dex
  做同尺寸二进制补丁：把 FeatureFlags.<clinit> 里
  const/4 v1,1 改为 const/4 v1,0（关闭 unification）。
  重建：python binpatch_unification_flag.py
  然后 zipalign + apksigner（testkey）。
  勿用 smali 整包重编：会出 DEX041，ART 报 Header size 112/120。

  验证（例 127.0.0.1:16384）：
    - 冷启动无 No layoutter found / 无 Application Error
    - mCurrentFocus=app.lawnchair/.LawnchairLauncher
    - dock 图标可启动；Home / 多任务可回桌面

  回滚/黑屏救援：
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
  No layoutter found / 桌面起不来（TouchInteractionService）
    -> 确认 APK 已用 binpatch_unification_flag.py 关闭
       ENABLE_TASKBAR_NAVBAR_UNIFICATION；再 -PrivilegedInstall 或
       覆盖 /system/priv-app/app.lawnchair/app.lawnchair.apk 后 reboot

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
  [string]$RecentsActivity = "app.lawnchair/com.android.quickstep.RecentsActivity",
  [int]$Index = -1,
  [switch]$ConnectOnly,
  [switch]$RecoverOnly,
  [Alias("ForceSystemPrivApp")]
  [switch]$PrivilegedInstall,
  [switch]$UserInstallOnly,
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
    "  .\Lawnchair-MuMu.ps1 -RecoverOnly     # 黑屏救援（会先重启模拟器）",
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
    "  .\Lawnchair-MuMu.ps1 -RecoverOnly   # 会先 reboot 再救援",
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

function Wait-BootReady([string]$AdbPath, [string]$Serial, [int]$TimeoutSec = 180) {
  Write-Step "等待模拟器启动完成"
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if ($Serial -match "^127\.0\.0\.1:") { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state 2>$null).Trim()
    if ($state -eq "device") {
      $boot = (Invoke-Adb $AdbPath -s $Serial shell getprop sys.boot_completed 2>$null).Trim()
      $anim = (Invoke-Adb $AdbPath -s $Serial shell getprop init.svc.bootanim 2>$null).Trim()
      # boot_completed=1 且 bootanim 停止/空 视为可操作
      if ($boot -eq "1" -and ($anim -eq "stopped" -or [string]::IsNullOrWhiteSpace($anim))) {
        # 再等一下 Settings/PM 就绪
        Start-Sleep -Seconds 3
        Write-Ok "boot_completed=1"
        return $true
      }
      Write-Host "  boot=$boot anim=$anim ..." -ForegroundColor DarkGray
    } else {
      Write-Host "  state=$state ..." -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds 3
  }
  return $false
}

function Reboot-And-Reconnect([string]$AdbPath, [string]$Serial, [int]$TimeoutSec = 180) {
  Write-Step "重启模拟器（FallbackHome 硬救援必需）"
  # 尽量 root 后再 reboot，失败也继续
  try { $null = Invoke-Adb $AdbPath -s $Serial root } catch {}
  Start-Sleep -Seconds 1
  if ($Serial -match "^127\.0\.0\.1:") { $null = Invoke-Adb $AdbPath connect $Serial }
  $null = Invoke-Adb $AdbPath -s $Serial reboot
  Write-Ok "已发送 reboot，等待掉线再重连..."
  Start-Sleep -Seconds 8

  # 重启期间持续 connect，直到 boot ready
  if (-not (Wait-BootReady $AdbPath $Serial $TimeoutSec)) {
    throw "重启后等待启动超时（$TimeoutSec 秒）。请确认 MuMu 已起来后再跑 -RecoverOnly"
  }
  # 启动后重新 root（很多环境 reboot 后 adbd 掉 root）
  $null = Invoke-Adb $AdbPath -s $Serial root
  Start-Sleep -Seconds 2
  if ($Serial -match "^127\.0\.0\.1:") { $null = Invoke-Adb $AdbPath connect $Serial }
  if (-not (Wait-Device $AdbPath $Serial 60)) {
    throw "重启后 root/重连失败: $Serial"
  }
  Write-Ok "重启完成，设备可操作"
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
  Write-Step "移除系统 priv-app 冲突（避免 FallbackHome / 签名冲突）"
  # MuMu 常见系统路径：
  #   /system/priv-app/Lawnchair
  #   /system/priv-app/app.lawnchair   <--- 很多机型是这个，之前漏删会导致 UPDATE_INCOMPATIBLE
  # 同时清 recents overlay + privapp xml（RecoverOnly 回滚特权安装）
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1; pm uninstall --user 0 $PackageName >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell @"
rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair \
       /system/priv-app/app.lawnchair /system/app/app.lawnchair \
       /system/priv-app/lawnchair /system/app/lawnchair \
       /product/priv-app/Lawnchair /product/priv-app/app.lawnchair \
       /system_ext/priv-app/Lawnchair /system_ext/priv-app/app.lawnchair \
       /data/app/*lawnchair* /data/app/*Lawnchair* 2>/dev/null
rm -f /system/etc/permissions/privapp-permissions-app.lawnchair.xml \
      /product/overlay/LawnchairRecentsOverlay.apk \
      /system/product/overlay/LawnchairRecentsOverlay.apk \
      /vendor/overlay/LawnchairRecentsOverlay.apk 2>/dev/null
"@
  # 按 pm path 再扫尾
  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName 2>$null).Trim()
  if ($path -match "package:(.+)$") {
    $apkFile = $Matches[1].Trim()
    Write-Warn "仍见包路径: $apkFile ，强制删除"
    $dir = Split-Path $apkFile -Parent
    $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf `"$apkFile`" `"$dir`""
    $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1"
  }
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -iE 'lawn|app\.lawn' || echo CLEAN").Trim()
  $path2 = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName 2>$null).Trim()
  Write-Ok "system lawn dirs: $check ; pm path: $(if ($path2) { $path2 } else { 'none' })"
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

function Install-Or-Repair-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  if (-not (Test-Path -LiteralPath $ApkPath)) { throw "需要 APK: $ApkPath" }
  $full = (Resolve-Path -LiteralPath $ApkPath).Path

  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  # 关键：无论原先有没有包，都先卸再装用户版。
  # 系统 priv-app 签名与 testkey 不一致时，-r 会 UPDATE_INCOMPATIBLE。
  Write-Step "安装用户版 Lawnchair（强制卸旧包）"
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1; pm uninstall --user 0 $PackageName >/dev/null 2>&1; rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair /system/priv-app/app.lawnchair /system/app/app.lawnchair"

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch "Success") {
    # 再清一次系统残留后重试
    Write-Warn "安装失败，二次清理后重试..."
    Remove-SystemPrivAppConflict $AdbPath $Serial
    $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
    $out = (Invoke-Adb $AdbPath -s $Serial install -g $full).Trim()
    Write-Host "  retry: $out"
    if ($out -notmatch "Success") { throw "安装失败: $out" }
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Ok "pm path: $path"
  if ($path -match "/system/") {
    throw "包仍落在 system 分区（$path），签名冲突风险高。请确认已删 /system/priv-app/Lawnchair"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am force-stop $PackageName"
  $start = (Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity -W").Trim()
  Write-Host "  $start"
  Start-Sleep -Seconds 2
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
  Start-Sleep -Seconds 1
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath, [switch]$SkipReboot) {
  Write-Step "救援 FallbackHome 黑屏"
  # 实测：卡在 FallbackHome 时仅 adb 救援经常无效，必须先重启模拟器
  if (-not $SkipReboot) {
    Reboot-And-Reconnect $AdbPath $Serial 180
  } else {
    Write-Warn "SkipReboot：跳过重启，仅软救援（可能无效）"
    if (-not (Wait-Device $AdbPath $Serial 30)) { throw "设备未就绪" }
  }

  Install-Or-Repair-UserHome $AdbPath $Serial $ApkPath
  if (Show-Status $AdbPath $Serial) { return $true }

  # 重启后仍失败，再软修一轮
  Write-Warn "重启救援后仍未就绪，再修一轮..."
  Install-Or-Repair-UserHome $AdbPath $Serial $ApkPath
  return (Show-Status $AdbPath $Serial)
}

function Get-PrivAppPermissionsXml {
  return @"
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="app.lawnchair">
        <permission name="android.permission.CONTROL_REMOTE_APP_TRANSITION_ANIMATIONS"/>
        <permission name="android.permission.STATUS_BAR"/>
        <permission name="android.permission.STATUS_BAR_SERVICE"/>
        <permission name="android.permission.FORCE_STOP_PACKAGES"/>
        <permission name="android.permission.MANAGE_USERS"/>
        <permission name="android.permission.BROADCAST_CLOSE_SYSTEM_DIALOGS"/>
        <permission name="android.permission.START_TASKS_FROM_RECENTS"/>
        <permission name="android.permission.STOP_APP_SWITCHES"/>
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
        <permission name="android.permission.INTERACT_ACROSS_USERS"/>
        <permission name="android.permission.INTERACT_ACROSS_USERS_FULL"/>
        <permission name="android.permission.INTERNAL_SYSTEM_WINDOW"/>
        <permission name="android.permission.MANAGE_ACTIVITY_TASKS"/>
        <permission name="android.permission.REMOVE_TASKS"/>
        <permission name="android.permission.READ_FRAME_BUFFER"/>
        <permission name="android.permission.MONITOR_INPUT"/>
        <permission name="android.permission.SYSTEM_APPLICATION_OVERLAY"/>
        <permission name="android.permission.SUSPEND_APPS"/>
    </privapp-permissions>
</permissions>
"@
}

function Install-RecentsOverlay([string]$AdbPath, [string]$Serial) {
  Write-Step "安装 recents overlay (config_recentsComponentName)"
  $overlayLocal = Join-Path $ScriptDir "LawnchairRecentsOverlay.apk"
  if (-not (Test-Path -LiteralPath $overlayLocal)) {
    throw "缺少 LawnchairRecentsOverlay.apk（应与脚本同目录）。该 RRO 把 Lawnchair 标为 recents 组件。"
  }
  $full = (Resolve-Path -LiteralPath $overlayLocal).Path
  $null = Invoke-Adb $AdbPath -s $Serial shell "mkdir -p /product/overlay /system/product/overlay"
  $null = Invoke-Adb $AdbPath -s $Serial push $full /data/local/tmp/LawnchairRecentsOverlay.apk
  $null = Invoke-Adb $AdbPath -s $Serial shell @"
cp /data/local/tmp/LawnchairRecentsOverlay.apk /product/overlay/LawnchairRecentsOverlay.apk
cp /data/local/tmp/LawnchairRecentsOverlay.apk /system/product/overlay/LawnchairRecentsOverlay.apk 2>/dev/null
chmod 644 /product/overlay/LawnchairRecentsOverlay.apk
chown root:root /product/overlay/LawnchairRecentsOverlay.apk
ls -la /product/overlay/LawnchairRecentsOverlay.apk
"@
  Write-Ok "overlay 已推送: /product/overlay/LawnchairRecentsOverlay.apk"
}

function Remove-RecentsOverlay([string]$AdbPath, [string]$Serial) {
  Write-Step "移除 recents overlay"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -f /product/overlay/LawnchairRecentsOverlay.apk /system/product/overlay/LawnchairRecentsOverlay.apk /vendor/overlay/LawnchairRecentsOverlay.apk 2>/dev/null"
}

function Install-PrivilegedHome([string]$AdbPath, [string]$Serial, [string]$ApkPath, [switch]$SkipReboot) {
  Write-Step "特权安装: priv-app + privapp-permissions + recents overlay"
  Write-Host "  修复用户安装时点击图标 '未安装'（remoteAnimation / MANAGE_ACTIVITY_TASKS）" -ForegroundColor DarkGray
  if (-not (Test-Path -LiteralPath $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path -LiteralPath $ApkPath).Path

  Ensure-Root $AdbPath $Serial

  # 卸用户副本，避免与 system 冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1; pm uninstall --user 0 $PackageName >/dev/null 2>&1"

  # 旧目录清理 + 规范路径 /system/priv-app/app.lawnchair
  $null = Invoke-Adb $AdbPath -s $Serial shell @"
rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair \
       /system/priv-app/lawnchair /system/app/lawnchair \
       /system/priv-app/app.lawnchair /system/app/app.lawnchair
mkdir -p /system/priv-app/app.lawnchair
"@

  Install-RecentsOverlay $AdbPath $Serial

  # privapp-permissions XML
  $xmlLocal = Join-Path $ScriptDir "privapp-permissions-app.lawnchair.xml"
  if (-not (Test-Path -LiteralPath $xmlLocal)) {
    $xmlLocal = Join-Path $env:TEMP "privapp-permissions-app.lawnchair.xml"
    [System.IO.File]::WriteAllText($xmlLocal, (Get-PrivAppPermissionsXml))
    Write-Warn "使用内置 privapp XML 写入: $xmlLocal"
  }
  $null = Invoke-Adb $AdbPath -s $Serial push $xmlLocal /system/etc/permissions/privapp-permissions-app.lawnchair.xml
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/etc/permissions/privapp-permissions-app.lawnchair.xml; chown root:root /system/etc/permissions/privapp-permissions-app.lawnchair.xml"

  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/app.lawnchair/app.lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/app.lawnchair/app.lawnchair.apk; chown root:root /system/priv-app/app.lawnchair/app.lawnchair.apk; rm -rf /system/priv-app/app.lawnchair/oat"

  if (-not $SkipReboot) {
    Write-Step "重启以使 priv-app / overlay / 权限生效（必需）"
    Reboot-And-Reconnect $AdbPath $Serial 180
    Ensure-Root $AdbPath $Serial
  } else {
    Write-Warn "SkipReboot：权限/系统标志可能未生效"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Ok "pm path: $path"
  if ($path -notmatch "/system/") {
    # 若扫包失败，尝试 pm install 从 system 路径
    Write-Warn "系统扫包未见 system 路径，尝试 pm install 系统路径"
    $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/app.lawnchair/app.lawnchair.apk").Trim()
    Write-Host "  $ins"
    $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  }
  if ($path -notmatch $PackageName) {
    throw "特权安装后未找到 $PackageName。请 -RecoverOnly 回滚用户安装。"
  }

  $flags = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName | grep -E 'pkgFlags=|privateFlags=|privatePkgFlags=' | head -4").Trim()
  Write-Host "  $flags"
  $grant = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName | grep 'MANAGE_ACTIVITY_TASKS: granted' | head -2").Trim()
  Write-Host "  $grant"
  if ($grant -notmatch "granted=true") {
    Write-Warn "MANAGE_ACTIVITY_TASKS 仍未 granted。检查 overlay: cmd overlay list | grep lawnchair"
  } else {
    Write-Ok "MANAGE_ACTIVITY_TASKS granted"
  }

  $recents = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys activity recents | head -4").Trim()
  Write-Host "  $recents"

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am force-stop $PackageName"
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm clear $PackageName >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm grant $PackageName android.permission.POST_NOTIFICATIONS >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_IMAGES >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_VIDEO >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_AUDIO >/dev/null 2>&1; pm grant $PackageName android.permission.READ_CONTACTS >/dev/null 2>&1; pm grant $PackageName android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
  Start-Sleep -Seconds 2
}

# 兼容旧函数名
function Install-ForceSystem([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Install-PrivilegedHome $AdbPath $Serial $ApkPath -SkipReboot:$SkipReboot
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

function Ensure-HomeReady([string]$AdbPath, [string]$Serial, [string]$ApkPath, [int]$MaxTries = 2, [switch]$PrivilegedMode) {
  Write-Step "防卡住校验（安装后自动救援）"

  if ($PrivilegedMode) {
    # 特权安装后禁止用用户安装路径“救援”，否则会卸掉 SYSTEM 包
    if (Show-Status $AdbPath $Serial) { return $true }
    Write-Warn "特权安装后桌面未就绪：尝试 set-home + 拉起"
    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
    $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
    Start-Sleep -Seconds 2
    return (Show-Status $AdbPath $Serial)
  }

  # 第一轮：软修复（不重启）
  Write-Ok "第 1 步：软修复（不重启）"
  try {
    Install-Or-Repair-UserHome $AdbPath $Serial $ApkPath
    if (Show-Status $AdbPath $Serial) { return $true }
  } catch {
    Write-Warn "软修复异常: $($_.Exception.Message)"
  }

  # 第二轮起：重启模拟器再救援（你确认的有效方法）
  for ($i = 1; $i -le $MaxTries; $i++) {
    Write-Warn "第 $($i+1) 步：重启模拟器后再救援 ($i/$MaxTries)"
    $ok = Recover-FallbackHome $AdbPath $Serial $ApkPath
    if ($ok) { return $true }
  }
  return (Show-Status $AdbPath $Serial)
}

try {
  if ($Help) {
    Show-Usage
    exit 0
  }

  if (($ConnectOnly.IsPresent -and $RecoverOnly.IsPresent) -or
      ($ConnectOnly.IsPresent -and $PrivilegedInstall.IsPresent) -or
      ($RecoverOnly.IsPresent -and $PrivilegedInstall.IsPresent) -or
      ($UserInstallOnly.IsPresent -and $PrivilegedInstall.IsPresent) -or
      ($UserInstallOnly.IsPresent -and $RecoverOnly.IsPresent)) {
    throw "ConnectOnly / RecoverOnly / PrivilegedInstall / UserInstallOnly 互斥。查看: .\Lawnchair-MuMu.ps1 -Help"
  }

  # 默认走特权安装（修复点击图标未安装）；-UserInstallOnly 才用户空间
  if (-not $ConnectOnly -and -not $RecoverOnly -and -not $UserInstallOnly -and -not $PrivilegedInstall) {
    $PrivilegedInstall = $true
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
    # 你确认有效的路径：重启模拟器 -> 再装/设 HOME
    $ok = Recover-FallbackHome $adb $serial $apkPath
    if (-not $ok) {
      Write-Warn "首轮重启救援失败，再来一轮..."
      $ok = Recover-FallbackHome $adb $serial $apkPath
    }
    if (-not $ok) { throw "重启救援后仍卡在 FallbackHome" }
    Write-Ok "救援成功"
    exit 0
  }

  # 若一上来就卡 FallbackHome，先重启救援再继续安装
  if (Test-IsFallbackHome $adb $serial) {
    Write-Warn "连接后发现 FallbackHome，先重启模拟器并救援"
    $null = Recover-FallbackHome $adb $serial $apkPath
  }

  if ($PrivilegedInstall) {
    Install-PrivilegedHome $adb $serial $apkPath -SkipReboot:$SkipReboot
  } else {
    # UserInstallOnly / Recover 路径：用户安装（会“未安装”，仅回滚/调试）
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

  # 替换完成后校验；特权模式勿回落用户安装
  $ready = Ensure-HomeReady $adb $serial $apkPath 2 -PrivilegedMode:$PrivilegedInstall
  if (-not $ready) {
    throw "安装完成但桌面未就绪。特权安装失败可回滚: .\Lawnchair-MuMu.ps1 -RecoverOnly"
  }

  Write-Step "完成"
  Write-Host ""
  Write-Host "设备: $serial" -ForegroundColor Green
  Write-Host "包名: $PackageName" -ForegroundColor Green
  Write-Host "数据: /data/user/0/$PackageName" -ForegroundColor Green
  $modeLabel = if ($PrivilegedInstall) { "PrivilegedInstall (priv-app+recents，修复点击未安装)" } elseif ($UserInstallOnly) { "用户安装（会未安装，仅调试）" } else { "默认" }
  Write-Host ("模式: " + $modeLabel) -ForegroundColor Green
  Write-Host "防卡住: 已自动校验/救援通过" -ForegroundColor Green
  Write-Host ""
  Write-Host "常用:" -ForegroundColor Green
  Write-Host "  .\Lawnchair-MuMu.ps1                     # 默认=特权安装（修复未安装）"
  Write-Host "  .\Lawnchair-MuMu.ps1 -PrivilegedInstall  # 同上"
  Write-Host "  .\Lawnchair-MuMu.ps1 -RecoverOnly        # 回滚到用户安装 / 黑屏救援"
  Write-Host "  .\Lawnchair-MuMu.ps1 -ConnectOnly        # 只连接"
  Write-Host "  .\Lawnchair-MuMu.ps1 -Help"
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  Write-Host "  查看用法: .\Lawnchair-MuMu.ps1 -Help" -ForegroundColor Yellow
  Write-Host "  黑屏救援: .\Lawnchair-MuMu.ps1 -RecoverOnly" -ForegroundColor Yellow
  exit 1
}