#!/bin/bash

# ----------------------------------------------------------------------
# name:         start.sh
# version:      1.0.0(100)
# createTime:   2018-09-30
# description:  iOS 自动打包脚本，可配置: Icon,LaunchImage,Info.plist,Config.plist
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/ios_auto_package_shell
# ----------------------------------------------------------------------


## 脚本文件目录
Shell_File_Path=$(cd `dirname $0`; pwd)

# 引用公用文件（public.sh）
source "./public.sh"
# 引用pre_build_function.sh
source "./pre_build_function.sh"



## 初始化用户配置 
initUserConfigFile
## 初始化项目配置
initProjectConfig


## 拷贝项目(打包工程)
# copyProjectFile

## 生成并替换AppIcon
createAppIcon

## 替换launchImage
replaceLaunchImage

## 更改项目配置文件
changeProjectProfile

# clear cache
# clearTmpCache

## 打包脚本
source "./IPABuildShell.sh"




