# 卸载模块时,释放wake_lock并清理旧版本可能残留的备份目录
echo "alist_online" > /sys/power/wake_unlock 2>/dev/null
rm -rf /data/adb/Alist_online_backups