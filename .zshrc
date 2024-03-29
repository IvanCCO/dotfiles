plugins=(git zsh-autosuggestions alias-finder docker docker-compose docker-machine jsontools history kubectl emoji encode64 copyfile)


# Tenho que fazer um scriptzinho para ele commitar com a mensagem e se der erro
# ele tentar dnv so que com minhas credenciais. Ou eu posso só criar uma 
# credencial definitiva ai ele sempre vai dar o push no repositorio com 
# a credencial



# Funcao para fazer o commit e o push
git_push_schedule() {
  mensagem="$1"
  at 00:01 tomorrow <<EOF
    git commit -m "$mensagem"
    git push
EOF
}

reminder(){
  echo "
    █████╗     ██████╗     ██████╗     
    ██╔══██╗    ██╔══██╗    ██╔══██╗    
    ███████║    ██║  ██║    ██║  ██║    
    ██╔══██║    ██║  ██║    ██║  ██║    
    ██║  ██║    ██████╔╝    ██████╔╝    
    ╚═╝  ╚═╝    ╚═════╝     ╚═════╝     
  "
}



# Alias 
alias kctx="kubectx"
alias kns="kubens"
alias k="kubectl"
alias audio="qjackctl"
alias jpt="jupyter lab --app-dir /home/linuxbrew/.linuxbrew/share/jupyter/lab"


# TODO Push does not change the hour of the commit so it must create a function to commit 
# and push on the next day
alias push-tomorrow="reminder; echo 'git push' | at 00:01 tomorrow"
alias python="python3"
alias pip="pip3"
alias v="nvim"
alias vconfig="nvim ~/.config/nvim/init.lua"
alias push_tomorrow="reminder; git_push_schedule"

