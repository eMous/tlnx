#!/bin/bash

# 脚本名称: encrypt.sh
# 脚本用途: 加密配置内容
# 脚本版本: 1.0

# 设置严格模式
set -e

# 函数：显示用法
display_usage() {
    echo "用法: $0 <源配置文件路径> [加密输出文件路径] [默认密钥环境变量名]"
    echo "示例1: $0 config/example.conf config/example.conf.enc"  # 输出到文件
    echo "示例2: $0 config/example.conf"  # 输出到标准输出
    echo "或: $0 config/example.conf config/example.conf.enc CUSTOM_KEY_ENV"
    exit 1
}

# 检查参数数量
if [ $# -lt 1 ]; then
    display_usage
fi

# 获取参数
SOURCE_FILE=$1
OUTPUT_FILE=$2
DEFAULT_KEY_ENV=${3:-"CONFIG_KEY"}

# 检查源文件是否存在
if [ ! -f "$SOURCE_FILE" ]; then
    echo "错误: 源配置文件不存在: $SOURCE_FILE"
    exit 1
fi

# 获取加密密钥
# 1. 尝试从环境变量获取
if [ -n "${!DEFAULT_KEY_ENV}" ]; then
    KEY="${!DEFAULT_KEY_ENV}"
    echo "使用默认环境变量 $DEFAULT_KEY_ENV 中的密钥进行加密" >&2
# 2. 提示用户输入
else
    read -s -p "请输入加密密钥: " KEY
    echo
fi

# 检查密钥是否为空
if [ -z "$KEY" ]; then
    echo "加密密钥不能为空"
    exit 1
fi

# 执行加密
# 使用-pbkdf2选项进行密钥派生，提高安全性，同时避免"deprecated key derivation used"警告
if [ -n "$OUTPUT_FILE" ]; then
    # 输出到文件
    openssl enc -e -aes-256-cbc -salt -pbkdf2 -in "$SOURCE_FILE" -k "$KEY" > "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
        echo "加密成功，输出到文件: $OUTPUT_FILE"
        exit 0
    else
        echo "配置内容加密失败"
        exit 1
    fi
else
    # 输出到标准输出
    openssl enc -e -aes-256-cbc -salt -pbkdf2 -in "$SOURCE_FILE" -k "$KEY"
    if [ $? -eq 0 ]; then
        exit 0
    else
        echo "配置内容加密失败"
        exit 1
    fi
fi
