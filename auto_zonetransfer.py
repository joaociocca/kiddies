#!/usr/bin/env python3
# original source https://gist.github.com/gothburz/f9805f0b10637e69dcb887d3292abee3

# depends on dnspython
import dns.resolver, dns.zone, sys

# receives domain name as argument
address = sys.argv[1]

# resolve the NS server
ns_answer = dns.resolver.resolve(address, 'NS')

# loop through the answers
for server in ns_answer:
    # resolve the A record
    ip_answer = dns.resolver.query(server.target, 'A')
    # loop through the answers
    for ip in ip_answer:
        try:
            # attempt zone transfer
            zone = dns.zone.from_xfr(dns.query.xfr(str(ip), address))
            # loop through the results
            for host in zone:
                print("[*] Found NS vulnerable to zone transfer: {}".format(server))
                print("[*] Found Host: {}".format(host))
        # if zone transfer fails
        except Exception as e:
            print("[*] Found NS {}, but it refused zone transfer!".format(server))
            continue