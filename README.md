
LBAutoPackingShell
==

`LBAutoPackingShell` 一个轻量级 iOS 快速自动打包工具。


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

## 配置PHP运行环境
https://getgrav.org/blog/macos-mojave-apache-multiple-php-versions

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
- 使用`php－m|grep phalcon` 命令，查看刚添加的`phalcon`扩展是否成功 

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
ln -s /usr/local/Cellar/php@5.6/5.6.38/sbin/php-fpm  /usr/local/bin/php
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


