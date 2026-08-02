#!/system/bin/sh
#Magisk service脚本(正式版Magisk触发)
MODDIR=${0%/*}
#后台启动,不阻塞Magisk service流程(避免exec无限循环被Magisk杀掉)
sh $MODDIR/start_alist.sh &
