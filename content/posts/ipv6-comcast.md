---
title: IPv6 on Comcast
description: >
  Notes from my experience setting up IPv6/IPv4 (dual stack) connectivity
  with Comcast/Xfinity.
summary: >
  Notes from my experience setting up IPv6/IPv4 (dual stack) connectivity
  with Comcast/Xfinity.
date: 2024-07-01
tags: ["comcast", "xfinity", "ipv4", "ipv6", "networking", "dns", "dhcp", "ethernet", "router", "dual-stack"]
author: ["Marco Paganini"]
draft: false
---

# IPv6 on Comcast

## Assumptions

For this set of notes, we assume that:

* The router is a multi-interface machine running Debian.
* One interface is connected directly to the Comcast modem/router (in gateway mode).
* The remaining interfaces are connected to the inside network.
* Interfaces could be actual physical interfaces or VLANs.
* We're using `dnsmasq` to provide DHCP and DNS services to internal hosts.
* Comcast and Xfinity are the same company and use the same setup.

## WAN (eth0) configuration using wide-dhcpv6

This component does a few important things:

* Retrieves an IPv6 address (from Comcast) for our external interfaces (Using IA).

* Retrieves a prefix from Comcast using Prefix Discovery (PD). By default,
  Comcast will send a /64 prefix, which is only good for one host (we need more
  networks, as routing anything less than a /64 tends to break a lot of stuff
  in IPv6). In this case, we use `wide-dhcpv6-client` to request a /60 from
  Comcast. Note that the network is *not* related to the IP address given to the
  interface.

* Assign IPv6 addresses to each of the other (internal) interfaces, based on
  the prefix received from Comcast and our configuration (see below).

* Note that routes (including default routes) in IPv6 are assigned via RA.
  Make sure `net.ipv6.conf.all.accept_ra` and `net.ipv6.conf.<interface>.accept_ra`
  are **both** set to 2 in `/etc/sysctl.conf` (normally interface here is
  the WAN interface, eth0.)

  Sample `/etc/sysctl.conf` entries:

```
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.eth0.accept_ra=2
```

  * Note: Setting it to 1 will work partially, but the WAN interface (eth0)
    won't receive the default route to the Internet, breaking things.

Sample wide-dhcpv6 config (eth0 = external interface, lan0.X = internal VLANs).
Note that PD = Prefix Discovery and NA = Normal Address:

```
profile default
{
  information-only;
  script "/etc/wide-dhcpv6/dhcp6c-script";
};

interface eth0 {
  send ia-na 1;
  send ia-pd 1;
};

id-assoc na 1 {
};

id-assoc pd 1 {
  # Request a /60 from Comcast.
  prefix ::/60 infinity;

  # `sla-id` is the Site Level Aggregator (SLA) used to form the IPv6 of each
  # of the interfaces. The format is normally `<prefix><sla-id>::<if-id>`. We
  # Match the VLAN number for easy identification of IPv6 addresses.
  #
  # `sla-len` is how long the SLA ID should be (in bits). In our case, we have
  # a /60 given to us by Comcast and we want each interface to have a /64,
  # so this should be 4.
  #
  # `if-id` identifies the interface number (in practive, the last octet)
  # inside each interface. We use 1 so that each interface in the server
  # will end up in `:1`.
  #
  # To reset the DUID (including the PD ip range), remove `/var/lib/dhcpv6/dhcp6c_duid`
  # and restart wide-dhcpv6.

  # Guest network
  prefix-interface lan0.3 {
    sla-id 3;
    sla-len 4;
    ifid 1;
  };

  # Internal network
  prefix-interface lan0.4 {
    sla-id 4;
    sla-len 4;
    ifid 1;
  };

  # DMZ
  prefix-interface lan0.5 {
    sla-id 5;
    sla-len 4;
    ifid 1;
  };
};
```

It should be possible to request multiple PDs with multiple `id_assoc` with
different `pd` values and only one interface inside. This should make it
possible to have multiple interfaces even if the provider only gives /64 PDs. I
have **not** tested this.

wide-dhcpv6 (`dhcp6c -Pdefault -d <interface>`) is started by systemd. Extra
configuration is present in `/etc/default/wide-dhcpv6-client`.  Sample:

```
# Interfaces on which the client should send DHCPv6 requests and listen to
# answers. If empty, the client is deactivated.
INTERFACES="eth0"

# Verbose level for syslog. Default is 0 (0: minimal; 1: info; 2: debug)
VERBOSE=1
```

# DNSMASQ configuration

