#!/bin/bash

# 遇到错误时立即退出
set -e

# --- 脚本功能 ---
# 1. 更新系统软件包
# 2. 安装必要的依赖软件 (sudo, vim, git)
# 3. 安装 Docker
# 4. 克隆 mailcow-dockerized 项目
# 5. 生成 mailcow 配置文件

# --- 开始执行 ---

# 检查脚本是否以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo "错误：请使用 sudo 或以 root 用户身份运行此脚本。" >&2
   exit 1
fi

echo "--- 第1步：更新apt软件包列表 ---"
apt update -y
echo "--- apt 更新完成 ---"
echo

# 检查并安装依赖软件
echo "--- 第2步：检查并安装依赖软件 (sudo, vim, git) ---"
packages="sudo vim git"
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
echo "--- 第3步：检查并安装 Docker ---"
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
# 将当前用户添加到docker组，以便无需sudo即可运行docker命令（可选，但推荐）
# 注意：这需要重新登录才能生效
# usermod -aG docker $(logname)
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

echo "--- 第5步：生成 mailcow 配置文件 ---"
# 进入项目目录
cd mailcow-dockerized

# 检查配置文件生成脚本是否存在
if [ -f "./generate_config.sh" ]; then
    echo "正在执行 ./generate_config.sh..."
    # 赋予执行权限并执行
    chmod +x ./generate_config.sh
    ./generate_config.sh
else
    echo "错误：未找到配置文件生成脚本 'generate_config.sh'！" >&2
    exit 1
fi
echo

echo "--- 所有操作已成功完成！---"
echo "您现在位于 $(pwd) 目录。"
echo "接下来，请根据 mailcow 的文档修改 'mailcow.conf' 文件，然后运行 'docker-compose up -d'。"

exit 0
