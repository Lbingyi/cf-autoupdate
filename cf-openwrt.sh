#!/bin/bash

# --------------------------------------------------------------
#	项目: 基于better-cloudflare-ip的 N1 自动更新 IP
#	版本: 1.4.0
#	更新日期：2022-4-13
#	作者: 鸿煊
#	项目: https://github.com/Lbingyi/cf-autoupdate
#	使用说明：加在openwrt上系统--计划任务里添加定时运行，如0 9 * * * bash /mnt/mmcblk2p4/cf-openwrt/cf-openwrt.sh
#	*解释：9点0分运行一次。
#	路由上的爬墙软件节点IP全部换成路由IP，如192.168.1.1:8443，端口全部8443
#	使用前请更换自己的推送token 注册地址下下方
# --------------------------------------------------------------
version=20220208

function bettercloudflareip (){
localport=8443
remoteport=443
declare -i bandwidth
declare -i speed
pushplus=自己的token
ServerChanTurbo=自己的token
Telegrambot=自己的token
bandwidth=0
tasknum=25
if [ -z "$tasknum" ]
then
	tasknum=25
fi
if [ $tasknum -eq 0 ]
then
	echo 进程数不能为0,自动设置为默认值
	tasknum=25
fi
if [ $tasknum -gt 50 ]
then
	echo 超过最大进程限制,自动设置为最大值
	tasknum=50
fi
speed=bandwidth*128*1024
starttime=$(date +'%Y-%m-%d %H:%M:%S')
cloudflaretest
declare -i realbandwidth
realbandwidth=max/128
endtime=$(date +'%Y-%m-%d %H:%M:%S')
start_seconds=$(date --date="$starttime" +%s)
end_seconds=$(date --date="$endtime" +%s)
clear
curl --$ips --resolve service.baipiao.eu.org:443:$anycast --retry 3 -s -X POST https://service.baipiao.eu.org -o temp.txt
publicip=$(grep publicip= temp.txt | cut -f 2- -d'=')
colo=$(grep colo= temp.txt | cut -f 2- -d'=')
rm -rf temp.txt
echo $anycast>$ips.txt
echo 优选IP $anycast
echo 公网IP $publicip
echo 自治域 AS$asn
echo 运营商 $isp
echo 经纬度 $longitude,$latitude
echo 位置信息 $city,$region,$country
echo 设置带宽 $bandwidth Mbps
echo 实测带宽 $realbandwidth Mbps
echo 峰值速度 $max kB/s
echo 往返延迟 $avgms 毫秒
echo 数据中心 $colo
echo 总计用时 $((end_seconds-start_seconds)) 秒
		iptables -t nat -D OUTPUT $(iptables -t nat -nL OUTPUT --line-number | grep $localport | awk '{print $1}')
		iptables -t nat -A OUTPUT -p tcp --dport $localport -j DNAT --to-destination $anycast:$remoteport
		#echo $(date +'%Y-%m-%d %H:%M:%S') IP指向 $anycast>>/usr/dns/cfnat.txt

		curl -s -o /dev/null --data "token=$pushplus&title=$anycast更新成功！&content= 优选IP $anycast<br>公网IP $publicip<br/>自治域 AS$asn<br>运营商 $isp<br>经纬度 $longitude,$latitude<br>位置信息 $city,$region,$country<br>实测带宽 $realbandwidth Mbps<br>峰值速度 $max kB/s<br>往返延迟 $avgms 毫秒<br>数据中心 $colo<br>总计用时 $((end_seconds-start_seconds)) 秒<br>&template=html" http://www.pushplus.plus/send #微信推送最新查找的IP-pushplus推送加

#		curl -s -o /dev/null --data "title=$anycast更新成功！&desp=$(date +'%Y-%m-%d %H:%M:%S') %0D%0A%0D%0A---%0D%0A%0D%0A * 优选IP $anycast 满足 $bandwidth Mbps带宽需求 %0D%0A * 公网IP $publicip %0D%0A * 自治域 AS$asn %0D%0A * 运营商 $isp %0D%0A * 经纬度 $longitude,$latitude %0D%0A * 位置信息 $city,$region,$country %0D%0A * 实测带宽 $realbandwidth Mbps %0D%0A * 峰值速度 $max kB/s %0D%0A·往返延迟 $avgms 毫秒 %0D%0A * 数据中心 $colo %0D%0A * 总计用时 $((end_seconds-start_seconds)) 秒"  https://sctapi.ftqq.com/$ServerChanTurbo.send #微信推送最新查找的IP-Server酱·Turbo版

		curl -s -o /dev/null --data "&text=*$anycast更新成功！* %0D%0A$(date +'%Y\-%m\-%d %H:%M:%S')%0D%0A----------------------------------%0D%0A·优选IP $anycast 满足 $bandwidth Mbps带宽需求 %0D%0A·公网IP $publicip %0D%0A·自治域 AS$asn %0D%0A·运营商 $isp %0D%0A·经纬度 $longitude,$latitude %0D%0A·位置信息 $city,$region,$country %0D%0A·实测带宽 $realbandwidth Mbps %0D%0A·峰值速度 $max kB/s %0D%0A·往返延迟 $avgms 毫秒 %0D%0A·数据中心 $colo %0D%0A----------------------------------&parse_mode=Markdown" https://pb.pupilcc.app/sendMessage/$Telegrambot #Telegram推送最新查找的IP- @notification_me_bot

}

