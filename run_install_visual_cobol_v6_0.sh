#!/bin/bash

##############################################################################
# Set variables
##############################################################################

set_variables () {
   TODAY=`date +"%m%d%Y"`
   logdir=/opt/app/tmp/microfocus
   logfile=Visual_COBOL_60_install.log
   EMAIL="EMAIL@email.com,$1"
   echo "EMAIL: $EMAIL passed"
}


create_user_account () {
   # check if asfrsvc account exists already
   grep asfrsvc /etc/passwd
   ret=$?

   if [ $ret -gt 0 ]; then
      echo "asfrsvc account does not exist. Creating it..."
      /usr/sbin/useradd -g xbag-dev-devl-asfr -d /home/asfrsvc -m -s /bin/bash -c "GENERIC, ASFR Service Account, [ISVC]" asfrsvc
      mv /home/asfrsvc/.bash_profile /home/asfrsvc/.bash_profile.$TODAY
      cp -p $logdir/bash_profile /home/asfrsvc/.bash_profile
      chown -R asfrsvc:xbag-dev-devl-asfr /home/asfrsvc
      echo "asfrsvc Account created!"
   fi
}

disable_selinux () {
   cp -p /etc/selinux/config /etc/selinux/config.bak.$TODAY
   # Update SELINUX Parameter
   sed -i 's+^SELINUX=enforcing+#SELINUX=enforcing+' /etc/selinux/config
   sed -i "/#SELINUX=enforcing/a SELINUX=disabled" /etc/selinux/config
}

install_libraries () {
   # Install Libraries
   yum install -y gcc.x86_64 > $logdir/libinstall.log
   yum install -y spax.x86_64 >> $logdir/libinstall.log
   yum install -y glibc-*.i686 >> $logdir/libinstall.log
   yum install -y glibc-*.x86_64 >> $logdir/libinstall.log
   yum install -y libgcc-*.i686 >> $logdir/libinstall.log
   yum install -y libgcc-*.x86_64 >> $logdir/libinstall.log
   yum install -y libstdc++.x86_64 >> $logdir/libinstall.log
   yum install -y libstdc++-devel.x86_64 >> $logdir/libinstall.log
   yum install -y libstdc++-docs.x86_64 >> $logdir/libinstall.log
   yum install -y libstdc++.i686 >> $logdir/libinstall.log
   yum install -y libstdc++-devel.i686 >> $logdir/libinstall.log
   yum install -y gtk2-*.x86_64 >> $logdir/libinstall.log
   yum install -y libXtst-*.x86_64 >> $logdir/libinstall.log
   yum install -y libXtst-1.2.3-7.el8.i686 >> $logdir/libinstall.log
   yum install -y libcanberra-gtk3-0.30-18.el8.i686 >> $logdir/libinstall.log
   yum install -y glibc-devel-*.x86_64 >> $logdir/libinstall.log
   yum install -y yum install -y glibc-devel.i686 >> $logdir/libinstall.log
   yum install -y PackageKit-gtk3-module-*.x86_64 >> $logdir/libinstall.log
   yum install -y libcanberra-gtk3-*.x86_64 >> $logdir/libinstall.log
   yum install -y webkit2gtk3.x86_64 >> $logdir/libinstall.log
   yum install -y xterm.x86_64 >> $logdir/libinstall.log
   yum install -y unzip.x86_64 >> $logdir/libinstall.log
   yum install -y cpp*x86_64 >> $logdir/libinstall.log
}

install_java () {
   # Install Java
   # yum install -y java-1.8.0-openjdk.x86_64 >> $logdir/libinstall.log
   yum install -y java-11-openjdk.x86_64 >> $logdir/libinstall.log
}

install_Visual_COBOL () {
   cd /opt/app/tmp/microfocus

   # Grant Permissions
   chmod 755 setup_visualcobol_deveclipse_6.0_redhat_x86_64 Visual_COBOL_for_Eclipse.mflic
   chmod +x setup_visualcobol_deveclipse_6.0_redhat_x86_64

   # Install Visual COBOL v6.0
   echo "Installing Visual COBOL v6.0 ..." > $logdir/$logfile
   /opt/app/tmp/microfocus/setup_visualcobol_deveclipse_6.0_redhat_x86_64 -silent -IacceptEULA -installlocation="/opt/microfocus/VisualCOBOL" >> $logdir/$logfile
   echo "Installed Visual COBOL v6.0." >> $logdir/$logfile
   . /opt/microfocus/VisualCOBOL/bin/cobsetenv >> $logdir/$logfile

   # Install the license
   /opt/microfocus/VisualCOBOL/bin/cesadmintool.sh -install $logdir/Visual_COBOL_for_Eclipse.mflic >> $logdir/$logfile

   # Grant Permissions
   chmod -R 775 /opt/microfocus
   chown -R asfrsvc:xbag-dev-devl-asfr /opt/microfocus

   # Run environment variables
   . ~asfrsvc/.bash_profile
   . /opt/microfocus/VisualCOBOL/bin/cobsetenv > $logdir/visual-cobol-output.txt
   echo -e "Visual COBOL v6.0 Output\n"  >> $logdir/visual-cobol-output.txt
   cob -V >> $logdir/visual-cobol-output.txt
   echo -e "\nVisual COBOL v6.0 Help" >> $logdir/visual-cobol-output.txt
   cob -? >> $logdir/visual-cobol-output.txt


   # Send an email
   echo "The installation logs for Microfocus Visual COBOL v6.0 are attached here." | mailx -s "Microfocus Visual COBOL Installation in $(hostname)" -a $logdir/libinstall.log -a $logdir/visual-cobol-output.txt -a $logdir/$logfile $EMAIL
}

# Start from here

# Set Variables here
set_variables

echo "EMAIL: $EMAIL"
# Create user account if it does not exist
create_user_account

# Disable SELINUX
disable_selinux

# Install required libraries
install_libraries

# Install Java
install_java

# Install COBOL Server v6.0
install_Visual_COBOL
