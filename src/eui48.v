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
import rand
import rand.wyrand

pub struct Eui48 {
	addr [6]u8
}

// Eui48.new creates new EUI-48 from six octets.
pub fn Eui48.new(a u8, b u8, c u8, d u8, e u8, f u8) Eui48 {
	return Eui48{
		addr: [a, b, c, d, e, f]!
	}
}

// Eui48.from_octets creates new EUI-48 from six-element byte array.
pub fn Eui48.from_octets(addr [6]u8) Eui48 {
	return Eui48{addr}
}

// Eui48.from_string parses addr string and returns new EUI-48 instance.
// Example:
// ```
// assert Eui48.from_string('a96:7a87:4ae3')!.str() == '0a-96-7a-87-4a-e3'
// ```
pub fn Eui48.from_string(addr string) !Eui48 {
	mut bytes := [6]u8{}
	match true {
		addr.contains_any('-:') {
			// canonical and unix formats
			mac := addr.split_any('-:')
			if mac.len == 6 {
				for i := 0; i < 6; i++ {
					if !('0x' + mac[i]).is_hex() {
						return error('invalid octet in ${addr}')
					}
					bytes[i] = ('0x' + mac[i]).u8()
				}
			} else {
				return error('6 octets expected in ${addr}')
			}
		}
		addr.contains('.') {
			// cisco triple-hextet format
			mac := addr.split('.')
			if mac.len == 3 {
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
				return error('3 hextets expected in ${addr}')
			}
		}
		('0x' + addr).is_hex() {
			// bare hex digit
			mac := ('0x' + addr).u8_array()
			len_diff := 6 - mac.len
			if len_diff == 0 {
				for i := 0; i < 6; i++ {
					bytes[i] = mac[i]
				}
			} else if len_diff > 0 {
				mut i := 0
				for pos in len_diff .. 6 {
					bytes[pos] = mac[i]
					i++
				}
			} else {
				return error('6 octets expected in ${addr}')
			}
		}
		else {
			return error('invalid EUI-48 in ${addr}')
		}
	}
	return Eui48{bytes}
}

// Eui48.random is guaranteed to return a locally administered unicast EUI-48.
// By default the WyRandRNG is used with default seed. You can set custom OUI
// if you don't want generate random one.
// Example:
// ```v ignore
// >>> netaddr.Eui48.random()
// be-8c-f7-90-b4-60
// >>> netaddr.Eui48.random(oui: [u8(0x02), 0x0, 0x0]!)
// 02-00-00-2d-1d-01
// ```
pub fn Eui48.random(params Eui48RandomParams) Eui48 {
	mut eui := [6]u8{}
	mut prng := params.prng
	if params.seed.len > 0 {
		prng.seed(params.seed)
	}
	if params.oui != none {
		eui[0], eui[1], eui[2] = params.oui[0], params.oui[1], params.oui[2]
	} else {
		eui[0], eui[1], eui[2] = prng.u8(), prng.u8(), prng.u8()
		if (eui[0] >> 1) & 1 == 0 {
			eui[0] ^= 0x02 // ensure to address is locally administreted
		}
		if eui[0] & 1 != 0 {
			eui[0] &= ~1 // ensure to address is unicast
		}
	}
	eui[3], eui[4], eui[5] = prng.u8(), prng.u8(), prng.u8()
	return Eui48{eui}
}

// str returns EUI-48 string representation in canonical format.
pub fn (e Eui48) str() string {
	return e.format(.canonical)
}

// format returns the MAC address as a string formatted according to the fmt rule.
pub fn (e Eui48) format(fmt Eui48Format) string {
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
			for i := 0; i <= 4; i += 2 {
				mac << e.addr[i..i + 2].hex()
			}
			return mac.join('.')
		}
		.bare {
			return e.addr[..].hex()
		}
	}
}

// u8_array returns EUI-48 as byte array.
pub fn (e Eui48) u8_array() []u8 {
	return e.addr[..]
}

// u8_array_fixed returns EUI-48 as fixed size byte array.
pub fn (e Eui48) u8_array_fixed() [6]u8 {
	return e.addr
}

// bit_len returns number of bits required to represent the current EUI-48.
pub fn (e Eui48) bit_len() int {
	return bits.len_64(binary.big_endian_u64(e.addr[..]))
}

// oui_bytes returns the 24 bit Organizationally Unique Identifier (OUI) as byte array.
pub fn (e Eui48) oui_bytes() [3]u8 {
	return [e.addr[0], e.addr[1], e.addr[2]]!
}

// ei_bytes returns the 24 bit Extended Identifier (EI) as byte array.
pub fn (e Eui48) ei_bytes() [3]u8 {
	return [e.addr[3], e.addr[4], e.addr[5]]!
}

// eui64 returns the EUI-64 converted from EUI-48 via extending address with FF-FE bytes.
pub fn (e Eui48) eui64() Eui64 {
	return Eui64{
		addr: [e.addr[0], e.addr[1], e.addr[2], 0xff, 0xfe, e.addr[3], e.addr[4], e.addr[5]]!
	}
}

// modified_eui64 converts the EUI-48 to Modified EUI-64.
// This is the same as `eui64()`, but the U/L-bit (universal/local bit) is inverted.
pub fn (e Eui48) modified_eui64() Eui64 {
	return Eui64{
		addr: [(e.addr[0] ^ 0x02), e.addr[1], e.addr[2], 0xff, 0xfe, e.addr[3], e.addr[4], e.addr[5]]!
	}
}

// ipv6 creates new IPv6 address from EUI-48. EUI-48 will be converted to
// Modified EUI-64 and appended to network prefix. Byte-reversed `prefix` must fit in 64 bit.
pub fn (e Eui48) ipv6(prefix Ipv6Addr) !Ipv6Addr {
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

// ipv6_link_local returns link-local IPv6 address created from EUI-48.
pub fn (e Eui48) ipv6_link_local() Ipv6Addr {
	return e.ipv6(Ipv6Addr.new(0xfe80, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
		0x0000) or { Ipv6Addr{} }) or { Ipv6Addr{} }
}

// is_universal returns true if address is universally administreted.
pub fn (e Eui48) is_universal() bool {
	// U/L bit is 0
	return (e.addr[0] >> 1) & 1 == 0
}

// is_local returns true if address is locally administreted.
pub fn (e Eui48) is_local() bool {
	return !e.is_universal()
}

// is_multicast returns true if address is multicast.
pub fn (e Eui48) is_multicast() bool {
	return !e.is_unicast()
}

// is_unicast returns true if address is unicast.
pub fn (e Eui48) is_unicast() bool {
	// I/G bit is 0
	return e.addr[0] & 1 == 0
}

// == returns true if a is equals b.
pub fn (a Eui48) == (b Eui48) bool {
	return a.addr == b.addr
}

@[params]
pub struct Eui48RandomParams {
pub:
	oui  ?[3]u8 // the custom OUI which is used instead of the random one.
	seed []u32  // seed for PRNG
	prng rand.PRNG = wyrand.WyRandRNG{}
}

pub enum Eui48Format {
	canonical // e.g. 0a-96-7a-87-4a-e3
	unix      // e.g. 0a:96:7a:87:4a:e3
	hextets   // e.g. 0a96.7a87.4ae3
	bare      // e.g. 0a967a874ae3
}
