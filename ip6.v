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
import math.big
import net

const max_u128 = big.integer_from_bytes([]u8{len: 16, init: 0xff})

pub struct Ipv6Addr {
	addr [16]u8
pub:
	zone_id ?string // the IPv6 scope zone identifier per RFC 4007
}

// Ipv6Addr.new creates new Ipv6Addr instance from eight 16-bit segments with optional
// scope zone_id.
// Example:
// ```
// import netaddr
//
// ip := netaddr.Ipv6Addr.new(0x2001, 0x0db8, 0x0008, 0x0004, 0x0000, 0x0000, 0x0000, 0x0002)!
// println(ip) // 2001:db8:8:4::2
// ```
pub fn Ipv6Addr.new(a u16, b u16, c u16, d u16, e u16, f u16, g u16, h u16, params Ipv6AddrParams) !Ipv6Addr {
	params.validate()!
	mut addr := [16]u8{}
	mut one := [2]u8{}
	mut nr := 0
	for segment in [a, b, c, d, e, f, g, h] {
		binary.big_endian_put_u16_fixed(mut one, segment)
		addr[nr] = one[0]
		addr[nr + 1] = one[1]
		nr += 2
	}
	return Ipv6Addr{
		addr:    addr
		zone_id: params.zone_id
	}
}

// Ipv6Addr.from_segments creates new Ipv6Addr instance from eight 16-bit segments
// with optional scope zone_id.
pub fn Ipv6Addr.from_segments(seg [8]u16, params Ipv6AddrParams) !Ipv6Addr {
	return Ipv6Addr.new(seg[0], seg[1], seg[2], seg[3], seg[4], seg[5], seg[6], seg[7],
		params)!
}

// Ipv6Addr.from_octets creates new Ipv6Addr instance from 16 octets
// with optional scope zone_id.
pub fn Ipv6Addr.from_octets(addr [16]u8, params Ipv6AddrParams) !Ipv6Addr {
	params.validate()!
	return Ipv6Addr{
		addr:    addr
		zone_id: params.zone_id
	}
}

// Ipv6Addr.from_string parses addr and returns new Ipv6Addr instance.
// The allowed formats are:
//
// * full length hexadecimal colon-separated address e.g. aaaa:bbbb:cccc:dddd:eeee:ffff:0000:1111;
// * address with omitted leading zeros in hextets;
// * address with omitted all-zeros hextets e.g. ::1;
// * combined form with omitted all-zeros and leading zeros;
// * mixed with dotted-decimal format e.g. ::ffff:192.168.3.12;
// * address with scope zone identifier e.g. fe80::d08e:6658%eth0;
// * address in square brackets: [a:b:c:d:e:f:0:1].
pub fn Ipv6Addr.from_string(addr string) !Ipv6Addr {
	if addr.is_blank() {
		return error('IP address cannot be blank')
	}
	if addr.contains('/') {
		return error("unexpected '/' in ${addr}")
	}
	addr_clean, zone_id := split_scope(addr.trim('[]')) or { return err }
	if addr_clean.count('::') > 1 {
		return error('too many :: in ${addr}')
	}
	if addr_clean[0] == u8(`:`) && !addr_clean.starts_with('::') {
		return error('leading : is allowed only as :: part in ${addr}')
	}
	if addr_clean[addr_clean.len - 1] == u8(`:`) && !addr_clean.ends_with('::') {
		return error('trailing : is allowed only as :: part in ${addr}')
	}
	mut hextets := addr_clean.split(':')
	if hextets.len < 3 {
		return error('at least 3 parts expected in ${addr}')
	}
	for i, hextet in hextets {
		if hextet.contains('.') && i == hextets.len - 1 {
			ip4 := Ipv4Addr.from_string(hextet) or {
				return error('invalid IPv6-embedded IPv4 address in ${addr}')
			}
			ip4_u8 := ip4.u8_array_fixed()
			hextets.delete(i)
			hextets << ip4_u8[0].hex() + ip4_u8[1].hex()
			hextets << ip4_u8[2].hex() + ip4_u8[3].hex()
		}
	}
	len_diff := 8 - hextets.len
	if len_diff < 8 && len_diff > 0 {
		for i := 0; i < len_diff + 1; i++ {
			// insert missing hextets with zero values
			hextets.insert(hextets.index(''), '0')
		}
		hextets.delete(hextets.index('')) // delete extra empty item
	} else if len_diff < 0 {
		// too many hextets (more than 8) in address
		return error('unable to parse IPv6 address from string ${addr}')
	}
	// replace empty strings with zeros
	for i := 0; i < hextets.len; i++ {
		if hextets[i] == '' {
			hextets[i] = '0'
		}
	}
	mut address := [16]u8{}
	mut i := 0
	for hextet in hextets {
		in_hex := '0x' + hextet
		if !in_hex.is_hex() {
			return error('non-hexadecimal value ${hextet} in ${addr}')
		}
		mut pair := in_hex.u8_array()
		if pair.len == 1 {
			// add leading zero to fit into len=2
			pair << u8(0)
			pair[0], pair[1] = pair[1], pair[0]
		}
		address[i] = pair[0]
		address[i + 1] = pair[1]
		i += 2
	}
	return Ipv6Addr{address, zone_id}
}

