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

/*
	This file contains functions for operating with 128-bit unsigned integer
	numbers represented as big endian ordered byte fixed size arrays.
	Note that arrays always be 16 byte length and may contain leading zeros.

	Using V math.big is significantly slower than doing math strictly on
	128-bit numbers. At a minimum, you have to do expensive instantiation of
	big.Integer.

	The functions below do not requires copying and allocates less memory.
*/

module netaddr

import math.bits

const max_128 = [16]u8{init: 0xff}
const one_128 = [u8(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]!

@[direct_array_access; inline]
fn add_128(a [16]u8, b [16]u8) [16]u8 {
	mut res := [16]u8{}
	mut num := u16(0)
	for i := 15; i >= 0; i-- {
		num += u16(a[i])
		num += u16(b[i])
		res[i] += u8(num % 256)
		num /= 256
	}
	if num > 0 {
		panic('128 bit overflow detected')
	}
	return res
}

@[direct_array_access; inline]
fn sub_128(a [16]u8, b [16]u8) [16]u8 {
	mut res := [16]u8{}
	mut borrowed := u8(0)
	for i := 15; i >= 0; i-- {
		if a[i] < b[i] {
			res[i] = (a[i] + 256) - borrowed - b[i]
			borrowed = 1
		} else {
			res[i] = a[i] - borrowed - b[i]
			borrowed = 0
		}
	}
	return res
}

@[direct_array_access; inline]
fn bit_len_128(a [16]u8) int {
	if a == [16]u8{} {
		return 0
	}
	mut len := 128
	mut zeros := 0
	for i in 0 .. 16 {
		zeros = bits.leading_zeros_8(a[i])
		if zeros == 0 {
			break
		}
		len -= zeros
	}
	return len
}

@[direct_array_access; inline]
fn left_shift_128(a [16]u8, shift int) [16]u8 {
	mut res := [16]u8{}
	shift_mod := shift % 8
	mask := u8((1 << shift_mod) - 1)
	offset := shift / 8

	for i := 0; i < 16; i++ {
		src_idx := i + offset
		if src_idx >= 16 {
			res[i] = 0
		} else {
			mut dst := u8(a[i] << shift_mod)
			if src_idx + 1 < 16 {
				dst |= a[src_idx + 1] >> ((8 - shift_mod) & mask)
			}
			res[i] = dst
		}
	}
	return res
}

@[direct_array_access; inline]
fn right_shift_128(a [16]u8, shift int) [16]u8 {
	mut res := [16]u8{}
	shift_mod := shift % 8
	mask := u8(0xff) << (8 - shift_mod)
	offset := shift / 8

	for i := 15; i >= 0; i-- {
		src_idx := i - offset
		if src_idx < 0 {
			res[i] = 0
		} else {
			mut dst := (u8(0xff) & a[i]) >> shift_mod
			if src_idx - 1 >= 0 {
				dst |= a[src_idx - 1] << ((8 - shift_mod) & mask)
			}
			res[i] = dst
		}
	}
	return res
}

@[direct_array_access; inline]
fn bitwise_and_128(a [16]u8, b [16]u8) [16]u8 {
	mut res := [16]u8{}
	for i := 0; i < 16; i++ {
		res[i] = a[i] & b[i]
	}
	return res
}

@[direct_array_access; inline]
fn bitwise_or_128(a [16]u8, b [16]u8) [16]u8 {
	mut res := [16]u8{}
	for i := 0; i < 16; i++ {
		res[i] = a[i] | b[i]
	}
	return res
}

@[direct_array_access; inline]
fn bitwise_xor_128(a [16]u8, b [16]u8) [16]u8 {
	mut res := [16]u8{}
	for i := 0; i < 16; i++ {
		res[i] = a[i] ^ b[i]
	}
	return res
}

// compare_128 returns:
//
// * -1 if a < b
// * 0 if a == b
// * +1 if a > b
@[direct_array_access; inline]
fn compare_128(a [16]u8, b [16]u8) int {
	for i in 0 .. 16 {
		if a[i] != b[i] {
			return if a[i] < b[i] { -1 } else { 1 }
		}
	}
	return 0
}
