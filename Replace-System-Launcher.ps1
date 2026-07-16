#Requires -Version 5.1
<#
.SYNOPSIS
  MuMu 一键替换默认桌面为改包名后的 Lawnchair（app.lawnchair）

.DESCRIPTION
  重要结论（踩坑后）：
  - 改过包 / 用 testkey 重签的 APK，不能直接覆盖 /system/priv-app 里原系统签名的 Lawnchair。
  - 否则开机 PackageManager 扫包失败 -> 只剩 com.android.settings/.FallbackHome 黑屏。
  - 正确做法：删掉系统 priv-app 冲突项，以【用户应用】安装，并设为唯一 HOME。
  - 数据目录仍是 /data/user/0/app.lawnchair。

.USAGE
  # 在脚本目录执行，或任意目录直接调用脚本路径
  .\Replace-System-Launcher.ps1

  # 指定多开
  .\Replace-System-Launcher.ps1 -Index 9

  # 黑屏救援（FallbackHome）
  .\Replace-System-Launcher.ps1 -RecoverOnly

  # 危险：仍尝试系统 priv-app（需要与系统原签名一致，testkey 包会失败）
  .\Replace-System-Launcher.ps1 -ForceSystemPrivApp

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
  [int]$Index = -1,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu Lawnchair Home"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
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
    Where-Object { #Requires -Version 5.1
<#
.SYNOPSIS
  MuMu 一键替换默认桌面为改包名后的 Lawnchair（app.lawnchair）

.DESCRIPTION
  重要结论（踩坑后）：
  - 改过包 / 用 testkey 重签的 APK，不能直接覆盖 /system/priv-app 里原系统签名的 Lawnchair。
  - 否则开机 PackageManager 扫包失败 -> 只剩 com.android.settings/.FallbackHome 黑屏。
  - 正确做法：删掉系统 priv-app 冲突项，以【用户应用】安装，并设为唯一 HOME。
  - 数据目录仍是 /data/user/0/app.lawnchair。

.USAGE
  # 在脚本目录执行，或任意目录直接调用脚本路径
  .\Replace-System-Launcher.ps1

  # 指定多开
  .\Replace-System-Launcher.ps1 -Index 9

  # 黑屏救援（FallbackHome）
  .\Replace-System-Launcher.ps1 -RecoverOnly

  # 危险：仍尝试系统 priv-app（需要与系统原签名一致，testkey 包会失败）
  .\Replace-System-Launcher.ps1 -ForceSystemPrivApp

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
  [int]$Index = -1,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu Lawnchair Home"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
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

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    # ...\nx_device\15.0\shell 或 ...\nx_main -> 上溯找 vms
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  # 次选：常见相对安装名（不带盘符前缀硬编码）
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @(
      "MuMu\vms",
      "Netease\MuMu\vms",
      "Netease\MuMuPlayer\vms"
    )) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-ConfigPorts([string]$VmsRoot, [int]$OnlyIndex) {
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @(Get-ListenPorts)
  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  foreach ($c in $cfgPorts) {
    Write-Host ("  [{0}] {1} -> {2}" -f $c.Index, $c.VM, $c.Port)
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)"
      $live += $map[$port]
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match 'connected|already') {
      Write-Ok $msg
      $connected += $item
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
    if ($Serial -match '^127\.0\.0\.1:') { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") { return $true }
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
  if ($id -notmatch 'uid=0') { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免签名不一致导致 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path $ApkPath).Path

  # 卸掉旧用户包，避免签名残留冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch 'Success') {
    throw "安装失败: $out"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch 'package:') {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path $ApkPath)) { throw "需要 APK 才能救援安装: $ApkPath" }
    $full = (Resolve-Path $ApkPath).Path
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
  Write-Warn "testkey 重签包在 MuMu 上会在重启后扫包失败并黑屏。仅在 APK 签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path $ApkPath).Path

  # 必须先卸干净再放 priv-app，并立刻 pm install 验证，然后才能 reboot
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch 'Success') {
    throw "系统 priv-app 安装失败，已中止 reboot。请改用默认用户安装模式。"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Host "  $path"
  if ($path -notmatch '/system/priv-app/') {
    Write-Warn "pm 未识别为 system 路径: $path"
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
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match 'LawnchairLauncher') {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match 'FallbackHome') {
    Write-Err "仍卡在 FallbackHome"
  }
}

