# Magisk Alist 模块

一个用于在 Android arm64 设备上**原生运行 [Alist](https://github.com/AlistGo/alist)** 的 Magisk 模块。

## 功能特性

- **开机自启**：开机后自动启动 Alist，无需手动干预
- **进程守护**：内置看门狗，每 60 秒检查一次，Alist 异常退出自动拉起
- **防睡眠断网**：持有 wake_lock，避免 CPU 深度睡眠导致网络中断
- **双触发机制**：`service.sh` + `post-fs-data.sh` 双兜底，兼容正式版与 alpha 版 Magisk
- **日志轮转**：日志超过 1MB 自动保留最后 200 行，防止膨胀
- **原生 arm64**：内置官方 `android-arm64` 二进制，无需依赖 Termux

## 设备要求

| 项目 | 要求 |
|---|---|
| 架构 | `arm64-v8a` / `aarch64` |
| Android | 10+ |
| Magisk | v20.4+（含 alpha 版） |
| Root | 必需 |

## 安装方法

1. 下载 [magisk_alist.zip](./magisk_alist.zip) 或自行打包
2. 打开 Magisk App → 左侧菜单 **模块** → 右下角 **从存储安装**
3. 选中 zip 文件，等待安装完成
4. **重启手机**
5. 浏览器访问 `http://127.0.0.1:5244`
6. 默认账户 `admin` 密码 `admin`

## 文件结构

```
magisk_alist/
├── META-INF/com/google/android/
│   ├── update-binary         # Magisk 模块安装入口
│   └── updater-script        # 占位文件（Magisk 规范要求）
├── alist                     # Alist 官方 android-arm64 二进制
├── module.prop               # 模块元信息（ID/版本/作者/描述）
├── customize.sh              # 安装时执行的脚本（打印提示信息）
├── service.sh                # Magisk service 阶段触发（正式版 Magisk）
├── post-fs-data.sh           # Magisk post-fs-data 阶段触发（alpha 版兜底）
├── start_alist.sh            # 核心启动脚本（被 service.sh 和 post-fs-data.sh 调用）
├── uninstall.sh              # 卸载时执行的清理脚本
└── README.md
```

## 启动流程

```
开机
  ├─ Magisk 触发 service.sh        （正式版 Magisk）
  │     └─ exec start_alist.sh
  └─ Magisk 触发 post-fs-data.sh   （alpha 版 Magisk 兜底）
        └─ 等 sys.boot_completed=1
        └─ exec start_alist.sh

start_alist.sh:
  1. 自行计算 MODDIR（不依赖外部变量，避免 exec 后丢失）
  2. 检查锁文件 .started，防止重复启动
  3. 持有 wake_lock 防睡眠断网
  4. 创建 data 目录，首次启动初始化 admin 密码
  5. setsid 启动 alist（脱离会话，防止被回收）
  6. 进入看门狗循环，每 60s 检查进程存活
```

## 卸载方法

1. Magisk App → 模块 → Alist_online → **移除**
2. 重启手机
3. 卸载脚本会自动：
   - 释放 wake_lock
   - 清理 data 目录和日志

## 重置密码 / 数据

卸载模块 → 重启 → 重新刷入 zip → 重启，即可重置为默认 `admin/admin`。

## 常见问题

**Q: 浏览器打不开 5244？**
- 等 30 秒让开机流程跑完
- 用 `pgrep -af alist` 检查进程是否在跑
- 查看 `/data/adb/modules/Alist_online/download.log` 排错

**Q: 后台被系统杀死？**
- OriginOS：设置 → 电池 → 后台耗电管理 → Magisk 允许后台高耗电 + 关闭冻结
- i 管家：应用管理 → Magisk → 允许自启动 + 关闭后台清理

**Q: 局域网其他设备访问不了？**
- 确认手机和访问设备在同一 WiFi
- 用手机 IP 替换 127.0.0.1，例如 `http://192.168.1.100:5244`
- 检查手机防火墙是否放行 5244 端口

## 致谢

- [AlistGo/alist](https://github.com/AlistGo/alist) — Alist 原项目
- [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) — Magisk 框架

## 许可

遵循 Alist 原项目许可。
