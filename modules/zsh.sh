#!/bin/bash

# ZSH 模块 - 安装和配置 ZSH

# 日志记录
log "INFO" "=== 开始安装和配置 ZSH ==="

# 安装 ZSH
zsh_install() {
    log "INFO" "安装 ZSH..."
    
    # 更新包列表
    sudo apt-get update >> "$LOG_FILE" 2>&1
    
    # 安装 ZSH
    sudo apt-get install -y zsh >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "ZSH 安装成功"
    else
        log "ERROR" "ZSH 安装失败"
        return 1
    fi
}

# 设置 ZSH 为默认 shell
zsh_set_default() {
    log "INFO" "设置 ZSH 为默认 shell..."
    
    # 获取当前用户
    local current_user=$(whoami)
    
    # 设置当前用户的默认 shell 为 zsh
    chsh -s $(which zsh) >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "ZSH 已设置为默认 shell"
    else
        log "WARNING" "设置 ZSH 为默认 shell 失败，可能需要手动设置"
    fi
}

# 安装 Oh My Zsh
ozsh_install() {
    log "INFO" "安装 Oh My Zsh..."
    
    # 下载并执行 Oh My Zsh 安装脚本
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >> "$LOG_FILE" 2>&1 || true
    
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Oh My Zsh 安装成功"
    else
        log "WARNING" "Oh My Zsh 安装失败，跳过"
    fi
}

# 配置 ZSH
ozsh_configure() {
    log "INFO" "配置 ZSH..."
    
    # 使用默认主题或配置文件中的主题
    local theme=${ZSH_THEME:-"robbyrussell"}
    
    # 检查 ~/.zshrc 文件是否存在
    if [ -f "$HOME/.zshrc" ]; then
        # 备份原有配置
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak" >> "$LOG_FILE" 2>&1
        
        # 更新主题
        sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"$theme\"/" "$HOME/.zshrc" >> "$LOG_FILE" 2>&1
        
        log "INFO" "ZSH 配置更新成功"
    else
        log "WARNING" "~/.zshrc 文件不存在，跳过配置"
    fi
}

# 主函数
zsh_main() {
    zsh_install
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    zsh_set_default
    ozsh_install
    ozsh_configure
    
    log "INFO" "=== ZSH 安装和配置完成 ==="
    return 0
}

# 执行 ZSH 主函数
zsh_main
