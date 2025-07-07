#!/bin/bash

# 遇到错误时立即退出
set -e

# --- 脚本功能 ---
# 0. 检查并设置 Swap 交换空间
# 1. 更新系统软件包
# 2. 安装必要的依赖软件 (sudo, vim, git)
# 3. 安装 Docker 并设置为开机自启动
# 4. 克隆 mailcow-dockerized 项目
# 5. 下载并解压额外的 API 和工具文件
# 6. 执行最终清理（清除历史、脚本自删除）

# --- 开始执行 ---

# 检查脚本是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo "错误：请使用 sudo 或以 root 用户身份运行此脚本。" >&2
   exit 1
fi

echo "--- 第0步：检查并设置 Swap 交换空间 ---"
# 检查 'swapon --show' 的输出是否为空，如果为空，则表示没有活动的swap
if [ -z "$(swapon --show)" ]; then
    echo "未检测到 Swap，正在创建 2048MB 的 Swap 文件..."

    # 创建一个 2GB 大小的文件
    fallocate -l 2G /swapfile
    
    # 设置文件权限，确保安全
    chmod 600 /swapfile
    
    # 将文件格式化为 swap 空间
    mkswap /swapfile
    
    # 启用 swap 文件
    swapon /swapfile
    
    # 将 swap 配置写入 /etc/fstab 使其永久生效
    # 首先检查是否已存在该条目，避免重复添加
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo "Swap 文件已成功创建并设置为开机自启动。"
    else
        echo "Swap 配置已存在于 /etc/fstab 中。"
    fi
else
    echo "系统已存在 Swap，跳过创建步骤。"
    # 显示当前的swap信息
    swapon --show
fi
echo "--- Swap 检查完成 ---"
echo


echo "--- 第1步：更新apt软件包列表 ---"
apt update -y
echo "--- apt 更新完成 ---"
echo

# 检查并安装依赖软件
echo "--- 第2步：检查并安装依赖软件 (sudo, vim, git) ---"
packages="sudo vim git curl" # 确保 curl 也被检查和安装
for pkg in $packages; do
    # 使用 command -v 检查命令是否存在
    if ! command -v $pkg &> /dev/null; then
        echo "未找到 '$pkg'，正在安装..."
        apt install -y $pkg
        echo "'$pkg' 安装完成。"
    else
        echo "'$pkg' 已安装。"
    fi
done
echo "--- 所有依赖软件均已安装 ---"
echo

# 检查并安装 Docker
echo "--- 第3步：安装 Docker 并设置为开机自启动 ---"
if ! command -v docker &> /dev/null; then
    echo "未找到 Docker，正在安装..."
    # 从官方源下载并执行安装脚本
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    # 删除安装脚本
    rm get-docker.sh
    echo "--- Docker 安装完成 ---"
else
    echo "--- Docker 已安装，跳过安装步骤 ---"
fi

# 启动并设置 Docker 开机自启动
echo "正在启动并设置 Docker 开机自启动..."
systemctl start docker
systemctl enable docker

# 检查 Docker 服务状态，确保已成功运行
if systemctl is-active --quiet docker; then
    echo "--- Docker 已成功启动并设置为开机自启动 ---"
else
    echo "--- 警告：Docker 服务未能启动，请手动检查！---" >&2
fi
echo

echo "--- 第4步：创建目录并克隆 mailcow-dockerized 项目 ---"
# 创建目录
if [ ! -d "/docker" ]; then
    echo "创建目录 /docker..."
    mkdir -p /docker
else
    echo "目录 /docker 已存在。"
fi

# 进入目录
cd /docker

# 克隆项目
if [ ! -d "mailcow-dockerized" ]; then
    echo "正在从 GitHub 克隆 mailcow-dockerized 项目..."
    git clone https://github.com/zp872571679/mailcow-dockerized.git
    echo "--- 项目克隆完成 ---"
else
    echo "--- 目录 mailcow-dockerized 已存在，跳过克隆步骤 ---"
fi
echo

echo "--- 第5步：下载并解压额外的 API 和工具文件 ---"
# 定义文件和目标目录
TARGET_DIR="/docker/mailcow-dockerized/data/web"
FILES_TO_DOWNLOAD=(
    "https://github.com/zp872571679/mailcowssh/raw/refs/heads/main/mail-api.tar.gz"
    "https://github.com/zp872571679/mailcowssh/raw/refs/heads/main/tool.tar.gz"
)

# 确保目标目录存在
echo "确保目标目录 '$TARGET_DIR' 存在..."
mkdir -p "$TARGET_DIR"

# 循环下载文件
for url in "${FILES_TO_DOWNLOAD[@]}"; do
    filename=$(basename "$url")
    filepath="$TARGET_DIR/$filename"
    if [ ! -f "$filepath" ]; then
        echo "文件 '$filename' 不存在，正在下载..."
        # 使用 curl 下载文件到指定目录
        curl -L -o "$filepath" "$url"
        echo "下载完成: $filename"
    else
        echo "文件 '$filename' 已存在，跳过下载。"
    fi
done

# 进入目标目录解压文件
cd "$TARGET_DIR"
echo "进入目录 $(pwd) 进行解压操作..."

for url in "${FILES_TO_DOWNLOAD[@]}"; do
    filename=$(basename "$url")
    if [ -f "$filename" ]; then
        echo "正在解压 '$filename'..."
        tar -xzvf "$filename"
        echo "解压完成，删除压缩包 '$filename'..."
        rm "$filename"
    else
        echo "警告：未找到压缩包 '$filename'，无法解压。"
    fi
done
echo "--- 额外文件处理完成 ---"
echo

echo "--- 脚本执行完毕！---"

# --- 新增：第6步，最终清理 ---
echo "--- 第6步：执行最终清理 ---"
echo "清除当前会话的命令历史记录..."
history -c
history -w

echo "删除安装脚本本身..."
# 使用 rm -- "$0" 来安全地删除脚本自身
rm -- "$0"

echo "清理完成。"

exit 0
