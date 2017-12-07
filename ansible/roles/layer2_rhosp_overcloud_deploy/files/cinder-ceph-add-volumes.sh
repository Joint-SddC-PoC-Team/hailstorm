#!/bin/bash
# cinder-ceph-add-volumes.sh
# Setup cinder for multiple ceph pools with different storage classes
# Author : Mohammed Salih <msalih@redhat.com>
# (C)2017 Red Hat Inc.
# Expected : Ceph pools "volumes-fast" & "volumes-slow" to be already created with right storage classes.


# Source stackrc
source ~/stackrc

# Get IP addresses of controller nodes
osp_controllers=$(openstack server list|grep overcloud-controller-.|cut -d "=" -f 2|cut -d " " -f 1)

# Iterate through the controller nodes and add the new pools from Ceph.
# it sets the existing backend "tripleo_ceph" as the default backend.
for node in $osp_controllers ; do
  ssh heat-admin@$node '
    vol_count=$(sudo ceph osd dump |grep ^pool|egrep "volumes-(fast|slow)"|wc -l)
    if [ "x"$vol_count != "x" ] ; then
      rbd_secret=$(sudo crudini --get /etc/cinder/cinder.conf tripleo_ceph rbd_secret_uuid)
      sudo crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends tripleo_ceph,volumes-fast,volumes-slow
      sudo crudini --set /etc/cinder/cinder.conf DEFAULT default_volume_type tripleo_ceph
      for type in fast slow ; do
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} volume_backend_name volumes-${type}
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} volume_driver cinder.volume.drivers.rbd.RBDDriver
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} rbd_ceph_conf /etc/ceph/ceph.conf
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} rbd_user openstack
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} rbd_pool volumes-${type}
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} rbd_secret_uuid ${rbd_secret}
        sudo crudini --set /etc/cinder/cinder.conf volumes-${type} backend_host hostgroup
      done
      echo "Configuration done on $node"
    else
      echo "Error: Ceph pools volumes-fast and/or volumes-slow could not be found"
    fi
  '
done

# Restart cinder-volume service using pcs on one of the controller nodes
ssh heat-admin@$(echo -e "$osp_controllers"|head -1) 'sudo pcs resource restart openstack-cinder-volume && sleep 5 && sudo pcs status'
echo "Cinder-Volume service restarted on $(echo -e "$osp_controllers"|head -1)"

for node in $osp_controllers ; do
  ssh heat-admin@$node 'sudo systemctl restart openstack-cinder-scheduler.service'
  echo "Cinder-Scheduler restarted on $node"
done
# Create Cinder storage types
source ~/overcloudrc.v3
cinder type-create volumes-fast
cinder type-create volumes-slow
cinder type-key volumes-fast set volume_backend_name=volumes-fast
cinder type-key volumes-slow set volume_backend_name=volumes-slow
