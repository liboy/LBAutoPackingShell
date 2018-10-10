#!/bin/bash


# ----------------------------------------------------------------------
# name:         ipa_public_function.sh
# version:      1.0.0(100)
# createTime:   2018-08-30
# description:  ipa打包函数文件
# author:       liboy
# email:        779385288@qq.com
# github:       https://github.com/liboy/ios_auto_package_shell
# ----------------------------------------------------------------------

function usage
{
	# setAliasShortCut
	echo ""
	echo "Usage:$(basename $0) -[abcdptvhx] [--enable-bitcode] [--auto-buildversion] ..."
	echo "可选项："
	echo "  -a | --archs <armv7|arm64|armv7 arm64> 指定构建架构集，例如：-a 'armv7'或者 -a 'arm64' 或者 -a 'armv7 arm64' 等"
  	echo "  -b | --bundle-id <bundleId> 设置Bundle Id"
  	echo "  -c | --channel <development|app-store|enterprise|ad-hoc>"
	echo "  -d | --provision-dir <dir> 指定授权文件目录，默认会在~/Library/MobileDevice/Provisioning Profiles 中寻找"
	echo "  -p | --keychain-password <passoword> 指定访问证书时解锁钥匙串的密码，即开机密码"
	echo "  -t | --target <targetName> 指定构建的target。默认当项目是单工程(非workspace)或者除Pods.xcodeproj之外只有一个工程的情况下，自动构建工程的第一个Target"
	echo "  -v | --version 输出当前脚本版本号"
	echo "  -h | --help 帮助."
	echo "  -x 脚本执行调试模式."

	
	echo "  --show-profile-detail <provisionfile> 查看授权文件的信息详情(development、enterprise、app-store、ad-hoc)"
	echo "  --pgyer-upload <ipafilepath>  指定IPA文件上传蒲公英"

	exit 0
}



#############################################基本配置#############################################


function getXcconfigValue() {
	local xcconfigFile=$1
	local key=$2
	if [[ ! -f "$xcconfigFile" ]]; then
		exit 1
	fi
	## 去掉//开头 ;  查找key=特征，去掉双引号
	local value=$(grep -v "[ ]*//" "$xcconfigFile" | grep -e "[ ]*$key[ ]*=" | tail -1| cut -d "=" -f2 | grep -o "[^ ]\+\( \+[^ ]\+\)*" | sed 's/\"//g' | sed "s/\'//g" ) 

	echo $value
}

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
	echo $xcconfigFile
}
## 初始化用户配置文件user.xcconfig
function initUserXcconfig() {
	if [[ -f "$Shell_User_Xcconfig_File" ]]; then
		local allKeys=(CHANNEL)
		for key in ${allKeys[@]}; do

			local value=$(getXcconfigValue "$Shell_User_Xcconfig_File" "$key")
			
			if [[ "$value" ]]; then
				# 重新赋值变量
				eval "$key"='$value'
				logit "【初始化用户配置】${key} = `eval echo "$value"`"
			fi

		done
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
}


## 获取Xcode版本
function getXcodeVersion() {
	local xcodeVersion=`$CMD_Xcodebuild -version | head -1 | cut -d " " -f 2`
	echo $xcodeVersion
}


##查找xcworkspace工程启动文件
function findXcworkspace() {

	local xcworkspace=$(find "$Shell_Work_Path" -maxdepth 1  -type d -iname "*.xcworkspace")
	if [[ -d "$xcworkspace" ]] || [[ -f "${xcworkspace}/contents.xcworkspacedata" ]]; then
		echo $xcworkspace
	fi
}

