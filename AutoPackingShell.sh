#!/bin/bash

# ----------------------------------------------------------------------
# name:         AutoPackingShell.sh
# version:      1.0.6(106)
# createTime:   2018-08-30
# description:  iOS 自动打包，可配置: Icon,LaunchImage,Info.plist,Config.plist
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
# 引用打包公用文件（ipa_public_function.sh）
source "$Shell_File_Path/ipa_public_function.sh"


###########################################核心逻辑#####################################################

## 打包开始时间
startTimeSeconds=`date +%s`

while [ "$1" != "" ]; do
    case $1 in
        -b | --bundle-id )
            shift
            newBundleId=("$1")
            ;;
        -c | --channel )
            shift
            CHANNEL="$1"
            ;;
        -v | --version )
			getShellVersion
			exit;
			;;

         -x )
			set -x;;
        --show-profile-detail )
			shift
			getProvisionfileInfo "$1"
			exit;
			;;
		--pgyer-upload )
			shift
			pgyerUpload "$1"
			exit;
			;;
		--config-resource )
            # 所需的json配置文件路径
            json_file_path=$2
            # 服务器动态时间标记（用来隔离打包）
            CurrentDateStr=$3
            ## 线上打包输出目录
            Package_Mode="Online"
			
			shift 2
			;;
        -h | --help )
            usage
            ;;
        * )
            usage
            ;;
    esac

    shift
done

###########################################打包前项目配置处理#####################################################

## 初始化用户配置 
initUserConfigFile

##初始化打包输出路径
initPackageDir "$CurrentDateStr" "$Package_Mode"

##检查所需工具支持
checkToolSupport

##检查openssl
checkOpenssl

## 线上服务器打包处理
if [ $Package_Mode == "Online" ]; then
    ## 从json文件获取资源配置信息
    configResourceFile "$json_file_path" 
fi

## 拷贝项目(打包工程)
copyProjectFile

## 生成并替换AppIcon
createAppIcon

## 替换launchImage
replaceLaunchImage

## 更改项目info.plist文件
changeProjectInfoPlist

## 更改项目配置文件
changeProjectProfile

###########################################IPA构建#####################################################

## 备份历史数据
# historyBackup

## podfile检查，并安装
checkPodfileAndInstall

## 获取Xcode版本
getXcodeVersion

## 查找xcworkspace工程启动文件,获取xcproj 工程列表
findXcworkspace

## 获取可构建Target
getTargetsFromXcprojList "${xcprojList[*]}"
## 获取要构建Target
getBuildTarget "${targetsInfoList[*]}"

##获取当前构建的配置模式ID
getConfigurationId "$xcodeprojPath" "$targetId"

## 获取Bundle Id
getProjectBundleId "$xcodeprojPath" "$configurationId"
## 获取infoPlist文件路径
getInfoPlistFile "$xcodeprojPath" "$configurationId"

## 设置手动签名
setManualCodeSigningStyle "$xcodeprojPath" "$targetId"

## 匹配授权文件
matchProvisionFile "$CHANNEL" "$projectBundleId" "$Provision_Dir"

## 解锁钥匙串
unlockKeychain

## 证书安装
createCertWithProvision "$provisionFile"

## 展示授权文件信息
getProvisionfileInfo "$provisionFile"

## 生成exportOptionsPlist文件
generateOptionsPlist "$provisionFile"

## 验证系统中是否有此签名ID证书
checkCodeSignIdentityValid "$codeSignIdentity"

## 初始化build.xcconfig配置文件
initBuildXcconfig

## 进行构建配置信息覆盖，关闭BitCode、签名手动、配置签名等
setBuildXcconfigFile "CODE_SIGN_STYLE" "$CODE_SIGN_STYLE"
setBuildXcconfigFile "PROVISIONING_PROFILE_SPECIFIER" "$provisionFileName" 
setBuildXcconfigFile "PROVISIONING_PROFILE" "$provisionFileUUID"
setBuildXcconfigFile "DEVELOPMENT_TEAM" "$provisionFileTeamID"
setBuildXcconfigFile "CODE_SIGN_IDENTITY" "$codeSignIdentity"
setBuildXcconfigFile "PRODUCT_BUNDLE_IDENTIFIER" "$projectBundleId"


## 开始归档
archiveBuild "$targetName" "$Tmp_Build_Xcconfig_File" "$xcworkspace" 

##结束时间
endTimeSeconds=`date +%s`
logit "【构建结束】构建时长：$((${endTimeSeconds}-${startTimeSeconds})) 秒"

## 开始导出IPA
exportIPA  "$targetName"

## 检查IPA
checkIPA "$exportPath"

##清理临时文件
clearCache

## IPA重命名并上传蒲公英
if [ $Package_Mode == "Offline" ]; then  
    ## IPA和日志重命名
    renameIPAAndLogFile "$targetName" "$infoPlistFile" "$channelName"
    ## 上传蒲公英
    if [ $CHANNEL == "development"]; then
        pgyerUpload "$ipaFilePath" "$pgyer_userKey" "$pgyer_apiKey"
    fi
fi

##结束时间
endTimeSeconds=`date +%s`
logit "【打包结束】打包总时长：$((${endTimeSeconds}-${startTimeSeconds})) 秒"





