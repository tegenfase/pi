# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000000
SAVEHIST=1000000
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/supercollider/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Fix encoding issues over SSH
export TERM=xterm

# Get sclang without X?
export DISPLAY=0

# Set supercollider in and outputs
export SC_JACK_DEFAULT_INPUTS="system:capture_1,system:capture_2"
export SC_JACK_DEFAULT_OUTPUTS="system:playback_1,system:playback_2"


# Supercollider
# start tmux session and boot jack & sclang
alias sc='xvfb-run sclang'


if [ -z "$TMUX" ]
then
	tmux attach -t tmux:0 || tmux new -s tmux scsynth -u 57110  \; neww -a -d -n supercollider ~/start_server.sh\; attach 
fi


alias config='/usr/bin/git --git-dir=/home/supercollider/.git/ --work-tree=/home/supercollider'
