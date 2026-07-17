#Requires -Version 5.1
<#
.SYNOPSIS
  MuMuClear — MuMu 清爽桌面（Lawnchair 连接/安装/救援）

.DESCRIPTION
  把改包名后的 Lawnchair（app.lawnchair）装到 MuMu，并设为默认桌面。

  ============================================================
  目录布局（全部相对本脚本所在目录，不写死盘符）
  ============================================================
    <脚本目录>\
      MuMuClear.ps1                       # 主入口（本文件，唯一脚本）
      tool\                               # 可分享交付物（打包: MuMuClear.ps1 + tool\）
        Lawnchair_app.lawnchair_signed.apk
        LawnchairRecentsOverlay.apk
        privapp-permissions-app.lawnchair.xml
        Adb\
          adb.exe
          AdbWinApi.dll / AdbWinUsbApi.dll
      local\                              # 本地源包/补丁脚本/分享 zip（不分享）
      devtools\                           # 改包/签名工具（不分享）
      build\ diag\ uploads\               # 本地缓存（不分享）

  ============================================================
  快速开始
  ============================================================
  1. 先启动 MuMu，进入安卓系统
  2. 将本目录放到英文路径（勿放桌面/下载等中文目录）
  3. 在脚本目录打开 PowerShell：
       cd <脚本目录>
       .\MuMuClear.ps1
  4. 等待安装完成；按 Home 应进入 Lawnchair
  5. 数据目录：/data/user/0/app.lawnchair

  若 ExecutionPolicy 拦截：
       powershell -NoProfile -ExecutionPolicy Bypass -File .\MuMuClear.ps1

  查看本帮助：
       .\MuMuClear.ps1 -Help
       Get-Help .\MuMuClear.ps1 -Full

  ============================================================
  常用命令
  ============================================================
  # 默认：自动连 MuMu + 用户安装 + 设默认桌面（推荐）
  .\MuMuClear.ps1

  # 只连接，不装包
  .\MuMuClear.ps1 -ConnectOnly

  # 指定多开序号（看 MuMu 多开器序号，如 9 号机）
  .\MuMuClear.ps1 -Index 9

  # 黑屏救援（卡在 Android 标志 / FallbackHome）
  .\MuMuClear.ps1 -RecoverOnly

  # 指定 APK 文件名（相对脚本目录）
  .\MuMuClear.ps1 -Apk "tool\Lawnchair_app.lawnchair_signed.apk"

  # 安装后顺便禁用原系统桌面包（可选）
  .\MuMuClear.ps1 -DisableStockLauncher -StockLauncher com.android.launcher3

  # 特权安装（修复点击图标“未安装”）：priv-app + privapp XML + recents overlay
  .\MuMuClear.ps1 -PrivilegedInstall
  # 兼容旧开关名（同 PrivilegedInstall）
  .\MuMuClear.ps1 -ForceSystemPrivApp

  ============================================================
  参数说明
  ============================================================
  -Apk                   APK 路径。相对路径相对【脚本目录】，不是当前目录。
                         默认：tool\Lawnchair_app.lawnchair_signed.apk
  -PackageName           包名。默认 app.lawnchair
  -HomeActivity          桌面 Activity。默认 app.lawnchair/.LawnchairLauncher
  -Index                 MuMu 多开序号。-1=自动：仅1个A15则直装；多个则交互输入编号
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
  5) 覆盖 MuMu 原版桌面双路径（同包名 app.lawnchair）：
       /system/priv-app/app.lawnchair/app.lawnchair.apk
       /system/priv-app/Lawnchair/Lawnchair.apk   <--- 原版广告桌面路径，必须覆盖
  6) 重启，PackageManager 授予 MANAGE_ACTIVITY_TASKS 等
  7) 同签名用户更新（UPDATED_SYSTEM_APP）+ set-home-activity + 拉起
  数据目录仍是：/data/user/0/app.lawnchair

  为何「清完一会重启又恢复原版」：
  MuMu A15 自带桌面就是 app.lawnchair（带广告/会员 SDK，装在
  /system/priv-app/Lawnchair）。若只写 app.lawnchair/ 不覆盖 Lawnchair/，
  重启扫包会回到广告桌面。本脚本现在双路径都覆盖。

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

  交付 APK（tool\Lawnchair_app.lawnchair_signed.apk）已对 classes.dex
  做同尺寸二进制补丁：把 FeatureFlags.<clinit> 里
  const/4 v1,1 改为 const/4 v1,0（关闭 unification）。
  重建：python local\binpatch_unification_flag.py
  然后 zipalign + apksigner（testkey）。
  勿用 smali 整包重编：会出 DEX041，ART 报 Header size 112/120。

  验证（例 127.0.0.1:16384）：
    - 冷启动无 No layoutter found / 无 Application Error
    - mCurrentFocus=app.lawnchair/.LawnchairLauncher
    - dock 图标可启动；Home / 多任务可回桌面

  回滚/黑屏救援：
       .\MuMuClear.ps1 -RecoverOnly

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
  $adb = ".\tool\Adb\adb.exe"
  $s   = $env:MUMU_ADB_SERIAL   # 例如 127.0.0.1:16672

  & $adb -s $s shell
  & $adb -s $s shell pm path app.lawnchair
  & $adb -s $s shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

  ============================================================
  故障排查
  ============================================================
  adb devices 空白
    -> 先开 MuMu；再 .\MuMuClear.ps1 -ConnectOnly
  找不到 adb.exe
    -> 确认 <脚本目录>\tool\Adb\adb.exe 存在
  找不到 APK
    -> 确认 <脚本目录>\tool\Lawnchair_app.lawnchair_signed.apk 存在
  安装失败 UPDATE_INCOMPATIBLE
    -> 脚本会先 uninstall；仍失败就手动：
       .\tool\Adb\adb.exe -s <serial> uninstall app.lawnchair
  黑屏 / FallbackHome
    -> .\MuMuClear.ps1 -RecoverOnly
  按 Home 仍回原桌面 / 重启后又广告桌面
    -> 再跑默认安装（现已覆盖 /system/priv-app/Lawnchair）
    -> 确认 MuMu 设置里「可写系统」已开并重启过模拟器
    -> 可选: -DisableStockLauncher（若另有原桌面包）
  ForceSystem 后黑屏
    -> 立刻 -RecoverOnly；不要再对 testkey 包用 ForceSystem
  No layoutter found / 桌面起不来（TouchInteractionService）
    -> 确认 APK 已用 local\binpatch_unification_flag.py 关闭
       ENABLE_TASKBAR_NAVBAR_UNIFICATION；再 -PrivilegedInstall 或
       覆盖 /system/priv-app/app.lawnchair/app.lawnchair.apk 后 reboot

#>
[CmdletBinding()]
param(
  [string]$Apk = "tool\Lawnchair_app.lawnchair_signed.apk",
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
$Host.UI.RawUI.WindowTitle = "MuMuClear"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ToolDir = Join-Path $ScriptDir "tool"
$AdbDir = Join-Path $ToolDir "Adb"

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "  [X] $m" -ForegroundColor Red }

