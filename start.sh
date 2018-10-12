#!/bin/bash


# ----------------------------------------------------------------------
# name:         start.sh
# version:      1.0.0(100)
# createTime:   2018-08-30
# description:  iOS 资源配置: Icon,LaunchImage,Info.plist,Config.plist
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

## 脚本文件目录
Shell_File_Path=$(cd `dirname $0`; pwd)

# 引用公用文件（public.sh）
source "$Shell_File_Path/public.sh"
# 引用预打包公用文件pre_build_function.sh
source "$Shell_File_Path/pre_build_function.sh"

# 创建存放资源文件目录
Tmp_resource_path="${Package_Dir}/Resource/"
mkdir -p $Tmp_resource_path
# 拷贝配置文件模板config_tpl.plist到资源文件目录
cp -rp "${Shell_File_Path}/config_tpl.plist" $Tmp_resource_path

json_file_name=$1
json_file_path=$2
# 测试
json_file_path="${Shell_File_Path}/test.json"

resource_json_file="$Tmp_resource_path/config.json"
logit "【资源配置】$resource_json_file" 
# 复制打包参数json文件到打包脚本目录
cp -rp $json_file_path $resource_json_file

jq . $resource_json_file

# https://blog.csdn.net/offbye/article/details/38379195
# mac下安装jq，使用brew install jq
# 解析json 打包参数
APP_CFBundleDisplayName=`cat $resource_json_file | jq -r '.app_name'`
APP_CFBundleIdentifier=`cat $resource_json_file | jq -r '.APPLICATION_ID'`
APP_CFBundleShortVersionString=`cat $resource_json_file | jq -r '.VERSION_NAME'`
APP_CFBundleVersion=`cat $resource_json_file | jq -r '.VERSION_CODE'`

CONFIG_project_id=`cat $resource_json_file | jq -r '.PROJECTID'`
CONFIG_merchant_id=`cat $resource_json_file | jq -r '.MERCHANT_ID'`
CONFIG_system_color=`cat $resource_json_file | jq -r '.color_theme'`
CONFIG_baidu_MapKey=`cat $resource_json_file | jq -r '.com_baidu_lbsapi_API_KEY'`
CONFIG_uMeng_AppKey=`cat $resource_json_file | jq -r '.UMENGKEY'`
CONFIG_bugly_AppId=`cat $resource_json_file | jq -r '.BUGLY_APPID'`
CONFIG_bugly_AppKey=`cat $resource_json_file | jq -r '.'BUGLY_APPKEY`
CONFIG_jPush_AppKey=`cat $resource_json_file | jq -r '.JPUSHKEY'`
CONFIG_home_page_num=`cat $resource_json_file | jq -r '.TempletStatus'`
CONFIG_mine_page_num=`cat $resource_json_file | jq -r '.PersonalCenterStatus'`
CONFIG_is_allied_school=`cat $resource_json_file | jq -r '.IsAlliedSchool'`
CONFIG_login_type=`cat $resource_json_file | jq -r '.LOGINFIRST'`
CONFIG_is_always_show_guidepage=`cat $resource_json_file | jq -r '.GuideModel'`
CONFIG_guide_page_num=`cat $resource_json_file | jq -r '.GuideCount'`

apk_name=`cat $resource_json_file | jq -r '.apk_name'`
icon=`cat $resource_json_file | jq -r '.icon'`
start_img=`cat $resource_json_file | jq -r '.start_img'`

GRADLE_SRC=`cat $resource_json_file | jq -r '.GRADLE_SRC'`
uri_name=`cat $resource_json_file | jq -r '.Platform'`


## 下载图片
# You-Get是一个小型命令行实用程序，用于从Web下载媒体内容（视频，音频，图像），以防没有其他方便的方法。
# Github 项目：https://github.com/soimort/you-get
# you-get -o ~/Desktop/PackageLog -O pic 'https://photo.16pic.com/00/03/11/16pic_311875_b.jpg'
# icon
you-get -o $Tmp_resource_path -O icon "$uri_name/$icon"


# 脚本资源里Config.plist文件路径
resource_config_plist="${Tmp_resource_path}/Config.plist"
# 重命名
mv "${Tmp_resource_path}config_tpl.plist" $resource_config_plist

#修改配置文件config.plist
logit "【资源配置】设置打包资源文件中Config.plist文件..."
# 数组
ConfigPlistKeyArray=("Name" "BundleIdentifier" "Version" "Build" "project_id" "merchant_id" "system_color" "baidu_MapKey" "uMeng_AppKey" "bugly_AppId" "bugly_AppKey" "jPush_AppKey" "home_page_num" "mine_page_num" "is_allied_school" "login_type" "is_always_show_guidepage" "guide_page_num" "weChat_AppID" "weChat_AppSecret") 
ConfigPlistValueArray=($APP_CFBundleDisplayName $APP_CFBundleIdentifier $APP_CFBundleShortVersionString $APP_CFBundleVersion $CONFIG_project_id $CONFIG_merchant_id $CONFIG_system_color $CONFIG_baidu_MapKey $CONFIG_uMeng_AppKey $CONFIG_bugly_AppId $CONFIG_bugly_AppKey $CONFIG_jPush_AppKey $CONFIG_home_page_num $CONFIG_mine_page_num $CONFIG_is_allied_school $CONFIG_login_type $CONFIG_is_always_show_guidepage $CONFIG_guide_page_num $CONFIG_weChat_AppID $CONFIG_weChat_AppSecret)

if [ ! -f "${resource_config_plist}" ]; then
    errorExit "Resource中缺少Config.plist 文件"
fi

for i in "${!ConfigPlistKeyArray[@]}"; do
    dictKey=${ConfigPlistKeyArray[$i]}
    dictValue=${ConfigPlistValueArray[$i]}
    # 替换对应值
    setResource_Config "$dictKey" "$dictValue"
    if [ $? -eq 0 ];then
        logit "【资源配置】$dictKey: $dictValue"
    else
        warning "设置资源Config.plist文件$dictKey失败"
    fi
done