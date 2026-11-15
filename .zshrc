# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# append completions to fpath
fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# My Aliases

# Functions Aliases
ytdl() {
    if [ -z "$1" ]; then
        echo "Usage: ytdl <Video_URL>"
        return 1
    fi
    
    local url="$1"
    
    # Create directory if it doesn't exist
    mkdir -p "$HOME/Downloads/yt-dlp"
    
    echo "Fetching available formats..."
    echo "================================================================"
    printf "%-8s %-8s %-12s %-8s %-12s %-15s\n" "ID" "EXT" "RESOLUTION" "FPS" "FILESIZE" "TYPE"
    echo "----------------------------------------------------------------"
    
    # Get formats with better categorization
    yt-dlp -F "$url" | grep -E "^[0-9]+" | \
    awk '{
        # Determine if audio only, video only, or combined
        type = "combined"
        if ($3 == "audio") type = "audio-only"
        else if (NF >= 6 && $(NF-1) ~ /video/) type = "video-only"
        else if ($3 ~ /^[0-9]+x[0-9]+$/ && NF <= 6) type = "video-only"
        
        # Find filesize
        filesize = ""
        for(i=5; i<=NF; i++) {
            if($i ~ /[0-9]+\.[0-9]+(Mi|Gi|Ki)?B/ || $i ~ /~[0-9]+/ || $i ~ /[0-9]+(Mi|Gi|Ki)?B/) {
                filesize = $i
                break
            }
        }
        if(filesize == "") filesize = "unknown"
        
        printf "%-8s %-8s %-12s %-8s %-12s %-15s\n", $1, $2, $3, $4, filesize, type
    }' | head -20
    
    echo "================================================================"
    echo "TIPS:"
    echo "• For best quality: use 'best' or press Enter"
    echo "• For video+audio: combine formats like '137+140' (video+audio)"
    echo "• 'bestvideo+bestaudio' gets best of each and merges them"
    echo "• Formats marked 'combined' already have video+audio"
    echo "================================================================"
    echo "Enter format choice:"
    read -r format_choice
    
    if [ -z "$format_choice" ]; then
        format_choice="bestvideo+bestaudio/best"
    fi
    
    echo "Downloading with format: $format_choice"
    
    # Get the filename that will be used
    local filename=$(yt-dlp --get-filename -f "$format_choice" -o "%(title)s.%(ext)s" --merge-output-format mp4 "$url" 2>/dev/null)
    local full_path="$HOME/Downloads/yt-dlp/$filename"
    
    # Download with chosen format - optimized for speed + resumable
    yt-dlp -f "$format_choice" \
           -o "$HOME/Downloads/yt-dlp/%(title)s.%(ext)s" \
           --continue \
           --no-overwrites \
           --retries 10 \
           --fragment-retries 10 \
           --external-downloader aria2c \
           --external-downloader-args "-x 8 -s 8 -j 8 --continue=true --file-allocation=none --retry-wait=1 --max-tries=5" \
           --keep-fragments \
           --write-info-json \
           --merge-output-format mp4 \
           "$url"
    
    if [ $? -eq 0 ]; then
        echo "Download completed successfully!"
        echo "File saved to: $full_path"
        
        # Clean up info.json file
        local info_file="${full_path%.*}.info.json"
        if [ -f "$info_file" ]; then
            rm "$info_file"
            echo "Cleaned up metadata file: $info_file"
        fi
        
        # Send desktop notification
        local file_name=$(basename "$full_path")
        notify-send "Video Download Complete" "Downloaded: $file_name" --app-name=YTDL --icon=video-x-generic --urgency=normal --expire-time=5000
    else
        echo "Download failed!"
        # Send failure notification
        notify-send "Video Download Failed" "Failed to download video" --app-name=YTDL --icon=dialog-error --urgency=critical --expire-time=8000
        return 1
    fi
}

# launch a http server
lsrv() {
    local directory="${1:-.}"  # Default to current directory if no argument provided
    local port="${2:-5000}"    # Default to port 5000 if no port specified
    
    # Check if directory exists
    if [[ ! -d "$directory" ]]; then
        echo "Error: Directory '$directory' does not exist"
        return 1
    fi
    
    echo "Starting HTTP server in directory: $(pwd)"
    echo "Server will be available at: http://localhost:$port"
    echo "Press Ctrl+C to stop the server"
    
    if command -v python3 &> /dev/null; then
        python3 -m http.server "$port" --directory "$directory"
    else
        echo "Error: Python is not installed or not in PATH"
        return 1
    fi
}

