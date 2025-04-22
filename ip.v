// This file is part of netaddr.
//
// netaddr is free software: you can redistribute it and/or modify it under
// the terms of the GNU Lesser General Public License as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// netaddr is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
// License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with netaddr. If not, see <https://www.gnu.org/licenses/>.

module netaddr

import encoding.binary
import math.bits
import net

pub struct Ipv4Addr {
	addr [4]u8
}

// Ipv4Addr.new creates new Ipv4Addr instance from four octets.
pub fn Ipv4Addr.new(a u8, b u8, c u8, d u8) Ipv4Addr {
	return Ipv4Addr{
		addr: [a, b, c, d]!
	}
}

// Ipv4Addr.from_octets creates new Ipv4Addr instance from four-element byte array.
pub fn Ipv4Addr.from_octets(addr [4]u8) Ipv4Addr {
	return Ipv4Addr{addr}
}

// Ipv4Addr.from_string parses addr string and creates new Ipv4Addr instance.
// Only dotted-decimal form is allowed e.g. 203.0.113.5.
pub fn Ipv4Addr.from_string(addr string) !Ipv4Addr {
	octets := addr.split('.')
	if octets.len != 4 {
		return error('expected 4 octets in ${addr}')
	}
	mut bytes := [4]u8{}
	for i := 0; i < 4; i++ {
		bytes[i] = u8(octets[i].parse_uint(10, 8) or {
			return error('${octets[i]} is not valid unsigned 8 bit integer in ${addr}')
		})
	}
	return Ipv4Addr{bytes}
}

// Ipv4Addr.from_u32 creates new Ipv4Addr instance from unsigned 32 bit integer.
pub fn Ipv4Addr.from_u32(addr u32) Ipv4Addr {
	mut bytes := [4]u8{}
	binary.big_endian_put_u32_fixed(mut bytes, addr)
	return Ipv4Addr{bytes}
}

// str returns string representation of IP address.
pub fn (a Ipv4Addr) str() string {
	// string concatenation is much faster than interpolation
	return a.addr[0].str() + '.' + a.addr[1].str() + '.' + a.addr[2].str() + '.' + a.addr[3].str()
}

// u32 returns IP address represented as unsigned 32 bit integer.
pub fn (a Ipv4Addr) u32() u32 {
	return binary.big_endian_u32_fixed(a.addr)
}

// u8_array returns IP address represented as byte array.
pub fn (a Ipv4Addr) u8_array() []u8 {
	return a.addr[..]
}

// u8_array_fixed returns IP address represented as fixed size byte array.
pub fn (a Ipv4Addr) u8_array_fixed() [4]u8 {
	return a.addr
}

// ipv6 returns IPv4-mapped or IPv4-compatible IPv6 address per RFC 4291.
// By default returns the IPv4-mapped IPv6 address e.g. ::ffff:203.0.113.90.
pub fn (a Ipv4Addr) ipv6(params Ipv4ToIpv6Params) Ipv6Addr {
	mut bytes := [16]u8{}
	if params.kind == .mapped {
		bytes[10] = u8(255)
		bytes[11] = u8(255)
	}
	bytes[12] = a.addr[0]
	bytes[13] = a.addr[1]
	bytes[14] = a.addr[2]
	bytes[15] = a.addr[3]
	return Ipv6Addr{
		addr: bytes
	}
}

// bit_len returns number of bits required to represent IP address.
// Example:
// ```
// assert netaddr.Ipv4Addr.new(0, 0, 255, 255).bit_len() == 16
// ```
pub fn (a Ipv4Addr) bit_len() int {
	return bits.len_32(a.u32())
}

// family returns the `net.AddrFamily` member corresponding to IP version.
pub fn (a Ipv4Addr) family() net.AddrFamily {
	return .ip // net.AddrFamily.ip means IP version 4
}

// reverse_pointer returns reverse DNS record for the IP address in .in-addr.arpa zone.
pub fn (a Ipv4Addr) reverse_pointer() string {
	return a.str().split('.').reverse().join('.') + '.in-addr.arpa'
}

