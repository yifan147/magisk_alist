#!/system/bin/sh
#Magisk模块操作交互脚本
#点击"操作"按钮时由Magisk触发,提供音量键导航的开关控制

MODDIR=${0%/*}
cd "$MODDIR" || exit 1

#检测alist是否正在运行
is_running() {
    [ -n "$(pgrep -x alist)" ]
}

#主循环:显示菜单并处理用户选择
while true; do
    if is_running; then
        #模块运行中:显示关闭选项
        choice=$(ui_ask "AList 运行中" "关闭模块" "退出选择界面")
        case "$choice" in
            1)
                #执行停止
                sh "$MODDIR/start_alist.sh" stop
                ;;
            2)
                #退出菜单
                break
                ;;
        esac
    else
        #模块已停止:显示打开选项
        choice=$(ui_ask "AList 已停止" "打开模块" "退出选择界面")
        case "$choice" in
            1)
                #执行启动
                sh "$MODDIR/start_alist.sh" launch
                ;;
            2)
                #退出菜单
                break
                ;;
        esac
    fi
done

#脚本结束后Magisk会自动刷新模块列表,显示最新状态描述
