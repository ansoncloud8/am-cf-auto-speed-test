#!/bin/bash
# $ ./CDNDomainUpdate.sh cdn xxxx.com xxxx@gmail.com xxxxxxxxxxxxxxx
export LANG=zh_CN.UTF-8
auth_email="xxxx@gmail.com"    #你的CloudFlare注册账户邮箱 *必填
auth_key="xxxxxxxxxxxxxxx"   #你的CloudFlare账户key,位置在域名概述页面点击右下角获取api key。*必填
zone_name="xxxx.com"     #你的主域名 *必填
record_name="cdn" #二级域名前缀
###############################################################以下脚本内容，勿动#######################################################################
area=1 #每个地区更新的IP数量
#带有二级域名前缀参数
if [ -n "$1" ]; then 
    record_name="$1"
fi

#带有主域名参数
if [ -n "$2" ]; then 
    zone_name="$2"
fi

#带有CloudFlare账户邮箱参数
if [ -n "$3" ]; then 
    auth_email="$3"
fi

#带有CloudFlare账户key参数
if [ -n "$4" ]; then 
    auth_key="$4"
fi

record_type="A"     
#获取zone_id、record_id
zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
# echo $zone_identifier
readarray -t record_identifiers < <(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name.$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')

record_count=0
for identifier in "${record_identifiers[@]}"; do
	# echo "${record_identifiers[$record_count]}"
	((record_count++))
done

file="./log/${record_name^^}-443.csv"

if [ -e "$file" ]; then
    	#echo "$file 存在."
    	start=2
	Rows=$((record_count + 1))
 	result_csv=$file
  
  	echo "待更新域名数: $record_count" 
   	line_count=$(wc -l < "$file")
    	echo "待处理IP总数: $((line_count - 1))"
     	if [ "$record_count" -gt "$((line_count - 1))" ]; then
	        echo "待处理域名数＞待处理IP总数，结束当前脚本."
	 	echo "请重新运行speed.sh脚本,获取更多${record_name^^}地区待处理IP后再试."
	        exit 1  # 可以选择适当的退出状态码
    	fi
     	echo "待更新域名 ${record_name}.${zone_name}"
else
    	#echo "$file 不存在."
	# 找到所有匹配的文件
	log_files=(./log/*.csv)

	# 要排除的元素
	element_to_exclude="./log/CDN.csv"

	filtered_log_files=()
	for file in "${log_files[@]}"; do
	    if [ "$file" != "$element_to_exclude" ]; then
	        filtered_log_files+=("$file")
	    fi
	done

	# 将过滤后的数组重新赋值给 log_files
	log_files=("${filtered_log_files[@]}")
	#echo "${log_files[@]}"
	
	count=0
	
	area_ip() {
	> ./log/CDN.csv #清空目标文件
	
	count=0
	# 遍历所有文件
	for file in "${log_files[@]}" 
	do
	  # 提取第2行起始内容写入目标文件    
	  sed -n "2,$((area+1))p" "$file" >> ./log/CDN.csv
	  ((count++))
	done
    	line_count=$(wc -l < ./log/CDN.csv )
	}
	
	area_ip

	while [ $record_count -gt $line_count ]; do
	  	echo "待更新域名数: $record_count" 
	  	echo "待处理IP总数: $line_count"
	  	#echo "record_count 大于 count * area"
	  	echo "待处理域名数＞待处理IP总数，尝试给每个地区增加1个IP"
	  	((area++))
	  	area_ip
	done
	
	echo "待更新域名数: $record_count" 
	echo "待处理IP总数: $line_count"
	echo "待更新域名 ${record_name}.${zone_name}"
	start=1
	Rows=$record_count
 	result_csv="log/CDN.csv"
fi

sed -n "$((start)),$((Rows))p" $result_csv | while read line
do
    #echo $record_name$record_count'.'$zone_name
    #record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name"'.'"$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	
    #更新DNS记录
    update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/${record_identifiers[$record_count - 1]}" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"type\":\"$record_type\",\"name\":\"$record_name.$zone_name\",\"content\":\"${line%%,*}\",\"ttl\":60,\"proxied\":false}")
    #反馈更新情况
	
    if [[ "$update" != "${update%success*}" ]] && [[ "$(echo $update | grep "\"success\":true")" != "" ]]; then
      echo $record_name'.'$zone_name'更新为:'${line%%,*}'....成功'
    else
      echo $record_name'.'$zone_name'更新失败:'$update
    fi
	
    record_count=$(($record_count-1))    #二级域名序号递减
    echo $record_count
    if [ $record_count -eq 0 ]; then
        break
    fi

done