// is_link_local returns true if the address is reserved for link-local usage.
pub fn (a Ipv4Addr) is_link_local() bool {
	return ipv4_link_local_network.contains(a)
}

// is_loopback returns true if this is a loopback address.
pub fn (a Ipv4Addr) is_loopback() bool {
	return ipv4_loopback_network.contains(a)
}

// is_multicast returns true if the address is reserved for multicast use.
pub fn (a Ipv4Addr) is_multicast() bool {
	return ipv4_multicast_network.contains(a)
}

// is_unicast returns true if the address is unicast.
pub fn (a Ipv4Addr) is_unicast() bool {
	return !a.is_multicast()
}

// is_shared returns true if the address is allocated in shared address space.
// See RFC 6598. Addresses from network 100.64.0.0/10 is both not "private" and
// not "global", so is_private and is_global methods returns false for it.
pub fn (a Ipv4Addr) is_shared() bool {
	return ipv4_public_network.contains(a)
}

// is_private returns true if the address is not globally reachable.
pub fn (a Ipv4Addr) is_private() bool {
	return ipv4_private_networks.any(it.contains(a) == true)
		&& ipv4_private_networks_exceptions.all(it.contains(a) == false)
}

// is_global return true if the address is globally reachable.
pub fn (a Ipv4Addr) is_global() bool {
	return !a.is_private() && !ipv4_public_network.contains(a)
}

// is_reserved returns true if the address is IETF reserved.
pub fn (a Ipv4Addr) is_reserved() bool {
	return ipv4_reserved_network.contains(a)
}

// is_unspecified returns true if the address is unspecified i.e. equals 0.0.0.0.
pub fn (a Ipv4Addr) is_unspecified() bool {
	return a.addr == [4]u8{}
}

// is_netmask returns true if IP address is network mask.
pub fn (a Ipv4Addr) is_netmask() bool {
	intval := (a.u32() ^ max_u32) + 1
	return intval & (intval - 1) == 0
}

// is_hostmask returns true if IP address is host mask.
pub fn (a Ipv4Addr) is_hostmask() bool {
	return (a.u32() + 1) & a.u32() == 0
}

// < returns true if a is lesser than b.
pub fn (a Ipv4Addr) < (b Ipv4Addr) bool {
	return a.u32() < b.u32()
}

// == returns true if a equals b.
pub fn (a Ipv4Addr) == (b Ipv4Addr) bool {
	return a.addr == b.addr
}

@[params]
pub struct Ipv4ToIpv6Params {
pub:
	kind Ipv6WithEmbeddedIpv4 = .mapped
}

// See RFC 4291 Section 2.5.5.
pub enum Ipv6WithEmbeddedIpv4 {
	mapped // e.g. ::ffff:203.0.113.90
	compat // e.g. ::203.0.113.90, deprecated per RFC 4291 Section 4
}

pub struct Ipv4Net {
pub:
	network_address   Ipv4Addr
	network_mask      Ipv4Addr
	host_mask         Ipv4Addr
	broadcast_address Ipv4Addr
	host_address      ?Ipv4Addr
	prefix_len        int
mut:
	current u32
}

// Ipv4Net.new creates new Ipv4Net from network *addr* with given *prefix* length.
pub fn Ipv4Net.new(addr Ipv4Addr, prefix int) !Ipv4Net {
	if prefix < 0 || prefix > 32 {
		return error('prefix length must be in range 0-32, not ${prefix}')
	}
	net_mask := max_u32 ^ (max_u32 >> prefix)
	mut net_addr := addr
	mut host_addr := ?Ipv4Addr(none)
	if (net_addr.u32() & net_mask) != net_addr.u32() {
		host_addr = Ipv4Addr{net_addr.u8_array_fixed()}
		net_addr = Ipv4Addr.from_u32(net_addr.u32() & net_mask)
	}
	host_mask := net_mask ^ max_u32
	broadcast := net_addr.u32() | host_mask
	return Ipv4Net{
		network_address:   net_addr
		network_mask:      Ipv4Addr.from_u32(net_mask)
		host_mask:         Ipv4Addr.from_u32(host_mask)
		broadcast_address: Ipv4Addr.from_u32(broadcast)
		host_address:      host_addr
		prefix_len:        prefix
		current:           net_addr.u32()
	}
}

