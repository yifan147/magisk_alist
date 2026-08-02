#!/system/bin/sh
#Magisk模块核心启动脚本,由service.sh和post-fs-data.sh共同调用
#自行计算MODDIR,不依赖外部变量(避免exec后变量丢失)
MODDIR=$(dirname "$0")
#兼容直接执行脚本时dirname返回.的情况
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
cd "$MODDIR" || exit 1

#锁文件,防止service.sh和post-fs-data.sh重复启动
LOCK="$MODDIR/.started"
if [ -f "$LOCK" ]; then
    exit 0
fi
touch "$LOCK"

#寻找busybox( Magisk自带,位置可能不同 )
BUSYBOX=""
for bb in /data/adb/magisk/busybox /system/bin/busybox /system/xbin/busybox; do
    if [ -x "$bb" ]; then
        BUSYBOX="$bb"
        break
    fi
done
#没有busybox也能跑,只是没有setsid
SETSID=""
if [ -n "$BUSYBOX" ]; then
    SETSID="$BUSYBOX setsid"
fi

chmod 755 "$MODDIR/alist"

#持有wake_lock防止深度睡眠时网络中断
echo "alist_online" > /sys/power/wake_lock 2>/dev/null

#确保data目录存在
mkdir -p "$MODDIR/data"

#首次安装初始化admin密码（已存在数据库则跳过）
if [ ! -f "$MODDIR/data/data.db" ]; then
    "$MODDIR/alist" admin set admin
fi

#日志轮转:超过1MB则保留最后200行
LOG="$MODDIR/download.log"
log_rotate() {
    if [ -f "$LOG" ]; then
        local size
        size=$(wc -c < "$LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            tail -n 200 "$LOG" > "$LOG.tmp"
            mv "$LOG.tmp" "$LOG"
        fi
    fi
}

#启动alist
log_rotate
echo "现在时间$(date +%y-%m-%d-%T)" >> "$LOG"
echo "正在启动的alist版本信息:" >> "$LOG"
"$MODDIR/alist" version >> "$LOG" 2>&1

start_alist() {
    if [ -n "$SETSID" ]; then
        $SETSID "$MODDIR/alist" server --data "$MODDIR/data" &
    else
        "$MODDIR/alist" server --data "$MODDIR/data" &
    fi
}

start_alist

#进程守护看门狗:每60s检查,alist异常退出则自动拉起
while true; do
    sleep 60
    if [ -z "$(pgrep -x alist)" ]; then
        echo "$(date +%y-%m-%d-%T) 看门狗:alist已退出,正在重启" >> "$LOG"
        log_rotate
        start_alist
    fi
done
