#!/bin/bash
cd "$(dirname "$0")"

source common.env

echo " "
echo "########## 2a-tools.sh ######################"
echo "start: BY `whoami`  ON  `date`  FROM  `pwd`"
echo " full hostname = $hostname"
echo "short hostname = $short_hostname"

if [ $uname == 'Linux' ]; then
  yum --version > /dev/null 2>&1
  rc=$?
  if [ "$rc" == "0" ]; then
    YUM="y"
  else
    YUM="n"
  fi

  if [ "$YUM" == "n" ]; then
    apt="apt-get install -y"
    PLATFORM=deb
    echo "## $PLATFORM ##"

    sudo $apt git net-tools wget curl zip git python3 openjdk-17-jdk-headless

    ## for using FPM package managemnt software for makeing DEB's
    sudo $apt squashfs-tools

    echo "## ONLY el8/9 supported for building binaries ###"
  else
    yum="dnf --skip-broken -y install"
    PLATFORM=`cat /etc/os-release | grep PLATFORM_ID | cut -d: -f2 | tr -d '\"'`
    echo "## $PLATFORM ##"
    sudo $yum git net-tools wget curl pigz sqlite which zip

    sudo $yum cpan
    echo yes | sudo cpan FindBin
    sudo cpan IPC::Run
    sudo $yum epel-release

    if [ "$short_hostname" == "test" ]; then
      echo "Goodbye TEST Setup!"
      exit 0
    fi

    if [ ! "$PLATFORM" == "el8" ] && [ ! "$PLATFORM" == "el9" ]; then
      echo " "
      echo "## ONLY el8 & el9 are supported for building binaries ###"
    else
      if [ "$PLATFORM" == "el8" ]; then
        sudo dnf config-manager --set-enabled powertools
      else
        sudo dnf config-manager --set-enabled crb
      fi
      sudo dnf -y groupinstall 'development tools'
      sudo dnf -y --nobest install zlib-devel bzip2-devel lbzip2 \
        openssl-devel libxslt-devel libevent-devel c-ares-devel \
        perl-ExtUtils-Embed pam-devel openldap-devel boost-devel 
      sudo dnf -y remove curl
      sudo $yum curl-devel chrpath clang-devel llvm-devel \
        cmake libxml2-devel 
      sudo $yum libedit-devel 
      sudo $yum *ossp-uuid*
      sudo $yum openjpeg2-devel libyaml libyaml-devel
      sudo $yum ncurses-compat-libs systemd-devel
      sudo $yum unixODBC-devel protobuf-c-devel libyaml-devel
      sudo $yum lz4-devel libzstd-devel krb5-devel
      sudo $yum java-17-openjdk-devel
      if [ "$PLATFORM" == "el8" ]; then
        sudo $yum python39 python39-devel
        sudo dnf -y remove python311
      else
	sudo $yum python3-devel
      fi 
      sudo $yum clang
      if [ "$PLATFORM" == "el9" ]; then
        ## postgis
        sudo $yum geos-devel proj-devel gdal

        ## sqlitefdw
        sudo $yum sqlite-devel

        ## friggin packakge management
        sudo $yum ruby rpm-build squashfs-tools
        gem install fpm
      fi

      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > install-rust.sh 
      chmod 755 install-rust.sh
      ./install-rust.sh -y
      rm install-rust.sh

    fi
  fi

elif [ $uname == 'Darwin' ]; then
  owner_group="$USER:staff"
  if [ "$SHELL" != "/bin/bash" ]; then
    chsh -s /bin/bash
  fi
fi

cd ~/dev
mkdir -p out
mkdir -p history

echo ""
echo "Goodbye!"
