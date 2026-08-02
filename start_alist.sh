#!/system/bin/sh
#Magisk模块核心启动脚本,由service.sh和post-fs-data.sh共同调用
#锁文件,防止service.sh和post-fs-data.sh重复启动
LOCK="$MODDIR/.started"

#如果已经启动过,直接退出
if [ -f "$LOCK" ]; then
    exit 0
fi
touch "$LOCK"

BUSYBOX="/data/adb/magisk/busybox"
cd $MODDIR/
chmod 755 alist

#持有wake_lock防止深度睡眠时网络中断
echo "alist_online" > /sys/power/wake_lock

#确保data目录存在
mkdir -p $MODDIR/data

#首次安装初始化admin密码（已存在数据库则跳过）
if [ ! -f $MODDIR/data/data.db ]; then
    $MODDIR/alist admin set admin
fi

#日志轮转:超过1MB则保留最后200行
log_rotate() {
    if [ -f $MODDIR/download.log ]; then
        local size=$(wc -c < $MODDIR/download.log 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            tail -n 200 $MODDIR/download.log > $MODDIR/download.log.tmp
            mv $MODDIR/download.log.tmp $MODDIR/download.log
        fi
    fi
}

#启动alist
log_rotate
echo "现在时间$(date +%y-%m-%d-%T)" >> download.log
echo "正在启动的alist版本信息:
$($MODDIR/alist version)" >> download.log
#setsid让alist脱离当前会话
$BUSYBOX setsid $MODDIR/alist server --data $MODDIR/data &

#进程守护看门狗:每60s检查,alist异常退出则自动拉起
while true; do
    sleep 60s
    if [ -z "$(pgrep -x alist)" ]; then
        echo "$(date +%y-%m-%d-%T) 看门狗:alist已退出,正在重启" >> download.log
        log_rotate
        $BUSYBOX setsid $MODDIR/alist server --data $MODDIR/data &
    fi
done