# ---------------- main ----------------
try {
  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
  }
  Write-Ok "apk: $apkPath"

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
  } else {
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if (-not $SkipReboot -and $ForceSystemPrivApp) {
    Write-Step "reboot（仅 ForceSystem 模式）"
    $null = Invoke-Adb $adb -s $serial reboot
    Start-Sleep 8
    $ok = $false
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $null = Invoke-Adb $adb connect $serial
      $boot = (Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim()
      if ($boot -eq "1") { $ok = $true; break }
      Start-Sleep 3
    }
    if (-not $ok) { Write-Warn "等待启动超时" }
    else {
      # 若又黑屏，自动救援
      $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
      if ($homeInfo -match 'FallbackHome') {
        Write-Warn "检测到 FallbackHome，自动救援"
        Recover-FallbackHome $adb $serial $apkPath
      }
    }
  }

  Show-Status $adb $serial
  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

黑屏救援:
  .\Replace-System-Launcher.ps1 -RecoverOnly

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
.Name -like 'MuMuPlayer-*' -and (Test-Path (Join-Path #Requires -Version 5.1
<#
.SYNOPSIS
  MuMu 一键替换默认桌面为改包名后的 Lawnchair（app.lawnchair）

.DESCRIPTION
  重要结论（踩坑后）：
  - 改过包 / 用 testkey 重签的 APK，不能直接覆盖 /system/priv-app 里原系统签名的 Lawnchair。
  - 否则开机 PackageManager 扫包失败 -> 只剩 com.android.settings/.FallbackHome 黑屏。
  - 正确做法：删掉系统 priv-app 冲突项，以【用户应用】安装，并设为唯一 HOME。
  - 数据目录仍是 /data/user/0/app.lawnchair。

.USAGE
  # 在脚本目录执行，或任意目录直接调用脚本路径
  .\Replace-System-Launcher.ps1

  # 指定多开
  .\Replace-System-Launcher.ps1 -Index 9

  # 黑屏救援（FallbackHome）
  .\Replace-System-Launcher.ps1 -RecoverOnly

  # 危险：仍尝试系统 priv-app（需要与系统原签名一致，testkey 包会失败）
  .\Replace-System-Launcher.ps1 -ForceSystemPrivApp

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
  [int]$Index = -1,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu Lawnchair Home"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
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

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    # ...\nx_device\15.0\shell 或 ...\nx_main -> 上溯找 vms
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  # 次选：常见相对安装名（不带盘符前缀硬编码）
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @(
      "MuMu\vms",
      "Netease\MuMu\vms",
      "Netease\MuMuPlayer\vms"
    )) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-ConfigPorts([string]$VmsRoot, [int]$OnlyIndex) {
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @(Get-ListenPorts)
  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  foreach ($c in $cfgPorts) {
    Write-Host ("  [{0}] {1} -> {2}" -f $c.Index, $c.VM, $c.Port)
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)"
      $live += $map[$port]
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match 'connected|already') {
      Write-Ok $msg
      $connected += $item
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
    if ($Serial -match '^127\.0\.0\.1:') { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") { return $true }
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
  if ($id -notmatch 'uid=0') { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免签名不一致导致 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path $ApkPath).Path

  # 卸掉旧用户包，避免签名残留冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch 'Success') {
    throw "安装失败: $out"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch 'package:') {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path $ApkPath)) { throw "需要 APK 才能救援安装: $ApkPath" }
    $full = (Resolve-Path $ApkPath).Path
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
  Write-Warn "testkey 重签包在 MuMu 上会在重启后扫包失败并黑屏。仅在 APK 签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path $ApkPath).Path

  # 必须先卸干净再放 priv-app，并立刻 pm install 验证，然后才能 reboot
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch 'Success') {
    throw "系统 priv-app 安装失败，已中止 reboot。请改用默认用户安装模式。"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Host "  $path"
  if ($path -notmatch '/system/priv-app/') {
    Write-Warn "pm 未识别为 system 路径: $path"
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
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match 'LawnchairLauncher') {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match 'FallbackHome') {
    Write-Err "仍卡在 FallbackHome"
  }
}

# ---------------- main ----------------
try {
  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
  }
  Write-Ok "apk: $apkPath"

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
  } else {
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if (-not $SkipReboot -and $ForceSystemPrivApp) {
    Write-Step "reboot（仅 ForceSystem 模式）"
    $null = Invoke-Adb $adb -s $serial reboot
    Start-Sleep 8
    $ok = $false
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $null = Invoke-Adb $adb connect $serial
      $boot = (Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim()
      if ($boot -eq "1") { $ok = $true; break }
      Start-Sleep 3
    }
    if (-not $ok) { Write-Warn "等待启动超时" }
    else {
      # 若又黑屏，自动救援
      $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
      if ($homeInfo -match 'FallbackHome') {
        Write-Warn "检测到 FallbackHome，自动救援"
        Recover-FallbackHome $adb $serial $apkPath
      }
    }
  }

  Show-Status $adb $serial
  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

黑屏救援:
  .\Replace-System-Launcher.ps1 -RecoverOnly

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
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
  MuMu 一键替换默认桌面为改包名后的 Lawnchair（app.lawnchair）

.DESCRIPTION
  重要结论（踩坑后）：
  - 改过包 / 用 testkey 重签的 APK，不能直接覆盖 /system/priv-app 里原系统签名的 Lawnchair。
  - 否则开机 PackageManager 扫包失败 -> 只剩 com.android.settings/.FallbackHome 黑屏。
  - 正确做法：删掉系统 priv-app 冲突项，以【用户应用】安装，并设为唯一 HOME。
  - 数据目录仍是 /data/user/0/app.lawnchair。

.USAGE
  # 在脚本目录执行，或任意目录直接调用脚本路径
  .\Replace-System-Launcher.ps1

  # 指定多开
  .\Replace-System-Launcher.ps1 -Index 9

  # 黑屏救援（FallbackHome）
  .\Replace-System-Launcher.ps1 -RecoverOnly

  # 危险：仍尝试系统 priv-app（需要与系统原签名一致，testkey 包会失败）
  .\Replace-System-Launcher.ps1 -ForceSystemPrivApp

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
  [int]$Index = -1,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu Lawnchair Home"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
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

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    # ...\nx_device\15.0\shell 或 ...\nx_main -> 上溯找 vms
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  # 次选：常见相对安装名（不带盘符前缀硬编码）
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @(
      "MuMu\vms",
      "Netease\MuMu\vms",
      "Netease\MuMuPlayer\vms"
    )) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-ConfigPorts([string]$VmsRoot, [int]$OnlyIndex) {
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @(Get-ListenPorts)
  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  foreach ($c in $cfgPorts) {
    Write-Host ("  [{0}] {1} -> {2}" -f $c.Index, $c.VM, $c.Port)
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)"
      $live += $map[$port]
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match 'connected|already') {
      Write-Ok $msg
      $connected += $item
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
    if ($Serial -match '^127\.0\.0\.1:') { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") { return $true }
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
  if ($id -notmatch 'uid=0') { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免签名不一致导致 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path $ApkPath).Path

  # 卸掉旧用户包，避免签名残留冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch 'Success') {
    throw "安装失败: $out"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch 'package:') {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path $ApkPath)) { throw "需要 APK 才能救援安装: $ApkPath" }
    $full = (Resolve-Path $ApkPath).Path
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
  Write-Warn "testkey 重签包在 MuMu 上会在重启后扫包失败并黑屏。仅在 APK 签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path $ApkPath).Path

  # 必须先卸干净再放 priv-app，并立刻 pm install 验证，然后才能 reboot
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch 'Success') {
    throw "系统 priv-app 安装失败，已中止 reboot。请改用默认用户安装模式。"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Host "  $path"
  if ($path -notmatch '/system/priv-app/') {
    Write-Warn "pm 未识别为 system 路径: $path"
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
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match 'LawnchairLauncher') {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match 'FallbackHome') {
    Write-Err "仍卡在 FallbackHome"
  }
}

