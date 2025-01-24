#!/bin/bash

###############################################################################################################
# Description:
# This script automates the installation and uninstallation of <Applicaton Name>.
# It dynamically sets the installation log file based on the detected <Applicaton Name> tarball
# and performs cleanup during uninstallation.
#
# Usage:
# To install <Applicaton Name>, place the <Applicaton Name> tarball in the same directory as this script
# and run: ./<Applicaton Name>.sh
# To uninstall <Applicaton Name>, simply run: ./<Applicaton Name>.sh uninstall
# To update <Applicaton Name> replace the compressed file, repackage to nexus and then simply run: ./<Applicaton Name>.sh update
###############################################################################################################

## Common Variables #############################################################################################
VERSION='6.0'
EMAIL="christopher.g.pouliot@gmail.com,${EMAIL}"

### Variables that Do Not Change Much ######
LOGDIR="/tmp"
TMPDIR=/opt/app/tmp/microfocus
DATE="$(date '+%Y-%m-%d %H:%M:%S')"


## Common Functions  #############################################################################################

log() {
    echo "${DATE} - $1" | tee -a "${LOGDIR}/${LOG_FILE}"
}

send_email() {
    echo 'Sending-email notification...'
    EMAIL_SUBJECT="${HOSTNAME}: ${LOG_FILE} successfully."
    cat "${LOGDIR}/${LOG_FILE}" | mailx -S replyto=no_reply@irs.gov -s "${EMAIL_SUBJECT}" ${EMAIL}
}


## Check Variables ###############################################################################################
echo "Deployment Directory=${deploy_dir}"
echo "${NODE_VERSION}"
echo "DATE=${DATE}"
echo "${EMAIL}"

##Place Main Function or Script in this area ####################################################################


## Install ### Place main install commands here.
install() {
    log "Starting installation..."

    # Ensure TMPDIR exists
    mkdir -p "$TMPDIR"

    if [[ -d /opt/microfocus/VisualCOBOL/bin ]]; then
        echo "Visual COBOL already installed. Uninstall it first before proceeding."
        exit 1
    fi

    # Move necessary files
    mv ${deploy_dir}/bash_profile $TMPDIR
    mv ${deploy_dir}/Visual_COBOL_for_Eclipse.mflic $TMPDIR
    mv ${deploy_dir}/setup_visualcobol_deveclipse_6.0_redhat_x86_64 $TMPDIR

    # Set Variables
    TODAY=$(date +"%m%d%Y")
    logfile=Visual_COBOL_60_install.log

    # Create user account if needed
    grep asfrsvc /etc/passwd > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Creating asfrsvc account..."
        /usr/sbin/useradd -g xbag-dev-devl-asfr -d /home/asfrsvc -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" asfrsvc
        mv /home/asfrsvc/.bash_profile /home/asfrsvc/.bash_profile.$TODAY
        cp -p $TMPDIR/bash_profile /home/asfrsvc/.bash_profile
        chown -R asfrsvc:xbag-dev-devl-asfr /home/asfrsvc
    fi

    # Disable SELinux temporarily
    cp -p /etc/selinux/config /etc/selinux/config.bak.$TODAY
    sed -i 's/^SELINUX=enforcing/#SELINUX=enforcing/' /etc/selinux/config
    sed -i '/#SELINUX=enforcing/a SELINUX=disabled' /etc/selinux/config

    # Install required libraries
    yum install -y gcc.x86_64 glibc-*.i686 glibc-*.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 libXtst-1.2.3-7.el8.i686 > $LOGDIR/libinstall.log

    # Perform installation
    chmod 755 $TMPDIR/setup_visualcobol_deveclipse_6.0_redhat_x86_64
    $TMPDIR/setup_visualcobol_deveclipse_6.0_redhat_x86_64 -silent -IacceptEULA -installlocation="/opt/microfocus/VisualCOBOL" >> $LOGDIR/$logfile

    # Install license
    /opt/microfocus/VisualCOBOL/bin/cesadmintool.sh -install $TMPDIR/Visual_COBOL_for_Eclipse.mflic >> $LOGDIR/$logfile

    # Clean up
    chmod -R 775 /opt/microfocus
    chown -R asfrsvc:xbag-dev-devl-asfr /opt/microfocus

    log "Installation completed."
}


## Uninstall ##
uninstall() {
    log "Starting uninstallation..."

    # Ensure TMPDIR exists
    mkdir -p "$TMPDIR"

    # Set Variables
    logfile=Visual_COBOL_Uninstall.log

    # Source environment variables
    . /opt/microfocus/VisualCOBOL/bin/cobsetenv >> $LOGDIR/$logfile

    # Perform uninstallation
    echo "yes" | /opt/microfocus/VisualCOBOL/bin/Uninstall_VisualCOBOLEclipse6.0.sh >> $LOGDIR/$logfile

    # Remove user account and directories
    /usr/sbin/userdel asfrsvc
    rm -rf /opt/microfocus /home/asfrsvc

    # Revert SELinux configuration
    sed -i 's/^#SELINUX=enforcing/SELINUX=enforcing/' /etc/selinux/config
    sed -i '/SELINUX=disabled/d' /etc/selinux/config

    log "Uninstallation completed."
}


## Update ##
update() {  } # Place main update commands here.



## Main Execution Logic #############################

case "$MODE" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    update)
        update
        ;;
    *)
        echo "Invalid mode. Usage: MODE={install|uninstall|update} $0 or $0 {install|uninstall|update}"
        exit 1
        ;;
esac