// Ipv6Addr.from_bigint creates new Ipv6Addr from big.Integer with optional scope
// zone_id. The integer sign will be discarded. `addr` must fit in 128 bit.
pub fn Ipv6Addr.from_bigint(addr big.Integer, params Ipv6AddrParams) !Ipv6Addr {
	params.validate()!
	if addr.bit_len() > 128 {
		return error('${addr} overflows 128 bit')
	}
	mut address := [16]u8{}
	bytes, _ := addr.bytes()
	len_diff := 16 - bytes.len
	if len_diff == 0 {
		for i in 0 .. 16 {
			address[i] = bytes[i]
		}
	} else {
		mut i := 0
		for pos in len_diff .. 16 {
			address[pos] = bytes[i]
			i++
		}
	}
	return Ipv6Addr{
		addr:    address
		zone_id: params.zone_id
	}
}

// str returns string representation of IPv6 address in compact format.
pub fn (a Ipv6Addr) str() string {
	return a.format(.compact | .dotted)
}

// format returns the IPv6 address as a string formatted according to the fmt rule.
pub fn (a Ipv6Addr) format(fmt Ipv6AddrFormat) string {
	mut str := []string{}
	match true {
		fmt & .compact == .compact {
			if fmt & .dotted == .dotted {
				if a.is_ipv4_mapped() {
					return '::ffff:' +
						Ipv4Addr{[a.addr[12], a.addr[13], a.addr[14], a.addr[15]]!}.str()
				}
				if a.is_ipv4_compat() {
					return '::' + Ipv4Addr{[a.addr[12], a.addr[13], a.addr[14], a.addr[15]]!}.str()
				}
			}
			for i := 0; i <= 14; i += 2 {
				mut hextet := a.addr[i..i + 2].hex().trim_left('0')
				if hextet == '' {
					hextet = '0'
				}
				str << hextet
			}
			// Find largest sequence of zeros and replace it with empty string
			mut zeros_seq_begin := -1
			mut zeros_seq_len := 0
			mut max_zeros_seq_begin := -1
			mut max_zeros_seq_len := 0
			for i, hx in str {
				if hx == '0' {
					zeros_seq_len++
					if zeros_seq_begin == -1 {
						zeros_seq_begin = i
					}
					if zeros_seq_len > max_zeros_seq_len {
						max_zeros_seq_len = zeros_seq_len
						max_zeros_seq_begin = zeros_seq_begin
					}
				} else {
					zeros_seq_len = 0
					zeros_seq_begin = -1
				}
			}
			if max_zeros_seq_len > 1 {
				if str.len == max_zeros_seq_begin + max_zeros_seq_len {
					str << ''
				}
				str.delete_many(max_zeros_seq_begin, max_zeros_seq_len)
				if max_zeros_seq_begin == 0 {
					str.insert(0, '')
				}
				str.insert(max_zeros_seq_begin, '')
			}
			if a.zone_id == none {
				return str.join(':')
			}
			return str.join(':') + '%' + (a.zone_id as string)
		}
		fmt & .verbose == .verbose {
			if fmt & .dotted == .dotted {
				if a.is_ipv4_mapped() {
					return '0000:0000:0000:0000:0000:ffff:' +
						Ipv4Addr{[a.addr[12], a.addr[13], a.addr[14], a.addr[15]]!}.str()
				}
				if a.is_ipv4_compat() {
					return '0000:0000:0000:0000:0000:0000:' +
						Ipv4Addr{[a.addr[12], a.addr[13], a.addr[14], a.addr[15]]!}.str()
				}
			}
			for i := 0; i <= 14; i += 2 {
				str << a.addr[i..i + 2].hex()
			}
			if a.zone_id == none {
				return str.join(':')
			}
			return str.join(':') + '%' + (a.zone_id as string)
		}
		else {
			return a.str()
		}
	}
}