# ---------------- main ----------------
try {
  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
  }
  Write-Ok "apk: $apkPath"

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
  } else {
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if (-not $SkipReboot -and $ForceSystemPrivApp) {
    Write-Step "reboot（仅 ForceSystem 模式）"
    $null = Invoke-Adb $adb -s $serial reboot
    Start-Sleep 8
    $ok = $false
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $null = Invoke-Adb $adb connect $serial
      $boot = (Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim()
      if ($boot -eq "1") { $ok = $true; break }
      Start-Sleep 3
    }
    if (-not $ok) { Write-Warn "等待启动超时" }
    else {
      # 若又黑屏，自动救援
      $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
      if ($homeInfo -match 'FallbackHome') {
        Write-Warn "检测到 FallbackHome，自动救援"
        Recover-FallbackHome $adb $serial $apkPath
      }
    }
  }

  Show-Status $adb $serial
  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

黑屏救援:
  .\Replace-System-Launcher.ps1 -RecoverOnly

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
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
  MuMu 一键替换默认桌面为改包名后的 Lawnchair（app.lawnchair）

.DESCRIPTION
  重要结论（踩坑后）：
  - 改过包 / 用 testkey 重签的 APK，不能直接覆盖 /system/priv-app 里原系统签名的 Lawnchair。
  - 否则开机 PackageManager 扫包失败 -> 只剩 com.android.settings/.FallbackHome 黑屏。
  - 正确做法：删掉系统 priv-app 冲突项，以【用户应用】安装，并设为唯一 HOME。
  - 数据目录仍是 /data/user/0/app.lawnchair。

.USAGE
  # 在脚本目录执行，或任意目录直接调用脚本路径
  .\Replace-System-Launcher.ps1

  # 指定多开
  .\Replace-System-Launcher.ps1 -Index 9

  # 黑屏救援（FallbackHome）
  .\Replace-System-Launcher.ps1 -RecoverOnly

  # 危险：仍尝试系统 priv-app（需要与系统原签名一致，testkey 包会失败）
  .\Replace-System-Launcher.ps1 -ForceSystemPrivApp

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
  [int]$Index = -1,
  [switch]$RecoverOnly,
  [switch]$ForceSystemPrivApp,
  [switch]$SkipReboot
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MuMu Lawnchair Home"

# 始终以脚本所在目录为根，不依赖当前工作目录 / 绝对盘符
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
  $candidates = @(
    (Join-Path $AdbDir "adb.exe"),
    (Join-Path $ScriptDir "adb.exe")
  )
  foreach ($p in $candidates) {
    if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请把 platform-tools 放到脚本同目录 Adb\ 下（需要 adb.exe）。"
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

function Find-MuMuVmsRoot {
  # 不写死盘符：优先从正在运行的 MuMu 进程反推安装目录
  $procNames = @("MuMuNxDevice", "MuMuNxMain", "MuMuPlayer", "NemuPlayer")
  foreach ($name in $procNames) {
    $p = Get-Process $name -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if (-not $p) { continue }
    $dir = Split-Path $p.Path -Parent
    # ...\nx_device\15.0\shell 或 ...\nx_main -> 上溯找 vms
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
      $vms = Join-Path $dir "vms"
      if (Test-Path -LiteralPath $vms) { return $vms }
      $dir = Split-Path $dir -Parent
    }
  }
  # 次选：常见相对安装名（不带盘符前缀硬编码）
  $pf = @(${env:ProgramFiles}, ${env:ProgramFiles(x86)}, ${env:ProgramW6432}) | Where-Object { $_ }
  foreach ($root in $pf) {
    foreach ($rel in @(
      "MuMu\vms",
      "Netease\MuMu\vms",
      "Netease\MuMuPlayer\vms"
    )) {
      $cand = Join-Path $root $rel
      if (Test-Path -LiteralPath $cand) { return $cand }
    }
  }
  return $null
}

function Get-ConfigPorts([string]$VmsRoot, [int]$OnlyIndex) {
  $list = @()
  Get-ChildItem $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @(Get-ListenPorts)
  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  foreach ($c in $cfgPorts) {
    Write-Host ("  [{0}] {1} -> {2}" -f $c.Index, $c.VM, $c.Port)
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)"
      $live += $map[$port]
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match 'connected|already') {
      Write-Ok $msg
      $connected += $item
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
    if ($Serial -match '^127\.0\.0\.1:') { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") { return $true }
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
  if ($id -notmatch 'uid=0') { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免签名不一致导致 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path $ApkPath).Path

  # 卸掉旧用户包，避免签名残留冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch 'Success') {
    throw "安装失败: $out"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch 'package:') {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path $ApkPath)) { throw "需要 APK 才能救援安装: $ApkPath" }
    $full = (Resolve-Path $ApkPath).Path
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
  Write-Warn "testkey 重签包在 MuMu 上会在重启后扫包失败并黑屏。仅在 APK 签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path $ApkPath).Path

  # 必须先卸干净再放 priv-app，并立刻 pm install 验证，然后才能 reboot
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch 'Success') {
    throw "系统 priv-app 安装失败，已中止 reboot。请改用默认用户安装模式。"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Host "  $path"
  if ($path -notmatch '/system/priv-app/') {
    Write-Warn "pm 未识别为 system 路径: $path"
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
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match 'LawnchairLauncher') {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match 'FallbackHome') {
    Write-Err "仍卡在 FallbackHome"
  }
}

