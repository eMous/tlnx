echo 'in .zshrc'
export ZIM_HOME="$HOME/.zim"
export ZIM_CONFIG_FILE="$HOME/.config/zsh/zimrc"
if [[ ! $HOME/.zim/init.zsh -nt $HOME/.config/zsh/zimrc ]]; then
  source $HOME/.zim/zimfw.zsh init
fi
source ${ZIM_HOME}/init.zsh