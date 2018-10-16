---
layout: "post"
title: "readme"
date: "2018-09-30"
---
AutoPackingShell
==

`AutoPackingShell` 一个轻量级 iOS 快速自动打包工具。

## 安装使用

```


sudo apachectl start/restart   #启动apache
sudo apachectl stop            #停止apache
```
### mac下phalcon安装与配置
```
https://blog.csdn.net/feinifi/article/details/75579100

git clone git://github.com/phalcon/cphalcon.git
cd cphalcon/build
sudo ./install

安装phalcon
进入目录~/Lib/php,并执行以下命令

git clone git://github.com/phalcon/cphalcon.git
cd cphalcon/build
sudo ./install

安装之后在php.ini 中添加:
php.ini文件默认是没有的，但是php.ini.default文件是有的，在/etc目录下，可以拷贝php.ini.default文件为php.ini,然后配置。
extension=phalcon.so
```

```
/etc/apache2/httpd.conf

将Include /private/etc/apache2/extra/httpd-vhosts.conf这行前的注释符号＃去掉
编辑httpd-vhosts.conf文件，输入命令： 
vim /etc/apache/extra/httpd-vhosts.conf

如何在Macbook上配置Apache虚拟主机 
在httpd-vhosts.conf 中添加以下内容：

<VirtualHost *:80>
    DocumentRoot "/Users/liboy/Sites/apiapppack/webroot"
    ServerName ios.pack.com
</VirtualHost>

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

重启Apache，输入命令： 
apachectl restart

/etc/hosts
添加如下内容： 
127.0.0.1 ios.pack.com


mac自带apache和php，对环境配置来说，相对友好很多； 
系统自带php文件位置： /etc/php.ini.default 
应当拷贝一份，命名为php.ini再修改内部文件；

homebrew所安装的php文件，位置：/usr/local/etc/php/下；


# ************* 安装Blade ************* 
# https://github.vimcom/jondot/blade
# blade --help 查看命令
# -s Icon( *注意：1024*1024,无alph,png格式)
# -t AppIcon.appiconset里的Contents.json文件
# -o 输出路径 AppIcon.appiconset
# -c 覆盖旧的Contents.json文件


# You-Get是一个小型命令行实用程序，用于从Web下载媒体内容（视频，音频，图像），以防没有其他方便的方法。
# Github 项目：https://github.com/soimort/you-get


# 该脚本使用方法
# step 1. 配置该脚本;
# step 2. cd 该脚本目录，运行chmod +x AutoPackingShell.sh;
# step 3. 终端运行 sh AutoPackingShell.sh;
# step 4. 选择不同选项....
# step 5. Success  🎉 🎉 🎉!
```

