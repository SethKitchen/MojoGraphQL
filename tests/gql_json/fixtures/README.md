# gql_json test fixtures

The `gql_json` tests read these files. Do not edit a file by hand: the tests compare the Mojo output with these bytes. `.gitattributes` keeps every byte unchanged, line endings too.

## `test_parsing/`: the JSONTestSuite

`test_parsing/` is a byte-for-byte copy of the `y_`, `n_` and `i_` files of the `test_parsing/` directory of the JSONTestSuite.

| Item | Value |
|---|---|
| Project | JSONTestSuite, by Nicolas Seriot |
| Source | <https://github.com/nst/JSONTestSuite> |
| Revision | `1ef36fa01286573e846ac449e8683f8833c5b26a` (2024-11-22) |
| License | MIT; the text is in `test_parsing/LICENSE` |

- A `y_` file is valid JSON. The parser must accept it.
- An `n_` file is not valid JSON. The parser must refuse it.
- An `i_` file is a choice that RFC 8259 gives to the parser. `test_suite.mojo` lists the choice of `gql_json` for each file and gives the reasons.

## `roundtrip/`: more inputs

The files in `roundtrip/` are MojoGraphQL files under the license of this repository. They add escapes, numbers, white space, nesting and top-level scalars that the `y_` files do not have. `small-response.json` and `variables.json` are copies of the files of the same name in `bench/fixtures/`.

## `expected/`, `expected-pretty/` and `numbers.txt`: the Node.js outputs

Node.js 22.14.0 wrote these files once, with `bench/baselines/js-json/make-fixtures.mjs`:

```sh
~/node/bin/node bench/baselines/js-json/make-fixtures.mjs tests/gql_json/fixtures
```

- `expected/<name>` is `JSON.stringify(JSON.parse(text))` for each `y_` file and each `roundtrip/` file.
- `expected-pretty/<name>` is `JSON.stringify(JSON.parse(text), null, 2)` for the same files.
- `numbers.txt` has one line for each `Float64` value: the 16 hex digits of its bits, a space, then `JSON.stringify(value)`. The values are edge cases, then a seeded random sample of 2000 values. The sample is small because `make coverage` runs it too; an offline check compared more than 4 million values with Node.js.

The script also writes `roundtrip/strings.json` and `roundtrip/nesting.json`. If you change the script, run it again and commit all of its outputs together.
