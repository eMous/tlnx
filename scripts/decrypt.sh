#!/bin/bash

# 解密配置脚本 - 支持输出到文件或标准输出

# 参数检查
if [ $# -lt 1 ]; then
    echo "用法: $0 <加密文件路径> [解密输出文件路径] [默认密钥环境变量名]"
    echo "示例1: $0 config/enc.conf.enc config/enc.conf"  # 输出到文件
    echo "示例2: $0 config/enc.conf.enc"  # 输出到标准输出
    exit 1
fi

# 加密文件路径
ENCRYPTED_FILE="$1"

# 解密输出文件路径（可选）
OUTPUT_FILE="$2"

# 默认密钥环境变量名，从参数获取或使用默认值
DEFAULT_KEY_ENV=${3:-"CONFIG_KEY"}

# 从默认环境变量获取密钥或提示用户输入
if [ -n "${!DEFAULT_KEY_ENV}" ]; then
    KEY="${!DEFAULT_KEY_ENV}"
    echo "使用默认环境变量 $DEFAULT_KEY_ENV 中的密钥进行解密" >&2
else
    read -s -p "请输入解密密钥: " KEY
    echo
fi

# 检查密钥是否为空
if [ -z "$KEY" ]; then
    echo "解密密钥不能为空"
    exit 1
fi

# 使用openssl解密文件
if [ -n "$OUTPUT_FILE" ]; then
    # 输出到文件
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENCRYPTED_FILE" -k "$KEY" > "$OUTPUT_FILE"
    if [ $? -eq 0 ]; then
        echo "解密成功，输出到文件: $OUTPUT_FILE"
        return 0
    else
        echo "解密失败"
        exit 1
    fi
else
    # 输出到标准输出
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENCRYPTED_FILE" -k "$KEY"
    if [ $? -eq 0 ]; then
        return 0
    else
        exit 1
    fi
fi
