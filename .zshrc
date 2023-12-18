plugins=(git zsh-autosuggestions alias-finder docker docker-compose docker-machine jsontools history kubectl emoji encode64 copyfile)

# Functions
reminder() {
  echo "
  ██████╗     ██████╗     ███╗   ███╗    ███╗   ███╗    ██╗    ████████╗
██╔════╝    ██╔═══██╗    ████╗ ████║    ████╗ ████║    ██║    ╚══██╔══╝
██║         ██║   ██║    ██╔████╔██║    ██╔████╔██║    ██║       ██║   
██║         ██║   ██║    ██║╚██╔╝██║    ██║╚██╔╝██║    ██║       ██║   
╚██████╗    ╚██████╔╝    ██║ ╚═╝ ██║    ██║ ╚═╝ ██║    ██║       ██║   
 ╚═════╝     ╚═════╝     ╚═╝     ╚═╝    ╚═╝     ╚═╝    ╚═╝       ╚═╝   
                                                                       
███████╗    ██╗    ██████╗     ███████╗    ████████╗                   
██╔════╝    ██║    ██╔══██╗    ██╔════╝    ╚══██╔══╝                   
█████╗      ██║    ██████╔╝    ███████╗       ██║                      
██╔══╝      ██║    ██╔══██╗    ╚════██║       ██║                      
██║         ██║    ██║  ██║    ███████║       ██║                      
╚═╝         ╚═╝    ╚═╝  ╚═╝    ╚══════╝       ╚═╝                      
                                                                       
"
}

# Alias 

alias kctx="kubectx"
alias kns="kubens"
alias audio="qjackctl"
alias push-tomorrow="reminder; echo 'git push' | at 00:01 tomorrow"

