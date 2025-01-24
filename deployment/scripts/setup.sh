#!/bin/bash -x
#
#  NO INPUT is required in Ansible Deployment unless;
#       -  You need to override the MODE (default is install, other valus is uninstall)
#       -  You need to provide a INSTALLDIR (default is /opt/app)
#

TMPDIR=/opt/app/tmp/microfocus

# Check if the Emails are passed
#if [[ E"$EMAIL" = "E" ]]; then
#   EMAIL="EMAIL@email.com"
#else
#   EMAIL="Palanisamy.K.Payiran@irs.gov,michael.j.briscoejr@irs.gov,${EMAIL}"
#fi

echo "EMAIL: $EMAIL"

# Check what mode was passed
if [[ M"$MODE" = "M" || M"$MODE" = "Minstall" || M"$MODE" = "MInstall" ]]; then
   MODE=install
elif [[ M"$MODE" = "Muninstall" || M"$MODE" = "MUninstall" ]]; then
   MODE=uninstall
else
   echo -e "\nThe incorret Mode=$MODE was passed. Deployment aborted!\n"
   exit 0
fi

echo "MODE: $MODE"

#Lets start the install/uninstall
mkdir -p /opt/app/tmp/microfocus

if [[ "$MODE" = "install" ]]; then
   if [[ -d /opt/microfocus/VisualCOBOL/bin ]]; then
      echo -e "\nMicrofocus Visual COBOL was already installed. Uninstall it first before attempting to install it.\n"
      exit 0
   fi
   mv ${deploy_dir}/bash_profile $TMPDIR
   mv ${deploy_dir}/Visual_COBOL_for_Eclipse.mflic $TMPDIR
   mv ${deploy_dir}/run_install_visual_cobol_v6_0.sh $TMPDIR
   mv ${deploy_dir}/setup_visualcobol_deveclipse_6.0_redhat_x86_64 $TMPDIR
   $TMPDIR/run_install_visual_cobol_v6_0.sh $EMAIL
elif [[ "$MODE" = "uninstall" ]]; then
   mv ${deploy_dir}/run_uninstall_visual_cobol_v6_0.sh $TMPDIR
   $TMPDIR/run_uninstall_visual_cobol_v6_0.sh $EMAIL
fi

# Lets clean up the directory
rm -rf /opt/app/tmp/microfocus
