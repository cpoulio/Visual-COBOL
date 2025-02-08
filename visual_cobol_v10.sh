#!/bin/bash

###############################################################################################################
# Description:
# This script automates the installation and uninstallation of Visual Cobal v10.
# It dynamically sets the installation log file based on the detected Visual Cobal v10 tarball
# and performs cleanup during uninstallation.
#
# Usage:
# To install Visual Cobal place the Visual Cobal tarball in the same directory as this script
# and run: MODE=install ./VisualCobal_v10.sh
# To uninstall Visual Cobal, simply run: MODE=uninstall ./VisualCobal_v10.sh 
# To update Visual Cobal replace the compressed file, repackage to nexus and then simply run: ./Visual Cobal v10.sh update
#
# Default Visual Cobol log files are saved in /var/mfcobol/logs
################################################################################################################

## Common Variables #############################################################################################
EMAIL="christopher.g.pouliot@gmail.com,${EMAIL}"
INSTALLDIR="/opt/microfocus/VisualCOBOL"
USER_ACCOUNT="asfrsvc"
LICENSE='Visual_COBOL_for_Eclipse.mflic'
INSTALL_BINARIES="setup_visualcobol_deveclipse_10.0_redhat_x86_64"

## Variables that Do Not Change Much ######
LOGDIR="/tmp"
DATE="$(date '+%Y-%m-%d_%H:%M:%S')"
COBOL_VERSION=$("${INSTALLDIR}/bin/cob" --version 2>&1)

YUM_PACKAGES="java-11-openjdk.x86_64 gcc.x86_64 \
glibc-*.i686 glibc-*.x86_64 glibc-devel-*.x86_64 glibc-devel.i686 \
libgcc-*.i686 libgcc-*.x86_64 \
libstdc++.x86_64 libstdc++-devel.x86_64 libstdc++.i686 libstdc++-devel.i686 \
xterm.x86_64 \
gawk.x86_64 \
ed.x86_64 psmisc.x86_64 sed.x86_64 tar.x86_64 which.x86_64 \
gtk2-*.x86_64 \
libXtst-*.x86_64 libXtst-*.i686 \
libcanberra-gtk3-*.x86_64 libcanberra-gtk3-*.i686 \
PackageKit-gtk3-module-*.x86_64 \
webkit2gtk3.x86_64 unzip.x86_64 cpp.x86_64 \
systemd-libs.i686"

## Multiword and Parse Argument Functions ####################################################################
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
        --email)
            capture_value EMAIL "$@"
            shift
            ;;
        --mode)
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


## Common Functions  #############################################################################################

log() {
    echo "${DATE} - $1" | tee -a "${LOGDIR}/${LOG_FILE}"
}

send_email() {
    log 'Sending-email notification...'
    EMAIL_SUBJECT="$(hostname): ${LOG_FILE} successfully."
    mailx -s "${EMAIL_SUBJECT}" "${EMAIL}" < "${LOGDIR}/${LOG_FILE}"
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
    ACTION_PERFORMED='Install'
    LOG_FILE="Visual_COBOL-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"
    
    log "Locating installation files."
    INSTALL_BINARIES_FILE=$(find . -name "${INSTALL_BINARIES}" -type f 2>/dev/null)
    LICENSE_FILE=$(find . -name "${LICENSE}" -type f 2>/dev/null)
    
    # Ensure installation files are present
    if [[ -z "${INSTALL_BINARIES_FILE}" || -z "${LICENSE_FILE}" ]]; then
        log "Error: Installation files are missing."
        exit 1
    fi
    
    # Ensure installation binary is executable
    if [[ ! -x "${INSTALL_BINARIES_FILE}" ]]; then
        log "Installation file is not executable. Fixing permissions."
        chmod +x "${INSTALL_BINARIES_FILE}"
    fi
    
    # Check if Visual COBOL is already installed
    if [[ -d "${INSTALLDIR}" ]]; then
        log "Visual COBOL is already installed in ${INSTALLDIR}. Exiting."
        exit 1
    fi

    # Create user account if needed
    if ! id "${USER_ACCOUNT}" &>/dev/null; then
        log "Creating ${USER_ACCOUNT} account..."
        /usr/sbin/useradd -g xbag-dev-devl-asfr -d "/home/${USER_ACCOUNT}" -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" "${USER_ACCOUNT}"
        
        # Verify user creation
        if id "${USER_ACCOUNT}" &>/dev/null; then
            log "${USER_ACCOUNT} account created successfully."
        else
            log "Error: Failed to create ${USER_ACCOUNT} account. Exiting."
            exit 1
        fi
    else
        log "User account ${USER_ACCOUNT} already exists. Skipping creation."
    fi

    install_yum_packages

    # Check current SELinux mode before modifying
    SELINUX_MODE=$(getenforce)
    if [[ "${SELINUX_MODE}" == "Enforcing" ]]; then
        log "Temporarily disabling SELinux."
        if ! setenforce 0; then
            log "Error: Failed to disable SELinux. Exiting."
            exit 1
        fi
        SELINUX_WAS_ENFORCING=true
    else
        log "SELinux is already disabled. No action needed."
        SELINUX_WAS_ENFORCING=false
    fi

    log "Starting Visual COBOL installation."
    if ! "${INSTALL_BINARIES_FILE}" -silent -IacceptEULA -installlocation="${INSTALLDIR}" >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
        log "Error: Installation failed."

        # Re-enable SELinux only if it was originally enforcing
        if [[ "${SELINUX_WAS_ENFORCING}" == "true" ]]; then
            log "Re-enabling SELinux due to installation failure."
            setenforce 1
        fi

        exit 1
    fi
    log "Visual COBOL installed successfully in ${INSTALLDIR}."

    # Validate installation
    if [[ -z "${COBOL_VERSION}" || "${COBOL_VERSION}" == "" ]]; then
        log "Error: Visual COBOL installation validation failed."
        exit 1
    fi
    log "Visual COBOL installation validated successfully. Installed version: ${COBOL_VERSION}"


    # Source the cobsetenv script to set environment variables
    if [ -f "${INSTALLDIR}/bin/cobsetenv" ]; then
        . "${INSTALLDIR}/bin/cobsetenv"
        log "Sourced cobsetenv to set environment variables."
    else
        log "Error: cobsetenv script not found in ${INSTALLDIR}/bin/. Installation cannot proceed."
        exit 1
    fi

    log "Applying license."
    if ! "${INSTALLDIR}/bin/cesadmintool.sh" -install "${LICENSE_FILE}" >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
        log "Error: License installation failed."
        exit 1
    fi
    log "License successfully applied."

    # Validate license installation
    if ! "${INSTALLDIR}/bin/cesadmintool.sh" -view | grep -q 'License is installed'; then
        log "Error: License validation failed."
        exit 1
    fi
    log "License validation successful."

    chmod -R 775 /opt/microfocus
    chown -R "${USER_ACCOUNT}:xbag-dev-devl-asfr" /opt/microfocus

    log "Installation of Visual COBOL completed successfully."

    # Re-enable SELinux only if it was originally enforcing
    if [[ "${SELINUX_WAS_ENFORCING}" == "true" ]]; then
        log "Re-enabling SELinux."
        setenforce 1
    else
        log "SELinux was disabled initially. No need to re-enable."
    fi

    send_email
}


