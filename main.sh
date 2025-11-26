#!/bin/bash

# 服务器自动配置工具 - 主执行脚本

# 加载库文件
source "lib/common.sh"
source "lib/remote.sh"
source "lib/config.sh"
source "lib/module.sh"

# 显示使用帮助信息
display_usage() {
    echo "服务器自动配置工具tlnx使用说明"
    # 获取当前主机名
    local current_hostname=$(hostname)
    
    # 检查是否为远程模式（通过SSH_CLIENT_HOST环境变量判断）
    if [ -n "${SSH_CLIENT_HOST:-}" ]; then
        echo -e "\033[31m[模式：远程] 当前正在远程服务器（${current_hostname}）上执行，会话由客户端主机 （${SSH_CLIENT_HOST}）发起\033[0m"
    else
        echo -e "\033[31m[模式：本地] 当前正在本地环境（${current_hostname}）执行\033[0m"
    fi
    echo ""
    echo "使用方法:"
    echo "  ./main.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -l, --log-level LEVEL 设置日志级别 (DEBUG, INFO, WARN, ERROR)"
    echo "  -t, --test           运行测试模式"
    echo "  -f, --force          强制安装模块，忽略已安装检查"
    echo "  --modules MODULES    指定要执行的模块列表，用逗号分隔"
    echo "  -d, --decrypt        执行解密功能，解密config/enc.conf.enc到config/enc.conf"
    echo "  -c, --encrypt        执行加密功能，加密config/enc.conf到config/enc.conf.enc"
    echo ""
    echo "示例:"
    echo "  ./main.sh -l INFO"
    echo "  ./main.sh --modules docker,zsh"
    echo "  ./main.sh -d"
    echo "  ./main.sh -c"
}