## 获取workspace的项目路径列表
function getAllXcprojPathFromWorkspace() {
	local xcworkspace=$1;
	local xcworkspacedataFile="$xcworkspace/contents.xcworkspacedata";
	if [[ ! -f "$xcworkspacedataFile" ]]; then
		echo "xcworkspacedata 文件不存在";
		exit 1;
	fi
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


##查找xcodeproj工程启动文件
function findXcodeproj() {

	local xcodeprojPath=$(find "$Shell_Work_Path" -maxdepth 1  -type d -iname "*.xcodeproj")
	if [[ ! -d "$xcodeprojPath" ]] || [[ ! -f "${xcodeprojPath}/project.pbxproj" ]]; then
		exit 1
	fi
	echo  $xcodeprojPath
}


##这里只取第一个target
function getTargetName()
{
	local pbxproj=$1/project.pbxproj
	local targetId=$2
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
	local targetName=$($CMD_PlistBuddy -c "Print :objects:$targetId:name" "$pbxproj")
	echo $targetName
}

## 获取xcproj的所有target
## 比分数组元素本身带有空格，所以采用字符串用“;”作为分隔符，而不是用数组。
function getAllTargetsInfoFromXcprojList() {
	## 转换成数组
	local xcprojList=$1

	## 因在mac 系统下 在for循环中无法使用map ，所以使用数组来代替，元素格式为 targetId:targetName:xcprojPath
	local wrapXcprojListStr='' ##
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
				if [[ "$wrapXcprojListStr" == '' ]]; then
					wrapXcprojListStr="$info";
				else
					wrapXcprojListStr="${wrapXcprojListStr};${info}";

				fi
			done
		fi
	done
	echo "$wrapXcprojListStr"

}


## 例如分割
# 16A99C1E1C744CE000907D37:iXiao:/Users/liboy/Desktop/自动打包/xinyue/iXiao.xcworkspace/../iXiao.xcodeproj;
# 16A99C371C744CE100907D37:iXiaoTests:/Users/liboy/Desktop/自动打包/xinyue/iXiao.xcworkspace/../iXiao.xcodeproj
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

## 获取配置ID列表,主要是后续用来获取bundle id
function getConfigurationIds() {

	##配置模式：Debug 或 Release
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
  	local buildConfigurationListId=$($CMD_PlistBuddy -c "Print :objects:$targetId:buildConfigurationList" "$pbxproj")
  	local buildConfigurationList=$($CMD_PlistBuddy -c "Print :objects:$buildConfigurationListId:buildConfigurations" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
  	##数组中存放的分别是release和debug对应的id
  	local configurationTypeIds=$(echo $buildConfigurationList)
  	echo $configurationTypeIds

}
## 获取配置ID，通过targetid、CONFIGRATION_TYPE
function getConfigurationIdWithType(){

	local configrationType=$3
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi

	local configurationTypeIds=$(getConfigurationIds "$1" $targetId)
	for id in ${configurationTypeIds[@]}; do
		local name=$($CMD_PlistBuddy -c "Print :objects:$id:name" "$pbxproj")
		if [[ "$configrationType" == "$name" ]]; then
			echo $id
		fi
	done
}

## 根据配置模式ID，获取项目bundleId,分为Releae和Debug
function getProjectBundleId()
{	
	# 配置模式ID
	local configurationId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
	local bundleId=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings:PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
	echo $bundleId
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
	infoPlistFilePath="$1/../$infoPlistFileName"
	echo $infoPlistFilePath
}

## 获取git仓库版本数量
function getGitRepositoryVersionNumbers (){
	## 是否存在.git目录
	local gitRepository=$(find "$Shell_Work_Path" -maxdepth 1  -type d -iname ".git")
	if [[ ! -d "$gitRepository" ]]; then
		exit 1
	fi

	local gitRepositoryVersionNumbers=$(git -C "$Shell_Work_Path" rev-list HEAD 2>/dev/null | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*")
	if [[ $? -ne 0 ]]; then
		## 可能是git只有在本地，而没有提交到服务器,或者没有网络
		exit 1
	fi
	echo $gitRepositoryVersionNumbers
}


#############################################签名设置#############################################

##获取签名方式,##设置手动签名,即不勾选：Xcode -> General -> Signing -> Automatically manage signning
## 在xcode 9之前（不包含9），只有在General这里配置是否手动签名，在xcode9之后，多加了一项在setting中
function getCodeSigningStyle ()
{

	local pbxproj=$1/project.pbxproj
	local targetId=$2
	local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxproj")
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
	##没有勾选过Automatically manage signning时，则不存在ProvisioningStyle
	signingStyle=$($CMD_PlistBuddy -c "Print :objects:$rootObject:attributes:TargetAttributes:$targetId:ProvisioningStyle " "$pbxproj" 2>/dev/null)
	echo $signingStyle

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

## 设置手动签名
function setManulCodeSigningRuby() {
	local project=$1
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	##获取签名方式
	local codeSigningStyle=$(getCodeSigningStyle "$xcodeprojPath" "$targetId")
	echo  $codeSigningStyle
	if [[ ! "$codeSigningStyle" ]] || [[ "$codeSigningStyle" != "Manual" ]]; then
		logit "【签名信息】设置签名方式:Manual"
		ruby "$Shell_File_Path/set_codesign_style.rb" "$project" "$targetId" 2>/dev/null
		## 这里会报错 :如果c [Xcodeproj] Unknown object version. (RuntimeError),但是实际可以修改成功，暂时不做下面的逻辑处理
		# if [[ $? -ne 0 ]]; then
		# 	local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxproj")
		# 	local compatibilityVersion=$($CMD_PlistBuddy -c "Print :objects:$rootObject:compatibilityVersion" "$pbxproj")
		# 	if [[ "$compatibilityVersion"=="Xcode 9.3" ]]; then
		# 		errorExit "设置手动签名失败,cocoapod 不兼容Xcode 9.3。版本请在【项目】- xxxTarget】- Show the File inspector】- Project Document】-【Project Format】 中选中小于Xcode 9.3-compatible的一项"
		# 	else
		# 		errorExit "设置手动签名失败，请在【项目】-【General】-【Signing】中去掉勾选Automatically manage signning"
		# 	fi

		# fi
	fi
}

## 检查openssl
function checkOpenssl() {
	local opensslInfo=$(openssl version)
	local opensslName=$(echo $opensslInfo | cut -d " " -f1)
	local opensslVersion=$(echo $opensslInfo | cut -d " " -f2)
	if [[ "$opensslName" == "LibreSSL" ]] || ! versionCompareGE "${opensslVersion%\.*}" "1.0"; then
		errorExit "${opensslInfo} 版本过旧，请更新 OpenSSL 版本"
	fi
	logit "【构建信息】OpenSSL 版本:$opensslVersion"
}

#############################################授权文件#############################################

## 从授权文件获取BundleId
function getProfileBundleId()
{
	local profile=$1
	local applicationIdentifier=$($CMD_PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null )")
	if [[ $? -ne 0 ]]; then
		exit 1;
	fi
	##截取bundle id,这种截取方法，有一点不太好的就是：当applicationIdentifier的值包含：*时候，会截取失败,如：applicationIdentifier=6789.*
	local bundleId=${applicationIdentifier#*.}
	echo $bundleId
}

## 获取授权文件类型
function getProfileType()
{
	local profile=$1
	local profileType=''
	if [[ ! -f "$profile" ]]; then
		exit 1
	fi
	##判断是否存在key:ProvisionedDevices
	local haveKey=$($CMD_Security cms -D -i "$profile" 2>/dev/null | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//' | grep ProvisionedDevices)
	if [[ "$haveKey" ]]; then
		local getTaskAllow=$($CMD_PlistBuddy -c 'Print :Entitlements:get-task-allow' /dev/stdin <<< $($CMD_Security cms -D -i "$profile" 2>/dev/null ) )
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
function getProvisionfileExpireTimestmap {
	local provisionFile=$1
	##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    ##获取授权文件的过期时间
    local expirationTime=`$CMD_PlistBuddy -c 'Print :ExpirationDate' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/tmp/log.txt)`
    local timestamp=`date -j -f "%a %b %d  %T %Z %Y" "$expirationTime" "+%s"`
    # echo $(date -r `expr $timestamp `  "+%Y年%m月%d" )
    echo "$timestamp"
}

##匹配授权文件
function matchMobileProvisionFile() {	
	## 分发渠道
	local channel=$1
	## BundleId
	local appBundleId=$2
	## 授权文件目录
	local mobileProvisionFileDir=$3
	if [[ ! -d "$mobileProvisionFileDir" ]]; then
		exit 1
	fi
	##遍历
	local provisionFile=''
	local maxExpireTimestmap=0

	for file in "${mobileProvisionFileDir}"/*.mobileprovision; do
		local bundleIdFromProvisionFile=$(getProfileBundleId "$file")
		if [[ "$bundleIdFromProvisionFile" ]] && [[ "$appBundleId" == "$bundleIdFromProvisionFile" ]]; then
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
	echo $provisionFile
}

## 获取授权文件TeamID
function getProvisionfileTeamID()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileTeamID=$($CMD_PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/dev/null))
	echo $provisonfileTeamID
}

## 获取授权文件名称
function getProvisionfileName()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileName=$($CMD_PlistBuddy -c 'Print :Name' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/dev/null))
	echo $provisonfileName
}

## 获取profile type的中文名字
function getProfileTypeCNName()
{
    local profileType=$1
    local profileTypeName
    if [[ "$profileType" == 'app-store' ]]; then
        profileTypeName='商店分发'
    elif [[ "$profileType" == 'enterprise' ]]; then
        profileTypeName='企业分发'
	elif [[ "$profileType" == 'ad-hoc' ]]; then
        profileTypeName='内部测试(ad-hoc)'
    else
        profileTypeName='内部测试'
    fi
    echo $profileTypeName

}

## 获取授权文件UUID
function getProvisionfileUUID()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileUUID=$($CMD_PlistBuddy -c 'Print :UUID' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/dev/null))
	echo $provisonfileUUID
}
## 获取授权文件TeamName
function getProvisionfileTeamName()
{
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	provisonfileTeamName=$($CMD_PlistBuddy -c 'Print :TeamName' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/dev/null))
	echo $provisonfileTeamName
}

function getProvisionfileCreateTimestmap {
	local provisionFile=$1
	##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    ##获取授权文件的过期时间
    local createTime=`$CMD_PlistBuddy -c 'Print :CreationDate' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/tmp/log.txt)`
    local timestamp=`date -j -f "%a %b %d  %T %Z %Y" "$createTime" "+%s"`
    # echo $(date -r `expr $timestamp `  "+%Y年%m月%d" )
    echo "$timestamp"
}

##获取授权文件过期天数
function getExpiretionDays()
{

	local expireTimestamp=$1
    local nowTimestamp=`date +%s`
    local r=$[expireTimestamp-nowTimestamp]
    local days=$[r/60/60/24]
    echo $days
}

## 将授权文件的签名数据封装成证书
function wrapProvisionSignDataToCer {

	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi
	## 获取DeveloperCertificates 字段
	local data=$($CMD_Security cms -D -i "$provisionFile" | grep data | head -n 1 | sed 's/.*<data>//g' | sed 's/<\/data>.*//g' ) 


	if [[ $? -ne 0 ]]; then
		exit 1
	fi
	## 使用openssl进行解码 1. 构建cer证书 2. 解码证书
	## 1.
	local tmpCerFile='/tmp/tmp.cer'
	echo "-----BEGIN CERTIFICATE-----" 	> "$tmpCerFile"
	echo "${data}"						>> "$tmpCerFile"
	echo "-----END CERTIFICATE-----"	>> "$tmpCerFile"
	echo "${tmpCerFile}"
}

## 获取授权文件中的签名id
function getCodeSignId() {

	local provisionFile=$1
	local cerFile=$(wrapProvisionSignDataToCer "$provisionFile")
	local codeSignIdentity=$(openssl x509 -noout -text -in "$cerFile"  | grep Subject | grep "CN=" | cut -d "," -f2 | cut -d "=" -f2)
	##必须使用"${}"这种形式，否则连续的空格会被转换成一个空格
	## 这里使用-e 来解决中文签名id的问题
	echo -e "${codeSignIdentity}"
}

## 获取授权文件中的证书序列号
function getProvisionCodeSignSerial {
	local provisionFile=$1
	local cerFile=$(wrapProvisionSignDataToCer "$provisionFile")
	## 去掉空格
	local serial=$( openssl x509 -noout -text -in "$cerFile" | grep "Serial Number" | cut -d ':' -f2 | sed 's/^[ ]//g')
	echo "$serial"
}

## 获取授权文件中指定证书的创建时间
function getProvisionCodeSignCreateTimestamp {
	local provisionFile=$1
	local cerFile=$(wrapProvisionSignDataToCer "$provisionFile")

    ##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
	## 得到字符串： Not Before: Sep  7 07:21:52 2017 GMT
	local startTimeStr=$( openssl x509 -noout -text -in "$cerFile" | grep "Not Before" )
	## 截图第一个：之后的字符串，得到：Sep  7 07:21:52 2017 GMT
	startTimeStr=$(echo ${startTimeStr#*:}) ## 截取,echo 去掉前后空格

	## 格式化
	local startTimestamp=$(date -j -f "%b %d  %T %Y %Z" "$startTimeStr" "+%s")
	# echo $(date -r `expr $startTimestamp `  "+%Y年%m月%d" )
	echo "$startTimestamp"
}


## 获取授权文件中指定证书的过期时间
function getProvisionCodeSignExpireTimestamp {
	local provisionFile=$1
	local cerFile=$(wrapProvisionSignDataToCer "$provisionFile")

    ##切换到英文环境，不然无法转换成时间戳
    export LANG="en_US.UTF-8"
    
	## 得到字符串： Not Before: Sep  7 07:21:52 2017 GMT
	local endTimeStr=$( openssl x509 -noout -text -in "$cerFile" | grep "Not After" )

	## 截图第一个：之后的字符串，得到：Sep  7 07:21:52 2017 GMT
	endTimeStr=$(echo ${endTimeStr#*:}) ## 截取，echo 去掉前后空格
	## 格式化
	local expireTimestamp=$(date -j -f "%b %d  %T %Y %Z" "$endTimeStr" "+%s")
	# echo $(date -r `expr $expireTimestamp + 86400`  "+%Y年%m月%d" )
	echo "$expireTimestamp"
}

## 获取授权文件信息
function getProfileInfo() {

	if [[ ! -f "$1" ]]; then
		errorExit "指定授权文件不存在!"
	fi

	provisionFileTeamID=$(getProvisionfileTeamID "$1")

	provisionFileType=$(getProfileType "$1")
	channelName=$(getProfileTypeCNName $provisionFileType)

	provisionFileName=$(getProvisionfileName "$1")
	provisionFileBundleID=$(getProfileBundleId "$1")
	provisionfileTeamName=$(getProvisionfileTeamName "$1")
	provisionFileUUID=$(getProvisionfileUUID "$1")

	provisionfileCreateTimestmap=$(getProvisionfileCreateTimestmap "$1")
	provisionfileCreateTime=$(date -r `expr $provisionfileCreateTimestmap `  "+%Y年%m月%d" )
	provisionfileExpireTimestmap=$(getProvisionfileExpireTimestmap "$1")
	provisionfileExpireTime=$(date -r `expr $provisionfileExpireTimestmap `  "+%Y年%m月%d" )
	provisionFileExpirationDays=$(getExpiretionDays "$provisionfileExpireTimestmap")

	provisionfileCodeSign=$(getCodeSignId "$1")
	provisionfileCodeSignSerial=$(getProvisionCodeSignSerial "$1")

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
	logit "【授权文件】使用的证书签名ID：$provisionfileCodeSign "
	logit "【授权文件】使用的证书序列号：$provisionfileCodeSignSerial"
	logit "【授权文件】使用的证书创建时间：$provisionCodeSignCreateTime"
	logit "【授权文件】使用的证书过期时间：$provisionCodeSignExpireTime"
	logit "【授权文件】使用的证书有效天数：$provisionCodesignExpirationDays "
}


function checkCodeSignIdentityValid()
{
	local codeSignIdentity=$1
	local content=$($CMD_Security find-identity -v -p codesigning | grep "$codeSignIdentity")
	echo "$content"
}

## 添加一项配置
function setXCconfigWithKeyValue() {

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
	$CMD_Security unlock-keychain -p "$UNLOCK_KEYCHAIN_PWD" "$HOME/Library/Keychains/login.keychain" 2>/dev/null
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	$CMD_Security unlock-keychain -p "$UNLOCK_KEYCHAIN_PWD" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	return 0
}

##检查podfile是否存在
function checkPodfileExist() {

	local podfile=$(find "$Shell_Work_Path" -maxdepth 1  -type f -iname "Podfile")
	if [[ ! -f "$podfile" ]]; then
		exit 1
	fi
	echo $podfile
}


### 开始构建归档，因为该函数里面逻辑较多，所以在里面添加了日志打印
function archiveBuild()
{
	local targetName=$1
	local xcconfigFile=$2
	local xcworkspacePath=$(findXcworkspace)

	## 暂时使用全局变量---
	archivePath="${Package_Dir}"/$targetName.xcarchive


	####################进行归档########################
	local cmd="$CMD_Xcodebuild archive"
	if [[ "$xcworkspacePath" ]]; then
		cmd="$cmd"" -workspace \"$xcworkspacePath\""
	fi
	## warning项目耦合处 CONFIGRATION_TYPE
	cmd="$cmd"" -scheme $CONFIGRATION_TYPE -archivePath \"$archivePath\" -configuration $CONFIGRATION_TYPE -xcconfig $xcconfigFile clean build"

	local xcpretty=$(getXcprettyPath)
	if [[ "$xcpretty" ]]; then
		## 格式化日志输出
		cmd="$cmd"" | xcpretty "
	fi

	# 执行构建，set -o pipefail 为了获取到管道前一个命令xcodebuild的执行结果，否则$?一直都会是0
	eval "set -o pipefail && $cmd " 
	if [[ $? -ne 0 ]]; then
		errorExit "归档失败，请检查编译日志(编译错误、签名错误等)。"
	fi


	# echo "$archivePath"
}


##xcode 8.3之后使用-exportFormat导出IPA会报错 xcodebuild: error: invalid option '-exportFormat',改成使用-exportOptionsPlist
function generateOptionsPlist(){
	local provisionFile=$1
	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi

	local provisionFileTeamID=$(getProvisionfileTeamID "$provisionFile")
	local provisionFileType=$(getProfileType "$provisionFile")
	local provisionFileName=$(getProvisionfileName "$provisionFile")
	local provisionFileBundleID=$(getProfileBundleId "$provisionFile")


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
	echo "$Tmp_Options_Plist_File"
}


## 导出IPA
function exportIPA() {

	local archivePath=$1
	local provisionFile=$2
	# %.* 表示去除最后的文件后缀
	# local targetName=${archivePath%.*}
	# targetName=${targetName##*/}
	local xcodeVersion=$(getXcodeVersion)
	## warning项目耦合处 CONFIGRATION_TYPE
	exportPath="${Package_Dir}"/${CONFIGRATION_TYPE}.ipa

	if [[ ! -f "$provisionFile" ]]; then
		exit 1
	fi

	####################进行导出IPA########################
	local cmd="$CMD_Xcodebuild -exportArchive"
	## xcode版本 >= 8.3
	if versionCompareGE "$xcodeVersion" "8.3"; then
		local optionsPlistFile=$(generateOptionsPlist "$provisionFile")
		cmd="$cmd"" -archivePath \"$archivePath\" -exportPath \"$Package_Dir\" -exportOptionsPlist \"$optionsPlistFile\""
	else
		cmd="$cmd"" -exportFormat IPA -archivePath \"$archivePath\" -exportPath \"$exportPath\""
	fi
	## 判断是否安装xcpretty
	xcpretty=$(getXcprettyPath)
	if [[ "$xcpretty" ]]; then
		## 格式化日志输出
		cmd="$cmd | xcpretty -c"
	fi
	# set -o pipefail 为了获取到管道前一个命令xcodebuild的执行结果，否则$?一直都会是0
	eval "set -o pipefail && $cmd" ;
	if [[ $? -ne 0 ]]; then
		errorExit "导出ipa失败，请检查日志。"
	fi
}

##打包的时候：会报 archived-expanded-entitlements.xcent  文件缺失!这是xcode的bug
##链接：http://stackoverflow.com/questions/28589653/mac-os-x-build-server-missing-archived-expanded-entitlements-xcent-file-in-ipa
## 发现在 xcode >= 8.3.3 以上都不存在 ,在xcode8.2.1 存在
function repairXcentFile()
{

	local exportPath=$1
	local archivePath=$2
	local xcodeVersion=$(getXcodeVersion)

	## 小于8.3(不包含8.3)
	if ! versionCompareGE "$xcodeVersion" "8.3"; then
		local appName=`basename "$exportPath" .ipa`
		local xcentFile="${archivePath}"/Products/Applications/"${appName}".app/archived-expanded-entitlements.xcent
		if [[ -f "$xcentFile" ]]; then
			# baxcent文件从archive中拷贝到IPA中
			unzip -o "$exportPath" -d /"$Package_Dir" >/dev/null 2>&1
			local app="${Package_Dir}"/Payload/"${appName}".app
			cp -af "$xcentFile" "$app" >/dev/null 2>&1
			##压缩,并覆盖原有的ipa
			cd "${Package_Dir}"  ##必须cd到此目录 ，否则zip会包含绝对路径
			zip -qry  "$exportPath" Payload >/dev/null 2>&1 && rm -rf Payload
			cd - >/dev/null 2>&1
			## 因为重新加压，文件名和路径都没有变化
			local ipa=$exportPath
			echo  "$ipa"
		fi
	fi
}



#构建完成，校验ipa
function checkIPA() {

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


	local appCodeSignIdenfifier=$($CMD_Codesign -dvvv "$app" 2>/tmp/log.txt &&  grep Authority /tmp/log.txt | head -n 1 | cut -d "=" -f2)
	#支持最小的iOS版本
	local supportMinimumOSVersion=$($CMD_PlistBuddy -c "print :MinimumOSVersion" "$ipaInfoPlistFile")
	#支持的arch
	local supportArchitectures=$($CMD_Lipo -info "$app"/"$appName" | cut -d ":" -f 3)

	logit "【IPA 信息】名字:$appShowingName"
	# getEnvirionment
	# logit "配置环境kBMIsTestEnvironment:$currentEnvironmentValue"
	logit "【IPA 信息】bundleID:$appBundleId"
	logit "【IPA 信息】版本:$appVersion"
	logit "【IPA 信息】build:$appBuildVersion"
	logit "【IPA 信息】支持最低iOS版本:$supportMinimumOSVersion"
	logit "【IPA 信息】支持的archs:$supportArchitectures"
	logit "【IPA 信息】签名:$appCodeSignIdenfifier"

	# getProfileInfo "$mobileProvisionFile"

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


## 获取最终IPA名称
function finalIPAName ()
{

	local targetName=$1
	local infoPlistFile=$2
	local channelName=$3

	if [[ ! -f "$infoPlistFile" ]]; then
		return;
	fi
		## IPA和日志重命名
	local curDatte=`date +"%Y%m%d_%H%M%S"`
	local ipaName=${targetName}_${curDatte}
	local projectVersion=$(getProjectVersion "$infoPlistFile")
	local buildVersion=$(getBuildVersion "$infoPlistFile")

	ipaName="${ipaName}""_${channelName}""_${projectVersion}""(${buildVersion})"
	echo "$ipaName"
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
	if [[ -d "${Shell_Work_Path}/.git" ]]; then
		gitVersionCount=`git -C "$Shell_Work_Path" rev-list HEAD | wc -l | grep -o "[^ ]\+\( \+[^ ]\+\)*"`
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
		logit "【上传蒲公英】userKey: $userKey"
		logit "【上传蒲公英】apiKey:$apiKey"
	fi
	logit "【上传蒲公英】蒲公英上传中..."
    /usr/bin/curl -F "file=@${filePath}" -F "uKey=$userKey" -F "_api_key=$apiKey" "https://www.pgyer.com/apiv1/app/upload"
    if [ $? -eq 0 ];then
        logit "【上传蒲公英】上传成功"
    else
        warning "【上传蒲公英】上传失败，重新上传"
        pgyerUpload
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
##匹配签名身份--方法已被替换
# function matchCodeSignIdentity()
# {
# 	local provisionFile=$1
# 	local channel=$2
# 	local channelFilterString=''
# 	local startSearchString=''
# 	local endSearchString='1\\0230\\021\\006\\003U\\004'


# 	if [[ ! -f "$provisionFile" ]]; then
# 		exit 1;
# 	fi

# 	if [[ "$channel" == 'enterprise' ]] || [[ "$channel" == 'app-store' ]]; then
# 		channelFilterString='iPhone Distribution: '
# 		startSearchString='003U\\004\\003\\0142'
# 	else
# 		channelFilterString='iPhone Developer: '
# 		startSearchString='003U\\004\\003\\014&'
# 	fi
# 	profileTeamId=$($CMD_PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' /dev/stdin <<< $($CMD_Security cms -D -i "$provisionFile" 2>/dev/null))
# 	codeSignIdentity=$($CMD_Security dump-keychain 2>/dev/null | grep "\"subj\"<blob>=" | cut -d '=' -f 2 | grep "$profileTeamId" | awk -F "[\"\"]" '{print $2}' | grep "$channelFilterString" | sed "s/\(.*\)$startSearchString\(.*\)$endSearchString\(.*\)/\2/g" | head -n 1)
# 	echo "$codeSignIdentity"
# }

