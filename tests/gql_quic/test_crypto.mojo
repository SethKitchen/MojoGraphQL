# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for `gql_quic.crypto`: the sample packets of RFC 9001 Appendix A as
exact bytes (A.1 keys, A.2 client Initial, A.3 server Initial, A.5
ChaCha20-Poly1305 short header), and the key update of section 6. The
upstream tests are the `#[cfg(test)]` vectors of quinn-proto 0.11.19
quinn-proto/src/crypto/rustls.rs and packet.rs, which use the same
appendix."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from gql_tls.error import TlsErrorKind
from gql_tls.openssl import OpenSsl
from gql_quic.crypto import (
    CipherSuite,
    Crypto,
    DirectionalKeys,
    HeaderKey,
    PacketKey,
    crypto_function,
    initial_keys,
    initial_secrets,
)


def unhex(text: StringSlice) -> List[UInt8]:
    """Parse hexadecimal digits, and skip every other character."""
    var out = List[UInt8]()
    var high = -1
    for byte in text.as_bytes():
        var digit = -1
        if byte >= 48 and byte <= 57:
            digit = Int(byte) - 48
        elif byte >= 97 and byte <= 102:
            digit = Int(byte) - 87
        if digit < 0:
            continue
        if high < 0:
            high = digit
        else:
            out.append(UInt8(high * 16 + digit))
            high = -1
    return out^


def tohex(data: Span[UInt8, _]) -> String:
    """Write bytes as lowercase hexadecimal digits."""
    var digits = "0123456789abcdef".as_bytes()
    var out = String()
    for byte in data:
        out += chr(Int(digits[Int(byte >> 4)]))
        out += chr(Int(digits[Int(byte & 15)]))
    return out^


comptime DCID = "8394c8f03e515708"

comptime CLIENT_CRYPTO = (
    "060040f1010000ed0303ebf8fa56f129 39b9584a3896472ec40bb863cfd3e868"
    " 04fe3a47f06a2b69484c000004130113 02010000c000000010000e00000b6578"
    " 616d706c652e636f6dff01000100000a 00080006001d00170018001000070005"
    " 04616c706e0005000501000000000033 00260024001d00209370b2c9caa47fba"
    " baf4559fedba753de171fa71f50f1ce1 5d43e994ec74d748002b000302030400"
    " 0d0010000e0403050306030203080408 050806002d00020101001c0002400100"
    " 3900320408ffffffffffffffff050480 00ffff07048000ffff08011001048000"
    " 75300901100f088394c8f03e51570806 048000ffff"
)

