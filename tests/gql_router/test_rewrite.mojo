# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Tests for fetch rewrites on a JSON response.

The cases follow `FetchRewriteExt::rewrite` in Hive Router.
"""

from gql_json.value import JsonDocument
from gql_json.writer import stringify
from gql_router.ast import NONE
from gql_router.fetch_step import FetchNodePathSegment, FetchRewrite
from gql_router.rewrite import PossibleTypes, apply_fetch_rewrite
from gql_router.store import Store
from std.testing import TestSuite, assert_equal


def _empty() -> PossibleTypes:
    return PossibleTypes(List[String](), List[List[String]]())


def _key(mut store: Store, name: String) -> FetchNodePathSegment:
    return FetchNodePathSegment(True, store.sym(name), NONE)


def _types(mut store: Store, name: String) -> FetchNodePathSegment:
    var names = List[Int]()
    names.append(store.sym(name))
    return FetchNodePathSegment(False, NONE, store.type_set(names^))


def _rename(
    mut store: Store, var path: List[FetchNodePathSegment], target: String
) -> FetchRewrite:
    return FetchRewrite(False, path^, store.sym(target))


def _set(
    mut store: Store, var path: List[FetchNodePathSegment], value: String
) -> FetchRewrite:
    return FetchRewrite(True, path^, store.sym(value))


def test_a_key_renamer_changes_the_field_name() raises:
    var store = Store()
    var doc = JsonDocument()
    var root = doc.add_object()
    doc.root = root
    doc.add_member(root, "name", doc.add_string("Ada"))
    var path = List[FetchNodePathSegment]()
    path.append(_key(store, "name"))
    var rewrite = _rename(store, path^, "title")
    apply_fetch_rewrite(store, rewrite, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"title":"Ada"}')
    var same = List[FetchNodePathSegment]()
    same.append(_key(store, "title"))
    var keep = _rename(store, same^, "title")
    apply_fetch_rewrite(store, keep, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"title":"Ada"}')


def test_a_rename_walks_arrays_and_nested_fields() raises:
    var store = Store()
    var doc = JsonDocument()
    var root = doc.add_object()
    doc.root = root
    var pets = doc.add_array()
    doc.add_member(root, "pets", pets)
    var first = doc.add_object()
    doc.append(pets, first)
    var pet = doc.add_object()
    doc.add_member(first, "pet", pet)
    doc.add_member(pet, "name", doc.add_string("Ada"))
    var path = List[FetchNodePathSegment]()
    path.append(_key(store, "pets"))
    path.append(_key(store, "pet"))
    path.append(_key(store, "name"))
    var rewrite = _rename(store, path^, "title")
    apply_fetch_rewrite(store, rewrite, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"pets":[{"pet":{"title":"Ada"}}]}')
    var missing = List[FetchNodePathSegment]()
    missing.append(_key(store, "nope"))
    var skip = _rename(store, missing^, "other")
    apply_fetch_rewrite(store, skip, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"pets":[{"pet":{"title":"Ada"}}]}')


def test_a_value_setter_replaces_the_value_at_the_path() raises:
    var store = Store()
    var doc = JsonDocument()
    var root = doc.add_object()
    doc.root = root
    doc.add_member(root, "name", doc.add_string("Ada"))
    var path = List[FetchNodePathSegment]()
    path.append(_key(store, "name"))
    var rewrite = _set(store, path^, "Bea")
    apply_fetch_rewrite(store, rewrite, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"name":"Bea"}')
    var whole = _set(store, List[FetchNodePathSegment](), "Done")
    apply_fetch_rewrite(store, whole, doc, root, _empty())
    assert_equal(stringify(doc, root), '"Done"')


def test_a_type_condition_uses_typename_and_possible_types() raises:
    var store = Store()
    var doc = JsonDocument()
    var root = doc.add_object()
    doc.root = root
    doc.add_member(root, "__typename", doc.add_string("Book"))
    doc.add_member(root, "name", doc.add_string("Ada"))
    var path = List[FetchNodePathSegment]()
    path.append(_types(store, "Book"))
    path.append(_key(store, "name"))
    var rewrite = _rename(store, path^, "title")
    apply_fetch_rewrite(store, rewrite, doc, root, _empty())
    assert_equal(stringify(doc, root), '{"__typename":"Book","title":"Ada"}')
    var author = JsonDocument()
    var other = author.add_object()
    author.root = other
    author.add_member(other, "__typename", author.add_string("Author"))
    author.add_member(other, "name", author.add_string("Ada"))
    var blocked = List[FetchNodePathSegment]()
    blocked.append(_types(store, "Book"))
    blocked.append(_key(store, "name"))
    var skip = _rename(store, blocked^, "title")
    apply_fetch_rewrite(store, skip, author, other, _empty())
    assert_equal(
        stringify(author, other), '{"__typename":"Author","name":"Ada"}'
    )
    var bare = JsonDocument()
    var plain = bare.add_object()
    bare.root = plain
    bare.add_member(plain, "name", bare.add_string("Ada"))
    var open = List[FetchNodePathSegment]()
    open.append(_types(store, "Book"))
    open.append(_key(store, "name"))
    var still = _rename(store, open^, "title")
    apply_fetch_rewrite(store, still, bare, plain, _empty())
    assert_equal(stringify(bare, plain), '{"title":"Ada"}')
    var names = List[String]()
    names.append("Product")
    var members = List[List[String]]()
    var books = List[String]()
    books.append("Book")
    members.append(books^)
    var possible = PossibleTypes(names^, members^)
    var iface = JsonDocument()
    var book = iface.add_object()
    iface.root = book
    iface.add_member(book, "__typename", iface.add_string("Book"))
    iface.add_member(book, "name", iface.add_string("Ada"))
    var through = List[FetchNodePathSegment]()
    through.append(_types(store, "Product"))
    through.append(_key(store, "name"))
    var wide = _rename(store, through^, "title")
    apply_fetch_rewrite(store, wide, iface, book, possible^)
    assert_equal(stringify(iface, book), '{"__typename":"Book","title":"Ada"}')


def test_a_scalar_and_an_empty_renamer_path_stay() raises:
    var store = Store()
    var doc = JsonDocument()
    var root = doc.add_string("Ada")
    doc.root = root
    var path = List[FetchNodePathSegment]()
    path.append(_key(store, "name"))
    var rewrite = _rename(store, path^, "title")
    apply_fetch_rewrite(store, rewrite, doc, root, _empty())
    assert_equal(stringify(doc, root), '"Ada"')
    var number = JsonDocument()
    var box = number.add_object()
    number.root = box
    number.add_member(box, "__typename", number.add_int(1))
    number.add_member(box, "name", number.add_string("Ada"))
    var typed = List[FetchNodePathSegment]()
    typed.append(_types(store, "Book"))
    typed.append(_key(store, "name"))
    var loose = _rename(store, typed^, "title")
    apply_fetch_rewrite(store, loose, number, box, _empty())
    assert_equal(stringify(number, box), '{"__typename":1,"title":"Ada"}')
    var empty = _rename(store, List[FetchNodePathSegment](), "title")
    apply_fetch_rewrite(store, empty, number, box, _empty())
    assert_equal(stringify(number, box), '{"__typename":1,"title":"Ada"}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
