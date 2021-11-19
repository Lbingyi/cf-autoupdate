#!/bin/bash

# --------------------------------------------------------------
#	项目: 基于better-cloudflare-ip的 N1 自动更新 IP
#	版本: 1.2.0
#	作者: 鸿煊
#	项目: https://github.com/Lbingyi/cf-autoupdate
#	使用说明：加在openwrt上系统--计划任务里添加定时运行，如0 9 * * * bash /usr/dns/cf-openwrt.sh
#	*解释：9点0分运行一次。
#	路由上的爬墙软件节点IP全部换成路由IP，如192.168.1.1:8443，端口全部8443
#	使用前请更换自己的推送token 注册地址下下方
# --------------------------------------------------------------

localport=8443
remoteport=443

declare -i bandwidth
declare -i speed
pushplus=自己的token
ServerChan=自己的token
ServerChanTurbo=自己的token
Telegrambot=自己的token
bandwidth=100
speed=bandwidth*128*1024
starttime=`date +'%Y-%m-%d %H:%M:%S'`
while true
do
	while true
	do
		rm -rf temp ip.txt data.txt meta.txt log.txt temp.txt speed.txt
		while true
		do
			if [ -f "resolve.txt" ]
			then
				echo 指向解析获取CF节点IP
				resolveip=$(cat resolve.txt)
				while true
				do
					if [ ! -f "meta.txt" ]
					then
						curl --ipv4 --resolve speed.cloudflare.com:443:$resolveip --retry 3 -s https://speed.cloudflare.com/meta | sed -e 's/{//g' -e 's/}//g' -e 's/"//g' -e 's/,/\n/g'>meta.txt
					else
						asn=$(cat meta.txt | grep asn: | awk -F: '{print $2}')
						city=$(cat meta.txt | grep city: | awk -F: '{print $2}')
						latitude=$(cat meta.txt | grep latitude: | awk -F: '{print $2}')
						longitude=$(cat meta.txt | grep longitude: | awk -F: '{print $2}')
						curl --ipv4 --resolve service.udpfile.com:443:$resolveip --retry 3 "https://service.udpfile.com?asn="$asn"&city="$city"" -o data.txt -#
						break
					fi
				done
			else
				echo DNS解析获取CF节点IP
				while true
				do
					if [ ! -f "meta.txt" ]
					then
						curl --ipv4 --retry 3 -s https://speed.cloudflare.com/meta | sed -e 's/{//g' -e 's/}//g' -e 's/"//g' -e 's/,/\n/g'>meta.txt
					else
						asn=$(cat meta.txt | grep asn: | awk -F: '{print $2}')
						city=$(cat meta.txt | grep city: | awk -F: '{print $2}')
						latitude=$(cat meta.txt | grep latitude: | awk -F: '{print $2}')
						longitude=$(cat meta.txt | grep longitude: | awk -F: '{print $2}')
						curl --ipv4 --retry 3 "https://service.udpfile.com?asn="$asn"&city="$city"" -o data.txt -#
						break
					fi
				done
			fi
			if [ -f "data.txt" ]
			then
				break
			fi
		done
		domain=$(cat data.txt | grep domain= | cut -f 2- -d'=')
		file=$(cat data.txt | grep file= | cut -f 2- -d'=')
		url=$(cat data.txt | grep url= | cut -f 2- -d'=')
		app=$(cat data.txt | grep app= | cut -f 2- -d'=')
		if [ "$app" != "20210903" ]
		then
			echo 发现新版本程序: $app
			echo 更新地址: $url
			echo 更新后才可以使用
			exit
		fi
		for i in `cat data.txt | sed '1,4d'`
		do
			echo $i>>ip.txt
		done
		rm -rf meta.txt data.txt
		./fping -f ip.txt -c 20 -i 0 > fping.txt
		sort -t/ -n -k 5 -k 8 fping.txt | cut -f 1 -d: | sed '21,$d' > ip.txt
		rm -rf fping.txt
		echo 选取20个丢包率最少的IP地址下载测速
		mkdir temp
		for i in `cat ip.txt`
		do
			echo $i 启动测速
			curl --resolve $domain:443:$i https://$domain/$file -o temp/$i -s --connect-timeout 2 --max-time 10&
		done
		echo 等待测速进程结束,筛选出三个优选的IP
		sleep 15
		echo 测速完成
		ls -S temp > ip.txt
		rm -rf temp
		declare -i n
		n=$(wc -l ip.txt | awk '{print $1}')
		if [ $n -ge 3 ]; then
			first=$(sed -n '1p' ip.txt)
			second=$(sed -n '2p' ip.txt)
			third=$(sed -n '3p' ip.txt)
			rm -rf ip.txt
			echo 优选的IP地址为 $first - $second - $third
			echo 第一次测试 $first
			curl --resolve $domain:443:$first https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max1
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$first
				break
			fi
			max=$[$max/1024]
			max1=max
			echo 峰值速度 $max kB/s
			echo 第二次测试 $first
			curl --resolve $domain:443:$first https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max2
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$first
				break
			fi
			max=$[$max/1024]
			max2=max
			echo 峰值速度 $max kB/s
			if [ $max1 -ge $max2 ]
			then
				curl --ipv4 --resolve service.udpfile.com:443:$first --retry 3 -s -X POST -d ''20210903-$first-$max1'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			else
				curl --ipv4 --resolve service.udpfile.com:443:$first --retry 3 -s -X POST -d ''20210903-$first-$max2'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			fi
			echo 第一次测试 $second
			curl --resolve $domain:443:$second https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max1
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$second
				break
			fi
			max=$[$max/1024]
			max1=max
			echo 峰值速度 $max kB/s
			echo 第二次测试 $second
			curl --resolve $domain:443:$second https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max2
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$second
				break
			fi
			max=$[$max/1024]
			max2=max
			echo 峰值速度 $max kB/s
			if [ $max1 -ge $max2 ]
			then
				curl --ipv4 --resolve service.udpfile.com:443:$second --retry 3 -s -X POST -d ''20210903-$second-$max1'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			else
				curl --ipv4 --resolve service.udpfile.com:443:$second --retry 3 -s -X POST -d ''20210903-$second-$max2'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			fi
			echo 第一次测试 $third
			curl --resolve $domain:443:$third https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max1
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$third
				break
			fi
			max=$[$max/1024]
			max1=max
			echo 峰值速度 $max kB/s
			echo 第二次测试 $third
			curl --resolve $domain:443:$third https://$domain/$file -o /dev/null --connect-timeout 5 --max-time 10 > log.txt 2>&1
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
			declare -i max2
			max=0
			for i in `cat speed.txt`
			do
				if [ $i -ge $max ]; then
					max=$i
				fi
			done
			rm -rf log.txt speed.txt
			if [ $max -ge $speed ]; then
				anycast=$third
				break
			fi
			max=$[$max/1024]
			max2=max
			echo 峰值速度 $max kB/s
			if [ $max1 -ge $max2 ]
			then
				curl --ipv4 --resolve service.udpfile.com:443:$third --retry 3 -s -X POST -d ''20210903-$third-$max1'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			else
				curl --ipv4 --resolve service.udpfile.com:443:$third --retry 3 -s -X POST -d ''20210903-$third-$max2'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o /dev/null --connect-timeout 5 --max-time 10
			fi
		fi
	done
		break
