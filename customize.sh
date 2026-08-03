#!/system/bin/sh

ui_print "安装中，请稍等..."
ui_print "OpenList是一款提供多个储存挂载服务的开源程序"
ui_print "开机自启,看门狗守护进程"
ui_print "地址:http://127.0.0.1:5244 账户 admin 密码 admin"

#安装时给所有脚本加权限(解决Magisk挂载后权限丢失)
MODDIR=${0%/*}
chmod 755 "$MODDIR/openlist" 2>/dev/null
chmod 755 "$MODDIR/service.sh" 2>/dev/null
chmod 755 "$MODDIR/start_openlist.sh" 2>/dev/null
chmod 755 "$MODDIR/post-fs-data.sh" 2>/dev/null
chmod 755 "$MODDIR/action.sh" 2>/dev/null
chmod 755 "$MODDIR/uninstall.sh" 2>/dev/null
chmod 755 "$MODDIR/customize.sh" 2>/dev/null

ui_print "安装已完成，重启生效"
