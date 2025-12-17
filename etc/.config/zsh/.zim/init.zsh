# FILE AUTOMATICALLY GENERATED FROM /home/tom/tlnx/etc/.config/zsh/.zimrc
# EDIT THE SOURCE FILE AND THEN RUN zimfw build. DO NOT DIRECTLY EDIT THIS FILE!

if [[ -e ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]] zimfw() { source "${HOME}/tlnx/etc/.config/zsh/.zim/zimfw.zsh" "${@}" }
fpath=("${HOME}/tlnx/etc/.config/zsh/.zim/modules/git/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/utility/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/duration-info/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/git-info/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/completion/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/archive/functions" "${HOME}/tlnx/etc/.config/zsh/.zim/modules/history-search-multi-word/functions" ${fpath})
autoload -Uz -- git-alias-lookup git-branch-current git-branch-delete-interactive git-branch-remote-tracking git-dir git-ignore-add git-root git-stash-clear-interactive git-stash-recover git-submodule-move git-submodule-remove mkcd mkpw duration-info-precmd duration-info-preexec coalesce git-action git-info archive lsarchive unarchive history-search-multi-word hsmw-context-main hsmw-highlight
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/environment/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/git/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/input/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/termtitle/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/utility/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/duration-info/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/pure/async.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/pure/pure.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/zsh-completions/zsh-completions.plugin.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/completion/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/exa/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/fzf/init.zsh"
source "${HOME}/tlnx/etc/.config/zsh/.zim/modules/archive/init.zsh"
