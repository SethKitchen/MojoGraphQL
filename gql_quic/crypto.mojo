# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Packet protection (RFC 9001 section 5) with the libcrypto of OpenSSL.

`Crypto` is the table of the libcrypto functions that QUIC needs: AEAD,
header protection and HKDF. It shares the library of a `gql_tls.OpenSsl`.
This module implements no cryptographic primitive: AES-GCM,
ChaCha20-Poly1305, AES-ECB, ChaCha20 and HKDF all run in libcrypto.

- `hkdf_expand_label` is the TLS 1.3 `HKDF-Expand-Label` (RFC 8446
  section 7.1) with an empty context. The module builds the `HkdfLabel`
  bytes, and libcrypto runs HKDF-Expand.
- `PacketKey` seals and opens a packet in place. The nonce is the IV
  XOR the packet number (RFC 9001 section 5.3). The tag is 16 bytes.
- `HeaderKey` makes the 5-byte mask of a 16-byte sample (RFC 9001
  section 5.4), and applies it to a packet or removes it.
- `DirectionalKeys` holds the keys of one direction and the secret for a
  key update. `KeyPair` holds both directions. `initial_keys` derives the
  Initial keys from the Destination Connection ID of the client.

A buffer is a typed `Pointer` and offsets, so that its owner stays alive
for the call. The C calls take the address.

This module ports the structure of quinn-proto 0.11.19 (8192ed3)
quinn-proto/src/crypto.rs (the `PacketKey`, `HeaderKey` and `Keys`
traits) and quinn-proto/src/crypto/rustls.rs (`initial_keys`) (MIT OR
Apache-2.0, used under MIT). The libcrypto API of OpenSSL 3 is
Apache-2.0 licensed; no OpenSSL code is copied.

Differences from upstream: quinn delegates the algorithms to rustls and
ring through traits. Here the keys are concrete types over libcrypto. Only
QUIC version 1 is supported, so there is one Initial salt. The Retry
integrity tag is not computed, because the endpoints neither send nor
accept Retry packets.
"""

from std.memory import ArcPointer, stack_allocation

from gql_tls.error import TlsError, TlsErrorKind
from gql_tls.openssl import CFunction, OpenSsl

comptime TAG_SIZE = 16
"""The size of the AEAD tag of every QUIC cipher suite."""
comptime SAMPLE_SIZE = 16
"""The size of the header protection sample."""
comptime IV_SIZE = 12
"""The size of the AEAD IV and nonce."""

comptime _EVP_PKEY_HKDF: Int32 = 1036
comptime _HKDF_EXTRACT_ONLY: Int32 = 1
comptime _HKDF_EXPAND_ONLY: Int32 = 2
comptime _EVP_CTRL_AEAD_GET_TAG: Int32 = 0x10
comptime _EVP_CTRL_AEAD_SET_TAG: Int32 = 0x11

comptime INITIAL_SALT_V1: Array[UInt8, 20] = [
    0x38,
    0x76,
    0x2C,
    0xF7,
    0xF5,
    0x59,
    0x34,
    0xB3,
    0x4D,
    0x17,
    0x9A,
    0xE6,
    0xA4,
    0xC8,
    0x0C,
    0xAD,
    0xCC,
    0xBB,
    0x7F,
    0x0A,
]
"""The Initial salt of QUIC version 1 (RFC 9001 section 5.2)."""


@fieldwise_init
struct CipherSuite(Equatable, ImplicitlyCopyable, Writable):
    """A TLS 1.3 cipher suite, by its IANA number."""

    var value: UInt16
    """The number; see `is_valid`."""

    comptime AES_128_GCM_SHA256 = CipherSuite(0x1301)
    """`TLS_AES_128_GCM_SHA256`; also the suite of the Initial keys."""
    comptime AES_256_GCM_SHA384 = CipherSuite(0x1302)
    """`TLS_AES_256_GCM_SHA384`."""
    comptime CHACHA20_POLY1305_SHA256 = CipherSuite(0x1303)
    """`TLS_CHACHA20_POLY1305_SHA256`."""

    def is_valid(self) -> Bool:
        """Return True for one of the three QUIC cipher suites.

        Returns:
            Whether the number names a suite.
        """
        return self.value >= 0x1301 and self.value <= 0x1303

    def key_size(self) -> Int:
        """Return the size of the AEAD key and the header key.

        Returns:
            16 for AES-128-GCM, else 32.
        """
        return 16 if self.value == 0x1301 else 32

    def hash_size(self) -> Int:
        """Return the output size of the HKDF hash.

        Returns:
            48 for SHA-384, else 32.
        """
        return 48 if self.value == 0x1302 else 32

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the suite.

        Args:
            writer: The destination.
        """
        if self.value == 0x1301:
            writer.write("TLS_AES_128_GCM_SHA256")
        elif self.value == 0x1302:
            writer.write("TLS_AES_256_GCM_SHA384")
        elif self.value == 0x1303:
            writer.write("TLS_CHACHA20_POLY1305_SHA256")
        else:
            writer.write("CipherSuite(", hex(self.value), ")")


