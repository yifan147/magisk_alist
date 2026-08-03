#!/system/bin/sh
#Magisk OpenList模块核心脚本
#用法:
#  无参数: 开机启动流程(初始化+启动+看门狗)
#  launch: 手动启动OpenList(由action.sh调用)
#  stop:   手动停止OpenList(由action.sh调用)

#自行计算MODDIR,不依赖外部变量
MODDIR=$(dirname "$0")
[ "$MODDIR" = "." ] && MODDIR=$(pwd)
cd "$MODDIR" || exit 1

#========== 给OpenList二进制加可执行权限(每次都执行,解决Magisk挂载后权限丢失) ==========
chmod_openlist() {
    chmod 755 "$MODDIR/openlist" 2>/dev/null
}

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
    #每次都加权限,防止Magisk挂载后权限丢失
    chmod_openlist
}

#========== 一次性初始化(仅首次执行) ==========
init_module() {
    local LOCK="$MODDIR/.started"
    [ -f "$LOCK" ] && return 0
    touch "$LOCK"

    chmod_openlist
    #持有wake_lock防止深度睡眠时网络中断
    echo "openlist_online" > /sys/power/wake_lock 2>/dev/null
    #确保data目录存在
    mkdir -p "$MODDIR/data"
    #首次安装初始化admin密码
    if [ ! -f "$MODDIR/data/data.db" ]; then
        "$MODDIR/openlist" admin set admin
    fi
}

#========== 获取当前WiFi的IP地址 ==========
get_wifi_ip() {
    local ip=""
    # 方法1: ip命令(toybox)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | awk '{print $2}' | head -1)
    fi
    # 方法2: busybox ifconfig
    if [ -z "$ip" ] && [ -n "$BUSYBOX" ]; then
        ip=$($BUSYBOX ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | sed 's/addr://' | head -1)
    fi
    # 方法3: getprop (DHCP分配的IP)
    if [ -z "$ip" ]; then
        ip=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    fi
    echo "$ip"
}

#========== 更新module.prop状态描述(含WiFi IP) ==========
update_status_desc() {
    local status="$1"
    local ip
    ip=$(get_wifi_ip)
    local access="http://127.0.0.1:5244"
    [ -n "$ip" ] && access="http://${ip}:5244"
    local status_symbol="✗ 已停止"
    [ "$status" = "运行中" ] && status_symbol="✓ 运行中"
    local new_desc="arm64原生运行OpenList,看门狗守护,双触发兼容alpha版 | 访问 ${access} 账户admin/admin | ${status_symbol}"
    sed "s#^description=.*#description=${new_desc}#" "$MODDIR/module.prop" > "$MODDIR/module.prop.tmp"
    mv "$MODDIR/module.prop.tmp" "$MODDIR/module.prop"
}

#========== 检查OpenList是否真正运行 ==========
is_really_running() {
    [ -z "$(pgrep -f 'openlist server')" ] && return 1
    sleep 2
    [ -z "$(pgrep -f 'openlist server')" ] && return 1
    return 0
}

#========== 启动OpenList进程 ==========
launch_openlist() {
    #清除暂停标记
    rm -f "$MODDIR/.paused"
    #每次启动前重新加权限
    chmod_openlist

    #日志轮转:超过1MB则保留最后200行
    local LOG="$MODDIR/openlist.log"
    if [ -f "$LOG" ]; then
        local size
        size=$(wc -c < "$LOG" 2>/dev/null || echo 0)
        if [ "$size" -gt 1048576 ]; then
            tail -n 200 "$LOG" > "$LOG.tmp"
            mv "$LOG.tmp" "$LOG"
        fi
    fi

    echo "现在时间$(date +%y-%m-%d-%T)" >> "$LOG"
    echo "正在启动的OpenList版本信息:" >> "$LOG"
    #每次执行前chmod
    chmod_openlist
    "$MODDIR/openlist" version >> "$LOG" 2>&1

    # 优先用系统setsid(toybox),其次busybox,确保OpenList脱离会话不被SIGHUP终止
    if command -v setsid >/dev/null 2>&1; then
        setsid "$MODDIR/openlist" server --data "$MODDIR/data" >> "$LOG" 2>&1 &
    elif [ -n "$BUSYBOX" ]; then
        "$BUSYBOX" setsid "$MODDIR/openlist" server --data "$MODDIR/data" >> "$LOG" 2>&1 &
    else
        "$MODDIR/openlist" server --data "$MODDIR/data" >> "$LOG" 2>&1 &
    fi

    #等待5秒后检测真实状态
    sleep 5
    if is_really_running; then
        update_status_desc "运行中"
        echo "$(date +%y-%m-%d-%T) 启动成功,OpenList正在运行" >> "$LOG"
    else
        update_status_desc "已停止"
        echo "$(date +%y-%m-%d-%T) [错误] OpenList启动失败,请检查日志" >> "$LOG"
        echo "[错误] OpenList启动失败,请查看openlist.log" >&2
    fi
}

#========== 停止OpenList进程 ==========
stop_openlist() {
    #创建暂停标记,通知看门狗不要重启
    touch "$MODDIR/.paused"
    #终止OpenList进程
    pkill -f 'openlist server' 2>/dev/null
    #释放wake_lock
    echo "openlist_online" > /sys/power/wake_unlock 2>/dev/null
    update_status_desc "已停止"
}

#========== 看门狗循环 ==========
run_watchdog() {
    local last_ip=""
    while true; do
        sleep 60
        #如果被手动暂停,跳过重启
        if [ -f "$MODDIR/.paused" ]; then
            continue
        fi
        #检查OpenList进程是否存活
        if [ -z "$(pgrep -f 'openlist server')" ]; then
            echo "$(date +%y-%m-%d-%T) 看门狗:OpenList已退出,正在重启" >> "$MODDIR/openlist.log"
            launch_openlist
        else
            # 进程在跑,检查WiFi IP是否变化,变化则刷新description
            local cur_ip
            cur_ip=$(get_wifi_ip)
            if [ "$cur_ip" != "$last_ip" ]; then
                last_ip="$cur_ip"
                update_status_desc "运行中"
            fi
        fi
    done
}

#========== 主入口 ==========
setup_env

case "${1:-}" in
    launch)
        #手动启动(由action.sh调用)
        launch_openlist
        ;;
    stop)
        #手动停止(由action.sh调用)
        stop_openlist
        ;;
    *)
        #开机启动流程
        # 并发锁:防止service.sh和post-fs-data.sh同时启动
        BOOT_LOCK="$MODDIR/.boot_lock"
        if [ -f "$BOOT_LOCK" ]; then
            LOCK_PID=$(cat "$BOOT_LOCK" 2>/dev/null)
            if [ -n "$LOCK_PID" ] && [ -d "/proc/$LOCK_PID" ]; then
                exit 0
            fi
        fi
        echo $$ > "$BOOT_LOCK"
        # 清除跨重启的.started锁,确保每次开机重新初始化(特别是重新获取wake_lock)
        rm -f "$MODDIR/.started"
        init_module
        launch_openlist
        run_watchdog
        ;;
esac
