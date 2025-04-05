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

pub struct Eui64 {
	addr [8]u8
}

// Eui64.new creates new EUI-64 from eigth octets.
pub fn Eui64.new(a u8, b u8, c u8, d u8, e u8, f u8, g u8, h u8) Eui64 {
	return Eui64{
		addr: [a, b, c, d, e, f, g, h]!
	}
}

// Eui64.from_octets creates new EUI-64 from eight-element byte array.
pub fn Eui64.from_octets(addr [8]u8) Eui64 {
	return Eui64{addr}
}

// Eui64.from_string parses addr string and returns new EUI-64 instance.
pub fn Eui64.from_string(addr string) !Eui64 {
	mut bytes := [8]u8{}
	match true {
		addr.contains_any('-:') {
			// canonical and colon-separated forms
			mac := addr.split_any('-:')
			if mac.len == 8 {
				for i := 0; i < 8; i++ {
					if !('0x' + mac[i]).is_hex() {
						return error('invalid octet in ${addr}')
					}
					bytes[i] = ('0x' + mac[i]).u8()
				}
			} else {
				return error('8 octets expected in ${addr}')
			}
		}
		addr.contains('.') {
			// period separated hextets
			mac := addr.split('.')
			if mac.len == 4 {
				mut i := 0
				for part in mac {
					if !('0x' + part).is_hex() {
						return error('non-hexadecimal value in ${addr}')
					}
					pair := ('0x' + part).u8_array()
					bytes[i] = pair[0]
					bytes[i + 1] = pair[1]
					i += 2
				}
			} else {
				return error('four hextets expected in ${addr}')
			}
		}
		('0x' + addr).is_hex() {
			// bare hex digit
			mac := ('0x' + addr).u8_array()
			len_diff := 8 - mac.len
			if len_diff == 0 {
				for i := 0; i < 8; i++ {
					bytes[i] = mac[i]
				}
			} else if len_diff > 0 {
				mut i := 0
				for pos in len_diff .. 6 {
					bytes[pos] = mac[i]
					i++
				}
			} else {
				return error('8 octets expected in ${addr}')
			}
		}
		else {
			return error('invalid EUI-64 in ${addr}')
		}
	}
	return Eui64{bytes}
}

// str returns EUI-64 string representation in canonical format.
pub fn (e Eui64) str() string {
	return e.format(.canonical)
}

// format returns the EUI-64 as a string formatted according to the fmt rule.
pub fn (e Eui64) format(fmt Eui64Format) string {
	mut mac := []string{}
	match fmt {
		.canonical {
			for b in e.addr {
				mac << b.hex()
			}
			return mac.join('-')
		}
		.unix {
			for b in e.addr {
				mac << b.hex()
			}
			return mac.join(':')
		}
		.hextets {
			for i := 0; i <= 6; i += 2 {
				mac << e.addr[i..i + 2].hex()
			}
			return mac.join('.')
		}
		.bare {
			return e.addr[..].hex()
		}
	}
}

// u8_array returns EUI-64 as byte array.
pub fn (e Eui64) u8_array() []u8 {
	return e.addr[..]
}

// u8_array_fixed returns EUI-64 as fixed size byte array.
pub fn (e Eui64) u8_array_fixed() [8]u8 {
	return e.addr
}

// bit_len returns number of bits required to represent the current EUI-64.
pub fn (e Eui64) bit_len() int {
	return bits.len_64(binary.big_endian_u64(e.addr[..]))
}

// oui_bytes returns the 24 bit Organizationally Unique Identifier (OUI) as byte array.
pub fn (e Eui64) oui_bytes() [3]u8 {
	return [e.addr[0], e.addr[1], e.addr[2]]!
}

// ei_bytes returns the 40 bit Extended Identifier (EI) as byte array.
pub fn (e Eui64) ei_bytes() [5]u8 {
	return [e.addr[3], e.addr[4], e.addr[5], e.addr[6], e.addr[7]]!
}

// modified_eui64 returns the Modified EUI-64 Format Interface Identifier per RFC 4291 (Appendix A).
pub fn (e Eui64) modified_eui64() Eui64 {
	mut addr := [8]u8{}
	for i in 0 .. 8 {
		addr[i] = e.addr[i]
	}
	addr[0] ^= 0x02
	return Eui64{addr}
}

// ipv6 creates new IPv6 address from Modified EUI-64.
// Byte-reversed `prefix` must fit in 64 bit.
// Example:
// ```
// pref := netaddr.Ipv6Net.from_string('2001:0db8:ef01:2345::/64')!
// eui := netaddr.Eui64.from_string('aa-bb-cc-dd-ee-ff-00-11')!
// ip6 := eui.ipv6(pref.network_address)!
// println(ip6) // 2001:0db8:ef01:2345:a8bb:ccdd:eeff:11
// ```
pub fn (e Eui64) ipv6(prefix Ipv6Addr) !Ipv6Addr {
	pref := prefix.u8_array_fixed()
	eui64 := e.modified_eui64().u8_array_fixed()
	if pref[8..] == []u8{len: 8} {
		return Ipv6Addr.from_octets([
			pref[0],
			pref[1],
			pref[2],
			pref[3],
			pref[4],
			pref[5],
			pref[6],
			pref[7],
			eui64[0],
			eui64[1],
			eui64[2],
			eui64[3],
			eui64[4],
			eui64[5],
			eui64[6],
			eui64[7],
		]!)!
	}
	return error('The prefix ${prefix} is too long. ' +
		'At least 64 bits must remain for the interface identifier.')
}

// ipv6_link_local returns link-local IPv6 address created from Modified EUI-64.
pub fn (e Eui64) ipv6_link_local() Ipv6Addr {
	return e.ipv6(Ipv6Addr.new(0xfe80, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000) or { Ipv6Addr{} }) or { Ipv6Addr{} }
}

// is_universal returns true if address is universally administreted.
pub fn (e Eui64) is_universal() bool {
	// U/L bit is 0
	return (e.addr[0] >> 1) & 1 == 0
}

// is_local returns true if address is locally administreted.
pub fn (e Eui64) is_local() bool {
	return !e.is_universal()
}

// is_multicast returns true if address is multicast.
pub fn (e Eui64) is_multicast() bool {
	return !e.is_unicast()
}

// is_unicast returns true if address is unicast.
pub fn (e Eui64) is_unicast() bool {
	// I/G bit is 0
	return e.addr[0] & 1 == 0
}

// == returns true if a is equals b.
pub fn (a Eui64) == (b Eui64) bool {
	return a.addr == b.addr
}

pub enum Eui64Format {
	canonical // e.g. 0a-96-7a-ff-fe-87-4a-e3
	unix      // e.g. 0a:96:7a:ff:fe:87:4a:e3
	hextets   // e.g. 0a96.7aff.ffe87.4ae3
	bare      // e.g. 0a967afffe874ae3
}
