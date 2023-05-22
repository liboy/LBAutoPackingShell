#!/bin/bash


# ----------------------------------------------------------------------
# name:         public.sh
# version:      1.0.6(106)
# createTime:   2018-09-29
# description:  公用文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

#############################################常用工具#############################################

CMD_PlistBuddy="/usr/libexec/PlistBuddy"xxxxxxx
CMD_Xcodebuild=$(which xcodebuild)xxxxxx
CMD_Security=$(which security)
CMD_Lipo=$(which lipo)
CMD_Codesign=$(which codesign)xxxxxxx

#############################################常用变量#############################################

CurrentDateStr=`date +"%Y%m%d%H%M%S"`xxxxxxxxxxxxx
## 区分（线上自动：Online 线下手动：Offline）
Package_Mode="Offline"
# 默认打包输出根目录
Package_Root_Dir=~/Sites/files/PackageLog
# 默认线下资源文件路径
Tmp_resource_path="${Shell_File_Path}/Resource"
# 授权文件目录
Provision_Dir="${Shell_File_Path}/MobileProvision"
## 用户配置Plist文件
ShellUserConfigPlist="$Shell_File_Path/user_config.plist"


##############################################默认配置###############################################

CODE_SIGN_STYLE='Manual'
pgyer_userKey="b805f985351b48620bd95cc5e4ab579b"
pgyer_apiKey="b9bcf5ef168fdf8ce379ae9ab9bd8dcc"

#############################################业务配置#############################################


ProjectConfigPlistKeyArray=("project_id" "merchant_id" "system_color" "baidu_MapKey" "uMeng_AppKey" "bugly_AppId" "bugly_AppKey" "jPush_AppKey" "home_page_num" "mine_page_num" "is_allied_school" "login_type" "is_always_show_guidepage" "guide_count" "weChat_AppID" "weChat_AppSecret") 
# LaunchImage需要的启动图需要对应尺寸，目前需要
# 1125x2436(5.8英寸)  目前机型: iPhoneX
# 1242x2208(5.5英寸)  目前机型: 6Plus，6sPlus，7Plus
# 750x1334(4.7英寸)   目前机型: 6，6s，7
# 640x1136(4英寸)     目前机型: 5，5s，SE
# 640x960(3.5英寸)    目前机型: 4，4s
LaunchImageArray=("1125x2436" "1242x2208" "750x1334" "640x1136" "640x960")


#############################################日志函数#############################################

## 日志格式化输出
function logit() {
    echo -e "\033[32m [AutoPackingShell] \033[0m $@" 
    if [[ $Tmp_Log_File ]]; then
    	echo "$@" >> "$Tmp_Log_File"
    fi

}

## 错误日志输出
function errorExit() {
    echo -e "\033[31m【AutoPackingShell】$@ \033[0m"
    echo "$@" >> "$Tmp_Log_File"
    exit 1
}

## 警告日志输出
function warning() {
    echo -e "\033[33m【警告】$@ \033[0m"
    # echo "$@" >> "$Tmp_Log_File"
}


