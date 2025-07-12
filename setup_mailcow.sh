#!/usr/bin/env bash

# 遇到错误时立即退出
set -e

# --- 脚本功能 ---
# 0. 自动重置并配置 Swap (检查->删除->新建2048MB)
# 1. 更新系统软件包
# 2. 安装必要的依赖软件
# 3. 安装 Docker 并设置为开机自启动
# 4. 克隆 mailcow-dockerized 项目
# 5. 下载并解压额外的 API 和工具文件

#=================================================#
#                   配置和函数定义                   #
#=================================================#

# 定义彩色输出
Green="\033[32m"
Red="\033[31m"
Font="\033[0m"

# 函数：必须以 root 权限运行
root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}错误：此脚本必须以 root 用户身份运行！${Font}"
        exit 1
    fi
}

# 函数：检测是否为 OpenVZ 架构（不支持 Swap）
ovz_no(){
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Red}错误：您的服务器基于 OpenVZ 虚拟化，不支持此脚本！${Font}"
        exit 1
    fi
}

# 函数：重置 Swap 的核心逻辑
setup_swap(){
    if grep -q "swapfile" /etc/fstab || swapon --show | grep -q "/swapfile"; then
        echo -e "${Green}检测到已存在的 /swapfile，正在开始移除...${Font}"
        swapoff /swapfile &>/dev/null || true
        sed -i '/\/swapfile/d' /etc/fstab
        rm -f /swapfile
        echo -e "${Green}旧的 /swapfile 已成功移除。${Font}"
        echo
    fi

    echo -e "${Green}开始创建并配置一个 2048MB 的新 Swap 文件...${Font}"
    echo -e "${Green}--> 步骤 1/5: 创建 2GB 文件 (此过程可能需要一些时间)...${Font}"
    fallocate -l 2048M /swapfile
    echo -e "${Green}--> 步骤 2/5: 设置文件权限为 600...${Font}"
    chmod 600 /swapfile
    echo -e "${Green}--> 步骤 3/5: 格式化为 Swap 空间...${Font}"
    mkswap /swapfile
    echo -e "${Green}--> 步骤 4/5: 启用 Swap 文件...${Font}"
    swapon /swapfile
    
    if ! swapon --show | grep -q "/swapfile"; then
        echo -e "${Red}错误：启用 Swap 失败，请检查系统日志！${Font}" >&2
        exit 1
    fi

    echo -e "${Green}--> 步骤 5/5: 添加开机自启动配置...${Font}"
    echo '/swapfile none swap defaults 0 0' >> /etc/fstab
    
    echo
    echo -e "${Green}Swap 重置成功！新的 2048MB Swap 已激活。${Font}"
    echo -e "${Green}当前内存和 Swap 状态如下：${Font}"
    free -h
}

#=================================================#
#                     主程序开始                     #
#=================================================#

clear
echo -e "================================================="
echo -e "${Green}      全自动服务器环境初始化脚本      ${Font}"
echo -e "================================================="
echo

# 步骤 -1: 执行权限和环境检查
root_need
ovz_no

# 步骤 0: 配置 Swap
echo -e "${Green}--- 第0步：重置并配置 Swap 交换空间 ---${Font}"
setup_swap
echo -e "${Green}--- Swap 配置完成 ---${Font}"
echo

# 步骤 1: 更新软件包
echo -e "${Green}--- 第1步：更新apt软件包列表 ---${Font}"
apt update -y
echo -e "${Green}--- apt 更新完成 ---${Font}"
echo

# 步骤 2: 安装依赖
echo -e "${Green}--- 第2步：检查并安装依赖软件 (sudo, vim, git) ---${Font}"
packages="sudo vim git curl"
for pkg in $packages; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "未找到 '$pkg'，正在安装..."
        apt install -y $pkg
        echo -e "'$pkg' 安装完成。"
    else
        echo -e "'$pkg' 已安装。"
    fi