def crypto_function[
    R: RegisterPassable
](openssl: OpenSsl, name: StaticString) raises TlsError -> CFunction[R]:
    """Look up one function of libcrypto.

    The function is valid while a copy of `openssl` lives.

    Parameters:
        R: The return type of the function.

    Args:
        openssl: The loaded library.
        name: The name of the function.

    Returns:
        The function.

    Raises:
        TlsError: `LIBRARY` when libcrypto has no such function.
    """
    var symbol = openssl.crypto_library[].get_symbol[NoneType](String(name))
    if not symbol:
        raise TlsError(
            TlsErrorKind.LIBRARY,
            "the libcrypto library has no function " + String(name),
            0,
        )
    return CFunction[R](
        symbol.value().unsafe_origin_cast[MutUntrackedOrigin](),
        Pointer(to=openssl.crypto_library[]).unsafe_origin_cast[
            MutUntrackedOrigin
        ](),
    )


struct _Table(Movable):
    """The libcrypto functions, and the library that holds them."""

    var openssl: OpenSsl
    var ctx_new: CFunction[Int]
    var ctx_free: CFunction[NoneType]
    var init: CFunction[Int32]
    var update: CFunction[Int32]
    var final: CFunction[Int32]
    var ctrl: CFunction[Int32]
    var padding: CFunction[Int32]
    var aes_128_gcm: Int
    var aes_256_gcm: Int
    var chacha20_poly1305: Int
    var aes_128_ecb: Int
    var aes_256_ecb: Int
    var chacha20: Int
    var sha256: Int
    var sha384: Int
    var pkey_new: CFunction[Int]
    var pkey_free: CFunction[NoneType]
    var derive_init: CFunction[Int32]
    var derive: CFunction[Int32]
    var hkdf_md: CFunction[Int32]
    var hkdf_mode: CFunction[Int32]
    var hkdf_salt: CFunction[Int32]
    var hkdf_key: CFunction[Int32]
    var hkdf_info: CFunction[Int32]

    def __init__(out self, var openssl: OpenSsl) raises TlsError:
        self.ctx_new = crypto_function[Int](openssl, "EVP_CIPHER_CTX_new")
        self.ctx_free = crypto_function[NoneType](
            openssl, "EVP_CIPHER_CTX_free"
        )
        self.init = crypto_function[Int32](openssl, "EVP_CipherInit_ex")
        self.update = crypto_function[Int32](openssl, "EVP_CipherUpdate")
        self.final = crypto_function[Int32](openssl, "EVP_CipherFinal_ex")
        self.ctrl = crypto_function[Int32](openssl, "EVP_CIPHER_CTX_ctrl")
        self.padding = crypto_function[Int32](
            openssl, "EVP_CIPHER_CTX_set_padding"
        )
        self.aes_128_gcm = crypto_function[Int](openssl, "EVP_aes_128_gcm")()
        self.aes_256_gcm = crypto_function[Int](openssl, "EVP_aes_256_gcm")()
        self.chacha20_poly1305 = crypto_function[Int](
            openssl, "EVP_chacha20_poly1305"
        )()
        self.aes_128_ecb = crypto_function[Int](openssl, "EVP_aes_128_ecb")()
        self.aes_256_ecb = crypto_function[Int](openssl, "EVP_aes_256_ecb")()
        self.chacha20 = crypto_function[Int](openssl, "EVP_chacha20")()
        self.sha256 = crypto_function[Int](openssl, "EVP_sha256")()
        self.sha384 = crypto_function[Int](openssl, "EVP_sha384")()
        self.pkey_new = crypto_function[Int](openssl, "EVP_PKEY_CTX_new_id")
        self.pkey_free = crypto_function[NoneType](
            openssl, "EVP_PKEY_CTX_free"
        )
        self.derive_init = crypto_function[Int32](
            openssl, "EVP_PKEY_derive_init"
        )
        self.derive = crypto_function[Int32](openssl, "EVP_PKEY_derive")
        self.hkdf_md = crypto_function[Int32](
            openssl, "EVP_PKEY_CTX_set_hkdf_md"
        )
        self.hkdf_mode = crypto_function[Int32](
            openssl, "EVP_PKEY_CTX_set_hkdf_mode"
        )
        self.hkdf_salt = crypto_function[Int32](
            openssl, "EVP_PKEY_CTX_set1_hkdf_salt"
        )
        self.hkdf_key = crypto_function[Int32](
            openssl, "EVP_PKEY_CTX_set1_hkdf_key"
        )
        self.hkdf_info = crypto_function[Int32](
            openssl, "EVP_PKEY_CTX_add1_hkdf_info"
        )
        self.openssl = openssl^


