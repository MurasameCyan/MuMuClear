# MuMuClear

MuMu 模拟器一键安装清爽桌面（Lawnchair）。

仓库：https://github.com/yuzunekovo/MuMuClear

## 使用

```powershell
# 先启动 MuMu，再在本目录执行：
.\MuMuClear.ps1 -PrivilegedInstall
```

常用：

```powershell
.\MuMuClear.ps1 -ConnectOnly      # 只连接
.\MuMuClear.ps1 -RecoverOnly      # 黑屏/回滚救援
.\MuMuClear.ps1 -Help
```

## 目录

```text
MuMuClear.ps1                 # 主入口
tool/                         # 可分享交付物
  Lawnchair_app.lawnchair_signed.apk
  LawnchairRecentsOverlay.apk
  privapp-permissions-app.lawnchair.xml
  Adb/                        # 便携 adb
  Replace-System-Launcher.ps1
  MuMu-Connect-And-Set-Lawnchair.ps1
local/                        # 本地源包/补丁脚本（不分享）
devtools/                     # 改包/签名工具（不分享）
build/ diag/                  # 本地缓存（不分享）
```

## 分享打包

```powershell
Compress-Archive -Path .\MuMuClear.ps1, .\tool -DestinationPath .\MuMuClear-share.zip -Force
```

## 兼容旧入口

- `Lawnchair-MuMu.ps1` → 转发到 `MuMuClear.ps1`
- `tool\Replace-System-Launcher.ps1`
- `tool\MuMu-Connect-And-Set-Lawnchair.ps1`