// bigint returns IP address represented as big.Integer.
pub fn (a Ipv6Addr) bigint() big.Integer {
	if a.addr == [16]u8{} {
		return big.zero_int
	}
	return big.integer_from_bytes(a.addr[..])
}

// u8_array returns IP address represented as byte array.
pub fn (a Ipv6Addr) u8_array() []u8 {
	return a.addr[..]
}

// u8_array_fixed returns IP address represented as fixed size byte array.
pub fn (a Ipv6Addr) u8_array_fixed() [16]u8 {
	return a.addr
}

// segments returns an array of eight 16-bit IP address segments.
pub fn (a Ipv6Addr) segments() [8]u16 {
	mut segments := [8]u16{}
	mut nr := 0
	for i in 0 .. 8 {
		segments[i] = binary.big_endian_u16_fixed([a.addr[nr], a.addr[nr + 1]]!)
		nr += 2
	}
	return segments
}

// with_scope returns IPv6 address with new zone_id.
// Note: with_scope creates new Ipv6Addr, does not change the current.
pub fn (a Ipv6Addr) with_scope(zone_id string) !Ipv6Addr {
	if zone_id.is_blank() || zone_id.contains('%') {
		return error('zone_id cannot be blank or contain % sign')
	}
	return Ipv6Addr{a.addr, zone_id}
}

// ipv4 returns IPv4 address converted from IPv4-mapped or IPv4-compatible IPv6 address.
// Note: this function does not treat :: and ::1 addresses as IPv4-compatible ones.
pub fn (a Ipv6Addr) ipv4() !Ipv4Addr {
	if a.is_ipv4_mapped() || a.is_ipv4_compat() {
		return Ipv4Addr{[a.addr[12], a.addr[13], a.addr[14], a.addr[15]]!}
	}
	return error('${a} is not IPv4-mapped or IPv4-compatible address')
}

// six_to_four returns embedded IPv4 address if the IPv6 address is 6to4. See RFC 3056.
pub fn (a Ipv6Addr) six_to_four() !Ipv4Addr {
	if a.addr[..2] != [u8(0x20), 2] {
		return error('${a} is not a 6to4 address')
	}
	return Ipv4Addr{[a.addr[2], a.addr[3], a.addr[4], a.addr[5]]!}
}

// teredo returns embedded Teredo address.
// See RFC 4380 and https://en.wikipedia.org/wiki/Teredo_tunneling
pub fn (a Ipv6Addr) teredo() !TeredoAddr {
	if a.addr[..4] != [u8(0x20), 1, 0, 0] {
		return error('${a} is not a Teredo address')
	}
	return TeredoAddr{
		server: Ipv4Addr{[a.addr[4], a.addr[5], a.addr[6], a.addr[7]]!}
		flags:  binary.big_endian_u16(a.addr[8..10])
		port:   binary.big_endian_u16([~a.addr[10], ~a.addr[11]])
		client: Ipv4Addr{[~a.addr[12], ~a.addr[13], ~a.addr[14], ~a.addr[15]]!}
	}
}

