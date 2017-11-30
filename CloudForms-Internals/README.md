ICD : default

-Automate: 
--Only ICD_eumartin enabled

-Ansible: Not Used

-Dialogs:
--ICD13xxxx
--ICD14xxxx
--ICD15xxxx
--ICD16xxxx
--ICD17xxxx?


IAV : disabled

-Automate:
-- Import from GIT : https://github.com/supernoodz/cloudforms-hailstorm
-- Enable top: TigerIQ_eumartin

-Dialogs:
--"Order (RHEL7|Windows) Web Cloud Service" (Entry point)
--"RHEL_roles"
--"WINDOWS_roles"

-Ansible:
-- Add git repo : https://github.com/eumartin/ansible_rhel
-- Map playbooks
--- rhel_roles to Service dialog RHEL_roles (same names, is consumed from rb)
--- win_roles to Service dialog  WIN_roles (idem)

