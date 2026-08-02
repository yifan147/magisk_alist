#!/system/bin/sh
#Magisk Alist模块核心脚本
#用法:
#  无参数: 开机启动流程(初始化+启动+看门狗)
#  launch: 手动启动alist(由action.sh调用)
#  stop:   手动停止alist(由action.sh调用)

#自行计算MODDIR,不依赖外部变量
MODDIR=$(dirname "$0")
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
cd "$MODDIR" || exit 1

#========== 环境设置(每次都执行) ==========
setup_env() {
    #寻找busybox( Magisk自带,位置可能不同 )
    BUSYBOX=""
    for bb in /data/adb/magisk/busybox /system/bin/busybox /system/xbin/busybox; do
        if [ -x "$bb" ]; then
            BUSYBOX="$bb"
            break
        fi
    done
    SETSID=""
    [ -n "$BUSYBOX" ] && SETSID="$BUSYBOX setsid"
}

#========== 一次性初始化(仅首次执行) ==========
init_module() {
    local LOCK="$MODDIR/.started"
    [ -f "$LOCK" ] && return 0
    touch "$LOCK"

    chmod 755 "$MODDIR/alist"
    #持有wake_lock防止深度睡眠时网络中断
    echo "alist_online" > /sys/power/wake_lock 2>/dev/null
    #确保data目录存在
    mkdir -p "$MODDIR/data"
    #首次安装初始化admin密码
    if [ ! -f "$MODDIR/data/data.db" ]; then
        "$MODDIR/alist" admin set admin
    fi
    #更新状态描述为已停止
    update_status_desc "已停止"
}

#========== 更新module.prop状态描述 ==========
update_status_desc() {
    local status="$1"
    local base_desc="arm64设备原生运行alist,开机自启,看门狗守护,双触发兼容alpha版Magisk,默认账户admin/admin"
    local new_desc
    case "$status" in
        运行中)  new_desc="${base_desc} ✓ 运行中" ;;
        已停止)  new_desc="${base_desc} ✗ 已停止" ;;
        *)       new_desc="${base_desc}" ;;
    esac
    #用#作sed分隔符,避免与description中的|冲突
    sed "s#^description=.*#description=${new_desc}#" "$MODDIR/module.prop" > "$MODDIR/module.prop.tmp"
    mv "$MODDIR/module.prop.tmp" "$MODDIR/module.prop"
}

#========== 启动alist进程 ==========
launch_alist() {
    #清除暂停标记
    rm -f "$MODDIR/.paused"

    #日志轮转:超过1MB则保留最后200行
    local LOG="$MODDIR/download.log"
    if [ -f "$LOG" ]; then
        local size
        size=$(wc -c < "$LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            tail -n 200 "$LOG" > "$LOG.tmp"
            mv "$LOG.tmp" "$LOG"
        fi
    fi

    echo "现在时间$(date +%y-%m-%d-%T)" >> "$LOG"
    echo "正在启动的alist版本信息:" >> "$LOG"
    "$MODDIR/alist" version >> "$LOG" 2>&1

    if [ -n "$SETSID" ]; then
        $SETSID "$MODDIR/alist" server --data "$MODDIR/data" &
    else
        "$MODDIR/alist" server --data "$MODDIR/data" &
    fi

    update_status_desc "运行中"
}

#========== 停止alist进程 ==========
stop_alist() {
    #创建暂停标记,通知看门狗不要重启
    touch "$MODDIR/.paused"
    #终止alist进程
    pkill -x alist 2>/dev/null
    #释放wake_lock
    echo "alist_online" > /sys/power/wake_unlock 2>/dev/null
    update_status_desc "已停止"
}

#========== 看门狗循环 ==========
run_watchdog() {
    while true; do
        sleep 60
        #如果被手动暂停,跳过重启
        if [ -f "$MODDIR/.paused" ]; then
            continue
        fi
        #检查alist进程是否存活
        if [ -z "$(pgrep -x alist)" ]; then
            echo "$(date +%y-%m-%d-%T) 看门狗:alist已退出,正在重启" >> "$MODDIR/download.log"
            launch_alist
        fi
    done
}

#========== 主入口 ==========
setup_env

case "${1:-}" in
    launch)
        #手动启动(由action.sh调用)
        launch_alist
        ;;
    stop)
        #手动停止(由action.sh调用)
        stop_alist
        ;;
    *)
        #开机启动流程
        init_module
        launch_alist
        run_watchdog
        ;;
esac
