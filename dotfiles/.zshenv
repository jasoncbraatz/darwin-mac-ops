
# >>> opus path fix (homebrew/gh) >>>
# Make non-interactive/ssh zsh sessions see Homebrew tools (gh, etc.).
# Interactive/login shells already get this via .zprofile/.zshrc.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
# <<< opus path fix (homebrew/gh) <<<

# >>> opus path fix (TeX Live + ~/bin/pandoc) — added 2026-06-18 Phase 16 >>>
# TeX Live 2026 lives at /Library/TeX/texbin; pandoc at ~/bin. Non-interactive ssh
# zsh sessions didn't see them (prior 'MISSING' false alarm). Reversible: ~/.zshenv.bak-prephase16.
export PATH="/Library/TeX/texbin:$HOME/bin:$PATH"
# <<< opus path fix (TeX Live + ~/bin/pandoc) <<<

# Distilled 2026-07-14 (replaces 4 blackbook zsh-glob leaves): non-interactive shells
# (ssh MCP, scripts) treat unmatched globs like bash — pass literally, never abort the line.
# Interactive shells keep zsh's default. Rollback: restore ~/.zshenv.bak-nonomatch-20260714
[[ -o interactive ]] || setopt no_nomatch

# deskTenancy-04 (2026-09-02): ~/Scripts on PATH for NON-login shells too — dx runs `zsh -c`, which reads
# .zshenv but not .zprofile, so every cloud session got 'command not found: architect-audit' until it
# remembered the full path. One line here retires that tax for every future session.
case ":$PATH:" in *":$HOME/Scripts:"*) ;; *) export PATH="$PATH:$HOME/Scripts" ;; esac

# wisdomDogfood (2026-09-11, ruling #280): the SHELL injects WISDOM_URL so `lessons.py search`
# eats from the vector store. lessons.py is NOT changed — it only reads the environment, so
# `env -u WISDOM_URL` is still byte-identical to the pre-dogfood world (verify-wisdomvector line 4).
# Every zsh reads .zshenv (interactive, -c, ssh, dx, rail-runner children), which is the whole point:
# before this line, store-mode in production was 0%. Undo: rm ~/.config/lessons/wisdom.env.
if [ -r "$HOME/.config/lessons/wisdom.env" ]; then . "$HOME/.config/lessons/wisdom.env"; fi
