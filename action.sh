#!/system/bin/sh
#Magisk模块操作交互脚本
#点击"操作"按钮时由Magisk触发,用getevent监听音量键实现选择

MODDIR=${0%/*}
cd "$MODDIR" || exit 1

is_running() {
    pgrep -f 'openlist server' >/dev/null 2>&1
}

#查找getevent
GE=""
for p in /system/bin/getevent /system/xbin/getevent getevent; do
    if command -v "$p" >/dev/null 2>&1 || [ -x "$p" ]; then
        GE="$p"
        break
    fi
done

TMP_FILE="$MODDIR/.key_pressed"
rm -f "$TMP_FILE"

echo "================================"
if is_running; then
    echo "  OpenList 运行中 ✓"
    echo "  [音量上] 关闭模块"
    echo "  [音量下] 退出选择界面"
else
    echo "  OpenList 已停止 ✗"
    echo "  [音量上] 打开模块"
    echo "  [音量下] 退出选择界面"
fi
echo "================================"
echo "请在 30 秒内按下音量键选择..."
echo ""

if [ -z "$GE" ]; then
    echo "[错误] 未找到 getevent 命令"
    echo "可手动执行: sh $MODDIR/start_openlist.sh launch  (启动)"
    echo "          sh $MODDIR/start_openlist.sh stop    (停止)"
    exit 1
fi

#后台监听第一个音量键事件,用awk匹配并输出UP/DOWN
$GE -ql 2>/dev/null | awk '
    /KEY_VOLUMEUP/   { print "UP";   exit }
    /KEY_VOLUMEDOWN/ { print "DOWN"; exit }
' > "$TMP_FILE" &
LISTENER_PID=$!

#等待按键或超时(30秒)
i=0
while [ $i -lt 30 ] && [ ! -s "$TMP_FILE" ]; do
    sleep 1
    i=$((i + 1))
done

#清理监听进程
kill $LISTENER_PID 2>/dev/null
wait $LISTENER_PID 2>/dev/null

#读取按键
key=$(cat "$TMP_FILE" 2>/dev/null)
rm -f "$TMP_FILE"

echo ""
case "$key" in
    UP)
        if is_running; then
            echo "正在关闭模块..."
            sh "$MODDIR/start_openlist.sh" stop
            echo "OpenList 已关闭 ✗"
        else
            echo "正在打开模块..."
            sh "$MODDIR/start_openlist.sh" launch
            sleep 2
            echo "OpenList 已启动 ✓"
        fi
        ;;
    DOWN)
        echo "已退出选择界面"
        ;;
    *)
        echo "超时未按键,已退出"
        echo "(若按键无效,请检查getevent权限)"
        ;;
esac

echo "完成"
