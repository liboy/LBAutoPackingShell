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

##检查所需工具支持
checkToolSupport

##检查openssl
checkOpenssl

## 打包开始时间
startTimeSeconds=`date +%s`

while [ "$1" != "" ]; do
    case $1 in
        -b | --bundle-id )
            shift
            NEW_BUNDLE_IDENTIFIER=("$1")
            ;;
        -c | --channel )
            shift
            CHANNEL="$1"
            ;;
        -t | --target)
            shift
			BUILD_TARGET="$1"
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
			configResourceFile "$2" "$3"
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

## podfile检查，并安装
checkPodfileAndInstall

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
setXCconfigWithKeyValue "CODE_SIGN_STYLE" "$CODE_SIGN_STYLE"
setXCconfigWithKeyValue "PROVISIONING_PROFILE_SPECIFIER" "$provisionFileName" 
setXCconfigWithKeyValue "PROVISIONING_PROFILE" "$provisionFileUUID"
setXCconfigWithKeyValue "DEVELOPMENT_TEAM" "$provisionFileTeamID"
setXCconfigWithKeyValue "CODE_SIGN_IDENTITY" "$codeSignIdentity"
setXCconfigWithKeyValue "PRODUCT_BUNDLE_IDENTIFIER" "$projectBundleId"


## 开始归档
archiveBuild "$targetName" "$Tmp_Build_Xcconfig_File" "$xcworkspace" 

## 开始导出IPA
exportIPA  "$archivePath" "$provisionFile"

## 检查IPA
checkIPA "$exportPath"

##清理临时文件
clearCache

## IPA和日志重命名
renameIPAAndLogFile "$targetName" "$infoPlistFile" "$channelName"

##结束时间
endTimeSeconds=`date +%s`
logit "【构建结束】构建时长：$((${endTimeSeconds}-${startTimeSeconds})) 秒"

## 上传蒲公英
if [ $CHANNEL == "development" ]; then
	pgyerUpload "$ipaFilePath" "$pgyer_userKey" "$pgyer_apiKey"
fi



