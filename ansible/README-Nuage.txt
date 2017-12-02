In Hailstorm you have fully integrated installation of Nuage 5.x and
integration with RHOSP and OCP. It has been only tested wth RHOSP11 and
OCP 3.5/6.

All code for integration of Nuage is enabled via the environment variable
"enable_nuage".

Structure
=========

The installation is done in 3 steps:
- install Nuage appliances
- patch Director and Overcloud image
- install Overcoud with Nuage

The first step is forwarded to the Nuage-Metro installer who will do the
job. Note that this installer is not idempotent. All other parts are
normal Hailstorm Ansible plays.


Deploy
=========

Creation of an Hailstorm environment with Nuage e.g. on storm6 can be
done with a command as simple as
ansible-playbook -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml create.yml -e "enable_nuage=nuage"

To deploy the parts of Nuage e.g. on storm6 in single steps use somethijng like the following:

a) Create required dnatting if you are using a virtual environment
ansible-playbook -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml create-01-base.yml --tags dnat --skip-tags satellite,tower

b) Create required route on the infrastructure/haproxy node
ansible-playbook -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml create-02-additional.yml --tags nuage -e "enable_nuage=nuage"

c) Install the nuage appliances (VSD, VSC, VSR)
ansible-playbook -vv -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml create-02-nuage.yml

NOTE: The installation frequently fails due to ghost-reasons. If that
happens and due to the non-idempotency of the Nuage playbooks, you have
to tear the Nuage part completely down as stated in "Tear down" below in
parts b, c and d. Then repeat the install step here to re-deploy.

d) Install OpenStack Director and Overcloud with already deployed Nuage
appliances
ansible-playbook -vv -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml -e "enable_nuage=nuage" create-03-osp.yml --skip-tags overcloud2,ipa-service


Passwords
=========

Paswords can be found at the end of config/hailstorm_config.yml. They
should not be changed as they are not forwarded to the Nuage installer,
but only used during installation.


Manual steps
============

After the deployment the following steps are required for the Nuage
infrastructure to be fully functional:

∘ Platform Configuration/Infrastructure/Data Center Gateways/Pending/{r1,r2}/Blue Check
∘ Platform Configuration/Infrastructure/Data Center Gateways/Gateways/{r1,r2}/WAN Services/vrf<num>001_FIP/Permissions/Shared Infrastructure
∘ Platform Configuration/Infrastructure/Data Center Gateways/Gateways/{r1,r2}/WAN Services/vrf<num>002_mgmt_data/Add OpenStack_Org
∘ Platform Configuration/Infrastructure/Data Center Gateways/Gateways/{r1,r2}/Blue Hammer (wait)
∘ Shared Infrastructure/L3 domains/Networks/Domain for FIPs in 10.32.96.0/router (symbol)/wan service/add r1 and r2 with vrf<num>001_FIP
∘ FOR ALL DOMAINS: OpenStack_Org/L3 domains/Networks/router <DOMAIN_NAME>/router (symbol)/wan service/add r1 and r2 with vrf<num>002_mgmt_data
∘ FOR ALL DOMAINS: OpenStack_Org/L3 domains/Networks/router <DOMAIN_NAME>/router (symbol)/dhcp/add option 26 with mtu 1450


Tear down
=========

Attention: This process will not remove anything from the Nuage VSR, so
the organization has to be removed manually, as well as the VSRs! To do
so, remove all VMs in OpenStack first!

a) Tear down RHOSP
ansible-playbook -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml destroy.yml --tags rhosp --skip-tags overcloud

b) Tear down Nuage appliances
ansible-playbook -i hosts_sddc -e @config/infrastructure_config_sddc.yml -e @config/hailstorm_config.yml -e @config/storm6.coe.muc.redhat.com.yml destroy.yml --tags nuage

c) In case of remaining VMs, remove them on e.g. storm6
for o in vsd c elastic r; do for m in destroy undefine; do for n in 1 2 3 4; do virsh $m $o$n.hailstorm6.coe.muc.redhat.com; done; done; done

