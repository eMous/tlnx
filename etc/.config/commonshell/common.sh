# Alias
alias l='ls -ah --group-directories-first --color=auto'
alias ll='l -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias v='vim'
if command -v nvim >/dev/null 2>&1; then
    alias v='nvim'
fi
alias zs='v $HOME/.config/zsh/.zshrc'
alias bs='v $HOME/.config/bash/.bashrc'
alias cs='v $HOME/.config/commonshell/common.sh'
alias vs='v $HOME/.config/vim/.vimrc'
alias t='cd /home/tom/tlnx'
alias bat='batcat'
alias dtlnx='DOCKER_TEST_ENABLED="true" tlnx'
echo "Common shell settings loaded."