function rtt (){
declare -i avgms
declare -i getrtt
t=1
n=1
for ip in `cat rtt/$1.txt`
do
	while true
	do
		if [ $t -le 5 ]
		then
			curl --resolve www.cloudflare.com:443:$ip https://www.cloudflare.com/cdn-cgi/trace -o /dev/null -s --connect-timeout 1 -w "$ip"_%{time_connect}_"HTTP"%{http_code}"\n">>rtt/$1-$n.log
			t=$[$t+1]
		else
			getrtt=$(grep HTTP200 rtt/$1-$n.log | wc -l)
			if [ $getrtt == 0 ]
			then
				rm -rf rtt/$1-$n.log
				n=$[$n+1]
				t=1
				break
			fi
			avgms=0
			for i in `grep HTTP200 rtt/$1-$n.log | awk -F_ '{printf ("%d\n",$2*1000000)}'`
			do
				avgms=$i+avgms
			done
			avgms=(avgms/getrtt)/1000
			getrtt=5-getrtt
			if [ $avgms -lt 10 ]
			then
				echo $getrtt 00$avgms $ip>rtt/$1-$n.log
			elif [ $avgms -ge 10 ] && [ $avgms -lt 100 ]
			then
				echo $getrtt 0$avgms $ip>rtt/$1-$n.log
			else
				echo $getrtt $avgms $ip>rtt/$1-$n.log
			fi
			n=$[$n+1]
			t=1
			break
		fi
	done
done
rm -rf rtt/$1.txt
}

function speedtest (){
curl --resolve $domain:443:$1 https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
cat log.txt | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | grep -v 'k\|M' >> speed.txt
for i in `cat log.txt | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | grep k | sed 's/k//g'`
do
	declare -i k
	k=$i
	k=k*1024
	echo $k >> speed.txt
done
for i in `cat log.txt | tr '\r' '\n' | awk '{print $NF}' | sed '1,3d;$d' | grep M | sed 's/M//g'`
do
	i=$(echo | awk '{print '$i'*10 }')
	declare -i M
	M=$i
	M=M*1024*1024/10
	echo $M >> speed.txt
done
declare -i max
max=0
for i in `cat speed.txt`
do
	if [ $i -ge $max ]
	then
		max=$i
	fi
done
rm -rf log.txt speed.txt
echo $max
}