done
	max=$[$max/1024]
	declare -i realbandwidth
	realbandwidth=max/128
	endtime=`date +'%Y-%m-%d %H:%M:%S'`
	start_seconds=$(date --date="$starttime" +%s)
	end_seconds=$(date --date="$endtime" +%s)
	clear
	curl --ipv4 --resolve service.udpfile.com:443:$anycast --retry 3 -s -X POST -d ''20210903-$anycast-$max'' "https://service.udpfile.com?asn="$asn"&city="$city"" -o temp.txt
	publicip=$(cat temp.txt | grep publicip= | cut -f 2- -d'=')
	colo=$(cat temp.txt | grep colo= | cut -f 2- -d'=')
	rm -rf temp.txt
	echo 优选IP $anycast 满足 $bandwidth Mbps带宽需求
	echo 公网IP $publicip
	echo 自治域 AS$asn
	echo 经纬度 $longitude,$latitude
	echo META城市 $city
	echo 实测带宽 $realbandwidth Mbps
	echo 峰值速度 $max kB/s
	echo 数据中心 $colo
	echo 总计用时 $((end_seconds-start_seconds)) 秒
		iptables -t nat -D OUTPUT $(iptables -t nat -nL OUTPUT --line-number | grep $localport | awk '{print $1}')
		iptables -t nat -A OUTPUT -p tcp --dport $localport -j DNAT --to-destination $anycast:$remoteport
		echo $(date +'%Y-%m-%d %H:%M:%S') IP指向 $anycast>>/root/dns/cfnat.txt
                     
		curl -s -o /dev/null --data "token=$pushplus&title=$anycast更新成功！&content= 优选IP $anycast 满足 $bandwidth Mbps带宽需求<br>公网IP $publicip<br/>自治域 AS$asn<br>经纬度 $longitude,$latitude<br>META城市 $city<br>实测带宽 $realbandwidth Mbps<br>峰值速度 $max kB/s<br>数据中心 $colo<br>总计用时 $((end_seconds-start_seconds)) 秒<br>&template=html" http://www.pushplus.plus/send #微信推送最新查找的IP-pushplus推送加
		
