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
EMAIL="christopher.g.pouliot@gmail.com,${EMAIL}"
INSTALLDIR="/opt/microfocus/VisualCOBOL"
USER_ACCOUNT="asfrsvc"
LICENSE='Visual_COBOL_for_Eclipse.mflic'
INSTALL_BINARIES='setup_visualcobol_deveclipse_6.0_redhat_x86_64'
UNINSTALL_BINARIES='Uninstall_VisualCOBOLEclipse6.0.sh'

## Variables that Do Not Change Much ######
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
    log 'Sending-email notification...'
    EMAIL_SUBJECT="${HOSTNAME}: ${LOG_FILE} successfully."
    mailx -S replyto=no_reply@irs.gov -s "${EMAIL_SUBJECT}" "${EMAIL}" < "${LOGDIR}/${LOG_FILE}"
}

install_yum_packages() {
    # YUM Installation Sequence.
    log "Starting YUM Installation..."
    if ! yum install -y "${YUM_PACKAGES}" 2>&1 | tee -a "${LOGDIR}/${LOG_FILE}"; then
        log "Failed to install prerequisites. Exiting."
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
    LOG_FILE="${INSTALL_BINARIES}-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"


    if [[ -d "${INSTALLDIR}"/bin ]]; then
        log "Visual COBOL already installed. Uninstall it first before proceeding."
        exit 1
    fi

    log Install required libraries
    install_yum_packages

    log Dynamically locate required files for installation
    BASH_PROFILE_FILE=$(find . -name "bash_profile" -type f 2>/dev/null)
    LICENSE_FILE=$(find . -name "${LICENSE}" -type f 2>/dev/null)
    INSTALL_BINARIES_FILE=$(find . -name "${INSTALL_BINARIES}" -type f 2>/dev/null)

    log Validate that files are found before proceeding
    if [[ -z "${BASH_PROFILE_FILE}" || -z "${LICENSE_FILE}" || -z "${INSTALL_BINARIES_FILE}" ]]; then
        echo "Error: Required files not found in the current directory or subdirectories."
        echo "Missing files:"
        [[ -z "${BASH_PROFILE_FILE}" ]] && echo "  - bash_profile"
        [[ -z "${LICENSE_FILE}" ]] && echo "  - ${LICENSE}"
        [[ -z "${INSTALL_BINARIES_FILE}" ]] && echo "  - ${INSTALL_BINARIES}"
        exit 1
    fi
   
    log Create user account if needed
    if ! grep -q "${USER_ACCOUNT}" /etc/passwd; then
        log "Creating ${USER_ACCOUNT} account..."
        /usr/sbin/useradd -g xbag-dev-devl-asfr -d "/home/${USER_ACCOUNT}" -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" "${USER_ACCOUNT}"
        mv "/home/${USER_ACCOUNT}/.bash_profile" "/home/${USER_ACCOUNT}/.bash_profile.${DATE}"
        cp -p "${BASH_PROFILE_FILE}" "/home/${USER_ACCOUNT}/.bash_profile"
        chown -R "${USER_ACCOUNT}:xbag-dev-devl-asfr" "/home/${USER_ACCOUNT}"
        log "${USER_ACCOUNT} Account created!"
    fi

    # Disable SELinux temporarily
    cp -p /etc/selinux/config "/etc/selinux/config.bak.${DATE}"
    sed -i 's/^SELINUX=enforcing/#SELINUX=enforcing/' /etc/selinux/config
    sed -i '/#SELINUX=enforcing/a SELINUX=disabled' /etc/selinux/config

    # Perform installation
    chmod 755 "${INSTALL_BINARIES_FILE}"
    "${INSTALL_BINARIES_FILE}" -silent -IacceptEULA -installlocation="${INSTALLDIR}" >> "${LOGDIR}/${LOG_FILE}"

    # Install license
    "${INSTALLDIR}/bin/cesadmintool.sh" -install "${LICENSE_FILE}" >> "${LOGDIR}/${LOG_FILE}"

    # Clean up
    chmod -R 775 /opt/microfocus
    chown -R "${USER_ACCOUNT}:xbag-dev-devl-asfr" /opt/microfocus
    
    log "${ACTION_PERFORMED} completed."
    send_email
}


## Uninstall ##
uninstall() {
    
    ACTION_PERFORMED='Uninstall'
    LOG_FILE="${UNINSTALL_BINARIES}-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"

    # Check source environment variables
    if [[ -f "${INSTALLDIR}/bin/cobsetenv" ]]; then
        . "${INSTALLDIR}/bin/cobsetenv" &>> "${LOGDIR}/${LOG_FILE}"
    else
        log "Error: Cannot find ${INSTALLDIR}/bin/cobsetenv. Exiting."
        exit 1
    fi


    # Uninstall Visual COBOL 
    if [[ -x "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" ]]; then
        log "yes" | "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" &>> "${LOGDIR}/${LOG_FILE}"
    else
        log "Uninstallation script not found or not executable!" >> "${LOGDIR}/${LOG_FILE}"
        exit 1
    fi

    # Validate USER_ACCOUNT
    if [[ -z "${USER_ACCOUNT}" ]]; then
        log "ERROR: USER_ACCOUNT is not set. Exiting."
        exit 1
    fi

    # Log the planned operations
    log "Deleting user account: ${USER_ACCOUNT}"
    log "Removing directories: /opt/microfocus /home/${USER_ACCOUNT}"

    # Perform the operations
    /usr/sbin/userdel "${USER_ACCOUNT}"
    rm -rf /opt/microfocus "/home/${USER_ACCOUNT:?}"

    # Revert SELinux configuration
    sed -i 's/^#SELINUX=enforcing/SELINUX=enforcing/' /etc/selinux/config
    sed -i '/SELINUX=disabled/d' /etc/selinux/config

    log "${ACTION_PERFORMED} completed."
    send_email
}


## Update ##
update() {  
    
    ACTION_PERFORMED='Updated'
    LOG_FILE="Visual_COBOL-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"
    
    #### UnInstall function ####
    uninstall

    #### Install function ####
    install

    log "${ACTION_PERFORMED} completed."
    send_email
} 

## Main Execution Logic #############################

case ${MODE} in
    install) install ;;
    uninstall) uninstall ;;
    update) update ;;
    *) log "Invalid mode. Usage: MODE=(install|uninstall|update)" ; exit 1 ;;
esac