function Show-Usage {
  $lines = @(
    "============================================================",
    "MuMuClear 使用说明",
    "============================================================",
    "",
    "目录布局（相对脚本目录）：",
    "  MuMuClear.ps1                 # 唯一脚本入口",
    "  tool\Lawnchair_app.lawnchair_signed.apk",
    "  tool\LawnchairRecentsOverlay.apk",
    "  tool\privapp-permissions-app.lawnchair.xml",
    "  tool\Adb\adb.exe                   # 便携 adb",
    "  local\ / devtools\                 # 本地/开发，勿分享",
    "",
    "快速开始：",
    "  1. 启动 MuMu，开启 Root + 可写系统并重启",
    "  2. 解压到英文路径（不要放桌面/下载等中文目录）",
    "  3. cd 到脚本目录后运行 .\MuMuClear.ps1",
    "",
    "注意：",
    "  路径含中文时 adb/推送可能报错，请使用如 C:\MuMuClear",
    "",
    "常用命令：",
    "  .\MuMuClear.ps1                  # 连接+安装+默认桌面（推荐）",
    "  .\MuMuClear.ps1 -ConnectOnly     # 只连接",
    "  .\MuMuClear.ps1 -RecoverOnly     # 黑屏救援（会先重启模拟器）",
    "  .\MuMuClear.ps1 -Index 9         # 指定多开（也可不写，多开时交互选择）",
    "  .\MuMuClear.ps1 -Apk xxx.apk     # 指定 APK（相对脚本目录）",
    "  .\MuMuClear.ps1 -DisableStockLauncher",
    "  .\MuMuClear.ps1 -ForceSystemPrivApp   # 危险，testkey 易黑屏",
    "  .\MuMuClear.ps1 -Help",
    "",
    "参数：",
    "  -Apk -PackageName -HomeActivity -Index",
    "  -ConnectOnly -RecoverOnly -ForceSystemPrivApp -SkipReboot",
    "  -DisableStockLauncher -StockLauncher -NoProxyPorts -Help",
    "",
    "默认流程：",
    "  探测多开名称+安卓版本 -> 仅 A15 可处理 -> 1个自动装 / 多个输入 Index",
    "  -> 特权安装（priv-app 双路径 + host rom.reset=0）-> 设 HOME",
    "",
    "多开选择：",
    "  显示名来自多开器（extra_config.playerName）；非 A15 自动排除",
    "  也可: .\MuMuClear.ps1 -Index N -PrivilegedInstall",
    "",
    "黑了就跑：",
    "  .\MuMuClear.ps1 -RecoverOnly   # 会先 reboot 再救援",
    "",
    "更完整的说明写在脚本顶部注释里：",
    "  Get-Content .\MuMuClear.ps1 -TotalCount 160",
    "  或 Get-Help .\MuMuClear.ps1 -Full"
  )
  Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Green
}

function Resolve-ScriptPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if ([IO.Path]::IsPathRooted($Path)) { return $Path }

  $leaf = [IO.Path]::GetFileName($Path)
  $candidates = New-Object System.Collections.Generic.List[string]

  # 1) as given under script dir (supports tool\xxx.apk)
  [void]$candidates.Add((Join-Path $ScriptDir $Path))
  # 2) bare name under tool\
  [void]$candidates.Add((Join-Path $ToolDir $leaf))
  # 3) bare name under script root (legacy flat layout)
  [void]$candidates.Add((Join-Path $ScriptDir $leaf))
  # 4) if path is not already tool\..., also try tool\ + original relative path
  if ($Path -notmatch '(?i)^tool[\\/]') {
    [void]$candidates.Add((Join-Path $ToolDir $Path))
  }

  foreach ($c in $candidates) {
    $full = [IO.Path]::GetFullPath($c)
    if (Test-Path -LiteralPath $full) { return $full }
  }

  # Prefer tool\leaf in error path
  return [IO.Path]::GetFullPath((Join-Path $ToolDir $leaf))
}

function Find-Adb {
  foreach ($p in @(
      (Join-Path $AdbDir "adb.exe"),
      (Join-Path (Join-Path $ScriptDir "Adb") "adb.exe"),
      (Join-Path $ScriptDir "adb.exe")
    )) {
    if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  }
  throw "找不到 adb.exe。请放到 tool\Adb\adb.exe`n也可运行: .\MuMuClear.ps1 -Help"
}

