#!/bin/bash


# ----------------------------------------------------------------------
# name:         public.sh
# version:      1.0.0(100)
# createTime:   2018-09-29
# description:  公用文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

#############################################常用工具#############################################

CMD_PlistBuddy="/usr/libexec/PlistBuddy"
CMD_Xcodebuild=$(which xcodebuild)
CMD_Security=$(which security)
CMD_Lipo=$(which lipo)
CMD_Codesign=$(which codesign)

#############################################常用变量#############################################

## 打包输出目录
Package_Dir=~/Desktop/PackageLog/`date +"%Y%m%d%H%M%S"` 
if [[ ! -d "$Package_Dir" ]]; then
	mkdir -p "$Package_Dir"
else
	errorExit "打包输出目录有误"
fi

## 打包工程文件拷贝目录路径
project_build_path="${Package_Dir}/iXiao_build"
##历史打包备份目录
History_Package_Dir="$Package_Dir/History"
## 脚本生成的日志文件
Tmp_Log_File="$Package_Dir/package_log.txt"
## 脚本临时生成最终用于构建的配置文件
Tmp_Build_Xcconfig_File="$Package_Dir/build.xcconfig"
##临时OptionsPlist文件
Tmp_Options_Plist_File="$Package_Dir/optionsplist.plist"

# 默认资源文件路径
Tmp_resource_path="${Shell_File_Path}/Resource/xinyue"


## 用户配置Plist文件
ShellUserConfigPlist="$Shell_File_Path/user_config.plist"

## 脚本工作目录(项目目录)
Shell_Work_Path=$project_build_path

#############################################业务配置#############################################

# config.plist key 数组
ConfigPlistKeyArray=("AppName" "BundleIdentifier" "Version" "Build" "project_id" "merchant_id" "system_color" "baidu_MapKey" "uMeng_AppKey" "bugly_AppId" "bugly_AppKey" "jPush_AppKey" "home_page_num" "mine_page_num" "is_allied_school" "login_type" "is_always_show_guidepage" "guide_count" "weChat_AppID" "weChat_AppSecret") 

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
    echo "$@" >> "$Tmp_Log_File"

}

## 错误日志输出
function errorExit() {
    echo -e "\033[31m【AutoPackingShell】$@ \033[0m"
    exit 1
}

## 警告日志输出
function warning() {
    echo -e "\033[33m【警告】$@ \033[0m"
}


