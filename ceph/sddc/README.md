Information from [1]

These scripts work only for one special use. This is an environment, where we have identical hyperconverged nodes with the following storage topology:

Disk /dev/sda: 300.0 GB, 299966445568 bytes, 585871964 sectors
Disk /dev/sdb: 1200.2 GB, 1200210141184 bytes, 2344160432 sectors
Disk /dev/sdc: 1200.2 GB, 1200210141184 bytes, 2344160432 sectors
Disk /dev/sdd: 1200.2 GB, 1200210141184 bytes, 2344160432 sectors
Disk /dev/sde: 1200.2 GB, 1200210141184 bytes, 2344160432 sectors
Disk /dev/sdf: 400.1 GB, 400054902784 bytes, 781357232 sectors
Disk /dev/sdg: 900.2 GB, 900151926784 bytes, 1758109232 sectors
Disk /dev/sdh: 900.2 GB, 900151926784 bytes, 1758109232 sectors
Disk /dev/sdi: 900.2 GB, 900151926784 bytes, 1758109232 sectors
Disk /dev/sdj: 900.2 GB, 900151926784 bytes, 1758109232 sectors
Disk /dev/sdk: 400.1 GB, 400054902784 bytes, 781357232 sectors

requirements: 
- cover stretched env across local DC 
- ensure continuous availability of storage layer in case one DC goes down 
- ensure continuous availability of storage layer in case one host goes down 
- provide access from "devel" and "prod" to both storage classes 
- ( picked: ) we don't distinguish between "devel" and "prod" inside storage classes 

solution approach: 
- define CRUSH map with 2 different top-level branches for storage classes: 
   - 900 GB HDD 10k based top-level 
   - 1200 GB HDD 10k based top-level 
- map must have two DC defined (identical) for both storage classes 
- must not allow two replicas to land on the same host (keep leaf definition) 
- cannot be able to accommodate additional host onto either side - must define the side

[1] HSRACKDEV-365