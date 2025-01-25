#!/bin/bash

###############################################################################################################
# Description:
# This script automates the installation and uninstallation of Visual Cobal v6.0.
# It dynamically sets the installation log file based on the detected Visual Cobal v6.0 tarball
# and performs cleanup during uninstallation.
#
# Usage:
# To install Visual Cobal v6.0, place the Visual Cobal v6.0 tarball in the same directory as this script
# and run: ./Visual Cobal v6.0.sh
# To uninstall Visual Cobal v6.0, simply run: ./Visual Cobal v6.0.sh uninstall
# To update Visual Cobal v6.0 replace the compressed file, repackage to nexus and then simply run: ./Visual Cobal v6.0.sh update
###############################################################################################################

## Common Variables #############################################################################################
VERSION='6.0'
EMAIL="christopher.g.pouliot@gmail.com,${EMAIL}"
INSTALLDIR="/opt/microfocus/VisualCOBOL"
LICENSE='Visual_COBOL_for_Eclipse.mflic'
INSTALL_BINARIES='setup_visualcobol_deveclipse_6.0_redhat_x86_64'
UNINSTALL_BINARIES='Uninstall_VisualCOBOLEclipse6.0.sh'
### Variables that Do Not Change Much ######
LOGDIR="/tmp"
TMPDIR=/opt/app/tmp/microfocus
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
HOSTNAME="$(uname -n)"

YUM_PACKAGES="java-11-openjdk.x86_64 gcc.x86_64 spax.x86_64 glibc-*.i686 glibc-*.x86_64 glibc-devel-*.x86_64 glibc-devel.i686 libgcc-*.i686 libgcc-*.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 libstdc++-docs.x86_64 libstdc++.i686 libstdc++-devel.i686 gtk2-*.x86_64 libXtst-*.x86_64 libXtst-1.2.3-7.el8.i686 libcanberra-gtk3-0.30-18.el8.i686 libcanberra-gtk3-*.x86_64 PackageKit-gtk3-module-*.x86_64 webkit2gtk3.x86_64 xterm.x86_64 unzip.x86_64 cpp*x86_64"
## Common Functions  #############################################################################################

log() {
    echo "${DATE} - $1" | tee -a "${LOGDIR}/${LOG_FILE}"
}

send_email() {
    echo 'Sending-email notification...'
    EMAIL_SUBJECT="${HOSTNAME}: ${LOG_FILE} successfully."
    mailx -S replyto=no_reply@irs.gov -s "${EMAIL_SUBJECT}" ${EMAIL} < "${LOGDIR}/${LOG_FILE}"
}

Install_YUM_packages() {
    # YUM Installation Sequence.
    log "Starting YUM Installation..."
    yum install -y ${YUM_PACKAGES} 2>&1 | tee -a "${LOGDIR}/${LOG_FILE}"
    if [ $? -ne 0 ]; then
        log 'Failed to install prerequisites. Exiting.'
        exit 1
    fi
    log 'Prerequisites libraries installed successfully.'
}

## Check Variables ###############################################################################################
echo "Deployment Directory=${deploy_dir}"
echo "DATE=${DATE}"
echo "${EMAIL}"

##Place Main Function or Script in this area ####################################################################


## Install ### 
install() {
    
    ACTION_PERFORMED='Install and Verify'
    LOG_FILE="Visual_COBOL_${VERSION}-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"


    if [[ -d "${INSTALLDIR}"/bin ]]; then
        log "Visual COBOL already installed. Uninstall it first before proceeding."
        exit 1
    fi

    # Install required libraries
    Install_YUM_packages

    # Ensure TMPDIR exists
    mkdir -p "${TMPDIR}"

    # Move necessary files
    mv ${deploy_dir}/bash_profile "${TMPDIR}"
    mv ${deploy_dir}/"${LICENSE}" "${TMPDIR}"
    mv ${deploy_dir}/"${INSTALL_BINARIES}" "${TMPDIR}"
    
    # Create user account if needed
    grep asfrsvc /etc/passwd > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "Creating asfrsvc account..."
        /usr/sbin/useradd -g xbag-dev-devl-asfr -d /home/asfrsvc -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" asfrsvc
        mv /home/asfrsvc/.bash_profile /home/asfrsvc/.bash_profile."${DATE}"
        cp -p "${TMPDIR}/bash_profile" /home/asfrsvc/.bash_profile
        chown -R asfrsvc:xbag-dev-devl-asfr /home/asfrsvc
        log "asfrsvc Account created!"
    fi

    # Disable SELinux temporarily
    cp -p /etc/selinux/config /etc/selinux/config.bak."${DATE}"
    sed -i 's/^SELINUX=enforcing/#SELINUX=enforcing/' /etc/selinux/config
    sed -i '/#SELINUX=enforcing/a SELINUX=disabled' /etc/selinux/config

    # Perform installation
    chmod 755 "${TMPDIR}/${INSTALL_BINARIES}"
    "${TMPDIR}/${INSTALL_BINARIES}" -silent -IacceptEULA -installlocation="${INSTALLDIR}" >> "${LOGDIR}/${LOG_FILE}"

    # Install license
    "${INSTALLDIR}/bin/cesadmintool.sh" -install "${TMPDIR}/${LICENSE}" >> "${LOGDIR}/${LOG_FILE}"

    # Clean up
    chmod -R 775 /opt/microfocus
    chown -R asfrsvc:xbag-dev-devl-asfr /opt/microfocus
    
    log "${ACTION_PERFORMED} completed."
    send_email
}


## Uninstall ##
uninstall() {
    
    ACTION_PERFORMED='Uninstall'
    LOG_FILE="Visual_COBOL_${VERSION}-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"

    # Source environment variables
    . "${INSTALLDIR}/bin/cobsetenv" &>> "${LOGDIR}/${LOG_FILE}"

    # Uninstall Visual COBOL 
    if [[ -x "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" ]]; then
        log "yes" | "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" &>> "${LOGDIR}/${LOG_FILE}"
    else
        log "Uninstallation script not found or not executable!" >> "${LOGDIR}/${LOG_FILE}"
        exit 1
    fi

    # Remove user account and directories
    /usr/sbin/userdel asfrsvc
    rm -rf /opt/microfocus /home/asfrsvc

    # Revert SELinux configuration
    sed -i 's/^#SELINUX=enforcing/SELINUX=enforcing/' /etc/selinux/config
    sed -i '/SELINUX=disabled/d' /etc/selinux/config

    log "${ACTION_PERFORMED} completed."
    send_email
}


## Update ##
#update() {  } # Place main update commands here.



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