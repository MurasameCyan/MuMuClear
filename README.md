# MuMuClear

MuMu 模拟器一键安装清爽桌面（Lawnchair）。

## 使用

```powershell
# 先启动 MuMu，再在本目录执行：
.\MuMuClear.ps1 -PrivilegedInstall
```

## 目录

- `MuMuClear.ps1` — 主入口
- `tool/` — 可分享交付物（APK / overlay / adb / 兼容脚本）
- `local/`、`devtools/`、`build/` — 本地开发文件，不必分享

## 兼容

旧入口仍可用：

- `Lawnchair-MuMu.ps1` → 转发到 `MuMuClear.ps1`
- `tool\Replace-System-Launcher.ps1`
- `tool\MuMu-Connect-And-Set-Lawnchair.ps1`