// Ipv4Net.from_string parses cidr and creates new Ipv4Net.
// Allowed formats are:
//
// * single IP address without prefix length, 32 is applied;
// * network address with non-negative integer prefix length e.g. 172.16.16.0/24;
// * network address with host mask: 172.16.16.0/0.0.0.255;
// * network address with network mask: 172.16.16.0/255.255.255.0.
//
// If prefix length is greather than 32 and host bits is set in the network address
// the optional `host_address` field will be filled with this host address.
// The `network_address` field always will contain the real network address.
pub fn Ipv4Net.from_string(cidr string) !Ipv4Net {
	if cidr.is_blank() {
		return error('network address cannot be blank')
	}
	mut net_addr_str, mut prefix_str := '', ''
	cidr_parts := cidr.split_nth('/', 2)
	if cidr_parts.len == 1 {
		net_addr_str, prefix_str = cidr_parts[0], '32'
	} else {
		net_addr_str, prefix_str = cidr_parts[0], cidr_parts[1]
	}
	mut net_addr := Ipv4Addr.from_string(net_addr_str) or {
		return error('invalid IPv4 address in ${cidr}')
	}
	mut prefix_len := 0
	mut host_mask := Ipv4Addr{}
	mut net_mask := Ipv4Addr.from_u32(max_u32)
	mut host_addr := ?Ipv4Addr(none)
	if prefix_u64 := prefix_str.parse_uint(10, 32) {
		prefix_len = int(prefix_u64)
		if prefix_len < 32 {
			net_mask = Ipv4Addr.from_u32(max_u32 ^ (max_u32 >> u32(prefix_len)))
		}
		host_mask = Ipv4Addr.from_u32(net_mask.u32() ^ max_u32)
	} else {
		mut mask := Ipv4Addr.from_string(prefix_str) or {
			return error('invalid prefix length in ${cidr}')
		}
		if mask.is_netmask() || mask.addr == [4]u8{} || mask.addr == [4]u8{init: 255} {
			net_mask = mask
			host_mask = Ipv4Addr.from_u32(mask.u32() ^ max_u32)
			prefix_len = 32 - host_mask.bit_len()
		} else if mask.is_hostmask() {
			host_mask = mask
			prefix_len = 32 - mask.bit_len()
			if prefix_len < 32 {
				net_mask = Ipv4Addr.from_u32(max_u32 ^ (max_u32 >> u32(prefix_len)))
			}
		} else {
			return error('${mask} is not valid host or network mask in ${cidr}')
		}
	}
	if (net_addr.u32() & net_mask.u32()) != net_addr.u32() {
		host_addr = Ipv4Addr{net_addr.u8_array_fixed()}
		net_addr = Ipv4Addr.from_u32(net_addr.u32() & net_mask.u32())
	}
	broadcast := Ipv4Addr.from_u32(net_addr.u32() | host_mask.u32())
	return Ipv4Net{
		network_address:   net_addr
		network_mask:      net_mask
		host_mask:         host_mask
		broadcast_address: broadcast
		host_address:      host_addr
		prefix_len:        prefix_len
		current:           net_addr.u32()
	}
}

// Ipv4Net.from_u32 creates new Ipv4Net from network *addr* with given *prefix* length.
pub fn Ipv4Net.from_u32(addr u32, prefix int) !Ipv4Net {
	if prefix < 0 || prefix > 32 {
		return error('prefix length must be in range 0-32, not ${prefix}')
	}
	mut host_addr := ?Ipv4Addr(none)
	mut net_addr := addr
	net_mask := max_u32 ^ (max_u32 >> prefix)
	if (net_addr & net_mask) != net_addr {
		mut net_addr_bytes := [4]u8{}
		binary.big_endian_put_u32_fixed(mut net_addr_bytes, net_addr)
		host_addr = Ipv4Addr{net_addr_bytes}
		net_addr &= net_mask
	}
	host_mask := net_mask ^ max_u32
	broadcast := net_addr | host_mask
	return Ipv4Net{
		network_address:   Ipv4Addr.from_u32(net_addr)
		network_mask:      Ipv4Addr.from_u32(net_mask)
		host_mask:         Ipv4Addr.from_u32(host_mask)
		broadcast_address: Ipv4Addr.from_u32(broadcast)
		host_address:      host_addr
		prefix_len:        prefix
		current:           net_addr
	}
}