struct Crypto(ImplicitlyCopyable, Movable):
    """The libcrypto functions of QUIC. Copies share one table."""

    var table: ArcPointer[_Table]
    """The functions, and the library that holds them."""

    def __init__(out self, var openssl: OpenSsl) raises TlsError:
        """Look up the functions in the libcrypto of a loaded OpenSSL.

        Args:
            openssl: The library.

        Raises:
            TlsError: `LIBRARY` when a function is missing.
        """
        self.table = ArcPointer(_Table(openssl^))

    def _digest(self, suite: CipherSuite) -> Int:
        """Return the `EVP_MD` of the HKDF of a suite."""
        if suite == CipherSuite.AES_256_GCM_SHA384:
            return self.table[].sha384
        return self.table[].sha256

    def hkdf_extract(
        self, suite: CipherSuite, salt: Span[UInt8, _], ikm: Span[UInt8, _]
    ) -> List[UInt8]:
        """Run HKDF-Extract (RFC 5869 section 2.2).

        Args:
            suite: The suite whose hash to use.
            salt: The salt.
            ikm: The input keying material.

        Returns:
            The pseudorandom key, of the size of the hash.
        """
        ref t = self.table[]
        var size = suite.hash_size()
        var out = List[UInt8](length=size, fill=0)
        var pctx = t.pkey_new(_EVP_PKEY_HKDF, 0)
        _ = t.derive_init(pctx)
        _ = t.hkdf_md(pctx, self._digest(suite))
        _ = t.hkdf_mode(pctx, _HKDF_EXTRACT_ONLY)
        _ = t.hkdf_salt(pctx, Int(salt.unsafe_ptr()), Int32(len(salt)))
        _ = t.hkdf_key(pctx, Int(ikm.unsafe_ptr()), Int32(len(ikm)))
        var out_size = stack_allocation[1, Int]()
        out_size[unsafe_offset=0] = size
        _ = t.derive(pctx, Int(out.unsafe_ptr()), Int(out_size))
        t.pkey_free(pctx)
        return out^

    def hkdf_expand_label(
        self,
        suite: CipherSuite,
        secret: Span[UInt8, _],
        label: StringSlice,
        size: Int,
    ) -> List[UInt8]:
        """Run HKDF-Expand-Label of TLS 1.3 with an empty context.

        Args:
            suite: The suite whose hash to use.
            secret: The secret.
            label: The label without the `tls13 ` prefix, such as
                `quic key`.
            size: The size of the output, at most 255 times the hash size.

        Returns:
            The output keying material.
        """
        var info = List[UInt8](capacity=10 + label.byte_length())
        info.append(UInt8(size >> 8))
        info.append(UInt8(size & 0xFF))
        info.append(UInt8(6 + label.byte_length()))
        info.extend("tls13 ".as_bytes())
        info.extend(label.as_bytes())
        info.append(0)
        ref t = self.table[]
        var out = List[UInt8](length=size, fill=0)
        var pctx = t.pkey_new(_EVP_PKEY_HKDF, 0)
        _ = t.derive_init(pctx)
        _ = t.hkdf_md(pctx, self._digest(suite))
        _ = t.hkdf_mode(pctx, _HKDF_EXPAND_ONLY)
        _ = t.hkdf_key(pctx, Int(secret.unsafe_ptr()), Int32(len(secret)))
        _ = t.hkdf_info(pctx, info.unsafe_ptr(), Int32(len(info)))
        var out_size = stack_allocation[1, Int]()
        out_size[unsafe_offset=0] = size
        _ = t.derive(pctx, Int(out.unsafe_ptr()), Int(out_size))
        t.pkey_free(pctx)
        return out^