// bit_len returns number of bits required to represent IP address.
pub fn (a Ipv6Addr) bit_len() int {
	return bit_len_128(a.addr)
}

// family returns the `net.AddrFamily` member corresponding to IP version.
pub fn (a Ipv6Addr) family() net.AddrFamily {
	return .ip6
}

// reverse_pointer returns a reverse DNS pointer name for IPv6 address.
pub fn (a Ipv6Addr) reverse_pointer() string {
	return a.addr[..].hex().split('').reverse().join('.') + '.ip6.arpa'
}

// is_ipv4_mapped returns true if IPv6 address is IPv4-mapped.
pub fn (a Ipv6Addr) is_ipv4_mapped() bool {
	return a.addr[..10].all(it == u8(0)) && a.addr[10] == 255 && a.addr[11] == 255
}

// is_ipv4_compat returns true if IPv6 address is IPv4-compatible.
// Note: loopback and unspecified addresses (::1 and :: respectively) are not
// recognized as IPv4-compatible addresses.
pub fn (a Ipv6Addr) is_ipv4_compat() bool {
	return a.addr[..12].all(it == u8(0)) && a.addr[12..16] !in [[u8(0), 0, 0, 0], [u8(0), 0, 0, 1]]
}

// is_site_local returns true if the address is reserved for site local usage.
// See RFC 3879.
pub fn (a Ipv6Addr) is_site_local() bool {
	return ipv6_site_local_network.contains(a)
}

// is_unique_local returns true if the address is unique local. See RFC 4193, RFC 8190.
pub fn (a Ipv6Addr) is_unique_local() bool {
	return ipv6_unique_local_network.contains(a)
}

// is_link_local returns true if the address is allocated in link-local network.
pub fn (a Ipv6Addr) is_link_local() bool {
	ip := a.ipv4() or { return ipv6_link_local_network.contains(a) }
	return ip.is_link_local()
}

