# 实现计划

## [x] Task 1: 修改 module.prop 添加 action=1 字段
- **Priority**: 高
- **描述**: 
  - 添加 `action=1` 字段启用操作按钮
  - 初始 description 带上 `| 已停止` 状态标签（安装时默认停止）
  - 同步更新版本号为 alist v3.62.0
- **验收**: AC-1

## [ ] Task 2: 重构 start_alist.sh 分离初始化/启动/看门狗
- **Priority**: 高
- **描述**:
  - 提取一次性初始化逻辑为 `init_module()` 函数（MODDIR、busybox、chmod、wake_lock、data 目录、admin 初始化）
  - 提取启动 alist 为 `launch_alist()` 函数（可被 action.sh 调用）
  - 看门狗循环改为检查 `.paused` 标记，存在时跳过重启
  - 添加 `update_status_desc()` 函数更新 module.prop 的 description 状态标签
- **验收**: AC-4, AC-7, AC-8

## [ ] Task 3: 创建 action.sh 交互控制脚本
- **Priority**: 高
- **描述**:
  - 检测 alist 运行状态，显示对应 ui_ask 菜单
  - 关闭：创建 `.paused` + pkill alist + 更新状态描述
  - 打开：删除 `.paused` + 调用 `launch_alist()` + 更新状态描述
  - 支持循环操作和退出
- **验收**: AC-2, AC-3, AC-4, AC-5, AC-9

## [ ] Task 4: 更新 service.sh 和 post-fs-data.sh
- **Priority**: 中
- **描述**:
  - 适配新的 start_alist.sh 结构
  - service.sh 调用 `init_module` 后进入看门狗循环
  - post-fs-data.sh 同样适配
- **验收**: AC-1, AC-6

## [ ] Task 5: 更新 README.md 文档
- **Priority**: 低
- **描述**:
  - 添加"操作控制"章节说明使用方法
  - 更新文件结构说明
  - 更新启动流程说明
- **验收**: 文档完整性

## [ ] Task 6: 重新打包 zip 并推送到 GitHub
- **Priority**: 高
- **描述**:
  - 使用 .NET API 重新打包（正斜杠、LF 行尾）
  - 验证 zip 内容完整性
  - 推送到 GitHub
- **验收**: AC-1 至 AC-9