# 主函数
main() {
    # 初始化默认值
    local LOG_LEVEL="INFO"
    local TEST_MODE="false"
    local CUSTOM_MODULES=""
    local DECRYPT_MODE="false"
    local ENCRYPT_MODE="false"
    
    # 解析命令行参数
    local i=1
    local FORCE_MODE="false"
    while [ $i -le $# ]; do
        local arg=${!i}
        if [ "$arg" = "-l" ] || [ "$arg" = "--log-level" ]; then
            local next_i=$((i+1))
            LOG_LEVEL="${!next_i}"
            i=$((i+2))
        elif [ "$arg" = "-t" ] || [ "$arg" = "--test" ]; then
            TEST_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "--modules" ]; then
            local next_i=$((i+1))
            CUSTOM_MODULES="${!next_i}"
            i=$((i+2))
        elif [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            display_usage
            exit 0
        elif [ "$arg" = "-d" ] || [ "$arg" = "--decrypt" ]; then
            DECRYPT_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "-c" ] || [ "$arg" = "--encrypt" ]; then
            ENCRYPT_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "-f" ] || [ "$arg" = "--force" ]; then
            FORCE_MODE="true"
            i=$((i+1))
        else
            echo "错误：未知参数: $arg" >&2
            display_usage
            exit 1
        fi
    done
    
    # 处理加密解密模式
    if [ "$DECRYPT_MODE" = "true" ]; then
        echo "执行解密功能..."
        bash "scripts/decrypt.sh" "config/enc.conf.enc" "config/enc.conf"
        if [ $? -eq 0 ]; then
            echo "解密成功：config/enc.conf.enc -> config/enc.conf"
        else
            echo "解密失败"
            exit 1
        fi
        exit 0
    fi
    
    if [ "$ENCRYPT_MODE" = "true" ]; then
        echo "执行加密功能..."
        bash "scripts/encrypt.sh" "config/enc.conf" "config/enc.conf.enc"
        if [ $? -eq 0 ]; then
            echo "加密成功：config/enc.conf -> config/enc.conf.enc"
        else
            echo "加密失败"
            exit 1
        fi
        exit 0
    fi
    
    # 再次加载完整配置（包括解密加密配置）
    load_config
    
    log "INFO" "开始执行服务器自动配置工具"
    
    # 测试模式处理
    if [ "$TEST_MODE" = "true" ]; then
        log "INFO" "测试模式：只加载配置，不执行模块操作"
        
        # 输出所有非空配置值
        log "INFO" "===== 非空配置值列表 ===="
        
        # 从配置模板和默认配置中提取所有环境变量名
        local template_file="config/default.conf.template"
        local default_file="config/default.conf"
        local config_vars=()
        
        # 从模板和默认配置中提取所有变量名
        for file in "$template_file" "$default_file"; do
            while IFS='=' read -r var_name _; do
                # 跳过注释和空行
                if [[ "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    # 检查变量名是否已存在
                    local exists=false
                    for existing_var in "${config_vars[@]}"; do
                        if [ "$existing_var" = "$var_name" ]; then
                            exists=true
                            break
                        fi
                    done
                    if [ "$exists" = false ]; then
                        config_vars+=("$var_name")
                    fi
                fi
            done < <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*=' "$file")
        done
        
        # 遍历所有提取的变量名
        for var in "${config_vars[@]}"; do
            # 检查变量是否存在
            if [ -z "${!var+x}" ]; then
                continue  # 变量不存在，跳过
            fi
            
            # 检查变量是否为数组
            if declare -p "$var" 2>/dev/null | grep -q 'declare -a'; then
                # 数组变量 - 使用nameref正确处理
                declare -n arr="$var"
                local array_values=()
                for item in "${arr[@]}"; do
                    # 对于数组，不过滤值，全部输出
                    array_values+=("$item")
                done
                if [ ${#array_values[@]} -gt 0 ]; then
                    log "INFO" "$var = (${array_values[*]})"
                fi
                unset -n arr  # 取消nameref
            else
                # 普通变量
                local value="${!var}"
                if [ -n "$value" ] && [ "$value" != "!!!!!!!ENCRYPTED!!!!!!!" ]; then
                    log "INFO" "$var = $value"
                fi
            fi
        done
        
        # 输出从加密配置中派生的变量
        log "INFO" "TARGET_HOST = $TARGET_HOST"
        log "INFO" "TARGET_USER = $TARGET_USER"
        log "INFO" "TARGET_PORT = $TARGET_PORT"
        log "INFO" "TARGET_PASSWORD = $TARGET_PASSWORD"
        
        log "INFO" "===== 配置值列表结束 ===="
        log "INFO" "配置加载完成，测试模式执行结束"
        exit 0
    fi
    
    # 环境检测 - 检查是否为执行环境
    if [ "${IS_EXECUTION_ENVIRONMENT:-false}" != "true" ]; then
        # 非执行环境，需要传输到目标主机执行
        if [ -z "$TARGET_HOST" ] || [ -z "$TARGET_USER" ]; then
            log "ERROR" "非执行环境下必须设置 TARGET_HOST 和 TARGET_USER 变量"
            exit 1
        fi
        # 直接执行远程传输
        log "INFO" "非执行环境，开始传输到目标主机执行"
        remote_execution "$TARGET_HOST" "$TARGET_USER" "$TARGET_PORT"
        exit $?
    fi
    
    # 发行版检测
    detect_distro
    # 确定要执行的模块列表
    local MODULES_TO_EXECUTE=()
    
    # 如果指定了自定义模块列表，则使用指定的模块
    if [ -n "$CUSTOM_MODULES" ]; then
        IFS=',' read -r -a MODULES_TO_EXECUTE <<< "$CUSTOM_MODULES"
        log "INFO" "使用自定义模块列表：${MODULES_TO_EXECUTE[*]}"
    # 否则使用配置文件中的模块列表
    elif [ -n "${CONFIG_MODULES[*]}" ]; then
        MODULES_TO_EXECUTE=("${CONFIG_MODULES[@]}")
        log "INFO" "使用配置文件中的模块列表：${MODULES_TO_EXECUTE[*]}"
    # 否则使用默认模块列表
    else
        MODULES_TO_EXECUTE=()
        log "INFO" "没有配置模块列表，使用默认空列表"
    fi
    
    # 处理必须安装的模块
    if [ -n "${CONFIG_REQUIRED_MODULES[*]}" ]; then
        log "INFO" "必须安装的模块列表：${CONFIG_REQUIRED_MODULES[*]}"
        
        # 创建一个临时数组，用于存储最终的模块列表
        local FINAL_MODULES=()
        
        # 首先添加所有必须的模块，确保不重复
        for req_module in "${CONFIG_REQUIRED_MODULES[@]}"; do
            if [[ ! "${FINAL_MODULES[*]}" =~ "$req_module" ]]; then
                FINAL_MODULES+=("$req_module")
            fi
        done
        
        # 然后添加所有非必须的模块，确保不重复且不在必须模块列表中
        for module in "${MODULES_TO_EXECUTE[@]}"; do
            if [[ ! "${FINAL_MODULES[*]}" =~ "$module" ]]; then
                FINAL_MODULES+=("$module")
            fi
        done
        
        # 更新要执行的模块列表
        MODULES_TO_EXECUTE=("${FINAL_MODULES[@]}")
        log "INFO" "最终执行模块列表：${MODULES_TO_EXECUTE[*]}"
    fi
    
    # 检查模块序列是否为空
    if [ ${#MODULES_TO_EXECUTE[@]} -eq 0 ]; then
        log "INFO" "没有需要执行的模块"
        exit 0
    fi
    # 按顺序执行模块
    for module in "${MODULES_TO_EXECUTE[@]}"; do
        execute_module "$module" "$FORCE_MODE"
    done
    
    log "INFO" "服务器自动配置工具执行完成"
}

# 执行主函数
main "$@"
