## 用ssh连接软件连接opewrt
```Bash
cd /usr
创建dns目录
mkdir dns
进入目录
cd dns
下载优选ip文件
wget https://raw.githubusercontent.com/wxfyes/cf/main/cf-openwrt.sh
下载杀进程文件
wget https://raw.githubusercontent.com/wxfyes/cf/main/kill-cf-openwrt.sh 
```
修改cf-openwrt.sh中的两处地方，一处是带宽选择，一处是微信推送token
