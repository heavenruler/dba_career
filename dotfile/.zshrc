HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

function preexec() {
  timer=${timer:-$SECONDS}
}

function precmd() {
  if [ $timer ]; then
    timer_show=$(($SECONDS - $timer))
    export RPROMPT="%F{cyan}${timer_show}s %{$reset_color%}"
    unset timer
  fi
}

alias history="history 1 -1"
alias ba1="ssh wnlin@wnlin@172.30.35.192@172.29.22.221"
alias ba2="ssh wnlin@wnlin@172.30.36.192@172.29.22.221"
alias bas1="ssh wnlin@wnlin@172.21.47.1@172.29.22.221"
alias bas2="ssh wnlin@wnlin@172.21.47.2@172.29.22.221"
alias bad1="ssh wnlin@wnlin@172.26.46.1@172.29.22.221"
alias bad2="ssh wnlin@wnlin@172.26.46.2@172.29.22.221"
alias grep="grep -v grep | grep "
alias ssh="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "
alias push="git add . ; git commit -m 'update' ; git push"
alias hist="history"
alias gitu="git pull -v"
alias sslawsdev="ssh wnlin@10.153.137.129"
alias pxcn="ssh root@pxc-n-1.104-dev.com.tw"
alias laba="ssh root@172.19.253.251"
alias gitz="git add .; git commit -m 'update'; git push"
alias gitu="git pull -v"
alias mountsmb="mount_smbfs \"//e104tw;wn.lin:$smbpwd@10.1.5.21/wn.lin\" ~/smb"
alias umountsmb="umount /Users/wn.lin/smb"
alias awssslsys="aws ssm start-session --target i-00b9ec60e741d701e --profile DBA-SYS49"
alias awssys49="aws ssm start-session --target i-00b9ec60e741d701e --region ap-northeast-1"
alias awssslstg="aws ssm start-session --target i-0e8a8f314f5161b72 --profile DBA-STG49"
alias pa="cd /Users/wn.lin/git;ls | xargs -P10 -I{} git -C {} pull;cd dba-documents"
export PATH="/opt/homebrew/opt/php@7.4/bin:$PATH"
export PATH="/opt/homebrew/opt/php@7.4/sbin:$PATH"
