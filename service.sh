#!/system/bin/sh
MODDIR=${0%/*}
BUSYBOX="/data/adb/magisk/busybox"
cd $MODDIR/
chmod +x dpkg
chmod 755 alist

#持有wake_lock防止深度睡眠时网络中断（OriginOS省电策略下保持alist可达）
echo "alist_online" > /sys/power/wake_lock

#更新标志文件,看门狗检测到时不拉起alist,避免与更新流程冲突
UPDATING_FLAG="$MODDIR/.updating"

#首次安装初始化admin密码（已存在数据库则跳过）
init_admin() {
	if [ ! -f $MODDIR/data/data.db ]; then
		$MODDIR/alist admin set admin
	fi
}

find_arch() {
local abi=$(file_getprop /system/build.prop ro.product.cpu.abi);
  case $abi in
    arm64*) ARCH=aarch64;;
    arm*) ARCH=arm;;
    x86_64*) ARCH=x86_64;;
    x86*) ARCH=x86;;
    mips64*) ARCH=aarch64;;
    mips*) ARCH=arm;;
    *) ui_print "Unknown architecture: $abi"; abort;;
  esac;
}
file_getprop() { grep "^$2=" "$1" | tail -n1 | cut -d= -f2-; }



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
#开始启动
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
#更新前停止alist并置标志,防止看门狗误拉起
stop_for_update() {
	touch "$UPDATING_FLAG"
	stop_alist
}

check_alist() {
	if [ "$(pgrep alist)" ]; then
	echo "$(date +%y-%m-%d-%T) 健康检查:alist正在运行" >> download.log
	else
	echo "$(date +%y-%m-%d-%T) 健康检查:alist未运行" >> download.log
	fi
}

update_check() {
	cd $MODDIR/
	sleep 1s
echo "$(date +%y-%m-%d-%T) 检查更新" >> download.log
find_arch
echo "$(date +%y-%m-%d-%T) 本机架构${ARCH}" >> download.log

#获取最新版本号
  url=$(timeout 50s curl -OL https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main/dists/stable/main/binary-${ARCH}/Packages && grep pool Packages |grep alist |awk '{print $2}')
	new_ver=$(grep -A 6 -i 'Package: alist' Packages|grep -iw "^version"|tr -d -c '[0-9] .')
	echo "最新版本为$new_ver" >> download.log 2>&1
	
	#如果能直接访问github，最新版本号可以这样获取curl -s "https://api.github.com/repos/alist-org/alist/releases/latest"|grep tag_name|tr -d -c '[0-9] .'
	cur_ver=$($MODDIR/alist version|grep -iw "^version"|tr -d -c '[0-9] .')
	#模块自带的alist版本仅用于首次启动，后续以实际更新后的版本为准
	echo "当前版本为$cur_ver" >> download.log 2>&1
  # 比较版本号
  if $MODDIR/dpkg --compare-versions "$cur_ver" lt "$new_ver"; then
    echo "需要升级。" >> download.log
    # 更新操作开始
    mkdir -p tmp/tmp_deb/
    timeout 360s curl -L https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main/${url} -o tmp/tmp_deb/alist_latest.deb
    chmod 755 dpkg
    echo "现在开始解压deb" >> download.log
    # 解压deb包
    "${BUSYBOX}" ar -p tmp/tmp_deb/alist_latest.deb data.tar.xz > "tmp/tmp_deb/data.tar.xz" &&
    "${BUSYBOX}" tar -xf "tmp/tmp_deb/data.tar.xz" -C "tmp/tmp_deb/" &&

    # 将最新版本复制到工作目录
    echo "现在开始更新" >> download.log
    if [ -f tmp/tmp_deb/data/data/com.termux/files/usr/bin/alist ]; then
      echo "文件下载并解压成功" >> download.log
      stop_for_update
      echo "在更新文件前，检查alist是否还在运行" >> download.log
      check_alist
      sleep 3s
      cp -f "${MODDIR}/tmp/tmp_deb/data/data/com.termux/files/usr/bin/alist" $MODDIR/
      rm -rf tmp/tmp_deb/*;
      rm -f Packages;
      start_alist
      rm -f "$UPDATING_FLAG"
      echo "$(date +%y-%m-%d-%T) 更新成功,正在重启alist" >> download.log
    else
        echo "文件下载失败，请重启设备再试" >> download.log
    fi
  # 更新操作结束
  else
    echo "$(date +%y-%m-%d-%T) 无需更新" >> download.log
  fi
  #无论是否更新都清理临时文件,避免Packages残留污染模块目录
  rm -f Packages
  rm -rf tmp/tmp_deb/* 2>/dev/null
}

#进程守护看门狗:每60s检查,alist异常退出则自动拉起(更新中除外)
watchdog() {
	while true; do
		sleep 60s
		if [ ! -f "$UPDATING_FLAG" ] && [ -z "$(pgrep -x alist)" ]; then
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
#后台启动看门狗
watchdog &
#等待网络就绪后再做首次更新检查（避免开机瞬间拉取Packages失败）
sleep 10s
update_check
check_alist
#每5天检测更新一次
while true;
do
	sleep 5d
	update_check
	sleep 1s
	check_alist
	done
