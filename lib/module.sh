#!/bin/bash

# 模块执行相关函数

# 函数：显示用法
display_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -l, --log-level <级别>  设置日志级别 (DEBUG, INFO, WARNING, ERROR)，默认为 INFO"
    echo "  -t, --test             测试模式：只加载配置，不执行模块操作"
    echo "  --modules <模块列表>    指定要执行的模块，逗号分隔，如：--modules docker,zsh"
    echo "  -h, --help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -l DEBUG"
    echo "  $0 -t  # 测试配置加载"
    echo "  $0 --modules docker,zsh  # 只执行docker和zsh模块"
}

# 函数：执行模块
execute_module() {
    local module=$1
    log "INFO" "开始执行模块: $module"
    
    # 检查模块脚本是否存在
    if [ -f "modules/$module.sh" ]; then
        . "modules/$module.sh"
        log "INFO" "模块 $module 执行成功"
    else
        log "WARNING" "模块脚本不存在: modules/$module.sh，跳过执行"
    fi
}