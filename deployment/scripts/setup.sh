#!/bin/bash
#
# ${deploy_dir} is set by Ansible and represents the directory where the script is executed.
# No need to set a default for ${deploy_dir} since it's provided by Ansible.
# You have to have something (MODE for example ) to pass into the script so you can use the Options {install| uninstall| update}. Install is the default.
# **** IMPORTANT*****  MODE has to stand for NULL ("") so the if an Option is selecet then the it will excicute the default is install. ****
#
# Ensure MODE is blanked out first
if [[ ${MODE} = "" ]]; then ## This makes sure MODE is blanked out.
   MODE="install" ## Install is default if $MODE is not set.
fi

# Function to capture multi-word values
capture_value() {
    local VAR_NAME=$1
    shift
    eval "$VAR_NAME=\"$1\""
    shift
    while [[ $# -gt 0 && "$1" != --* ]]; do
        eval "$VAR_NAME+=\" $1\""
        shift
    done
}

# Parse Additional Arguments
while [[ $# -gt 0 ]]; do
    ARG="${1,,}"  # Convert argument to lowercase for case insensitivity
    case "$ARG" in
        --email|-e)
            capture_value EMAIL "$@"
            shift
            ;;
        --mode|-m)
            capture_value MODE "$@"
            shift
            ;;
        *)
            echo "Invalid option: $1"
            echo "Usage: $0 --mode {install|uninstall|update} [--email <email>]"
            exit 1
            ;;
    esac
done  

# Confirm Variables for Debugging
echo "MODE: ${MODE}"
echo "Email: ${EMAIL:-None}"

# Execution (Ansible and Local Testing Compatibility)
SCRIPT="${deploy_dir}/visual_cobol_v10.sh" # Deploy with Ansible
#SCRIPT="./visual_cobol_v10.sh" # Local testing

EMAIL=${EMAIL} ${SCRIPT} "${MODE}"