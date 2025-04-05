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

pub type IpAddr = Ipv4Addr | Ipv4Net | Ipv6Addr | Ipv6Net

// IpAddr.from_string parses the addr string and returns IP address or IP network.
// This is universal function that processes both internet protocol versions.
//
// This function accepts all of the IP address and network formats allowed in
// Ipv4Addr.from_string, Ipv4Net.from_string, Ipv6Addr.from_string
// and Ipv6Net.from_string.
//
// Example:
// ```
// ip := netaddr.IpAddr.from_string('2001:db8:beaf::/56')!
// match ip {
// 	netaddr.Ipv4Addr {
// 		println('${ip} is IPv4 address')
// 	}
// 	netaddr.Ipv4Net {
// 		println('${ip} is IPv4 network')
// 	}
// 	netaddr.Ipv6Addr {
// 		println('${ip} is IPv6 address')
// 	}
// 	netaddr.Ipv6Net {
// 		println('${ip} is IPv6 network')
// 	}
// }
// ```
pub fn IpAddr.from_string(addr string) !IpAddr {
	if addr.contains('/') {
		if result := Ipv4Net.from_string(addr) {
			return result
		}
		if result := Ipv6Net.from_string(addr) {
			return result
		}
	}
	if result := Ipv4Addr.from_string(addr) {
		return result
	}
	if result := Ipv6Addr.from_string(addr) {
		return result
	}
	return error('${addr} is not a valid IPv4 or IPv6 address or network')
}

// str returns the IP string representation.
pub fn (ip IpAddr) str() string {
	return match ip {
		Ipv4Addr { ip.str() }
		Ipv6Addr { ip.str() }
		Ipv4Net { ip.str() }
		Ipv6Net { ip.str() }
	}
}

pub type Eui = Eui48 | Eui64

// Eui.from_string parses addr string and returns EUI-48 or EUI-64.
// Example:
// ```v okfmt
// cmd := os.execute('ip -br link show wlan0')
// interface_id := netaddr.Eui.from_string(cmd.output.split_by_space()[2])!
// println(interface_id)
// ```
pub fn Eui.from_string(addr string) !Eui {
	if result := Eui48.from_string(addr) {
		return result
	}
	if result := Eui64.from_string(addr) {
		return result
	}
	return error('${addr} is not valid EUI-48 or EUI-64')
}

// str returns the EUI string representation.
pub fn (eui Eui) str() string {
	return match eui {
		Eui48 { eui.str() }
		Eui64 { eui.str() }
	}
}