struct PacketKey(Movable):
    """An AEAD key and IV of one direction: it seals or it opens."""

    var crypto: Crypto
    """The functions."""
    var suite: CipherSuite
    """The cipher suite."""
    var encrypt: Bool
    """True for a sealing key."""
    var ctx: Int
    """The `EVP_CIPHER_CTX *`, keyed once."""
    var iv: Array[UInt8, IV_SIZE]
    """The IV, which the packet number turns into the nonce."""

    def __init__(
        out self,
        crypto: Crypto,
        suite: CipherSuite,
        key: Span[UInt8, _],
        iv: Span[UInt8, _],
        encrypt: Bool,
    ):
        """Make a key.

        Args:
            crypto: The functions.
            suite: The cipher suite; it sets the AEAD.
            key: The key, of `suite.key_size()` bytes.
            iv: The IV, of 12 bytes.
            encrypt: True to seal, False to open.
        """
        self.crypto = crypto
        self.suite = suite
        self.encrypt = encrypt
        self.iv = Array[UInt8, IV_SIZE](fill=0)
        for index in range(IV_SIZE):
            self.iv[index] = iv[index]
        ref t = self.crypto.table[]
        var cipher = t.chacha20_poly1305
        if suite == CipherSuite.AES_128_GCM_SHA256:
            cipher = t.aes_128_gcm
        elif suite == CipherSuite.AES_256_GCM_SHA384:
            cipher = t.aes_256_gcm
        self.ctx = t.ctx_new()
        _ = t.init(
            self.ctx, cipher, 0, Int(key.unsafe_ptr()), 0, Int32(Int(encrypt))
        )

    def __deinit__(deinit self):
        """Free the cipher context."""
        self.crypto.table[].ctx_free(self.ctx)

    @always_inline
    def _start(self, pn: UInt64):
        """Set the nonce of a packet number (RFC 9001 section 5.3)."""
        var nonce = stack_allocation[IV_SIZE, UInt8]()
        for index in range(IV_SIZE):
            nonce[unsafe_offset=index] = self.iv[index]
        for index in range(8):
            nonce[unsafe_offset=IV_SIZE - 1 - index] ^= UInt8(
                (pn >> UInt64(8 * index)) & 0xFF
            )
        _ = self.crypto.table[].init(self.ctx, 0, 0, 0, Int(nonce), Int32(-1))

    def seal(
        self,
        data: Pointer[UInt8, _],
        start: Int,
        header_end: Int,
        payload_end: Int,
        pn: UInt64,
    ):
        """Encrypt a payload in place, and write the tag after it.

        Args:
            data: The buffer of the datagram.
            start: The offset of the first byte of the packet.
            header_end: The offset after the packet number; the header is
                the associated data.
            payload_end: The offset after the payload. The 16-byte tag
                goes there, so the buffer must have room for it.
            pn: The full packet number.
        """
        ref t = self.crypto.table[]
        var base = Int(data)
        var size = stack_allocation[1, Int32]()
        self._start(pn)
        _ = t.update(self.ctx, 0, Int(size), base + start, Int32(header_end - start))
        _ = t.update(
            self.ctx,
            base + header_end,
            Int(size),
            base + header_end,
            Int32(payload_end - header_end),
        )
        _ = t.final(self.ctx, base + payload_end, Int(size))
        _ = t.ctrl(
            self.ctx, _EVP_CTRL_AEAD_GET_TAG, Int32(TAG_SIZE), base + payload_end
        )

    def open(
        self,
        data: Pointer[UInt8, _],
        start: Int,
        header_end: Int,
        end: Int,
        pn: UInt64,
    ) -> Bool:
        """Decrypt a payload in place and check its tag.

        Args:
            data: The buffer of the datagram.
            start: The offset of the first byte of the packet.
            header_end: The offset after the packet number.
            end: The offset after the tag.
            pn: The full packet number.

        Returns:
            True when the tag is valid; the plaintext then lies between
            `header_end` and `end - 16`.
        """
        if end - header_end < TAG_SIZE:
            return False
        ref t = self.crypto.table[]
        var base = Int(data)
        var size = stack_allocation[1, Int32]()
        var payload_end = end - TAG_SIZE
        self._start(pn)
        _ = t.ctrl(
            self.ctx, _EVP_CTRL_AEAD_SET_TAG, Int32(TAG_SIZE), base + payload_end
        )
        _ = t.update(self.ctx, 0, Int(size), base + start, Int32(header_end - start))
        _ = t.update(
            self.ctx,
            base + header_end,
            Int(size),
            base + header_end,
            Int32(payload_end - header_end),
        )
        return t.final(self.ctx, base + payload_end, Int(size)) == 1


