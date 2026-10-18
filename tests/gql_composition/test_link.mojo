# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `src/specifications/link.spec.ts`.

The `parseLinkUrl` table is the upstream table. The other URLs check the
URL parsing; their expected values come from upstream `parseLinkUrl` in
Node.js. The resolved names come from upstream `extractLinkImplementations`
in Node.js. The JSON5 import errors come from upstream `parseLinkImport` in
Node.js. The `@link` validation cases are in `test_link_import.mojo`.
"""

from gql_composition.link import (
    ImportKind,
    LinkImport,
    is_federation_v1,
    link_supports_missing,
    link_supports_version,
    links_from_document,
    parse_link_directive,
    parse_link_import,
    parse_link_url,
    resolve_imported_name,
)
from gql_language.ast import NO_NODE, Role
from gql_language.parser import parse
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _check(url: String, expected: String) raises:
    assert_equal(String(parse_link_url(url)), expected, url)


def test_parse_link_url() raises:
    _check(
        "https://spec.example.com/a/b/mySchema/v1.0/",
        "https://spec.example.com/a/b/mySchema name=mySchema version=v1.0",
    )
    _check(
        "https://spec.example.com/a/b/mySchema/v1.0",
        "https://spec.example.com/a/b/mySchema name=mySchema version=v1.0",
    )
    _check(
        "https://spec.example.com",
        "https://spec.example.com name=null version=null",
    )
    _check(
        "https://spec.example.com/mySchema/v0.1?q=v#frag",
        "https://spec.example.com/mySchema name=mySchema version=v0.1",
    )
    _check(
        "https://spec.example.com/mySchema/not-a-version",
        (
            "https://spec.example.com/mySchema/not-a-version name=not-a-version"
            " version=null"
        ),
    )
    _check(
        "https://spec.example.com/v1.0",
        "https://spec.example.com name=null version=v1.0",
    )
    _check(
        "https://spec.example.com/vX",
        "https://spec.example.com/vX name=vX version=null",
    )
    _check(
        "file:///extensions/permissions",
        "file:///extensions/permissions name=permissions version=null",
    )
    _check(
        "https://specs.apollo.dev/federation/not-a-version",
        (
            "https://specs.apollo.dev/federation/not-a-version"
            " name=not-a-version version=null"
        ),
    )
    _check(
        "https://specs.apollo.dev",
        "https://specs.apollo.dev name=null version=null",
    )
    _check("specs.apollo.dev", "specs.apollo.dev name=null version=null")
    _check(
        "not-valid.apollo.dev/v1",
        "not-valid.apollo.dev/v1 name=null version=null",
    )


def test_parse_link_url_more() raises:
    _check(
        "HTTPS://Spec.Example.COM/A/v1.0",
        "https://spec.example.com/A name=A version=v1.0",
    )
    _check(
        "http://example.com:80/a/v1.0",
        "http://example.com/a name=a version=v1.0",
    )
    _check(
        "http://example.com:8080/a/v1.0",
        "http://example.com:8080/a name=a version=v1.0",
    )
    _check(
        "https://example.com:443/a", "https://example.com/a name=a version=null"
    )
    _check(
        "https://example.com:0443/a",
        "https://example.com/a name=a version=null",
    )
    _check(
        "https://example.com:65535/a",
        "https://example.com:65535/a name=a version=null",
    )
    _check(
        "https://example.com:65536/a",
        "https://example.com:65536/a name=null version=null",
    )
    _check(
        "https://example.com:12a/a",
        "https://example.com:12a/a name=null version=null",
    )
    _check(
        "https://example.com:/a", "https://example.com/a name=a version=null"
    )
    _check("ws://example.com:80/a", "ws://example.com/a name=a version=null")
    _check("wss://example.com:443/a", "wss://example.com/a name=a version=null")
    _check(
        "wss://example.com:444/a", "wss://example.com:444/a name=a version=null"
    )
    _check("ftp://example.com:21/a", "ftp://example.com/a name=a version=null")
    _check(
        "ftp://example.com:22/a", "ftp://example.com:22/a name=a version=null"
    )
    _check(
        "https://user:pass@example.com/a/v2",
        "https://example.com/a name=a version=v2",
    )
    _check(
        "https://user@example.com:81/a",
        "https://example.com:81/a name=a version=null",
    )
    _check(
        "https://example.com/a/./b/../c/v1.0",
        "https://example.com/a/c name=c version=v1.0",
    )
    _check(
        "https://example.com/../../a",
        "https://example.com/a name=a version=null",
    )
    _check(
        "https://example.com/a/%2e%2E/b",
        "https://example.com/b name=b version=null",
    )
    _check(
        'https://example.com/a b/c"d<e>f`g{h}i/v1.0',
        (
            "https://example.com/a%20b/c%22d%3Ce%3Ef%60g%7Bh%7Di"
            " name=c%22d%3Ce%3Ef%60g%7Bh%7Di version=v1.0"
        ),
    )
    _check(
        "https://example.com/café/v1.0",
        "https://example.com/caf%C3%A9 name=caf%C3%A9 version=v1.0",
    )
    _check(
        "https://example.com\\a\\b/v1",
        "https://example.com/a/b name=b version=v1",
    )
    _check(
        "https://example.com/a//b///v1",
        "https://example.com/a/b name=b version=v1",
    )
    _check(
        "https://example.com?x=1", "https://example.com name=null version=null"
    )
    _check(
        "https://example.com#f", "https://example.com name=null version=null"
    )
    _check("https://", "https:// name=null version=null")
    _check("https:///a", "https://a name=null version=null")
    _check("https:", "https: name=null version=null")
    _check("http:example.com/a", "http://example.com/a name=a version=null")
    _check("foo://host/a/v1.0", "null/a name=a version=v1.0")
    _check("foo://host:99/a", "null/a name=a version=null")
    _check("foo:/a/b", "null/a/b name=b version=null")
    _check("foo:bar", "null/bar name=bar version=null")
    _check("mailto:a@b.c", "null/a@b.c name=a@b.c version=null")
    _check("1http://x/a", "1http://x/a name=null version=null")
    _check("a+b-c.d://h/p", "null/p name=p version=null")
    _check(
        "  https://example.com/a  ", "https://example.com/a name=a version=null"
    )
    _check(
        "\thttps://example.com/a\n", "https://example.com/a name=a version=null"
    )
    _check("file://host/a/b", "file:///a/b name=b version=null")
    _check("file:/a/b/v2", "null/a/b name=b version=v2")
    _check("file:a", "file:///a name=a version=null")
    _check("https://example.com/V1", "https://example.com name=null version=V1")
    _check(
        "https://example.com/a/v", "https://example.com/a/v name=v version=null"
    )
    _check("https://a%41/x", "https://aa/x name=x version=null")
    _check("https://a%4/x", "https://a%4/x name=null version=null")
    _check("https://a%G1/x", "https://a%G1/x name=null version=null")
    _check("https://a%4G/x", "https://a%4G/x name=null version=null")
    _check("https://a%2f/x", "https://a%2f/x name=null version=null")
    _check("https://a%01/x", "https://a%01/x name=null version=null")
    _check("https://a%7F/x", "https://a%7F/x name=null version=null")
    _check("https://a%20/x", "https://a%20/x name=null version=null")
    _check("https://a%23/x", "https://a%23/x name=null version=null")
    _check("https://a%3A/x", "https://a%3A/x name=null version=null")
    _check("https://a%3C/x", "https://a%3C/x name=null version=null")
    _check("https://a%3E/x", "https://a%3E/x name=null version=null")
    _check("https://a%3F/x", "https://a%3F/x name=null version=null")
    _check("https://a%40/x", "https://a%40/x name=null version=null")
    _check("https://a%5B/x", "https://a%5B/x name=null version=null")
    _check("https://a%5C/x", "https://a%5C/x name=null version=null")
    _check("https://a%5D/x", "https://a%5D/x name=null version=null")
    _check("https://a%5E/x", "https://a%5E/x name=null version=null")
    _check("https://a%7C/x", "https://a%7C/x name=null version=null")
    _check("https://a%25/x", "https://a%25/x name=null version=null")
    _check("https://a%61%62/x", "https://aab/x name=x version=null")
    _check("https://a:b:80/x", "https://a:b:80/x name=null version=null")
    _check("https://a<b/x", "https://a<b/x name=null version=null")
    _check("https://a^b/x", "https://a^b/x name=null version=null")
    _check("https://a|b/x", "https://a|b/x name=null version=null")
    _check("https://@a/x", "https://a/x name=x version=null")
    _check("https://a@/x", "https://a@/x name=null version=null")
    _check("https://a:/x", "https://a/x name=x version=null")
    _check("https://a:99999/x", "https://a:99999/x name=null version=null")
    _check("https://A.B/x", "https://a.b/x name=x version=null")
    _check(
        "https://example.com/a0001b/v1",
        "https://example.com/a0001b name=a0001b version=v1",
    )
    _check(
        "https://exa mple.com/a",
        "https://exa mple.com/a name=null version=null",
    )
    _check("", " name=null version=null")


def test_import_kind() raises:
    assert_equal(String(ImportKind.of("@key")), "directive")
    assert_equal(String(ImportKind.of("FieldSet")), "type")
    assert_true(ImportKind(1).is_valid())
    assert_false(ImportKind(2).is_valid())
    assert_equal(String(ImportKind(2)), "<invalid>")


def test_link_import_text() raises:
    assert_equal(
        String(LinkImport(ImportKind.DIRECTIVE, "@key", String("@id"))),
        "directive @key as @id",
    )
    assert_equal(
        String(LinkImport(ImportKind.TYPE, "FieldSet", None)), "type FieldSet"
    )


def test_a_link_url_supports_an_equal_or_lower_minor() raises:
    var fed = parse_link_url("https://specs.apollo.dev/federation/v2.3")
    assert_true(fed.supports(2, 0))
    assert_true(fed.supports(2, 3))
    assert_false(fed.supports_version("v2.10"))
    assert_true(fed.supports_version("v2.0"))
    assert_false(fed.supports(2, 4))
    assert_false(fed.supports(1, 0))
    assert_false(fed.supports_version("v1.0"))
    assert_false(fed.supports_missing())
    var zero = parse_link_url("https://spec.example.com/mySchema/v0.1")
    assert_true(zero.supports(0, 1))
    assert_false(zero.supports(0, 0))
    assert_false(zero.supports(0, 2))
    var bare = parse_link_url("https://specs.apollo.dev")
    assert_true(bare.supports_missing())
    assert_true(bare.supports_version("nope"))
    assert_false(fed.supports_version("nope"))
    var older = parse_link_url("https://specs.apollo.dev/federation/v2.0")
    assert_true(fed.supports_link(older))
    var other = parse_link_url("https://example.com/other/v2.0")
    assert_false(fed.supports_link(other))


def test_resolve_imported_name() raises:
    var fed = "https://specs.apollo.dev/federation"
    var links = links_from_document(
        parse(
            "extend schema @link(url:"
            ' "https://specs.apollo.dev/federation/v2.3", as: "fed",'
            ' import: ["@key", { name: "@shareable", as: "@shared" }])'
        )
    )
    assert_equal(resolve_imported_name(links, fed, "@key"), "key")
    assert_equal(resolve_imported_name(links, fed, "@shareable"), "shared")
    assert_equal(resolve_imported_name(links, fed, "@federation"), "fed")
    assert_equal(resolve_imported_name(links, fed, "FieldSet"), "fed__FieldSet")
    assert_equal(resolve_imported_name(links, fed, "@id"), "fed__id")
    assert_false(is_federation_v1(links))
    assert_true(link_supports_version(links, fed, "v2.0"))
    assert_false(link_supports_version(links, fed, "v2.4"))
    assert_false(link_supports_missing(links, fed))
    assert_false(
        link_supports_version(links, "https://example.com/missing", "v1.0")
    )
    var empty = links_from_document(parse("type Query { x: Int }"))
    assert_true(is_federation_v1(empty))
    assert_equal(resolve_imported_name(empty, fed, "@key"), "key")
    assert_equal(resolve_imported_name(empty, fed, "FieldSet"), "FieldSet")
    var core = links_from_document(
        parse(
            "extend schema @core(feature:"
            ' "https://specs.apollo.dev/federation/v2.0")'
        )
    )
    assert_equal(resolve_imported_name(core, fed, "@key"), "federation__key")


def test_parse_link_url_edges() raises:
    _check("https://a%-1/x", "https://a%-1/x name=null version=null")
    _check("https://a%!1/x", "https://a%!1/x name=null version=null")
    _check(
        "https://exa\tmple.com/a", "https://example.com/a name=a version=null"
    )
    _check(
        "https://exa\nmple.com/a", "https://example.com/a name=a version=null"
    )
    _check(
        "https://exa\rmple.com/a", "https://example.com/a name=a version=null"
    )
    _check("h2://x/a", "null/a name=a version=null")
    _check("foo:a", "null/a name=a version=null")
    _check("foo://host", "null name=null version=null")
    _check("foo:/a?x", "null/a name=a version=null")
    _check("file:\\\\host/a/b", "file:///a/b name=b version=null")
    _check("file:ab/c", "file:///ab/c name=c version=null")
    _check("file:/\\h/a", "file:///a name=a version=null")
    _check("file://host", "null name=null version=null")
    _check("file:///a?x", "file:///a name=a version=null")
    _check(
        "https:\\\\example.com/a", "https://example.com/a name=a version=null"
    )
    _check("https://x/a/v1234.5", "https://x/a name=a version=v1234.5")
    _check("https://x/a/V2.3", "https://x/a name=a version=V2.3")


def test_version_matching_edges() raises:
    # Upstream `parseVersion` is `/v(\d{1,3})\.(\d{1,4})/i`.
    assert_true(parse_link_url("https://x/a/V2.3").supports(2, 3))
    var long = parse_link_url("https://x/a/v1234.5")
    assert_false(long.supports(1, 0))
    assert_true(long.supports(-1, -1))
    assert_true(parse_link_url("https://x/a/v1").supports(-1, -1))
    assert_true(parse_link_url("https://x/a/v1x").supports(-1, -1))
    assert_true(parse_link_url("https://x/a/v1.").supports(-1, -1))
    assert_true(parse_link_url("https://x/a/v1.x").supports(-1, -1))
    assert_true(parse_link_url("https://x/a/v2.12345").supports(2, 1234))
    var fed = parse_link_url("https://specs.apollo.dev/federation/v2.3")
    assert_false(fed.supports_version("v.1"))


def test_resolve_imported_name_edges() raises:
    # The expected names are those of upstream `extractLinkImplementations`.
    var bare = links_from_document(
        parse('extend schema @link(url: "https://specs.apollo.dev")')
    )
    assert_equal(
        resolve_imported_name(bare, "https://specs.apollo.dev", "@key"), "key"
    )
    var fed = "https://specs.apollo.dev/federation"
    var defined = links_from_document(
        parse(
            'schema @link(url: "https://specs.apollo.dev/federation/v2.3")'
            " { query: Query }"
        )
    )
    assert_equal(
        resolve_imported_name(defined, fed, "@federation"), "federation"
    )
    assert_equal(resolve_imported_name(defined, fed, "@key"), "federation__key")
    var odd = links_from_document(
        parse(
            'extend schema @link(url: 1) @link(url: "https://a.dev/x/v1.0",'
            " as: 1)"
        )
    )
    assert_equal(len(odd), 1)
    assert_equal(resolve_imported_name(odd, "https://a.dev/x", "T"), "x__T")
    assert_equal(resolve_imported_name(odd, "https://a.dev/x", "@x"), "x")
    var core = links_from_document(
        parse(
            'extend schema @core(other: "x") @core(as: "x", feature:'
            ' "https://a.dev/z/v1.0") @core(feature: 1)'
        )
    )
    assert_equal(len(core), 1)
    assert_equal(core[0].identity, "https://a.dev/z")
    assert_equal(len(links_from_document(parse("schema { query: Query }"))), 0)
    assert_false(link_supports_missing(core, "https://example.com/missing"))


def test_the_first_url_argument_wins() raises:
    # Upstream `parseLinkDirective` finds the first `url` argument.
    var document = parse(
        'extend schema @link(url: "https://a.dev/x/v1.0", url:'
        ' "https://b.dev/y/v1.0")'
    )
    var definition = document.children(document.root, Role.DEFINITION)[0]
    var directive = document.children(definition, Role.DIRECTIVE)[0]
    var link = parse_link_directive(document, directive)
    assert_equal(link.value().identity, "https://a.dev/x")
    # It also finds the first `import` argument that is a list.
    var imports = parse(
        'extend schema @link(url: "https://a.dev/x/v1.0", import: ["@a"],'
        ' import: ["@b"])'
    )
    var schema = imports.children(imports.root, Role.DEFINITION)[0]
    var first = parse_link_directive(
        imports, imports.children(schema, Role.DIRECTIVE)[0]
    )
    assert_equal(len(first.value().imports), 1)
    assert_equal(first.value().imports[0].name, "@a")


def _import_error(value: String) raises -> String:
    """Return the error of `parse_link_import` on an `import` value."""
    var document = parse(
        'extend schema @link(url: "https://a.dev/x/v1.0", import: '
        + value
        + ")"
    )
    var definition = document.children(document.root, Role.DEFINITION)[0]
    var directive = document.children(definition, Role.DIRECTIVE)[0]
    var node = NO_NODE
    var argument = document.first_child(directive)
    while argument != NO_NODE:
        if document.name(argument) == "import":
            node = document.child(argument, Role.VALUE)
        argument = document.next_sibling(argument)
    try:
        _ = parse_link_import(document, node)
    except error:
        return String(error)
    return String("")


def test_parse_link_import_edges() raises:
    # The messages are those of upstream `parseLinkImport` in Node.js.
    assert_equal(
        _import_error("Infinit"),
        (
            "Invalid import binding: Infinit: SyntaxError: JSON5: invalid end"
            " of input at 1:8"
        ),
    )
    assert_equal(
        _import_error("[{ name: 0e5 }]"),
        "Invalid import binding: [{name: 0e5}]: Error: Syntax",
    )
    assert_equal(
        _import_error("[{ name: 0E1 }]"),
        "Invalid import binding: [{name: 0E1}]: Error: Syntax",
    )
    assert_equal(
        _import_error("[{ name: 1.5 }]"),
        (
            "Invalid import binding: [{name: 1.5}]: TypeError:"
            " binding.name.startsWith is not a function"
        ),
    )
    assert_equal(
        _import_error("[{ name: 0.0 }]"),
        "Invalid import binding: [{name: 0.0}]: Error: Syntax",
    )
    assert_equal(
        _import_error("[{ name: NaN }]"),
        "Invalid import binding: [{name: NaN}]: Error: Syntax",
    )
    assert_equal(
        _import_error("[{ name: Infinity }]"),
        (
            "Invalid import binding: [{name: Infinity}]: TypeError:"
            " binding.name.startsWith is not a function"
        ),
    )
    assert_equal(_import_error('[{ name: "@a", as: 0e1 }]'), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
