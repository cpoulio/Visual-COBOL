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
# ❌ return 1
#  ✅ return 0  ✅
# 
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
TMPDIR=/opt/app/Visual
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
HOSTNAME="$(uname -n)"
YUM_PACKAGES="java-11-openjdk.x86_64 gcc.x86_64 spax.x86_64 glibc-*.i686 glibc-*.x86_64 glibc-devel-*.x86_64 glibc-devel.i686 libgcc-*.i686 libgcc-*.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 libstdc++-docs.x86_64 libstdc++.i686 libstdc++-devel.i686 gtk2-*.x86_64 libXtst-*.x86_64 libXtst-1.2.3-7.el8.i686 libcanberra-gtk3-0.30-18.el8.i686 libcanberra-gtk3-*.x86_64 PackageKit-gtk3-module-*.x86_64 webkit2gtk3.x86_64 xterm.x86_64 unzip.x86_64 cpp*x86_64"
SKIP_IF_ALREADY_INSTALLED=true
## Common Functions  #############################################################################################

log() {
    echo "${DATE} - $1" | tee -a "${LOGDIR}/${LOG_FILE}"
    log_success
    return 0
}

send_email() {
    log 'Sending-email notification...'
    EMAIL_SUBJECT="${HOSTNAME}: ${LOG_FILE} successfully."
    mailx -S replyto=no_reply@irs.gov -s "${EMAIL_SUBJECT}" "${EMAIL}" < "${LOGDIR}/${LOG_FILE}"
    log_success
    return 0
}
# YUM Installation
install_yum_packages() {
    log "Starting YUM Installation..."
    yum_output=$(yum install -y ${YUM_PACKAGES} 2>&1 | tee -a "${LOGDIR}/${LOG_FILE}")
    yum_exit_status=${PIPESTATUS[0]}
    
    if [[ ${yum_output} | grep -q "Nothing to do" ]]; then
        log "YUM packages already installed. Skipping installation."
    elif [[ ${yum_exit_status} -ne 0 ]]; then
        log "Error: Failed to install prerequisites via YUM. Exiting."
        kill_keep_alive && return 1
    else
        log "Prerequisite libraries installed successfully."
    fi
    log_success
    return 0
}

