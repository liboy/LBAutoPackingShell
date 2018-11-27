
# LBAutoPackingShell

`LBAutoPackingShell` 一个轻量级 iOS 快速自动打包工具。如果你需要更多的功能，详见帮助`-h | --help` 

## 功能

- <font color=#006400 size=3>自动匹配最新的描述文件(Provisioning Profile)</font>
- <font color=#006400 size=3>自动匹配签名身份(Code Signing Identity)</font>
- 支持`--show-profile-detail provisionfile` 查看授权文件类型、创建日期、过期日期、使用证书签名ID、使用证书的创建日期等
- 允许指定授权文件目录,脚本将只在该目录匹配授权文件
- 支持Xcode8.3.3以上
- 支持ipa签名方式：development、app-store、enterprise，ad-hoc，即内部分发、商店分发、企业分发、企业内部分发
- 支持workplace、cocoapod
- 支持多工程协同项目使用`-t targetName` 指定构建target
- 自动关闭BitCode，并可配置开关
- 支持可选构建架构集合，默认构建"armv7 arm64"
- 可配置自动修改内部版本号(Build Version)
- 可配置修改接口生产环境和开发环境
- 可配置指定新的Bundle Id
- 可配置指定构建Debug、Release模式
- 可指定构建的Architcture(arm64、armv7)
- 自动格式化IPA名称，例如:

 ```
 MyApp_20170321_222303_开发环境_企业分发_2.1.0(67).ipa
 MyApp_20170321_222403_生产环境_商店分发_2.1.0(68).ipa`
 ```
- 自动校验ipa签名
- 格式化日志输出

### 常用IPA分发途径：
```
- 内部测试(development)：用于给我们内部人员测试使用的，指定的授权用户设备才可以通过使用“同步助手”、“APP助手”等工具安装
- 商店分发(app-store)：用于提交到商店审核，用户设备只能通过在App Store下载安装
- 企业分发(enterprise)：用于部署到服务器，所有用户设备都可通过扫描二维码或使用浏览器点击链接下载安装
- 企业内部分发(ad-hoc)：用于部署到服务器，授权用户设备才可以通过扫描二维码或使用浏览器点击链接下载安装
```
## 安装使用
```
# 该脚本使用方法
# step 1. 配置该脚本;
# step 2. cd 该脚本目录，运行chmod +x AutoPackingShell.sh;
# step 3. 终端运行 sh AutoPackingShell.sh;
# step 4. 选择不同选项....
# step 5. Success  🎉 🎉 🎉!
```
## 安装脚本所需工具
### 安装 [Homebrew](https://brew.sh/index_zh-cn)
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
确保正确配置所有内容
```
$ brew doctor
```
### XCode命令行工具
```
$ xcode-select --install
```
### 安装 [jq](https://stedolan.github.io/jq/download/)
在Shell命令行处理JSON数据

```
brew install jq
```

### 安装 [You-Get](https://github.com/soimort/you-get)
`You-Get`是一个小型命令行实用程序，用于从Web下载媒体内容（视频，音频，图像），以防没有其他方便的方法。

```
brew install you-get
```
### 安装 [Blade](https://github.com/jondot/blade)
生成iOS应用程序图标Icon到Xcode图像目录

```
 brew tap jondot/tap
 brew install blade
```
```
# blade --help 查看命令
# -s Icon( *注意：1024*1024,无alph,png格式)
# -t AppIcon.appiconset里的Contents.json文件
# -o 输出路径 AppIcon.appiconset
# -c 覆盖旧的Contents.json文件
```
### 安装xcpretty（可选）
用来格式化xcodebuild输出日志，建议安装

```
sudo gem install xcpretty
```

### OpenSSL版本
一个安全套接字层密码库，囊括主要的密码算法、常用的密钥和证书封装管理功能及SSL协议，并提供丰富的应用程序供测试或其它目的使用。

- 使用最新的openssl命令，方便研究SSL协议、数字证书。

如果你的openssl是 `LibreSSL` 查看[Mac安装新版OpenSSL问题](https://www.jianshu.com/p/32f068922baf)
更新前

```
$ openssl version
LibreSSL 2.2.7

