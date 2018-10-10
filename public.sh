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

##打包输出目录
Package_Dir=~/Desktop/PackageLog

## 打包工程文件拷贝目录路径
project_build_path="${Package_Dir}/iXiao_build"
##历史打包备份目录
History_Package_Dir="$Package_Dir/History"
## 脚本生成的日志文件
Tmp_Log_File="$Package_Dir/`date +"%Y%m%d%H%M%S"`.txt"
## 脚本临时生成最终用于构建的配置文件
Tmp_Build_Xcconfig_File="$Package_Dir/build.xcconfig"
##临时OptionsPlist文件
Tmp_Options_Plist_File="$Package_Dir/optionsplist.plist"


## 用户配置Plist文件
ShellUserConfigPlist="./user_config.plist"

## 脚本工作目录(项目目录)
Shell_Work_Path=$project_build_path


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