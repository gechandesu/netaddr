import netaddr

fn test_ipv4_addr_from_string() {
	assert netaddr.Ipv4Addr.from_string('203.0.113.1')!.str() == '203.0.113.1'
}

fn test_ipv4_addr_from_u32() {
	assert netaddr.Ipv4Addr.from_u32(0).u8_array() == []u8{len: 4}
	assert netaddr.Ipv4Addr.from_u32(0).u8_array_fixed() == [4]u8{}
	assert netaddr.Ipv4Addr.from_u32(u32(2886733829)).str() == '172.16.16.5'
}

fn test_ipv4_addr_tests() {
	addr := netaddr.Ipv4Addr.from_string('203.0.113.1')!
	assert !addr.is_link_local()
	assert !addr.is_loopback()
	assert !addr.is_multicast()
	assert addr.is_unicast()
	assert !addr.is_shared()
	assert addr.is_private()
	assert !addr.is_global()
	assert !addr.is_reserved()
	assert !addr.is_unspecified()
}

fn test_ipv4_addr_ipv6() {
	addr := netaddr.Ipv4Addr.from_string('203.0.113.90')!
	assert addr.ipv6().str() == '::ffff:203.0.113.90'
	assert addr.ipv6(kind: .compat).str() == '::203.0.113.90'
}

fn test_ipv4_ipv6_addr_arr() {
	mut addrs := []netaddr.IpAddr{}
	addrs << netaddr.Ipv4Addr.from_string('203.0.113.90')!
	addrs << netaddr.Ipv6Addr.from_string('::1')!
	assert (addrs[0] as netaddr.Ipv4Addr).str() == '203.0.113.90'
	assert (addrs[1] as netaddr.Ipv6Addr).str() == '::1'
}

fn test_ipv4_net_compare() {
	assert netaddr.Ipv4Net.from_string('10.0.0.0/24')! < netaddr.Ipv4Net.from_string('10.10.0.0/24')!
}

fn test_ipv4_net() {
	net := netaddr.Ipv4Net.from_string('198.51.100.0/24')!
	assert net.str() == '198.51.100.0/24'
	assert net.prefix_len == 24
	assert net.network_address.str() == '198.51.100.0'
	assert net.network_mask.str() == '255.255.255.0'
	assert net.host_mask.str() == '0.0.0.255'
	assert net.broadcast_address.str() == '198.51.100.255'
	assert net.capacity() == 256
	assert !net.is_global()
}

fn test_ipv4_net_from_string() {
	net1 := netaddr.Ipv4Net.from_string('198.51.100.0/24')!
	net2 := netaddr.Ipv4Net.from_string('198.51.100.0/255.255.255.0')!
	net3 := netaddr.Ipv4Net.from_string('198.51.100.0/0.0.0.255')!
	assert net1.str() == '198.51.100.0/24'
	assert net2.str() == '198.51.100.0/24'
	assert net3.str() == '198.51.100.0/24'
	assert net1.host_address == none
	assert net2.host_address == none
	assert net3.host_address == none
	assert net3.host_address as netaddr.Ipv4Addr == netaddr.Ipv4Addr{}
	assert (net3.host_address as netaddr.Ipv4Addr).u8_array_fixed() == [4]u8{}
	net4 := netaddr.Ipv4Net.from_string('198.51.100.12/24')!
	net5 := netaddr.Ipv4Net.from_string('198.51.100.12/255.255.255.0')!
	net6 := netaddr.Ipv4Net.from_string('198.51.100.12/0.0.0.255')!
	assert net4.str() == '198.51.100.0/24'
	assert net5.str() == '198.51.100.0/24'
	assert net6.str() == '198.51.100.0/24'
	assert (net4.host_address as netaddr.Ipv4Addr).str() == '198.51.100.12'
	assert (net5.host_address as netaddr.Ipv4Addr).str() == '198.51.100.12'
	assert (net6.host_address as netaddr.Ipv4Addr).str() == '198.51.100.12'
	net7 := netaddr.Ipv4Net.from_string('172.16.16.6')!
	assert net7.str() == '172.16.16.6/32'
	assert net7.host_address == none
}

fn test_ipv4_net_from_u32() {
	net1 := netaddr.Ipv4Net.from_u32(3405803776, 24)!
	net2 := netaddr.Ipv4Net.from_u32(3405803788, 24)!
	assert net1.str() == '203.0.113.0/24'
	assert net1.host_address == none
	assert net2.str() == '203.0.113.0/24'
	assert (net2.host_address as netaddr.Ipv4Addr).u32() == u32(3405803788)
}