comptime CLIENT_PROTECTED = (
    "c000000001088394c8f03e5157080000 449e7b9aec34d1b1c98dd7689fb8ec11"
    "d242b123dc9bd8bab936b47d92ec356c 0bab7df5976d27cd449f63300099f399"
    "1c260ec4c60d17b31f8429157bb35a12 82a643a8d2262cad67500cadb8e7378c"
    "8eb7539ec4d4905fed1bee1fc8aafba1 7c750e2c7ace01e6005f80fcb7df6212"
    "30c83711b39343fa028cea7f7fb5ff89 eac2308249a02252155e2347b63d58c5"
    "457afd84d05dfffdb20392844ae81215 4682e9cf012f9021a6f0be17ddd0c208"
    "4dce25ff9b06cde535d0f920a2db1bf3 62c23e596d11a4f5a6cf3948838a3aec"
    "4e15daf8500a6ef69ec4e3feb6b1d98e 610ac8b7ec3faf6ad760b7bad1db4ba3"
    "485e8a94dc250ae3fdb41ed15fb6a8e5 eba0fc3dd60bc8e30c5c4287e53805db"
    "059ae0648db2f64264ed5e39be2e20d8 2df566da8dd5998ccabdae053060ae6c"
    "7b4378e846d29f37ed7b4ea9ec5d82e7 961b7f25a9323851f681d582363aa5f8"
    "9937f5a67258bf63ad6f1a0b1d96dbd4 faddfcefc5266ba6611722395c906556"
    "be52afe3f565636ad1b17d508b73d874 3eeb524be22b3dcbc2c7468d54119c74"
    "68449a13d8e3b95811a198f3491de3e7 fe942b330407abf82a4ed7c1b311663a"
    "c69890f4157015853d91e923037c227a 33cdd5ec281ca3f79c44546b9d90ca00"
    "f064c99e3dd97911d39fe9c5d0b23a22 9a234cb36186c4819e8b9c5927726632"
    "291d6a418211cc2962e20fe47feb3edf 330f2c603a9d48c0fcb5699dbfe58964"
    "25c5bac4aee82e57a85aaf4e2513e4f0 5796b07ba2ee47d80506f8d2c25e50fd"
    "14de71e6c418559302f939b0e1abd576 f279c4b2e0feb85c1f28ff18f58891ff"
    "ef132eef2fa09346aee33c28eb130ff2 8f5b766953334113211996d20011a198"
    "e3fc433f9f2541010ae17c1bf202580f 6047472fb36857fe843b19f5984009dd"
    "c324044e847a4f4a0ab34f719595de37 252d6235365e9b84392b061085349d73"
    "203a4a13e96f5432ec0fd4a1ee65accd d5e3904df54c1da510b0ff20dcc0c77f"
    "cb2c0e0eb605cb0504db87632cf3d8b4 dae6e705769d1de354270123cb11450e"
    "fc60ac47683d7b8d0f811365565fd98c 4c8eb936bcab8d069fc33bd801b03ade"
    "a2e1fbc5aa463d08ca19896d2bf59a07 1b851e6c239052172f296bfb5e724047"
    "90a2181014f3b94a4e97d117b4381303 68cc39dbb2d198065ae3986547926cd2"
    "162f40a29f0c3c8745c0f50fba3852e5 66d44575c29d39a03f0cda721984b6f4"
    "40591f355e12d439ff150aab7613499d bd49adabc8676eef023b15b65bfc5ca0"
    "6948109f23f350db82123535eb8a7433 bdabcb909271a6ecbcb58b936a88cd4e"
    "8f2e6ff5800175f113253d8fa9ca8885 c2f552e657dc603f252e1a8e308f76f0"
    "be79e2fb8f5d5fbbe2e30ecadd220723 c8c0aea8078cdfcb3868263ff8f09400"
    "54da48781893a7e49ad5aff4af300cd8 04a6b6279ab3ff3afb64491c85194aab"
    "760d58a606654f9f4400e8b38591356f bf6425aca26dc85244259ff2b19c41b9"
    "f96f3ca9ec1dde434da7d2d392b905dd f3d1f9af93d1af5950bd493f5aa731b4"
    "056df31bd267b6b90a079831aaf579be 0a39013137aac6d404f518cfd4684064"
    "7e78bfe706ca4cf5e9c5453e9f7cfd2b 8b4c8d169a44e55c88d4a9a7f9474241"
    "e221af44860018ab0856972e194cd934"
)

comptime SERVER_PAYLOAD = (
    "02000000000600405a020000560303ee fce7f7b37ba1d1632e96677825ddf739"
    "88cfc79825df566dc5430b9a045a1200 130100002e00330024001d00209d3c94"
    "0d89690b84d08a60993c144eca684d10 81287c834d5311bcf32bb9da1a002b00"
    "020304"
)

comptime SERVER_PROTECTED = (
    "cf000000010008f067a5502a4262b500 4075c0d95a482cd0991cd25b0aac406a"
    "5816b6394100f37a1c69797554780bb3 8cc5a99f5ede4cf73c3ec2493a1839b3"
    "dbcba3f6ea46c5b7684df3548e7ddeb9 c3bf9c73cc3f3bded74b562bfb19fb84"
    "022f8ef4cdd93795d77d06edbb7aaf2f 58891850abbdca3d20398c276456cbc4"
    "2158407dd074ee"
)

comptime CHACHA_SECRET = (
    "9ac312a7f877468ebe69422748ad00a15443f18203a07d6060f688f30f21632b"
)


def test_suites() raises:
    assert_true(CipherSuite.AES_256_GCM_SHA384.is_valid())
    assert_false(CipherSuite(0x1304).is_valid())
    assert_false(CipherSuite(0x1300).is_valid())
    assert_equal(CipherSuite.AES_128_GCM_SHA256.key_size(), 16)
    assert_equal(CipherSuite.CHACHA20_POLY1305_SHA256.key_size(), 32)
    assert_equal(CipherSuite.AES_256_GCM_SHA384.hash_size(), 48)
    assert_equal(CipherSuite.AES_128_GCM_SHA256.hash_size(), 32)
    assert_equal(
        String(CipherSuite.AES_128_GCM_SHA256), "TLS_AES_128_GCM_SHA256"
    )
    assert_equal(
        String(CipherSuite.AES_256_GCM_SHA384), "TLS_AES_256_GCM_SHA384"
    )
    assert_equal(
        String(CipherSuite.CHACHA20_POLY1305_SHA256),
        "TLS_CHACHA20_POLY1305_SHA256",
    )
    assert_equal(String(CipherSuite(0x1304)), "CipherSuite(0x1304)")


def test_missing_function() raises:
    var kind = TlsErrorKind.OS
    try:
        _ = crypto_function[Int](OpenSsl(), "EVP_no_such_function")
    except e:
        kind = e.kind
    assert_equal(kind, TlsErrorKind.LIBRARY)