done
echo -e "${Green}--- 所有依赖软件均已安装 ---${Font}"
echo

# 步骤 3: 安装并配置 Docker
echo -e "${Green}--- 第3步：安装 Docker 并设置为开机自启动 ---${Font}"
if ! command -v docker &> /dev/null; then
    echo "未找到 Docker，正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${Green}--- Docker 安装完成 ---${Font}"
else
    echo -e "${Green}--- Docker 已安装，跳过安装步骤 ---${Font}"
fi

echo "正在启动并设置 Docker 开机自启动..."
systemctl start docker
systemctl enable docker

if systemctl is-active --quiet docker; then
    echo -e "${Green}--- Docker 已成功启动并设置为开机自启动 ---${Font}"
else
    echo -e "${Red}--- 警告：Docker 服务未能启动，请手动检查！---${Font}" >&2
fi
echo

# 步骤 4: 克隆项目
echo -e "${Green}--- 第4步：创建目录并克隆 mailcow-dockerized 项目 ---${Font}"
if [ ! -d "/docker" ]; then
    echo "创建目录 /docker..."
    mkdir -p /docker
else
    echo "目录 /docker 已存在。"
fi
cd /docker
if [ ! -d "mailcow-dockerized" ]; then
    echo "正在从 GitHub 克隆 mailcow-dockerized 项目..."
    git clone https://github.com/zp872571679/mailcow-dockerized.git
    echo -e "${Green}--- 项目克隆完成 ---${Font}"
else
    echo -e "${Green}--- 目录 mailcow-dockerized 已存在，跳过克隆步骤 ---${Font}"
fi
echo

# 步骤 5: 下载并解压额外文件
echo -e "${Green}--- 第5步：下载并解压额外的 API 和工具文件 ---${Font}"
TARGET_DIR="/docker/mailcow-dockerized/data/web"
FILES_TO_DOWNLOAD=(
    "https://github.com/zp872571679/mailcowssh/raw/refs/heads/main/mail-api.tar.gz"
    "https://github.com/zp872571679/mailcowssh/raw/refs/heads/main/tool.tar.gz"
)
echo "确保目标目录 '$TARGET_DIR' 存在..."
mkdir -p "$TARGET_DIR"
for url in "${FILES_TO_DOWNLOAD[@]}"; do
    filename=$(basename "$url")
    filepath="$TARGET_DIR/$filename"
    if [ ! -f "$filepath" ]; then
        echo "文件 '$filename' 不存在，正在下载..."
        curl -L -o "$filepath" "$url"
        echo "下载完成: $filename"
    else
        echo "文件 '$filename' 已存在，跳过下载。"
    fi
done
cd "$TARGET_DIR"
echo "进入目录 $(pwd) 进行解压操作..."
for url in "${FILES_TO_DOWNLOAD[@]}"; do
    filename=$(basename "$url")
    if [ -f "$filename" ]; then
        echo "正在解压 '$filename'..."
        tar -xzvf "$filename" &>/dev/null
        echo "解压完成，删除压缩包 '$filename'..."
        rm "$filename"
    else
        echo -e "${Red}警告：未找到压缩包 '$filename'，无法解压。${Font}"
    fi
done
echo -e "${Green}--- 额外文件处理完成 ---${Font}"
echo

# 最终提示
echo -e "${Green}--- 脚本执行完毕！---${Font}"
echo "所有准备工作已完成。"

#=================================================#
#                   最终清理步骤                    #
#=================================================#

echo "--- 开始执行最终清理 ---"

# 1. 清除在脚本执行期间（root用户）产生的历史记录
echo "清除当前会话的命令历史记录..."
history -c
history -w

# 2. 回到执行文件夹
cd ~

# 3. 启动后台任务，在脚本退出后删除自身
echo "脚本将在2秒后后台自删除..."
(sleep 3 && rm -- "$0") &

# 脚本主程序正常退出
exit 0
