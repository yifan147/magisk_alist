#!/system/bin/sh
#Magisk模块操作交互脚本
#点击"操作"按钮时由Magisk触发,用getevent监听音量键实现选择

MODDIR=${0%/*}
cd "$MODDIR" || exit 1

is_running() {
    [ -n "$(pgrep -x alist)" ]
}

TMP_FILE="$MODDIR/.key_pressed"
rm -f "$TMP_FILE"

echo "================================"
if is_running; then
    echo "  AList 运行中 ✓"
    echo "  [音量上] 关闭模块"
    echo "  [音量下] 退出选择界面"
else
    echo "  AList 已停止 ✗"
    echo "  [音量上] 打开模块"
    echo "  [音量下] 退出选择界面"
fi
echo "================================"
echo "请在 30 秒内按下音量键选择..."

#后台监听第一个音量键事件
(
    getevent -ql 2>/dev/null | grep -m1 'KEY_VOLUME' | grep -o 'KEY_VOLUME[A-Z_]*' > "$TMP_FILE"
) &
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
    KEY_VOLUME_UP)
        if is_running; then
            echo "正在关闭模块..."
            sh "$MODDIR/start_alist.sh" stop
            echo "AList 已关闭 ✗"
        else
            echo "正在打开模块..."
            sh "$MODDIR/start_alist.sh" launch
            sleep 2
            echo "AList 已启动 ✓"
        fi
        ;;
    KEY_VOLUME_DOWN)
        echo "已退出选择界面"
        ;;
    *)
        echo "超时未按键,已退出"
        ;;
esac

echo "完成"
