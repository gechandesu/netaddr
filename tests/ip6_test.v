import math.big
import netaddr

fn test_ipv6_addr_new() {
	a := netaddr.Ipv6Addr.new(0x2001, 0x0db8, 0x0008, 0x0004, 0x0000, 0x0000, 0x0000,
		0x0002)!
	b := netaddr.Ipv6Addr.new(0xfe80, 0x0000, 0x0000, 0x0000, 0xd08e, 0x6658, 0x38bd,
		0x6391,
		zone_id: 'wlan0'
	)!
	assert a.str() == '2001:db8:8:4::2'
	assert b.str() == 'fe80::d08e:6658:38bd:6391%wlan0'
}

fn test_ipv6_add_segments() {
	ip := netaddr.Ipv6Addr.new(0x2001, 0x0db8, 0x0008, 0x0004, 0x0000, 0x0000, 0x0000,
		0x0002)!
	assert ip.segments() == [u16(0x2001), 0x0db8, 0x0008, 0x0004, 0x0000, 0x0000, 0x0000, 0x0002]!
}

fn test_ipv6_addr_from_to_bigint() {
	bigint := big.integer_from_string('338288524927261089661396923005694177083')!
	addr := netaddr.Ipv6Addr.from_bigint(bigint)!
	assert addr.format(.verbose) == 'fe80:0000:0000:0000:6664:03b4:bd68:ef3b'
	assert addr.bigint() == bigint
	addr2 := netaddr.Ipv6Addr.from_string('fe80:0000:0000:0000:6664:03b4:bd68:ef3b')!
	assert addr2.bigint() == bigint
}

fn test_ipv6_addr_from_string_zeros() {
	assert netaddr.Ipv6Addr.from_string('::')!.bigint() == big.zero_int
}

fn test_ipv6_addr_from_string() {
	addrs := {
		'fe80:0000:0000:0000:0896:7aff:0e87:4ae3': 'fe80::896:7aff:e87:4ae3'
		'fe80:0:0:0:896:7aff:e87:4ae3':            'fe80::896:7aff:e87:4ae3'
		'fe80::896:7aff:e87:4ae3':                 'fe80::896:7aff:e87:4ae3'
		'fe80::896:7aff:e87:4ae3%1':               'fe80::896:7aff:e87:4ae3%1'
		'[fe80::896:7aff:e87:4ae3%2]':             'fe80::896:7aff:e87:4ae3%2'
		'0:0:0:0:0:0:0:0':                         '::'
		'0000:0000:0000:0000:0000:0000:0000:0000': '::'
		'::':                                      '::'
		'::1':                                     '::1'
		'0:0:ff::':                                '0:0:ff::'
		'0:0:ff::1':                               '0:0:ff::1'
		'::ffff:1:2:3:4':                          '::ffff:1:2:3:4'
		'::192.168.1.1':                           '::192.168.1.1'
	}
	for inp, out in addrs {
		assert netaddr.Ipv6Addr.from_string(inp)!.str() == out
	}
}

fn test_ipv6_addr_format() {
	addr1 := netaddr.Ipv6Addr.from_string('fe80::896:7aff:e87:4ae3')!
	assert addr1.format(.dotted) == 'fe80::896:7aff:e87:4ae3'
	assert addr1.format(.compact) == 'fe80::896:7aff:e87:4ae3'
	assert addr1.format(.compact | .dotted) == 'fe80::896:7aff:e87:4ae3'
	assert addr1.format(.verbose) == 'fe80:0000:0000:0000:0896:7aff:0e87:4ae3'
	assert addr1.format(.verbose | .dotted) == 'fe80:0000:0000:0000:0896:7aff:0e87:4ae3'
	assert addr1.format(.compact | .verbose | .dotted) == 'fe80::896:7aff:e87:4ae3'
	addr2 := netaddr.Ipv6Addr.from_string('::ffff:192.168.3.8')!
	assert addr2.format(.dotted) == '::ffff:192.168.3.8'
	assert addr2.format(.compact) == '::ffff:c0a8:308'
	assert addr2.format(.compact | .dotted) == '::ffff:192.168.3.8'
	assert addr2.format(.verbose) == '0000:0000:0000:0000:0000:ffff:c0a8:0308'
	assert addr2.format(.verbose | .dotted) == '0000:0000:0000:0000:0000:ffff:192.168.3.8'
	assert addr2.format(.compact | .verbose | .dotted) == '::ffff:192.168.3.8'
}

