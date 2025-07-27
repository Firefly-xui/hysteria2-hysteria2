# 一键安装
在安装前请确保你的系统支持`bash`环境,且系统网络正常  


# 配置要求  
## 内存  
- 128MB minimal/256MB+ recommend  
## OS  
- Ubuntu 22-24

-FinalShell下载地址 [FinalShell](https://dl.hostbuf.com/finalshell3/finalshell_windows_x64.exe)

# hysteria2中转hysteria2协议

落地机执行
```
bash <(curl -Ls https://raw.githubusercontent.com/Firefly-xui/hysteria2-hysteria2/main/destination-node.sh)
```  
在落地机查找路径为为：/opt/hysteria2_client.yaml的文件将该文件下载，然后上传到中转机的：/opt/路径下。

中转机执行
```
bash <(curl -Ls https://raw.githubusercontent.com/Firefly-xui/hysteria2-hysteria2/main/relay-node.sh)
```  
下载中转机路径为：/opt/hysteria2_relay_client.yaml文件，在v2rayn中导入自定义配置文件即可。

windows客户端
-官方v2rayn [v2rayn](https://github.com/Firefly-xui/hysteria2-hysteria2/releases/download/hysteria2-hysteria2/v2rayN-windows-64.zip)

| 协议组合                            | 抗封锁   | 延迟    | 稳定性   | 部署复杂度 | 适用建议       |
| ------------------------------- | ----- | ----- | ----- | ----- | ---------- |
| hysteria2-hysteria2   | ★★★☆☆ | ★★★★★ | ★★★☆☆ | ★★★★☆ | 稳定直播低延迟低卡顿场景 |
| Hysteria2 + UDP + TLS + Obfs    | ★★★☆☆ | ★★★★★ | ★★★☆☆ | ★★☆☆☆ | 电影流媒体等大流量场景 |
| TUIC + UDP + QUIC + TLS         | ★★★★☆ | ★★★★★ | ★★★★☆ | ★★★★★ | 游戏直播等低延迟场景场景 |
| VLESS + Reality + uTLS + Vision | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★☆☆☆☆ | 安全可靠长期稳定场景     |