// str returns string representation of IPv4 network in CIDR format.
pub fn (n Ipv4Net) str() string {
	return n.format(.with_prefix_len)
}

// format returns the IPv4 network as a string formatted according to the fmt rule.
pub fn (n Ipv4Net) format(fmt Ipv4NetFormat) string {
	match fmt {
		.with_prefix_len {
			return n.network_address.str() + '/' + n.prefix_len.str()
		}
		.with_host_mask {
			return n.network_address.str() + '/' + n.host_mask.str()
		}
		.with_network_mask {
			return n.network_address.str() + '/' + n.network_mask.str()
		}
	}
}

// capacity returns a total number of addresses in the network.
pub fn (n Ipv4Net) capacity() u64 {
	return u64(n.broadcast_address.u32() - n.network_address.u32()) + 1
}

// next implements an iterator that iterates over all addresses in network
// including network and broadcast addresses.
// Example:
// ```
// network := netaddr.Ipv4Net.from_string('10.0.10.2/29')!
// for addr in network {
//     println(addr)
// }
// ```
pub fn (mut n Ipv4Net) next() ?Ipv4Addr {
	if n.current >= n.broadcast_address.u32() + 1 {
		return none
	}
	defer {
		n.current++
	}
	return Ipv4Addr.from_u32(n.current)
}

// first returns the first usable host address in network.
pub fn (n Ipv4Net) first() Ipv4Addr {
	if n.prefix_len in [31, 32] {
		return n.network_address
	}
	return Ipv4Addr.from_u32(n.network_address.u32() + 1)
}

// last returns the last usable host address in network.
pub fn (n Ipv4Net) last() Ipv4Addr {
	if n.prefix_len in [31, 32] {
		return n.broadcast_address
	}
	return Ipv4Addr.from_u32(n.broadcast_address.u32() - 1)
}

// nth returns the Nth address in network. Supports negative indexes.
pub fn (n Ipv4Net) nth(num i64) !Ipv4Addr {
	mut addr := Ipv4Addr{}
	if num >= 0 {
		addr = Ipv4Addr.from_u32(n.network_address.u32() + u32(num))
	} else {
		addr = Ipv4Addr.from_u32(n.broadcast_address.u32() + u32(num + 1))
	}
	if n.contains(addr) {
		return addr
	}
	return error('unable to get ${num}th address')
}

// contains returns true if IP address is in the network.
pub fn (n Ipv4Net) contains(addr Ipv4Addr) bool {
	return n.network_address.u32() <= addr.u32() && addr.u32() <= n.broadcast_address.u32()
}

// overlaps returns true if network partly contains in *other*,
// in other words if the networks addresses sets intersect.
pub fn (n Ipv4Net) overlaps(other Ipv4Net) bool {
	return other.contains(n.network_address) || (other.contains(n.broadcast_address)
		|| (n.contains(other.network_address) || (n.contains(other.broadcast_address))))
}

// subnets returns iterator that iterates over the network subnets partitioned by given *prefix* length.
// Example:
// ```
// network := netaddr.Ipv4Net.from_string('198.51.100.0/24')!
// subnets := network.subnets(26)!
// for subnet in subnets {
// 	println(subnet)
// }
// ```
pub fn (n Ipv4Net) subnets(prefix int) !Ipv4NetsIterator {
	if prefix > 32 || prefix < n.prefix_len {
		return error('prefix length must be in range ${n.prefix_len}-32, not ${prefix}')
	}
	return Ipv4NetsIterator{
		prefix_len: prefix
		step:       (n.host_mask.u32() + 1) >> (prefix - n.prefix_len)
		end:        n.broadcast_address.u32()
		current:    n.network_address.u32()
	}
}