# ---------------- main ----------------
try {
  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
  }
  Write-Ok "apk: $apkPath"

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
  } else {
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if (-not $SkipReboot -and $ForceSystemPrivApp) {
    Write-Step "reboot（仅 ForceSystem 模式）"
    $null = Invoke-Adb $adb -s $serial reboot
    Start-Sleep 8
    $ok = $false
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $null = Invoke-Adb $adb connect $serial
      $boot = (Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim()
      if ($boot -eq "1") { $ok = $true; break }
      Start-Sleep 3
    }
    if (-not $ok) { Write-Warn "等待启动超时" }
    else {
      # 若又黑屏，自动救援
      $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
      if ($homeInfo -match 'FallbackHome') {
        Write-Warn "检测到 FallbackHome，自动救援"
        Recover-FallbackHome $adb $serial $apkPath
      }
    }
  }

  Show-Status $adb $serial
  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

黑屏救援:
  .\Replace-System-Launcher.ps1 -RecoverOnly

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
 }
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
    if ($_.Name -notmatch 'MuMuPlayer-.*?-(\d+)$') { return }
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

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @(Get-ListenPorts)
  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) { if (-not $map.ContainsKey($p.Port)) { $map[$p.Port] = $p } }

  foreach ($c in $cfgPorts) {
    Write-Host ("  [{0}] {1} -> {2}" -f $c.Index, $c.VM, $c.Port)
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)"
      $live += $map[$port]
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match 'connected|already') {
      Write-Ok $msg
      $connected += $item
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
    if ($Serial -match '^127\.0\.0\.1:') { $null = Invoke-Adb $AdbPath connect $Serial }
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") { return $true }
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
  if ($id -notmatch 'uid=0') { throw "未获得 root: $id" }
  Write-Ok $id
}

