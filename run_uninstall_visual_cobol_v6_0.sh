#!/bin/bash

# This script uninstalls COBOL Server v6.0

# Set Variables
logdir=/opt/app/tmp/microfocus
logfile=Visual_COBOL_Uninstall.log
#EMAIL=$1
EMAIL="EMAIL@email.com,$1"

# Remove old log if it exists.
rm -f $logdir/$logfile

# Source the environment variables
. /opt/microfocus/VisualCOBOL/bin/cobsetenv >> $logdir/$logfile

# Uninstall COBOL Server v6.0
echo "yes"|/opt/microfocus/VisualCOBOL/bin/Uninstall_VisualCOBOLEclipse6.0.sh >> $logdir/$logfile

# Delete the user account asfrsvc
/usr/sbin/userdel asfrsvc

# Remove directories
rm -rf /opt/microfocus /home/asfrsvc

# Revert the SELinux changes
sed -i 's+^#SELINUX=enforcing+SELINUX=enforcing+' /etc/selinux/config
sed -i "/SELINUX=disabled/d" /etc/selinux/config

echo "Microfocus Visual COBOL v6.0 Uninstallation  Log attached.!" |mailx -s "Microfocus Visual COBOL Uninstallation in $(hostname)" -a $logdir/$logfile $EMAIL
