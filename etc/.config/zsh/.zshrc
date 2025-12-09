export ZIM_HOME="$HOME/.config/zsh/.zim"
export ZIM_CONFIG_FILE="$HOME/.config/zsh/.zimrc"
if [[ ! $HOME/.config/zsh/.zim/init.zsh -nt $HOME/.config/zsh/.zimrc ]]; then
  source $HOME/.config/zsh/.zim/zimfw.zsh init
fi
source ${ZIM_HOME}/init.zsh 