function Invoke-Adb {
  param([string]$AdbPath, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    # Windows 下 *.ps1 常为 CRLF；多行 adb shell 脚本若带 \r，Android sh 会报
    # "umask: bad number" / "set: - : unknown option"，写入静默失败。
    $norm = @()
    foreach ($a in $Args) {
      if ($null -eq $a) { $norm += $a; continue }
      $s = [string]$a
      if ($s.IndexOf([char]13) -ge 0) {
        $s = $s.Replace("`r`n", "`n").Replace("`r", "`n")
      }
      $norm += $s
    }
    $out = & $AdbPath @norm 2>&1
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

function Get-InstanceDisplayMeta([string]$InstDir, [string]$VmName) {
  # MuMu 多开器显示名在 configs\extra_config.json 的 playerName
  $name = $null
  $series = $null
  $extra = Join-Path $InstDir "configs\extra_config.json"
  if (Test-Path -LiteralPath $extra) {
    try {
      $ej = [System.IO.File]::ReadAllText($extra, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
      if ($ej.playerName) { $name = [string]$ej.playerName }
      if ($ej.series) { $series = [string]$ej.series }
    } catch {}
  }
  if (-not $series -and $VmName -match "MuMuPlayer-(\d+\.\d+)-") {
    $series = $Matches[1]
  }
  if (-not $name) { $name = $VmName }
  return [PSCustomObject]@{ DisplayName = $name; Series = $series }
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
      $j = [System.IO.File]::ReadAllText($cfg, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
      $port = [int]$j.vm.nat.port_forward.adb.host_port
      if ($port -le 0) { return }
      $log = Join-Path $_.FullName "logs\shell.log"
      $logTime = if (Test-Path $log) { (Get-Item $log).LastWriteTime } else { [datetime]::MinValue }
      $meta = Get-InstanceDisplayMeta $_.FullName $_.Name
      $list += [PSCustomObject]@{
        Index = $idx
        VM = $_.Name
        DisplayName = $meta.DisplayName
        Series = $meta.Series
        Port = $port
        LogTime = $logTime
        Serial = "127.0.0.1:$port"
        Source = "vm_config"
        Android = $null
        Sdk = $null
        Model = $null
      }
    } catch {}
  }
  return $list | Sort-Object Index
}

function Test-IsAndroid15([string]$AndroidRelease, [string]$Sdk, [string]$Series, [string]$VmName) {
  # 优先 adb 实测；否则用 MuMu 系列号 / 目录名推断
  if ($Sdk -match '^\d+$' -and [int]$Sdk -ge 35) { return $true }
  if ($AndroidRelease -match '^(1[5-9]|[2-9]\d)') { return $true }
  if ($Series -match '^15(\.|$)') { return $true }
  if ($VmName -match 'MuMuPlayer-15(\.|-)') { return $true }
  return $false
}

function Get-DeviceAndroidInfo([string]$AdbPath, [string]$Serial) {
  $ver = (Invoke-Adb $AdbPath -s $Serial shell getprop ro.build.version.release).Trim()
  $sdk = (Invoke-Adb $AdbPath -s $Serial shell getprop ro.build.version.sdk).Trim()
  $model = (Invoke-Adb $AdbPath -s $Serial shell getprop ro.product.model).Trim()
  # 清掉 adb 错误噪声
  if ($ver -match 'error:|not found|device offline|no devices|^\s*$') { $ver = $null }
  if ($sdk -match 'error:|not found|device offline|no devices|^\s*$') { $sdk = $null }
  if ($model -match 'error:|not found|device offline|no devices|^\s*$') { $model = $null }
  return [PSCustomObject]@{ Android = $ver; Sdk = $sdk; Model = $model }
}

function Get-ListenPorts {
  $out = @()
  Get-Process MuMuNxDevice -ErrorAction SilentlyContinue | ForEach-Object {
    $proc = $_
    $winTitle = ""
    try { $winTitle = [string]$proc.MainWindowTitle } catch {}
    Get-NetTCPConnection -OwningProcess $proc.Id -State Listen -ErrorAction SilentlyContinue |
      Where-Object {
        ($_.LocalPort -ge 16384 -and $_.LocalPort -le 20000) -or
        $_.LocalPort -eq 7555 -or
        ($_.LocalPort -ge 5555 -and $_.LocalPort -le 5600)
      } | ForEach-Object {
        $out += [PSCustomObject]@{
          Index = -1
          VM = "MuMuNxDevice"
          DisplayName = $(if ($winTitle) { $winTitle } else { "未命名/代理端口" })
          Series = $null
          Port = [int]$_.LocalPort
          LogTime = Get-Date
          Serial = "127.0.0.1:$($_.LocalPort)"
          Source = "listen"
          Android = $null
          Sdk = $null
          Model = $null
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

function Get-VmInstanceDir([string]$VmsRoot, [int]$Index, [string]$Serial) {
  if (-not $VmsRoot -or -not (Test-Path -LiteralPath $VmsRoot)) { return $null }
  $port = $null
  if ($Serial -match ':(\d+)$') { $port = [int]$Matches[1] }
  $script:__bestInst = $null
  Get-ChildItem -LiteralPath $VmsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch "MuMuPlayer-.*?-(\d+)$") { return }
    $idx = [int]$Matches[1]
    if ($Index -ge 0 -and $idx -ne $Index) { return }
    $cfg = Join-Path $_.FullName "configs\vm_config.json"
    if (-not (Test-Path $cfg)) { return }
    try {
      $j = [System.IO.File]::ReadAllText($cfg, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
      $cfgPort = [int]$j.vm.nat.port_forward.adb.host_port
      if ($port -and $cfgPort -eq $port) { $script:__bestInst = $_.FullName; return }
      if ($Index -ge 0 -and $idx -eq $Index -and -not $script:__bestInst) { $script:__bestInst = $_.FullName }
    } catch {}
  }
  $r = $script:__bestInst
  Remove-Variable -Name __bestInst -Scope Script -ErrorAction SilentlyContinue
  return $r
}

function Ensure-HostVmPersistence([string]$VmsRoot, [int]$Index, [string]$Serial) {
  Write-Step "加固 host 实例配置（防冷启动回滚 system-diff）"
  $inst = Get-VmInstanceDir $VmsRoot $Index $Serial
  if (-not $inst) {
    Write-Warn "未定位到实例目录，跳过 host 配置加固"
    return $null
  }
  Write-Ok "实例目录: $inst"
  $cfgPath = Join-Path $inst "configs\vm_config.json"
  if (-not (Test-Path -LiteralPath $cfgPath)) {
    Write-Warn "无 vm_config.json: $cfgPath"
    return $inst
  }
  try {
    $bak = "$cfgPath.bak_mumu_clear"
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $cfgPath -Destination $bak -Force }
    $j = [System.IO.File]::ReadAllText($cfgPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    $changed = $false
    if (-not $j.vm) { throw "vm_config 缺少 vm 字段" }

    if ("$($j.vm.root)" -ne "true") {
      $j.vm | Add-Member -NotePropertyName root -NotePropertyValue "true" -Force
      $changed = $true
      Write-Ok "vm.root = true"
    } else { Write-Host "  vm.root = true" }

    if (-not $j.vm.system_vdi) {
      $j.vm | Add-Member -NotePropertyName system_vdi -NotePropertyValue ([pscustomobject]@{ sharable = "Writable" }) -Force
      $changed = $true
    } elseif ("$($j.vm.system_vdi.sharable)" -ne "Writable") {
      $j.vm.system_vdi.sharable = "Writable"
      $changed = $true
      Write-Ok "system_vdi.sharable = Writable"
    } else { Write-Host "  system_vdi.sharable = Writable" }

    if (-not $j.vm.phone) { $j.vm | Add-Member -NotePropertyName phone -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $j.vm.phone.rom) {
      $j.vm.phone | Add-Member -NotePropertyName rom -NotePropertyValue ([pscustomobject]@{ reset = "0" }) -Force
      $changed = $true
      Write-Ok "phone.rom.reset = 0 (新建)"
    } elseif ("$($j.vm.phone.rom.reset)" -ne "0") {
      $old = $j.vm.phone.rom.reset
      $j.vm.phone.rom.reset = "0"
      $changed = $true
      Write-Ok "phone.rom.reset: $old -> 0（关键：否则冷启动可能丢 system-diff）"
    } else { Write-Host "  phone.rom.reset = 0" }

    if ($changed) {
      $json = $j | ConvertTo-Json -Depth 20
      [System.IO.File]::WriteAllText($cfgPath, $json, [System.Text.UTF8Encoding]::new($false))
      Write-Ok "已写回: $cfgPath"
    } else {
      Write-Ok "host 配置已是可持久状态"
    }

    $diff = Join-Path $inst "system-diff.vdi"
    if (Test-Path -LiteralPath $diff) {
      $fi = Get-Item -LiteralPath $diff
      Write-Host ("  system-diff.vdi = {0:N1} MB  mtime={1}" -f ($fi.Length / 1MB), $fi.LastWriteTime)
    } else {
      Write-Warn "尚无 system-diff.vdi（写入 system 后应由 MuMu 创建）"
    }
    return $inst
  } catch {
    Write-Warn "host 配置加固失败: $($_.Exception.Message)"
    return $inst
  }
}

function Assert-SystemDiffGrew([string]$InstDir, [long]$BeforeSize, [string]$Label) {
  if (-not $InstDir) { return }
  $diff = Join-Path $InstDir "system-diff.vdi"
  if (-not (Test-Path -LiteralPath $diff)) {
    Write-Warn "${Label}: 仍无 system-diff.vdi，冷启动可能丢修改"
    return
  }
  $after = (Get-Item -LiteralPath $diff).Length
  $delta = $after - $BeforeSize
  Write-Host ("  system-diff {0}: {1:N1} MB (delta {2:N1} MB)" -f $Label, ($after / 1MB), ($delta / 1MB))
  if ($delta -lt 1MB -and $Label -match "写入后") {
    Write-Warn "system-diff 几乎没增长：系统写入可能未落到 host 磁盘"
  }
}

function Connect-MuMu([string]$AdbPath, [int]$OnlyIndex, [switch]$NoProxy) {
  Write-Step "自动探测 MuMu 端口并连接"
  $vms = Find-MuMuVmsRoot
  if (-not $vms) { throw "未找到 MuMu vms 目录。先启动 MuMu，或查看: .\MuMuClear.ps1 -Help" }
  Write-Ok "vms: $vms"

  $cfgPorts = @(Get-ConfigPorts -VmsRoot $vms -OnlyIndex $OnlyIndex)
  $listen = @()
  if (-not $NoProxy) { $listen = @(Get-ListenPorts) }

  $map = @{}
  foreach ($p in $cfgPorts) { $map[$p.Port] = $p }
  foreach ($p in $listen) {
    if ($map.ContainsKey($p.Port)) { continue }
    # 已在 vm_config 里的端口优先
    $hit = $cfgPorts | Where-Object { $_.Port -eq $p.Port } | Select-Object -First 1
    if ($hit) { $map[$p.Port] = $hit; continue }

    # 5555–5600 / 7555 是 MuMu 代理口，不是多开序号；挂进去会变成 Index=-1 干扰选择
    $isProxyPort = ($p.Port -eq 7555) -or ($p.Port -ge 5555 -and $p.Port -le 5600)
    if ($isProxyPort) {
      Write-Host "  [·] 忽略代理端口 127.0.0.1:$($p.Port)（非多开编号）" -ForegroundColor DarkGray
      continue
    }

    # 其它未知监听口仅在没有 vm_config 时兜底（仍无真实 Index）
    if ($cfgPorts.Count -gt 0) {
      Write-Host "  [·] 忽略未登记端口 127.0.0.1:$($p.Port)（无多开 Index）" -ForegroundColor DarkGray
      continue
    }
    $p | Add-Member -NotePropertyName DisplayName -NotePropertyValue "未命名/代理端口" -Force
    $p | Add-Member -NotePropertyName Series -NotePropertyValue $null -Force
    $p | Add-Member -NotePropertyName Android -NotePropertyValue $null -Force
    $p | Add-Member -NotePropertyName Sdk -NotePropertyValue $null -Force
    $p | Add-Member -NotePropertyName Model -NotePropertyValue $null -Force
    $map[$p.Port] = $p
  }

  if ($cfgPorts.Count -gt 0) {
    Write-Host ("  {0,-6} {1,-18} {2,-6} {3,-22} {4}" -f "Index", "名称", "系列", "VM", "Port") -ForegroundColor DarkGray
    foreach ($c in $cfgPorts) {
      $ser = if ($c.Series) { $c.Series } else { "?" }
      $mark = if (Test-IsAndroid15 $null $null $c.Series $c.VM) { "" } else { " (非A15)" }
      Write-Host ("  {0,-6} {1,-18} {2,-6} {3,-22} {4}{5}" -f $c.Index, $c.DisplayName, $ser, $c.VM, $c.Port, $mark)
    }
  }

  $live = @()
  foreach ($port in ($map.Keys | Sort-Object)) {
    if (Test-TcpOpen -Port $port) {
      Write-Ok "在线 $($map[$port].Serial)  [$($map[$port].DisplayName)]"
      $live += $map[$port]
    } else {
      Write-Host "  [ ] 未开放: 127.0.0.1:$port  $($map[$port].DisplayName)" -ForegroundColor DarkGray
    }
  }
  if ($live.Count -eq 0) { throw "没有在线实例，请先打开 MuMu" }

  $null = Invoke-Adb $AdbPath start-server
  $connected = @()
  foreach ($item in $live) {
    $msg = (Invoke-Adb $AdbPath connect $item.Serial).Trim()
    if ($msg -match "connected|already") {
      # 探测 Android 版本（用于过滤非 A15）
      $info = Get-DeviceAndroidInfo $AdbPath $item.Serial
      $item.Android = $info.Android
      $item.Sdk = $info.Sdk
      $item.Model = $info.Model
      $a15 = Test-IsAndroid15 $item.Android $item.Sdk $item.Series $item.VM
      $verLabel = if ($item.Android) { "Android $($item.Android)" } elseif ($item.Series) { "系列 $($item.Series)" } else { "版本未知" }
      if ($a15) {
        Write-Ok "$($item.Serial)  $($item.DisplayName)  $verLabel  [可处理]"
        $connected += $item
      } else {
        Write-Warn "跳过非 Android 15: Index=$($item.Index)  $($item.DisplayName)  $verLabel  $($item.Serial)"
      }
    } else {
      Write-Warn "$($item.Serial) -> $msg"
    }
  }

  # 在线实例按：配置端口优先、非 7555 代理、最近日志
  $ranked = @($connected |
    Sort-Object `
      @{ Expression = { if ($_.Source -eq "vm_config") { 0 } else { 1 } } }, `
      @{ Expression = { if ($_.Port -ge 16384) { 0 } elseif ($_.Port -eq 7555) { 2 } else { 1 } } }, `
      @{ Expression = { $_.LogTime }; Descending = $true })

  if ($ranked.Count -eq 0) {
    throw "没有可处理的 Android 15 在线实例（已排除 A12/其它版本）。请启动 A15 实例后重试。"
  }

  # 选择列表只用真实多开编号（Index>=0）。Index=-1 是旧逻辑里的代理口残留，不展示。
  $selectable = @($ranked | Where-Object { $_.Index -ge 0 })
  if ($selectable.Count -eq 0) {
    throw "在线 Android 15 未能对应到多开序号（仅检测到代理口）。请从多开器启动实例，或指定: .\MuMuClear.ps1 -Index N"
  }
  $ranked = $selectable

  # 用户已指定 -Index：校验该序号在可处理列表中
  if ($OnlyIndex -ge 0) {
    $hit = @($ranked | Where-Object { $_.Index -eq $OnlyIndex })
    if ($hit.Count -eq 0) {
      Write-Host ""
      Write-Host "当前可处理的 Android 15 在线实例：" -ForegroundColor Yellow
      foreach ($c in $ranked) {
        $ver = if ($c.Android) { "A$($c.Android)" } else { "系列$($c.Series)" }
        Write-Host ("  -Index {0,-4}  {1,-18}  {2,-10}  {3}" -f $c.Index, $c.DisplayName, $ver, $c.Serial)
      }
      throw "指定的 -Index $OnlyIndex 不在可处理的 Android 15 在线列表中（或不在线/非 A15）"
    }
    $primary = $hit | Select-Object -First 1
  }
  elseif ($ranked.Count -eq 1) {
    # 只有 1 个可处理实例：直接 patch
    $primary = $ranked[0]
    Write-Ok "仅 1 个 Android 15 在线实例，自动选择: Index=$($primary.Index)  $($primary.DisplayName)"
  }
  else {
    # 多个：列出名称 + 版本，让用户输入编号
    Write-Host ""
    Write-Host "检测到多个 Android 15 在线实例，请输入要处理的编号（Index）：" -ForegroundColor Yellow
    Write-Host ("  {0,-6} {1,-18} {2,-10} {3}" -f "Index", "名称", "系统", "adb") -ForegroundColor DarkGray
    foreach ($c in ($ranked | Sort-Object Index)) {
      $ver = if ($c.Android) { "A$($c.Android)" } elseif ($c.Series) { "系列$($c.Series)" } else { "?" }
      Write-Host ("  {0,-6} {1,-18} {2,-10} {3}" -f $c.Index, $c.DisplayName, $ver, $c.Serial)
    }
    Write-Host ""
    $allowed = @($ranked | Select-Object -ExpandProperty Index -Unique | Sort-Object)
    $chosen = $null
    for ($try = 0; $try -lt 5; $try++) {
      $raw = Read-Host "请输入 Index（回车默认 $($allowed[0])）"
      if ([string]::IsNullOrWhiteSpace($raw)) {
        $chosen = [int]$allowed[0]
        break
      }
      if ($raw -match '^\s*(\d+)\s*$') {
        $n = [int]$Matches[1]
        if ($allowed -contains $n) { $chosen = $n; break }
      }
      Write-Warn "无效编号，可选: $($allowed -join ', ')"
    }
    if ($null -eq $chosen) {
      throw "未选择有效实例编号。也可下次直接: .\MuMuClear.ps1 -Index N -PrivilegedInstall"
    }
    $primary = $ranked | Where-Object { $_.Index -eq $chosen } | Select-Object -First 1
    if (-not $primary) { throw "选择的 Index=$chosen 无效" }
  }

  if (-not $primary) { throw "connect 失败" }
  # 交互/自动选中后回写全局 -Index，供 Ensure-HostVmPersistence 等使用
  if ($primary.Index -ge 0) {
    $script:Index = [int]$primary.Index
  }
  $verShow = if ($primary.Android) { "Android $($primary.Android)" } elseif ($primary.Series) { "系列 $($primary.Series)" } else { "Android 15?" }
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host "  将操作实例: Index=$($primary.Index)  名称=$($primary.DisplayName)" -ForegroundColor Green
  Write-Host "  VM: $($primary.VM)  $verShow" -ForegroundColor Green
  Write-Host "  adb: $($primary.Serial)" -ForegroundColor Green
  Write-Host "============================================================" -ForegroundColor Green
  Write-Host ""
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
    $state = (Invoke-Adb $AdbPath -s $Serial get-state).Trim()
    if ($state -eq "device") {
      $boot = (Invoke-Adb $AdbPath -s $Serial shell getprop sys.boot_completed).Trim()
      $anim = (Invoke-Adb $AdbPath -s $Serial shell getprop init.svc.bootanim).Trim()
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
  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if ($path -match "package:(.+)$") {
    $apkFile = $Matches[1].Trim()
    Write-Warn "仍见包路径: $apkFile ，强制删除"
    $dir = Split-Path $apkFile -Parent
    $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf `"$apkFile`" `"$dir`""
    $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1"
  }
  $check = (Invoke-Adb $AdbPath -s $Serial shell "ls /system/priv-app 2>/dev/null | grep -iE 'lawn|app\.lawn' || echo CLEAN").Trim()
  $path2 = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
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
  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd role add-role-holder android.app.role.HOME $PackageName >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
  $resolved = (Invoke-Adb $AdbPath -s $Serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
  $role = (Invoke-Adb $AdbPath -s $Serial shell "cmd role get-role-holders android.app.role.HOME 2>/dev/null").Trim()
  Write-Host "  HOME: $resolved"
  Write-Host "  ROLE: $role"
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
  $overlayLocal = $null
  foreach ($c in @(
      (Join-Path $ToolDir "LawnchairRecentsOverlay.apk"),
      (Join-Path $ScriptDir "LawnchairRecentsOverlay.apk")
    )) {
    if (Test-Path -LiteralPath $c) { $overlayLocal = $c; break }
  }
  if (-not $overlayLocal) {
    throw "缺少 LawnchairRecentsOverlay.apk（应放在 tool\）。该 RRO 把 Lawnchair 标为 recents 组件。"
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

function Test-IsStockMuMuLauncher([string]$AdbPath, [string]$Serial) {
  # MuMu A15 原版桌面就是 app.lawnchair（/system/priv-app/Lawnchair），带广告/会员 SDK。
  $info = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep -E 'versionName=|codePath=|MuMuNotification|com\.mumu\.core' | head -12").Trim()
  if (-not $info) { return $false }
  if ($info -match "versionName=15\.0\.0\.1") { return $true }
  if ($info -match "com\.mumu\.core|MuMuNotification") { return $true }
  if ($info -match "codePath=/system/priv-app/Lawnchair" -and $info -notmatch "16\.Dev") { return $true }
  return $false
}

function Test-IsPrivilegedSystemPackage([string]$AdbPath, [string]$Serial) {
  # 必须 SYSTEM+PRIVILEGED 且 MANAGE_ACTIVITY_TASKS granted，否则点图标会「未安装该应用」
  $flags = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep -E 'pkgFlags=|privateFlags=' | head -6").Trim()
  $grant = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep 'MANAGE_ACTIVITY_TASKS: granted' | head -2").Trim()
  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  if (-not $path) { return $false }
  if ($flags -notmatch "SYSTEM") { return $false }
  if ($flags -notmatch "PRIVILEGED") { return $false }
  if ($grant -notmatch "granted=true") { return $false }
  return $true
}

function Wait-PackagePrivileged([string]$AdbPath, [string]$Serial, [int]$TimeoutSec = 60) {
  # 重启后 PM 扫包/授权有延迟，轮询而不是立刻判失败
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-IsPrivilegedSystemPackage $AdbPath $Serial) { return $true }
    Start-Sleep -Seconds 3
  }
  return (Test-IsPrivilegedSystemPackage $AdbPath $Serial)
}


function Install-SystemLawnchairApk([string]$AdbPath, [string]$Serial, [string]$ApkPath) {
  # 关键加固：
  # 1) 目录必须 0755、APK 必须 0644。MuMu overlay 上 mkdir 常变成 0777，
  #    PackageManager 会跳过 world-writable 的 priv-app → 黑屏 FallbackHome。
  # 2) 规范路径 /system/priv-app/app.lawnchair 为主；同时删除/覆盖原版
  #    /system/priv-app/Lawnchair，防止广告桌面回退。
  $full = (Resolve-Path -LiteralPath $ApkPath).Path
  $expectBytes = [long](Get-Item -LiteralPath $full).Length
  $push = (Invoke-Adb $AdbPath -s $Serial push $full /data/local/tmp/mumu_clear_lawnchair.apk).Trim()
  Write-Host "  $push"
  if ($push -notmatch "pushed|skipped") {
    throw "adb push APK 失败: $push"
  }
  $shellOut = (Invoke-Adb $AdbPath -s $Serial shell @"
umask 022
set -e
# 清掉所有可能冲突路径
rm -rf /system/priv-app/Lawnchair /system/app/Lawnchair \
       /system/priv-app/lawnchair /system/app/lawnchair \
       /system/priv-app/app.lawnchair /system/app/app.lawnchair \
       /product/priv-app/Lawnchair /product/priv-app/app.lawnchair \
       /system_ext/priv-app/Lawnchair /system_ext/priv-app/app.lawnchair

# 主路径：包名目录（PM 稳定扫到）
mkdir -p /system/priv-app/app.lawnchair
cp /data/local/tmp/mumu_clear_lawnchair.apk /system/priv-app/app.lawnchair/app.lawnchair.apk
# 原版路径也写一份清爽 APK（防止 lower 层/回退扫到广告包）
mkdir -p /system/priv-app/Lawnchair
cp /data/local/tmp/mumu_clear_lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk

# 强制安全权限（绝不能 777/666）
chmod 0755 /system/priv-app/app.lawnchair /system/priv-app/Lawnchair
chmod 0644 /system/priv-app/app.lawnchair/app.lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk
chown root:root /system/priv-app/app.lawnchair /system/priv-app/app.lawnchair/app.lawnchair.apk \
                 /system/priv-app/Lawnchair /system/priv-app/Lawnchair/Lawnchair.apk
# 二次强制（部分 overlay 会改回宽权限）
chmod 0755 /system/priv-app/app.lawnchair /system/priv-app/Lawnchair
chmod 0644 /system/priv-app/app.lawnchair/app.lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk
rm -rf /system/priv-app/app.lawnchair/oat /system/priv-app/Lawnchair/oat
rm -rf /data/system/package_cache/*/*[Ll]awnchair* /data/system/package_cache/*/*lawnchair* 2>/dev/null || true
sync
ls -la /system/priv-app/app.lawnchair/ /system/priv-app/Lawnchair/
stat -c '%n %s' /system/priv-app/app.lawnchair/app.lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk
"@).Trim()
  Write-Host "  $shellOut"
  if ($shellOut -match "bad number|unknown option|Read-only file system|Permission denied") {
    throw "系统写入 shell 失败（常见原因：脚本 CRLF 或未开可写系统）:`n$shellOut"
  }

  # 校验：权限 + 远端大小必须等于本地清爽 APK（原版约 43MB，清爽约 18MB）
  $ls = (Invoke-Adb $AdbPath -s $Serial shell "ls -ld /system/priv-app/app.lawnchair /system/priv-app/Lawnchair; ls -l /system/priv-app/app.lawnchair/app.lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk").Trim()
  Write-Host "  $ls"
  if ($ls -match "No such file" -or $ls -notmatch "app\.lawnchair\.apk" -or $ls -notmatch "Lawnchair\.apk") {
    throw "系统路径未写上 APK。请确认 Root+可写系统。ls:`n$ls"
  }
  if ($ls -match "drwxrwxrwx|rw-rw-rw-") {
    Write-Warn "检测到 world-writable 权限，再次强制 chmod"
    $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 0755 /system/priv-app/app.lawnchair /system/priv-app/Lawnchair; chmod 0644 /system/priv-app/app.lawnchair/app.lawnchair.apk /system/priv-app/Lawnchair/Lawnchair.apk"
    $ls2 = (Invoke-Adb $AdbPath -s $Serial shell "ls -ld /system/priv-app/app.lawnchair /system/priv-app/Lawnchair").Trim()
    Write-Host "  retry: $ls2"
    if ($ls2 -match "drwxrwxrwx") {
      throw "无法把 priv-app 目录权限设为 0755（仍是 0777）。PackageManager 会跳过该目录导致黑屏。请确认可写系统已开。"
    }
  }
  $sizes = (Invoke-Adb $AdbPath -s $Serial shell "stat -c %s /system/priv-app/app.lawnchair/app.lawnchair.apk; stat -c %s /system/priv-app/Lawnchair/Lawnchair.apk").Trim() -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
  foreach ($sz in $sizes) {
    $n = [long]$sz
    if ([math]::Abs($n - $expectBytes) -gt 64) {
      throw @"
系统 APK 大小不对（写入未真正生效）。
  期望: $expectBytes 字节（本地清爽包）
  实际: $n
  远端: $sizes

常见原因：
  - 未开启「可写系统」/ Root
  - 旧版分享包多行 adb shell 带 CRLF 导致 sh 失败（请用最新 Release）
"@
    }
  }
  $null = Invoke-Adb $AdbPath -s $Serial shell "sync; sync; md5sum /system/priv-app/Lawnchair/Lawnchair.apk /system/priv-app/app.lawnchair/app.lawnchair.apk 2>/dev/null"
  Write-Ok "系统路径已写入且权限安全（0755/0644，大小=$expectBytes）"
}

function Install-PrivilegedHome([string]$AdbPath, [string]$Serial, [string]$ApkPath, [switch]$SkipReboot) {
  Write-Step "特权安装（纯系统替换）: priv-app + privapp XML + recents overlay"
  Write-Host "  路线: 直接覆盖 /system/priv-app（不走 KernelSU 模块）" -ForegroundColor DarkGray
  Write-Host "  目标: SYSTEM+PRIVILEGED + MANAGE_ACTIVITY_TASKS；目录 0755/0644；host 关 rom.reset" -ForegroundColor DarkGray
  if (-not (Test-Path -LiteralPath $ApkPath)) { throw "APK 不存在: $ApkPath" }
  $full = (Resolve-Path -LiteralPath $ApkPath).Path

  # host 侧先关 rom.reset，避免冷启动丢掉 system-diff
  $vmsRoot = Find-MuMuVmsRoot
  $instDir = Ensure-HostVmPersistence $vmsRoot $Index $Serial
  $diffBefore = 0L
  if ($instDir) {
    $diffPath = Join-Path $instDir "system-diff.vdi"
    if (Test-Path -LiteralPath $diffPath) { $diffBefore = [long](Get-Item -LiteralPath $diffPath).Length }
  }

  Ensure-Root $AdbPath $Serial
  # 不走模块路线：清掉可能残留的 mumu_clear
  $null = Invoke-Adb $AdbPath -s $Serial shell "rm -rf /data/adb/modules/mumu_clear /data/adb/modules_update/mumu_clear 2>/dev/null"

  if (Test-IsStockMuMuLauncher $AdbPath $Serial) {
    Write-Warn "检测到 MuMu 原版 app.lawnchair（广告桌面），将覆盖系统路径"
  }

  Write-Step "移除用户版 app.lawnchair（避免盖住 system 特权包）"
  $null = Invoke-Adb $AdbPath -s $Serial uninstall $PackageName
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1; pm uninstall --user 0 $PackageName >/dev/null 2>&1; rm -rf /data/app/*app.lawnchair* /data/app/*lawnchair* /data/user/0/$PackageName /data/user_de/0/$PackageName /data/data/$PackageName 2>/dev/null"

  Install-RecentsOverlay $AdbPath $Serial
  # overlay 也强制安全权限
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 0644 /product/overlay/LawnchairRecentsOverlay.apk 2>/dev/null; chown root:root /product/overlay/LawnchairRecentsOverlay.apk 2>/dev/null"

  $xmlLocal = $null
  foreach ($c in @(
      (Join-Path $ToolDir "privapp-permissions-app.lawnchair.xml"),
      (Join-Path $ScriptDir "privapp-permissions-app.lawnchair.xml")
    )) {
    if (Test-Path -LiteralPath $c) { $xmlLocal = $c; break }
  }
  if (-not $xmlLocal) {
    $xmlLocal = Join-Path $env:TEMP "privapp-permissions-app.lawnchair.xml"
    [System.IO.File]::WriteAllText($xmlLocal, (Get-PrivAppPermissionsXml))
    Write-Warn "使用内置 privapp XML 写入: $xmlLocal"
  }
  $null = Invoke-Adb $AdbPath -s $Serial push $xmlLocal /system/etc/permissions/privapp-permissions-app.lawnchair.xml
  $null = Invoke-Adb $AdbPath -s $Serial shell "chmod 0644 /system/etc/permissions/privapp-permissions-app.lawnchair.xml; chown root:root /system/etc/permissions/privapp-permissions-app.lawnchair.xml"

  Install-SystemLawnchairApk $AdbPath $Serial $full
  Assert-SystemDiffGrew $instDir $diffBefore "写入后"
  if ($instDir) {
    $dp = Join-Path $instDir "system-diff.vdi"
    if (Test-Path -LiteralPath $dp) { $diffBefore = [long](Get-Item -LiteralPath $dp).Length }
  }

  if ($SkipReboot) {
    Write-Warn "SkipReboot：系统扫包/权限几乎一定不会生效，点图标可能仍显示未安装"
  } else {
    Write-Step "重启以使 PackageManager 扫成 SYSTEM+PRIVILEGED（必需）"
    Reboot-And-Reconnect $AdbPath $Serial 180
    Ensure-Root $AdbPath $Serial
  }

  Write-Step "等待 PackageManager 扫包并授权"
  $ok = Wait-PackagePrivileged $AdbPath $Serial 45
  $stillStock = Test-IsStockMuMuLauncher $AdbPath $Serial
  if ((-not $ok -or $stillStock) -and -not $SkipReboot) {
    Write-Warn "重启后未就绪或仍是原版广告包，二次系统覆盖并重启"
    $ls = (Invoke-Adb $AdbPath -s $Serial shell "ls -ld /system/priv-app/app.lawnchair /system/priv-app/Lawnchair 2>/dev/null; ls -l /system/priv-app/app.lawnchair/*.apk /system/priv-app/Lawnchair/*.apk 2>/dev/null; md5sum /system/priv-app/Lawnchair/Lawnchair.apk 2>/dev/null").Trim()
    Write-Host "  $ls"
    Install-SystemLawnchairApk $AdbPath $Serial $full
    Assert-SystemDiffGrew $instDir $diffBefore "二次写入后"
    $null = Invoke-Adb $AdbPath -s $Serial shell "pm install -r -g -d /system/priv-app/app.lawnchair/app.lawnchair.apk >/dev/null 2>&1"
    Reboot-And-Reconnect $AdbPath $Serial 180
    Ensure-Root $AdbPath $Serial
    $ok = Wait-PackagePrivileged $AdbPath $Serial 60
  }

  $path = (Invoke-Adb $AdbPath -s $Serial shell pm path $PackageName).Trim()
  Write-Ok "pm path: $path"
  $flags = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName | grep -E 'pkgFlags=|privateFlags=' | head -6").Trim()
  Write-Host "  $flags"
  $grant = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName | grep 'MANAGE_ACTIVITY_TASKS: granted' | head -2").Trim()
  Write-Host "  $grant"

  if (-not $ok) {
    # 最后兜底：若 system 文件在但 PM 未扫到，不要留下 FallbackHome；先用户安装保证能进桌面，并明确警告
    Write-Warn "特权扫包失败，临时用户安装以脱离黑屏（点图标可能仍未安装，需再跑 PrivilegedInstall）"
    $null = Invoke-Adb $AdbPath -s $Serial install -r -g $full
    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity; am start -a android.intent.action.MAIN -c android.intent.category.HOME"
    throw @"
特权安装失败：app.lawnchair 没有 SYSTEM+PRIVILEGED 或 MANAGE_ACTIVITY_TASKS 未授予。
这会导致点击图标弹出「未安装该应用」，或重启后 FallbackHome 黑屏。

常见原因：
  - priv-app 目录权限变成 0777（world-writable），PackageManager 跳过扫包
  - 未开启「可写系统」
  - 使用了 -SkipReboot

请确认可写系统+Root 后重跑：
  .\MuMuClear.ps1 -PrivilegedInstall

pm path: $path
flags  : $flags
grant  : $grant
"@
  }
  Write-Ok "SYSTEM+PRIVILEGED 且 MANAGE_ACTIVITY_TASKS granted"

  if (Test-IsStockMuMuLauncher $AdbPath $Serial) {
    throw "安装后仍检测到 MuMu 原版广告桌面组件。请确认可写系统已生效后重试。"
  }

  # 可选：同签名用户更新。若破坏特权则回滚
  Write-Step "同签名用户更新（保留 SYSTEM/PRIVILEGED）"
  $upd = (Invoke-Adb $AdbPath -s $Serial install -r -g $full).Trim()
  Write-Host "  $upd"
  if ($upd -match "Success") {
    if (-not (Test-IsPrivilegedSystemPackage $AdbPath $Serial)) {
      Write-Warn "用户更新后特权异常，卸载用户更新，保留纯 system 包"
      $null = Invoke-Adb $AdbPath -s $Serial shell "pm uninstall $PackageName >/dev/null 2>&1; pm uninstall --user 0 $PackageName >/dev/null 2>&1"
    } else {
      Write-Ok "UPDATED_SYSTEM_APP 且特权仍在"
    }
  } else {
    Write-Warn "用户更新跳过（不影响特权）: $upd"
  }

  $recents = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys activity recents | head -4").Trim()
  Write-Host "  $recents"
  $overlay = (Invoke-Adb $AdbPath -s $Serial shell "cmd overlay list 2>/dev/null | grep -i lawnchair").Trim()
  Write-Host "  overlay: $overlay"

  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
  $null = Invoke-Adb $AdbPath -s $Serial shell "cmd role add-role-holder android.app.role.HOME $PackageName >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am force-stop $PackageName"
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm clear $PackageName >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "pm grant $PackageName android.permission.POST_NOTIFICATIONS >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_IMAGES >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_VIDEO >/dev/null 2>&1; pm grant $PackageName android.permission.READ_MEDIA_AUDIO >/dev/null 2>&1; pm grant $PackageName android.permission.READ_CONTACTS >/dev/null 2>&1; pm grant $PackageName android.permission.READ_EXTERNAL_STORAGE >/dev/null 2>&1"
  $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
  Start-Sleep -Seconds 2

  # 安装收尾再等焦点就绪，避免误报卡住
  for ($i = 0; $i -lt 8; $i++) {
    if (Show-Status $AdbPath $Serial) { return }
    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity; am start -a android.intent.action.MAIN -c android.intent.category.HOME"
    Start-Sleep -Seconds 2
  }
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
  $ver = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep versionName= | head -1").Trim()
  $flags = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep -E 'pkgFlags=|privateFlags=' | head -4").Trim()
  $grant = (Invoke-Adb $AdbPath -s $Serial shell "dumpsys package $PackageName 2>/dev/null | grep 'MANAGE_ACTIVITY_TASKS: granted' | head -1").Trim()
  Write-Host "  pm path : $pkgPath"
  Write-Host "  version : $ver"
  Write-Host "  flags   : $flags"
  Write-Host "  grant   : $grant"
  Write-Host "  HOME    : $homeInfo"
  Write-Host "  focus   : $focus"
  if (Test-IsStockMuMuLauncher $AdbPath $Serial) {
    Write-Warn "仍是 MuMu 原版广告桌面（需覆盖 /system/priv-app/Lawnchair 后重启）"
    return $false
  }
  if (-not (Test-IsPrivilegedSystemPackage $AdbPath $Serial)) {
    Write-Warn "不是 SYSTEM+PRIVILEGED 或未授予 MANAGE_ACTIVITY_TASKS → 点图标会「未安装该应用」"
    Write-Warn "请跑: .\MuMuClear.ps1 -PrivilegedInstall（不要 -UserInstallOnly / -SkipReboot）"
    return $false
  }
  if ($homeInfo -match [regex]::Escape($PackageName) -and $focus -match "LawnchairLauncher") {
    Write-Ok "桌面正常（清爽 + 特权，可点图标）"
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
    if (Show-Status $AdbPath $Serial) { return $true }

    # FallbackHome：priv-app 可能因 0777 权限被 PM 跳过。重写权限并重启扫包。
    if (Test-IsFallbackHome $AdbPath $Serial) {
      Write-Warn "特权模式检测到 FallbackHome，修复 priv-app 权限并重启扫包"
      try {
        Install-SystemLawnchairApk $AdbPath $Serial $ApkPath
        Reboot-And-Reconnect $AdbPath $Serial 180
        Ensure-Root $AdbPath $Serial
        if (Wait-PackagePrivileged $AdbPath $Serial 45) {
          $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
          $null = Invoke-Adb $AdbPath -s $Serial shell "cmd role add-role-holder android.app.role.HOME $PackageName >/dev/null 2>&1"
          $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
          Start-Sleep -Seconds 2
          if (Show-Status $AdbPath $Serial) { return $true }
        }
      } catch {
        Write-Warn "FallbackHome 特权救援异常: $($_.Exception.Message)"
      }
    }

    Write-Warn "特权安装后桌面未就绪：尝试 set-home + 拉起"
    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd package set-home-activity --user 0 $HomeActivity"
    $null = Invoke-Adb $AdbPath -s $Serial shell "cmd role add-role-holder android.app.role.HOME $PackageName >/dev/null 2>&1"
    $null = Invoke-Adb $AdbPath -s $Serial shell "am start -a android.intent.action.MAIN -c android.intent.category.HOME"
    Start-Sleep -Seconds 2
    return (Show-Status $AdbPath $Serial)
  }

  Write-Ok "第 1 步：软修复（不重启）"
  try {
    Install-Or-Repair-UserHome $AdbPath $Serial $ApkPath
    if (Show-Status $AdbPath $Serial) { return $true }
  } catch {
    Write-Warn "软修复异常: $($_.Exception.Message)"
  }

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
    throw "ConnectOnly / RecoverOnly / PrivilegedInstall / UserInstallOnly 互斥。查看: .\MuMuClear.ps1 -Help"
  }

  # 默认走特权安装（修复点击图标未安装）；-UserInstallOnly 才用户空间
  if (-not $ConnectOnly -and -not $RecoverOnly -and -not $UserInstallOnly -and -not $PrivilegedInstall) {
    $PrivilegedInstall = $true
  }

  # 中文/非 ASCII 路径会导致 adb push、 purl 编码异常
  if ($ScriptDir -match '[^\x00-\x7F]') {
    throw @"
当前脚本目录包含中文或非英文字符，运行会报错：
  $ScriptDir

请把整个 MuMuClear 文件夹移动到纯英文路径后再运行，例如：
  C:\MuMuClear
  D:\tools\MuMuClear

不要放在「桌面 / 下载 / 中文用户名目录」下。
"@
  }

  Write-Ok "scriptDir: $ScriptDir"
  Write-Ok "toolDir  : $ToolDir"
  Write-Ok "adbDir   : $AdbDir"

  # 从 GitHub 下载的分享包常带 Zone.Identifier，解除阻止避免 adb/脚本异常
  try {
    Get-ChildItem -LiteralPath $ToolDir -Recurse -File -ErrorAction SilentlyContinue |
      Unblock-File -ErrorAction SilentlyContinue
    Unblock-File -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
  } catch {}

  $adb = Find-Adb
  Write-Ok "adb: $adb"

  $apkPath = Resolve-ScriptPath $Apk
  if (-not $ConnectOnly) {
    if (-not (Test-Path -LiteralPath $apkPath)) {
      throw "APK 不存在: $apkPath`n请把 APK 放在 tool\，默认名 tool\Lawnchair_app.lawnchair_signed.apk`n查看: .\MuMuClear.ps1 -Help"
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

  Write-Step "安装前桌面快照（确认实例）"
  $prePath = (Invoke-Adb $adb -s $serial shell pm path $PackageName).Trim()
  $preVer = (Invoke-Adb $adb -s $serial shell "dumpsys package $PackageName 2>/dev/null | grep versionName= | head -1").Trim()
  $preHome = (Invoke-Adb $adb -s $serial shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").Trim()
  Write-Host "  设备   : $serial"
  Write-Host "  pm path: $prePath"
  Write-Host "  version: $preVer"
  Write-Host "  HOME   : $preHome"
  if ($preVer -match "15\.0\.0\.1") {
    Write-Warn "当前是 MuMu 原版广告桌面 (15.0.0.1)，将替换为清爽版"
  }
if ($ConnectOnly) {
    Write-Step "完成（仅连接）"
    Write-Host ""
    Write-Host "主设备: $serial" -ForegroundColor Green
    Write-Host "端口  : $($dev.Port)" -ForegroundColor Green
    # 连接后也探测是否卡在 FallbackHome，给提示
    if (Test-IsFallbackHome $adb $serial) {
      Write-Warn "当前设备卡在 FallbackHome。请运行: .\MuMuClear.ps1 -RecoverOnly"
    }
    Write-Host ""
    Write-Host "之后可用:" -ForegroundColor Green
    Write-Host "  & `"$adb`" -s $serial shell"
    Write-Host "  .\MuMuClear.ps1            # 继续安装默认桌面（含防卡住）"
    Write-Host "  .\MuMuClear.ps1 -RecoverOnly"
    Write-Host "  .\MuMuClear.ps1 -Help"
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

  # FallbackHome：特权安装会重写 /system/priv-app，勿先跑 Recover（会清 system 再装用户版）
  if (Test-IsFallbackHome $adb $serial) {
    if ($PrivilegedInstall) {
      Write-Warn "连接后发现 FallbackHome；特权模式将直接系统覆盖并重启扫包（不清 system 后用户装）"
    } else {
      Write-Warn "连接后发现 FallbackHome，先重启模拟器并救援"
      $null = Recover-FallbackHome $adb $serial $apkPath
    }
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
    throw "安装完成但桌面未就绪。特权安装失败可回滚: .\MuMuClear.ps1 -RecoverOnly"
  }

  Write-Step "完成"
  Write-Host ""
  Write-Host "设备: $serial" -ForegroundColor Green
  Write-Host "包名: $PackageName" -ForegroundColor Green
  Write-Host "数据: /data/user/0/$PackageName" -ForegroundColor Green
  $modeLabel = if ($PrivilegedInstall) { "PrivilegedInstall (priv-app+recents，修复点击未安装)" } elseif ($UserInstallOnly) { "用户安装（会未安装，仅调试）" } else { "默认" }
  Write-Host ("模式: " + $modeLabel) -ForegroundColor Green
  Write-Host "防卡住: 已自动校验/救援通过" -ForegroundColor Green
  $finalVer = (Invoke-Adb $adb -s $serial shell "dumpsys package $PackageName 2>/dev/null | grep versionName= | head -1").Trim()
  Write-Host ("版本: " + $finalVer) -ForegroundColor Green
  if ($finalVer -match '15\.0\.0\.1') { throw '完成后仍是原版 15.0.0.1，说明改错实例或系统写入未生效' }
  Write-Host ""
  Write-Host "常用:" -ForegroundColor Green
  Write-Host "  .\MuMuClear.ps1                     # 默认=特权安装（修复未安装）"
  Write-Host "  .\MuMuClear.ps1 -PrivilegedInstall  # 同上"
  Write-Host "  .\MuMuClear.ps1 -RecoverOnly        # 回滚到用户安装 / 黑屏救援"
  Write-Host "  .\MuMuClear.ps1 -ConnectOnly        # 只连接"
  Write-Host "  .\MuMuClear.ps1 -Help"
  exit 0
}
catch {
  Write-Err $_.Exception.Message
  Write-Host "  查看用法: .\MuMuClear.ps1 -Help" -ForegroundColor Yellow
  Write-Host "  黑屏救援: .\MuMuClear.ps1 -RecoverOnly" -ForegroundColor Yellow
  exit 1
}