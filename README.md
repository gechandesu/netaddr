# Network address processing library for V

`netaddr` supports IP (both IPv4 and IPv6) and EUI (EUI-48, EUI-64) addresses.

Features:

- Parsing and validation of EUI, IP addresses and IP network addresses.
- Converting addresses to/from different formats, e.g. various string representations, byte arrays, integers.
- IP addresses and networks comparison.
- IPv4-IPv6 interoperability.
- IPv6 scopes support.
- Parsing/creating Teredo (IPv4 over IPv6 tunneling) addresses.
- Testing addresses and networks i.e. check is network intended for private use or not and many other tests.
- Generating random EUI-48 (useful for virtual machines, etc).
- Converting EUI to IPv6.
- Calculating IP networks (both versions).
- ...

## Usage

### IP address/network parsing and validation

Once you got an `Ipv{4,6}Addr` or `Ipv{4,6}Net` instance without errors — that's done,
validation is passed. In the simplest case you can do:

```v okfmt
if ip := netaddr.IpAddr.from_string('::1') {
	// address is valid
} else {
	// address is not valid
}
```

More concrete example that prints the address on success:

```v
import netaddr

fn main() {
	addr := arguments()[1] or {
		panic('no such argument, specify an IP address')
	}
	ip := netaddr.IpAddr.from_string(addr) or {
		panic('${addr} is not valid IP address')
	}
	if ip is netaddr.Ipv4Net || ip is netaddr.Ipv6Net {
		panic('${ip} seems to be network, not a single host addresses')
	}
	println(addr)
}
```

### Working with IP networks

Basic usage:

```v
import netaddr

fn main() {
	network4 := netaddr.Ipv4Net.from_string('172.16.16.0/24')!
	network6 := netaddr.Ipv6Net.from_string('fe80:aaaa:bbbb:cccc::/64')!
	println(network4)
	println(network6)
}
```

The `from_string()` method of the Ipv4Net and Ipv6Net structs supports several different
formats for network prefixes:

- a single address without a prefix length will be considered as a network with a prefix of 32 or 128 depending on the IP version;
- an address with an integer non-negative prefix length;
- an address with a subnet mask;
- an address with a host mask;

```v okfmt
network := netaddr.Ipv4Net.from_string('203.0.113.99/0.0.0.255')!
assert network.network_address.str() == '203.0.113.0'
assert (network.host_address as netaddr.Ipv4Addr).str() == '203.0.113.99'
```

If host bits is set in the network address the optional `host_address` field will be filled with
this host address. The `network_address` field always will contain the real network address.
The `host_address` will equal `none` for single address "networks" such as `127.0.0.1/32`, etc.

#### Iterating over network hosts

`Ipv4Net` and `Ipv6Net` has `next()` method that implements the V iterator mechanism
which allow you use object in `for` loop in following maner:

```v okfmt
network := netaddr.Ipv4Net.from_string('172.16.16.0/26')!
for host in network {
	// `host` is an Ipv4Addr instance
	if host == network.network_address || host == network.broadcast_address {
		continue
	}
	println(host)
}
```

Note that the iterator will iterate over all addresses in the network, including those that
cannot be used as a host address: the network address and broadcast address. Exceptions are
the networks with small prefixes: 31 (point-to-point) and 32 (single address) for IPv4, and
127 and 128 for IPv6 respectively.

If you just want to check is network contain some address use `contains()` method:

```v okfmt
network := netaddr.Ipv4Net.from_string('172.16.0.0/26')!
addr := netaddr.Ipv4Addr.from_string('172.16.16.68')!
assert !network.contains(addr)
```

#### Networks intersection tests and subnetting

To choose the right prefix when planning a network, it is important to avoid overlapping
network address spaces.

Check partial overlapping:

```v okfmt
net_a := netaddr.Ipv4Net.from_string('100.64.0.0/22')!
net_b := netaddr.Ipv4Net.from_string('100.64.4.0/22')!
assert !net_a.overlaps(net_b)
```

Also you can check is the network a subnet or supernet of another one:

```v okfmt
assert !net_a.is_subnet_of(net_b)
assert !net_a.is_supernet_of(net_b)
```

To split the network into equal prefixes, you can use the `subnets()` method:

