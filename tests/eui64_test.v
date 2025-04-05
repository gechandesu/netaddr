import netaddr

fn test_eui48_from_string() {
	expected := netaddr.Eui64.new(0x0a, 0x96, 0x7a, 0xff, 0xfe, 0x87, 0x4a, 0xe3)
	assert netaddr.Eui64.from_string('0a-96-7a-ff-fe-87-4a-e3')! == expected
	assert netaddr.Eui64.from_string('0a:96:7a:ff:fe:87:4a:e3')! == expected
	assert netaddr.Eui64.from_string('0a96.7aff.fe87.4ae3')! == expected
	assert netaddr.Eui64.from_string('0a967afffe874ae3')! == expected
}

fn test_eui48_format() {
	eui := netaddr.Eui64.new(0x0a, 0x96, 0x7a, 0xff, 0xfe, 0x87, 0x4a, 0xe3)
	assert eui.str() == '0a-96-7a-ff-fe-87-4a-e3'
	assert eui.format(.canonical) == '0a-96-7a-ff-fe-87-4a-e3'
	assert eui.format(.unix) == '0a:96:7a:ff:fe:87:4a:e3'
	assert eui.format(.hextets) == '0a96.7aff.fe87.4ae3'
	assert eui.format(.bare) == '0a967afffe874ae3'
	assert netaddr.Eui64{}.format(.hextets) == '0000.0000.0000.0000'
}

fn test_eui64_modified() {
}
