#!/usr/bin/env bash
DEVSTACK_MGMT_IP=10.0.135.252
. devstack/functions
sudo ip addr del $DEVSTACK_MGMT_IP/24 dev eth2
sudo ovs-vsctl add-port br-ex eth2
sudo ip link set eth2 up
sudo ip link set eth2 promisc on
sudo ip addr add $DEVSTACK_MGMT_IP/24 dev br-ex
sudo iptables -t nat -A POSTROUTING -o br-ex -j MASQUERADE

. devstack/openrc admin
DEMO_TENANT_ID=$(keystone tenant-list | grep " demo" | get_field 1)
neutron net-create p-m --provider:network_type vlan --provider:physical_network default --provider:segmentation_id 500 --tenant-id $DEMO_TENANT_ID
. devstack/openrc demo

NEUTRON_NET_ID=$(neutron net-list | grep private | get_field 1)
neutron security-group-rule-create --protocol icmp default
neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 default
NEUTRON_SUBNET_ID=$(neutron subnet-list | grep private-subnet | get_field 1)
manila share-network-create --neutron-net-id $NEUTRON_NET_ID --neutron-subnet-id $NEUTRON_SUBNET_ID --name p-s
sleep 5
manila create --share-network p-s --name share NFS 1

nova boot --poll --flavor m1.nano --image ubuntu_1204_nfs_cifs --nic net-id=$NEUTRON_NET_ID demo-vm0
MANILA_NET_ID=$(manila list | grep share | get_field 1)
INSTANCE_IP=$(nova list | grep demo-vm0 | get_field 6 | grep -oE '[0-9.]+')
manila access-allow $MANILA_NET_ID ip $INSTANCE_IP

nova floating-ip-create public

FLOATING_IP=$(nova floating-ip-list | grep public | get_field 2)
nova add-floating-ip demo-vm0 $FLOATING_IP
BOOT_TIMEOUT=360
if ! timeout $BOOT_TIMEOUT sh -c "while ! ping -c1 -w1 $FLOATING_IP; do sleep 1; done"; then
        echo "Couldn't ping server"
        exit 1
fi

# Tempest integration
eval export $(cat /opt/stack/manila/contrib/ci/pre_test_hook.sh |grep "TEMPEST_COMMIT=")
OLD_PWD=$(pwd)
cd /opt/stack/tempest
git checkout $TEMPEST_COMMIT
cp -r /opt/stack/manila/contrib/tempest /opt/stack/
cd $OLD_PWD

# Manila Horizon UI
cd /opt/stack && git clone https://github.com/hp-storage/manila-ui && git clone https://github.com/hp-storage/manila-ui
cd /opt/stack/horizon && git fetch https://review.openstack.org/openstack/horizon refs/changes/33/128133/10 && git checkout FETCH_HEAD
cd /opt/stack/horizon && cp openstack_dashboard/local/local_settings.py.example openstack_dashboard/local/local_settings.py
sed -i "s/'js_spec_files': \[\],/'js_spec_files': \[\],\n'customization_module': 'manila_ui.overrides',/" /opt/stack/horizon/openstack_dashboard/local/local_settings.py
sudo pip install -e /opt/stack/manila-ui
cd /opt/stack/horizon && cp ../manila-ui/_90_manila_admin_shares.py openstack_dashboard/local/enabled
cd /opt/stack/horizon && cp ../manila-ui/_90_manila_project_shares.py openstack_dashboard/local/enabled
sudo /etc/init.d/apache2 restart

