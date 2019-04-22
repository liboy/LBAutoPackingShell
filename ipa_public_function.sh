#!/bin/bash


# ----------------------------------------------------------------------
# name:         ipa_public_function.sh
# version:      1.0.6(106)
# createTime:   2018-08-30
# description:  ipa打包函数文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/LBAutoPackingShell
# ----------------------------------------------------------------------

function usage {
	# setAliasShortCut
	echo ""
	# `basename $0`值显示当前脚本或命令的名字
	# $0显示会包括当前脚本或命令的路径
	echo "Usage:$(basename $0) -[abcdptvhx] [--show-profile-detail] [--pgyer-upload] ..."
	echo "可选项："
	echo "  -a | --archs <armv7|arm64|armv7 arm64> 指定构建架构集，例如：-a 'armv7'或者 -a 'arm64' 或者 -a 'armv7 arm64' 等"
  	echo "  -b | --bundle-id <bundleId> 设置Bundle Id"
  	echo "  -c | --channel <development|app-store|enterprise|ad-hoc>"
	echo "  -p | --keychain-password <passoword> 指定访问证书时解锁钥匙串的密码，即开机密码"
	echo "  -v | --version 输出当前脚本版本号"
	echo "  -h | --help 帮助."
	echo "  -x 脚本执行调试模式."

	
	echo "  --show-profile-detail <provisionfile> 查看授权文件的信息详情(development、enterprise、app-store、ad-hoc)"
	echo "  --pgyer-upload <ipafilepath>  指定IPA文件上传蒲公英"
	echo "  --config-resource <jsonfilepath> <datestr> 服务器调用脚本接口，指定json文件和时间字符串(例:20181023140504）配置脚本资源配置信息后打包项目"
	
	exit 0
}

## 检查所需工具是否安装
function checkToolSupport() {

	jqPath=$(which jq)
	logit "【环境配置】jqPath:$jqPath"
	if [[ ! "$jqPath" ]]; then
	    errorExit "【环境配置】请使用brew install jq安装 "  
	fi
	logit "【环境配置】jq安装:$jqPath"

	yougetPath=$(which you-get)
	# you-get -h >/dev/null 2>&1
	if [[ ! "$yougetPath" ]]; then
	    errorExit "【环境配置】请使用brew install you-get安装 "  
	fi
	logit "【环境配置】you-get安装:$yougetPath"

	blade=$(which blade)
	if [[ ! "$blade" ]]; then
	    errorExit "【环境配置】请使用brew install blade安装 "  
	fi
	logit "【环境配置】blade安装:$blade"
	
}

## 检查openssl
function checkOpenssl() {
	local opensslInfo=$(openssl version)
	local opensslName=$(echo $opensslInfo | cut -d " " -f1)
	local opensslVersion=$(echo $opensslInfo | cut -d " " -f2)
	if [[ "$opensslName" == "LibreSSL" ]] || ! versionCompareGE "${opensslVersion%\.*}" "1.0"; then
		errorExit "${opensslInfo} 版本过旧，请更新 OpenSSL 版本"
	fi
	logit "【环境配置】OpenSSL 版本:$opensslVersion"
}

#############################################基本配置#############################################

## 初始化build.xcconfig配置文件
function initBuildXcconfig() {
	local xcconfigFile=$Tmp_Build_Xcconfig_File
	if [[ -f "$xcconfigFile" ]]; then
		## 清空
		> "$xcconfigFile"
	else 
		## 生成文件
		touch "$xcconfigFile"
	fi
	if [[ "$xcconfigFile" ]]; then
		logit "【签名设置】初始化build.xcconfig配置文件：$xcconfigFile"
	fi
}

## 备份历史数据
function historyBackup() {

	## 备份上一次的打包数据
	if [[ -d "$Package_Dir" ]] && [[ -d "$History_Package_Dir" ]]; then
		for name in "${Package_Dir}"/* ; do
			if [[ "$name" == "$History_Package_Dir" ]] && [[ -d "$name" ]]; then
				continue;
			fi

			cp -rf "$name" "$History_Package_Dir"
			rm -rf "$name"
		done
	else
		mkdir -p "$History_Package_Dir"
	fi

	# $?表示"最后一次执行命令"的退出状态.
	# 0为成功,非0为失败.
	# 前一个命令执行成功
	if [[ $? -eq 0 ]]; then
		logit "【数据备份】上一次打包文件已备份到：$History_Package_Dir"	
	fi
}


## 获取Xcode版本
function getXcodeVersion() {
	xcodeVersion=`$CMD_Xcodebuild -version | head -1 | cut -d " " -f 2`
	if [[ ! "$xcodeVersion" ]]; then
		errorExit "获取当前XcodeVersion失败"
	fi
	logit "【构建信息】Xcode版本：$xcodeVersion"
}


## 查找xcworkspace工程启动文件,获取xcodeproj工程列表
function findXcworkspace() {

	xcworkspace=$(find "$project_build_path" -maxdepth 1  -type d -iname "*.xcworkspace")
	xcworkspacedataFile="$xcworkspace/contents.xcworkspacedata"
	if [[ -d "$xcworkspace" ]] || [[ -f "${xcworkspace}/contents.xcworkspacedata" ]]; then
		logit "【构建信息】项目结构：多工程协同(workspace)"
		logit "【构建信息】xcworkspace文件：$xcworkspace"
		## 外括号作用是转变为数组
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
		## 查找xcodeproj工程启动文件
		logit "【构建信息】项目结构：单工程"
		xcodeprojPath=$(find "$project_build_path" -maxdepth 1  -type d -iname "*.xcodeproj")
		if [[ -d "$xcodeprojPath" ]] || [[ -f "${xcodeprojPath}/project.pbxproj" ]]; then
			logit "【构建信息】工程路径:$xcodeprojPath"
		else
			errorExit "项目目录$project_build_path不存在.xcworkspace或.xcodeproj工程文件"
		fi
		xcprojPathList=("$xcodeprojPath")

	fi

	## 构建的xcprojPath列表,即除去Pods.xcodeproj之外的
	xcprojList=()
	for (( i = 0; i < ${#xcprojPathList[*]}; i++ )); do
		path=${xcprojPathList[i]};
		if [[ "${path##*/}" == "Pods.xcodeproj" ]]; then
			continue;
		fi
		## 数组追加元素括号里面第一个参数不能用双引号，否则会多出一个空格
		xcprojList=(${xcprojList[*]} "$path")
	done
	logit "【构建信息】可构建的工程数量（不含Pods）:${#xcprojList[*]}"

}

