#!/system/bin/sh
#Magisk service脚本(正式版Magisk触发)
MODDIR=${0%/*}
exec $MODDIR/start_alist.sh
