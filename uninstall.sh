# 卸载模块时,释放wake_lock并清理旧版本可能残留的备份目录
echo "openlist_online" > /sys/power/wake_unlock 2>/dev/null
rm -rf /data/adb/Openlist_online_backups