// is_loopback returns true if the address is loopback i.e equals ::1.
pub fn (a Ipv6Addr) is_loopback() bool {
	ip := a.ipv4() or { return a.addr == [u8(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]! }
	return ip.is_loopback()
}

// is_multicast returns true if the address is reserved for multicast use.
pub fn (a Ipv6Addr) is_multicast() bool {
	ip := a.ipv4() or { return ipv6_multicast_network.contains(a) }
	return ip.is_multicast()
}

// is_unicast returns true if the address is unicast.
pub fn (a Ipv6Addr) is_unicast() bool {
	return !a.is_multicast()
}

// is_private returns true if the address is not globally reachable.
pub fn (a Ipv6Addr) is_private() bool {
	ip := a.ipv4() or {
		return ipv6_private_networks.any(it.contains(a) == true)
			&& ipv6_private_networks_exceptions.all(it.contains(a) == false)
	}
	return ip.is_private()
}

// is_global return true if the address is globally reachable.
pub fn (a Ipv6Addr) is_global() bool {
	return !a.is_private()
}

// is_reserved returns true if the address is allocated in reserved networks.
pub fn (a Ipv6Addr) is_reserved() bool {
	ip := a.ipv4() or { return ipv6_reserved_networks.any(it.contains(a) == true) }
	return ip.is_reserved()
}

// is_unspecified returns true if IP address is unspecified i.e equals ::.
pub fn (a Ipv6Addr) is_unspecified() bool {
	ip := a.ipv4() or { return a.addr == [16]u8{} }
	return ip.is_unspecified()
}

// is_netmask returns true if IP address is network mask.
pub fn (a Ipv6Addr) is_netmask() bool {
	val := a.bigint().bitwise_xor(max_u128) + big.one_int
	return val.bitwise_and(val - big.one_int) == big.zero_int
}

// is_hostmask returns true if IP address is host mask.
pub fn (a Ipv6Addr) is_hostmask() bool {
	addr_num := a.bigint()
	return (addr_num + big.one_int).bitwise_and(addr_num) == big.zero_int
}

// < returns true if a is lesser than b.
pub fn (a Ipv6Addr) < (b Ipv6Addr) bool {
	return compare_128(a.addr, b.addr) == -1
}

// == returns true if a equals b.
pub fn (a Ipv6Addr) == (b Ipv6Addr) bool {
	return a.addr == b.addr
}

fn split_scope(addr string) !(string, ?string) {
	address, zone_id := addr.split_once('%') or { '', 'empty' }
	if zone_id == '' || zone_id.contains('%') {
		return error('invalid zone_id in ${addr}')
	}
	if address == '' {
		return addr, ?string(none)
	}
	return address, zone_id
}

@[params]
pub struct Ipv6AddrParams {
pub:
	zone_id ?string
}

fn (p Ipv6AddrParams) validate() ! {
	if p.zone_id != none {
		zone_id := p.zone_id as string
		if zone_id.is_blank() || zone_id.contains('%') {
			return error('zone_id cannot be blank or contain % sign')
		}
	}
}

@[flag]
pub enum Ipv6AddrFormat {
	compact // e.g. fe80::896:7aff:e87:4ae3
	verbose // e.g. fe80:0000:0000:0000:0896:7aff:0e87:4ae3
	dotted  // use dotted-decimal notation for IPv4-mapped and IPv4-compat addresses e.g. ::ffff:192.168.3.11
}

// TeredoAddr represents the parsed Teredo address. See RFC 4380 Section 4.
pub struct TeredoAddr {
pub:
	server Ipv4Addr
	flags  u16
	port   u16
	client Ipv4Addr
}

// ipv6 returns Ipv6Addr created from Teredo address.
@[direct_array_access]
pub fn (t TeredoAddr) ipv6() Ipv6Addr {
	mut addr := [16]u8{}
	addr[0] = u8(0x20)
	addr[1] = u8(0x01)
	mut flags := [2]u8{}
	binary.big_endian_put_u16_fixed(mut flags, t.flags)
	addr[8] = flags[0]
	addr[9] = flags[1]
	mut port := [2]u8{}
	binary.big_endian_put_u16_fixed(mut port, t.port)
	addr[10] = ~port[0]
	addr[11] = ~port[1]
	for i := 4; i < 8; i++ {
		addr[i] = t.server.addr[i - 4]
		addr[i + 8] = ~t.client.addr[i - 4]
	}
	return Ipv6Addr{
		addr: addr
	}
}

pub struct Ipv6Net {
pub:
	network_address   Ipv6Addr
	network_mask      Ipv6Addr
	host_mask         Ipv6Addr
	broadcast_address Ipv6Addr
	host_address      ?Ipv6Addr
	prefix_len        int
mut:
	current [16]u8
}

// Ipv6Net.new creates new IPv6 network from given Ipv6Addr and prefix.
pub fn Ipv6Net.new(addr Ipv6Addr, prefix int) !Ipv6Net {
	if prefix < 0 || prefix > 128 {
		return error('prefix length must be in range 0-128, not ${prefix}')
	}
	mut net_addr := addr
	mut host_addr := ?Ipv6Addr(none)
	net_mask := Ipv6Addr{
		addr: bitwise_xor_128(max_128, right_shift_128(max_128, prefix))
	}
	if bitwise_and_128(net_addr.addr, net_mask.addr) != net_addr.u8_array_fixed() {
		host_addr = Ipv6Addr{
			addr: net_addr.addr
		}
		net_addr = Ipv6Addr{
			addr: bitwise_and_128(net_addr.addr, net_mask.addr)
		}
	}
	host_mask := Ipv6Addr{
		addr: bitwise_xor_128(net_mask.addr, max_128)
	}
	broadcast := Ipv6Addr{
		addr: bitwise_or_128(net_addr.addr, host_mask.addr)
	}
	return Ipv6Net{
		network_address:   net_addr
		network_mask:      net_mask
		host_mask:         host_mask
		broadcast_address: broadcast
		host_address:      host_addr
		prefix_len:        prefix
		current:           net_addr.u8_array_fixed()
	}
}

// Ipv6Net.from_string parses cidr and creates new Ipv6Net.
// All formats supported by Ipv6Addr.from_string is allowed here.
// See also Ipv4Net.from_string for additional info about parsing strategy and
// supported network/prefix variants.
pub fn Ipv6Net.from_string(cidr string) !Ipv6Net {
	net_addr_str, prefix_str := cidr.split_once('/') or { cidr, '128' }
	mut net_addr := Ipv6Addr.from_string(net_addr_str)!
	mut prefix_len := 0
	mut host_mask := Ipv6Addr{}
	mut net_mask := Ipv6Addr{
		addr: [16]u8{init: 0xff}
	}
	mut host_addr := ?Ipv6Addr(none)
	if prefix_len_u64 := prefix_str.parse_uint(10, 64) {
		prefix_len = int(prefix_len_u64)
		if prefix_len < 128 {
			net_mask = Ipv6Addr{
				addr: bitwise_xor_128(max_128, right_shift_128(max_128, prefix_len))
			}
		}
		host_mask = Ipv6Addr{
			addr: bitwise_xor_128(net_mask.addr, max_128)
		}
	} else {
		mut mask := Ipv6Addr.from_string(prefix_str)!
		match true {
			mask.is_netmask() || mask.addr == [16]u8{} || mask.addr == [16]u8{init: 0xff} {
				net_mask = mask
				host_mask = Ipv6Addr{
					addr: bitwise_xor_128(mask.addr, max_128)
				}
				prefix_len = 128 - host_mask.bit_len()
			}
			mask.is_hostmask() {
				host_mask = mask
				prefix_len = 128 - host_mask.bit_len()
				if prefix_len < 128 {
					net_mask = Ipv6Addr{
						addr: bitwise_xor_128(max_128, right_shift_128(max_128, prefix_len))
					}
				}
			}
			else {
				return error('${mask} is not valid network or host mask in ${cidr}')
			}
		}
	}
	if bitwise_and_128(net_addr.addr, net_mask.addr) != net_addr.u8_array_fixed() {
		host_addr = Ipv6Addr{
			addr: net_addr.u8_array_fixed()
		}
		net_addr = Ipv6Addr{
			addr: bitwise_and_128(net_addr.u8_array_fixed(), net_mask.addr)
		}
	}
	broadcast := Ipv6Addr{
		addr: bitwise_or_128(net_addr.addr, host_mask.addr)
	}
	return Ipv6Net{
		network_address:   net_addr
		network_mask:      net_mask
		host_mask:         host_mask
		broadcast_address: broadcast
		host_address:      host_addr
		prefix_len:        prefix_len
		current:           net_addr.u8_array_fixed()
	}
}

// Ipv6Net.from_bigint creates new IPv6 network from given addr and prefix.
// `addr` must fit in 128 bits.
pub fn Ipv6Net.from_bigint(addr big.Integer, prefix int) !Ipv6Net {
	if prefix < 0 || prefix > 128 {
		return error('prefix length must be in range 0-128, not ${prefix}')
	}
	if addr.bit_len() > 128 {
		return error('${addr} overflows 128 bit')
	}
	mut host_addr := ?Ipv6Addr(none)
	mut net_addr := addr
	net_mask := max_u128.bitwise_xor(max_u128.right_shift(u32(prefix)))
	if net_addr.bitwise_and(net_mask) != net_addr {
		host_addr = Ipv6Addr.from_bigint(net_addr)!
		net_addr = net_addr.bitwise_and(net_mask)
	}
	host_mask := net_mask.bitwise_xor(max_u128)
	broadcast := net_addr.bitwise_or(host_mask)
	net_addr6 := Ipv6Addr.from_bigint(net_addr)!
	return Ipv6Net{
		network_address:   net_addr6
		network_mask:      Ipv6Addr.from_bigint(net_mask)!
		host_mask:         Ipv6Addr.from_bigint(host_mask)!
		broadcast_address: Ipv6Addr.from_bigint(broadcast)!
		host_address:      host_addr
		prefix_len:        prefix
		current:           net_addr6.u8_array_fixed()
	}
}

// str returns string representation of IPv6 network in CIDR format.
pub fn (n Ipv6Net) str() string {
	return n.format(.compact | .dotted | .with_prefix_len)
}

// format returns the IPv6 network as a string formatted according to the fmt rule.
pub fn (n Ipv6Net) format(fmt Ipv6NetFormat) string {
	addr_fmt := Ipv6AddrFormat(fmt)
	match true {
		fmt & .with_prefix_len == .with_prefix_len {
			return n.network_address.format(addr_fmt) + '/' + n.prefix_len.str()
		}
		fmt & .with_network_mask == .with_network_mask {
			return n.network_address.format(addr_fmt) + '/' + n.network_mask.format(addr_fmt)
		}
		fmt & .with_host_mask == .with_host_mask {
			return n.network_address.format(addr_fmt) + '/' + n.host_mask.format(addr_fmt)
		}
		else {
			return n.format(fmt | .with_prefix_len)
		}
	}
}

// capacity returns a total number of addresses in the network.
pub fn (n Ipv6Net) capacity() big.Integer {
	return (n.broadcast_address.bigint() - n.network_address.bigint()) + big.one_int
}

// next implements an iterator that iterates over all addresses in network
// including network and broadcast addresses.
// Example:
// ```
// network := netaddr.Ipv6Net.from_string('fe80::/124')!
// for addr in network {
//     println(addr)
// }
// ```
pub fn (mut n Ipv6Net) next() ?Ipv6Addr {
	// Possible optimization: do not calculate `limit` on each fn call (use LRU cache?)
	limit := add_128(n.broadcast_address.addr, one_128)
	if compare_128(n.current, limit) in [0, 1] {
		return none
	}
	defer {
		n.current = add_128(n.current, one_128)
	}
	return Ipv6Addr.from_octets(n.current)!
}

// first returns the first usable host address in network.
pub fn (n Ipv6Net) first() Ipv6Addr {
	if n.prefix_len in [127, 128] {
		return n.network_address
	}
	return Ipv6Addr.from_octets(add_128(n.network_address.addr, one_128)) or { panic(err) }
}

// last returns the last usable host address in network.
pub fn (n Ipv6Net) last() Ipv6Addr {
	if n.prefix_len in [127, 128] {
		return n.broadcast_address
	}
	return Ipv6Addr.from_octets(sub_128(n.broadcast_address.addr, one_128)) or { panic(err) }
}

// nth returns the Nth address in network. Supports negative indexes.
pub fn (n Ipv6Net) nth(num big.Integer) !Ipv6Addr {
	mut addr := Ipv6Addr{}
	if num >= big.zero_int {
		addr = Ipv6Addr.from_bigint(n.network_address.bigint() + num)!
	} else {
		addr = Ipv6Addr.from_bigint(n.broadcast_address.bigint() + num + big.one_int)!
	}
	if n.contains(addr) {
		return addr
	}
	return error('unable to get ${num}th address')
}

// contains returns true if IP address is in the network.
pub fn (n Ipv6Net) contains(addr Ipv6Addr) bool {
	return n.network_address <= addr && addr <= n.broadcast_address
}

// overlaps returns true if network partly contains in *other*,
// in other words if the networks addresses sets intersect.
pub fn (n Ipv6Net) overlaps(other Ipv6Net) bool {
	return other.contains(n.network_address) || (other.contains(n.broadcast_address)
		|| (n.contains(other.network_address) || (n.contains(other.broadcast_address))))
}

// subnets returns iterator that iterates over the network subnets partitioned by given *prefix* length.
// Example:
// ```
// network := netaddr.Ipv6Net.from_string('2001:db8:beaf::/56')!
// subnets := network.subnets(64)!
// for subnet in subnets {
//  println(subnet)
// }
// ```
pub fn (n Ipv6Net) subnets(prefix int) !Ipv6NetsIterator {
	if prefix > 128 || prefix < n.prefix_len {
		return error('prefix length must be in range ${n.prefix_len}-128, not ${prefix}')
	}
	return Ipv6NetsIterator{
		prefix_len: prefix
		step:       (n.host_mask.bigint() + big.one_int).right_shift(u32(prefix - n.prefix_len))
		end:        n.broadcast_address.bigint()
		current:    n.network_address.bigint()
	}
}

// supernet returns IPv6 network containing the current network.
pub fn (n Ipv6Net) supernet(prefix int) !Ipv6Net {
	if prefix < 0 || prefix > n.prefix_len {
		return error('prefix length must be in range 0-${n.prefix_len}, not ${prefix}')
	}
	if prefix == 0 {
		return n
	}
	net_addr := Ipv6Addr{
		addr: bitwise_and_128(n.network_address.addr, left_shift_128(n.network_mask.addr,
			n.prefix_len - prefix))
	}
	return Ipv6Net.new(net_addr, prefix)!
}

// is_subnet_of returns true if *other* contains the network.
pub fn (n Ipv6Net) is_subnet_of(other Ipv6Net) bool {
	return other.network_address <= n.network_address
		&& other.broadcast_address >= n.broadcast_address
}

// is_supernet_of returns true if the network contains *other*.
pub fn (n Ipv6Net) is_supernet_of(other Ipv6Net) bool {
	return n.network_address <= other.network_address
		&& n.broadcast_address >= other.broadcast_address
}

// is_site_local returns true if the network is site-local.
pub fn (n Ipv6Net) is_site_local() bool {
	return n.network_address.is_site_local() && n.broadcast_address.is_site_local()
}

// is_unique_local returns true if the network is unique-local.
pub fn (n Ipv6Net) is_unique_local() bool {
	return n.network_address.is_unique_local() && n.broadcast_address.is_unique_local()
}

// is_link_local returns true if the network is link-local.
pub fn (n Ipv6Net) is_link_local() bool {
	return n.network_address.is_link_local() && n.broadcast_address.is_link_local()
}

// is_loopback returns true if this is a loopback network.
pub fn (n Ipv6Net) is_loopback() bool {
	return n.network_address.is_loopback() && n.broadcast_address.is_loopback()
}

// is_multicast returns true if the network is reserved for multicast use.
pub fn (n Ipv6Net) is_multicast() bool {
	return n.network_address.is_multicast() && n.broadcast_address.is_multicast()
}

// is_unicast returns true if the network is unicast.
pub fn (n Ipv6Net) is_unicast() bool {
	return !n.is_multicast()
}

// is_private returns true if the network is not globally reachable.
pub fn (n Ipv6Net) is_private() bool {
	return n.network_address.is_private() && n.broadcast_address.is_private()
}

// is_global return true if the network is globally reachable.
pub fn (n Ipv6Net) is_global() bool {
	return !n.is_private()
}

// is_reserved returns true if the network is reserved.
pub fn (n Ipv6Net) is_reserved() bool {
	return n.network_address.is_reserved() && n.broadcast_address.is_reserved()
}

// is_unspecified returns true if the network is ::/0.
pub fn (n Ipv6Net) is_unspecified() bool {
	return n.network_address.is_unspecified() && n.broadcast_address.is_unspecified()
}

// < returns true if the network is lesser than other network.
pub fn (n Ipv6Net) < (other Ipv6Net) bool {
	if n.network_address != other.network_address {
		return n.network_address < other.network_address
	}
	if n.network_mask != other.network_mask {
		return n.network_mask < other.network_mask
	}
	return false
}

// == returns true if networks equals.
pub fn (n Ipv6Net) == (other Ipv6Net) bool {
	return n.network_address == other.network_address && n.network_mask == n.network_mask
}

@[flag]
pub enum Ipv6NetFormat {
	compact
	verbose
	dotted
	with_prefix_len
	with_host_mask
	with_network_mask
}

pub struct Ipv6NetsIterator {
	prefix_len int
	step       big.Integer
	end        big.Integer
mut:
	current big.Integer
}

// next implements the iterator interface for IP network subnets.
pub fn (mut iter Ipv6NetsIterator) next() ?Ipv6Net {
	if iter.current >= iter.end + big.one_int {
		return none
	}
	defer {
		iter.current += iter.step
	}
	return Ipv6Net.from_bigint(iter.current, iter.prefix_len)!
}