DNSMASQ is used to:

* Assign internal IPv6 addresses, based on the client's IPv4 addresses and their network.

* Send Route Advertisements (RA) to the internal networks.

To enable RA, set `enable-ra` in `/etc/dnsmasq.conf`.

IPv6 can also use RAs for IPs, setting the AAAA record from IPv6 dhcp_names.
Sample excerpt from `/etc/dnsmasq.conf` for two internal networks on the
interfaces `lan1.3` and `lan1.4`:

```
dhcp-range=::100,::999,constructor:lan1.3,slaac,ra-names,24h
dhcp-range=::100,::999,constructor:lan1.4,slaac,ra-names,24h
```

* `dhcp-range` defines a range for a given interface. There's one for interface
  `lan1.3` and another for interface `lan1.4`.
* IPv6 addresses given will have the last number starting with 100 and ending
  as 999.  Please note that the man page for dnsmasq indicates that the upper
  limit of the IPv6 range (::100, ::999, in this case ::999) is not needed.
  This was indeed the case, but apparently after a dnsmasq upgrade, stopped
  working **without any error messages**.  I spent a good number of hours
  diagnosing this.
* The option `ra_names` will populate AAAA records with the names.
* Without `slaac` android phones won't get an IPv6 address.

There are many other options available.  See dnsmasq documentation for more
details.

## Debugging RA messages

Use `radvdump` to see the stream of RA messages. This will show RA
advertisement messages from all interfaces.

Another option, using tcpdump:

```bash
sudo tcpdump -i eth0 -v multicast and not broadcast
```

To see the advertised prefix, turn on debugging for wide-dhcpdv6 (in
`/etc/default/wide-dhcpv6-client`) or run the tcpdump command above and grep
for `IA-PD-prefix`. Sample output from tcpdump:

```
IA_PD-prefix 2601:646:9e02:6040::/60
```

Remember that with a /64 (the default) it won't be possible to have multiple
internal networks.

Sample routing table on client inside internal network:

```
$ ip -6 route show

::1 dev lo proto kernel metric 256 pref medium
2601:546:9680:5924::/64 dev eth0 proto ra metric 100 pref medium
fe80::/64 dev eth0 proto kernel metric 100 pref medium
default via fe80::5ca2:99ff:fe50:d55d dev eth0 proto ra metric 100 pref medium
```

Note how the fe80 (link local) addresses are used as destination for internal
routes. The default gateway points to the link local address of the router.

### Case study: No default route

For some reason, there's no default route pointing to Comcast (on the server):

```
$ ip -6 r s | grep '^default'
<nothing>
```

Using `radvdump` we see messages coming from eth0 (fe80::201:5cff:eea9:3446), but no
default routes. The following routes are present (but still don't generate entries
in the routing tables):

```
prefix 2001:558:4000:62::/64
prefix 2001:558:5027:c6::/64
prefix 2001:558:6045:74::/64
prefix 2001:558:8046:b6::/64
```

Adding a default route for testing purposes works:

```
ip -6 route add default via fe80::201:5cff:eea9:3446 dev eth0
```

Cause: missing `accept_ra = 2` in `/etc/sysctl.conf`.

## Other differences

* The `arp` command is now `ip neigh`. Use `ip -6 neigh show` to see IPv6 and
  mac addresses.
* With IPv6, there's no need for NATing, so **your internal hosts are exposed
  to the Internet**.  Make sure you create proper firewall rules in your
  router.

## Dynamic addresses on clients

IPv6 can use DHCP6 or SLAAC (stateless) to give addresses to clients. SLAAC is
simpler, but can't be used to set fixed addresses on certain hosts, for
example.

Clients typically end up with two types of addresses on clients: "temporary
dynamic" and "mngtmpaddr noprefixroute", or "scope global".  The first is, as
the name implies, dynamic and used by clients (for privacy purposes). The
second is the "fixed" address of the machine, used for inbound connections.
Once dynamic addresses expire (check the `valid_lft` and `preferred_lft`
fields), they become "temporary deprecated dynamic" until they eventually
disappear from the address table.

Example:

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    inet6 2601:646:ee02:6044::2d4/128 scope global dynamic noprefixroute
       valid_lft 74866sec preferred_lft 74866sec
    inet6 2601:646:ee02:6044:ca60:ff:fe5f:9fd8/64 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::ea60:ff:fe5f:9fd8/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

## Useful Links

* Test your IPv6 connectivity:
  * https://test-ipv6.com
  * https://ipv6-test.com
