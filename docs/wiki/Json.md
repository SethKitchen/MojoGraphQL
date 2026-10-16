<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# Json

`gql_json` reads and writes JSON for the other packages: request bodies and variables, execution results, router responses and client caches. The parser is strict RFC 8259. The writer gives the same text as ECMAScript `JSON.stringify`. The package needs only the Mojo standard library.

| Module | Contents |
| --- | --- |
| `gql_json.parser` | `parse`, `parse_bytes`, `DEFAULT_MAX_DEPTH`, `MAX_LENGTH` |
| `gql_json.value` | `JsonDocument`, `JsonNode`, `JsonKind`, `JsonObjectIndex`, `NO_NODE`, string and number helpers |
| `gql_json.writer` | `JsonWriter`, `stringify`, `stringify_bytes`, `write_string`, `MAX_INDENT` |
| `gql_json.number` | `read_float64`, `read_int64`, `IntStatus`, `is_integer_text`, `write_number`, `write_int` |
| `gql_json.error` | `JsonError` |
| `gql_json.scan` | The SIMD finders for white space, string bytes and escapes |
| `gql_json.pow10` | The table of 128-bit powers of ten |

```mojo
from gql_json.parser import parse
from gql_json.writer import stringify

var document = parse('{"data": {"hero": {"name": "R2-D2", "height": 0.96}}}')
var hero = document.get(document.get(document.root, "data"), "hero")
print(document.string_value(document.get(hero, "name")))  # R2-D2
print(stringify(document, hero))  # {"name":"R2-D2","height":0.96}
```

## Parse functions

Each function returns a `JsonDocument` whose root is node 0. Each function raises a `JsonError` when the input is not valid JSON.

| Function | Input |
| --- | --- |
| `parse(text, max_depth=1000, max_length=MAX_LENGTH)` | A `StringSlice`; the parser copies it once |
| `parse_bytes(bytes, max_depth=1000, max_length=MAX_LENGTH)` | A `List[UInt8]`; the document takes the list, and nothing is copied |

The parser accepts exactly the grammar of RFC 8259. Any value can be the top-level value.

- **Refused:** comments, trailing commas, `NaN`, `Infinity`, leading zeros, single quotes, a byte order mark, and escapes that RFC 8259 does not define.
- **UTF-8:** the parser checks each byte of a string. It refuses an invalid sequence, an overlong form, a surrogate, and a code point above U+10FFFF.
- **Depth:** `max_depth` limits the nesting of arrays and objects. The parser keeps a stack of its own, so a deep input cannot overflow the call stack.
- **Length:** `max_length` limits the input, in bytes. A server can use it as a limit on the request body. The largest permitted value is `MAX_LENGTH`, which is 2 GiB less 65 bytes.

The parser has no recursion, and it decodes no string. SIMD finders skip white space and string bytes 32 bytes at a time.

On the benchmark fixtures, `parse` and `stringify` are faster than Node.js, serde_json, astjson and Go `encoding/json`. The [Benchmarks](Benchmarks) page tells how the project measures this.

## JsonError

`JsonError` is the error of the parser and of the readers.

| Field | Contents |
| --- | --- |
| `message: String` | The description, such as `Unexpected character ']'` |
| `offset: Int` | The byte offset of the problem, or `-1` when there is no position |
| `line: Int` | The one-based line of the offset, or `0` |
| `column: Int` | The one-based column of the offset, in code points, or `0` |

A line ends at `\n`, `\r\n` or `\r`. Write the error, such as with `print(error)`, to get the message and the position: `Unexpected character 't' at line 2, column 8 (byte 9)`.

## JsonDocument

A `JsonDocument` holds the bytes of the JSON text and all of its values in one `List[JsonNode]`. A value is an `Int` index into that list. `NO_NODE`, which is `-1`, names no value.

| Field | Contents |
| --- | --- |
| `bytes: List[UInt8]` | The source bytes, then the text that the builder added |
| `nodes: List[JsonNode]` | Every value; a parsed document is in preorder |
| `root: Int` | The root value, or `NO_NODE` for an empty document |