struct HeaderKey(Movable):
    """A header protection key (RFC 9001 section 5.4)."""

    var crypto: Crypto
    """The functions."""
    var chacha: Bool
    """True for ChaCha20, False for AES-ECB."""
    var ctx: Int
    """The `EVP_CIPHER_CTX *`, keyed once."""

    def __init__(out self, crypto: Crypto, suite: CipherSuite, key: Span[UInt8, _]):
        """Make a key.

        Args:
            crypto: The functions.
            suite: The cipher suite; it sets the cipher.
            key: The header protection key, of `suite.key_size()` bytes.
        """
        self.crypto = crypto
        self.chacha = suite == CipherSuite.CHACHA20_POLY1305_SHA256
        ref t = self.crypto.table[]
        var cipher = t.chacha20
        if suite == CipherSuite.AES_128_GCM_SHA256:
            cipher = t.aes_128_ecb
        elif suite == CipherSuite.AES_256_GCM_SHA384:
            cipher = t.aes_256_ecb
        self.ctx = t.ctx_new()
        _ = t.init(self.ctx, cipher, 0, Int(key.unsafe_ptr()), 0, Int32(1))
        _ = t.padding(self.ctx, 0)

    def __deinit__(deinit self):
        """Free the cipher context."""
        self.crypto.table[].ctx_free(self.ctx)

    @always_inline
    def _mask(self, sample: Int, dest: Int):
        """Write the mask of a sample: 16 bytes, of which 5 are used."""
        ref t = self.crypto.table[]
        var size = stack_allocation[1, Int32]()
        if self.chacha:
            # The sample is the counter and the nonce of ChaCha20; the mask
            # is the key stream over five zero bytes.
            var zeros = stack_allocation[8, UInt8]()
            for index in range(8):
                zeros[unsafe_offset=index] = 0
            _ = t.init(self.ctx, 0, 0, 0, sample, Int32(1))
            _ = t.update(self.ctx, dest, Int(size), Int(zeros), Int32(5))
        else:
            _ = t.update(
                self.ctx, dest, Int(size), sample, Int32(SAMPLE_SIZE)
            )

    def mask(self, sample: Span[UInt8, _]) -> Array[UInt8, 5]:
        """Return the mask of a 16-byte sample.

        Args:
            sample: The sample, of at least 16 bytes.

        Returns:
            The 5 bytes of the mask.
        """
        var out = stack_allocation[SAMPLE_SIZE, UInt8]()
        self._mask(Int(sample.unsafe_ptr()), Int(out))
        var mask = Array[UInt8, 5](fill=0)
        for index in range(5):
            mask[index] = out[unsafe_offset=index]
        return mask^

    def protect(
        self, data: Pointer[UInt8, _], start: Int, pn_offset: Int, pn_len: Int
    ):
        """Apply header protection to a sealed packet in place.

        Args:
            data: The buffer of the datagram.
            start: The offset of the first byte of the packet.
            pn_offset: The offset of the packet number; the sample starts
                4 bytes after it.
            pn_len: The size of the packet number, 1 to 4.
        """
        var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data))
        var out = stack_allocation[SAMPLE_SIZE, UInt8]()
        self._mask(Int(data) + pn_offset + 4, Int(out))
        var bits = UInt8(0x0F) if p[unsafe_offset=start] & 0x80 != 0 else 0x1F
        p[unsafe_offset=start] ^= out[unsafe_offset=0] & bits
        for index in range(pn_len):
            p[unsafe_offset=pn_offset + index] ^= out[unsafe_offset=1 + index]

    def unprotect(
        self, data: Pointer[UInt8, _], start: Int, pn_offset: Int, end: Int
    ) -> Int:
        """Remove header protection from a packet in place.

        Args:
            data: The buffer of the datagram.
            start: The offset of the first byte of the packet.
            pn_offset: The offset of the packet number.
            end: The offset after the packet.

        Returns:
            The size of the packet number, 1 to 4; 0 when the packet is too
            short for a sample, and then nothing changed.
        """
        if pn_offset + 4 + SAMPLE_SIZE > end:
            return 0
        var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data))
        var out = stack_allocation[SAMPLE_SIZE, UInt8]()
        self._mask(Int(data) + pn_offset + 4, Int(out))
        var bits = UInt8(0x0F) if p[unsafe_offset=start] & 0x80 != 0 else 0x1F
        p[unsafe_offset=start] ^= out[unsafe_offset=0] & bits
        var pn_len = Int(p[unsafe_offset=start] & 0x03) + 1
        for index in range(pn_len):
            p[unsafe_offset=pn_offset + index] ^= out[unsafe_offset=1 + index]
        return pn_len