## Uninstall ##
uninstall() {
    ACTION_PERFORMED='Uninstall'
    LOG_FILE="Visual_COBOL-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"

    # Check if Visual COBOL is installed
    if [[ ! -d "${INSTALLDIR}" ]]; then
        log "Visual COBOL is not installed. Exiting."
        exit 1
    fi

    log "Stopping related services."
    systemctl stop mfserver 2>/dev/null || log "Warning: Could not stop Micro Focus Directory Server (mfserver). It may not be running."
    systemctl stop escwa 2>/dev/null || log "Warning: Could not stop ESCWA service. It may not be running."

    # Find uninstall scripts dynamically
    UNINSTALL_BINARIES_FILE=$(find "${INSTALLDIR}" -type f \( -iname 'uninstall*visual*.sh' \) 2>/dev/null | head -n 1)
    UNINSTALL_LICENSE_FILE=$(find "${INSTALLDIR}" -type f \( -iname 'uninstall*license*.sh' \) 2>/dev/null | head -n 1)

    if [[ -z "${UNINSTALL_BINARIES_FILE}" ]]; then
        log "Error: Uninstall script not found in ${INSTALLDIR}. Exiting."
        exit 1
    fi

    # Ensure uninstall script is executable
    if [[ ! -x "${UNINSTALL_BINARIES_FILE}" ]]; then
        log "Uninstall script is not executable. Fixing permissions."
        chmod +x "${UNINSTALL_BINARIES_FILE}"
    fi

    log "Running Visual COBOL uninstallation script: ${UNINSTALL_BINARIES_FILE}"
    if ! "${UNINSTALL_BINARIES_FILE}" -silent >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
        log "Error: Uninstallation failed."
        exit 1
    fi
    log "Visual COBOL uninstalled successfully."

    if [[ -n "${UNINSTALL_LICENSE_FILE}" ]]; then
        # Ensure uninstall license script is executable
        if [[ ! -x "${UNINSTALL_LICENSE_FILE}" ]]; then
            log "License uninstall script is not executable. Fixing permissions."
            chmod +x "${UNINSTALL_LICENSE_FILE}"
        fi

        log "Removing Micro Focus License Administration: ${UNINSTALL_LICENSE_FILE}"
        if ! "${UNINSTALL_LICENSE_FILE}" -silent >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
            log "Warning: Failed to uninstall Micro Focus License Server. Manual removal may be required."
        else
            log "Micro Focus License Server uninstalled successfully."
        fi
    else
        log "License uninstall script not found. Skipping license removal."
    fi

    log "Checking for remaining Micro Focus directories."
    for DIR in /opt/microfocus /var/opt/microfocus /etc/opt/microfocus; do
        if [[ -d "$DIR" ]]; then
            log "Warning: Directory $DIR still exists. Manual removal may be required."
        fi
    done

    log "Re-enabling SELinux."
    if ! setenforce 1; then
        log "Error: Failed to re-enable SELinux. Manual intervention required."
    fi

    send_email
}

## Main Execution Logic #############################

case ${MODE} in
    install) install ;;
    uninstall) uninstall ;;
    update) update ;;
    *) log "Invalid mode. Usage: MODE=(install|uninstall|update)" ; exit 1 ;;
esac