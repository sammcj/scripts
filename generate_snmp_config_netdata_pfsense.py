# Generates netdata snmp config file for PFSense
# Requires: pip install pysnmp pyyaml
# Author: Sam McLeod (2023)

# To find OIDs: snmpwalk -t 20 -O fn -v 2c -c public 192.168.0.1

import sys
from pysnmp.hlapi import SnmpEngine, CommunityData, UdpTransportTarget, ContextData, ObjectType, ObjectIdentity, nextCmd
import yaml

host = '192.168.0.1' # replace with your pfSense IP
community = 'public' # replace with your community string
base_oid = '1.3.6.1.2.1.2.2.1'  # OID for interfaces
outfile = 'snmp.conf'

# Define prefixes for CPU, memory, and disk usage OIDs
search_oid_prefixes = [
    '1.3.6.1.2.1.5',        # Bandwidth
    '1.3.6.1.2.1.4.20.1',   # Interface status
    '1.3.6.1.2.1.25.6.3.1.5.1', # Uptime
    '1.3.6.1.2.1.25.2.3.1.3.237', # State Table Count
    '1.3.6.1.2.1.25.3.2.1.3.15', # CPU core0 temp
    '1.3.6.1.4.1.2021.10',  # CPU load
    '1.3.6.1.4.1.2021.4',   # memory usage
    '1.3.6.1.4.1.2021.9'    # disk usage
]

def snmp_walk(host, community, oid):
    for (errorIndication,
         errorStatus,
         errorIndex,
         varBinds) in nextCmd(SnmpEngine(),
                              CommunityData(community),
                              UdpTransportTarget((host, 161)),
                              ContextData(),
                              ObjectType(ObjectIdentity(oid)),
                              lexicographicMode=False):

        if errorIndication:
            print(errorIndication, file=sys.stderr)
            break
        elif errorStatus:
            print(f'{errorStatus.prettyPrint()} at {errorIndex and varBinds[int(errorIndex) - 1][0] or "?"}', file=sys.stderr)
            break
        else:
            for varBind in varBinds:
                yield varBind

def find_relevant_oids(host, community, oid_prefixes):
    relevant_oids = {}
    for oid_prefix in oid_prefixes:
        for varBind in snmp_walk(host, community, oid_prefix):
            oid, value = varBind
            oid_str = oid.prettyPrint()

            # Filter logic based on OID prefix
            if any(oid_str.startswith(prefix) for prefix in oid_prefixes):
                relevant_oids[oid_str] = value.prettyPrint()

    return relevant_oids

def generate_netdata_config(oids, filename):
    config = {
        'jobs': [
            {
                'name': 'pfSense',
                'update_every': 60,
                'hostname': host,
                'community': community,
                'options': {'version': 2},
                'charts': []
            }
        ]
    }

    for index, name in oids.items():
        in_oid = f"{base_oid}.10.{index}" # OID for inbound bandwidth
        out_oid = f"{base_oid}.16.{index}" # OID for outbound bandwidth
        if_status_oid = f"{base_oid}.7.{index}" # OID for interface status

        # Add bandwidth chart for each interface
        bandwidth_chart = {
            'id': f"bandwidth_{name}",
            'title': f"pfSense Bandwidth for {name}",
            'units': "kilobits/s",
            'type': "area",
            'family': "interfaces",
            'dimensions': [
                {'name': "in", 'oid': in_oid, 'algorithm': "incremental", 'multiplier': 8, 'divisor': 1000},
                {'name': "out", 'oid': out_oid, 'algorithm': "incremental", 'multiplier': -8, 'divisor': 1000}
            ]
        }
        config['jobs'][0]['charts'].append(bandwidth_chart)

        # Add interface status chart for each interface
        if_status_chart = {
            'id': f"if_status_{name}",
            'title': f"Interface Status for {name}",
            'units': "status",
            'type': "line",
            'family': "interfaces",
            'dimensions': [
                {'name': f"status_{name}", 'oid': if_status_oid, 'algorithm': "absolute"}
            ]
        }
        config['jobs'][0]['charts'].append(if_status_chart)

    # # Example Creating charts for additional specific named metrics
    # metrics = [
    #     ('state_table_count', state_table_oid, 'State Table Counts', 'count'),
    #     ('pf_matches', pf_matches_oid, 'Packet Filter Matches', 'matches'),
    #     ('memory_drops', mem_drops_oid, 'Memory Drops', 'drops'),
    #     ('source_nodes_count', src_nodes_oid, 'Source Nodes Count', 'count'),
    # ]

    # for metric_id, oid, title, unit in metrics:
    #     chart = {
    #         'id': metric_id,
    #         'title': f"pfSense {title}",
    #         'units': unit,
    #         'type': "line",
    #         'family': "pfSense_metrics",
    #         'dimensions': [
    #             {'name': metric_id, 'oid': oid, 'algorithm': "absolute"}
    #         ]
    #     }
    #     config['jobs'][0]['charts'].append(chart)

    with open(filename, 'w') as file:
        yaml.dump(config, file)

def main():
    oids = {}

    for varBind in snmp_walk(host, community, base_oid):
        oid, value = varBind
        interface_name = value.prettyPrint()
        # Extract the interface index from the OID
        interface_index = oid.prettyPrint().split('.')[-1]
        oids[interface_index] = interface_name

    search_oids = find_relevant_oids(host, community, search_oid_prefixes)
    # add the non-interface OIDs to the list
    oids.update(search_oids)

    generate_netdata_config(oids, outfile)

if __name__ == '__main__':
    main()