struct DirectionalKeys(Movable):
    """The keys of one direction of one packet number space."""

    var suite: CipherSuite
    """The cipher suite."""
    var secret: List[UInt8]
    """The traffic secret of the current key phase."""
    var packet: PacketKey
    """The AEAD key of the current key phase."""
    var header: HeaderKey
    """The header protection key; a key update keeps it."""

    def __init__(
        out self,
        crypto: Crypto,
        suite: CipherSuite,
        secret: Span[UInt8, _],
        encrypt: Bool,
    ):
        """Derive the keys of a traffic secret (RFC 9001 section 5.1).

        Args:
            crypto: The functions.
            suite: The cipher suite.
            secret: The traffic secret, from TLS or `initial_keys`.
            encrypt: True for the keys that seal.
        """
        self.suite = suite
        self.secret = List[UInt8](secret)
        var key = crypto.hkdf_expand_label(
            suite, secret, "quic key", suite.key_size()
        )
        var iv = crypto.hkdf_expand_label(suite, secret, "quic iv", IV_SIZE)
        var hp = crypto.hkdf_expand_label(
            suite, secret, "quic hp", suite.key_size()
        )
        self.packet = PacketKey(crypto, suite, key, iv, encrypt)
        self.header = HeaderKey(crypto, suite, hp)

    def next_secret(self) -> List[UInt8]:
        """Return the secret of the next key phase (RFC 9001 section 6.1).

        Returns:
            `HKDF-Expand-Label(secret, "quic ku", "", hash size)`.
        """
        return self.packet.crypto.hkdf_expand_label(
            self.suite, self.secret, "quic ku", self.suite.hash_size()
        )

    def next_packet_key(self, secret: Span[UInt8, _]) -> PacketKey:
        """Derive the AEAD key of the next key phase.

        Args:
            secret: The secret from `next_secret`.

        Returns:
            The key, which seals when this one does.
        """
        ref crypto = self.packet.crypto
        var key = crypto.hkdf_expand_label(
            self.suite, secret, "quic key", self.suite.key_size()
        )
        var iv = crypto.hkdf_expand_label(self.suite, secret, "quic iv", IV_SIZE)
        return PacketKey(crypto, self.suite, key, iv, self.packet.encrypt)

    def update(mut self) -> PacketKey:
        """Move to the next key phase, and return the key of the old one.

        Returns:
            The AEAD key of the phase that ends, for late packets.
        """
        var secret = self.next_secret()
        var key = self.next_packet_key(secret)
        self.secret = secret^
        swap(self.packet, key)
        return key^


