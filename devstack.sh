#!/bin/sh

# environment variables
OPENSTACK_BRANCH=master
OPENSTACK_ADM_PASSWORD=devstack
MANILA_BRANCH=master

# determine own script path
BASHPATH="`dirname \"$0\"`"              # relative
BASHPATH="`( cd \"$BASHPATH\" && pwd )`"  # absolutized and normalized
echo "run script from $BASHPATH"

export OPENSTACK_BRANCH=$OPENSTACK_BRANCH
export MANILA_BRANCH=$MANILA_BRANCH
export OPENSTACK_ADM_PASSWORD=$OPENSTACK_ADM_PASSWORD
export HOST_IP=$OS_HOST_IP
export NODE_MGMT_IP=$NODE_MGMT_IP
export DEVSTACK_MGMT_IP=$DEVSTACK_MGMT_IP
# update system
export DEBIAN_FRONTEND noninteractive
sudo apt-get update
sudo apt-get install -qqy git
sudo apt-get -y install vim-gtk libxml2-dev libxslt1-dev libpq-dev python-pip libsqlite3-dev && sudo apt-get -y build-dep python-mysqldb && sudo pip install git-review tox


# determine checkout folder
OS_USER=vagrant
PWD=$(su $OS_USER -c "cd && pwd")
DEVSTACK=/home/vagrant/devstack

# check if devstack is already there
if [ ! -d "$DEVSTACK" ]
then
  echo "Download devstack into $DEVSTACK"

  # clone devstack
  su $OS_USER -c "cd && git clone -b $OPENSTACK_BRANCH https://github.com/openstack-dev/devstack.git $DEVSTACK"

  echo "Copy configuration"

  # copy localrc settings (source: devstack/samples/localrc)
  echo "copy config from $BASHPATH/config/localrc to $DEVSTACK/localrc"
  cp $BASHPATH/config/localrc $DEVSTACK/localrc
  chown $OS_USER:$OS_USER $DEVSTACK/localrc

  # copy local.conf settings (source: devstack/samples/local.conf)
  echo "copy config from $BASHPATH/config/local.conf to $DEVSTACK/local.conf"
  cp $BASHPATH/config/local.conf $DEVSTACK/local.conf
  chown $OS_USER:$OS_USER $DEVSTACK/local.conf

  MANILA_IMAGE="/vagrant/ubuntu_1204_nfs_cifs.qcow2"
  if [ -f $MANILA_IMAGE ]; then
    echo "Found Manila image, copy to devstack"
    su $OS_USER -c "cp $MANILA_IMAGE $DEVSTACK/files/"
  fi
fi


# start devstack
echo "Start Devstack"
su $OS_USER -c "cd $DEVSTACK && ./stack.sh"
cp /vagrant/poststack.sh $DEVSTACK/../poststack.sh
su $OS_USER -c "cd $DEVSTACK && cd .. && ./poststack.sh"
