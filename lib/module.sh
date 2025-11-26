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
    local force=$2  # 新增force参数
    log "INFO" "开始执行模块: $module"
    
    # 检查模块脚本是否存在
    if [ -f "modules/$module.sh" ]; then
        # 先加载模块脚本
        source "modules/$module.sh"
        
        local need_install=true
        
        # 如果不是强制安装，则检查模块是否已安装
        if [ "$force" != "true" ]; then
            # 检查模块是否已安装（尝试调用check_installed函数）
            if command -v _${module}_check_installed &> /dev/null; then
                if _${module}_check_installed; then
                    log "INFO" "模块 $module 已安装，跳过安装步骤"
                    need_install=false
                else
                  log "INFO" "模块 $module 未安装，开始执行安装过程"
                fi
            else
                log "WARNING" "模块 $module 没有提供 check_installed 函数，直接执行安装"
            fi
        else
            log "INFO" "强制执行模块 $module 的安装函数"
        fi
        
        # 执行模块的安装函数
        if [ "$need_install" = "true" ]; then
            # 尝试调用以模块名命名的install函数（如docker_install）
            local install_func="_${module}_install"
            if command -v "$install_func" &> /dev/null; then
                "$install_func"
                if [ $? -ne 0 ]; then
                    log "ERROR" "模块 $module 的 $install_func 函数执行失败"
                    return 1
                fi
            else
                log "WARNING" "模块 $module 没有找到 ${install_func} 函数，跳过安装步骤"
            fi
        fi
        
        # 执行模块的主函数来完成配置（无论是否安装）
        # 尝试调用以模块名命名的主函数（如docker_main）或通用main函数
        if command -v "${module}_main" &> /dev/null; then
            "${module}_main"
        elif command -v "main" &> /dev/null; then
            main
        else
            log "ERROR" "模块 $module 没有找到主函数（${module}_main 或 main）"
            return 1
        fi
        
        if [ $? -eq 0 ]; then
            log "INFO" "模块 $module 执行成功"
        else
            log "ERROR" "模块 $module 执行失败"
            return 1
        fi
    else
        log "WARNING" "模块脚本不存在: modules/$module.sh，跳过执行"
        return 1
    fi
}  