Each `JsonNode` is 28 bytes: `kind`, `flags`, the byte range `start` and `end`, `count`, the key range `key_start` and `key_end`, and the link `next`. A container keeps its first and last child in `start` and `end`. A string keeps its source bytes, and a number keeps its source text. The parser decodes nothing. A reader decodes a string only when a program asks for its value.

`JsonKind` is one of `NULL`, `BOOLEAN`, `NUMBER`, `STRING`, `ARRAY` and `OBJECT`.

### Read values

| Method | Returns |
| --- | --- |
| `kind(node)` | The `JsonKind` of the value |
| `length(node)` | The number of items or members; 0 for a scalar |
| `first(node)`, `next(node)` | The first child or the next sibling, or `NO_NODE` |
| `at(node, index)` | The child at a position, or `NO_NODE` when the position is out of range |
| `children(node)` | All the children, in order |
| `find(node, key)` | The last member of an object with the key, or `NO_NODE` |
| `get(node, key)` | The last member with the key; raises a `JsonError` when there is none |
| `key(node)`, `raw_key(node)` | The decoded key of a member, or its source text |
| `key_equals(node, key)` | Whether the decoded key of a member is the text |
| `text(node)` | The stored text of a scalar: the number text, or the string text without its quotes |
| `string_value(node)` | The decoded value of a string |
| `has_escapes(node)` | Whether a string has escapes, so that `text` and `string_value` differ |
| `bool_value(node)` | Whether the value is `true` |
| `is_integer(node)` | Whether a number has no fraction, as `Number.isInteger`: `1.0` and `1e2` are integers |
| `as_int64(node)` | The exact `Int64` value; raises a `JsonError` for a fraction, an overflow or another kind |
| `as_float64(node)` | The nearest `Float64`, ties to even, as `JSON.parse`; NaN for another kind |

`find` is a linear search. For many lookups in one large object, make a `JsonObjectIndex(document, object)`. Its `find(document, key)` uses a hash table. The index stays valid while the object gets no new member.

### Build values

Each `add_*` method adds a value with no parent and returns its index. Then `append` or `add_member` gives it a parent. A program can add values to a parsed document, too.

| Method | Adds |
| --- | --- |
| `add_null()`, `add_bool(value)` | `null`, `true` or `false` |
| `add_int(value)` | An `Int64`, exactly |
| `add_float(value)` | A `Float64`, in the `JSON.stringify` form; NaN and the infinities become `null` |
| `add_number(text)` | A number from its JSON text, kept exactly; raises a `JsonError` for text that is not a JSON number |
| `add_string(text)` | A string, from its decoded value |
| `add_array()`, `add_object()` | An empty container |
| `append(parent, child)` | Makes a value the last item of an array |
| `add_member(parent, key, child)` | Makes a value the last member of an object |
| `add_copy(other, node)` | A copy of a value of another document, with all of its descendants |

```mojo
from gql_json.value import JsonDocument

var response = JsonDocument()
response.root = response.add_object()
var data = response.add_object()
response.add_member(data, "count", response.add_int(3))
response.add_member(response.root, "data", data)
```

## Write JSON

`stringify(document, node, indent=0)` returns the JSON text of a value. `stringify_bytes` returns the same text as a `List[UInt8]`, ready for a socket. The `indent` is the third argument of `JSON.stringify`: the spaces for each level, from 0 to 10.

`JsonWriter(indent=0, capacity=256)` writes JSON one token at a time. It adds the commas, the colons and, with an indent, the line breaks. It does not check the order of the calls.

| Method | Writes |
| --- | --- |
| `begin_object()`, `end_object()` | `{` and `}` |
| `begin_array()`, `end_array()` | `[` and `]` |
| `key(name)` | A member key and its colon |
| `string(text)`, `int(value)`, `float(value)`, `bool(value)`, `null()` | A scalar |
| `raw(json)` | JSON text that is already complete; the writer does not check it |
| `value(document, node)` | A value of a document, and all that it holds |
| `take_string()`, `take_bytes()` | The text; this ends the writer |
| `clear()` | Removes the text, keeps the buffer, and starts again |

