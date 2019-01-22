import json
import sys
import subprocess
import ipaddress

result = subprocess.run(['terraform', 'show', '-no-color'], stdout=subprocess.PIPE).stdout.decode('utf-8').split('\n')

heading = None
tmpDict = {}
for line in result:
    if line.strip()[-1:] == ":":
        heading = line.strip()[0:-1]
        tmpDict[heading] = {}
    else:
        if line.strip() == '':
            continue
        k, v = line.strip().replace(" ", "").split("=")
        tmpDict[heading][k] = v

dictKeys = list(tmpDict.keys())
for i in dictKeys:
    if "openstack_compute_floatingip_associate_v2" not in i and"openstack_compute_instance_v2" not in i:
        del tmpDict[i]

        

for fipKey in dictKeys:
    if "openstack_compute_floatingip_associate_v2" in fipKey:
        for compKey in dictKeys:
            if "openstack_compute_instance_v2" in compKey:
                if tmpDict[compKey]['id'] == tmpDict[fipKey]['instance_id']:
                    tmpDict[compKey]['floating_ip'] = tmpDict[fipKey]['floating_ip']
        del tmpDict[fipKey]

#print(json.dumps(tmpDict, indent=2))
ansible_inventory = {'all': []}
ip_cidr = ipaddress.ip_network('192.168.70.0/24')
for i in tmpDict.keys():
    #print(i)
    # try:
    #     if tmpDict[i]['metadata.entrypoint']:
    #         #print(tmpDict[i])
    #         print("====\nName:\t{0}\nfip:\t{1}\n====".format(tmpDict[i]['name'], tmpDict[i]['floating_ip']))
    # except Exception as e:
    #    pass
    networks=[ipaddress.ip_address(value) for key, value in tmpDict[i].items() if '.fixed_ip_v4' in key.lower()]
    correct_network=None
    for ip in networks:
        if ip in ip_cidr:
            correct_network = str(ip.exploded)
   #print("====\nName:\t{0}\nIP:\t{1}\n====".format(tmpDict[i]['name'], correct_network))
    ansible_inventory['all'].append(correct_network)
    try:
        for group in tmpDict[i]['metadata.ansible_groups'].strip().split(","):
            if str(group) not in ansible_inventory.keys():
                ansible_inventory[str(group)] = []
            ansible_inventory[str(group)].append(correct_network)
    except Exception as e:
        print(e)
        pass

print("[all:vars]\nansible_private_key_file={}".format(sys.argv[1]))
for key in ansible_inventory.keys():
    print('[{}]'.format(key))
    for ip in ansible_inventory[key]:
        print(ip)

