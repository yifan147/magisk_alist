#!/system/bin/sh
#post-fs-data:alpha版Magisk的兜底启动器
#比service.sh更早触发,但此时系统刚启动完成,需要等待系统就绪
MODDIR=${0%/*}
(
    #等待系统完全启动
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done
    #额外等5秒,确保Magisk守护进程就绪
    sleep 5
    #后台启动,不exec(避免无限循环阻塞)
    sh $MODDIR/start_openlist.sh
) &
