#!/system/bin/sh
MODDIR=${0%/*}
BUSYBOX="/data/adb/magisk/busybox"
cd $MODDIR/
chmod 755 alist

#持有wake_lock防止深度睡眠时网络中断（OriginOS省电策略下保持alist可达）
echo "alist_online" > /sys/power/wake_lock

#首次安装初始化admin密码（已存在数据库则跳过）
init_admin() {
	if [ ! -f $MODDIR/data/data.db ]; then
		$MODDIR/alist admin set admin
	fi
}

#日志轮转:超过1MB则保留最后200行,防止长期运行膨胀
log_rotate() {
	if [ -f $MODDIR/download.log ]; then
		local size=$(wc -c < $MODDIR/download.log 2>/dev/null || echo 0)
		if [ "$size" -gt 1048576 ]; then
			tail -n 200 $MODDIR/download.log > $MODDIR/download.log.tmp
			mv $MODDIR/download.log.tmp $MODDIR/download.log
		fi
	fi
}

start_alist() {
	cd $MODDIR/
	chmod 755 alist
	log_rotate
	echo "现在时间$(date +%y-%m-%d-%T)" >> download.log
	echo "正在启动的alist版本信息:
$($MODDIR/alist version)" >> download.log
	#setsid让alist脱离service.sh会话,即使service.sh被回收alist仍可继续运行
	$BUSYBOX setsid $MODDIR/alist server --data $MODDIR/data &
}

stop_alist() {
	if [ -n "$(pgrep -x alist)" ]; then
		pkill -x alist
		sleep 2s
	fi
}

check_alist() {
	if [ -n "$(pgrep -x alist)" ]; then
		echo "$(date +%y-%m-%d-%T) 健康检查:alist正在运行" >> download.log
	else
		echo "$(date +%y-%m-%d-%T) 健康检查:alist未运行" >> download.log
	fi
}

#进程守护看门狗:每60s检查,alist异常退出则自动拉起
watchdog() {
	while true; do
		sleep 60s
		if [ -z "$(pgrep -x alist)" ]; then
			echo "$(date +%y-%m-%d-%T) 看门狗:alist已退出,正在重启" >> download.log
			start_alist
		fi
	done
}

#启动alist
init_admin
sleep 1s
start_alist
check_alist
#后台启动看门狗守护进程
watchdog &
#主循环守住service.sh进程,让看门狗持续存活
while true;
do
	sleep 1d
	check_alist
done