def test_a1_keys() raises:
    """RFC 9001 A.1: the Initial secret, and the client and server keys."""
    var crypto = Crypto(OpenSsl())
    var suite = CipherSuite.AES_128_GCM_SHA256
    var salt = unhex("38762cf7f55934b34d179ae6a4c80cadccbb7f0a")
    var initial = crypto.hkdf_extract(suite, salt, unhex(DCID))
    assert_equal(
        tohex(initial),
        "7db5df06e7a69e432496adedb00851923595221596ae2ae9fb8115c1e9ed0a44",
    )
    var secrets = initial_secrets(crypto, unhex(DCID))
    assert_equal(
        tohex(secrets[0]),
        "c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea",
    )
    assert_equal(
        tohex(secrets[1]),
        "3c199828fd139efd216c155ad844cc81fb82fa8d7446fa7d78be803acdda951b",
    )
    var client = secrets[0].copy()
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, client, "quic key", 16)),
        "1f369613dd76d5467730efcbe3b1a22d",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, client, "quic iv", 12)),
        "fa044b2f42a3fd3b46fb255c",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, client, "quic hp", 16)),
        "9f50449e04a0e810283a1e9933adedd2",
    )
    var server = secrets[1].copy()
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, server, "quic key", 16)),
        "cf3a5331653c364c88f0f379b6067e37",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, server, "quic iv", 12)),
        "0ac1493ca1905853b0bba03e",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, server, "quic hp", 16)),
        "c206b8d9b9f0f37644430b490eeaa314",
    )


def test_a2_client_initial() raises:
    """RFC 9001 A.2: protect the client Initial, then remove the protection
    on the server side."""
    var crypto = Crypto(OpenSsl())
    var keys = initial_keys(crypto, unhex(DCID), False)
    var packet = unhex("c300000001088394c8f03e5157080000449e00000002")
    var header_end = len(packet)
    packet.extend(unhex(CLIENT_CRYPTO))
    while len(packet) < header_end + 1162:
        packet.append(0)
    var plain = List[UInt8](packet[header_end:])
    packet.resize(len(packet) + 16, 0)
    keys.local.packet.seal(
        packet.unsafe_ptr(), 0, header_end, header_end + 1162, 2
    )
    keys.local.header.protect(packet.unsafe_ptr(), 0, 18, 4)
    assert_equal(tohex(packet), tohex(unhex(CLIENT_PROTECTED)))
    var server = initial_keys(crypto, unhex(DCID), True)
    var pn_len = server.remote.header.unprotect(
        packet.unsafe_ptr(), 0, 18, len(packet)
    )
    assert_equal(pn_len, 4)
    assert_equal(packet[0], 0xC3)
    assert_true(
        server.remote.packet.open(packet.unsafe_ptr(), 0, 22, len(packet), 2)
    )
    assert_equal(tohex(packet[22 : 22 + 1162]), tohex(plain))


def test_a3_server_initial() raises:
    """RFC 9001 A.3: protect the server Initial with a 2-byte packet
    number, then open it as the client."""
    var crypto = Crypto(OpenSsl())
    var keys = initial_keys(crypto, unhex(DCID), True)
    var packet = unhex("c1000000010008f067a5502a4262b50040750001")
    var header_end = len(packet)
    packet.extend(unhex(SERVER_PAYLOAD))
    var payload_end = len(packet)
    packet.resize(payload_end + 16, 0)
    keys.local.packet.seal(packet.unsafe_ptr(), 0, header_end, payload_end, 1)
    keys.local.header.protect(packet.unsafe_ptr(), 0, 18, 2)
    assert_equal(tohex(packet), tohex(unhex(SERVER_PROTECTED)))
    var client = initial_keys(crypto, unhex(DCID), False)
    assert_equal(
        client.remote.header.unprotect(packet.unsafe_ptr(), 0, 18, len(packet)),
        2,
    )
    assert_true(
        client.remote.packet.open(packet.unsafe_ptr(), 0, 20, len(packet), 1)
    )
    assert_equal(tohex(packet[20:payload_end]), tohex(unhex(SERVER_PAYLOAD)))