fn test_ipv6_addr_dns_ptr() {
	expect := '1.9.3.6.d.b.8.3.8.5.6.6.e.8.0.d.0.0.0.0.0.0.0.0.0.0.0.0.0.8.e.f.ip6.arpa'
	assert netaddr.Ipv6Addr.from_string('fe80::d08e:6658:38bd:6391')!.reverse_pointer() == expect
}

fn test_ipv6_addr_with_scope() {
	addr := netaddr.Ipv6Addr.from_string('fe80::896:7aff:e87:4ae3%lan0')!
	assert addr.zone_id as string == 'lan0'
	assert addr.str() == 'fe80::896:7aff:e87:4ae3%lan0'
	assert netaddr.Ipv6Addr.from_string('fe80::896:7aff:e87:4ae3')!
		.with_scope('1')!
		.str() == 'fe80::896:7aff:e87:4ae3%1'
}

fn test_ipv6_addr_is_ipv4_compat() {
	assert !netaddr.Ipv6Addr.from_string('::')!.is_ipv4_compat()
	assert !netaddr.Ipv6Addr.from_string('::1')!.is_ipv4_compat()
	assert netaddr.Ipv6Addr.from_string('::192.168.0.3')!.is_ipv4_compat()
}

fn test_ipv6_addr_is_ipv4_mapped() {
	assert netaddr.Ipv6Addr.from_string('::ffff:cb00:715a')!.is_ipv4_mapped()
	assert !netaddr.Ipv6Addr.from_string('::fff:cb00:715a')!.is_ipv4_mapped()
}

fn test_ipv6_addr_ipv4() {
	assert netaddr.Ipv6Addr.from_string('::ffff:cb00:715a')!.ipv4()!.str() == '203.0.113.90'
}

fn test_ipv6_addr_six_to_four() {
	assert netaddr.Ipv6Addr.from_string('2002:c001:0203::')!.six_to_four()!.str() == '192.1.2.3'
	assert netaddr.Ipv6Addr.from_string('2002:09fe:fdfc::')!.six_to_four()!.str() == '9.254.253.252'
}

fn test_ipv6_addr_teredo() {
	teredo := netaddr.Ipv6Addr.from_string('2001:0000:4136:e378:8000:63bf:3fff:fdd2')!.teredo()!
	assert teredo.server.str() == '65.54.227.120'
	assert teredo.flags == 0x8000
	assert teredo.port == 40_000
	assert teredo.client.str() == '192.0.2.45'
}

fn test_teredo_addr_ipv6() {
	teredo := netaddr.TeredoAddr{
		server: netaddr.Ipv4Addr.from_string('65.54.227.120')!
		flags:  0x8000
		port:   40_000
		client: netaddr.Ipv4Addr.from_string('192.0.2.45')!
	}
	assert teredo.ipv6().str() == '2001:0:4136:e378:8000:63bf:3fff:fdd2'
}

fn test_ipv6_addr_tests() {
	addr := netaddr.Ipv6Addr.from_string('fe80::d08e:6658:38bd:6391')!
	assert !addr.is_ipv4_mapped()
	assert !addr.is_ipv4_compat()
	assert !addr.is_site_local()
	assert !addr.is_unique_local()
	assert addr.is_link_local()
	assert !addr.is_loopback()
	assert !addr.is_multicast()
	assert addr.is_unicast()
	assert addr.is_private()
	assert !addr.is_global()
	assert !addr.is_reserved()
	assert !addr.is_unspecified()
}

fn test_ipv6_is_netmask_is_hostmask() {
	assert netaddr.Ipv6Addr.from_string('ffff:ffff:ffff:ffff:ffff:ffff:0000:0000')!.is_netmask()
	assert !netaddr.Ipv6Addr.from_string('ffff:ffff:ffff:ffff:ffff:ffff:0000:ffff')!.is_netmask()
	assert netaddr.Ipv6Addr.from_string('::ffff:ffff:ffff:ffff')!.is_hostmask()
	assert !netaddr.Ipv6Addr.from_string('::2a:ffff:ffff:ffff:ffff')!.is_hostmask()
}

