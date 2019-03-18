#!/bin/bash


# ----------------------------------------------------------------------
# name:         pre_build_function.sh
# version:      1.0.6(106)
# createTime:   2018-08-30
# description:  打包之前处理函数文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

# ********************* user_config.plist *********************
#读取   ShellUserConfigPlist.plist文件
function printUserConfigPlist() {
    echo `$CMD_PlistBuddy -c "Print :${1}" ${ShellUserConfigPlist}`
}
#写入   ShellUserConfigPlist.plist文件
function setUserConfigPlist() {
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${ShellUserConfigPlist}`
}

# ********************* 读资源文件 *********************
function printResource_Config() {
    # 脚本资源里Config.plist文件路径
    local configPlistPath="${Tmp_resource_path}/Config.plist"
    echo `$CMD_PlistBuddy -c "Print :${1}" ${configPlistPath}`
}
function setResource_Config() {
    local configPlistPath="${Tmp_resource_path}/Config.plist"
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' $configPlistPath`
    if [ $? -eq 0 ];then
        logit "【资源配置】${1}: ${2}"
    else
        warning "配置资源Config.plist文件${1}失败"
    fi
}

function setProject_Config() {
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${project_config_plist}`
}

# ********************* 项目中Info.plist配置 *********************

function printProject_Info() {
    # 项目里Info.plist文件路径
    local project_info_plist="${project_build_path}/${project_name}/Info.plist"
    echo `$CMD_PlistBuddy -c "Print :${1}" ${project_info_plist}`
}

function setProject_Info() {
    # 项目里Info.plist文件路径
    local project_info_plist="${project_build_path}/${project_name}/Info.plist"
    echo `$CMD_PlistBuddy -c 'Set :'${1}' "'${2}'"' ${project_info_plist}`
}


# 判断 数组是否包含对应元素
function contains() {
    # $#:参数个数
    # ${!n} 根据索引获取对应参数
    local n=$#
    for ((i=1;i < n;i++)) {
        if [ "${!i}" == "${!n}" ]; then
        echo "y"
        return 0
        fi
    }
    echo "n"
    return 1
}
## 修改配置文件资源名称
function replaceResourceName() {

    while true;do
        read -p "请输入资源文件名称:" input_name
        local resource_path="${Tmp_resource_path}/$input_name"
        if [[ ! -d $resource_path || $input_name == "" ]]; then
            echo "${resource_path}目录不存在,或名称不能为空"
            continue
        else
            echo "${resource_path}目录存在"
            Tmp_resource_path="$resource_path"
            setUserConfigPlist "resource_name" "$input_name"
            break
        fi
    done
}
## 设置资源名称
function setResourceName() {
    while true; do
        read -p "当前读取的资源文件 ${resource_name} 是否要改变（y/n）:" isChange
        if [[ $isChange == "y" ]];then
            # 列出 Tmp_resource_path 目录下的所有文件夹名称
            cd $Tmp_resource_path
            echo "========现有的资源文件=========>"
            for file in $(ls)
            do
                echo $file
            done
            echo "=============================>"
            replaceResourceName
            break
        elif [[ $isChange == "n" ]];then
            Tmp_resource_path="${Tmp_resource_path}/$resource_name"
            break
        else
            continue
        fi
    done
}

## 初始化用户配置
function initUserConfigFile() {

    #脚本全局参数配置文件user_config.plist(脚本参数优先于全局配置参数)
    # 项目名称
    project_name=`printUserConfigPlist "project_name"`
    # 项目源码文件路径
    project_source_path=`printUserConfigPlist "project_source_path"`
    # keychain解锁密码，即开机密码
    UNLOCK_KEYCHAIN_PWD=`printUserConfigPlist "unlock_keychain_pwd"`
    
    # 构建模式：Debug/Release ；默认 Release
    CONFIGRATION_TYPE=`printUserConfigPlist "configration_type"`
    if [[ ! "$CONFIGRATION_TYPE" ]]; then
        CONFIGRATION_TYPE="Release"
    fi

    # 指定分发渠道，development 内部分发，app-store商店分发，enterprise企业分发， ad-hoc 企业内部分发"
    CHANNEL=`printUserConfigPlist "channel"`
    if [[ ! "$CHANNEL" ]]; then
        CHANNEL="app-store"
    fi
    ##指定构建的target,不指定默认工程的第一个target
    BUILD_TARGET=`printUserConfigPlist "build_target"`

    ##指定打包资源文件名称
    resource_name=`printUserConfigPlist "resource_name"`
    

}

##初始化打包路径
function initPackageDir() {

    local CurrentDateStr=$1
    local Package_Mode=$2

    ## 默认线下打包输出目录
    Package_Dir="$Package_Root_Dir/$Package_Mode"
    if [[ ! -d "$Package_Dir" ]]; then
        mkdir -p "$Package_Dir"
    fi
    ## 线上服务打包处理
    if [[ $Package_Mode == "Online" ]]; then
        Package_Dir="$Package_Root_Dir/$Package_Mode/$CurrentDateStr" 
        # 临时存放资源文件目录
        Tmp_resource_path="$Package_Dir/Resource"
        # 授权文件目录
        Provision_Dir=$Tmp_resource_path
        if [[ ! -d "$Tmp_resource_path" ]]; then
            mkdir -p "$Tmp_resource_path"
        fi
        # 拷贝配置文件模板config_tpl.plist到资源文件目录
        cp -rp "${Shell_File_Path}/config_tpl.plist" $Tmp_resource_path
    else
        ## 线下设置资源路径
        setResourceName
    fi
    
    # 自动打开打包输出目录
    open $Package_Dir

    ## 打包工程文件拷贝目录路径
    project_build_path="$Package_Dir/iXiao_build"
    ## 历史打包备份目录
    History_Package_Dir="$Package_Dir/History"
    ## 脚本临时生成最终用于构建的配置文件
    Tmp_Build_Xcconfig_File="$Package_Dir/build.xcconfig"
    ## 临时OptionsPlist文件
    Tmp_Options_Plist_File="$Package_Dir/OptionsPlist.plist"
    ## 临时ProvisionPlist文件
    Tmp_Provision_Plist_File="$Package_Dir/ProvisionPlist.plist"
    ## 脚本生成的日志文件
    Tmp_Log_File="$Package_Dir/${CurrentDateStr}.txt"
    ## 脚本生成的证书文件
    Tmp_Cer_File="$Package_Dir/tmp.cer"

    logit "【用户配置】项目名称: ${project_name}"
    logit "【用户配置】源码文件路径: ${project_source_path}"
    logit "【用户配置】keychain解锁密码: ${UNLOCK_KEYCHAIN_PWD}"
    logit "【用户配置】构建模式: ${CONFIGRATION_TYPE}"
    logit "【用户配置】分发渠道: ${CHANNEL}"
    
   
    logit "【用户配置】预打包项目路径: ${project_build_path}"
    logit "【用户配置】历史打包备份目录: ${History_Package_Dir}"
    logit "【用户配置】脚本生成的日志文件: ${Tmp_Log_File}"
    logit "【用户配置】脚本生成构建的配置文件: ${Tmp_Build_Xcconfig_File}"
    logit "【用户配置】脚本生成OptionsPlist文件: ${Tmp_Options_Plist_File}"
    logit "【用户配置】打包资源文件目录: ${Tmp_resource_path}"
    logit "【用户配置】证书和授权文件目录: ${Provision_Dir}"
}



## 拷贝项目到打包目录
function copyProjectFile() {

    if [ -d "$project_build_path" ]; then
        logit "【工程文件】删除之前工程文件 ${project_build_path}"
        rm -rf "$project_build_path"
        if [ $? -eq 0 ];then
            logit "【工程文件】删除成功 "
        else
            errorExit "原有工程删除失败！"
        fi
    fi
    logit "【工程文件】拷贝项目文件中,请稍等... "
    cp -rf ${project_source_path} $project_build_path
    if [ $? -eq 0 ];then
        logit "【工程文件】拷贝成功"
    else
        errorExit "工程文件拷贝失败"
    fi
}

## 用Blade生成并替换AppIcon
function createAppIcon() {

    ResourceIconFilePath="$Tmp_resource_path/icon.png"
    if [ ! -f "${ResourceIconFilePath}" ]; then
        errorExit "【生成AppIcon】${ResourceIconFilePath}不存在"
    fi 
    project_icon_path="${project_build_path}/${project_name}/Assets.xcassets/AppIcon.appiconset"
    if [ ! -d $project_icon_path ];then
        errorExit "【生成AppIcon】${project_icon_path}不存在"
    fi

    logit "【生成AppIcon】生成AppIcon中..."
    blade --verbose -s "${ResourceIconFilePath}" -t "${project_icon_path}/Contents.json" -o "${project_icon_path}" -c
    if [ $? -eq 0 ];then
        logit "【生成AppIcon】生成成功"
    else
        errorExit "生成AppIcon失败"
    fi

}

## 替换项目启动图
function replaceLaunchImage() {

    # 由于无法使用LaunchScreen来适配单张启动图（无法清除iPhone缓存），因此使用了LaunchImage来设置启动图
    LaunchImagePath="$Tmp_resource_path/LaunchImage"

    # 遍历查看对应尺寸Image
    LaunchImageIsBool="true"
    for i in "${!LaunchImageArray[@]}"; do
        if [ ! -f "${LaunchImagePath}${LaunchImageArray[$i]}.png" ]; then

            logit "【LaunchImage】缺少${LaunchImageArray[$i]}分辨率LaunchImage"
            LaunchImageIsBool="false"
        fi
    done

    if [ "$LaunchImageIsBool" = "false" ];then
        errorExit "LaunchImage图片不全，请补全对应尺寸资源文件。"   
    fi
    for i in "${!LaunchImageArray[@]}"; do
        # 替换LunchImage   cp -rf "${APP_LaunchImage_PATH}" "${BUILD_PROJECT}/${PROJECT_FILE_NAME}/Assets.xcassets/LaunchImage.imageset/LaunchImage.png"
        cp -rf "${LaunchImagePath}${LaunchImageArray[$i]}.png" "${project_build_path}/${project_name}/Assets.xcassets/LaunchImage.launchimage/LaunchImage${LaunchImageArray[$i]}.png"
        if [ $? -eq 0 ];then
            logit "【LaunchImage】拷贝${LaunchImageArray[$i]}.png 成功"
        else
            errorExit "拷贝${LaunchImageArray[$i]}.png 失败" 
        fi
    done
}



## 更改项目infoPist
function changeProjectInfoPlist() {
    #**************************Resource/Config.plist ***************************
    APP_BundleId=`printResource_Config "BundleIdentifier"`
    APP_Name=`printResource_Config "AppName"`
    APP_Version=`printResource_Config "Version"`
    APP_Build=`printResource_Config "Build"`

     #工程原BundleId
    # ProjectBundleId=`printProject_Info "CFBundleIdentifier"`
    ProjectBundleId="com.xiaohe.ixiaostar"
    logit "【项目配置】APP名称: $APP_Name"
    logit "【项目配置】原BundleId: ${ProjectBundleId}"
    logit "【项目配置】新BundleId: $APP_BundleId"
    logit "【项目配置】版本号: $APP_Version"
    logit "【项目配置】构建版本号: $APP_Build"

    #========================= 更改info.plist文件 =========================
    # setProject_Info "CFBundleIdentifier" "$APP_BundleId"
    setProject_Info "CFBundleDisplayName" "$APP_Name"
    setProject_Info "CFBundleShortVersionString" "$APP_Version"
    setProject_Info "CFBundleVersion" "$APP_Build"
    

    # project.pbxproj文件路径
    local pbxprojPath="${project_build_path}/${project_name}.xcodeproj/project.pbxproj"
    if [ ! -f "${pbxprojPath}" ]; then
        errorExit  "project.pbxproj文件不存在${pbxprojPath}"
    fi
    sed -i '' s/$ProjectBundleId/$APP_BundleId/g $pbxprojPath
    if [ $? -eq 0 ];then
        logit "【配置信息】修改project.pbxproj文件BundleId成功"
    else
        errorExit "修改project.pbxproj文件BundleId失败"
    fi
    
    

    #在Info中需要更改URLScheme (支付宝、微信URLScheme的设置)
    wechat_URLScheme=`printResource_Config "weChat_AppID"`

    UrlSchemeNameArray=("alipay" "wechat")
    # 下标对应UrlSchemeNameArray中
    UrlSchemesArray=($APP_BundleId $wechat_URLScheme) 
    # 遍历（带数组下标）
    for i in "${!UrlSchemeNameArray[@]}"; do
        #读取CFBundleURLTypes数组下第i个CFBundleURLName的值
        BundleUrlName=`printProject_Info "CFBundleURLTypes:$i:CFBundleURLName"`
        if [ $(contains "${UrlSchemeNameArray[@]}" ${BundleUrlName}) == "y" ]; then
            setProject_Info "CFBundleURLTypes:'${i}':CFBundleURLSchemes:0" "${UrlSchemesArray[$i]}"
            logit "【URLScheme配置】$BundleUrlName: ${UrlSchemesArray[$i]}"
        else
            logit "【URLScheme配置】${UrlSchemeNameArray[$i]}不存在!"
        fi
    done

}

## 更改项目配置文件
function changeProjectProfile() {
    
    logit "【项目配置】更改项目中Config.plist文件..."
    
    # 脚本资源里Config.plist文件路径
    resource_config_plist="${Tmp_resource_path}/Config.plist"
    # 项目里Config.plist文件路径
    project_config_plist="${project_build_path}/${project_name}/Configs/Config.plist"
    
    if [ ! -f "${resource_config_plist}" ]; then
        errorExit "Resource中缺少Config.plist 文件"
    fi
    
    local ConfigPlistKeyArray=("project_id" "merchant_id" "system_color" "baidu_MapKey" "uMeng_AppKey" "bugly_AppId" "bugly_AppKey" "jPush_AppKey" "home_page_num" "mine_page_num" "is_allied_school" "login_type" "is_always_show_guidepage" "guide_count" "weChat_AppID" "weChat_AppSecret" "is_ixiao_star" "is_has_agreement") 

    for i in "${!ConfigPlistKeyArray[@]}"; do
        local dictKey=${ConfigPlistKeyArray[$i]}
        local dictValue=`printResource_Config "$dictKey"`
        # 替换对应值
        setProject_Config "$dictKey" "$dictValue"
        if [ $? -eq 0 ];then
            logit "【项目配置】$dictKey: $dictValue"
        else
            warning "替换Config.plist文件$dictKey失败"
        fi
    done


}


## 服务器调用脚本接口
## 根据项目需求从json文件获取资源配置信息
function configResourceFile() {

    # 所需的json配置文件路径
    local json_file_path=$1
   
    # 测试
    # json_file_path="${Shell_File_Path}/test.json"

    resource_json_file="$Tmp_resource_path/config.json"
    logit "【资源配置】json文件: $json_file_path" 
    # 复制打包参数json文件到打包脚本目录
    cp -rp $json_file_path $resource_json_file
    # 打印json
    jq . $resource_json_file
    
    # 解析json 打包参数
    #************************** 工程配置信息 ***************************
 
    APP_Name=`cat $resource_json_file | jq -r '.app_name'`
    APP_BundleId=`cat $resource_json_file | jq -r '.APPLICATION_ID'`
    APP_Version=`cat $resource_json_file | jq -r '.VERSION_NAME'`
    APP_Build=`cat $resource_json_file | jq -r '.VERSION_CODE'`

    #************************** 业务配置信息 ***************************

    CONFIG_project_id=`cat $resource_json_file | jq -r '.PROJECTID'`
    CONFIG_merchant_id=`cat $resource_json_file | jq -r '.MERCHANT_ID'`
    CONFIG_system_color=`cat $resource_json_file | jq -r '.color_theme'`
    CONFIG_baidu_MapKey=`cat $resource_json_file | jq -r '.baidu_MapKey'`
    CONFIG_uMeng_AppKey=`cat $resource_json_file | jq -r '.UMENGKEY'`
    CONFIG_bugly_AppId=`cat $resource_json_file | jq -r '.BUGLY_APPID'`
    CONFIG_bugly_AppKey=`cat $resource_json_file | jq -r '.'BUGLY_APPKEY`
    CONFIG_jPush_AppKey=`cat $resource_json_file | jq -r '.JPUSHKEY'`
    CONFIG_home_page_num=`cat $resource_json_file | jq -r '.home_page_num'`
    CONFIG_mine_page_num=`cat $resource_json_file | jq -r '.mine_page_num'`
    CONFIG_is_allied_school=`cat $resource_json_file | jq -r '.IsAlliedSchool'`
    CONFIG_login_type=`cat $resource_json_file | jq -r '.LOGINFIRST'`
    CONFIG_is_always_show_guidepage=`cat $resource_json_file | jq -r '.GuideModel'`
    CONFIG_guide_count=`cat $resource_json_file | jq -r '.GuideCount'`
    CONFIG_weChat_AppID=`cat $resource_json_file | jq -r '.weChat_AppID'`
    CONFIG_weChat_AppSecret=`cat $resource_json_file | jq -r '.weChat_AppSecret'`
    CONFIG_is_ixiao_star=""
    CONFIG_is_has_agreement=""

    
    #************************** 图片文件资源 ***************************
    
    Domain_Url=`cat $resource_json_file | jq -r '.Platform'`
    icon=`cat $resource_json_file | jq -r '.icon'`
    LaunchImage=`cat $resource_json_file | jq -r '.start_img'`
    ## 下载图片
    downloadResourceFile "$Domain_Url" "$icon" "$LaunchImage" "$CONFIG_guide_count"
    ## 格式转换
    convertImgToPNG "$Tmp_resource_path"
    # 生成不同分辨率启动图
    createLaunchImages "$Tmp_resource_path/LaunchImage.png"

    # 描述文件路径
    MobileProvision=`cat $resource_json_file | jq -r '.mobileprovision'`
    # 下载
    you-get -o $Tmp_resource_path -O ProvisionFile.mobileprovision "$Domain_Url$MobileProvision" >> "$Tmp_Log_File"

    # p12证书文件路径
    CertFile=`cat $resource_json_file | jq -r '.cert_file'`
    # 下载
    you-get -o $Tmp_resource_path -O tmp_p12_file.p12 "$Domain_Url$CertFile" >> "$Tmp_Log_File"
    ## 脚本下载证书文件路径
    Tmp_P12_File="$Tmp_resource_path/tmp_p12_file.p12"
    installiCertFile "$Tmp_P12_File"

    # 脚本资源里Config.plist文件路径
    resource_config_plist="${Tmp_resource_path}/Config.plist"
    # 重命名
    mv "${Tmp_resource_path}/config_tpl.plist" $resource_config_plist

    #修改配置文件config.plist
    logit "【资源配置】配置资源Config.plist文件中..."

    if [ ! -f "${resource_config_plist}" ]; then
        errorExit "Resource中缺少Config.plist 文件"
    fi
    # config.plist key 数组
    local ConfigPlistKeyArray=("AppName" "BundleIdentifier" "Version" "Build" "project_id" "merchant_id" "system_color" "baidu_MapKey" "uMeng_AppKey" "bugly_AppId" "bugly_AppKey" "jPush_AppKey" "home_page_num" "mine_page_num" "is_allied_school" "login_type" "is_always_show_guidepage" "guide_count" "weChat_AppID" "weChat_AppSecret" "is_ixiao_star" "is_has_agreement") 
    # key对应->value数组
    local ConfigPlistValueArray=($APP_Name $APP_BundleId $APP_Version $APP_Build $CONFIG_project_id $CONFIG_merchant_id $CONFIG_system_color $CONFIG_baidu_MapKey $CONFIG_uMeng_AppKey $CONFIG_bugly_AppId $CONFIG_bugly_AppKey $CONFIG_jPush_AppKey $CONFIG_home_page_num $CONFIG_mine_page_num $CONFIG_is_allied_school $CONFIG_login_type $CONFIG_is_always_show_guidepage $CONFIG_guide_count $CONFIG_weChat_AppID $CONFIG_weChat_AppSecret $CONFIG_is_ixiao_star $CONFIG_is_has_agreement)
    for i in "${!ConfigPlistKeyArray[@]}"; do
        dictKey=${ConfigPlistKeyArray[$i]}
        dictValue=${ConfigPlistValueArray[$i]}
        # 替换对应值
        setResource_Config "$dictKey" "$dictValue"
    done
}

## 生成不同分辨率启动图
function createLaunchImages() {
    local imgPath=$1
    # iPhone 3.5" @2x
    sips -Z 960 -c 960 640 "$imgPath" --out "$Tmp_resource_path/LaunchImage640x960.png"
    # iPhone 4.0" @2x
    sips -Z 1136 -c 1136 640 "$imgPath" --out "$Tmp_resource_path/LaunchImage640x1136.png"
    # iPhone 5.5" @3x - landscape
    sips -Z 2208 -c 2208 1242 "$imgPath" --out "$Tmp_resource_path/LaunchImage1242x2208.png"
    # iPhone 5.5" @3x - portrait
    # sips -r 90 "$Tmp_resource_path/LaunchImage1242x2208.png" --out $Tmp_resource_path/LaunchImage2208x1242.png
    # iPhone 4.7" @2x
    sips -Z 1334 -c 1334 750 "$imgPath" --out "$Tmp_resource_path/LaunchImage750x1334.png"
    # iPhone X @3x - landscape
    sips -Z 2436 -c 2436 1125 "$imgPath" --out "$Tmp_resource_path/LaunchImage1125x2436.png"
}

## 下载图片
function downloadResourceFile() {

    local domain=$1
    local icon=$2
    local launchImage=$3
    local guideCount=$4
    # icon
    logit "【启动图下载】$domain$icon"
    you-get -o $Tmp_resource_path -O icon "$domain$icon" >> "$Tmp_Log_File"

    # 启动图
    logit "【启动图下载】$domain$launchImage"
    you-get -o $Tmp_resource_path -O LaunchImage "$domain$launchImage" >> "$Tmp_Log_File"

    # 引导图
    for (( i = 1; i <= "${guideCount}"; i++ )); do
        local jsonName="guide_img_$i"
        local image_url=`cat $resource_json_file | jq -r ."$jsonName"` 
        local filePaht="$Domain_Url/$image_url"
        logit "【引导图下载】$filePaht"
        you-get -o $Tmp_resource_path -O $jsonName "$filePaht" >> "$Tmp_Log_File"
    done

}
## 转换图片格式，确保为png格式
function convertImgToPNG() {

    local path=$1
    cd $path
    files=`find . -name "*.png"`

    for i in ${files[@]}; do
        SOURCE_FILE=${i}
        DESTINATION_FILE=$SOURCE_FILE
        sips --matchTo '/System/Library/ColorSync/Profiles/sRGB Profile.icc' "$SOURCE_FILE" --out "$DESTINATION_FILE"
    done
}







