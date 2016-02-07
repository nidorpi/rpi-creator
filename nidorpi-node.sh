#!/bin/bash

if (( EUID != 0 )); then
    echo "You must be root to do this"
    exit 100
fi

CHANGE_MOTD=1

IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)

function msg() {
    echo -e "\x1B[01;93m$1\x1B[0m"
}
  
msg "Preparing to install"

apt-get update && apt-get -y upgrade
apt-get install -y pydf htop vim mc

PATH_NIDORPI="/usr/src/nidorpi/"
LINK_DEB="http://burylo.com/debs"
WGET_OPTIONS="-P $PATH_NIDORPI -q --show-progress"

# modify vim settings
sed -i 's/"syntax\ on/syntax\ on/' /etc/vim/vimrc
echo "set tabstop=4" >> /etc/vim/vimrc
echo "set shiftwidth=4" >> /etc/vim/vimrc
echo "set expandtab" >> /etc/vim/vimrc

mkdir -p $PATH_NIDORPI

msg "Checking kernel"
if ! `uname -r | grep -e "[hypriot|nidorpi]" > /dev/null`; then
    msg "+Downloading new kernel"
    wget $LINK_DEB/libraspberrypi0_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/libraspberrypi-bin_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/libraspberrypi-dev_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/libraspberrypi-doc_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/linux-headers-4.1.16-nidorpi_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/linux-headers-4.1.16-nidorpi-v7+_latest_armhf.deb $WGET_OPTIONS
    wget $LINK_DEB/raspberrypi-bootloader_latest_armhf.deb $WGET_OPTIONS
    msg "+Kernel downloaded, installing ..."
    dpkg -i $PATH_NIDORPI*.deb
    msg "+Kernel installed"
    rm -f $PATH_NIDORPI*
else
    msg "+Installed kernel is valid"
fi

msg "Checking Docker"

if which docker > /dev/null; then
    msg "+You have Docker installed"
else
    msg "+Installing docker"
    wget http://downloads.hypriot.com/docker-hypriot_1.10.0-1_armhf.deb $WGET_OPTIONS
    dpkg -i $PATH_NIDORPI/docker-hypriot_1.10.0-1_armhf.deb
fi

msg "Checking docker-machine"

if which docker-machine > /dev/null; then
    msg "+You have docker-machine installed"
else
    msg "+Installing docker-machine"
    wget http://downloads.hypriot.com/docker-machine_linux-arm_0.4.1 $WGET_OPTIONS
    mv $PATH_NIDORPI/docker-machine_linux-arm_0.4.1 /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-machine
fi

if [ $CHANGE_MOTD == 1 ]; then 
    msg "Getting modified motd"
    wget $LINK_DEB/extras/motd $WGET_OPTIONS
    mv $PATH_NIDORPI/motd /etc/profile.d/motd.sh
    echo > /etc/motd
    echo "ALL  ALL=(ALL) NOPASSWD:/opt/vc/bin/vcgencmd" >> /etc/sudoers
fi

msg "Preparing /etc/default/docker "
#clean docker runtime options
sed -i 's/^DOCKER_OPTS=".*"/DOCKER_OPTS=""/g' /etc/default/docker
# add  --storage-driver=overlay
sed -i 's/^DOCKER_OPTS="/DOCKER_OPTS=\"--storage-driver=overlay -D/g' /etc/default/docker
# add -H unix:///var/run/docker.sock
sed -i 's/^DOCKER_OPTS="/DOCKER_OPTS=\"-H unix:\/\/\/var\/run\/docker.sock /g' /etc/default/docker
# add -H tcp://0.0.0.0:2375
sed -i 's/^DOCKER_OPTS="/DOCKER_OPTS=\"-H tcp:\/\/0.0.0.0:2375 /g' /etc/default/docker

msg "Pulling needed images"
docker pull hypriot/rpi-swarm > /dev/null
#docker pull hypriot/rpi-consul

# msg "Starting swarm node"

