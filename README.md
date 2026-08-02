# Magisk Alist 模块

一个用于在 Android arm64 设备上**原生运行 [Alist](https://github.com/AlistGo/alist)** 的 Magisk 模块。

## 功能特性

- **开机自启**：开机后自动启动 Alist，无需手动干预
- **进程守护**：内置看门狗，每 60 秒检查一次，Alist 异常退出自动拉起
- **操作按钮**：Magisk 模块卡片上的"操作"按钮，支持音量键即时开关
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

## 操作控制

模块安装后，在 Magisk 模块页面的 **Alist_online** 卡片底部会显示 **"操作"** 按钮。

### 使用方法

1. 点击 **"操作"** 按钮，弹出交互菜单
2. 使用 **音量键** 上下选择选项，**电源键** 确认
3. 根据当前运行状态显示不同菜单：

| 状态 | 可选操作 |
|------|----------|
| 运行中 | 关闭模块 / 退出选择界面 |
| 已停止 | 打开模块 / 退出选择界面 |

### 即时生效

- **关闭模块**：立即终止 Alist 进程，释放 5244 端口，无需重启
- **打开模块**：立即启动 Alist 进程，恢复 5244 端口监听，无需重启
- 模块介绍区域会实时显示当前状态（`运行中` / `已停止`）

### 看门狗机制

- 手动关闭模块后，看门狗暂停守护（不会自动重启）
- 手动打开模块后，看门狗恢复守护（Alist 异常退出会自动拉起）
- 完全无需重启即可切换状态

## 文件结构

```
magisk_alist/
├── META-INF/com/google/android/
│   ├── update-binary         # Magisk 模块安装入口
│   └── updater-script        # 占位文件（Magisk 规范要求）
├── alist                     # Alist 官方 android-arm64 二进制
├── module.prop               # 模块元信息（ID/版本/动作/描述）
├── customize.sh              # 安装时执行的脚本（打印提示信息）
├── action.sh                 # 操作按钮触发的交互脚本（ui_ask 菜单）
├── service.sh                # Magisk service 阶段触发（正式版 Magisk）
├── post-fs-data.sh           # Magisk post-fs-data 阶段触发（alpha 版兜底）
├── start_alist.sh            # 核心脚本（初始化/启动/停止/看门狗）
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

start_alist.sh（开机流程）:
  1. setup_env（查找 busybox，设置 setsid）
  2. init_module（一次性初始化：MODDIR/锁文件/wake_lock/data目录/admin密码）
  3. launch_alist（启动 alist，更新状态描述为"运行中"）
  4. run_watchdog（看门狗循环，检查 .paused 标记）

操作流程:
  点击"操作"按钮 → action.sh
    ├─ 运行中: ui_ask "关闭模块" / "退出"
    │    └─ 选择关闭 → start_alist.sh stop（创建 .paused + kill 进程 + 更新描述）
    └─ 已停止: ui_ask "打开模块" / "退出"
         └─ 选择打开 → start_alist.sh launch（删除 .paused + 启动进程 + 更新描述）
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

**Q: 操作按钮没出现？**
- 确认 module.prop 包含 `action=1` 字段
- 重新安装模块

**Q: 操作后状态没变？**
- 退出 Magisk 模块页后重新进入，刷新状态
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