jnb() {
    source ~/anaconda3/bin/activate && jupyter-notebook
}

pyr() {
    local FORCE=false
    local REPLY

    local usage
    usage() {
        echo "Usage: release [options] VERSION"
        echo
        echo "VERSION:"
        echo "  major: bump major version number"
        echo "  minor: bump minor version number"
        echo "  patch: bump patch version number"
        echo
        echo "Options:"
        echo "  -f, --force:  force release"
        echo "  -h, --help:   show this help message"
        return 1
    }

    # parse args
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -f | --force)
            FORCE=true
            shift
            ;;
        -h | --help)
            usage
            return $?
            ;;
        *)
            break
            ;;
        esac
    done

    # check if version is specified
    if [ "$#" -ne 1 ]; then
        usage
        return $?
    fi

    if [ "$1" != "major" ] && [ "$1" != "minor" ] && [ "$1" != "patch" ]; then
        usage
        return $?
    fi

    # resolve repo root from cwd (walks up to find pyproject.toml)
    local repo_root
    repo_root="$(pwd)"
    while [ "$repo_root" != "/" ] && [ ! -f "$repo_root/pyproject.toml" ]; do
        repo_root="$(dirname "$repo_root")"
    done
    if [ ! -f "$repo_root/pyproject.toml" ]; then
        echo "Error: could not find repo root (no pyproject.toml found)"
        return 1
    fi

    # check if git is clean and force is not enabled
    if ! git -C "$repo_root" diff-index --quiet HEAD -- && [ "$FORCE" = false ]; then
        echo "Error: git is not clean. Please commit all changes first."
        return 1
    fi

    if ! command -v uv &> /dev/null; then
        echo "Error: uv is not installed. Please install uv from https://docs.astral.sh/uv/"
        return 1
    fi

    echo "Would bump version:"
    (cd "$repo_root" && uv version --bump "$1" --dry-run)

    # prompt for confirmation
    if [ "$FORCE" = false ]; then
        read -p "Do you want to release? [yY] " -n 1 -r REPLY
        echo
    else
        REPLY="y"
    fi

    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$repo_root"
        uv version --bump "$1"
        local new_version
        new_version=$(uv version --short)
        git add . 
        git commit -m "bump version to $new_version"
        git tag -a "v$new_version" -m "v$new_version"
        git push origin main
        git push origin "v$new_version"
    else
        echo "Aborted."
        return 1
    fi
}

