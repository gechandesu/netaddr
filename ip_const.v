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

// This file contains pre-calculated values for IPv4 reserved networks.
// See https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml

module netaddr

struct Ipv4Const {
	begin u32
	end   u32
}

fn (n Ipv4Const) contains(addr Ipv4Addr) bool {
	return n.begin <= addr.u32() && addr.u32() <= n.end
}

// 169.254.0.0/16
const ipv4_link_local_network = Ipv4Const{u32(2851995648), u32(2852061183)}
// 127.0.0.0/8
const ipv4_loopback_network = Ipv4Const{u32(2130706432), u32(2147483647)}
// 224.0.0.0/4
const ipv4_multicast_network = Ipv4Const{u32(3758096384), u32(4026531839)}
// 100.64.0.0/10
const ipv4_public_network = Ipv4Const{u32(1681915904), u32(1686110207)}
// 240.0.0.0/4
const ipv4_reserved_network = Ipv4Const{u32(4026531840), u32(4294967295)}

const ipv4_private_networks = [
	// 0.0.0.0/8
	Ipv4Const{u32(0), u32(16777215)},
	// 10.0.0.0/8
	Ipv4Const{u32(167772160), u32(184549375)},
	// 169.254.0.0/16
	Ipv4Const{u32(2851995648), u32(2852061183)}
	// 127.0.0.0/8
	Ipv4Const{u32(2130706432), u32(2147483647)}
	// 172.16.0.0/12
	Ipv4Const{u32(2886729728), u32(2887778303)},
	// 192.0.0.0/24
	Ipv4Const{u32(3221225472), u32(3221225727)},
	// 192.0.0.170/31
	Ipv4Const{u32(3221225642), u32(3221225643)},
	// 192.0.2.0/24
	Ipv4Const{u32(3221225984), u32(3221226239)},
	// 192.168.0.0/16
	Ipv4Const{u32(3232235520), u32(3232301055)},
	// 198.18.0.0/15
	Ipv4Const{u32(3323068416), u32(3323199487)},
	// 198.51.100.0/24
	Ipv4Const{u32(3325256704), u32(3325256959)},
	// 203.0.113.0/24
	Ipv4Const{u32(3405803776), u32(3405804031)},
	// 240.0.0.0/4
	Ipv4Const{u32(4026531840), u32(4294967295)}
	// 255.255.255.255/32
	Ipv4Const{u32(4294967295), u32(4294967295)},
]!

const ipv4_private_networks_exceptions = [
	// 192.0.0.9/32
	Ipv4Const{u32(3221225481), u32(3221225481)},
	// 192.0.0.10/32
	Ipv4Const{u32(3221225482), u32(3221225482)},
]!
