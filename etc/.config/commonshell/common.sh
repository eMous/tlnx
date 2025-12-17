# Alias
alias l='ls -ah --group-directories-first --color=auto'
alias ll='l -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias zs='vim $TLNX_DIR/etc/.config/zsh/.zshrc'
alias bs='vim $TLNX_DIR/etc/.config/bash/.bashrc'
alias cs='vim $TLNX_DIR/etc/.config/commonshell/common.sh'
alias vs='vim $TLNX_DIR/etc/.config/vim/.vimrc'
alias v='vim'
if command -v nvim >/dev/null 2>&1; then
    alias v='nvim'
fi
alias t='cd /home/tom/tlnx'
alias bat='batcat'
alias dtlnx='DOCKER_TEST_ENABLED="true" tlnx'
echo "Common shell settings loaded."