fn test_ipv4_net_host_bits() {
	net := netaddr.Ipv4Net.from_string('10.0.10.2/29')!
	assert net.network_address.str() == '10.0.10.0'
	assert (net.host_address as netaddr.Ipv4Addr).str() == '10.0.10.2'
}

fn test_ipv4_net_0() {
	net := netaddr.Ipv4Net.from_string('0.0.0.0/0')!
	assert net.str() == '0.0.0.0/0'
	assert net.prefix_len == 0
	assert net.network_address.str() == '0.0.0.0'
	assert net.network_mask.str() == '0.0.0.0'
	assert net.host_mask.str() == '255.255.255.255'
	assert net.broadcast_address.str() == '255.255.255.255'
	assert net.host_address == none
	assert net.capacity() == u64(max_u32) + 1
}

fn test_ipv4_net_255() {
	net := netaddr.Ipv4Net.from_string('255.255.255.255/32')!
	assert net.str() == '255.255.255.255/32'
	assert net.prefix_len == 32
	assert net.network_address.str() == '255.255.255.255'
	assert net.network_mask.str() == '255.255.255.255'
	assert net.host_mask.str() == '0.0.0.0'
	assert net.broadcast_address.str() == '255.255.255.255'
	assert net.host_address == none
	assert net.capacity() == 1
}

fn test_ipv4_net_next() {
	net := netaddr.Ipv4Net.from_string('10.0.10.128/30')!
	mut addrs := []netaddr.Ipv4Addr{}
	for addr in net {
		addrs << addr
	}
	assert addrs[0].str() == '10.0.10.128'
	assert addrs[1].str() == '10.0.10.129'
	assert addrs[2].str() == '10.0.10.130'
	assert addrs[3].str() == '10.0.10.131'
}

fn test_ipv4_net_subnets() {
	net := netaddr.Ipv4Net.from_string('10.0.10.0/24')!
	subnets := net.subnets(26)!
	mut networks := []netaddr.Ipv4Net{}
	for subnet in subnets {
		networks << subnet
	}
	assert networks[0].str() == '10.0.10.0/26'
	assert networks[1].str() == '10.0.10.64/26'
	assert networks[2].str() == '10.0.10.128/26'
	assert networks[3].str() == '10.0.10.192/26'
}

fn test_ipv4_net_nth() {
	net := netaddr.Ipv4Net.from_string('10.0.10.0/24')!
	assert net.nth(-2)!.str() == '10.0.10.254'
	assert net.nth(-1)!.str() == '10.0.10.255'
	assert net.nth(0)!.str() == '10.0.10.0'
	assert net.nth(1)!.str() == '10.0.10.1'
	assert (net.nth(99999) or { netaddr.Ipv4Addr{} }).str() == '0.0.0.0'
}

fn test_ipv4_net_supernet() {
	net := netaddr.Ipv4Net.from_string('10.129.10.0/24')!
	supernet := net.supernet(10)!
	assert supernet.str() == '10.128.0.0/10'
}

fn test_ipv4_net_is_subnet_of() {
	net1 := netaddr.Ipv4Net.from_string('10.10.0.0/16')!
	net2 := netaddr.Ipv4Net.from_string('10.10.0.0/24')!
	assert net2.is_subnet_of(net1)
}

fn test_ipv4_net_is_supernet_of() {
	net1 := netaddr.Ipv4Net.from_string('10.10.0.0/16')!
	net2 := netaddr.Ipv4Net.from_string('10.10.0.0/24')!
	net3 := netaddr.Ipv4Net.from_string('172.16.16.0/24')!
	assert net1.is_supernet_of(net2)
	assert !net1.is_supernet_of(net3)
}

fn test_ipv4_net_first_last() {
	net1 := netaddr.Ipv4Net.from_string('10.0.0.0/24')!
	net2 := netaddr.Ipv4Net.from_string('10.0.0.0/30')!
	net3 := netaddr.Ipv4Net.from_string('10.0.0.0/31')!
	net4 := netaddr.Ipv4Net.from_string('10.0.0.0/32')!
	assert net1.first().str() == '10.0.0.1'
	assert net1.last().str() == '10.0.0.254'
	assert net2.first().str() == '10.0.0.1'
	assert net2.last().str() == '10.0.0.2'
	assert net3.first().str() == '10.0.0.0'
	assert net3.last().str() == '10.0.0.1'
	assert net4.first().str() == '10.0.0.0'
	assert net4.last().str() == '10.0.0.0'
}
