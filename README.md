# MuMuClear

MuMu 模拟器一键安装清爽桌面（Lawnchair）。

- 仓库：https://github.com/MurasameCyan/MuMuClear
- 发布页：https://github.com/MurasameCyan/MuMuClear/releases

## 下载

到 [Releases](https://github.com/MurasameCyan/MuMuClear/releases) 下载 `MuMuClear-share.zip`，解压后使用。

## 使用

```powershell
# 1. 启动 MuMu，进入安卓系统
# 2. 解压分享包，在目录中执行：
.\MuMuClear.ps1 -PrivilegedInstall
```

常用命令：

```powershell
.\MuMuClear.ps1 -ConnectOnly      # 只连接 adb
.\MuMuClear.ps1 -RecoverOnly      # 黑屏 / FallbackHome 救援
.\MuMuClear.ps1 -Help
```

## 目录结构（分享包）

```text
MuMuClear.ps1                 # 主入口
tool/
  Lawnchair_app.lawnchair_signed.apk
  LawnchairRecentsOverlay.apk
  privapp-permissions-app.lawnchair.xml
  Adb/adb.exe (+ dll)
  Replace-System-Launcher.ps1
  MuMu-Connect-And-Set-Lawnchair.ps1
```

## 开发 / 本地打包

```powershell
# 本地打分享 zip（与 CI 相同内容）
Compress-Archive -Path .\MuMuClear.ps1, .\tool -DestinationPath .\MuMuClear-share.zip -Force
```

打 tag 会触发 Actions，自动构建 zip 并发布到 Releases：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## 兼容旧入口

- `Lawnchair-MuMu.ps1` → 转发到 `MuMuClear.ps1`
- `tool\Replace-System-Launcher.ps1`
- `tool\MuMu-Connect-And-Set-Lawnchair.ps1`