d) In case of remaining xmpp DNS entries, remove them e.g. on storm6
ssh ipa.hailstorm6.coe.muc.redhat.com <<EOF
echo redhat01 | kinit admin && ipa dnsrecord-del hailstorm6.coe.muc.redhat.com xmpp --a-rec=10.116.127.156
echo redhat01 | kinit admin && ipa dnsrecord-del hailstorm6.coe.muc.redhat.com xmpp --a-rec=10.116.127.157
echo redhat01 | kinit admin && ipa dnsrecord-del hailstorm6.coe.muc.redhat.com xmpp --a-rec=10.116.127.158
EOF


Configuration
=============

a) Hosts
All appliances with their networks and IPs are defined in the hosts file
(like "-i hosts_sdds" in our examples) in the group [nuage] and referred
to in the groups [nuage-vsd] and [nuage-elastic]. Keep in mind that VSR
and VSC can only deal with FQDN not longer than 32 characters!

b) Variables
All variables for Nuage are held in config/hailstorm_config.yml in the
variable "nuage".

c) Binaries and Licenses
For Nuage binaries and licenses there are 2 places that are used to copy
them from to the install-host, that actually does the installation:
- binary/{{ nuage.metro_bins }}			# currently binary/nuage
- <KVM-Host, e.g. storm6.coe.muc.redhat.com>:/var/hailstorm/nuage_binary/

In those directories you can have subdirs
- binaries
- licenses
- and in case of KVM-Host also {{ nuage.metro_bins }}
which will later be used by the Nuage installer.

Note that all files in the first source will be overwritten by the files
with the same name in the second source.

d) Nuage RHOSP integration files
Those files come from a public github repository
(https://github.com/nuagenetworks/nuage-ospdirector/wiki/Nuage-OSP-Director-11-integration-with-ML2)
and are held for a stable environment in
- layer2_rhosp_undercloud_configure_nuage/files

e) Nuage-Metro installer

This ansible installer for the appliances comes from a private Nuage
github repository (https://github.com/nuagenetworks/nuage-metro) which is
held as nuage-metro-latest.tar.gz where the binaries are.

Its configuration is held in
- layer2_nuage/templates/ha_build_vars.yml.j2

Note that the actual installation of the appliances is done by this
installer which will be called on the install-host in a special python
environment, prepared by the role layer2_nuage.

Components
==========

a) Roles
The work for the appliances is done on the install-host using the role
- layer2_nuage

The work for the Director is done in the role
- layer2_rhosp_undercloud_configure_nuage

And the deployment is done - modified by the variable enable_nuage - in
the normal roles
- layer2_rhosp_overcloud_deploy
- layer2_rhosp_overcloud_postdeploy_controller

There is also an addiitonal route needed on the haproxy host
"infrastructure" done in
- layer2_infrastructure

b) Templates
Templates used especially for nuage are in
layer2_rhosp_overcloud_deploy/templates:
- neutron-nuage-config.yaml.j2
- nova-nuage-config.yaml.j2
- controller-nuage.yaml.j2
- compute-nuage.yaml.j2
- controller-baremetal-nuage.yaml.j2
- compute-baremetal-nuage.yaml.j2

Templates at the same place adapted for Nuage usage if enabled are:
- network-environment.yaml.j2
- deploy-overcloud.j2

c) HaProxy
The haproxy config can be found in create-02-nuage.yml.

d) DNAT
The VSD and VSTAT (aka elasticsearch) are reachable via the haproxy which
resides on the host "infrastructure". The DNAT configuration is held in
config/<KVM-Host, e.g. storm6.coe.muc.redhat.com> in the section
- external_network_config:
  services_network_dnat:
    mapping:
      - expose_machine: infrastructure
for ports 443 and 7443 for VSD (OSP/OCP) as well as 9200 for VSTAT..