```v okfmt
network := netaddr.Ipv4Net.from_string('100.64.64.0/20')!
println(network)
mut subnets := []netaddr.Ipv4Net{}
for subnet in network.subnets(22)! {
	subnets << subnet
}
println(subnets)
// [100.64.64.0/22, 100.64.68.0/22, 100.64.72.0/22, 100.64.76.0/22]
```

### IPv4-IPv6 interoperability

`netaddr` supports IP conversion between 4 and 6 versions in both directions.

The V REPL session below illustrates this:

```
>>> import netaddr
>>> ip4 := netaddr.Ipv4Addr.from_string('203.0.113.99')!
>>> ip4
203.0.113.99
>>> ip6 := ip4.ipv6()
>>> ip6
::ffff:203.0.113.99
>>> ip6.is_ipv4_mapped()
true
>>> ip6.is_ipv4_compat()
false
>>> ip6.ipv4()!
203.0.113.99
>>> ip4 == ip6.ipv4()!
true
```

IPv6 address cannot be converted to IPv4 if it is not the IPv4-mapped or IPv4-compatible
per RFC 4291 Section 2.5.5.

Also several representation formats are supported:

```
>>> ip6.format(.dotted | .compact)
::ffff:203.0.113.99
>>> ip6.format(.dotted | .verbose)
0000:0000:0000:0000:0000:ffff:203.0.113.99
>>> ip6.format(.compact)
::ffff:cb00:7163
>>> ip6.format(.verbose)
0000:0000:0000:0000:0000:ffff:cb00:7163
```

### Dealing with scoped IPv6 addresses

`Ipv6Addr` struct has optional `zone_id` field that contains the scope zone identifier
if available. For example (V REPL session):

```
>>> ip6_scoped := netaddr.Ipv6Addr.from_string('fe80::d08e:6658:38bd:6391%wlan0')!
>>> ip6_scoped
fe80::d08e:6658:38bd:6391%wlan0
>>> ip6_scoped.zone_id
Option('wlan0')
>>> zone_id := ip6_scoped.zone_id as string
>>> zone_id
wlan0
```

For creating scoped address from `big.Integer`, `u8`, `u16`, etc use the optional `zone_id`
parameter. e.g.:

```v okfmt
// vfmt off
new := netaddr.Ipv6Addr.new(
	0xfe80, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x1234,
	zone_id: 'eth0'
)!
from_u8 := netaddr.Ipv6Addr.from_octets(
	[
		u8(0xfe), 0x80,
		0x0, 0x0,
		0x0, 0x0,
		0x0, 0x0,
		0x0, 0x0,
		0x0, 0x0,
		0x0, 0x0,
		0x12, 0x34
	]!,
	zone_id: 'eth0'
)!
// vfmt on
println(new) // fe80::1234%eth0
println(from_u8) // fe80::1234%eth0
```

Also you can create new IPv6 address with zone_id from existing `Ipv6Addr` instance:

```
>>> ip6 := netaddr.Ipv6Addr.from_string('fe80::d08e:6658:38bd:6391')!
>>> new_ip6 := ip6.with_scope('eth1')!
>>> new_ip6
fe80::d08e:6658:38bd:6391%eth1
```

Scoped IPv6 networks are supported, but `Ipv6Net` struct does not have own `zone_id`
field, refer to it's `network_address` as follows:

```
>>> ip6net := netaddr.Ipv6Net.from_string('fe80::%eth1/64')!
>>> ip6net
fe80::%eth1/64
>>> ip6net.network_address.zone_id
Option('eth1')
```

### Getting global unicast IPv6 from EUI-48

This is a slightly synthetic example that shows how you can automatically get a global
unicast IPv6 address for a host given the network prefix.

```v okfmt
// Known network prefix
network := netaddr.Ipv6Net.from_string('2001:0db8::/64')!
// Lets generate random EUI-48
eui := netaddr.Eui48.random()
// ipv6() method converts EUI-48 to Modified EUI-64 and appends it to prefix per RFC 4291
ip := eui.ipv6(network.network_address)!
println(ip) // 2001:db8::8429:6bff:fedc:ef8b
```

Note that using EUI in IPv6 address may cause security issues. See
[RFC 4941](https://datatracker.ietf.org/doc/html/rfc4941) for details.

# License

`netaddr` is released under LGPL 3.0 or later license.

SPDX Lincese ID: `LGPL-3.0-or-later`.
