import netaddr

fn test_eui48_from_string() {
	expected := netaddr.Eui48.from_octets([u8(0x0a), 0x96, 0x7a, 0x87, 0x4a, 0xe3]!)
	assert netaddr.Eui48.from_string('0a-96-7a-87-4a-e3')! == expected
	assert netaddr.Eui48.from_string('0a:96:7a:87:4a:e3')! == expected
	assert netaddr.Eui48.from_string('0a96.7a87.4ae3')! == expected
	assert netaddr.Eui48.from_string('0a967a874ae3')! == expected
	assert netaddr.Eui48.from_string(u64(4123532145345345).hex()) or { netaddr.Eui48{} } == netaddr.Eui48{}
}

fn test_eui48_format() {
	mac := netaddr.Eui48.from_octets([u8(0x0a), 0x96, 0x7a, 0x87, 0x4a, 0xe3]!)
	assert mac.str() == '0a-96-7a-87-4a-e3'
	assert mac.format(.canonical) == '0a-96-7a-87-4a-e3'
	assert mac.format(.unix) == '0a:96:7a:87:4a:e3'
	assert mac.format(.hextets) == '0a96.7a87.4ae3'
	assert mac.format(.bare) == '0a967a874ae3'
	assert netaddr.Eui48{}.format(.hextets) == '0000.0000.0000'
}

fn test_eui48_tests() {
	mac := netaddr.Eui48.from_octets([u8(0x10), 0xff, 0xe0, 0x4b, 0xe6, 0xb8]!)
	assert mac.is_universal()
	assert mac.is_unicast()
}

fn test_eui48_ipv6_link_local() {
	mac := netaddr.Eui48.from_octets([u8(0x10), 0xff, 0xe0, 0x4b, 0xe6, 0xb8]!)
	assert mac.ipv6_link_local().str() == 'fe80::12ff:e0ff:fe4b:e6b8'
}

fn test_eui48_random() {
	mac_a := netaddr.Eui48.random()
	assert mac_a.is_local()
	assert mac_a.is_unicast()
	mac_b := netaddr.Eui48.random(oui: [u8(0x02), 0x00, 0x00]!)
	assert mac_b.is_local()
	assert mac_b.is_unicast()
}
