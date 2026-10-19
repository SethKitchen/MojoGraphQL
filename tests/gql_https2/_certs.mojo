# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Test certificates: a self-signed certificate for `localhost`.

`test_certs` makes a fresh one with the `openssl` command when it is on
`PATH`. Otherwise it writes the fixture below, which is valid until 2126.
Both have the names `localhost` and `127.0.0.1`.
"""

from std.os import getenv, makedirs
from std.os.path import exists
from std.subprocess import run

from gql_http.socket import Sys

comptime FIXTURE_CERT = """-----BEGIN CERTIFICATE-----
MIIBmzCCAUGgAwIBAgIUF05ayQv+z0teaxp6STWbbZ2pesIwCgYIKoZIzj0EAwIw
FDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MTAxODE0NDY1M1oYDzIxMjYwOTI0
MTQ0NjUzWjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggqhkjO
PQMBBwNCAAQXHeqc3jrGNEaCF+t2dBDBOhzQDDmr/WQEk8wFya8KP7VNZ8P5/hqa
XbGSLk4DjRW8znISgS1nbEeEBlu/oho5o28wbTAdBgNVHQ4EFgQUlJr+fBK6+LLw
D8Q5HLZjSet+GxIwHwYDVR0jBBgwFoAUlJr+fBK6+LLwD8Q5HLZjSet+GxIwDwYD
VR0TAQH/BAUwAwEB/zAaBgNVHREEEzARgglsb2NhbGhvc3SHBH8AAAEwCgYIKoZI
zj0EAwIDSAAwRQIhAPDvYgIrlQwpdlTxeD9QUmlIoDIJPfEYjIHfT72GY/OaAiAW
+zFJMI/QSyzPTEXhKnepBwnMrcnYWXIOZtDOJv2zrw==
-----END CERTIFICATE-----
"""
"""A self-signed P-256 certificate for `localhost`, valid until 2126."""

comptime FIXTURE_KEY = """-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg/Z6e5qhkjN1Xdkfo
7d9pbKK51jOKZPDU5b+fUjaCQAChRANCAAQXHeqc3jrGNEaCF+t2dBDBOhzQDDmr
/WQEk8wFya8KP7VNZ8P5/hqaXbGSLk4DjRW8znISgS1nbEeEBlu/oho5
-----END PRIVATE KEY-----
"""
"""The private key of `FIXTURE_CERT`. It protects nothing: tests only."""


@fieldwise_init
struct Certs(Copyable, Movable):
    """The files of a test certificate."""

    var cert: String
    var key: String
    var generated: Bool


def test_certs() raises -> Certs:
    """Make a certificate and a key in a directory of this process."""
    var sys = Sys()
    var directory = (
        getenv("TMPDIR", "/tmp") + "/gql_tls_test_" + String(sys.pid())
    )
    if not exists(directory):
        makedirs(directory)
    var cert = directory + "/cert.pem"
    var key = directory + "/key.pem"
    if exists(cert) and exists(key):
        return Certs(cert, key, False)
    var out = run(
        "openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1"
        " -nodes -keyout "
        + key
        + " -out "
        + cert
        + " -days 2 -subj /CN=localhost"
        " -addext subjectAltName=DNS:localhost,IP:127.0.0.1"
        " > /dev/null 2>&1 && echo made"
    )
    if out.startswith("made"):
        return Certs(cert, key, True)
    with open(cert, "w") as file:
        file.write(FIXTURE_CERT)
    with open(key, "w") as file:
        file.write(FIXTURE_KEY)
    return Certs(cert, key, False)