fn test_ipv6_net() {
	net := netaddr.Ipv6Net.from_string('fe80::/64')!
	assert net.str() == 'fe80::/64'
	assert net.network_address.str() == 'fe80::'
	assert net.network_mask.str() == 'ffff:ffff:ffff:ffff::'
	assert net.host_mask.str() == '::ffff:ffff:ffff:ffff'
	assert net.broadcast_address.str() == 'fe80::ffff:ffff:ffff:ffff'
	assert net.host_address == none
	assert net.prefix_len == 64
}

fn test_ipv6_net_new() {
	addr := netaddr.Ipv6Addr.from_string('fe80::')!
	net := netaddr.Ipv6Net.new(addr, 64)!
	assert net.str() == 'fe80::/64'
	assert net.network_address.str() == 'fe80::'
	assert net.network_mask.str() == 'ffff:ffff:ffff:ffff::'
	assert net.host_mask.str() == '::ffff:ffff:ffff:ffff'
	assert net.broadcast_address.str() == 'fe80::ffff:ffff:ffff:ffff'
	assert net.host_address == none
	assert net.prefix_len == 64
}

fn test_ipv6_net_from_string() {
	assert netaddr.Ipv6Net.from_string('fe80:ffff::/64')!.str() == 'fe80:ffff::/64'
	assert netaddr.Ipv6Net.from_string('fe80:ffff::/ffff:ffff:ffff:ffff::')!.str() == 'fe80:ffff::/64'
	assert netaddr.Ipv6Net.from_string('fe80:ffff::/::ffff:ffff:ffff:ffff')!.str() == 'fe80:ffff::/64'
}

fn test_ipv6_net_format() {
	net := netaddr.Ipv6Net.from_string('fe80:ffff::/64')!
	assert net.format(.compact) == 'fe80:ffff::/64'
	assert net.format(.with_prefix_len) == 'fe80:ffff::/64'
	assert net.format(.with_network_mask) == 'fe80:ffff::/ffff:ffff:ffff:ffff::'
	assert net.format(.with_host_mask) == 'fe80:ffff::/::ffff:ffff:ffff:ffff'
	assert net.format(.verbose) == 'fe80:ffff:0000:0000:0000:0000:0000:0000/64'
	assert net.format(.verbose | .with_prefix_len) == 'fe80:ffff:0000:0000:0000:0000:0000:0000/64'
	assert net.format(.verbose | .with_network_mask) == 'fe80:ffff:0000:0000:0000:0000:0000:0000/ffff:ffff:ffff:ffff:0000:0000:0000:0000'
	assert net.format(.verbose | .with_host_mask) == 'fe80:ffff:0000:0000:0000:0000:0000:0000/0000:0000:0000:0000:ffff:ffff:ffff:ffff'
}

fn test_ipv6_net_first_last() {
	net := netaddr.Ipv6Net.from_string('fe80:ffff::/64')!
	assert net.first().str() == 'fe80:ffff::1'
	assert net.last().str() == 'fe80:ffff::ffff:ffff:ffff:fffe'
}

fn test_ipv6_net_next() {
	net := netaddr.Ipv6Net.from_string('fe80::/64')!
	mut addrs := []netaddr.Ipv6Addr{}
	limit := 5
	for i, addr in net {
		if i >= limit {
			break
		}
		addrs << addr
	}
	assert addrs[0].str() == 'fe80::'
	assert addrs[1].str() == 'fe80::1'
	assert addrs[2].str() == 'fe80::2'
	assert addrs[3].str() == 'fe80::3'
}

fn test_ipv6_net_subnets() {
	net := netaddr.Ipv6Net.from_string('fe80::/48')!
	subnets := net.subnets(64)!
	mut networks := []netaddr.Ipv6Net{}
	limit := 5
	for i, subnet in subnets {
		if i >= limit {
			break
		}
		networks << subnet
	}
	assert networks[0].str() == 'fe80::/64'
	assert networks[1].str() == 'fe80:0:0:1::/64'
	assert networks[2].str() == 'fe80:0:0:2::/64'
	assert networks[3].str() == 'fe80:0:0:3::/64'
}

fn test_ipv6_net_supernet() {
	net := netaddr.Ipv6Net.from_string('fe80:0:0:3::/64')!
	assert net.supernet(48)!.str() == 'fe80::/48'
}
