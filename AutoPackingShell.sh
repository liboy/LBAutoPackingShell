#!/bin/bash

# ----------------------------------------------------------------------
# name:         AutoPackingShell.sh
# version:      1.0.0(100)
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
			getProfileInfo "$1"
			exit;
			;;
		--pgyer-upload )
			shift
			pgyerUpload "$1"
			exit;
			;;
		--config-resource )
			shift
			configResourceFile "$1"
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
## 初始化项目配置
initProjectConfig


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

## 构建开始时间
startTimeSeconds=`date +%s`

## 备份历史数据
# historyBackup

# $?表示"最后一次执行命令"的退出状态.
# 0为成功,非0为失败.
# 前一个命令执行成功
if [[ $? -eq 0 ]]; then
	logit "【数据备份】上一次打包文件已备份到：$History_Package_Dir"	
fi


### Xcode版本
xcVersion=$(getXcodeVersion)

if [[ ! "$xcVersion" ]]; then
	errorExit "获取当前XcodeVersion失败"
fi
logit "【构建信息】Xcode版本：$xcVersion"


## 获取xcproj 工程列表
xcprojPathList=()

## 查找xcworkspace工程启动文件
xcworkspace=$(findXcworkspace)
logit "【构建信息】xcworkspace文件：$xcworkspace"
if [[ "$xcworkspace" ]]; then
	
	logit "【构建信息】项目结构：多工程协同(workspace)"
	##  外括号作用是转变为数组
	xcprojPathList=($(getAllXcprojPathFromWorkspace "$xcworkspace"))
	num=${#xcprojPathList[@]} ##数组长度 

	if [[ $num -gt 1 ]]; then
		i=0
		for xcproj in ${xcprojPathList[*]}; do
			i=$(expr $i + 1)
			logit "【构建信息】工程${i}：${xcproj##*/}"
		done
	fi

else
	## 查找xcodeproj 文件
	logit "【构建信息】项目结构：单工程"
	xcodeprojPath=$(findXcodeproj)
	if [[ "$xcodeprojPath" ]]; then
		logit "【构建信息】工程路径:$xcodeprojPath"
	else
		# `basename $0`值显示当前脚本或命令的名字
		# $0显示会包括当前脚本或命令的路径
		errorExit "项目目录"$Shell_Work_Path"不存在.xcworkspace或.xcodeproj工程文件，"
	fi
	xcprojPathList=("$xcodeprojPath")
fi


## 构建的xcprojPath列表,即除去Pods.xcodeproj之外的
buildXcprojPathList=()
for (( i = 0; i < ${#xcprojPathList[*]}; i++ )); do
	path=${xcprojPathList[i]};
	if [[ "${path##*/}" == "Pods.xcodeproj" ]]; then
		continue;
	fi
	## 数组追加元素括号里面第一个参数不能用双引号，否则会多出一个空格
	buildXcprojPathList=(${buildXcprojPathList[*]} "$path")
done
logit "【构建信息】可构建的工程数量（不含Pods）:${#buildXcprojPathList[*]}"


## 获取可构建的工程的所有target
targetsInfoListStr=$(getAllTargetsInfoFromXcprojList "${buildXcprojPathList[*]}")
# 16A99C1E1C744CE000907D37:iXiao:/Users/liboy/Desktop/自动打包/xinyue/iXiao.xcworkspace/../iXiao.xcodeproj;
# 16A99C371C744CE100907D37:iXiaoTests:/Users/liboy/Desktop/自动打包/xinyue/iXiao.xcworkspace/../iXiao.xcodeproj

## 将字符串以分号分割成数组
# 记录当前分隔符号
OLD_IFS="$IFS"
IFS=";"
targetsInfoList=($targetsInfoListStr)
IFS="$OLD_IFS" ##还原

logit "【构建信息】可构建的Target数量（不含Pods）:${#targetsInfoList[*]}"

i=1
for targetInfo in ${targetsInfoList[*]}; do
	tId=$(getTargetInfoValue "$targetInfo" "id")
	tName=$(getTargetInfoValue "$targetInfo" "name")
	logit "【构建信息】可构建Target${i}：${tName}"
	i=$(expr $i + 1 )
done


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
provisionFile=$(matchMobileProvisionFile "$CHANNEL" "$projectBundleId" "$PROVISION_DIR")
if [[ ! "$provisionFile" ]]; then
	errorExit "不存在BundleId为:${projectBundleId}，分发渠道为:${CHANNEL}的授权文件，请检查${PROVISION_DIR}目录是否存在对应授权文件"
fi
##导入授权文件
open "$provisionFile"

logit "【构建信息】匹配授权文件：$provisionFile"

## 展示授权文件信息
getProfileInfo "$provisionFile"

## 解锁钥匙串
unlockKeychain
if [[ $? -eq 0 ]]; then
	logit "【钥匙串】unlock-keychain";
else
	errorExit "unlock-keychain失败, 请使用-p 参数或者在user.xcconfig配置文件中指定密码";
fi

## 获取签名
codeSignIdentity=$(getCodeSignId "$provisionFile")
if [[ ! "$codeSignIdentity" ]]; then
	errorExit "获取授权文件签名失败! 授权文件:${provisionFile}"
fi
logit "【签名信息】匹配签名ID：$codeSignIdentity"

result=$(checkCodeSignIdentityValid "$codeSignIdentity")
if [[ ! "$result" ]]; then
	errorExit "签名ID:${codeSignIdentity}无效，请检查钥匙串是否导入对应的证书或脚本访问keychain权限不足，请使用-p参数指定密码 "
fi


## 进行构建配置信息覆盖，关闭BitCode、签名手动、配置签名等
xcconfigFile=$(initBuildXcconfig)
if [[ "$xcconfigFile" ]]; then
	logit "【签名设置】初始化XCconfig配置文件：$xcconfigFile"
fi


setXCconfigWithKeyValue "CODE_SIGN_STYLE" "$CODE_SIGN_STYLE"
setXCconfigWithKeyValue "PROVISIONING_PROFILE_SPECIFIER" "$(getProvisionfileName "$provisionFile")" 
setXCconfigWithKeyValue "PROVISIONING_PROFILE" "$(getProvisionfileUUID "$provisionFile")"
setXCconfigWithKeyValue "DEVELOPMENT_TEAM" "$(getProvisionfileTeamID "$provisionFile")"
setXCconfigWithKeyValue "CODE_SIGN_IDENTITY" "$codeSignIdentity"
setXCconfigWithKeyValue "PRODUCT_BUNDLE_IDENTIFIER" "$projectBundleId"



## podfile检查，并安装
podfile=$(checkPodfileExist)
if [[ "$podfile" ]]; then
	logit "【cocoapods】pod install";
	##必须cd到此工程目录
	cd "${Shell_Work_Path}"  
	pod install
	cd - 
fi

## 开始归档。
## 这里使用a=$(...)这种形式会导致xocdebuild日志只能在函数archiveBuild执行完毕的时候输出；
## archivePath 在函数archiveBuild 是全局变量
archivePath=''
archiveBuild "$targetName" "$Tmp_Build_Xcconfig_File" 
logit "【归档信息】项目构建成功，文件路径：$archivePath"


# 开始导出IPA
exportPath=''
exportIPA  "$archivePath" "$provisionFile"
if [[ ! "$exportPath" ]]; then
	errorExit "IPA导出失败，请检查日志。"
fi
logit "【IPA 导出】IPA导出成功，文件路径：$exportPath"


# ## 修复8.3 以下版本的xcent文件
# xcentFile=$(repairXcentFile "$exportPath" "$archivePath")
# if [[ "$xcentFile" ]]; then
# 	logit "【xcent 文件修复】拷贝archived-expanded-entitlements.xcent 到${xcentFile}"
# fi

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