// supernet returns IPv4 network containing the current network.
pub fn (n Ipv4Net) supernet(prefix int) !Ipv4Net {
	if prefix < 0 || prefix > n.prefix_len {
		return error('prefix length must be in range 0-${n.prefix_len}, not ${prefix}')
	}
	if prefix == 0 {
		return n
	}
	net_addr := n.network_address.u32() & (n.network_mask.u32() << (n.prefix_len - prefix))
	return Ipv4Net.from_u32(net_addr, prefix)!
}

// is_subnet_of returns true if *other* contains the network.
pub fn (n Ipv4Net) is_subnet_of(other Ipv4Net) bool {
	return other.network_address.u32() <= n.network_address.u32()
		&& other.broadcast_address.u32() >= n.broadcast_address.u32()
}

// is_supernet_of returns true if the network contains *other*.
pub fn (n Ipv4Net) is_supernet_of(other Ipv4Net) bool {
	return n.network_address.u32() <= other.network_address.u32()
		&& n.broadcast_address.u32() >= other.broadcast_address.u32()
}

// is_link_local returns true if the network is link-local.
pub fn (n Ipv4Net) is_link_local() bool {
	return n.network_address.is_link_local() && n.broadcast_address.is_link_local()
}

// is_loopback returns true if this is a loopback network.
pub fn (n Ipv4Net) is_loopback() bool {
	return n.network_address.is_loopback() && n.broadcast_address.is_loopback()
}

// is_multicast returns true if the network is reserved for multicast use.
pub fn (n Ipv4Net) is_multicast() bool {
	return n.network_address.is_multicast() && n.broadcast_address.is_multicast()
}

// is_unicast returns true if the network is unicast.
pub fn (n Ipv4Net) is_unicast() bool {
	return !n.is_multicast()
}

// is_shared returns true if the network is in shared address space.
pub fn (n Ipv4Net) is_shared() bool {
	return n.network_address.is_shared() && n.broadcast_address.is_shared()
}

// is_private returns true if the network is not globally reachable.
pub fn (n Ipv4Net) is_private() bool {
	return n.network_address.is_private() && n.broadcast_address.is_private()
}

// is_global return true if the network is globally reachable.
pub fn (n Ipv4Net) is_global() bool {
	return !n.is_private()
}

// is_reserved returns true if the network is IETF reserved.
pub fn (n Ipv4Net) is_reserved() bool {
	return n.network_address.is_reserved() && n.broadcast_address.is_reserved()
}

// is_unspecified returns true if the network is 0.0.0.0/32.
pub fn (n Ipv4Net) is_unspecified() bool {
	return n.network_address.is_unspecified() && n.broadcast_address.is_unspecified()
}

// < returns true if the network is lesser than other network.
pub fn (n Ipv4Net) < (other Ipv4Net) bool {
	if n.network_address != other.network_address {
		return n.network_address.u32() < other.network_address.u32()
	}
	if n.network_mask != other.network_mask {
		return n.network_mask.u32() < other.network_mask.u32()
	}
	return false
}

// == returns true if networks equals.
pub fn (n Ipv4Net) == (other Ipv4Net) bool {
	return n.network_address == other.network_address && n.network_mask == n.network_mask
}

pub enum Ipv4NetFormat {
	with_prefix_len   // e.g. 198.51.100.0/24
	with_host_mask    // e.g. 198.51.100.0/0.0.0.255
	with_network_mask // e.g. 198.51.100.0/255.255.255.0
}

pub struct Ipv4NetsIterator {
	prefix_len int
	step       u32
	end        u32
mut:
	current u32
}

// next implements the iterator interface for IP network subnets.
pub fn (mut iter Ipv4NetsIterator) next() ?Ipv4Net {
	if iter.current >= iter.end + 1 {
		return none
	}
	defer {
		iter.current += iter.step
	}
	return Ipv4Net.from_u32(iter.current, iter.prefix_len)!
}