$ which openssl
/usr/bin/openssl
```
更新后

```
$ openssl version
OpenSSL 1.0.2j 26 Sep 2016

$ which openssl
/usr/local/bin/openssl
```
如果更新之后还是没有显示正确的openssl，是因为系统存在两个openssl，可通过设置系统环境变量PATH来优先执行。

```
echo 'export PATH="/usr/local/Cellar/openssl/1.0.2p/bin/:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
```
或软连接

```
ln -s /usr/local/Cellar/openssl/1.0.2p/bin/openssl /usr/local/bin
```
>注意：`/usr/local/Cellar/openssl/1.0.2p/bin/` 该路径请按照你实际情况来更改,通常是1.0.2p这个文件夹不同！

### user_config.plist 文件说明

执行脚本时，要指定一些些固定的参数，需要在`user_config.plist`文件中配置这些参数：

```
//脚本全局参数配置文件(脚本参数优先于全局配置参数)

//keychain解锁密码，即PC开机密码。通常只有在第一次执行脚本时候需要。相当于脚本参数 -p | --keychain-password
UNLOCK_KEYCHAIN_PWD =

//构建模式：Debug/Release ；默认 Release。相当于脚本参数 -t | --configration-type
CONFIGRATION_TYPE=

```

## 配置PHP运行环境

### 环境要求

- PHP5.6
- Apache2.4

```
apachectl -v && php -v

Server version: Apache/2.4.35 (Unix)
Server built:   Sep 24 2018 01:07:08
PHP 5.6.38 (cli) (built: Sep 14 2018 22:31:05) 
Copyright (c) 1997-2016 The PHP Group
Zend Engine v2.6.0, Copyright (c) 1998-2016 Zend Technologies
```

### Apache 2.4
浏览器中访问服务器 http://localhost:8080

关闭内置Apache，并删除所有自动加载脚本。

```
$ sudo apachectl stop
$ sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
```
安装

```
$ brew install httpd
```
Apache服务器自动启动

```
$ sudo brew services start httpd
```
检查服务器已启动,如果Apache启动并运行，应该会看到一些httpd进程。

```
$ ps -aef | grep httpd
```

查看Apache错误日志

```
$ tail -f /usr/local/var/log/httpd/error_log
```

重启Apache常用命令

```
#启动apache
sudo apachectl start/restart   
#停止apache
sudo apachectl stop  
#立即强制重启
$ sudo apachectl -k restart
```
> 该 `-k`将立即强制重启，而不是在apache良好并准备就绪时重新启动

#### Apache配置
1. 编辑Apache的配置文件`/usr/local/etc/httpd/httpd.conf`手动设置默认端口 `Listen 8080` 为 `Listen 80`
2. Apache默认根目录`DocumentRoot "/usr/local/var/www"`为`DocumentRoot /Users/your_user/Sites`和`<Directory /Users/your_user/Sites>`
3. 更改`AllowOverride None` 为 `AllowOverride All`
4. 取消注释该行 
```
LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
```
5. 用户和组（替换`your_user` 用你的真实用户名
```
User your_user
Group staff
```
6. 服务器名称`#ServerName www.example.com:8080`替换为：`ServerName localhost`

#### 测试Apache
`Sites`站点文件夹

```
$ mkdir ~/Sites
$ echo "<h1>My User Web Root</h1>" > ~/Sites/index.html
```
重启apache以确保配置更改生效,并浏览器访问：http://localhost:80