function Remove-SystemPrivAppConflict([string]$AdbPath, [string]$Serial) {
  Write-Step "移除系统 priv-app 冲突（避免签名不一致导致 FallbackHome 黑屏）"
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair"
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -i lawn || echo CLEAN").Trim()
  Write-Ok "priv-app Lawnchair: $check"
}

function Install-UserHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "安装用户版桌面并设为默认 HOME"
  if (-not (Test-Path $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path $ApkPath).Path

  # 卸掉旧用户包，避免签名残留冲突
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName

  $out = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $out"
  if ($out -notmatch 'Success') {
    throw "安装失败: $out"
  }

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -n $HomeActivity"
  Write-Ok "已安装并拉起 $HomeActivity"
}

function Recover-FallbackHome([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  Write-Step "救援 FallbackHome 黑屏"
  Ensure-Root $AdbPath $Serial
  Remove-SystemPrivAppConflict $AdbPath $Serial

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -notmatch 'package:') {
    Write-Warn "包不存在，重新安装"
    if (-not (Test-Path $ApkPath)) { throw "需要 APK 才能救援安装: $ApkPath" }
    $full = (Resolve-Path $ApkPath).Path
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
  Write-Warn "testkey 重签包在 MuMu 上会在重启后扫包失败并黑屏。仅在 APK 签名=原系统签名时使用。"
  Ensure-Root $AdbPath $Serial
  $full = (Resolve-Path $ApkPath).Path

  # 必须先卸干净再放 priv-app，并立刻 pm install 验证，然后才能 reboot
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /system/priv-app/Lawnchair; mkdir -p /system/priv-app/Lawnchair"
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /system/priv-app/Lawnchair/Lawnchair.apk).Trim()
  Write-Host "  $push"
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 644 /system/priv-app/Lawnchair/Lawnchair.apk; chown root:root /system/priv-app/Lawnchair/Lawnchair.apk; rm -rf /system/priv-app/Lawnchair/oat"

  $ins = (Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ins"
  if ($ins -notmatch 'Success') {
    throw "系统 priv-app 安装失败，已中止 reboot。请改用默认用户安装模式。"
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Host "  $path"
  if ($path -notmatch '/system/priv-app/') {
    Write-Warn "pm 未识别为 system 路径: $path"
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
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match 'LawnchairLauncher') {
    Write-Ok "桌面正常"
  } elseif ($homeInfo -match 'FallbackHome') {
    Write-Err "仍卡在 FallbackHome"
  }
}

# ---------------- main ----------------
try {
  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "adbDir   : $AdbDir"

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "APK 不存在: $apkPath`n请把 APK 放在脚本同目录，默认名 Lawnchair_app.lawnchair_signed.apk"
  }
  Write-Ok "apk: $apkPath"

  $dev = Connect-MuMu -AdbPath $adb -OnlyIndex $Index
  $serial = $dev.Serial
  $env:MUMU_ADB_SERIAL = $serial
  if (-not (Wait-Device $adb $serial 30)) { throw "设备未就绪" }

  if ($RecoverOnly) {
    Recover-FallbackHome $adb $serial $apkPath
    exit 0
  }

  if ($ForceSystemPrivApp) {
    Install-ForceSystem $adb $serial $apkPath
  } else {
    Ensure-Root $adb $serial
    Remove-SystemPrivAppConflict $adb $serial
    Install-UserHome $adb $serial $apkPath
  }

  if (-not $SkipReboot -and $ForceSystemPrivApp) {
    Write-Step "reboot（仅 ForceSystem 模式）"
    $null = Invoke-Adb $adb -s $serial reboot
    Start-Sleep 8
    $ok = $false
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $null = Invoke-Adb $adb connect $serial
      $boot = (Invoke-Adb $adb -s $serial shell getprop sys.boot_completed).Trim()
      if ($boot -eq "1") { $ok = $true; break }
      Start-Sleep 3
    }
    if (-not $ok) { Write-Warn "等待启动超时" }
    else {
      # 若又黑屏，自动救援
      $homeInfo = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
      if ($homeInfo -match 'FallbackHome') {
        Write-Warn "检测到 FallbackHome，自动救援"
        Recover-FallbackHome $adb $serial $apkPath
      }
    }
  }

  Show-Status $adb $serial
  Write-Step "完成"
  Write-Host @"

设备: $serial
包名: $PackageName
数据: /data/user/0/$PackageName
模式: $(if ($ForceSystemPrivApp) { 'ForceSystemPrivApp(危险)' } else { '用户安装 + 默认HOME(推荐)' })

黑屏救援:
  .\Replace-System-Launcher.ps1 -RecoverOnly

"@ -ForegroundColor Green
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  exit 1
}