```mojo
from gql_json.writer import JsonWriter

var writer = JsonWriter()
writer.begin_object()
writer.key("errors")
writer.begin_array()
writer.end_array()
writer.end_object()
print(writer^.take_string())  # {"errors":[]}
```

The output is the output of `JSON.stringify`:

- **Strings:** the writer escapes `"` and `\`, and writes `\b`, `\f`, `\n`, `\r` and `\t`. It writes every other control character as `\u00XX`, with lowercase hex. It writes all other code points as UTF-8, U+2028 and U+2029 too.
- **Numbers:** the writer uses the ECMAScript `Number::toString` form. That is the shortest digits that read back as the same `Float64`, and the closest of them. For example, `1e21` becomes `1e+21`, `1e-7` stays `1e-7`, `-0` becomes `0`, and NaN becomes `null`.
- **Parsed numbers:** an integer of at most 15 digits is copied as it is. Every other number is read as a `Float64` and written again, as `JSON.stringify(JSON.parse(text))` does.

## Numbers

The functions of `gql_json.number` work on JSON number text and on `Float64` values.

| Function | Result |
| --- | --- |
| `read_float64(text)` | The nearest `Float64`, ties to even; an infinity when the value is too large |
| `read_int64(text)` | The exact `Int64` value and an `IntStatus`: `OK`, `FRACTION` or `OVERFLOW` |
| `is_integer_text(text)` | Whether the exact value has no fraction |
| `write_number(out, value)` | Appends the `JSON.stringify` text of a `Float64` |
| `write_int(out, value)` | Appends the decimal text of an `Int64` |

`read_float64` uses the method of Clinger for short numbers, and the method of Eisel and Lemire for up to 19 digits. A longer number, or a result that the fast methods cannot decide, takes an exact path with big integers. `write_number` uses the Schubfach method of Giulietti. The two methods use the table in `gql_json.pow10`.

## Differences from JSON.parse and JSON.stringify

- **Duplicate keys.** An object keeps every member, in source order. `find` and `get` return the last member with a key, which is the member that `JSON.parse` keeps. `stringify` writes every member, and `JSON.stringify(JSON.parse(text))` writes only the last one.
- **Key order.** ECMAScript puts the keys that are array indices, such as `"1"`, first in an object. This package keeps the source order.
- **Lone surrogates.** The parser refuses a `\u` escape of a lone surrogate, such as `"\uD800"`. A Mojo string is valid UTF-8, so it cannot hold a lone surrogate. `JSON.parse` accepts it.
- **Bytes.** The input is UTF-8 bytes, and the parser refuses invalid UTF-8. `JSON.parse` reads a JavaScript string.
- **Limits.** `max_depth` and `max_length` limit the input. `JSON.parse` has no limits but its call stack and its memory.
- **Big integers.** `add_int`, `JsonWriter.int` and `as_int64` keep every `Int64` exactly. A JavaScript number keeps an integer exactly only up to 2^53.
- **Exact number text.** A parsed number keeps its source text. `text` returns it, and `as_int64` reads it exactly.
- **Messages.** The error messages are not the V8 messages. A `JsonError` gives the position as fields.

## Tests

The tests are in `tests/gql_json/`. The fixtures and their origins are in `tests/gql_json/fixtures/README.md`.

- **JSONTestSuite.** All 318 parsing files of the JSONTestSuite of Nicolas Seriot (MIT). The parser accepts each `y_` file and refuses each `n_` file. `test_suite.mojo` gives the decision and the reason for each `i_` file.
- **Round trips.** For each `y_` file and each extra corpus file, `stringify` gives the same bytes as Node.js `JSON.stringify(JSON.parse(text))`, compact and with an indent of 2.
- **Numbers.** For more than 2000 values, `write_number` gives the Node.js text, and `read_float64` reads that text back to the same bits.