### 安装PHP5.6
> 由于`Homebrew/php`tap在[2018年3月底被弃用](https://github.com/Homebrew/homebrew-php/issues/4721)
> 如果通过旧版Brew安装了PHP，则需要升级Homebrew清理设置

#### 升级Homebrew清理设置
如果您通过Brew安装了现有的PHP，则需要先使用我们的升级Homebrew指南清理您的设置
更新 Homebrew 

```
# 获取最新的包的列表，首先得更新 Homebrew 自己
brew update
# 更新所有的包
brew upgrade
# 清理所有包的旧版本 
brew cleanup
```
检查当前安装的PHP包

```
brew list | grep php
```
卸载php版本：

```
$ brew uninstall --force php56 php56-apcu php56-opcache php56-xdebug php56-yaml
$ brew uninstall --force php70 php70-apcu php70-opcache php70-xdebug php70-yaml
$ brew cleanup
```
清除PHP的旧配置选项

```
$ rm -Rf /usr/local/etc/php/*
```
#### PHP安装
```
$ brew install php@5.6
$ brew install php@7.0
```
- PHP的配置-内存设置

```
/usr/local/etc/php/5.6/php.ini
date.timezone = PRC
```
- 切换PHP版本

```
$ brew unlink php@7.2 && brew link --force --overwrite php@5.6
```


- 查看安装版本
>强烈推荐:此时建议关闭所有终端选项卡和窗口。打开一个新的终端继续下一步。否则可能会出现一些非常奇怪的路径问题。。。

```
php -v

PHP 5.6.38 (cli) (built: Sep 14 2018 22:31:05) 
Copyright (c) 1997-2016 The PHP Group
Zend Engine v2.6.0, Copyright (c) 1998-2016 Zend Technologies
```

#### 配置Apache
在`/usr/local/etc/httpd/httpd.conf`文件中

```
LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
# 在此一下添加以下内容
LoadModule php5_module /usr/local/opt/php@5.6/lib/httpd/modules/libphp5.so
#LoadModule php7_module /usr/local/opt/php@7.0/lib/httpd/modules/libphp7.so
```
此外，必须显式设置PHP的目录索引：

```
<IfModule dir_module>
    DirectoryIndex index.html
</IfModule>
# 替换为：
<IfModule dir_module>
    DirectoryIndex index.php index.html
</IfModule>

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
```
#### 验证PHP安装
在 `Sites`目录下创建一个`info.php`文件，将浏览器指向 `http://localhost/info.php`
如果看到phpinfo结果，恭喜！您现在已成功运行`Apache`和`PHP`


#### 安装PHP框架phalcon
php语言中高性能的mvc框架

```
git clone git://github.com/phalcon/cphalcon.git
cd cphalcon/build
sudo ./install
```
- 配置

```
# 在php.ini 中添加
extension=phalcon.so
```
- 重启服务器`sudo apachectl restart`
- 使用`php -m|grep phalcon` 命令，查看刚添加的`phalcon`扩展是否成功 

> 注意：Mac系统自带`php.ini`在`/etc`目录下默认没有，可以拷贝`php.ini.default`为`php.ini`配置。


### 配置Apache虚拟主机 
将 `httpd.conf` 中这行前的注释符号＃去掉

```
Include /private/etc/apache2/extra/httpd-vhosts.conf
```

在 `httpd-vhosts.conf` 中添加：

```
<VirtualHost *:80>
    DocumentRoot "/Users/liboy/Sites/apiapppack/webroot"
    ServerName ios.pack.com
</VirtualHost>
```
在`/etc/hosts`添加

```
127.0.0.1 ios.pack.com
```

### 常用路径记录
```
# 系统自带apache
/etc/apache2/httpd.conf
/private/etc/apache2/extra/httpd-vhosts.conf

# brew安装apache
/usr/local/etc/httpd/httpd.conf
/usr/local/etc/httpd/extra/httpd-vhosts.conf
```

```
mkdir -p ~/Library/LaunchAgents    
#加入开机自启
cp /usr/local/opt/php@5.6/homebrew.mxcl.php@5.6.plist ~/Library/LaunchAgents/launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.php56.plist
```

```
软连接：
ln -s /usr/local/Cellar/php@5.6/5.6.38/bin/php  /usr/local/bin/php
ln -s /usr/local/Cellar/php@5.6/5.6.38/sbin/php-fpm  /usr/local/sbin/php-fpm
```
```
<VirtualHost *:80>
    ServerAdmin webmaster@xiaohua.com
    DocumentRoot "/Users/yournameDev/xiaohua.com"
    ServerName xiaohua.com
    ErrorLog "/Users/yourname/Dev/xiaohua.com/error_log"
    CustomLog "/Users/yourname/Dev/xiaohua.com/access_log" common
    <Directory "/Users/yourname/Dev/xiaohua.com">
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Require all granted
    </Directory>
</VirtualHost>
```


## 签名相关命令

允许 `codesign` 访问您的钥匙串中的密钥

```
security import /Users/xiaohe/Downloads/haina_dev.p12 -k ~/Library/Keychains/login.keychain -P 1 -T /usr/bin/codesign
security import /tmp/tmp.cer -k ~/Library/Keychains/login.keychain -P p12password -T /usr/bin/codesign
security import /tmp/tmp.cer -k ~/Library/Keychains/login.keychain -T /usr/bin/codesign
security delete-certificate -c "iPhone Developer: Yumei Xing (9X7JK3J2YZ)" -t ~/Library/Keychains/login.keychain
```
从`mobileprovision`文件中生成一个完整的plist文件

```
security cms -D -i "/Users/liboy/Desktop/自动打包/LBAutoPackingShell/MobileProvision/xiaolundun_development.mobileprovision" > "/Users/liboy/Desktop/MobileProvision.plist"
```
以XML格式查看描述文件的命令：

```
security cms -D -i "/Users/liboy/Desktop/自动打包/LBAutoPackingShell/MobileProvision/xiaolundun_development.mobileprovision"
```
开发者证书被包含在`Provisioning Profile`文件中DeveloperCertificates选项里面，所有的证书都是基于 Base64 编码符合 PEM (Privacy Enhanced Mail, RFC 1848) 格式的。

```
security cms -D -i "/Users/liboy/Desktop/自动打包/LBAutoPackingShell/MobileProvision/xiaolundun_development.mobileprovision" | grep data | head -n 1 | sed 's/.*<data>//g' | sed 's/<\/data>.*//g'
```
提取`DeveloperCertificates/<data></data>` 之间的内容复制粘贴到一个文件中去，像下面这样：

```
-----BEGIN CERTIFICATE-----
MIIFnjCCBIagAwIBAgIIE/IgVItTuH4wDQYJKoZIhvcNAQEFBQAwgZYxCzA…
-----END CERTIFICATE-----`
```
然后使用 `openssl x509 -text -in file.pem` 来显示证书详细内容。


查找xcworkspace工程启动文件,获取xcproj 工程列表

```
grep "location =" "/Users/liboy/Desktop/PackageLog/Offline/iXiao_build/iXiao.xcworkspace/contents.xcworkspacedata" | cut -d "\"" -f2 | cut -d ":" -f2
```
## 问题
1. xcode的bug打包的时候：会报 archived-expanded-entitlements.xcent  文件缺失!
链接：http://stackoverflow.com/questions/28589653/mac-os-x-build-server-missing-archived-expanded-entitlements-xcent-file-in-ipa
发现在 xcode >= 8.3.3 以上都不存在 ,在xcode8.2.1 存在

```
# ## 修复8.3 以下版本的xcent文件
# xcentFile=$(repairXcentFile "$exportPath" "$archivePath")
# if [[ "$xcentFile" ]]; then
#   logit "【xcent 文件修复】拷贝archived-expanded-entitlements.xcent 到${xcentFile}"
# fi

function repairXcentFile()
{

    local exportPath=$1
    local archivePath=$2

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
```
## 版本更新日志

```
# 2018/09/30
#
# 版本：1.0.0
# 功能：
#   1.显示Build Settings 签名配置
#   2.获取git版本数量，并自动更改build号为版本数量号
#   3.日志文本log.txt输出
#   4.自动匹配签名和授权文件
#   5.支持workplace、多个scheme
#   6.校验构建后的ipa的bundle Id、签名、支持最低iOS版本、arm体系等等
#   7.构建前清理缓存,防止xib更改没有被重新编译
#   8.备份历史打包ipa以及log.txt
#   9.可更改OC代码，自动配置服务器测试环境or生产环境
#   10.格式化输出ipa包名称：name_time_开发环境_企业分发_1.0.0(168).ipa

# 2. 更改默认构建架构集为“armv7 arm64” 

# 1. 增加-t参数指定构建的Target
# 2. 优化一些日志输出
# 3. 使用--debug 参数代替-t | --config-type参数 来指定Debug或Release模式，详见 AutoPackingShell -h
#--------------------------------------------
# 1. 增加支持ad-hoc打包格式
# 2. 增加-v参数输出详细的构建信息
# 3. 增加--show-profile-detail provisionfile 参数查看授权文件内容
# 4. 修复无法匹配证书签名ID带有多个连续空格的bug
# 2. 使用xcodeproj工具代替PlistBuddy来修改project.pbxproj文件，防止项目中文乱码和project.pbxproj文件格式发生变化
# 3. 增加岁OpenSSL的检查校验
# 1. 自动匹配授权文件和签名（移除config.plist配置）
# 2. 优化授权文件匹配算法，取有效期最长授权文件
# 3. 调整脚本参数,详见-h
# 4. 优化代码
# 5. 兼容长参数
# 6. 增加全局配置文件user.xcconfig


# 1. 移除使用xcodepro（xceditor.rb）,使用xcodebuild 的`-xcconfig `参数来实现签名等配置修改
# 2. 保持工程配置(project.pbxproj)文件不被修改

# 1. 优化build函数代码。
# 2. 增加xcpretty 来格式化日志输出
# 3. 支持xcode9（8.0~9.3）

# 1. 增加一个“修改Bundle Id”功能。如-b com.xxx.xx。

# 优化：默认构建ipa支持armch 为 arm64。（因iOS 11强制禁用32位）

# 优化：对授权文件mobiprovision有效期检测，授权文件有效期小于90天，强制打包失败！

# 优化：兼容xcode8.3以上版本
# xcode 8.3之后使用-exportFormat导出IPA会报错 xcodebuild: error: invalid option '-exportFormat',改成使用-exportOptionsPlist
# Available options: app-store, ad-hoc, package, enterprise, development, and developer-id.
# 当前用到：app-store ,ad-hoc, enterprise, development
#
#--------------------------------------------
#		为了节省打包时间，在打开发环境的包时，只打armv7
#		profileType==development 时，设置archs=armv7 （向下兼容） ，否则archs为默认值：arm64 和armv7。
：
#		1.去掉可配置签名、授权文件，并修改为自动匹配签名和授权文件！
#
#--------------------------------------------


# 备注：
#		1.security 命令会报警告,忽略即可:security: SecPolicySetValue: One or more parameters passed to a function were not valid.
#		2.支持Xcode8.0及以上版本（8.0前没有测试过）


```

## 参考
https://getgrav.org/blog/macos-mojave-apache-multiple-php-versions
https://www.cnblogs.com/wangyang1213/p/5209119.html
[代码签名探析](https://objccn.io/issue-17-2/)

Mac升级bash到最新版本
https://blog.csdn.net/pz0605/article/details/51954868
https://www.cnblogs.com/litifeng/p/8448019.html


https://github.com/CocoaPods/CocoaPods/pull/6964

