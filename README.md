## 用ssh连接软件连接opewrt
```Bash
cd /usr
mkdir dns
cd dns
wget https://raw.githubusercontent.com/Lbingyi/cf-autoupdate/cf-openwrt.sh
wget https://raw.githubusercontent.com/Lbingyi/cf-autoupdate/kill-cf-openwrt.sh 
```
修改cf-openwrt.sh中的两处地方，一处是带宽选择，一处是微信推送token
