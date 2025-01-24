# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
# Cobol variables and parameters
. /opt/microfocus/VisualCOBOL/bin/cobsetenv

COBSW=-F
export COBSW

PATH=$PATH:$COBDIR/bin
export PATH
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$COBDIR/lib
export LD_LIBRARY_PATH

cd /opt/microfocus
