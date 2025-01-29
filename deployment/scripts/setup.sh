#!/bin/bash
#
# ${deploy_dir} is set by Ansible and represents the directory where the script is executed.
# No need to set a default for ${deploy_dir} since it's provided by Ansible.
# You have to have something (MODE for example ) to pass into the script so you can use the Options {install| uninstall| update}. Install is the default.
# **** IMPORTANT*****  MODE has to stand for NULL ("") so the if an Option is selecet then the it will excicute the default is install. ****

if [[ ${MODE} = "" ]]; then
   MODE="install"
fi

##################################################################################################################

echo "MODE=${MODE}" # Testing to see if install or uninstall comes across
echo "Deployment Directory=${deploy_dir}"  # Confirming the directory set by Ansible
echo "EMAIL=${EMAIL}" #Email recipient

SCRIPT="${deploy_dir}/visual_cobol_v10.sh"
#SCRIPT="./visual_cobol_v10.sh"

case ${MODE} in
    install|uninstall|update)
        echo "Switching to ${MODE} mode..."
        EMAIL=${EMAIL} ${SCRIPT} ${MODE}
        ;;
    *)
        echo "Invalid mode. Usage: $0 {install|uninstall|update}"
        exit 1
        ;;
esac