struct KeyPair(Movable):
    """The keys of both directions of one packet number space."""

    var local: DirectionalKeys
    """The keys that seal what this end sends."""
    var remote: DirectionalKeys
    """The keys that open what the peer sends."""

    def __init__(out self, var local: DirectionalKeys, var remote: DirectionalKeys):
        """Pair two sets of keys.

        Args:
            local: The keys that seal.
            remote: The keys that open.
        """
        self.local = local^
        self.remote = remote^


def initial_secrets(
    crypto: Crypto, dcid: Span[UInt8, _]
) -> Tuple[List[UInt8], List[UInt8]]:
    """Derive the Initial secrets of a connection (RFC 9001 section 5.2).

    Args:
        crypto: The functions.
        dcid: The Destination Connection ID of the first Initial packet of
            the client.

    Returns:
        The client secret and the server secret.
    """
    var suite = CipherSuite.AES_128_GCM_SHA256
    var salt = materialize[INITIAL_SALT_V1]()
    var initial = crypto.hkdf_extract(
        suite, Span(unsafe_ptr=salt.unsafe_ptr(), length=20), dcid
    )
    var client = crypto.hkdf_expand_label(suite, initial, "client in", 32)
    var server = crypto.hkdf_expand_label(suite, initial, "server in", 32)
    return (client^, server^)


def initial_keys(crypto: Crypto, dcid: Span[UInt8, _], is_server: Bool) -> KeyPair:
    """Derive the Initial keys of one end of a connection.

    Args:
        crypto: The functions.
        dcid: The Destination Connection ID of the first Initial packet of
            the client.
        is_server: True for the keys of the server.

    Returns:
        The keys; the server seals with the server secret.
    """
    var secrets = initial_secrets(crypto, dcid)
    var suite = CipherSuite.AES_128_GCM_SHA256
    var client = DirectionalKeys(crypto, suite, secrets[0], not is_server)
    var server = DirectionalKeys(crypto, suite, secrets[1], is_server)
    if is_server:
        return KeyPair(server^, client^)
    return KeyPair(client^, server^)
