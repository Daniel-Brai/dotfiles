# Oh My Posh Theme Config
eval "$(oh-my-posh init zsh --config ~/.poshthemes/spaceship.omp.json)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - zsh)"
export PATH="$PATH:$HOME/.rvm/bin"


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# My aliases
alias ~="cd ~"
alias bat="batcat"
alias bathelp='batcat --help'
alias crun="cargo run"
alias cnew="cargo new"
alias grun="go run ."
alias gmod="go mod init"
alias gi="git init"
alias ga="git add"
alias gs="git status"
alias gc="git commit -m"
alias gp="git push -u origin"
alias gotocode="cd ~/../../mnt/i/Programming"
alias gotoviconf="cd ~/.config/nvim/lua"
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias py='python3'
alias rnew="rails new"
alias rs="rails s"
alias rbin="./bin/dev"
alias vi='nvim'

# Exported Paths
export GOROOT=/usr/local/go-1.20.3
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
export PATH="/usr/bin/py3clean:/usr/bin/py3compile:$PATH"
