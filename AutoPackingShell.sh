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

##############################################默认配置###############################################

CODE_SIGN_STYLE='Manual'
##指定构建的target,默认工程的第一个target
BUILD_TARGET="" 

pgyer_userKey="b805f985351b48620bd95cc5e4ab579b"
pgyer_apiKey="b9bcf5ef168fdf8ce379ae9ab9bd8dcc"

###########################################核心逻辑#####################################################

jq -h >/dev/null 2>&1
if [[ ! $? -eq 0 ]]; then
    errorExit "【环境配置】请使用brew install jq安装 "  
fi

you-get -h >/dev/null 2>&1
if [[ ! $? -eq 0 ]]; then
    errorExit "【环境配置】请使用brew install you-get安装 "  
fi

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
# copyProjectFile

# ## 生成并替换AppIcon
# createAppIcon

# ## 替换launchImage
# replaceLaunchImage

# ## 更改项目info.plist文件
# changeProjectInfoPlist

# ## 更改项目配置文件
# changeProjectProfile


###########################################IPA构建#####################################################

## 备份历史数据
# historyBackup

# $?表示"最后一次执行命令"的退出状态.
# 0为成功,非0为失败.
# 前一个命令执行成功
if [[ $? -eq 0 ]]; then
	logit "【数据备份】上一次打包文件已备份到：$History_Package_Dir"	
fi


## 获取Xcode版本
getXcodeVersion

## 查找xcworkspace工程启动文件,获取xcproj 工程列表
findXcworkspace


## 获取可构建Target
getTargetsFromXcprojList "${xcprojList[*]}"


##获取构建的targetName和targetId 和构建的xcodeprojPath
targetName=''
targetId=''
xcodeprojPath=''

## 初始化默认设置构建Target
if [[ "$BUILD_TARGET" ]]; then
	for targetInfo in ${targetsInfoList[*]}; do
		tId=$(getTargetInfoValue "$targetInfo" "id")
		tName=$(getTargetInfoValue "$targetInfo" "name")
		path=$(getTargetInfoValue "$targetInfo" "xcproj")
		if [[ "$tName" == "$BUILD_TARGET" ]]; then
			targetName="$tName"
			targetId="$tId"
			xcodeprojPath="$path"
			break;
		fi

	done
else
	## 默认选择第一个target
	targetInfo=${targetsInfoList[0]}
	targetId=$(getTargetInfoValue "$targetInfo" "id")
	targetName=$(getTargetInfoValue "$targetInfo" "name")
	xcodeprojPath=$(getTargetInfoValue "$targetInfo" "xcproj")
fi



logit "【构建信息】构建Target：${targetName}（${targetId}）"

if [[ ! "targetName" ]] || [[ ! "targetId" ]] || [[ ! "xcodeprojPath" ]]; then
	errorExit "获取构建信息失败!"
fi


##获取构建配置模式ID列表 （Release和Debug分别对应不同的ID）
configurationTypeIds=$(getConfigurationIds "$xcodeprojPath" "$targetId")
if [[ ! "$configurationTypeIds" ]]; then
	errorExit "获取配置模式(Release和Debug)Id列表失败"
fi
logit "【构建信息】配置模式ID列表：$configurationTypeIds"

## 获取当前构建的配置模式ID
configurationId=$(getConfigurationIdWithType "$xcodeprojPath" "$targetId" "$CONFIGRATION_TYPE")
if [[ ! "$configurationId" ]]; then
	errorExit "获取${CONFIGRATION_TYPE}配置模式Id失败"
fi
logit "【构建信息】配置模式：$CONFIGRATION_TYPE （${configurationId}）"



## 获取Bundle Id
if [[ $NEW_BUNDLE_IDENTIFIER ]]; then
	## 重新指定Bundle Id
	projectBundleId=$NEW_BUNDLE_IDENTIFIER
else
	## 获取工程中的Bundle Id
	projectBundleId=$(getProjectBundleId "$xcodeprojPath" "$configurationId")
	if [[ ! "$projectBundleId" ]] ; then
		errorExit "获取项目的Bundle Id失败"
	fi
fi
logit "【构建信息】Bundle Id：$projectBundleId"

infoPlistFile=$(getInfoPlistFile "$xcodeprojPath" "$configurationId")
if [[ ! -f "$infoPlistFile" ]]; then
	errorExit "获取infoPlist文件失败"
fi
logit "【构建信息】InfoPlist 文件：$infoPlistFile"


## 设置手动签名
setManulCodeSigningRuby "$xcodeprojPath" "$targetId"

##检查openssl
checkOpenssl

logit "【构建信息】进行授权文件匹配..."
## 匹配授权文件
provisionFile=$(matchMobileProvisionFile "$CHANNEL" "$projectBundleId" "$Provision_Dir")
if [[ ! "$provisionFile" ]]; then
	errorExit "不存在BundleId为:${projectBundleId}，分发渠道为:${CHANNEL}的授权文件，请检查${Provision_Dir}目录是否存在对应授权文件"
fi
logit "【构建信息】匹配授权文件: $provisionFile"

## 导入授权文件
open "$provisionFile"

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



## podfile检查，并安装
podfile=$(checkPodfileExist)
if [[ "$podfile" ]]; then
	logit "【cocoapods】pod install";
	##必须cd到此工程目录
	cd "${project_build_path}"  
	pod install
	cd - 
fi

## 开始归档。
## 这里使用a=$(...)这种形式会导致xocdebuild日志只能在函数archiveBuild执行完毕的时候输出；
## archivePath 在函数archiveBuild 是全局变量
logit "【归档信息】开始归档中...";
archivePath=''
archiveBuild "$targetName" "$Tmp_Build_Xcconfig_File" "$xcworkspace" 
logit "【归档信息】项目构建成功，文件路径：$archivePath"


# 开始导出IPA
exportPath=''
exportIPA  "$archivePath" "$provisionFile"
if [[ ! "$exportPath" ]]; then
	errorExit "IPA导出失败，请检查日志。"
fi
logit "【IPA 导出】IPA导出成功，文件路径：$exportPath"


## 检查IPA
logit "【签名校验】IPA签名校验中..."
checkIPA "$exportPath"

##清理临时文件
clearCache

## IPA和日志重命名
logit "【IPA 信息】IPA和日志文件重命名..."
## 去除最后的文件名称,得到纯路径
exportDir=${exportPath%/*} 
## 重新定义IPA名称
ipaName=$(finalIPAName "$targetName" "$infoPlistFile" "$(getProfileTypeCNName $CHANNEL)")
logit "【IPA 信息】IPA路径:${exportDir}/${ipaName}.ipa"
logit "【IPA 信息】日志路径:${exportDir}/${ipaName}.txt"
# 重命名
mv "$exportPath" 	"${exportDir}/${ipaName}.ipa"
mv "$Tmp_Log_File" 	"${exportDir}/${ipaName}.txt"

##结束时间
endTimeSeconds=`date +%s`
logit "【构建结束】构建时长：$((${endTimeSeconds}-${startTimeSeconds})) 秒"


## 上传蒲公英
if [ $CHANNEL == "development" ]; then
	pgyerUpload "${exportDir}/${ipaName}.ipa" "$pgyer_userKey" "$pgyer_apiKey"
fi



