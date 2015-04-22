#!/usr/bin/env bash
DEVSTACK_MGMT_IP=10.0.135.252
. devstack/functions
sudo ip addr del $DEVSTACK_MGMT_IP/24 dev eth2
sudo ovs-vsctl add-port br-ex eth2
sudo ip link set eth2 up
sudo ip link set eth2 promisc on
sudo ip addr add $DEVSTACK_MGMT_IP/24 dev br-ex
sudo iptables -t nat -A POSTROUTING -o br-ex -j MASQUERADE

# Tempest integration
eval export $(cat /opt/stack/manila/contrib/ci/pre_test_hook.sh |grep "TEMPEST_COMMIT=")
OLD_PWD=$(pwd)
cd /opt/stack/tempest
git checkout $TEMPEST_COMMIT
cp -r /opt/stack/manila/contrib/tempest /opt/stack/
cd $OLD_PWD

# Manila Horizon UI
cd /opt/stack && git clone https://github.com/hp-storage/manila-ui
cd /opt/stack/horizon && cp openstack_dashboard/local/local_settings.py.example openstack_dashboard/local/local_settings.py
sed -i "s/'js_spec_files': \[\],/'js_spec_files': \[\],\n'customization_module': 'manila_ui.overrides',/" /opt/stack/horizon/openstack_dashboard/local/local_settings.py
sudo pip install -e /opt/stack/manila-ui
cd /opt/stack/horizon && cp ../manila-ui/manila_ui/enabled/_90_manila_*.py openstack_dashboard/local/enabled
sudo /etc/init.d/apache2 restart