# Function: pause_for_input
pause_for_input() {
    read -p "Press any key to continue or type exit to quit: "
    if [[ "$USER_RESPONSE
    " == "exit" ]]; then
        kill_keep_alive && return 1
    else
        echo "Continuing script execution..."
    fi
}

# Function: kill_keep_alive, start_keep_alive, keep_alive``
kill_keep_alive() {
    if [[ -n "${KEEP_ALIVE_PID}" ]] && kill -0 "${KEEP_ALIVE_PID}" 2>/dev/null; then
        kill "${KEEP_ALIVE_PID}" 2>/dev/null
        wait "${KEEP_ALIVE_PID}" 2>/dev/null
    fi
    log_success
    return 0 
}

keep_alive() {
    while true; do
        echo -ne "."
        sleep 60
    done
}

start_keep_alive() {
    keep_alive &
    KEEP_ALIVE_PID=$!
    trap 'kill_keep_alive' EXIT
    log_success
    return 0    
}

log_success() {
    echo "✅ Success"
}
##### Functions Just For Visual COBOL ########################################
check_and_disable_selinux() {
    log "Check current SELinux mode before modifying"
    SELINUX_MODE=$(getenforce)
    if [[ "${SELINUX_MODE}" == "Enforcing" ]]; then
        log "Temporarily disabling SELinux."
        if ! setenforce 0; then
            log "Error: Failed to disable SELinux. Exiting."
            kill_keep_alive && return 1
        fi
        SELINUX_WAS_ENFORCING=true
    else
        log "SELinux is already disabled. No action needed."
        SELINUX_WAS_ENFORCING=false
    fi
    log_success
    return 0 
}
# Function: ensure_install_dir_exists
ensure_install_dir_exists() {
    log "Checking if installation directory exists: ${INSTALLDIR}"

    if [[ ! -d "${INSTALLDIR}" ]]; then
        log "Installation directory not found. Creating: ${INSTALLDIR}"
        mkdir -p "${INSTALLDIR}" || {
            log "Error: Failed to create ${INSTALLDIR}"
            kill_keep_alive && return 1
        }
        chown root:root "${INSTALLDIR}"
        chmod 755 "${INSTALLDIR}"
        log "Installation directory created successfully."
    else
        log "Installation directory already exists: ${INSTALLDIR}"
    fi
    log_success
    return 0 
}

find_required_files_location() {
    log "Dynamically locate required files for installation"
    BASH_PROFILE_FILE=$(find . -name "bash_profile" -type f -exec readlink -f {} \; 2>/dev/null | head -n 1)
    LICENSE_FILE=$(find . -name "${LICENSE}" -type f -exec readlink -f {} \; 2>/dev/null | head -n 1)
    INSTALL_BINARIES_FILE=$(find . -name "${INSTALL_BINARIES}" -type f -exec readlink -f {} \; 2>/dev/null | head -n 1)
    log_success
    return 0
}

validate_required_files() {
    log "Validating that required files are found before proceeding..."

    if [[ -z "${BASH_PROFILE_FILE}" || -z "${LICENSE_FILE}" || -z "${INSTALL_BINARIES_FILE}" ]]; then
        echo "❌ Error: One or more required files are missing in the current directory or subdirectories."
        echo "Missing files:"
        [[ -z "${BASH_PROFILE_FILE}" ]] && echo "  - bash_profile"
        [[ -z "${LICENSE_FILE}" ]] && echo "  - ${LICENSE}"
        [[ -z "${INSTALL_BINARIES_FILE}" ]] && echo "  - ${INSTALL_BINARIES}"
        kill_keep_alive && return 1
    fi
    log_success
    return 0   
}

check_version_number() {
    log "Checking version number of Visual COBOL installed..."

    if [[ "${SKIP_IF_ALREADY_INSTALLED}" == "true" && -d "${INSTALLDIR}/bin" ]]; then
        COBVER_FILE="${INSTALLDIR}/etc/cobver"

        if [[ -f "${COBVER_FILE}" ]]; then
            VISUAL_COBOL_VERSION=$(grep -Eoi 'cobol V[0-9]+\.[0-9]+\.[0-9]+' "${COBVER_FILE}" | head -n 1)

            if [[ -n "${VISUAL_COBOL_VERSION}" ]]; then
                log "Visual COBOL already installed at ${INSTALLDIR}. Version detected: ${VISUAL_COBOL_VERSION}"
                kill_keep_alive && log_success
    return 0
            else
                log "Visual COBOL installed, but version info missing in cobver file."
                kill_keep_alive && return 1
            fi
        else
            log "Visual COBOL appears installed, but cobver file not found at ${COBVER_FILE}."
            kill_keep_alive && return 1
        fi
    fi
    log_success
    return 0
}


check_and_add_user() {
    log "Create user account if needed"
    if id "${USER_ACCOUNT}" &>/dev/null; then
        log "User ${USER_ACCOUNT} already exists. Skipping user creation."
    else
        log "User ${USER_ACCOUNT} does not exist. Creating account..."

        if /usr/sbin/useradd -g xbag-dev-devl-asfr -d "/home/${USER_ACCOUNT}" -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" "${USER_ACCOUNT}"; then
            log "Useradd command executed successfully for ${USER_ACCOUNT}."

            # ✅ Confirm the user was actually created
            if id "${USER_ACCOUNT}" &>/dev/null; then
                log "User ${USER_ACCOUNT} verified successfully after creation."

                # Backup and apply .bash_profile
                if [[ -f "/home/${USER_ACCOUNT}/.bash_profile" ]]; then
                    mv "/home/${USER_ACCOUNT}/.bash_profile" "/home/${USER_ACCOUNT}/.bash_profile.${DATE}"
                    log "Backed up existing .bash_profile for ${USER_ACCOUNT}."
                fi

                cp -p "${BASH_PROFILE_FILE}" "/home/${USER_ACCOUNT}/.bash_profile"
                chown -R "${USER_ACCOUNT}:xbag-dev-devl-asfr" "/home/${USER_ACCOUNT}"
                log ".bash_profile applied successfully to ${USER_ACCOUNT}."
            else
                log "Error: useradd succeeded but user ${USER_ACCOUNT} is not present. Aborting."
                kill_keep_alive && return 1
            fi
        else
            log "Error: useradd command failed for ${USER_ACCOUNT}. Possible system issue."
            kill_keep_alive && return 1
        fi
    fi
    log_success
    return 0
}



install_visual_cobol () {
    if [[ "${SKIP_IF_ALREADY_INSTALLED}" != "true" ]]; then
        ensure_install_dir_exists

        log "Starting Visual COBOL silent installation..."
        if ! "${INSTALL_BINARIES_FILE}" -silent -IacceptEULA -installlocation="${INSTALLDIR}" >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
            log "Error: Silent installation failed. Check ${LOGDIR}/${LOG_FILE} for details."
            kill_keep_alive && return 1
        else
            log "Silent installation completed successfully. Visual COBOL installed in ${INSTALLDIR}."
        fi
    fi
    log_success
    return 0 
}

validate_installation_and_source_cobsetenv_script (){
    log "Validating Visual COBOL installation..."
    if [[ -z "${VISUAL_VISUAL_COBOL_VERSION}" || "${VISUAL_VISUAL_COBOL_VERSION}" == "" ]]; then
        log "Error: Visual COBOL installation validation failed."
        kill_keep_alive && return 1
    fi

    
        log "Source the cobsetenv script to set environment variables"
    if [ -f "${INSTALLDIR}/bin/cobsetenv" ]; then
        . "${INSTALLDIR}/bin/cobsetenv"
        log "Sourced cobsetenv to set environment variables."
    else
        log "Error: cobsetenv script not found in ${INSTALLDIR}/bin/. Installation cannot proceed."
        kill_keep_alive && return 1
    fi
    log_success
    return 0
}

install_verify_license() {
    log "Install license"
    if ! "${INSTALLDIR}/bin/cesadmintool.sh" -install "${LICENSE_FILE}" >> "${LOGDIR}/${LOG_FILE}" 2>&1; then
        log "Error: Failed to install license. Check ${LOGDIR}/${LOG_FILE} for details."
        kill_keep_alive && return 1
    fi
    
    log "Validate license installation"
    if ! "${INSTALLDIR}/bin/cesadmintool.sh" -view | grep -q 'License is installed'; then
        log "Error: License validation failed."
        kill_keep_alive && return 1
    fi
    log "License installation validated successfully."
    log_success
    return 0    
}

enable_selinux() {
    # Re-enable SELinux if it was previously enforcing
    if [[ "${SELINUX_WAS_ENFORCING}" == "true" ]]; then
        log "Re-enabling SELinux."
        if ! setenforce 1; then
            log "Error: Failed to re-enable SELinux. Manual intervention required."
            kill_keep_alive && return 1
        fi
    else
        log "SELinux was not enforcing. No action needed."
    fi
    log_success
    return 0
}

change_mode_and_ownership() {
    chmod -R 775 /opt/microfocus
    chown -R "${USER_ACCOUNT}:xbag-dev-devl-asfr" /opt/microfocus
    log_success
    return 0
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

    start_keep_alive || return 1
    log "Starting keep-alive process with PID: ${KEEP_ALIVE_PID}"

    check_and_disable_selinux || return 1
    log "SELinux disabled successfully."

    find_required_files_location || return 1
    log "Required files found:"

    validate_required_files || return 1
    log "Visual COBOL installation validated successfully. Installed version: ${VISUAL_VISUAL_COBOL_VERSION}."

    check_version_number || return 1
    log "Version number checked successfully."

    install_yum_packages | return 1
    log "YUM packages installed successfully."

    pause_for_input

    check_and_add_user || return 1
    log "User account checked and created if needed."

    pause_for_input

    install_visual_cobol || return 1
    log "Visual COBOL installation succeeded."

    validate_installation_and_source_cobsetenv_script || return 1
    log "Visual COBOL installation validated successfully. Sourcing cobsetenv script to set environment variables."

    install_verify_license || return 1
    log "License installed successfully."

    pause_for_input

    enable_selinux || return 1
    log "SELinux re-enabled successfully."

    change_mode_and_ownership || return 1
    log "Mode and ownership changed successfully."
    
    log "${ACTION_PERFORMED} completed."

    pause_for_input

    send_email
    log "Email notification sent successfully."
    
    log_success
    kill_keep_alive && return 0
}



## Uninstall ##
uninstall() {
    
    ACTION_PERFORMED='Uninstall'
    LOG_FILE="${UNINSTALL_BINARIES}-${ACTION_PERFORMED}-${DATE}.log"
    log "${ACTION_PERFORMED}"

    # Temporarily disable SELinux
    if [[ "$(getenforce)" != "Disabled" ]]; then
        setenforce 0
        log "Temporarily disabled SELinux (runtime-only) for uninstallation."
    else
        log "SELinux is already disabled."
    fi
    
    # Check source environment variables
    if [[ -f "${INSTALLDIR}/bin/cobsetenv" ]]; then
        . "${INSTALLDIR}/bin/cobsetenv" &>> "${LOGDIR}/${LOG_FILE}"
    else
        log "Error: Cannot find ${INSTALLDIR}/bin/cobsetenv. Exiting."
        kill_keep_alive && return 1
    fi


    # Uninstall Visual COBOL 
    if [[ -x "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" ]]; then
        log "yes" | "${INSTALLDIR}/bin/${UNINSTALL_BINARIES}" &>> "${LOGDIR}/${LOG_FILE}"
    else
        log "Uninstallation script not found or not executable!" >> "${LOGDIR}/${LOG_FILE}"
        kill_keep_alive && return 1
    fi

    # Validate USER_ACCOUNT
    if [[ -z "${USER_ACCOUNT}" ]]; then
        log "ERROR: USER_ACCOUNT is not set. Exiting."
        kill_keep_alive && return 1
    fi

    # Log the planned operations
    log "Deleting user account: ${USER_ACCOUNT}"
    log "Removing directories: /opt/microfocus /home/${USER_ACCOUNT}"

    # Perform the operations
    /usr/sbin/userdel "${USER_ACCOUNT}"
    rm -rf /opt/microfocus "/home/${USER_ACCOUNT:?}"

    # Re-enable SELinux
    if [[ "$(getenforce)" != "Disabled" ]]; then
        setenforce 1
        log "Re-enabled SELinux (runtime-only)."
    fi
    
    # Revert SELinux configuration
    #sed -i 's/^#SELINUX=enforcing/SELINUX=enforcing/' /etc/selinux/config
    #sed -i '/SELINUX=disabled/d' /etc/selinux/config

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