## 获取workspace的项目路径列表xcodeproj
function getAllXcprojPathFromWorkspace() {
	
	local list=($(grep "location =" "$xcworkspacedataFile" | cut -d "\"" -f2 | cut -d ":" -f2))
	## 补充完整路径
	local completePathList=()
	for xcproj in ${list[*]}; do
		local path="${xcworkspace}/../${xcproj}"
		## 数组追加元素括号里面第一个参数不能用双引号，否则会多出一个空格
		completePathList=(${completePathList[*]} "$path")
	done
	echo "${completePathList[*]}"
}


## 获取xcproj的所有可构建target
## 比分数组元素本身带有空格，所以采用字符串用“;”作为分隔符，而不是用数组。
function getTargetsFromXcprojList() {
	local xcprojList=$1
	# 元素格式为 targetId:targetName:xcprojPath
	local targetsInfoListStr='' ##
	## 获取每个子工程的target
	for (( i = 0; i < ${#xcprojList[*]}; i++ )); do
		local xcprojPath=${xcprojList[i]};
		local pbxprojPath="${xcprojPath}/project.pbxproj"
		if [[ -f "$pbxprojPath" ]]; then
			# echo "$pbxprojPath"
			local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxprojPath")
			local targetIdList=$($CMD_PlistBuddy -c "Print :objects:${rootObject}:targets" "$pbxprojPath" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
			#括号用于初始化数组,例如arr=(1,2,3),括号用于初始化数组,例如arr=(1,2,3)
			local targetIds=($(echo $targetIdList));
			for targetId in ${targetIds[*]}; do
				local targetName=$($CMD_PlistBuddy -c "Print :objects:$targetId:name" "$pbxprojPath")
				local info="${targetId}:${targetName}:${xcprojPath}"
				if [[ "$targetsInfoListStr" == '' ]]; then
					targetsInfoListStr="$info";
				else
					targetsInfoListStr="${targetsInfoListStr};${info}";

				fi
			done
		fi
	done

	## 将字符串以分号分割成数组
	# 记录当前分隔符号
	OLD_IFS="$IFS"
	IFS=";"
	targetsInfoList=($targetsInfoListStr)
	IFS="$OLD_IFS" ##还原

	logit "【构建信息】可构建的Target数量（不含Pods）:${#targetsInfoList[*]}"
	for i in "${!targetsInfoList[@]}"; do
		local targetInfo=${targetsInfoList[$i]} 
		local tId=$(getTargetInfoValue "$targetInfo" "id")
		local tName=$(getTargetInfoValue "$targetInfo" "name")
		logit "【构建信息】可构建Target${i}：${tName}"
	done

}

## 获取构建的targetName和targetId 和xcodeprojPath
function getBuildTarget() {
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
}

## 例如分割
# 16A99C1E1C744CE000907D37:iXiao:/iXiao.xcworkspace/../iXiao.xcodeproj;
# 16A99C371C744CE100907D37:iXiaoTests:/iXiao.xcworkspace/../iXiao.xcodeproj
function getTargetInfoValue(){

	local targetInfo="$1"
	local key="$2"
	if [[ "$targetInfo" == "" ]] || [[ "$key" == "" ]]; then
		errorExit "getTargetInfoValue 参数不能为空"
	fi

	## 更换数组分隔符
	OLD_IFS="$IFS"
	IFS=":"
	local arr=($targetInfo)
	IFS="$OLD_IFS"
	if [[ ${#arr[@]} -lt 3 ]]; then
		errorExit "getTargetInfoValue 函数出错"
	fi
	local value=''
	if [[ "$key"  == "id" ]]; then
		value=${arr[0]}
	elif [[ "$key" == "name" ]]; then
		value=${arr[1]}
	elif [[ "$key" == "xcproj" ]]; then
		value=${arr[2]}
	fi
	echo "$value"
}

## 获取配置ID
function getConfigurationId() {
	##配置模式：Debug 或 Release
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
  	local buildConfigurationListId=$($CMD_PlistBuddy -c "Print :objects:$targetId:buildConfigurationList" "$pbxproj")
  	local buildConfigurationList=$($CMD_PlistBuddy -c "Print :objects:$buildConfigurationListId:buildConfigurations" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
  	##数组中存放的分别是release和debug对应的id
  	configurationTypeIds=$(echo $buildConfigurationList)

  	if [[ ! "$configurationTypeIds" ]]; then
		errorExit "获取配置模式Id列表失败"
	fi
	logit "【构建信息】配置模式ID列表：$configurationTypeIds"


	for id in ${configurationTypeIds[@]}; do
		local name=$($CMD_PlistBuddy -c "Print :objects:$id:name" "$pbxproj")
		if [[ "$CONFIGRATION_TYPE" == "$name" ]]; then
			configurationId=$id
			break;
		fi
	done
	if [[ ! "$configurationId" ]]; then
		errorExit "获取${CONFIGRATION_TYPE}配置模式Id失败"
	fi
	logit "【构建信息】配置模式：$CONFIGRATION_TYPE （${configurationId}）"
  	
}

## 根据配置模式ID，获取项目bundleId,分为Releae和Debug
function getProjectBundleId() {	
	# 配置模式ID
	local configurationId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
	if [[ $newBundleId ]]; then
		## 重新指定Bundle Id
		projectBundleId=$newBundleId
	else
		## 获取工程中的Bundle Id
		projectBundleId=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings:PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
		if [[ ! "$projectBundleId" ]] ; then
			errorExit "获取项目的Bundle Id失败"
		fi
	fi
	logit "【构建信息】Bundle Id：$projectBundleId"

}

## 获取infoPlist文件
function getInfoPlistFile()
{
	configurationId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
 	local  infoPlistFileName=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings:INFOPLIST_FILE" "$pbxproj" )
 	## 替换$(SRCROOT)为.
 	infoPlistFileName=${infoPlistFileName//\$(SRCROOT)/.}
	### 完整路径
	infoPlistFile="$1/../$infoPlistFileName"
	if [[ ! -f "$infoPlistFile" ]]; then
		errorExit "获取infoPlist文件失败"
	fi
	logit "【构建信息】InfoPlist 文件：$infoPlistFile"
	
}

## 获取git仓库版本数量
function getGitRepositoryVersionNumbers (){
	## 是否存在.git目录
	local gitRepository=$(find "$project_build_path" -maxdepth 1  -type d -iname ".git")
	if [[ ! -d "$gitRepository" ]]; then
		exit 1
	fi

	local gitRepositoryVersionNumbers=$(git -C "$project_build_path" rev-list HEAD 2>/dev/null | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*")
	if [[ $? -ne 0 ]]; then
		## 可能是git只有在本地，而没有提交到服务器,或者没有网络
		exit 1
	fi
	echo $gitRepositoryVersionNumbers
}


#############################################签名设置#############################################
## 设置手动签名
## 设置手动签名,即不勾选：Xcode -> General -> Signing -> Automatically manage signning
## 在xcode 9之前（不包含9），只有在General这里配置是否手动签名，在xcode9之后，多加了一项在setting中
function setManualCodeSigningStyle ()
{
	local project=$1
	local pbxproj=$1/project.pbxproj
	local targetId=$2
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
	local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxproj")
	#没有勾选过Automatically manage signning时，则不存在ProvisioningStyle
	#获取签名方式
	codeSigningStyle=$($CMD_PlistBuddy -c "Print :objects:$rootObject:attributes:TargetAttributes:$targetId:ProvisioningStyle " "$pbxproj" 2>/dev/null)
	logit "【签名信息】项目签名方式为:$codeSigningStyle"
	if [[ ! "$codeSigningStyle" ]] || [[ "$codeSigningStyle" != "Manual" ]]; then
		logit "【签名信息】设置签名方式为:Manual"
		ruby "$Shell_File_Path/set_codesign_style.rb" "$project" "$targetId" 2>/dev/null
	fi

}

# ##设置签名方式（手动/自动）,注意：如果项目存在中文文件名，使用PlistBuddy 命令对pbxproj文件进行修改导致乱码！该方法已被抛弃!
# function setManulCodeSigning ()
# {
# 	local pbxproj=$1/project.pbxproj
# 	local targetId=$2
# 	local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxproj")
# 	##如果需要设置成自动签名,将Manual改成Automatic
# 	$CMD_PlistBuddy -c "Set :objects:$rootObject:attributes:TargetAttributes:$targetId:ProvisioningStyle Manual" "$pbxproj"

# }


#############################################授权文件#############################################

## 从授权文件获取BundleId
function getProfileBundleId()
{
	local profile=$1
	local applicationIdentifier=$($CMD_PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null)" )
	if [[ $? -ne 0 ]]; then
		exit 1;
	fi
	##截取bundle id,这种截取方法，有一点不太好的就是：当applicationIdentifier的值包含：*时候，会截取失败,如：applicationIdentifier=6789.*
	local bundleId=${applicationIdentifier#*.}
	echo $bundleId
}

## 获取授权文件类型
function getProfileType() {
	local profile=$1
	local profileType=''
	if [[ ! -f "$profile" ]]; then
		exit 1
	fi
	##判断是否存在key:ProvisionedDevices
	local haveKey=$($CMD_Security cms -D -i "$profile" 2>/dev/null | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//' | grep ProvisionedDevices)
	if [[ "$haveKey" ]]; then
		local getTaskAllow=$($CMD_PlistBuddy -c 'Print :Entitlements:get-task-allow' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null)" )
		if [[ $getTaskAllow == true ]]; then
			profileType='development'
		else
			profileType='ad-hoc'
		fi
	else
		local haveKeyProvisionsAllDevices=$($CMD_Security cms -D -i "$profile" 2>/dev/null | grep ProvisionsAllDevices)
		if [[ "$haveKeyProvisionsAllDevices" != '' ]]; then
			provisionsAllDevices=$($CMD_PlistBuddy -c 'Print :ProvisionsAllDevices' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null)" )
			if [[ $provisionsAllDevices == true ]]; then
				profileType='enterprise'
			else
				profileType='app-store'
			fi
		else
			profileType='app-store'
		fi
	fi
	echo $profileType
}

## 获取授权文件过期时间
function getProvisionfileExpireTimestmap() {
	local provisionFile=$1
	##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    ##获取授权文件的过期时间
    local expirationTime=$($CMD_PlistBuddy -c 'Print :ExpirationDate' /dev/stdin <<< "$($CMD_Security cms -D -i "$provisionFile" 2>/dev/null)" )
    local timestamp=`date -j -f "%a %b %d  %T %Z %Y" "$expirationTime" "+%s"`
    # echo $(date -r `expr $timestamp `  "+%Y年%m月%d" )
    echo "$timestamp"
}

## 匹配授权文件
function matchProvisionFile() {	
	## 分发渠道
	local channel=$1
	## BundleId
	local appBundleId=$2
	## 授权文件目录
	local provisionFileDir=$3
	if [[ ! -d "$provisionFileDir" ]]; then
		exit 1
	fi
	
	provisionFile=''
	local maxExpireTimestmap=0
	logit "【构建信息】进行授权文件匹配..."
	for file in "${provisionFileDir}"/*.mobileprovision; do
		local provisionBundleId=$(getProfileBundleId "$file")
		if [[ "$provisionBundleId" ]] && [[ "$appBundleId" == "$provisionBundleId" ]]; then
			local profileType=$(getProfileType "$file")
			if [[ "$profileType" == "$channel" ]]; then
				local timestmap=$(getProvisionfileExpireTimestmap "$file")
				## 匹配到有效天数最大的授权文件
				if [[ $timestmap -gt $maxExpireTimestmap ]]; then
					provisionFile=$file
					maxExpireTimestmap=$timestmap
				fi
			fi
		fi
	done
	if [[ ! "$provisionFile" ]]; then
		errorExit "请检查${Provision_Dir}目录是否存在对应授权文件"
	fi
	logit "【构建信息】匹配到的授权文件: $provisionFile"

	## 导入授权文件
	open "$provisionFile"
}

## 获取授权文件TeamID
function getProvisionfileTeamID()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileTeamID=$($CMD_PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' $Tmp_Provision_Plist_File)
	echo $provisonfileTeamID
}

## 获取授权文件名称
function getProvisionfileName()
{
	local provisionFile=$1
	provisonfileName=$($CMD_PlistBuddy -c 'Print :Name' $Tmp_Provision_Plist_File)
	echo $provisonfileName
}

## 获取profiletype或渠道的文字描述
function getChannelName()
{
    local profileType=$1
    local channelName
    if [[ "$profileType" == 'app-store' ]]; then
        channelName='商店分发'
    elif [[ "$profileType" == 'enterprise' ]]; then
        channelName='企业分发'
	elif [[ "$profileType" == 'ad-hoc' ]]; then
        channelName='内部发布'
    else
        channelName='内部开发'
    fi
    echo $channelName

}

## 获取授权文件UUID
function getProvisionfileUUID()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileUUID=$($CMD_PlistBuddy -c 'Print :UUID' $Tmp_Provision_Plist_File)
	echo $provisonfileUUID
}
## 获取授权文件TeamName
function getProvisionfileTeamName()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileTeamName=$($CMD_PlistBuddy -c 'Print :TeamName' $Tmp_Provision_Plist_File)
	echo $provisonfileTeamName
}

function getProvisionfileCreateTimestmap {
	local provisionFile=$1
	##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    ##获取授权文件的过期时间
    local createTime=$($CMD_PlistBuddy -c 'Print :CreationDate' $Tmp_Provision_Plist_File)
    local timestamp=`date -j -f "%a %b %d  %T %Z %Y" "$createTime" "+%s"`
    # echo $(date -r `expr $timestamp `  "+%Y年%m月%d" )
    echo "$timestamp"
}

##获取授权文件过期天数
function getExpiretionDays() {

	local expireTimestamp=$1
    local nowTimestamp=`date +%s`
    local r=$[expireTimestamp-nowTimestamp]
    local days=$[r/60/60/24]
    echo $days
}

## 证书安装
function installiCertFile() {

	local certFile=$1
	if [[ ! -f "$certFile" ]]; then
		errorExit "指定证书文件不存在!"
	fi
	$CMD_Security import $certFile -k "$HOME/Library/Keychains/login.keychain" -P 1 -A 2>/dev/null
	# $CMD_Security import ${Tmp_Cer_File} -k "$HOME/Library/Keychains/login.keychain" -T /usr/bin/codesign 2>/dev/null
	if [[ $? -eq 0 ]]; then
		logit "【证书安装】证书Cer导入成功";
	fi
}

function createCertWithProvision() {

	local provisionFile=$1
	## 获取DeveloperCertificates 字段
	local data=$($CMD_Security cms -D -i "$provisionFile" | grep data | head -n 1 | sed 's/.*<data>//g' | sed 's/<\/data>.*//g' ) 
	
	## 使用openssl进行解码 1. 构建cer证书 2. 解码证书
	echo "-----BEGIN CERTIFICATE-----" 	> "$Tmp_Cer_File"
	echo "${data}"						>> "$Tmp_Cer_File"
	echo "-----END CERTIFICATE-----"	>> "$Tmp_Cer_File"

}

## 获取授权文件中的签名id
function getCodeSignId() {

	local codeSignIdentity=$(openssl x509 -noout -text -in "$Tmp_Cer_File"  | grep Subject | grep "CN=" | cut -d "," -f2 | cut -d "=" -f2)
	##必须使用"${}"这种形式，否则连续的空格会被转换成一个空格
	## 这里使用-e 来解决中文签名id的问题
	echo -e "${codeSignIdentity}"
}

## 获取授权文件中的证书序列号
function getProvisionCodeSignSerial() {
	## 去掉空格
	local serial=$( openssl x509 -noout -text -in "$Tmp_Cer_File" | grep "Serial Number" | cut -d ':' -f2 | sed 's/^[ ]//g')
	echo "$serial"
}

## 获取授权文件中指定证书的创建时间
function getProvisionCodeSignCreateTimestamp() {

    ##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
	## 得到字符串： Not Before: Sep  7 07:21:52 2017 GMT
	local startTimeStr=$( openssl x509 -noout -text -in "$Tmp_Cer_File" | grep "Not Before" )
	## 截图第一个：之后的字符串，得到：Sep  7 07:21:52 2017 GMT
	startTimeStr=$(echo ${startTimeStr#*:}) ## 截取,echo 去掉前后空格

	## 格式化
	local startTimestamp=$(date -j -f "%b %d  %T %Y %Z" "$startTimeStr" "+%s")
	# echo $(date -r `expr $startTimestamp `  "+%Y年%m月%d" )
	echo "$startTimestamp"
}


## 获取授权文件中指定证书的过期时间
function getProvisionCodeSignExpireTimestamp() {

    ##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    
	## 得到字符串： Not Before: Sep  7 07:21:52 2017 GMT
	local endTimeStr=$( openssl x509 -noout -text -in "$Tmp_Cer_File" | grep "Not After" )

	## 截图第一个：之后的字符串，得到：Sep  7 07:21:52 2017 GMT
	endTimeStr=$(echo ${endTimeStr#*:}) ## 截取，echo 去掉前后空格
	## 格式化
	local expireTimestamp=$(date -j -f "%b %d  %T %Y %Z" "$endTimeStr" "+%s")
	# echo $(date -r `expr $expireTimestamp + 86400`  "+%Y年%m月%d" )
	echo "$expireTimestamp"
}

## 获取授权文件信息
function getProvisionfileInfo() {

	local provisionFile=$1
	if [[ ! -f "$1" ]]; then
		errorExit "指定授权文件不存在!"
	fi
	#从mobileprovision文件中生成一个完整的plist文件
	security cms -D -i "$1" > "$Tmp_Provision_Plist_File"

	provisionFileTeamID=$(getProvisionfileTeamID "$1")

	provisionFileType=$(getProfileType "$1")
	channelName=$(getChannelName $provisionFileType)

	provisionFileName=$(getProvisionfileName "$1")
	provisionFileBundleID=$(getProfileBundleId "$1")
	provisionfileTeamName=$(getProvisionfileTeamName "$1")
	provisionFileUUID=$(getProvisionfileUUID "$1")

	provisionfileCreateTimestmap=$(getProvisionfileCreateTimestmap "$1")
	provisionfileCreateTime=$(date -r `expr $provisionfileCreateTimestmap `  "+%Y年%m月%d" )
	provisionfileExpireTimestmap=$(getProvisionfileExpireTimestmap "$1")
	provisionfileExpireTime=$(date -r `expr $provisionfileExpireTimestmap `  "+%Y年%m月%d" )
	provisionFileExpirationDays=$(getExpiretionDays "$provisionfileExpireTimestmap")

	codeSignIdentity=$(getCodeSignId)
	if [[ ! "$codeSignIdentity" ]]; then
		errorExit "获取授权文件签名失败!"
	fi
	codeSignIdentitySerial=$(getProvisionCodeSignSerial)

	provisionCodeSignCreateTimestmap=$(getProvisionCodeSignCreateTimestamp "$1")
	provisionCodeSignCreateTime=$(date -r `expr $provisionCodeSignCreateTimestmap `  "+%Y年%m月%d" )
	provisionCodeSignExpireTimestamp=$(getProvisionCodeSignExpireTimestamp "$1")
	provisionCodeSignExpireTime=$(date -r `expr $provisionCodeSignExpireTimestamp + 86400`  "+%Y年%m月%d" )
	provisionCodesignExpirationDays=$(getExpiretionDays "$provisionCodeSignExpireTimestamp")
	

	logit "【授权文件】名字：$provisionFileName "
	logit "【授权文件】类型：${provisionFileType}（${channelName}）"
	logit "【授权文件】TeamID：$provisionFileTeamID "
	logit "【授权文件】Team Name：$provisionfileTeamName "
	logit "【授权文件】BundleID：$provisionFileBundleID "
	logit "【授权文件】UUID：$provisionFileUUID "
	logit "【授权文件】创建时间：$provisionfileCreateTime "
	logit "【授权文件】过期时间：$provisionfileExpireTime "
	logit "【授权文件】有效天数：$provisionFileExpirationDays "
	logit "【授权文件】使用的证书签名ID：$codeSignIdentity "
	logit "【授权文件】使用的证书序列号：$codeSignIdentitySerial"
	logit "【授权文件】使用的证书创建时间：$provisionCodeSignCreateTime"
	logit "【授权文件】使用的证书过期时间：$provisionCodeSignExpireTime"
	logit "【授权文件】使用的证书有效天数：$provisionCodesignExpirationDays "
}

## 验证系统中是否有此签名ID证书
#codeSignIdentity=iPhone Developer: Jing Han (Q853BJVX2C) 
function checkCodeSignIdentityValid() {
	local codeSignIdentity=$1
	local content=$($CMD_Security find-identity -v -p codesigning | grep "$codeSignIdentity")
	if [[ ! "$content" ]]; then
		errorExit "证书签名ID:${codeSignIdentity}无效，请检查钥匙串是否导入对应的证书!"
	fi 
}

## 设置build.xcconfig配置
function setBuildXcconfigFile() {

	local key=$1
	local value=$2

	local xcconfigFile=$Tmp_Build_Xcconfig_File
	if [[ ! -f "$xcconfigFile" ]]; then
		exit 1
	fi

	if grep -q "[ ]*$key[ ]*=.*" "$xcconfigFile";then 
		## 进行替换
		sed -i "_bak" "s/[ ]*$key[ ]*=.*/$key = $value/g" "$xcconfigFile"
	else 
		## 进行追加(重定位)
		echo "$key = $value" >>"$xcconfigFile"
	fi
}


## 解锁keychain
function unlockKeychain(){
	#解锁keychain，使其它工具可以访问证书，
	$CMD_Security unlock-keychain -p "$UNLOCK_KEYCHAIN_PWD" "$HOME/Library/Keychains/login.keychain" 2>/dev/null
	if [[ $? -eq 0 ]]; then
		logit "【解锁钥匙串】解锁钥匙串成功";
	else
		errorExit "unlock-keychain失败, 请使用-p 参数或者在user_config配置文件中指定密码";
	fi
	$CMD_Security unlock-keychain -p "$UNLOCK_KEYCHAIN_PWD" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null
	
	#解锁后设置keychain关闭时间为1小时
	$CMD_Security set-keychain-settings -t 3600 -l "$HOME/Library/Keychains/login.keychain"
	if [[ $? -eq 0 ]]; then
		logit "【解锁钥匙串】解锁后设置keychain关闭时间为1小时";
	fi

}

##检查podfile是否存在
function checkPodfileAndInstall() {

	local podfile=$(find "$project_build_path" -maxdepth 1  -type f -iname "Podfile")
	if [[ -f "$podfile" ]]; then
		logit "【cocoapods】pod install";
		##必须cd到此工程目录
		cd "${project_build_path}"  
		pod install >> $Tmp_Log_File
		cd - 
	fi
}


### 开始构建归档，因为该函数里面逻辑较多，所以在里面添加了日志打印
function archiveBuild() {
	local targetName=$1
	local xcconfigFile=$2
	local xcworkspacePath=$3

	logit "【归档信息】开始归档中...";

	## archivePath 在函数archiveBuild 是全局变量
	archivePath="${Package_Dir}"/$targetName.xcarchive

	####################进行归档########################
	local cmd="$CMD_Xcodebuild archive"
	if [[ "$xcworkspacePath" ]]; then
		cmd="$cmd"" -workspace \"$xcworkspacePath\""
	fi
	## 
	cmd="$cmd"" -scheme $targetName -archivePath \"$archivePath\" -configuration $CONFIGRATION_TYPE -xcconfig $xcconfigFile clean build"

	local xcpretty=$(getXcprettyPath)
	if [[ "$xcpretty" ]]; then
		## 格式化日志输出
		cmd="$cmd"" | xcpretty >> $Tmp_Log_File"
	fi
	logit "【归档信息】归档命令为：$cmd"
	# 执行构建，set -o pipefail 为了获取到管道前一个命令xcodebuild的执行结果，否则$?一直都会是0
	eval "set -o pipefail && $cmd " 
	if [[ $? -ne 0 ]]; then
		errorExit "归档失败，请检查编译日志(编译错误、签名错误等)。"
	fi
	logit "【归档信息】项目构建成功，文件路径：$archivePath"
}


## 生成exportOptionsPlist文件
function generateOptionsPlist() {

	local plistfileContent="
	<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n
	<plist version=\"1.0\">\n
	<dict>\n
	<key>teamID</key>\n
	<string>$provisionFileTeamID</string>\n
	<key>method</key>\n
	<string>$provisionFileType</string>\n
	<key>stripSwiftSymbols</key>\n
    <true/>\n
	<key>provisioningProfiles</key>\n
    <dict>\n
        <key>$provisionFileBundleID</key>\n
        <string>$provisionFileName</string>\n
    </dict>\n
	<key>compileBitcode</key>\n
	<false/>\n
	</dict>\n
	</plist>\n
	"
	## 重定向
	echo -e "$plistfileContent" > "$Tmp_Options_Plist_File"
}


## 导出IPA
function exportIPA() {

	local targetName=$1
	# %.* 表示去除最后的文件后缀
	# local targetName=${archivePath%.*}
	# targetName=${targetName##*/}
	exportPath="${Package_Dir}"/${targetName}.ipa

	####################进行导出IPA########################
	local cmd="$CMD_Xcodebuild -exportArchive"
	## xcode版本 >= 8.3
	# if versionCompareGE "$xcodeVersion" "8.3"; then	
	# else
	# 	cmd="$cmd"" -exportFormat IPA -archivePath \"$archivePath\" -exportPath \"$exportPath\""
	# fi
	cmd="$cmd"" -archivePath \"$archivePath\" -exportPath \"$Package_Dir\" -exportOptionsPlist \"$Tmp_Options_Plist_File\""
	## 判断是否安装xcpretty
	xcpretty=$(getXcprettyPath)
	if [[ "$xcpretty" ]]; then
		## 格式化日志输出
		cmd="$cmd | xcpretty -c  >> $Tmp_Log_File"
	fi
	logit "【IPA 导出】导出ipa命令为：$cmd"
	# set -o pipefail 为了获取到管道前一个命令xcodebuild的执行结果，否则$?一直都会是0
	eval "set -o pipefail && $cmd" ;
	if [[ $? -ne 0 ]]; then
		errorExit "导出ipa失败，请检查日志。"
	fi
	logit "【IPA 导出】IPA导出成功，文件路径：$exportPath"
}


#构建完成，校验ipa
function checkIPA() {
	logit "【签名校验】IPA签名校验中..."
	local exportPath=$1
	if [[ ! -f "$exportPath" ]]; then
		errorExit "无法找到$exportPath"
	fi
	# 获取app文件名称
	local appName=${archivePath%.*}
	appName=${appName##*/}
	# local ipaName=`basename "$exportPath" .ipa`

	##解压强制覆盖，并不输出日志
	if [[ -d "${Package_Dir}/Payload" ]]; then
		rm -rf "${Package_Dir}/Payload"
	fi
	unzip -o "$exportPath" -d ${Package_Dir} >/dev/null 2>&1
	
	local app=${Package_Dir}/Payload/"${appName}".app
	codesign --no-strict -v "$app"
	if [[ $? -ne 0 ]]; then
		errorExit "签名检查：签名校验不通过！"
	fi
	logit "【签名校验】签名校验通过"
	if [[ ! -d "$app" ]]; then
		errorExit "解压失败！无法找到$app"
	fi

	local ipaInfoPlistFile=${app}/Info.plist
	local mobileProvisionFile=${app}/embedded.mobileprovision
	local appShowingName=`$CMD_PlistBuddy -c "Print :CFBundleName" $ipaInfoPlistFile`
	local appBundleId=`$CMD_PlistBuddy -c "print :CFBundleIdentifier" "$ipaInfoPlistFile"`
	local appVersion=`$CMD_PlistBuddy -c "Print :CFBundleShortVersionString" $ipaInfoPlistFile`
	local appBuildVersion=`$CMD_PlistBuddy -c "Print :CFBundleVersion" $ipaInfoPlistFile`

	# $ codesign -vv -d Example.app 会列出一些有关 Example.app 的签名信息
	local appCodeSignIdenfifier=$($CMD_Codesign -dvvv "$app" 2>/tmp/log.txt &&  grep Authority /tmp/log.txt | head -n 1 | cut -d "=" -f2)
	#支持最小的iOS版本
	local supportMinimumOSVersion=$($CMD_PlistBuddy -c "print :MinimumOSVersion" "$ipaInfoPlistFile")
	#支持的arch
	local supportArchitectures=$($CMD_Lipo -info "$app"/"$appName" | cut -d ":" -f 3)

	logit "【IPA 信息】ipa名字:$appShowingName"
	logit "【IPA 信息】bundleID:$appBundleId"
	logit "【IPA 信息】版本:$appVersion"
	logit "【IPA 信息】build:$appBuildVersion"
	logit "【IPA 信息】支持最低iOS版本:$supportMinimumOSVersion"
	logit "【IPA 信息】支持的archs:$supportArchitectures"
	logit "【IPA 信息】签名:$appCodeSignIdenfifier"

	# getProvisionfileInfo "$mobileProvisionFile"

    ## 清除解压出来的Playload
    rm -rf ${Package_Dir}/Payload
}


function getProjectVersion() {
	local infoPlistFile=$1
	if [[ ! -f "$infoPlistFile" ]]; then
		exit 1
	fi
	local projectVersion=$($CMD_PlistBuddy -c "Print :CFBundleShortVersionString"  "$infoPlistFile")

	echo $projectVersion
}
function getBuildVersion() {
	local infoPlistFile=$1
	if [[ ! -f "$infoPlistFile" ]]; then
		exit 1
	fi
	local projectVersion=$($CMD_PlistBuddy -c "Print :CFBundleVersion"  "$infoPlistFile")

	echo $projectVersion
}


## 线下手动打包IPA和日志重命名
function renameIPAAndLogFile () {
	local targetName=$1
	local infoPlistFile=$2
	local channelName=$3
	if [[ ! -f "$infoPlistFile" ]]; then
		return;
	fi
	logit "【IPA 信息】IPA和日志文件重命名..."

	local curDatte=`date +"%Y%m%d_%H%M%S"`
	local ipaName=${targetName}_${curDatte}
	local projectVersion=$(getProjectVersion "$infoPlistFile")
	local buildVersion=$(getBuildVersion "$infoPlistFile")

	ipaName="${ipaName}""_${channelName}""_${projectVersion}""(${buildVersion})"
	## 去除最后的文件名称,得到纯路径
	local exportDir=${exportPath%/*} 
	# ipa文件路径
	ipaFilePath=${exportDir}/${targetName}.ipa
	# 线上打包名字固定，线下打包重命名IPA名称
	if [ $Package_Mode == "Offline" ]; then
		ipaFilePath=${exportDir}/${ipaName}.ipa
	fi
	logTxtFilePath=${exportDir}/${ipaName}.txt
	logit "【IPA 信息】IPA路径:$ipaFilePath"
	logit "【IPA 信息】日志路径:$logTxtFilePath"
	# 重命名
	mv "$exportPath" 	"$ipaFilePath"
	mv "$Tmp_Log_File" 	"$logTxtFilePath"

	Tmp_Log_File=$logTxtFilePath
}

#执行完毕，删除临时文件
function clearCache() {

    removeFileWithPath "$Tmp_Options_Plist_File"
    removeFileWithPath "$Tmp_Build_Xcconfig_File"
    removeFileWithPath "$archivePath"
    removeFileWithPath "$Package_Dir/Packaging.log"
    removeFileWithPath "$Package_Dir/ExportOptions.plist"
    removeFileWithPath "$Package_Dir/DistributionSummary.plist"

}

## 删除指定文件
function removeFileWithPath() {

	local filePath=$1
	logit "【清理文件】$filePath "
	if [ -d "${filePath}" ]; then
        rm -rf ${filePath}
        if [ $? -eq 0 ];then
        	logit "【清理文件】删除成功 $filePath "
        else
        	errorExit "删除文件失败 $filePath "
        fi
    fi
    
}

##字符串版本号比较：大于等于
function versionCompareGE() { test "$(echo "$@" | tr " " "\n" | sort -rn | head -n 1)" == "$1"; }


## 获取xcpretty安装路径
function getXcprettyPath() {
	xcprettyPath=$(which xcpretty)
	echo $xcprettyPath
}


### 显示当前脚本版本号的
function getShellVersion(){
	if [[ -d "${Shell_File_Path}/.git" ]]; then
		gitVersionCount=`git -C "$Shell_File_Path" rev-list HEAD | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
		logit "${gitVersionCount}"
	fi
}

#############################################上传蒲公英#############################################

function pgyerUpload() {

	local filePath=$1
	local userKey=$2
	local apiKey=$3
	if [[ ! "$userKey" ]] || [[ ! "$apiKey" ]]; then
		userKey="b805f985351b48620bd95cc5e4ab579b"
		apiKey="b9bcf5ef168fdf8ce379ae9ab9bd8dcc"
		logit "【上传蒲公英】userKey:$userKey"
		logit "【上传蒲公英】apiKey:$apiKey"
	fi
	logit "【上传蒲公英】蒲公英上传中..."
    /usr/bin/curl -F "file=@${filePath}" -F "uKey=$userKey" -F "_api_key=$apiKey" "https://www.pgyer.com/apiv1/app/upload"
    if [ $? -eq 0 ];then
        logit "【上传蒲公英】上传成功"
    else
        warning "【上传蒲公英】上传失败，重新上传"
        # pgyerUpload "$ipaFilePath" "$pgyer_userKey" "$pgyer_apiKey"
    fi
	
}


# function addManulCodeSigning ()
# {
# 	local pbxproj=$1/project.pbxproj
# 	local targetId=$2
# 	local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxproj")
# 	##如果需要设置成自动签名,将Manual改成Automatic
# 	$CMD_PlistBuddy -c "Add :objects:$rootObject:attributes:TargetAttributes:$targetId:ProvisioningStyle string Manual" "$pbxproj"
# }

