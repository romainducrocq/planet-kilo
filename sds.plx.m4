m4_ifdef(`_DEF_SDS_M4', `', `
m4_define(`_DEF_SDS_M4', `')m4_dnl

# This is a single-file port of the sds library by antirez, to planet
# https://github.com/antirez/sds - see copyright at the bottom of this file

# SDS -- Simple Dynamic Strings library for planet in a single-file header,
#        define the _IMPL_SDS_M4 macro in one source file and include this
#        header file at call sites to use the sds library
#
# m4_define(`_IMPL_SDS_M4', `')m4_dnl     # only once
# m4_include(`path/to/sds.plx.m4')m4_dnl  # at call sites

m4_define(`sds', `string')m4_dnl

pub fn sds_len(s: sds) u64;
pub fn sds_new(init: string) sds;
pub fn sds_dup(s: sds) sds;
pub fn sds_free(s: sds) none;
pub fn sds_growzero(s: sds, len: u64) sds;
pub fn sds_cat(s: sds, t: string) sds;

pub fn sds_range(s: sds, start: i64, end: i64) none;
pub fn sds_clear(s: sds) none;
pub fn sds_fromlong(value: i64) sds;
pub fn sds_fromunsignedlong(value: u64) sds;

# Low level functions exposed to the user API
pub fn sds_MakeRoomFor(s: sds, addlen: u64) sds;

m4_ifdef(`_IMPL_SDS_M4', `

use "ctype"
use "stdio"
use "stdlib"
use "string"

# Note: sds_hdr5 is never used, we just access the flags byte directly.
# However is here to document the layout of type 5 SDS strings.
type struc sds_hdr5(
    flags: u8 # 3 lsb of type, and 5 msb of string length
    # char buf[];
)

type struc sds_hdr8(
    len: u8,   # used
    alloc: u8, # excluding the header and null terminator
    flags: u8  # 3 lsb of type, 5 unused bits
    # char buf[];
)

type struc sds_hdr32(
    len: u32,   # used
    alloc: u32, # excluding the header and null terminator
    flags: u8   # 3 lsb of type, 5 unused bits
    # char buf[];
)

type struc sds_hdr64(
    len: u64,   # used
    alloc: u64, # excluding the header and null terminator
    flags: u8   # 3 lsb of type, 5 unused bits
    # char buf[];
)

m4_define(`SDS_TYPE_5', `0')m4_dnl
m4_define(`SDS_TYPE_8', `1')m4_dnl
m4_define(`SDS_TYPE_32', `3')m4_dnl
m4_define(`SDS_TYPE_64', `4')m4_dnl
m4_define(`SDS_TYPE_MASK', `7')m4_dnl
m4_define(`SDS_TYPE_BITS', `3')m4_dnl
m4_define(`SDS_HDR_VAR', `sh: *struc sds_hdr$1 = cast<*any>(($2) - sizeof<struc sds_hdr$1>)')m4_dnl
m4_define(`SDS_HDR', `cast<*struc sds_hdr$1>(($2) - sizeof<struc sds_hdr$1>)')m4_dnl
m4_define(`SDS_TYPE_5_LEN', `(($1) >> SDS_TYPE_BITS)')m4_dnl

pub sds_NOINIT: string = "NOINIT"

pub fn sds_len(s: sds) u64 {
    flags: u8 = s[-1]
    match flags & SDS_TYPE_MASK {
        -> SDS_TYPE_5 {
            return SDS_TYPE_5_LEN(flags)
        }
        -> SDS_TYPE_8 {
            return SDS_HDR(8, s)[].len
        }
        -> SDS_TYPE_32 {
            return SDS_HDR(32, s)[].len
        }
        -> SDS_TYPE_64 {
            return SDS_HDR(64, s)[].len
        }
    }
    return 0
}

fn sds_avail(s: sds) u64 {
    flags: u8 = s[-1]
    match flags & SDS_TYPE_MASK {
        -> SDS_TYPE_5 {
            return 0
        }
        -> SDS_TYPE_8 {
            SDS_HDR_VAR(8, s)
            return sh[].alloc - sh[].len
        }
        -> SDS_TYPE_32 {
            SDS_HDR_VAR(32, s)
            return sh[].alloc - sh[].len
        }
        -> SDS_TYPE_64 {
            SDS_HDR_VAR(64, s)
            return sh[].alloc - sh[].len
        }
    }
    return 0
}

fn sds_setlen(s: sds, newlen: u64) none {
    flags: u8 = s[-1]
    match flags & SDS_TYPE_MASK {
        -> SDS_TYPE_5 {
            fp: *u8 = (cast<*u8>(s)) - 1
            fp[] = SDS_TYPE_5 | (newlen << SDS_TYPE_BITS)
            break
        }
        -> SDS_TYPE_8 {
            SDS_HDR(8, s)[].len = newlen
            break
        }
        -> SDS_TYPE_32 {
            SDS_HDR(32, s)[].len = newlen
            break
        }
        -> SDS_TYPE_64 {
            SDS_HDR(64, s)[].len = newlen
            break
        }
    }
}

fn sds_setalloc(s: sds, newlen: u64) none {
    flags: u8 = s[-1]
    match flags & SDS_TYPE_MASK {
        -> SDS_TYPE_5 {
            # Nothing to do, this type has no total allocation info.
            break
        }
        -> SDS_TYPE_8 {
            SDS_HDR(8, s)[].alloc = newlen
            break
        }
        -> SDS_TYPE_32 {
            SDS_HDR(32, s)[].alloc = newlen
            break
        }
        -> SDS_TYPE_64 {
            SDS_HDR(64, s)[].alloc = newlen
            break
        }
    }
}

fn sds_HdrSize(stype: char) i32 {
    match stype & SDS_TYPE_MASK {
        -> SDS_TYPE_5 {
            return sizeof<struc sds_hdr5>
        }
        -> SDS_TYPE_8 {
            return sizeof<struc sds_hdr8>
        }
        -> SDS_TYPE_32 {
            return sizeof<struc sds_hdr32>
        }
        -> SDS_TYPE_64 {
            return sizeof<struc sds_hdr64>
        }
    }
    return 0
}

fn sds_ReqType(string_size: u64) char {
    if string_size < 1 << 5 {
        return SDS_TYPE_5
    }
    if string_size < 1 << 8 {
        return SDS_TYPE_8
    }
    if string_size < 1l << 32 {
        return SDS_TYPE_32
    }
    return SDS_TYPE_64
}

# Create a new sds string with the content specified by the init pointer
# and initlen.
# If 0 is used for init the string is initialized with zero bytes.
# If sds_NOINIT is used, the buffer is left uninitialized;
#
# The string is always null-terminated (all the sds strings are, always) so
# even if you create an sds string with:
#
# mystring = sds_newlen("abc",3);
#
# You can print the string with printf() as there is an implicit \0 at the
# end of the string. However the string is binary safe and can contain
# \0 characters in the middle, as the length is stored in the sds header.
fn sds_newlen(init: *any, initlen: u64) sds {
    sh: *any;
    s: sds;
    stype: char = sds_ReqType(initlen)
    # Empty strings are usually created in order to append. Use type 8
    # since type 5 is not good at this.
    if stype == SDS_TYPE_5 and initlen == 0 {
        stype = SDS_TYPE_8
    }
    hdrlen: i32 = sds_HdrSize(stype)
    fp: *u8; # flags pointer.

    sh = malloc(hdrlen + initlen + 1)
    if sh == 0 {
        return 0
    }
    if init == sds_NOINIT {
        init = 0
    }
    elif not init {
        memset(sh, 0, hdrlen + initlen + 1)
    }
    s = cast<string>(sh) + hdrlen
    fp = (cast<*u8>(s)) - 1
    match stype {
        -> SDS_TYPE_5 {
            fp[] = stype | (initlen << SDS_TYPE_BITS)
            break
        }
        -> SDS_TYPE_8 {
            SDS_HDR_VAR(8, s)
            sh[].len = initlen
            sh[].alloc = initlen
            fp[] = stype
            break
        }
        -> SDS_TYPE_32 {
            SDS_HDR_VAR(32, s)
            sh[].len = initlen
            sh[].alloc = initlen
            fp[] = stype
            break
        }
        -> SDS_TYPE_64 {
            SDS_HDR_VAR(64, s)
            sh[].len = initlen
            sh[].alloc = initlen
            fp[] = stype
            break
        }
    }
    if initlen and init {
        memcpy(s, init, initlen)
    }
    s[initlen] = 0
    return s
}

# Create a new sds string starting from a null terminated C string.
pub fn sds_new(init: string) sds {
    initlen: u64 = ? (init == 0) then 0 else strlen(init)
    return sds_newlen(init, initlen)
}

# Duplicate an sds string.
pub fn sds_dup(s: sds) sds {
    return sds_newlen(s, sds_len(s))
}

# Free an sds string. No operation is performed if s is 0.
pub fn sds_free(s: sds) none {
    if s == 0 {
        return none
    }
    free(cast<string>(s) - sds_HdrSize(s[-1]))
}

# Modify an sds string in-place to make it empty (zero length).
# However all the existing buffer is not discarded but set as free space
# so that next append operations will not require allocations up to the
# number of bytes previously available.
pub fn sds_clear(s: sds) none {
    sds_setlen(s, 0)
    s[0] = 0
}

# Enlarge the free space at the end of the sds string so that the caller
# is sure that after calling this function can overwrite up to addlen
# bytes after the end of the string, plus one more byte for nul term.
#
# Note: this does not change the *length* of the sds string as returned
# by sds_len(), but only the free buffer space we have.
m4_define(`SDS_MAX_PREALLOC', `(1024 * 1024)')m4_dnl
pub fn sds_MakeRoomFor(s: sds, addlen: u64) sds {
    sh: *any;
    newsh: *any;
    avail: u64 = sds_avail(s)
    len: u64;
    newlen: u64;
    stype: char;
    oldstype: char = s[-1] & SDS_TYPE_MASK
    hdrlen: i32;

    # Return ASAP if there is enough space left.
    if avail >= addlen {
        return s
    }

    len = sds_len(s)
    sh = cast<string>(s) - sds_HdrSize(oldstype)
    newlen = (len + addlen)
    if newlen < SDS_MAX_PREALLOC {
        newlen *= 2
    }
    else {
        newlen += SDS_MAX_PREALLOC
    }

    stype = sds_ReqType(newlen)

    # Dont use type 5: the user is appending to the string and type 5 is
    # not able to remember empty space, so sds_MakeRoomFor() must be called
    # at every appending operation.
    if stype == SDS_TYPE_5 {
        stype = SDS_TYPE_8
    }

    hdrlen = sds_HdrSize(stype)
    # assert(hdrlen + newlen + 1 > (len + addlen)); # Catch unsigned long overflow
    if oldstype == stype {
        newsh = realloc(sh, hdrlen + newlen + 1)
        if newsh == 0 {
            return 0
        }
        s = cast<string>(newsh) + hdrlen
    }
    else {
        # Since the header size changes, need to move the string forward,
        # and cant use realloc
        newsh = malloc(hdrlen + newlen + 1)
        if newsh == 0 {
            return 0
        }
        memcpy(cast<string>(newsh) + hdrlen, s, len + 1)
        free(sh)
        s = cast<string>(newsh) + hdrlen
        s[-1] = stype
        sds_setlen(s, len)
    }
    sds_setalloc(s, newlen)
    return s
}

# Grow the sds to have the specified length. Bytes that were not part of
# the original length of the sds will be set to zero.
#
# if the specified length is smaller than the current length, no operation
# is performed.
pub fn sds_growzero(s: sds, len: u64) sds {
    curlen: u64 = sds_len(s)

    if len <= curlen {
        return s
    }
    s = sds_MakeRoomFor(s, len - curlen)
    if s == 0 {
        return 0
    }

    # Make sure added region doesnt contain garbage
    memset(s + curlen, 0, (len - curlen + 1)) # also set trailing \0 byte
    sds_setlen(s, len)
    return s
}

# Append the specified binary-safe string pointed by t of len bytes to the
# end of the specified sds string s.
#
# After the call, the passed sds string is no longer valid and all the
# references must be substituted with the new pointer returned by the call.
fn sds_catlen(s: sds, t: *any, len: u64) sds {
    curlen: u64 = sds_len(s)

    s = sds_MakeRoomFor(s, len)
    if s == 0 {
        return 0
    }
    memcpy(s + curlen, t, len)
    sds_setlen(s, curlen + len)
    s[curlen + len] = 0
    return s
}

# Append the specified null termianted C string to the sds string s.
#
# After the call, the passed sds string is no longer valid and all the
# references must be substituted with the new pointer returned by the call.
pub fn sds_cat(s: sds, t: string) sds {
    return sds_catlen(s, t, strlen(t))
}

# Helper for sds_catlonglong() doing the actual number -> string
# conversion. s must point to a string with room for at least
# SDS_LLSTR_SIZE bytes.
#
# The function returns the length of the null-terminated string
# representation stored at s.
m4_define(`SDS_LLSTR_SIZE', `21')m4_dnl
fn sds_ll2str(s: string, value: i64) i32 {
    p: string;
    aux: char;
    v: u64;
    l: u64;

    # Generate the string representation, this method produces
    # an reversed string.
    if value < 0 {
        # Since v is unsigned, if value==LLONG_MIN then
        # -LLONG_MIN will overflow.
        if value ~= -9223372036854775807l - 1 {
            v = -value
        }
        else {
            v = (cast<u64>(9223372036854775807l)) + 1
        }
    }
    else {
        v = value
    }

    p = s
    loop .. while v {
        p++[] = 48 + (v % 10)
        v /= 10
    }
    if value < 0 {
        p++[] = 45
    }

    # Compute length and add null term.
    l = p - s
    p[] = 0

    # Reverse the string.
    p--
    loop while s < p {
        aux = s[]
        s[] = p[]
        p[] = aux
        s++
        p--
    }
    return l
}

# Identical sds_ll2str(), but for unsigned long type.
fn sds_ull2str(s: string, v: u64) i32 {
    p: string;
    aux: char;
    l: u64;

    # Generate the string representation, this method produces
    # an reversed string.
    p = s
    loop .. while v {
        p++[] = 48 + (v % 10)
        v /= 10
    }

    # Compute length and add null term.
    l = p - s
    p[] = 0

    # Reverse the string.
    p--
    loop while s < p {
        aux = s[]
        s[] = p[]
        p[] = aux
        s++
        p--
    }
    return l
}

# Create an sds string from a long value. It is much faster than:
#
# sds_catprintf(sds_empty(),"%lld\n", value);
pub fn sds_fromlong(value: i64) sds {
    buf: [SDS_LLSTR_SIZE]char;
    len: i32 = sds_ll2str(buf, value)

    return sds_newlen(buf, len)
}

pub fn sds_fromunsignedlong(value: u64) sds {
    buf: [SDS_LLSTR_SIZE]char;
    len: i32 = sds_ull2str(buf, value)

    return sds_newlen(buf, len)
}

# Turn the string into a smaller (or equal) string containing only the
# substring specified by the start and end indexes.
#
# start and end can be negative, where -1 means the last character of the
# string, -2 the penultimate character, and so forth.
#
# The interval is inclusive, so the start and end characters will be part
# of the resulting string.
#
# The string is modified in-place.
#
# Example:
#
# s = sds_new("Hello World");
# sds_range(s,1,-1); => "ello World"
pub fn sds_range(s: sds, start: i64, end: i64) none {
    newlen: u64;
    len: u64 = sds_len(s)

    if len == 0 {
        return none
    }
    if start < 0 {
        start = len + start
        if start < 0 {
            start = 0
        }
    }
    if end < 0 {
        end = len + end
        if end < 0 {
            end = 0
        }
    }
    newlen = ? (start > end) then 0 else (end - start) + 1
    if newlen ~= 0 {
        if start >= cast<i64>(len) {
            newlen = 0
        }
        elif end >= cast<i64>(len) {
            end = len - 1
            newlen = (end - start) + 1
        }
    }
    if start and newlen {
        memmove(s, s + start, newlen)
    }
    s[newlen] = 0
    sds_setlen(s, newlen)
}

# Copyright 2026 Romain Ducrocq
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# -----------------------------------------------------------------------
#
# SDSLib 2.0 -- A C dynamic strings library
#
# Copyright (c) 2006-2015, Salvatore Sanfilippo <antirez at gmail dot com>
# Copyright (c) 2015, Oran Agra
# Copyright (c) 2015, Redis Labs, Inc
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of Redis nor the names of its contributors may be used
#     to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

')m4_dnl
')m4_dnl
