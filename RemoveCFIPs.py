import os
import sys
import requests
import ipaddress

# 获取命令行参数
filename = sys.argv[1] if len(sys.argv) > 1 else 'ip.txt'

# 检查文件是否存在
if not os.path.exists(filename):
    print(f"{filename} 文件不存在")
else:
    # 获取Cloudflare的IP段
    cloudflare_ips = []
    for asn in ['AS13335', 'AS209242']:
        response = requests.get(f'http://asn2cidr.ssrc.cf/{asn}')
        if response.status_code == 200:
            cloudflare_ips.extend(response.text.split('\n'))

    # 读取文件中的IP
    with open(filename, 'r') as file:
        ips = file.read().split('\n')

    # 删除符合Cloudflare IP段的IP
    ips = [ip for ip in ips if ip and not any(ipaddress.ip_address(ip) in ipaddress.ip_network(cf_ip) for cf_ip in cloudflare_ips)]

    # 保存回源文件
    with open(filename, 'w') as file:
        file.write('\n'.join(ips))

    print(f"已完成删除 {filename} 中符合Cloudflare IP段的IP")