def test_a5_chacha20_short_header() raises:
    """RFC 9001 A.5: a ChaCha20-Poly1305 short header packet, and the
    secret of the next key phase."""
    var crypto = Crypto(OpenSsl())
    var suite = CipherSuite.CHACHA20_POLY1305_SHA256
    var secret = unhex(CHACHA_SECRET)
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, secret, "quic key", 32)),
        "c6d98ff3441c3fe1b2182094f69caa2ed4b716b65488960a7a984979fb23e1c8",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, secret, "quic iv", 12)),
        "e0459b3474bdd0e44a41c144",
    )
    assert_equal(
        tohex(crypto.hkdf_expand_label(suite, secret, "quic hp", 32)),
        "25a282b9e82f06f21f488917a4fc8f1b73573685608597d0efcb076b0ab7a7a4",
    )
    var keys = DirectionalKeys(crypto, suite, secret, True)
    assert_equal(
        tohex(keys.next_secret()),
        "1223504755036d556342ee9361d253421a826c9ecdf3c7148684b36b714881f9",
    )
    var packet = unhex("4200bff4 01")
    packet.resize(len(packet) + 16, 0)
    keys.packet.seal(packet.unsafe_ptr(), 0, 4, 5, 654360564)
    assert_equal(tohex(packet[4:]), "655e5cd55c41f69080575d7999c25a5bfb")
    var mask = keys.header.mask(packet[5:])
    assert_equal(tohex(Span(mask)), "aefefe7d03")
    keys.header.protect(packet.unsafe_ptr(), 0, 1, 3)
    assert_equal(tohex(packet), "4cfe4189655e5cd55c41f69080575d7999c25a5bfb")
    var peer = DirectionalKeys(crypto, suite, secret, False)
    assert_equal(
        peer.header.unprotect(packet.unsafe_ptr(), 0, 1, len(packet)), 3
    )
    assert_equal(tohex(packet[0:4]), "4200bff4")
    assert_true(
        peer.packet.open(packet.unsafe_ptr(), 0, 4, len(packet), 654360564)
    )
    assert_equal(packet[4], 1)


def test_open_failures() raises:
    var crypto = Crypto(OpenSsl())
    var keys = initial_keys(crypto, unhex(DCID), False)
    var peer = initial_keys(crypto, unhex(DCID), True)
    var packet = List[UInt8](length=40, fill=7)
    keys.local.packet.seal(packet.unsafe_ptr(), 0, 4, 24, 9)
    # A packet shorter than a tag, a changed byte, and a wrong number fail.
    assert_false(peer.remote.packet.open(packet.unsafe_ptr(), 0, 30, 40, 9))
    assert_false(peer.remote.packet.open(packet.unsafe_ptr(), 0, 4, 40, 8))
    packet[10] ^= 1
    assert_false(peer.remote.packet.open(packet.unsafe_ptr(), 0, 4, 40, 9))
    # Too few bytes for the sample leave the packet unchanged.
    var before = packet[0]
    assert_equal(
        peer.remote.header.unprotect(packet.unsafe_ptr(), 0, 30, 40), 0
    )
    assert_equal(packet[0], before)


def test_aes_256_and_key_update() raises:
    var crypto = Crypto(OpenSsl())
    var suite = CipherSuite.AES_256_GCM_SHA384
    var secret = List[UInt8](length=48, fill=5)
    var local = DirectionalKeys(crypto, suite, secret, True)
    var remote = DirectionalKeys(crypto, suite, secret, False)
    assert_equal(len(local.next_secret()), 48)
    var packet = List[UInt8](length=64, fill=3)
    packet[0] = 0x43
    local.packet.seal(packet.unsafe_ptr(), 0, 5, 48, 77)
    local.header.protect(packet.unsafe_ptr(), 0, 1, 4)
    assert_equal(remote.header.unprotect(packet.unsafe_ptr(), 0, 1, 64), 4)
    assert_true(remote.packet.open(packet.unsafe_ptr(), 0, 5, 64, 77))
    # After an update on both ends, the new keys work and the old one
    # still opens a late packet of the old phase.
    var late = List[UInt8](length=40, fill=1)
    local.packet.seal(late.unsafe_ptr(), 0, 4, 24, 78)
    var old_local = local.update()
    var old_remote = remote.update()
    assert_true(old_remote.open(late.unsafe_ptr(), 0, 4, 40, 78))
    var fresh = List[UInt8](length=40, fill=1)
    local.packet.seal(fresh.unsafe_ptr(), 0, 4, 24, 79)
    assert_true(remote.packet.open(fresh.unsafe_ptr(), 0, 4, 40, 79))
    assert_true(old_local.encrypt)


def test_header_mask_aes() raises:
    var crypto = Crypto(OpenSsl())
    var key = HeaderKey(
        crypto,
        CipherSuite.AES_128_GCM_SHA256,
        unhex("9f50449e04a0e810283a1e9933adedd2"),
    )
    var mask = key.mask(unhex("d1b1c98dd7689fb8ec11d242b123dc9b"))
    assert_equal(tohex(Span(mask)), "437b9aec36")
    var pkey = PacketKey(
        crypto,
        CipherSuite.AES_128_GCM_SHA256,
        List[UInt8](length=16, fill=0),
        List[UInt8](length=12, fill=0),
        True,
    )
    assert_true(pkey.encrypt)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