function cloudflaretest (){
while true
do
	while true
	do
		declare -i ipnum
		declare -i iplist
		declare -i n
		rm -rf rtt data.txt meta.txt log.txt anycast.txt temp.txt speed.txt
		mkdir rtt
		while true
		do
			if [ ! -f "$ips.txt" ]
			then
				echo DNS解析获取CF $ips 节点
				echo 如果域名被污染,请手动创建 $ips.txt 做解析
				while true
				do
					if [ ! -f "meta.txt" ]
					then
						curl --$ips --retry 3 -s https://service.baipiao.eu.org/meta -o meta.txt
					else
						asn=$(grep asn= meta.txt | cut -f 2- -d'=')
						isp=$(grep isp= meta.txt | cut -f 2- -d'=')
						country=$(grep country= meta.txt | cut -f 2- -d'=')
						region=$(grep region= meta.txt | cut -f 2- -d'=')
						city=$(grep city= meta.txt | cut -f 2- -d'=')
						longitude=$(grep longitude= meta.txt | cut -f 2- -d'=')
						latitude=$(grep latitude= meta.txt | cut -f 2- -d'=')
						curl --$ips --retry 3 https://service.baipiao.eu.org -o data.txt -#
						break
					fi
				done
			else
				echo 指向解析获取CF $ips 节点
				echo 如果长时间无法获取CF $ips 节点,重新运行程序并选择清空缓存
				resolveip=$(cat $ips.txt)
				while true
				do
					if [ ! -f "meta.txt" ]
					then
						curl --$ips --resolve service.baipiao.eu.org:443:$resolveip --retry 3 -s https://service.baipiao.eu.org/meta -o meta.txt
					else
						asn=$(grep asn= meta.txt | cut -f 2- -d'=')
						isp=$(grep isp= meta.txt | cut -f 2- -d'=')
						country=$(grep country= meta.txt | cut -f 2- -d'=')
						region=$(grep region= meta.txt | cut -f 2- -d'=')
						city=$(grep city= meta.txt | cut -f 2- -d'=')
						longitude=$(grep longitude= meta.txt | cut -f 2- -d'=')
						latitude=$(grep latitude= meta.txt | cut -f 2- -d'=')
						curl --$ips --resolve service.baipiao.eu.org:443:$resolveip --retry 3 https://service.baipiao.eu.org -o data.txt -#
						break
					fi
				done
			fi
			if [ -f "data.txt" ]
			then
				break
			fi
		done
		domain=$(grep domain= data.txt | cut -f 2- -d'=')
		file=$(grep file= data.txt | cut -f 2- -d'=')
		url=$(grep url= data.txt | cut -f 2- -d'=')
		app=$(grep app= data.txt | cut -f 2- -d'=')
		if [ "$app" != "$version" ]
		then
			echo 发现新版本程序: $app
			echo 更新地址: $url
			echo 更新后才可以使用
			exit
		fi
		if [ $selfmode == 1 ]
		then
			rm -rf data.txt
			n=0
			while true
			do
				if [ $n == 256 ]
				then
					break
				else
					echo $selfip.$n>>anycast.txt
					n=n+1
				fi
			done
		else
			for i in `cat data.txt | sed '1,4d'`
			do
				echo $i>>anycast.txt
			done
		fi
		rm -rf meta.txt data.txt
		ipnum=$(cat anycast.txt | wc -l)
		if [ $ipnum -lt $tasknum ]
		then
			tasknum=ipnum
		fi
		iplist=ipnum/tasknum
		declare -i a=1
		declare -i b=1
		for i in `cat anycast.txt`
		do
			echo $i>>rtt/$b.txt
			if [ $a == $iplist ]
			then
				a=1
				b=b+1
			else
				a=a+1
			fi
		done
		rm -rf anycast.txt
		if [ $a != 1 ]
		then
			a=1
			b=b+1
		fi
		while true
		do
			if [ $a == $b ]
			then
				break
			else
				rtt $a &
			fi
			a=a+1
		done
		while true
		do
			sleep 2
			n=$(ls rtt | grep txt | grep -v "grep" | wc -l)
			if [ $n -ne 0 ]
			then
				echo 等待RTT测试结束,剩余进程数 $n
			else
				echo RTT测试完成
				break
			fi
		done
		n=$(ls rtt | wc -l)
		if [ $n -ge 5 ]
		then
			cat rtt/*.log | sort | awk '{print $2"_"$3}'>ip.txt
			echo 待测速的IP地址
			echo $(sed -n '1p' ip.txt | awk -F_ '{print "第1个IP "$2" 往返延迟 "$1" 毫秒"}')
			echo $(sed -n '2p' ip.txt | awk -F_ '{print "第2个IP "$2" 往返延迟 "$1" 毫秒"}')
			echo $(sed -n '3p' ip.txt | awk -F_ '{print "第3个IP "$2" 往返延迟 "$1" 毫秒"}')
			echo $(sed -n '4p' ip.txt | awk -F_ '{print "第4个IP "$2" 往返延迟 "$1" 毫秒"}')
			echo $(sed -n '5p' ip.txt | awk -F_ '{print "第5个IP "$2" 往返延迟 "$1" 毫秒"}')
			n=0
			for ip in `cat ip.txt`
			do
				if [ $n == 5 ]
				then
					echo 没有满足速度要求的IP
					break
				else
					n=n+1
				fi
				avgms=$(echo $ip | awk -F_ '{print $1}')
				ip=$(echo $ip | awk -F_ '{print $2}')
				echo 正在测试 $ip
				max=$(speedtest $ip)
				if [ $max -ge $speed ]
				then
					anycast=$ip
					max=$[$max/1024]
					echo $ip 峰值速度 $max kB/s
					break
				else
				max=$[$max/1024]
				echo $ip 峰值速度 $max kB/s
				fi
			done
			rm -rf rtt ip.txt
			if [ $n != 5 ]
			then
				break
			fi
		else
			echo 当前所有IP都存在RTT丢包
			tasknum=10
		fi
	done
		break
done
}

function singletest (){
read -p "请输入需要测速的IP: " testip
curl --resolve service.baipiao.eu.org:443:$testip https://service.baipiao.eu.org -o temp.txt -#
domain=$(grep domain= temp.txt | cut -f 2- -d'=')
file=$(grep file= temp.txt | cut -f 2- -d'=')
rm -rf temp.txt
curl --resolve $domain:443:$testip https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 15
}


while true
do
	clear
	#echo 1. IPV4优选
	#echo 2. IPV6优选
	#echo 3. 自定义IPV4段
	#echo 4. 单IP测速
	#echo 5. 清空缓存
	#echo 0. 退出
	#read -p "请选择菜单: " menu
	menu=1
	if [ $menu == 0 ]
	then
		clear
		echo 退出成功
		break
	fi
	if [ $menu == 1 ]
	then
		rm -rf ipv4.txt ipv6.txt rtt data.txt meta.txt log.txt anycast.txt temp.txt speed.txt
		ips=ipv4
		selfmode=0
		bettercloudflareip
		break
	fi
	if [ $menu == 2 ]
	then
		ips=ipv6
		selfmode=0
		bettercloudflareip
		break
	fi
	if [ $menu == 3 ]
	then
		ips=ipv4
		selfmode=1
		read -p "请输入C类自定义IPV4(格式 104.16.16):" selfip
		bettercloudflareip
		break
	fi
	if [ $menu == 4 ]
	then
		singletest
		clear
		echo 测速完毕
	fi
	if [ $menu == 5 ]
	then
		rm -rf ipv4.txt ipv6.txt rtt data.txt meta.txt log.txt anycast.txt temp.txt speed.txt
		clear
		echo 缓存已经清空
	fi
done
