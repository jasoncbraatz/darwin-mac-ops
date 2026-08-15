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
export LESSONS_CONTRIBUTOR=opus

# >>> machine-local / personal settings (acmeLedger-19, 2026-08-15) >>>
# This file is symlinked from jasoncbraatz/darwin-mac-ops, which is a PUBLIC repo.
# Anything personal (locations, client names, machine-specific paths, anything you
# would not put on the internet) goes in ~/.zshrc.local, which is NOT repo-backed
# and never leaves this Mac. Repo-backing the config must not mean publishing you.
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
# <<< machine-local / personal settings <<<

# >>> nvm + per-repo node (acmeLedger-19, 2026-08-15) >>>
# WHY: darwin ran homebrew node 25.x while flowers' CI and production both run what
# .nvmrc says (22.9.0). node 24 removed buffer.SlowBuffer, so jwa/jsonwebtoken throw
# ON IMPORT and `npm run preflight` reported test:sms RED on darwin as a PHANTOM —
# green in CI the whole time. Card 1217515727428281.
#
# DESIGN: homebrew node stays the machine default ON PURPOSE — other things here
# depend on it (opencode-ai, puppeteer-core, and the TCC network-volumes grant that
# is pinned to /opt/homebrew/Cellar/node/<ver>/bin/node). nvm is loaded with
# --no-use so it costs ~nothing at startup and does NOT change your node; the hook
# below switches ONLY inside a directory tree that declares a .nvmrc, and switches
# back on the way out.
#
# NON-INTERACTIVE shells (dx, ssh, LaunchAgents) never source this file — use
# `~/Scripts/with-nvmrc <cmd>` there. Same effect, one verb, no rule to remember.
#
# ROLLBACK: restore ~/.zshrc.bak-acmeLedger19-* (and `rm -rf ~/.nvm` to undo nvm).
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  autoload -U add-zsh-hook
  _nvmrc_load() {
    local nvmrc_path nvmrc_ver
    nvmrc_path="$(nvm_find_nvmrc 2>/dev/null)"
    if [ -n "$nvmrc_path" ]; then
      nvmrc_ver="$(nvm version "$(cat "$nvmrc_path")" 2>/dev/null)"
      if [ "$nvmrc_ver" = "N/A" ]; then
        # Say so. Silently running the wrong node is the bug this block exists to kill.
        echo "nvm: $nvmrc_path wants $(cat "$nvmrc_path") — not installed. Run: nvm install"
      elif [ "$nvmrc_ver" != "$(nvm version current 2>/dev/null)" ]; then
        nvm use --silent >/dev/null
      fi
    elif [ -n "${NVM_BIN:-}" ]; then
      nvm deactivate --silent >/dev/null 2>&1   # left the tree: hand node back to homebrew
    fi
  }
  add-zsh-hook chpwd _nvmrc_load
  _nvmrc_load
fi
# <<< nvm + per-repo node (acmeLedger-19, 2026-08-15) <<<
