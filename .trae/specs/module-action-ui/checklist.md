## 验证清单

- [ ] module.prop 包含 action=1 字段
- [ ] module.prop 的 description 包含状态标签（| 运行中 或 | 已停止）
- [ ] start_alist.sh 分离为 init_module()、launch_alist()、watchdog 循环
- [ ] 看门狗循环检查 .paused 标记
- [ ] launch_alist() 可被外部脚本调用
- [ ] action.sh 存在且包含 ui_ask 交互逻辑
- [ ] 运行中时 action.sh 显示"关闭模块"选项
- [ ] 已停止时 action.sh 显示"打开模块"选项
- [ ] 关闭操作创建 .paused 文件并终止 alist 进程
- [ ] 打开操作删除 .paused 文件并启动 alist 进程
- [ ] 操作后 module.prop description 状态标签更新
- [ ] 关闭后看门狗不会误重启 alist
- [ ] 手动开启 alist 异常退出时看门狗能正常拉起
- [ ] 退出菜单返回 Magisk 模块页
- [ ] README.md 包含操作控制说明
- [ ] zip 包含所有新文件（action.sh、更新后的 start_alist.sh 等）
- [ ] zip 使用正斜杠路径分隔符
- [ ] 脚本文件使用 LF 行尾