#		curl -s -o /dev/null --data "text=$anycast更新成功！&desp=$(date +'%Y-%m-%d %H:%M:%S') %0D%0A%0D%0A---%0D%0A%0D%0A * 优选IP $anycast 满足 $bandwidth Mbps带宽需求 %0D%0A * 公网IP $publicip%0D%0A * 自治域 AS$asn %0D%0A * 经纬度 $longitude,$latitude %0D%0A * META城市 $city %0D%0A * 实测带宽 $realbandwidth Mbps %0D%0A * 峰值速度 $max kB/s %0D%0A * 数据中心 $colo %0D%0A * 总计用时 $((end_seconds-start_seconds)) 秒" https://sc.ftqq.com/$ServerChan.send #微信推送最新查找的IP-Server酱

#		curl -s -o /dev/null --data "title=$anycast更新成功！&desp=$(date +'%Y-%m-%d %H:%M:%S') %0D%0A%0D%0A---%0D%0A%0D%0A * 优选IP $anycast 满足 $bandwidth Mbps带宽需求 %0D%0A * 公网IP $publicip%0D%0A * 自治域 AS$asn %0D%0A * 经纬度 $longitude,$latitude %0D%0A * META城市 $city %0D%0A * 实测带宽 $realbandwidth Mbps %0D%0A * 峰值速度 $max kB/s %0D%0A * 数据中心 $colo %0D%0A * 总计用时 $((end_seconds-start_seconds)) 秒"  https://sctapi.ftqq.com/$ServerChanTurbo.send #微信推送最新查找的IP-Server酱·Turbo版

#		curl -s -o /dev/null --data "&text=*$anycast更新成功！* %0D%0A$(date +'%Y\-%m\-%d %H:%M:%S')%0D%0A----------------------------------%0D%0A·优选IP $anycast 满足 $bandwidth Mbps带宽需求 %0D%0A·公网IP $publicip%0D%0A·自治域 AS$asn %0D%0A·经纬度 $longitude,$latitude %0D%0A·META城市 $city %0D%0A·实测带宽 $realbandwidth Mbps %0D%0A·峰值速度 $max kB/s %0D%0A·数据中心 $colo %0D%0A----------------------------------&parse_mode=Markdown" https://pushbot.pupilcc.com/sendMessage/$Telegrambot #Telegram推送最新查找的IP- @notification_me_bot