cleanall() {
    setopt local_options null_glob

    # Asks "<step>? [y/N]"; only y/Y runs the step, anything else skips it
    _cleanall_ask() {
        local reply
        read "reply?$1? [y/N] "
        [[ $reply == [yY]* ]]
    }

    local before=$(df --output=avail -B1M / | tail -1)

    if _cleanall_ask "Clean DNF cache"; then
        sudo dnf clean all
    fi

    if _cleanall_ask "Remove orphaned packages"; then
        sudo dnf autoremove -y
    fi

    if _cleanall_ask "Remove unused Flatpak runtimes"; then
        flatpak uninstall --unused -y
    fi

    if _cleanall_ask "Vacuum systemd journal (keep last 2 weeks)"; then
        sudo journalctl --vacuum-time=2weeks
    fi

    if _cleanall_ask "Delete rotated logs in /var/log (e.g. messages-20260927)"; then
        sudo find /var/log -maxdepth 2 -type f -regextype posix-extended \
            -regex '.*-[0-9]{8}(\.gz)?' -print -delete
    fi

    if _cleanall_ask "Delete temp files untouched for 1+ day in /tmp and /var/tmp"; then
        # -xdev skips AppImage mounts; systemd-private-* belongs to running services
        sudo find /tmp /var/tmp -xdev -mindepth 1 -not -path '*/systemd-private-*' \
            -type f -mtime +1 -delete
    fi

    if _cleanall_ask "Remove old kernels (keeps the running and newest ones)"; then
        sudo dnf remove -y --oldinstallonly
    fi

    if _cleanall_ask "Empty ~/.cache (apps rebuild it; first launches are slower)"; then
        # some tools (dotslash) unpack read-only files that rm can't delete
        chmod -R u+w ~/.cache 2>/dev/null
        rm -rf ~/.cache/*(D)
    fi

    if _cleanall_ask "Clear Flatpak app caches: Spotify, Chrome, Brave, Edge... (close them first)"; then
        local app
        for app in ~/.var/app/*/cache(/); do
            echo "cleared ${${app:h}:t} ($(du -sh $app | cut -f1))"
            rm -rf $app/*(D)
        done
    fi

    if _cleanall_ask "Prune Docker and Podman (stopped containers, unused images and networks)"; then
        command -v docker >/dev/null && docker system prune -af
        command -v podman >/dev/null && podman system prune -af
    fi

    if _cleanall_ask "Clean JS package caches (pnpm store prune, npm, yarn)"; then
        command -v pnpm >/dev/null && pnpm store prune && rm -rf ~/.cache/pnpm
        command -v npm >/dev/null && npm cache clean --force && rm -rf ~/.npm/_npx
        command -v yarn >/dev/null && yarn cache clean
    fi

    if _cleanall_ask "Clean Python package caches (pip, uv, conda)"; then
        command -v pip >/dev/null && pip cache purge
        command -v uv >/dev/null && uv cache clean
        [[ -x ~/anaconda3/bin/conda ]] && ~/anaconda3/bin/conda clean --all -y
    fi

    if _cleanall_ask "Clean Go build cache and ghcup cache"; then
        command -v go >/dev/null && go clean -cache
        command -v ghcup >/dev/null && ghcup gc --cache --tmpdirs
    fi

    if _cleanall_ask "Clear JetBrains caches (close your IDEs first)"; then
        rm -rf ~/.cache/JetBrains/*
    fi

    if _cleanall_ask "Remove old VS Code extension versions"; then
        python3 -I -c '
import json, os, shutil
d = os.path.expanduser("~/.vscode/extensions")
keep = {os.path.basename(e["location"]["path"]) for e in json.load(open(d + "/extensions.json"))}
for n in sorted(os.listdir(d)):
    if os.path.isdir(os.path.join(d, n)) and n not in keep:
        print("removed", n)
        shutil.rmtree(os.path.join(d, n))'
        rm -rf ~/.config/Code/CachedExtensionVSIXs/*
    fi

    if _cleanall_ask "Remove old Codex versions (keeps current and running ones)"; then
        local pkg rel cur
        for pkg in ~/.codex/packages/*(/); do
            cur=$pkg/current
            for rel in $pkg/releases/*(/); do
                [[ ${rel:A} == ${cur:A} ]] && continue
                pgrep -f "releases/${rel:t}/" >/dev/null && continue
                echo "removed ${pkg:t}/${rel:t}"
                rm -rf "$rel"
            done
        done
    fi

    if _cleanall_ask "Remove old Claude Code versions (keeps the current one)"; then
        local v cur=~/.local/bin/claude
        cur=${cur:A}
        for v in ~/.local/share/claude/versions/*(.); do
            [[ $v == $cur ]] && continue
            echo "removed claude ${v:t}"
            rm -f "$v"
        done
    fi

    if _cleanall_ask "Remove clean Claude agent worktrees in ~/Code (keeps their branches)"; then
        # only worktrees without uncommitted changes to tracked files go;
        # untracked files like a node_modules link don't count
        local wt
        for wt in ~/Code/**/.claude/worktrees/*(/N); do
            if [[ -z $(git -C $wt status --porcelain --untracked-files=no 2>/dev/null) ]]; then
                git -C $wt worktree remove --force $wt && echo "removed $wt"
            else
                echo "kept $wt (uncommitted changes)"
            fi
        done
    fi

    if _cleanall_ask "Delete node_modules in ~/Code projects with no commits for 30+ days"; then
        # judged by the repo's last commit, not the folder's date: workspace
        # packages in an active monorepo keep old node_modules dates
        local nm last cutoff
        zmodload zsh/datetime
        cutoff=$(( EPOCHSECONDS - 30 * 86400 ))
        for nm in ${(f)"$(find ~/Code -xdev -type d -name node_modules -prune -print)"}; do
            last=$(git -C ${nm:h} log -1 --format=%ct 2>/dev/null)
            [[ -z $last ]] && last=$(stat -c %Y $nm)
            (( last > cutoff )) && continue
            echo "removed $nm ($(du -sh $nm | cut -f1))"
            rm -rf $nm
        done
    fi

    unfunction _cleanall_ask
    local after=$(df --output=avail -B1M / | tail -1)
    printf 'All cleanup tasks completed. Freed %.1f GB, %.1f GB free.\n' \
        $(( (after - before) / 1024.0 )) $(( after / 1024.0 ))
}

vagrant() { PATH=/usr/bin:$PATH command vagrant "$@"; }

# Normal aliases
alias zshcfg="nvim ~/.zshrc"
alias zshsrc="source ~/.zshrc"
alias cls="clear"
alias nvcfg="nvim ~/.config/nvim"
alias ccflags='echo "--std=c23" > compile_flags.txt'
alias dnfup='sudo dnf -y update && sudo dnf -y --refresh upgrade'

# AI
alias cld="claude"
alias oc="opencode"

# K8s
alias k8="minikube kubectl --"
alias k8gn="k8 get namespaces"
alias k8gs="k8 get po -n kube-system"

# Tmux
alias tnns="tmux new -s" # Start a new named session
alias tans="tmux a -t" # Attach to named session
alias tnas="tmux new-session -A -s" # Start a new named session or attach to a named existing session 
alias tkns="tmux kill-session -t" # Kill named session
alias tkase="tmux kill-session -a -t" # Kill all sessions except ---
alias tkaec="tmux kill-session -a" # Kill all except current session
alias tlas="tmux ls" # List sessions

# PostgreSQL
alias pgup="sudo systemctl stop postgresql"
alias pgdown="sudo systemctl stop postgresql"
alias pgss="sudo systemctl status postgresql"

## Redis
alias rup="redis-server"

## Apps
alias co="code ."

## Git
alias ga="git add"
alias gac="git add . && git commit -m"
alias gbd="git branch -D"
alias gb="git branch"
alias gch="git checkout"
alias gcl="git clone"
alias gfo="git fetch origin"
alias gfpl="gfo && gpl"
alias gi="git init"
alias glog="git log"
alias gpl="git pull origin"
alias gph="git push -u origin"
alias gra="git remote add origin"
alias grlog="git reflog"
alias grs="git remote show origin"
alias gs="git status"
alias gsw="git switch"

# Python
alias avenv="source ./.venv/bin/activate"

# Elixir/Phoenix
alias hdsrv="lsrv ~/.hex/docs/hexpm"
alias hdf="mix hex.docs fetch"

alias mdg="mix deps.get"
alias mdgc="mix do deps.get, deps.compile"
alias mecm="mix do ecto.create, ecto.migrate"
alias mem="mix ecto.migrate"
alias med="mix ecto.drop"
alias mft="mix format"
alias mn="mix new" 
alias mt="mix test"
alias mrl="mix release"

alias phi="mix archive.install hex phx_new"
alias phn="mix phx.new"
alias phs="mix phx.server"
alias phsi="iex -S mix phx.server"

# Go
alias gmod="go mod"
alias gmodi="gmod init"
alias gmodt="gmod tidy"
alias grun="go run"
alias gvet="go vet"
alias gget="go get"
alias gil="go install"
alias gpkg="pkgsite -open ."


# Ruby/Rails
alias bdev="bin/dev"
alias rc="rails c"
alias rdc="rails db:create"
alias rdm="rails db:migrate"
alias rdr="rails db:rollback"
alias rds="rails db:seed"
alias rgc="rails g controller"
alias rgm="rails g model"
alias rnew="rails new"
alias rgnew="gem exec nextgen create"
alias rs="rails s"

# Rust
alias cad="cargo add"
alias cadd="cargo add --dev"
alias cbd="cargo build"
alias ccl="cargo clean"
alias ccfmt="cargo clippy -- -W clippy::cargo"
alias cin="cargo install"
alias cfmt="cargo fmt"
alias cfx="cargo fix"
alias cfxc="cfx --clippy"
alias cip="cin --path ."
alias cnew="cargo new"
alias crun="cargo run"
alias ct="cargo test" 
alias ctdx="cargo testdox"
alias cw="cargo ws"
alias rsrv="lsrv ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/share/doc/rust/html 5005"

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# pnpm
export PNPM_HOME="/home/danielbrai/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
alias lzd='lazydocker'

[ -f "/home/danielbrai/.ghcup/env" ] && . "/home/danielbrai/.ghcup/env" # ghcup-env

# bun completions
[ -s "/home/danielbrai/.bun/_bun" ] && source "/home/danielbrai/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# Load Angular CLI autocompletion.
source <(ng completion script)

# opencode
export PATH=/home/danielbrai/.opencode/bin:$PATH

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/home/danielbrai/.opam/opam-init/init.zsh' ]] || source '/home/danielbrai/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null; true
# END opam configuration

# TLA+ tools (tla2tools.jar v1.8.0; v1.7.4 kept as tla2tools-1.7.4.jar)
export TLA2TOOLS="$HOME/.local/share/tla/tla2tools.jar"
alias tlc='java -XX:+UseParallelGC -cp "$TLA2TOOLS" tlc2.TLC'
alias pcal='java -cp "$TLA2TOOLS" pcal.trans'
