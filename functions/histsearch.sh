# @name: histsearch
# @description: Fuzzy-search shell history with fzf and push the selection onto the command line
# @usage: histsearch
# @platform: zsh, fzf

histsearch() {
  local cmd
  cmd=$(
    fc -rl 1 | \
    fzf --height=40% --reverse --border \
        --prompt='history> ' \
        --bind 'ctrl-r:reload(eval "fc -rl 1")' \
        | sed 's/^[[:space:][:digit:]]*//'
  )

  [[ -n $cmd ]] && print -z -- "$cmd"
}
alias hs='histsearch'
