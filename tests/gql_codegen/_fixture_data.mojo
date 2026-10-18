# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The files of `fixtures/`, written by `_embed.mojo`. Do not edit."""


def _path_0() -> String:
    var out = String()
    out += "antlr_tokens/TestOperation.graphql"
    return out^


def _file_0() -> String:
    var out = String()
    out += "# A query that contains fields named as GraphQL keywords as "
    out += "well as a multiline string to make sure the parser\n# handle"
    out += 's them correctly\n"""\nThe test query.\n"""\nquery Tes'
    out += 'tQuery(\n  """\n  The operation to perform.\n  """\n  '
    out += "$operation: String\n) {\n  typeWithGraphQLKeywords {\n    on"
    out += "\n    null(fragment: $operation)\n    alias: null(fragment: "
    out += '"""A string\nwith a new line\n""")\n  }\n}\n'
    return out^


def _path_1() -> String:
    var out = String()
    out += "antlr_tokens/used-coordinates.json.expected"
    return out^


def _file_1() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "TypeWithGra'
    out += 'phQLKeywords": {\n            "null": [\n                '
    out += '"fragment"\n            ]\n        },\n        "String":'
    out += ' {},\n        "Query": {}\n    }\n}'
    return out^


def _path_2() -> String:
    var out = String()
    out += "arguments_hardcoded/TestOperation.graphql"
    return out^


def _file_2() -> String:
    var out = String()
    out += "# hardcoded arguments\nquery TestQuery {\n  reviews(episode:"
    out += " JEDI starsInt: 10 starsFloat: 9.9) {\n    stars\n    commen"
    out += "tary\n  }\n  testNullableArguments(int: null, string: null, "
    out += "float: null, review: null, episode: null, boolean: null, lis"
    out += "t: null)\n}"
    return out^


def _path_3() -> String:
    var out = String()
    out += "arguments_hardcoded/used-coordinates.json.expected"
    return out^


def _file_3() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Review": {'
    out += '},\n        "Query": {\n            "reviews": [\n      '
    out += '          "episode",\n                "starsInt",\n     '
    out += '           "starsFloat"\n            ],\n            "tes'
    out += 'tNullableArguments": [\n                "int",\n         '
    out += '       "string",\n                "float",\n            '
    out += '    "review",\n                "episode",\n             '
    out += '   "boolean",\n                "list"\n            ]\n  '
    out += '      },\n        "Int": {},\n        "String": {}\n    '
    out += "}\n}"
    return out^


def _path_4() -> String:
    var out = String()
    out += "big_query/TestOperation.graphql"
    return out^


def _file_4() -> String:
    var out = String()
    out += "query TestQuery {\n    # This query document will end up mor"
    out += "e than 64k which is more than what the JVM can put in a cons"
    out += "tant\n    # The kotlin compiler should split it in several c"
    out += "onstants\n    # See https://github.com/apollographql/apollo-"
    out += 'kotlin/pull/4130\n    character(id: "vvoihoihoihoihoihoihoi'
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += 'hoihoihoihoihoihoi"){\n        name\n    }\n}'
    return out^


def _path_5() -> String:
    var out = String()
    out += "capitalized_fields/TestOperation.graphql"
    return out^


def _file_5() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ... on Horse {"
    out += "\n      Cow {\n        Moo\n      }\n    }\n  }\n}\n"
    return out^


def _path_6() -> String:
    var out = String()
    out += "capitalized_fields/schema.graphqls"
    return out^


def _file_6() -> String:
    var out = String()
    out += "type Query {\n  Horse: Horse\n}\n\ntype Horse {\n  Donkey: S"
    out += "tring\n  Cow: Cow\n}\n\ntype Cow {\n  Moo: String\n}"
    return out^


def _path_7() -> String:
    var out = String()
    out += "capitalized_fields/used-coordinates.json.expected"
    return out^


def _file_7() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Horse": {}'
    out += ',\n        "Cow": {},\n        "String": {},\n        "'
    out += 'Query": {}\n    }\n}'
    return out^


def _path_8() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_allowed.exp"
    out += "ected"
    return out^


def _file_8() -> String:
    var out = String()
    return out^


def _path_9() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_allowed.gra"
    out += "phql"
    return out^


def _file_9() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ... on Horse {"
    out += "\n      Cow {\n        Moo\n      }\n    }\n  }\n}\n"
    return out^


def _path_10() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_allowed_wit"
    out += "h_fragment_spread.expected"
    return out^


def _file_10() -> String:
    var out = String()
    out += "UpperCaseField (15:3)\nCapitalized field 'Cow' is not suppor"
    out += "ted as it causes name clashes with the generated models. Use"
    out += " an alias instead or the 'flattenModels' or 'decapitalizeFie"
    out += "lds' compiler option."
    return out^


def _path_11() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_allowed_wit"
    out += "h_fragment_spread.graphql"
    return out^


def _file_11() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ... on Horse {"
    out += "\n      Cow {\n        Moo\n      }\n    }\n\n    ... HorseF"
    out += "ragment\n  }\n}\n\nfragment HorseFragment on Horse {\n  Cow "
    out += "{\n    Moo\n  }\n}\n"
    return out^


def _path_12() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_disallowed."
    out += "expected"
    return out^


def _file_12() -> String:
    var out = String()
    out += "UpperCaseField (2:3)\nCapitalized field 'Horse' is not suppo"
    out += "rted as it causes name clashes with the generated models. Us"
    out += "e an alias instead or the 'flattenModels' or 'decapitalizeFi"
    out += "elds' compiler option.\n------------\nUpperCaseField (5:7)\n"
    out += "Capitalized field 'Cow' is not supported as it causes name c"
    out += "lashes with the generated models. Use an alias instead or th"
    out += "e 'flattenModels' or 'decapitalizeFields' compiler option."
    return out^


def _path_13() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_disallowed."
    out += "graphql"
    return out^


def _file_13() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ... on Horse {"
    out += "\n      Cow {\n        Moo\n      }\n    }\n  }\n}\n"
    return out^


def _path_14() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_disallowed_"
    out += "with_fragment_spread.expected"
    return out^


def _file_14() -> String:
    var out = String()
    out += "UpperCaseField (2:3)\nCapitalized field 'Horse' is not suppo"
    out += "rted as it causes name clashes with the generated models. Us"
    out += "e an alias instead or the 'flattenModels' or 'decapitalizeFi"
    out += "elds' compiler option.\n------------\nUpperCaseField (9:3)\n"
    out += "Capitalized field 'Cow' is not supported as it causes name c"
    out += "lashes with the generated models. Use an alias instead or th"
    out += "e 'flattenModels' or 'decapitalizeFields' compiler option."
    return out^


def _path_15() -> String:
    var out = String()
    out += "capitalized_fields_validation/capitalized_fields_disallowed_"
    out += "with_fragment_spread.graphql"
    return out^


def _file_15() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ...HorseFragme"
    out += "nt\n  }\n}\n\nfragment HorseFragment on Horse {\n  Cow {\n  "
    out += "  Moo\n  }\n}\n"
    return out^


def _path_16() -> String:
    var out = String()
    out += "capitalized_fields_validation/schema.graphqls"
    return out^


def _file_16() -> String:
    var out = String()
    out += "type Query {\n    Horse: Horse\n}\n\ntype Horse {\n    Donke"
    out += "y: String\n    Cow: Cow\n}\n\ntype Cow {\n    Moo: String\n}"
    return out^


def _path_17() -> String:
    var out = String()
    out += "case_sensitive_enum/TestOperation.graphql"
    return out^


def _file_17() -> String:
    var out = String()
    out += "# The generated enum class should contain all members\nquery"
    out += " TestQuery {\n  enum\n}\n"
    return out^


def _path_18() -> String:
    var out = String()
    out += "case_sensitive_enum/schema.graphqls"
    return out^


def _file_18() -> String:
    var out = String()
    out += "type Query {\n  enum: Enum\n}\n\nenum Enum {\n    north @dep"
    out += "recated\n    North @deprecated\n    NORTH\n    SOUTH\n}"
    return out^


def _path_19() -> String:
    var out = String()
    out += "case_sensitive_enum/used-coordinates.json.expected"
    return out^


def _file_19() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Enum": {},'
    out += '\n        "Query": {}\n    }\n}'
    return out^


def _path_20() -> String:
    var out = String()
    out += "companion/TestOperation.graphql"
    return out^


def _file_20() -> String:
    var out = String()
    out += "query TestQuery {\n  companion {\n    foo\n  }\n}\n"
    return out^


def _path_21() -> String:
    var out = String()
    out += "companion/schema.graphqls"
    return out^


def _file_21() -> String:
    var out = String()
    out += "type Query {\n  companion: Companion\n}\n\ntype Companion {"
    out += "\n  foo: Int!\n}"
    return out^


def _path_22() -> String:
    var out = String()
    out += "companion/used-coordinates.json.expected"
    return out^


def _file_22() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Companion"'
    out += ': {},\n        "Int": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_23() -> String:
    var out = String()
    out += "decapitalized_fields/TestOperation.graphql"
    return out^


def _file_23() -> String:
    var out = String()
    out += "query TestQuery {\n  Horse {\n    Donkey\n    ... on Horse {"
    out += "\n      Cow {\n        Moo\n      }\n    }\n\n    ... HorseF"
    out += "ragment\n  }\n}\n\nfragment HorseFragment on Horse {\n  Cow "
    out += "{\n    Moo\n  }\n}\n"
    return out^


def _path_24() -> String:
    var out = String()
    out += "decapitalized_fields/schema.graphqls"
    return out^


def _file_24() -> String:
    var out = String()
    out += "type Query {\n  Horse: Horse\n}\n\ntype Horse {\n  Donkey: S"
    out += "tring\n  Cow: Cow\n}\n\ntype Cow {\n  Moo: String\n}"
    return out^


def _path_25() -> String:
    var out = String()
    out += "decapitalized_fields/used-coordinates.json.expected"
    return out^


def _file_25() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Horse": {}'
    out += ',\n        "Cow": {},\n        "String": {},\n        "'
    out += 'Query": {}\n    }\n}'
    return out^


def _path_26() -> String:
    var out = String()
    out += "deprecated_merged_field/TestOperation.graphql"
    return out^


def _file_26() -> String:
    var out = String()
    out += "query CatQuery {\n    cat {\n        ...AnimalFragment\n    "
    out += "}\n}\n\nfragment AnimalFragment on Animal {\n    ... on Cat "
    out += "{\n        name\n    }\n    ... on Dog {\n        name\n    "
    out += "}\n}"
    return out^


def _path_27() -> String:
    var out = String()
    out += "deprecated_merged_field/schema.graphqls"
    return out^


def _file_27() -> String:
    var out = String()
    out += "type Cat {\n    name: String!\n}\n\ntype Dog {\n    name: St"
    out += "ring! @deprecated\n}\n\nunion Animal = Cat | Dog\n\ntype Que"
    out += "ry {\n    cat: Cat\n}\n\n"
    return out^


def _path_28() -> String:
    var out = String()
    out += "deprecated_merged_field/used-coordinates.json.expected"
    return out^


def _file_28() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Cat": {},'
    out += '\n        "String": {},\n        "Query": {},\n        '
    out += '"Animal": {},\n        "Dog": {}\n    }\n}'
    return out^


def _path_29() -> String:
    var out = String()
    out += "deprecation/TestOperation.graphql"
    return out^


def _file_29() -> String:
    var out = String()
    out += "# deprecated fields should have a @Deprecated annotation\nqu"
    out += "ery TestQuery($episode: Episode) {\n  hero(episode: $episode"
    out += ") {\n    name\n    deprecated\n    deprecatedBool\n    depre"
    out += "catedEmptyReason\n  }\n}"
    return out^


def _path_30() -> String:
    var out = String()
    out += "deprecation/schema.graphqls"
    return out^


def _file_30() -> String:
    var out = String()
    out += "type Query {\n    hero(episode: Episode @deprecated): Charac"
    out += "ter\n}\n\nenum Episode {\n    JEDI,\n    CLONES @deprecated"
    out += "\n}\ntype Character {\n    name: String!\n    deprecated: St"
    out += "ring! @deprecated\n    deprecatedBool: Boolean! @deprecated"
    out += '\n    deprecatedEmptyReason: String! @deprecated(reason: "'
    out += '")\n}\n'
    return out^


def _path_31() -> String:
    var out = String()
    out += "deprecation/used-coordinates.json.expected"
    return out^


def _file_31() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'String": {},\n        "Boolean": {},\n        "Episode"'
    out += ": {}\n    }\n}"
    return out^


def _path_32() -> String:
    var out = String()
    out += "enum_field/TestOperation.graphql"
    return out^


def _file_32() -> String:
    var out = String()
    out += "# A query with a case sensitive enum\nquery TestQuery {\n  g"
    out += "ravity\n  gravityAsEnum\n}\n"
    return out^


def _path_33() -> String:
    var out = String()
    out += "enum_field/schema.graphqls"
    return out^


def _file_33() -> String:
    var out = String()
    out += "type Query {\n  gravity: Gravity\n  gravityAsEnum: GravityAs"
    out += "Enum\n}\n\nenum Gravity {\n  TOP\n  CENTER\n  BOTTOM\n  # li"
    out += "ke BOTTOM but with different case instead\n  bottom @depreca"
    out += 'ted(reason: "use BOTTOM instead")\n\n  # a name that clash'
    out += "es with a Kotlin reserved keyword\n  is\n\n  # a name that c"
    out += "lashes with the generated `type` constant\n  type\n\n  # an "
    out += "enum value that clashes with the rawValue type\n  String\n\n"
    out += "  field\n}\n\nenum GravityAsEnum {\n  TOP\n  CENTER\n  BOTTO"
    out += 'M\n\n  "like BOTTOM but with different case instead"\n  bo'
    out += 'ttom @deprecated(reason: "use BOTTOM instead")\n\n  # a na'
    out += 'me that clashes with a Kotlin reserved keyword\n  is\n\n  "'
    out += 'a name that clashes with a Java reserved keyword"\n  while'
    out += '\n\n  "a name that clashes with the generated `type` consta'
    out += 'nt"\n  type\n\n  "an enum value that clashes with the rawV'
    out += 'alue type"\n  String\n\n  field\n}\n'
    return out^


def _path_34() -> String:
    var out = String()
    out += "enum_field/used-coordinates.json.expected"
    return out^


def _file_34() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Gravity": '
    out += '{},\n        "GravityAsEnum": {},\n        "Query": {}\n'
    out += "    }\n}"
    return out^


def _path_35() -> String:
    var out = String()
    out += "enums_as_sealed/TestOperation.graphql"
    return out^


def _file_35() -> String:
    var out = String()
    out += "# The generated enum class should contain all members\nquery"
    out += " TestQuery {\n  enum\n}\n"
    return out^


def _path_36() -> String:
    var out = String()
    out += "enums_as_sealed/schema.graphqls"
    return out^


def _file_36() -> String:
    var out = String()
    out += "type Query {\n  enum: Enum\n}\n\nenum Enum {\n    north @dep"
    out += "recated\n    North @deprecated\n    NORTH\n    SOUTH\n\n    "
    out += "type\n}\n"
    return out^


def _path_37() -> String:
    var out = String()
    out += "enums_as_sealed/used-coordinates.json.expected"
    return out^


def _file_37() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Enum": {},'
    out += '\n        "Query": {}\n    }\n}'
    return out^


def _path_38() -> String:
    var out = String()
    out += "escape_equals_hashcode/TestOperation.graphql"
    return out^


def _file_38() -> String:
    var out = String()
    out += "query TestQuery {\n  in\n  out\n}\n"
    return out^


def _path_39() -> String:
    var out = String()
    out += "escape_equals_hashcode/schema.graphqls"
    return out^


def _file_39() -> String:
    var out = String()
    out += "type Query {\n  in: Int!\n  out: Int!\n}\n\n"
    return out^


def _path_40() -> String:
    var out = String()
    out += "escape_equals_hashcode/used-coordinates.json.expected"
    return out^


def _file_40() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {}\n    }\n}'
    return out^


def _path_41() -> String:
    var out = String()
    out += "escaped_kdocs/TestOperation.graphql"
    return out^


def _file_41() -> String:
    var out = String()
    out += "query TestQuery {\n  someType {\n    someField\n  }\n}\n"
    return out^


def _path_42() -> String:
    var out = String()
    out += "escaped_kdocs/schema.graphqls"
    return out^


def _file_42() -> String:
    var out = String()
    out += 'type Query {\n  someType: SomeType\n}\n\n"""\n/1 Stuff\n*'
    out += 'TODO*/2 More stuff\n"""\ntype SomeType {\n  """\n  Som'
    out += 'e URL: https://example.com/some-url/*\n  """\n  someField'
    out += ": Int\n}\n\n"
    return out^


def _path_43() -> String:
    var out = String()
    out += "escaped_kdocs/used-coordinates.json.expected"
    return out^


def _file_43() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "SomeType":'
    out += ' {},\n        "Int": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_44() -> String:
    var out = String()
    out += "field_with_include_directive/TestOperation.graphql"
    return out^


def _file_44() -> String:
    var out = String()
    out += "query TestQuery($includeName: Boolean!, $skipFriends: Boolea"
    out += 'n!) @operationDirective(dummy: "hello") {\n  hero {\n    n'
    out += "ame @include(if: $includeName)\n    friendsConnection @skip("
    out += "if: $skipFriends) {\n      totalCount\n    }\n  }\n}"
    return out^


def _path_45() -> String:
    var out = String()
    out += "field_with_include_directive/used-coordinates.json.expected"
    return out^


def _file_45() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "FriendsConnection'
    out += '": {},\n        "Int": {},\n        "Query": {},\n     '
    out += '   "Boolean": {}\n    }\n}'
    return out^


def _path_46() -> String:
    var out = String()
    out += "fieldset_with_multiple_super/TestOperation.graphql"
    return out^


def _file_46() -> String:
    var out = String()
    out += "# This test tests that inside a given field some field set m"
    out += "ight implement multiple super interfaces\n# In this case, th"
    out += "e ABC object must implement both AC and AB interfaces\n# Eve"
    out += "n if it's not tested here, the same is true when implementin"
    out += "g fragments\nquery TestQuery {\n    c {\n        ... on A {"
    out += "\n            fieldA1\n            ... on B {\n             "
    out += "   fieldB1\n            }\n        }\n        ... on B {\n  "
    out += "          fieldB2\n            ... on A {\n                f"
    out += "ieldA2\n            }\n        }\n    }\n}\n"
    return out^


def _path_47() -> String:
    var out = String()
    out += "fieldset_with_multiple_super/schema.graphqls"
    return out^


def _file_47() -> String:
    var out = String()
    out += "type Query {\n  c: C\n}\n\ninterface A {\n  fieldA1: String"
    out += "\n  fieldA2: String\n}\n\ninterface B {\n  fieldB1: String\n"
    out += "  fieldB2: String\n}\ninterface C {\n  fieldC: String\n}\n\n"
    out += "type ABC implements A & B & C {\n  fieldA1: String\n  fieldA"
    out += "2: String\n  fieldB1: String\n  fieldB2: String\n  fieldC: S"
    out += "tring\n}\n\ntype AC implements A & C {\n  fieldA1: String\n "
    out += " fieldA2: String\n  fieldC: String\n}\n\ntype BC implements "
    out += "B & C {\n  fieldB1: String\n  fieldB2: String\n  fieldC: Str"
    out += "ing\n}\n\ntype SomeC implements C {\n  fieldC: String\n}\n"
    return out^


def _path_48() -> String:
    var out = String()
    out += "fieldset_with_multiple_super/used-coordinates.json.expected"
    return out^


def _file_48() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "C": {},\n '
    out += '       "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_49() -> String:
    var out = String()
    out += "fragment_spread_with_include_directive/TestOperation.graphql"
    return out^


def _file_49() -> String:
    var out = String()
    out += "query TestQuery(\n  $withDetails: Boolean!,\n  $skipHumanDet"
    out += "ails: Boolean!,\n  $optionalWithDefaultFalse: Boolean = fals"
    out += "e,\n  $optionalWithDefaultTrue: Boolean = true,\n  $optional"
    out += "WithNoDefault: Boolean,\n) {\n  hero {\n    id\n    ... Hero"
    out += "Details @include(if: $withDetails) @skip(if: $skipHumanDetai"
    out += "ls)\n    ... HumanDetails @include(if: $withDetails)\n    .."
    out += ". DroidDetails @skip(if: $optionalWithDefaultTrue)\n    ... "
    out += "OtherDroidDetails @include(if: $optionalWithDefaultTrue)\n  "
    out += "}\n  getBoolean(booleanArg: $optionalWithNoDefault)\n}\n\nfr"
    out += "agment HeroDetails on Character {\n  name\n}\n\nfragment Hum"
    out += "anDetails on Human {\n  homePlanet\n}\n\nfragment DroidDetai"
    out += "ls on Droid {\n  primaryFunction\n}\n\nfragment OtherDroidDe"
    out += "tails on Droid {\n  id\n}\n"
    return out^


def _path_50() -> String:
    var out = String()
    out += "fragment_spread_with_include_directive/used-coordinates.json"
    out += ".expected"
    return out^


def _file_50() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Boolean": {},\n        "Query": {\n     '
    out += '       "getBoolean": [\n                "booleanArg"\n  '
    out += '          ]\n        },\n        "String": {},\n        "'
    out += 'ID": {},\n        "Human": {},\n        "Droid": {}\n  '
    out += "  }\n}"
    return out^


def _path_51() -> String:
    var out = String()
    out += "fragment_spread_with_nested_fields/TestOperation.graphql"
    return out^


def _file_51() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ...HeroDetails\n  }\n}\n\nf"
    out += "ragment HeroDetails on Character {\n  name\n  friendsConnect"
    out += "ion {\n    totalCount\n    edges {\n      node {\n        na"
    out += "me\n      }\n    }\n  }\n}"
    return out^


def _path_52() -> String:
    var out = String()
    out += "fragment_spread_with_nested_fields/used-coordinates.json.exp"
    out += "ected"
    return out^


def _file_52() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "FriendsConnection": {},\n        "Int": {},\n      '
    out += '  "FriendsEdge": {}\n    }\n}'
    return out^


def _path_53() -> String:
    var out = String()
    out += "fragment_used_twice/TestOperation.graphql"
    return out^


def _file_53() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    __typename\n    ...HeroDeta"
    out += "ils\n    ...HumanDetails\n  }\n}\n\nfragment HeroDetails on "
    out += "Character {\n  __typename\n  name\n  ...CharacterDetails\n}"
    out += "\n\nfragment HumanDetails on Human {\n  __typename\n  name\n"
    out += "  ...CharacterDetails\n}\n\nfragment CharacterDetails on Cha"
    out += "racter {\n  name\n  birthDate\n}\n"
    return out^


def _path_54() -> String:
    var out = String()
    out += "fragment_used_twice/used-coordinates.json.expected"
    return out^


def _file_54() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Human": {},\n        "Date": {}\n    }\n}'
    return out^


def _path_55() -> String:
    var out = String()
    out += "fragment_with_inline_fragment/TestOperation.graphql"
    return out^


def _file_55() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n    ...HeroDetails\n "
    out += "   appearsIn\n  }\n}\n\nfragment HeroDetails on Character {"
    out += "\n  ... HumanDetails\n  ... on Droid {\n    ...DroidDetails"
    out += "\n  }\n  name\n  friendsConnection {\n    totalCount\n    ed"
    out += "ges {\n      node {\n        name\n      }\n    }\n  }\n}\n"
    out += "\nfragment DroidDetails on Droid {\n  name\n  primaryFunctio"
    out += "n\n}\n\nfragment HumanDetails on Human {\n  name\n}\n"
    return out^


def _path_56() -> String:
    var out = String()
    out += "fragment_with_inline_fragment/used-coordinates.json.expected"
    return out^


def _file_56() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Episode": {},\n  '
    out += '      "Query": {},\n        "FriendsConnection": {},\n  '
    out += '      "Int": {},\n        "FriendsEdge": {},\n        "'
    out += 'Droid": {},\n        "Human": {}\n    }\n}'
    return out^


def _path_57() -> String:
    var out = String()
    out += "fragment_with_multiple_fieldsets/TestOperation.graphql"
    return out^


def _file_57() -> String:
    var out = String()
    out += "# when generating the implementations, it's important to inh"
    out += "erit from the most qualified fragment interface\n# In that c"
    out += "ase `AIFragment`. Else we not have access to fieldA from int"
    out += "erfaces\n# i.e with\n#    data.i\n#        .iFragment()\n#  "
    out += "      .asA() // <= this will cast to AIFragment so the inter"
    out += "face needs to be implemented\n#        .fieldA\nquery TestQu"
    out += "ery {\n    i {\n        ...iFragment\n    }\n}\n\nfragment i"
    out += "Fragment on I {\n    ... on A {\n        fieldA\n    }\n}"
    return out^


def _path_58() -> String:
    var out = String()
    out += "fragment_with_multiple_fieldsets/schema.graphqls"
    return out^


def _file_58() -> String:
    var out = String()
    out += "type Query {\n  i: I\n}\n\ninterface I {\n  fieldI: String\n"
    out += "}\n\ninterface J {\n  fieldJ: String\n}\n\ntype A implements"
    out += " I {\n  fieldI: String\n  fieldA: String\n}\n\ntype B implem"
    out += "ents I & J {\n  fieldI: String\n  fieldJ: String\n}\n"
    return out^


def _path_59() -> String:
    var out = String()
    out += "fragment_with_multiple_fieldsets/used-coordinates.json.expec"
    out += "ted"
    return out^


def _file_59() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "I": {},\n '
    out += '       "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_60() -> String:
    var out = String()
    out += "fragments_same_type_condition/TestOperation.graphql"
    return out^


def _file_60() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ...DroidDetails1\n    ...Dr"
    out += "oidDetails2\n  }\n}\n\nfragment DroidDetails1 on Droid {\n  "
    out += "name\n}\n\nfragment DroidDetails2 on Droid {\n  primaryFunct"
    out += "ion\n}\n"
    return out^


def _path_61() -> String:
    var out = String()
    out += "fragments_same_type_condition/used-coordinates.json.expected"
    return out^


def _file_61() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Droid": {}\n    }\n}'
    return out^


def _path_62() -> String:
    var out = String()
    out += "fragments_with_defer_and_include_directives/TestOperation.gr"
    out += "aphql"
    return out^


def _file_62() -> String:
    var out = String()
    out += "query SpreadSingleWithDefer {\n  hero {\n    ...DroidDetails"
    out += " @defer\n  }\n}\n\nquery SpreadMultipleWithDefer {\n  hero {"
    out += '\n    ...DroidDetails @defer(label: "a_first")\n    ...Dro'
    out += 'idDetails @defer(label: "a_second")\n  }\n}\n\nquery Sprea'
    out += "dMultipleWithDeferAndInclude($cond1: Boolean!, $cond2: Boole"
    out += "an!, $cond3: Boolean!, $cond4: Boolean!) {\n  hero {\n    .."
    out += ".DroidDetails @include(if: $cond1)\n    ...DroidDetails @ski"
    out += 'p(if: $cond2)\n    ...DroidDetails @defer(label: "b_first"'
    out += ')\n    ...DroidDetails @defer(label: "b_second")\n    ...D'
    out += 'roidDetails @defer(label: "b_third") @include(if: $cond3)'
    out += '\n    ...DroidDetails @defer(label: "b_fourth") @skip(if: '
    out += "$cond4)\n  }\n}\n\nfragment DroidDetails on Droid {\n  name"
    out += "\n}\n\nquery SpreadMultipleWithDeferWithIf($cond: Boolean!) "
    out += '{\n  hero {\n    ...CharacterDetails @defer(label: "c_first'
    out += '" if: false)\n    ...CharacterDetails2 @defer(label: "c_se'
    out += 'cond" if: true)\n    ...CharacterDetails3 @defer(label: "c'
    out += '_third" if: $cond)\n  }\n}\n\nfragment CharacterDetails on '
    out += "Droid {\n  name\n}\n\nfragment CharacterDetails2 on Droid {"
    out += "\n  id\n}\n\nfragment CharacterDetails3 on Droid {\n  birthD"
    out += "ate\n}\n\nquery InlineSingleWithDefer {\n  hero {\n    ... o"
    out += "n Droid @defer {\n      name\n    }\n  }\n}\n\nquery InlineM"
    out += "ultipleWithDefer {\n  hero {\n    ... on Droid @defer(label:"
    out += ' "d_first") {\n      name\n    }\n\n    ... on Droid @defe'
    out += 'r(label: "d_second") {\n      id\n    }\n  }\n}\n\nquery I'
    out += "nlineMultipleWithDeferAndInclude($cond1: Boolean!, $cond2: B"
    out += "oolean!, $cond3: Boolean!, $cond4: Boolean!) {\n  hero {\n  "
    out += "  ... on Droid @include(if: $cond1) {\n      name\n    }\n  "
    out += "  ... on Droid @skip(if: $cond2) {\n      id\n    }\n    ..."
    out += ' on Droid @defer(label: "e_first") {\n      name\n    }\n '
    out += '   ... on Droid @defer(label: "e_second") {\n      id\n   '
    out += ' }\n    ... on Droid @defer(label: "e_third") @include(if:'
    out += " $cond3) {\n      name\n    }\n    ... on Droid @defer(label"
    out += ': "e_fourth") @skip(if: $cond4) {\n      id\n    }\n  }\n}'
    out += "\n\nquery InlineMultipleWithDeferWithIf($cond: Boolean!) {\n"
    out += '  hero {\n    ... on Character @defer(label: "f_first" if:'
    out += " false) {\n      id\n    }\n\n    ... on Character @defer(la"
    out += 'bel: "f_second" if: true) {\n      name\n    }\n\n    ... '
    out += 'on Character @defer(label: "f_third" if: $cond) {\n      n'
    out += "ame\n    }\n  }\n}\n"
    return out^


def _path_63() -> String:
    var out = String()
    out += "fragments_with_defer_and_include_directives/used-coordinates"
    out += ".json.expected"
    return out^


def _file_63() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Boolean": {},\n        "ID": {},\n        "Droid"'
    out += ': {},\n        "Date": {}\n    }\n}'
    return out^


def _path_64() -> String:
    var out = String()
    out += "fragments_with_type_condition/TestOperation.graphql"
    return out^


def _file_64() -> String:
    var out = String()
    out += "# query the same field with two different aliases\nquery Tes"
    out += "tQuery {\n  r2: hero {\n    ...HumanDetails\n    ...DroidDet"
    out += "ails\n  }\n  luke: hero {\n    ...HumanDetails\n    ...Droid"
    out += "Details\n  }\n}\n\nfragment HumanDetails on Human {\n  name"
    out += "\n  height\n}\n\nfragment DroidDetails on Droid {\n  name\n "
    out += " primaryFunction\n}\n"
    return out^


def _path_65() -> String:
    var out = String()
    out += "fragments_with_type_condition/used-coordinates.json.expected"
    return out^


def _file_65() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Float": {},\n        "Human": {},\n        "Droid'
    out += '": {}\n    }\n}'
    return out^


def _path_66() -> String:
    var out = String()
    out += "golden/operations.graphql"
    return out^


def _file_66() -> String:
    var out = String()
    out += "query Hero($episode: Episode, $withFriends: Boolean! = true,"
    out += " $skipName: Boolean = false) {\n  hero(episode: $episode) {"
    out += "\n    name @skip(if: $skipName)\n    id\n    friends @includ"
    out += "e(if: $withFriends) {\n      name\n    }\n    ... on Droid {"
    out += "\n      primaryFunction\n    }\n    ... on Human {\n      he"
    out += "ight(unit: FOOT)\n      birthDate\n    }\n    ...CharacterAp"
    out += "pearances\n  }\n}\n\nfragment CharacterAppearances on Charac"
    out += "ter {\n  appearsIn\n}\n\nquery Search($text: String!, $verbo"
    out += "se: Boolean! = false) {\n  search(text: $text) {\n    ... on"
    out += " Human {\n      name\n      mass @include(if: $verbose)\n   "
    out += " }\n    ... on Droid {\n      name\n    }\n  }\n  matrix\n}"
    out += "\n\nmutation CreateReview($episode: Episode, $review: Review"
    out += "Input!) {\n  createReview(episode: $episode, review: $review"
    out += ") {\n    stars\n    commentary\n    from\n  }\n}\n\nquery De"
    out += "ferred {\n  hero {\n    id\n    ... on Droid @defer(label: "
    out += '"droid") {\n      primaryFunction\n    }\n  }\n}\n'
    return out^


def _path_67() -> String:
    var out = String()
    out += "golden/schema.graphqls"
    return out^


def _file_67() -> String:
    var out = String()
    out += "schema {\n  query: Query\n  mutation: Mutation\n}\n\ndirecti"
    out += "ve @defer(label: String, if: Boolean! = true) on FRAGMENT_SP"
    out += "READ | INLINE_FRAGMENT\n\ninterface Character {\n  id: ID!\n"
    out += "  name: String!\n  friends: [Character]\n  appearsIn: [Episo"
    out += "de]!\n}\n\nenum Episode {\n  NEWHOPE\n  EMPIRE\n  JEDI\n}\n"
    out += "\nenum LengthUnit {\n  METER\n  FOOT\n}\n\nscalar Date\n\nty"
    out += "pe Human implements Character {\n  id: ID!\n  name: String!"
    out += "\n  friends: [Character]\n  appearsIn: [Episode]!\n  height("
    out += "unit: LengthUnit = METER): Float\n  mass: Float\n  birthDate"
    out += ": Date\n}\n\ntype Droid implements Character {\n  id: ID!\n "
    out += " name: String!\n  friends: [Character]\n  appearsIn: [Episod"
    out += "e]!\n  primaryFunction: String\n}\n\nunion SearchResult = Hu"
    out += "man | Droid\n\ninput ColorInput {\n  red: Int! = 0\n  green:"
    out += " Int!\n  blue: Int!\n}\n\ninput ReviewInput {\n  stars: Int!"
    out += "\n  commentary: String\n  favoriteColor: ColorInput\n  tags:"
    out += " [String!] = []\n  episodes: [Episode]\n  when: Date\n  isFa"
    out += "n: Boolean\n}\n\ntype Review {\n  stars: Int!\n  commentary:"
    out += " String\n  from: String\n}\n\ntype Query {\n  hero(episode: "
    out += "Episode): Character\n  search(text: String!): [SearchResult!"
    out += "]!\n  reviews(episode: Episode!): [Review]\n  matrix: [[Int!"
    out += "]]\n}\n\ntype Mutation {\n  createReview(episode: Episode, r"
    out += "eview: ReviewInput!): Review\n}\n"
    return out^


def _path_68() -> String:
    var out = String()
    out += "hero_details/TestOperation.graphql"
    return out^


def _file_68() -> String:
    var out = String()
    out += "query HeroDetails {\n  hero {\n    type\n    name\n    frien"
    out += "dsConnection {\n      totalCount\n      edges {\n        nod"
    out += "e {\n          name\n        }\n      }\n    }\n  }\n}\n"
    return out^


def _path_69() -> String:
    var out = String()
    out += "hero_details/used-coordinates.json.expected"
    return out^


def _file_69() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "hero_type": {},\n        "String": {},\n'
    out += '        "FriendsConnection": {},\n        "Int": {},\n  '
    out += '      "FriendsEdge": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_70() -> String:
    var out = String()
    out += "hero_details_semantic_naming/TestOperation.graphql"
    return out^


def _file_70() -> String:
    var out = String()
    out += "query HeroDetails {\n  hero {\n    name\n    friendsConnecti"
    out += "on {\n      totalCount\n      edges {\n        node {\n     "
    out += "     name\n        }\n      }\n    }\n  }\n}\n"
    return out^


def _path_71() -> String:
    var out = String()
    out += "hero_details_semantic_naming/used-coordinates.json.expected"
    return out^


def _file_71() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "FriendsConnection'
    out += '": {},\n        "Int": {},\n        "FriendsEdge": {},'
    out += '\n        "Query": {}\n    }\n}'
    return out^


def _path_72() -> String:
    var out = String()
    out += "hero_name/TestOperation.graphql"
    return out^


def _file_72() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n    birthDate\n    .."
    out += ". on Droid {\n       primaryFunction\n    }\n  }\n}\n"
    return out^


def _path_73() -> String:
    var out = String()
    out += "hero_name/used-coordinates.json.expected"
    return out^


def _file_73() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Date": {},\n     '
    out += '   "Query": {}\n    }\n}'
    return out^


def _path_74() -> String:
    var out = String()
    out += "hero_name_query_long_name/TestOperation.graphql"
    return out^


def _file_74() -> String:
    var out = String()
    out += "# KotlinPoet should not wrap in illegal positions\nquery Tes"
    out += "tQueryWithAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVery"
    out += "AVeryAVeryAVeryLongName($episodeAVeryAVeryAVeryAVeryAVeryAVe"
    out += "ryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryLongName:Epis"
    out += "ode) {\n  heroAVeryAVeryAVeryAVeryAVeryAVeryAV: hero(episode"
    out += ": $episodeAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVery"
    out += "AVeryAVeryAVeryAVeryAVeryLongName) {\n    nameAVeryAVeryAVer"
    out += "yAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVer"
    out += "yLongName: name\n  }\n}\n"
    return out^


def _path_75() -> String:
    var out = String()
    out += "hero_name_query_long_name/used-coordinates.json.expected"
    return out^


def _file_75() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'String": {},\n        "Episode": {}\n    }\n}'
    return out^


def _path_76() -> String:
    var out = String()
    out += "hero_with_review/TestOperation.graphql"
    return out^


def _file_76() -> String:
    var out = String()
    out += "mutation TestQuery($ep: Episode!) {\n  createReview(episode:"
    out += " $ep, review: {stars: 5, listOfEnums: [JEDI EMPIRE NEWHOPE],"
    out += ' listOfStringNonOptional: ["1" "2" "3"], favoriteColor'
    out += ": {red: 1, blue: 1}}) {\n    stars\n    commentary\n  }\n}\n"
    return out^


def _path_77() -> String:
    var out = String()
    out += "hero_with_review/used-coordinates.json.expected"
    return out^


def _file_77() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Review": {'
    out += '},\n        "Mutation": {\n            "createReview": ['
    out += '\n                "episode",\n                "review"\n'
    out += '            ]\n        },\n        "Int": {},\n        "S'
    out += 'tring": {},\n        "Episode": {}\n    }\n}'
    return out^


def _path_78() -> String:
    var out = String()
    out += "inline_fragment_for_non_optional_field/TestOperation.graphql"
    return out^


def _file_78() -> String:
    var out = String()
    out += "query TestQuery {\n  nonOptionalHero(episode: EMPIRE) {\n   "
    out += " name\n    ... on Human {\n      height\n    }\n  }\n}\n"
    return out^


def _path_79() -> String:
    var out = String()
    out += "inline_fragment_for_non_optional_field/used-coordinates.json"
    out += ".expected"
    return out^


def _file_79() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "nonOptionalHero"'
    out += ': [\n                "episode"\n            ]\n        },'
    out += '\n        "Float": {},\n        "String": {}\n    }\n}'
    return out^


def _path_80() -> String:
    var out = String()
    out += "inline_fragment_inside_inline_fragment/TestOperation.graphql"
    return out^


def _file_80() -> String:
    var out = String()
    out += 'query TestQuery {\n  search(text: "bla-bla") {\n    ... on'
    out += " Character {\n      name\n      ...on Human {\n        homeP"
    out += "lanet\n      }\n      ...on Droid {\n        primaryFunction"
    out += "\n      }\n    }\n  }\n}\n"
    return out^


def _path_81() -> String:
    var out = String()
    out += "inline_fragment_inside_inline_fragment/used-coordinates.json"
    out += ".expected"
    return out^


def _file_81() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "SearchResul'
    out += 't": {},\n        "Query": {\n            "search": [\n '
    out += '               "text"\n            ]\n        },\n        '
    out += '"String": {},\n        "Human": {},\n        "Droid": '
    out += '{},\n        "Starship": {},\n        "Character": {}\n '
    out += "   }\n}"
    return out^


def _path_82() -> String:
    var out = String()
    out += "inline_fragment_intersection/TestOperation.graphql"
    return out^


def _file_82() -> String:
    var out = String()
    out += "query TestOperation {\n   random {\n       ... on Being {\n "
    out += "          name\n           friends {\n               name\n "
    out += "              ... on Wookie {\n                lifeExpectanc"
    out += "y\n              }\n           }\n           ... on Human {"
    out += "\n               profilePictureUrl\n               friends {"
    out += "\n                  isFamous\n                  ... on Wooki"
    out += "e {\n                    race\n                  }\n        "
    out += "       }\n           }\n       }\n       ... on Wookie {\n  "
    out += "        race\n          friends {\n            lifeExpectanc"
    out += "y\n          }\n       }\n       ... on Being {\n           "
    out += "friends {\n               ... on Wookie {\n                 "
    out += "  lifeExpectancy\n               }\n           }\n       }\n"
    out += "   }\n}\n"
    return out^


def _path_83() -> String:
    var out = String()
    out += "inline_fragment_intersection/schema.graphqls"
    return out^


def _file_83() -> String:
    var out = String()
    out += "# This file is not used, but it is a useful reference to rec"
    out += "reate testSchema.json by running\n#\n# const { buildSchema, "
    out += "getIntrospectionQuery, graphql } = require('graphql')\n#\n# "
    out += "const schema = buildSchema(...)\n# graphql(schema, getIntros"
    out += "pectionQuery()).then(result => console.log(JSON.stringify(re"
    out += "sult, null, 2)))\n\n# Star Wars schema\n\ninterface Characte"
    out += "r {\n  id: ID!\n  name: String!\n}\n\ninterface Thing {\n  p"
    out += "rice: Float\n  owner: Being\n}\n\ninterface Being {\n  name:"
    out += " String!\n  possessions: [Thing!]!\n  lifeExpectancy: Float"
    out += "\n  friends: [Being!]!\n  optionalFriends: [Being]\n  isRebe"
    out += "l: Boolean!\n  isFamous: Boolean\n}\n\ninterface Alien {\n  "
    out += "homePlanet: String!\n  race: Race!\n}\n\ninterface AbstractW"
    out += "ookie {\n  hairLength: Float\n  friends: [Being!]!\n}\n\ntyp"
    out += "e Droid implements Character & Thing {\n  id: ID!\n  name: S"
    out += "tring!\n  price: Float\n  owner: Being\n  primaryFunction: S"
    out += "tring\n}\n\ntype Human implements Character & Being {\n  id:"
    out += " ID!\n  name: String!\n  profilePictureUrls: [String]\n  pro"
    out += "filePictureUrl: String\n  possessions: [Thing!]!\n  lifeExpe"
    out += "ctancy: Float\n  friends: [Being!]!\n  optionalFriends: [Bei"
    out += "ng]\n  favoriteSport: Sport\n  parents: [Human!]!\n  isRebel"
    out += ": Boolean!\n  isFamous: Boolean\n  appearsIn: [Episode!]!\n "
    out += " appearsInOptional: [Episode]\n}\n\ntype Wookie implements C"
    out += "haracter & Being & Alien & AbstractWookie {\n  id: ID!\n  ra"
    out += "ce: Race!\n  name: String!\n  possessions: [Thing!]!\n  life"
    out += "Expectancy: Float\n  friends: [Being!]!\n  optionalFriends: "
    out += "[Being]\n  homePlanet: String!\n  hairLength: Float\n  isReb"
    out += "el: Boolean!\n  isFamous: Boolean\n}\n\ntype Ship implements"
    out += " Thing {\n  id: ID!\n  price: Float\n  owner: Being\n  speed"
    out += ": Float\n}\n\ntype TypeWithAllSortsOfFields {\n  id: ID!\n  "
    out += "optionalId: ID\n  ids1: [ID]\n  ids2: [ID!]\n  ids3: [ID]!\n"
    out += "  ids4: [ID!]!\n\n  long: Long!\n  optionalLong: Long\n  lon"
    out += "gs1: [Long]\n  longs2: [Long!]\n  longs3: [Long]!\n  longs4:"
    out += " [Long!]!\n\n  episode: Episode!\n  optionalEpisode: Episode"
    out += "\n  episodes1: [Episode]\n  episodes2: [Episode!]\n  episode"
    out += "s3: [Episode]!\n  episodes4: [Episode!]!\n\n  string: String"
    out += "!\n  optionalString: String\n  strings1: [String]\n  strings"
    out += "2: [String!]\n  strings3: [String]!\n  strings4: [String!]!"
    out += "\n\n  object: Human!\n  optionalObject: Human\n  objects1: ["
    out += "Human]\n  objects2: [Human!]\n  objects3: [Human]!\n  object"
    out += "s4: [Human!]!\n}\n\n\nenum Sport {\n  Soccer\n  SpeedRacing"
    out += "\n  LightSaberFight\n}\n\nenum Episode {\n  A_NEW_HOPE\n  TH"
    out += "E_EMPIRE_STRIKE_BACK\n  RETURN_OF_THE_JEDI\n}\n\nenum Race {"
    out += "\n  WOOKIE\n  GUMGAN\n  EWOK\n}\n\nunion Anything = Human | "
    out += "Wookie | Droid | Ship\n\ninput AlienInput {\n  episode: Epis"
    out += "ode!\n  planet: String\n}\n\ninput InputWithAllSortsOfFields"
    out += " {\n  id: ID!\n  optionalId: ID\n  ids1: [ID]\n  ids2: [ID!]"
    out += "\n  ids3: [ID]!\n  ids4: [ID!]!\n\n  long: Long!\n  optional"
    out += "Long: Long\n  longs1: [Long]\n  longs2: [Long!]\n  longs3: ["
    out += "Long]!\n  longs4: [Long!]!\n\n  episode: Episode!\n  optiona"
    out += "lEpisode: Episode\n  episodes1: [Episode]\n  episodes2: [Epi"
    out += "sode!]\n  episodes3: [Episode]!\n  episodes4: [Episode!]!\n"
    out += "\n  string: String!\n  optionalString: String\n  strings1: ["
    out += "String]\n  strings2: [String!]\n  strings3: [String]!\n  str"
    out += "ings4: [String!]!\n\n  object: AlienInput!\n  optionalObject"
    out += ": AlienInput\n  objects1: [AlienInput]\n  objects2: [AlienIn"
    out += "put!]\n  objects3: [AlienInput]!\n  objects4: [AlienInput!]!"
    out += "\n}\n\n# Some of Merlin schema\n\nscalar Long\n\ntype Merlin"
    out += "Query {\n  homesPdp(request: MerlinHomesPdpRequestInput!): M"
    out += "erlinHomesPdpResponse\n}\n\ninput MerlinHomesPdpRequestInput"
    out += " {\n  adults: Long\n  causeId: Long\n  checkIn: String\n  ch"
    out += "eckOut: String\n  children: Long\n  disasterId: Long\n  fiel"
    out += "dSelector: String\n  homeCollection: Int\n  infants: Long\n "
    out += " listingId: Long!\n  priceDropSource: String\n  promotionUui"
    out += "d: String\n  searchContext: String\n  tierOverride: Int\n  d"
    out += "ebugMode: Boolean\n  fetchEmptyResponse: Boolean\n  translat"
    out += "eUgc: Boolean\n}\n\ntype MerlinHomesPdpResponse {\n  pdpList"
    out += "ingDetail: MerlinPdpListingDetailForNativeResponse\n}\n\ntyp"
    out += "e MerlinPdpListingDetailForNativeResponse {\n  bedroomLabel:"
    out += " String!\n  guestLabel: String!\n  id: Long!\n  lat: Float\n"
    out += "  lng: Float\n  minNights: Int\n  p3SummaryTitle: String\n  "
    out += "sectionedDescription: MerlinPdpListingDescriptionNestedWithi"
    out += "nListing\n}\n\ntype MerlinPdpListingDescriptionNestedWithinL"
    out += "isting {\n  neighborhoodOverview: String\n  summary: String"
    out += "\n}\n\n# Final schema stitching\n\ntype Query {\n  hero(epis"
    out += "ode: Episode): Character\n  luke: Human!\n  random: Anything"
    out += "!\n  being(id : ID!) : Being\n  droid(id: ID!): Droid\n  ali"
    out += "en(id: ID!): Alien\n  alienWithInput(input: AlienInput!): Al"
    out += "ien\n  abstractWookie(id: ID!): AbstractWookie\n  wookie(id:"
    out += " ID!): Wookie\n  charactersInEpisod(episode: Episode!): [Cha"
    out += "racter!]!\n  anything(id: ID!): Anything\n  getPossessions(b"
    out += "eingId: ID!): [Thing!]!\n  merlin: MerlinQuery\n  humanWithI"
    out += "nput(input1:[String!]!, input2:[ID!], input3: [Episode]!, in"
    out += "put4: [String]): Human\n  anyAlienWithInput(input: AlienInpu"
    out += "t, id: ID): Alien\n  allFieldTypes(input: InputWithAllSortsO"
    out += "fFields): [TypeWithAllSortsOfFields!]!\n}\n\ntype Mutation {"
    out += "\n  changeCharacterName(id : ID!, name: String!): Character"
    out += "\n}\n\nschema {\n  query: Query\n  mutation: Mutation\n}\n"
    return out^


def _path_84() -> String:
    var out = String()
    out += "inline_fragment_intersection/used-coordinates.json.expected"
    return out^


def _file_84() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Anything":'
    out += ' {},\n        "String": {},\n        "Being": {},\n     '
    out += '   "Race": {},\n        "Boolean": {},\n        "Float'
    out += '": {},\n        "Query": {},\n        "Human": {},\n   '
    out += '     "Wookie": {},\n        "Droid": {},\n        "Ship'
    out += '": {},\n        "Character": {},\n        "Alien": {},'
    out += '\n        "AbstractWookie": {},\n        "Thing": {}\n  '
    out += "  }\n}"
    return out^


def _path_85() -> String:
    var out = String()
    out += "inline_fragment_merge_fields/TestOperation.graphql"
    return out^


def _file_85() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n    friendsConnection"
    out += " {\n      edges {\n        node {\n          name\n        }"
    out += "\n      }\n    }\n    ... on Character {\n      name\n      "
    out += "profileLink\n      friendsConnection {\n        edges {\n   "
    out += "       node {\n            name\n          }\n        }\n   "
    out += "   }\n    }\n  }\n}"
    return out^


def _path_86() -> String:
    var out = String()
    out += "inline_fragment_merge_fields/used-coordinates.json.expected"
    return out^


def _file_86() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "URL": {},\n      '
    out += '  "FriendsConnection": {},\n        "FriendsEdge": {},\n'
    out += '        "Query": {}\n    }\n}'
    return out^


def _path_87() -> String:
    var out = String()
    out += "inline_fragment_simple/TestOperation.graphql"
    return out^


def _file_87() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ... on Human {\n      heigh"
    out += "t\n    }\n  }\n}\n"
    return out^


def _path_88() -> String:
    var out = String()
    out += "inline_fragment_simple/used-coordinates.json.expected"
    return out^


def _file_88() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Float": {},\n        "String": {},\n    '
    out += '    "Query": {}\n    }\n}'
    return out^


def _path_89() -> String:
    var out = String()
    out += "inline_fragment_type_coercion/TestOperation.graphql"
    return out^


def _file_89() -> String:
    var out = String()
    out += "query TestQuery {\n  foo {\n    foo\n    ... on Bar {\n     "
    out += " bar\n    }\n  }\n}\n"
    return out^


def _path_90() -> String:
    var out = String()
    out += "inline_fragment_type_coercion/used-coordinates.json.expected"
    return out^


def _file_90() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Foo": {},'
    out += '\n        "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_91() -> String:
    var out = String()
    out += "inline_fragment_with_include_directive/TestOperation.graphql"
    return out^


def _file_91() -> String:
    var out = String()
    out += "query TestQuery($withDetails: Boolean!, $skipHumanDetails: B"
    out += "oolean!) {\n  hero {\n    id\n    ... on Human @include(if: "
    out += "$withDetails) @skip(if: $skipHumanDetails) {\n      name\n  "
    out += "    homePlanet\n    }\n    ... on Droid @include(if: $withDe"
    out += "tails) {\n      name\n      primaryFunction\n    }\n    ... "
    out += "on Character @include(if: $withDetails) {\n      name\n    }"
    out += "\n  }\n}\n"
    return out^


def _path_92() -> String:
    var out = String()
    out += "inline_fragment_with_include_directive/used-coordinates.json"
    out += ".expected"
    return out^


def _file_92() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "ID": {},\n       '
    out += ' "Query": {},\n        "Boolean": {}\n    }\n}'
    return out^


def _path_93() -> String:
    var out = String()
    out += "inline_fragments_with_friends/TestOperation.graphql"
    return out^


def _file_93() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n    ... on Human {\n "
    out += "     height\n      friends {\n        appearsIn\n      }\n  "
    out += "  }\n    ... on Droid {\n      primaryFunction\n      friend"
    out += "s {\n        id\n      }\n    }\n  }\n}"
    return out^


def _path_94() -> String:
    var out = String()
    out += "inline_fragments_with_friends/used-coordinates.json.expected"
    return out^


def _file_94() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Float": {},\n        "Episode": {},\n   '
    out += '     "String": {},\n        "ID": {},\n        "Query"'
    out += ": {}\n    }\n}"
    return out^


def _path_95() -> String:
    var out = String()
    out += "input_object_oneof/TestOperation.graphql"
    return out^


def _file_95() -> String:
    var out = String()
    out += "query FindUserQuery($findUserInput: FindUserInput!) {\n  fin"
    out += "dUser(findUserInput: $findUserInput) {\n    id\n  }\n}"
    return out^


def _path_96() -> String:
    var out = String()
    out += "input_object_oneof/schema.graphqls"
    return out^


def _file_96() -> String:
    var out = String()
    out += "input FindUserInput @oneOf {\n  email: String\n  name: Strin"
    out += "g\n  identity: FindUserBySocialNetworkInput\n  friends: Find"
    out += "UserByFriendInput\n}\n\ninput FindUserBySocialNetworkInput @"
    out += "oneOf {\n  facebookId: String\n  googleId: String\n}\n\ninpu"
    out += "t FindUserByFriendInput {\n  socialNetworkId: ID!\n  friendI"
    out += "d: ID!\n}\n\ntype User {\n  id: ID!\n}\n\ntype Query {\n  fi"
    out += "ndUser(findUserInput: FindUserInput!): User\n}"
    return out^


def _path_97() -> String:
    var out = String()
    out += "input_object_oneof/used-coordinates.json.expected"
    return out^


def _file_97() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "User": {},'
    out += '\n        "Query": {\n            "findUser": [\n       '
    out += '         "findUserInput"\n            ]\n        },\n     '
    out += '   "ID": {},\n        "FindUserInput": {},\n        "St'
    out += 'ring": {},\n        "FindUserBySocialNetworkInput": {},\n'
    out += '        "FindUserByFriendInput": {}\n    }\n}'
    return out^


def _path_98() -> String:
    var out = String()
    out += "input_object_type/TestOperation.graphql"
    return out^


def _file_98() -> String:
    var out = String()
    out += "mutation TestQuery($ep: Episode!, $review: ReviewInput!) {\n"
    out += "  createReview(episode: $ep, review: $review) {\n    stars\n"
    out += "    commentary\n  }\n}\n"
    return out^


def _path_99() -> String:
    var out = String()
    out += "input_object_type/used-coordinates.json.expected"
    return out^


def _file_99() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Review": {'
    out += '},\n        "Mutation": {\n            "createReview": ['
    out += '\n                "episode",\n                "review"\n'
    out += '            ]\n        },\n        "Int": {},\n        "S'
    out += 'tring": {},\n        "Episode": {},\n        "ReviewInpu'
    out += 't": {},\n        "colorInput": {},\n        "Date": {},'
    out += '\n        "Boolean": {},\n        "Float": {},\n        '
    out += '"ReviewRefInput": {}\n    }\n}'
    return out^


def _path_100() -> String:
    var out = String()
    out += "input_object_variable_and_argument/TestOperation.graphql"
    return out^


def _file_100() -> String:
    var out = String()
    out += "# An input object variable as well as argument\nquery TestQu"
    out += "ery($episode: Episode, $stars: Int!, $greenValue: Float!) {"
    out += "\n  heroWithReview (\n    episode: $episode,\n    review: {"
    out += "\n      stars: $stars,\n      favoriteColor: {\n        red:"
    out += " 0\n        green: $greenValue\n        blue: 0\n      }\n  "
    out += "    booleanNonOptional: false\n      listOfStringNonOptional"
    out += ": []\n    },\n    listOfInts: [$stars, $stars]\n  ) {\n    n"
    out += "ame\n    height(unit: FOOT)\n  }\n}\n"
    return out^


def _path_101() -> String:
    var out = String()
    out += "input_object_variable_and_argument/used-coordinates.json.exp"
    out += "ected"
    return out^


def _file_101() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Human": {'
    out += '\n            "height": [\n                "unit"\n     '
    out += '       ]\n        },\n        "Query": {\n            "he'
    out += 'roWithReview": [\n                "episode",\n           '
    out += '     "review",\n                "listOfInts"\n          '
    out += '  ]\n        },\n        "String": {},\n        "Float":'
    out += ' {},\n        "Episode": {},\n        "Int": {},\n      '
    out += '  "Character": {}\n    }\n}'
    return out^


def _path_102() -> String:
    var out = String()
    out += "input_object_variable_and_argument_with_generated_methods/Te"
    out += "stOperation.graphql"
    return out^


def _file_102() -> String:
    var out = String()
    out += "# An input object variable as well as argument\nquery TestQu"
    out += "ery($episode: Episode, $stars: Int!, $greenValue: Float!) {"
    out += "\n  heroWithReview (\n    episode: $episode,\n    review: {"
    out += "\n      stars: $stars,\n      favoriteColor: {\n        red:"
    out += " 0\n        green: $greenValue\n        blue: 0\n      }\n  "
    out += "    booleanNonOptional: false\n      listOfStringNonOptional"
    out += ": []\n    },\n    listOfInts: [$stars, $stars]\n  ) {\n    n"
    out += "ame\n    height(unit: FOOT)\n  }\n}\n"
    return out^


def _path_103() -> String:
    var out = String()
    out += "input_object_variable_and_argument_with_generated_methods/us"
    out += "ed-coordinates.json.expected"
    return out^


def _file_103() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Human": {'
    out += '\n            "height": [\n                "unit"\n     '
    out += '       ]\n        },\n        "Query": {\n            "he'
    out += 'roWithReview": [\n                "episode",\n           '
    out += '     "review",\n                "listOfInts"\n          '
    out += '  ]\n        },\n        "String": {},\n        "Float":'
    out += ' {},\n        "Episode": {},\n        "Int": {},\n      '
    out += '  "Character": {}\n    }\n}'
    return out^


def _path_104() -> String:
    var out = String()
    out += "interface_always_nested/TestOperation.graphql"
    return out^


def _file_104() -> String:
    var out = String()
    out += "# The B interface is only used from A so we don't really nee"
    out += "d a B interface even if some concrete types map to it\n# Hav"
    out += "ing AB should be enough\nquery TestQuery {\n    root {\n    "
    out += "    ... on A {\n            fieldA1\n            ... on B {"
    out += "\n                fieldB1\n            }\n        }\n    }\n"
    out += "}\n"
    return out^


def _path_105() -> String:
    var out = String()
    out += "interface_always_nested/schema.graphqls"
    return out^


def _file_105() -> String:
    var out = String()
    out += "type Query {\n  root: C\n}\n\ninterface A {\n  fieldA1: Stri"
    out += "ng\n  fieldA2: String\n}\n\ninterface B {\n  fieldB1: String"
    out += "\n  fieldB2: String\n}\ninterface C {\n  fieldC: String\n}\n"
    out += "\ntype ABC implements A & B & C {\n  fieldA1: String\n  fiel"
    out += "dA2: String\n  fieldB1: String\n  fieldB2: String\n  fieldC:"
    out += " String\n}\n\ntype AC implements A & C {\n  fieldA1: String"
    out += "\n  fieldA2: String\n  fieldC: String\n}\n\ntype BC implemen"
    out += "ts B & C {\n  fieldB1: String\n  fieldB2: String\n  fieldC: "
    out += "String\n}\n\ntype SomeC implements C {\n  fieldC: String\n}"
    out += "\n"
    return out^


def _path_106() -> String:
    var out = String()
    out += "interface_always_nested/used-coordinates.json.expected"
    return out^


def _file_106() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "C": {},\n '
    out += '       "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_107() -> String:
    var out = String()
    out += "introspection_query/TestOperation.graphql"
    return out^


def _file_107() -> String:
    var out = String()
    out += "query TestQuery {\n  __schema {\n    queryType {\n      name"
    out += "\n    }\n    types {\n      name\n    }\n  }\n  __type(name:"
    out += ' "Vehicle") {\n    name\n    kind\n  }\n}\n'
    return out^


def _path_108() -> String:
    var out = String()
    out += "introspection_query/used-coordinates.json.expected"
    return out^


def _file_108() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "__Schema":'
    out += ' {},\n        "__Type": {},\n        "Query": {\n       '
    out += '     "__type": [\n                "name"\n            ]'
    out += '\n        },\n        "String": {},\n        "__TypeKind'
    out += '": {}\n    }\n}'
    return out^


def _path_109() -> String:
    var out = String()
    out += "java8annotation/TestOperation.graphql"
    return out^


def _file_109() -> String:
    var out = String()
    out += "\nmutation LoginBarber($input: Login!) {\n  login(input: $in"
    out += "put) {\n    response\n  }\n}"
    return out^


def _path_110() -> String:
    var out = String()
    out += "java8annotation/schema.graphqls"
    return out^


def _file_110() -> String:
    var out = String()
    out += "type Query {\n  unused: Int\n}\n\ninput Login {\n  email: St"
    out += "ring!\n}\n\ntype Mutation {\n  login(input: Login!): User!\n"
    out += "}\n\ntype User {\n  response: String!\n}"
    return out^


def _path_111() -> String:
    var out = String()
    out += "java8annotation/used-coordinates.json.expected"
    return out^


def _file_111() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "User": {},'
    out += '\n        "Mutation": {\n            "login": [\n       '
    out += '         "input"\n            ]\n        },\n        "Str'
    out += 'ing": {},\n        "Login": {}\n    }\n}'
    return out^


def _path_112() -> String:
    var out = String()
    out += "java_android_annotations/TestOperation.graphql"
    return out^


def _file_112() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_113() -> String:
    var out = String()
    out += "java_android_annotations/schema.graphqls"
    return out^


def _file_113() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_114() -> String:
    var out = String()
    out += "java_android_annotations/used-coordinates.json.expected"
    return out^


def _file_114() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_115() -> String:
    var out = String()
    out += "java_apollo_optionals/TestOperation.graphql"
    return out^


def _file_115() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_116() -> String:
    var out = String()
    out += "java_apollo_optionals/schema.graphqls"
    return out^


def _file_116() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_117() -> String:
    var out = String()
    out += "java_apollo_optionals/used-coordinates.json.expected"
    return out^


def _file_117() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_118() -> String:
    var out = String()
    out += "java_guava_optionals/TestOperation.graphql"
    return out^


def _file_118() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_119() -> String:
    var out = String()
    out += "java_guava_optionals/schema.graphqls"
    return out^


def _file_119() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_120() -> String:
    var out = String()
    out += "java_guava_optionals/used-coordinates.json.expected"
    return out^


def _file_120() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_121() -> String:
    var out = String()
    out += "java_hashcode/TestOperation.graphql"
    return out^


def _file_121() -> String:
    var out = String()
    out += "query TestQuery {\n  h\n}\n\n"
    return out^


def _path_122() -> String:
    var out = String()
    out += "java_hashcode/schema.graphqls"
    return out^


def _file_122() -> String:
    var out = String()
    out += "type Query {\n  h: Int\n}\n"
    return out^


def _path_123() -> String:
    var out = String()
    out += "java_hashcode/used-coordinates.json.expected"
    return out^


def _file_123() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {}\n    }\n}'
    return out^


def _path_124() -> String:
    var out = String()
    out += "java_java_optionals/TestOperation.graphql"
    return out^


def _file_124() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_125() -> String:
    var out = String()
    out += "java_java_optionals/schema.graphqls"
    return out^


def _file_125() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_126() -> String:
    var out = String()
    out += "java_java_optionals/used-coordinates.json.expected"
    return out^


def _file_126() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_127() -> String:
    var out = String()
    out += "java_jetbrains_annotations/TestOperation.graphql"
    return out^


def _file_127() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_128() -> String:
    var out = String()
    out += "java_jetbrains_annotations/schema.graphqls"
    return out^


def _file_128() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_129() -> String:
    var out = String()
    out += "java_jetbrains_annotations/used-coordinates.json.expected"
    return out^


def _file_129() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_130() -> String:
    var out = String()
    out += "java_jsr305_annotations/TestOperation.graphql"
    return out^


def _file_130() -> String:
    var out = String()
    out += "query MyQuery(\n  $nullableInt: Int,\n  $nonNullableInt: Int"
    out += "!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $nullableInpu"
    out += "t: MyInput,\n  $nonNullableInput: MyInput!,\n  $nonNullableI"
    out += "nputWithDefault: MyInput! = {nonNullableInt: 4},\n) {\n  nul"
    out += "lableInt(nullableInt: $nullableInt, nonNullableInt: $nonNull"
    out += "ableInt, nonNullableIntWithDefault: $nonNullableIntWithDefau"
    out += "lt, nullableInput: $nullableInput, nonNullableInput: $nonNul"
    out += "lableInput, nonNullableInputWithDefault: $nonNullableInputWi"
    out += "thDefault)\n  nonNullableInt(nullableInt: $nullableInt, nonN"
    out += "ullableInt: $nonNullableInt, nonNullableIntWithDefault: $non"
    out += "NullableIntWithDefault, nullableInput: $nullableInput, nonNu"
    out += "llableInput: $nonNullableInput, nonNullableInputWithDefault:"
    out += " $nonNullableInputWithDefault)\n  nullableMyType {\n    null"
    out += "ableInt\n    nonNullableInt\n  }\n  nonNullableMyType {\n   "
    out += " nullableInt\n    nonNullableInt\n  }\n  nullableListOfNulla"
    out += "bleString\n  nullableListOfNonNullableString\n}\n\n"
    return out^


def _path_131() -> String:
    var out = String()
    out += "java_jsr305_annotations/schema.graphqls"
    return out^


def _file_131() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n  nullableListOfNullableString: [String]\n  nu"
    out += "llableListOfNonNullableString: [String!]\n}\n\ninput MyInput"
    out += " {\n  nullableInt: Int\n  nonNullableInt: Int!\n  nonNullabl"
    out += "eIntWithDefault: Int! = 4\n}\n\ntype MyType {\n  nullableInt"
    out += ": Int\n  nonNullableInt: Int!\n}\n"
    return out^


def _path_132() -> String:
    var out = String()
    out += "java_jsr305_annotations/used-coordinates.json.expected"
    return out^


def _file_132() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "Stri'
    out += 'ng": {},\n        "MyInput": {}\n    }\n}'
    return out^


def _path_133() -> String:
    var out = String()
    out += "java_primitive_types/TestOperation.graphql"
    return out^


def _file_133() -> String:
    var out = String()
    out += "query JavaPrimitiveQuery(\n  $nullableInt: Int,\n  $nonNulla"
    out += "bleInt: Int!,\n  $nonNullableIntWithDefault: Int! = 4,\n  $n"
    out += "ullableInput: MyInput,\n  $nonNullableInput: MyInput!,\n  $n"
    out += "onNullableInputWithDefault: MyInput! = {nonNullableInt: 4},"
    out += "\n) {\n  nullableInt(nullableInt: $nullableInt, nonNullableI"
    out += "nt: $nonNullableInt, nonNullableIntWithDefault: $nonNullable"
    out += "IntWithDefault, nullableInput: $nullableInput, nonNullableIn"
    out += "put: $nonNullableInput, nonNullableInputWithDefault: $nonNul"
    out += "lableInputWithDefault)\n  nonNullableInt(nullableInt: $nulla"
    out += "bleInt, nonNullableInt: $nonNullableInt, nonNullableIntWithD"
    out += "efault: $nonNullableIntWithDefault, nullableInput: $nullable"
    out += "Input, nonNullableInput: $nonNullableInput, nonNullableInput"
    out += "WithDefault: $nonNullableInputWithDefault)\n  nullableMyType"
    out += " {\n    nullableInt\n    nonNullableInt\n  }\n  nonNullableM"
    out += "yType {\n    nullableInt\n    nonNullableInt\n  }\n}\n\n"
    return out^


def _path_134() -> String:
    var out = String()
    out += "java_primitive_types/schema.graphqls"
    return out^


def _file_134() -> String:
    var out = String()
    out += "type Query {\n  nullableInt(nullableInt: Int, nonNullableInt"
    out += ": Int!, nonNullableIntWithDefault: Int! = 4, nullableInput: "
    out += "MyInput, nonNullableInput: MyInput!, nonNullableInputWithDef"
    out += "ault: MyInput! = {nonNullableInt: 4}): Int\n  nonNullableInt"
    out += "(nullableInt: Int, nonNullableInt: Int!, nonNullableIntWithD"
    out += "efault: Int! = 4, nullableInput: MyInput, nonNullableInput: "
    out += "MyInput!, nonNullableInputWithDefault: MyInput! = {nonNullab"
    out += "leInt: 4}): Int!\n  nullableMyType: MyType\n  nonNullableMyT"
    out += "ype: MyType!\n}\n\ninput MyInput {\n  nullableInt: Int\n  no"
    out += "nNullableInt: Int!\n  nonNullableIntWithDefault: Int! = 4\n}"
    out += "\n\ntype MyType {\n  nullableInt: Int\n  nonNullableInt: Int"
    out += "!\n}\n"
    return out^


def _path_135() -> String:
    var out = String()
    out += "java_primitive_types/used-coordinates.json.expected"
    return out^


def _file_135() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Int": {},'
    out += '\n        "Query": {\n            "nullableInt": [\n    '
    out += '            "nullableInt",\n                "nonNullableI'
    out += 'nt",\n                "nonNullableIntWithDefault",\n     '
    out += '           "nullableInput",\n                "nonNullable'
    out += 'Input",\n                "nonNullableInputWithDefault"\n '
    out += '           ],\n            "nonNullableInt": [\n          '
    out += '      "nullableInt",\n                "nonNullableInt",'
    out += '\n                "nonNullableIntWithDefault",\n          '
    out += '      "nullableInput",\n                "nonNullableInput'
    out += '",\n                "nonNullableInputWithDefault"\n      '
    out += '      ]\n        },\n        "MyType": {},\n        "MyIn'
    out += 'put": {}\n    }\n}'
    return out^


def _path_136() -> String:
    var out = String()
    out += "list_field_clash/TestOperation.graphql"
    return out^


def _file_136() -> String:
    var out = String()
    out += "query TestQuery {\n  amenityCategories {\n    text\n  }\n  c"
    out += "ategory\n}\n"
    return out^


def _path_137() -> String:
    var out = String()
    out += "list_field_clash/schema.graphqls"
    return out^


def _file_137() -> String:
    var out = String()
    out += "# https://github.com/apollographql/apollo-kotlin/issues/1156"
    out += "\ntype Query {\n  amenityCategories: [PropertyAmenityCategor"
    out += "y]\n  category: AmenityCategory\n}\n\ntype PropertyAmenityCa"
    out += "tegory {\n  text: String\n}\n\nenum AmenityCategory{\n  Cate"
    out += "gory0,\n  Category1\n}"
    return out^


def _path_138() -> String:
    var out = String()
    out += "list_field_clash/used-coordinates.json.expected"
    return out^


def _file_138() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "PropertyAme'
    out += 'nityCategory": {},\n        "AmenityCategory": {},\n     '
    out += '   "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_139() -> String:
    var out = String()
    out += "merged_include/TestOperation.graphql"
    return out^


def _file_139() -> String:
    var out = String()
    out += "query TestQuery {\n    hero {\n        name\n    }\n    hero"
    out += " @include(if: false) {\n        id\n    }\n}"
    return out^


def _path_140() -> String:
    var out = String()
    out += "merged_include/used-coordinates.json.expected"
    return out^


def _file_140() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "ID": {},\n       '
    out += ' "Query": {}\n    }\n}'
    return out^


def _path_141() -> String:
    var out = String()
    out += "multiple_fragments/TestOperation.graphql"
    return out^


def _file_141() -> String:
    var out = String()
    out += "query TestQuery {\n    a {\n        ...aFragment\n    }\n}\n"
    out += "\nfragment aFragment on A {\n    node {\n        ...fragment"
    out += "1\n        ...fragment2\n    }\n}\nfragment fragment1 on ANo"
    out += "de {\n    field1\n}\n\nfragment fragment2 on ANode {\n    fi"
    out += "eld2\n}"
    return out^


def _path_142() -> String:
    var out = String()
    out += "multiple_fragments/schema.graphqls"
    return out^


def _file_142() -> String:
    var out = String()
    out += "type Query {\n    a: A\n}\n\ntype A {\n    node: Node\n}\n\n"
    out += "interface Node {\n    field1: String,\n}\n\ntype ANode imple"
    out += "ments Node {\n    field1: String,\n    field2: String,\n    "
    out += "field3: String,\n}\n\ntype BNode implements Node {\n    fiel"
    out += "d1: String,\n    field2: String,\n    field4: String,\n}"
    return out^


def _path_143() -> String:
    var out = String()
    out += "multiple_fragments/used-coordinates.json.expected"
    return out^


def _file_143() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "A": {},\n '
    out += '       "String": {},\n        "Query": {},\n        "No'
    out += 'de": {},\n        "ANode": {}\n    }\n}'
    return out^


def _path_144() -> String:
    var out = String()
    out += "mutation_create_review/TestOperation.graphql"
    return out^


def _file_144() -> String:
    var out = String()
    out += "mutation CreateReviewForEpisode($ep: Episode!, $review: Revi"
    out += "ewInput!) {\n  createReview(episode: $ep, review: $review) {"
    out += "\n    stars\n    commentary\n    listOfListOfString,\n    li"
    out += "stOfListOfEnum,\n    listOfListOfCustom,\n    listOfListOfOb"
    out += "ject {\n      name\n    }\n  }\n}\n"
    return out^


def _path_145() -> String:
    var out = String()
    out += "mutation_create_review/used-coordinates.json.expected"
    return out^


def _file_145() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Review": {'
    out += '\n            "stars": [],\n            "commentary": []'
    out += ',\n            "listOfListOfString": [],\n            "li'
    out += 'stOfListOfEnum": [],\n            "listOfListOfCustom": ['
    out += '],\n            "listOfListOfObject": []\n        },\n    '
    out += '    "Mutation": {\n            "createReview": [\n      '
    out += '          "episode",\n                "review"\n        '
    out += '    ]\n        },\n        "Int": {},\n        "String":'
    out += ' {},\n        "Episode": {},\n        "Date": {},\n     '
    out += '   "Character": {\n            "name": []\n        },\n '
    out += '       "ReviewInput": {},\n        "colorInput": {},\n  '
    out += '      "Boolean": {},\n        "Float": {},\n        "Re'
    out += 'viewRefInput": {}\n    }\n}'
    return out^


def _path_146() -> String:
    var out = String()
    out += "mutation_create_review_semantic_naming/TestOperation.graphql"
    return out^


def _file_146() -> String:
    var out = String()
    out += "mutation CreateReviewForEpisode($ep: Episode!, $review: Revi"
    out += "ewInput!) {\n  createReview(episode: $ep, review: $review) {"
    out += "\n    stars\n    commentary\n  }\n}"
    return out^


def _path_147() -> String:
    var out = String()
    out += "mutation_create_review_semantic_naming/used-coordinates.json"
    out += ".expected"
    return out^


def _file_147() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Review": {'
    out += '},\n        "Mutation": {\n            "createReview": ['
    out += '\n                "episode",\n                "review"\n'
    out += '            ]\n        },\n        "Int": {},\n        "S'
    out += 'tring": {},\n        "Episode": {},\n        "ReviewInpu'
    out += 't": {},\n        "colorInput": {},\n        "Date": {},'
    out += '\n        "Boolean": {},\n        "Float": {},\n        '
    out += '"ReviewRefInput": {}\n    }\n}'
    return out^


def _path_148() -> String:
    var out = String()
    out += "named_fragment_delegate/TestOperation.graphql"
    return out^


def _file_148() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ...DroidDetails\n    ...Hum"
    out += "anDetails\n  }\n}\n\nfragment DroidDetails on Droid {\n  nam"
    out += "e\n  primaryFunction\n  friends {\n    name\n  }\n}\n\nfragm"
    out += "ent HumanDetails on Human {\n  name\n  profileLink\n  friend"
    out += "sConnection {\n    edges {\n      node {\n        name\n    "
    out += "  }\n    }\n  }\n}\n"
    return out^


def _path_149() -> String:
    var out = String()
    out += "named_fragment_delegate/used-coordinates.json.expected"
    return out^


def _file_149() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Droid": {},\n        "URL": {},\n        "FriendsC'
    out += 'onnection": {},\n        "FriendsEdge": {},\n        "Hu'
    out += 'man": {}\n    }\n}'
    return out^


def _path_150() -> String:
    var out = String()
    out += "named_fragment_inside_inline_fragment/TestOperation.graphql"
    return out^


def _file_150() -> String:
    var out = String()
    out += "query GetHero {\n  hero {\n    ... on Character {\n      ..."
    out += "characterName\n      ...characterAppearsIn\n    }\n  }\n}\n"
    out += "\nfragment characterName on Character {\n  name\n}\n\nfragme"
    out += "nt characterAppearsIn on Character {\n  appearsIn\n}\n"
    return out^


def _path_151() -> String:
    var out = String()
    out += "named_fragment_inside_inline_fragment/used-coordinates.json."
    out += "expected"
    return out^


def _file_151() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Episode": {}\n    }\n}'
    return out^


def _path_152() -> String:
    var out = String()
    out += "named_fragment_with_variables/TestOperation.graphql"
    return out^


def _file_152() -> String:
    var out = String()
    out += "query GetUser($organizationId: String!, $query: UserQuery!, "
    out += "$size: Int! ) {\n  ...QueryFragment\n}\n\nfragment QueryFrag"
    out += "ment on Query {\n  organization(id: $organizationId) {\n    "
    out += "id\n    user(query: $query) {\n      ...UserFragment\n    }"
    out += "\n  }\n}\n\nfragment UserFragment on User {\n  firstName\n  "
    out += "lastName\n  avatar(size: $size)\n}"
    return out^


def _path_153() -> String:
    var out = String()
    out += "named_fragment_with_variables/schema.graphqls"
    return out^


def _file_153() -> String:
    var out = String()
    out += "type Query {\n  organization(id: String!): Organization\n}\n"
    out += "\ntype Organization {\n  id: String!\n  name: String!\n  use"
    out += "r(query: UserQuery!): [User!]!\n}\n\ninput UserQuery {\n  na"
    out += "me: String!\n  isAdmin: Boolean\n}\n\ntype User {\n  firstNa"
    out += "me: String!\n  lastName: String!\n  birthDate: String!\n  av"
    out += "atar(size: Int!): String!\n}"
    return out^


def _path_154() -> String:
    var out = String()
    out += "named_fragment_with_variables/used-coordinates.json.expected"
    return out^


def _file_154() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "String": {'
    out += '},\n        "Query": {\n            "organization": [\n '
    out += '               "id"\n            ]\n        },\n        "'
    out += 'UserQuery": {},\n        "Int": {},\n        "Organizati'
    out += 'on": {\n            "user": [\n                "query"'
    out += '\n            ]\n        },\n        "User": {\n          '
    out += '  "avatar": [\n                "size"\n            ]\n  '
    out += '      },\n        "Boolean": {}\n    }\n}'
    return out^


def _path_155() -> String:
    var out = String()
    out += "named_fragment_without_implementation/TestOperation.graphql"
    return out^


def _file_155() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n    ...HumanDetails\n"
    out += "    ...DroidDetails\n  }\n}\n\nfragment HumanDetails on Huma"
    out += "n {\n  height\n}\n\nfragment DroidDetails on Droid {\n  prim"
    out += "aryFunction\n}\n"
    return out^


def _path_156() -> String:
    var out = String()
    out += "named_fragment_without_implementation/used-coordinates.json."
    out += "expected"
    return out^


def _file_156() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Float": {},\n        "Human": {},\n        "Droid'
    out += '": {}\n    }\n}'
    return out^


def _path_157() -> String:
    var out = String()
    out += "nested_conditional_inline/TestOperation.graphql"
    return out^


def _file_157() -> String:
    var out = String()
    out += "query TestQuery($episode: Episode) {\n  hero(episode: $episo"
    out += "de) {\n    name\n    ... on Human {\n      friends {\n      "
    out += "  name\n        ... on Human {\n          height(unit: FOOT)"
    out += "\n        }\n      }\n    }\n    ... on Droid {\n      frien"
    out += "ds {\n        name\n        ... on Human {\n          height"
    out += "(unit: METER)\n        }\n      }\n    }\n  }\n}\n"
    return out^


def _path_158() -> String:
    var out = String()
    out += "nested_conditional_inline/used-coordinates.json.expected"
    return out^


def _file_158() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'Float": {},\n        "Human": {\n            "height": '
    out += '[\n                "unit"\n            ]\n        },\n    '
    out += '    "String": {},\n        "Episode": {}\n    }\n}'
    return out^


def _path_159() -> String:
    var out = String()
    out += "nested_field_with_multiple_fieldsets/TestOperation.graphql"
    return out^


def _file_159() -> String:
    var out = String()
    out += "# when generating the implementations of a nested field, it'"
    out += "s important to inherit from the most qualified parent interf"
    out += "ace\n# In that case `Impl2Iface2`. Else we not have access t"
    out += "o scalar2 from interfaces\n# i.e with\n#    data.iface1\n#  "
    out += "      .asImpl1()\n#        .iface2\n#        .asImpl2Iface2("
    out += ") // <= this will cast to Impl2Iface2 so the interface needs"
    out += " to be implemented\n#        .scalar2\n#\n# This sample also"
    out += " demonstrate why we generate accessors as companion objects "
    out += "instead of using default interface methods.\n# In that case,"
    out += " asImpl2 is both in Iface1.Iface2 and Impl1Iface1.IFace2 and"
    out += " using default interface methods would yield\n# Class 'Impl1"
    out += "Iface1.Impl2IFace2' must override public open fun asImpl2() "
    out += "because it inherits multiple interface methods of it\nquery "
    out += "TestQuery {\n    iface1 {\n      ... on Iface1 {\n          "
    out += "iface2 {\n              ... on Iface2 {\n                  s"
    out += "calar1\n              }\n              ... on Impl2 {\n     "
    out += "             scalar2\n              }\n          }\n      }"
    out += "\n      ... on Impl1 {\n          iface2 {\n              .."
    out += ". on Iface2 {\n                  scalar3\n              }\n "
    out += "             ... on Impl2 {\n                  scalar4\n    "
    out += "          }\n          }\n      }\n    }\n}"
    return out^


def _path_160() -> String:
    var out = String()
    out += "nested_field_with_multiple_fieldsets/schema.graphqls"
    return out^


def _file_160() -> String:
    var out = String()
    out += "type Query {\n  iface1: Iface1\n}\n\ninterface Iface1 {\n  i"
    out += "face2: Iface2\n}\n\ntype Impl1 implements Iface1 {\n  iface2"
    out += ": Iface2\n}\n\ninterface Iface2 {\n  scalar1: String\n  scal"
    out += "ar3: String\n}\n\ntype Impl2 implements Iface2 {\n  scalar1:"
    out += " String\n  scalar2: String\n  scalar3: String\n  scalar4: St"
    out += "ring\n}\n"
    return out^


def _path_161() -> String:
    var out = String()
    out += "nested_field_with_multiple_fieldsets/used-coordinates.json.e"
    out += "xpected"
    return out^


def _file_161() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Iface1": {'
    out += '},\n        "Iface2": {},\n        "String": {},\n      '
    out += '  "Query": {}\n    }\n}'
    return out^


def _path_162() -> String:
    var out = String()
    out += "nested_named_fragments/TestOperation.graphql"
    return out^


def _file_162() -> String:
    var out = String()
    out += "# A named fragment that includes another one\nquery AllStars"
    out += "hips {\n  allStarships(first: 7) {\n    edges {\n      node "
    out += "{\n        ...starshipFragment\n      }\n    }\n  }\n}\n\nfr"
    out += "agment starshipFragment on Starship {\n  id\n  name\n  pilot"
    out += "Connection {\n    edges {\n      node {\n        ...pilotFra"
    out += "gment\n      }\n    }\n  }\n}\n\nfragment pilotFragment on P"
    out += "erson {\n  name\n  homeworld {\n    ...planetFragment\n  }\n"
    out += "}\n\nfragment planetFragment on Planet {\n  name\n}\n"
    return out^


def _path_163() -> String:
    var out = String()
    out += "nested_named_fragments/schema.graphqls"
    return out^


def _file_163() -> String:
    var out = String()
    out += 'schema {\n  query: Root\n}\n\n"""A single film."""\nty'
    out += "pe Film implements Node {\n  characterConnection(after: Stri"
    out += "ng, first: Int, before: String, last: Int): FilmCharactersCo"
    out += 'nnection\n\n  """The ISO 8601 date format of the time tha'
    out += 't this resource was created."""\n  created: String\n\n  '
    out += '"""The name of the director of this film."""\n  direct'
    out += 'or: String\n\n  """The ISO 8601 date format of the time t'
    out += 'hat this resource was edited."""\n  edited: String\n\n  '
    out += '"""The episode number of this film."""\n  episodeID: I'
    out += 'nt\n\n  """The ID of an object"""\n  id: ID!\n\n  ""'
    out += '"The opening paragraphs at the beginning of this film.""'
    out += '"\n  openingCrawl: String\n  planetConnection(after: String'
    out += ", first: Int, before: String, last: Int): FilmPlanetsConnect"
    out += 'ion\n\n  """The name(s) of the producer(s) of this film.'
    out += '"""\n  producers: [String]\n\n  """The ISO 8601 date f'
    out += 'ormat of film release at original creator country."""\n  '
    out += "releaseDate: String\n  speciesConnection(after: String, firs"
    out += "t: Int, before: String, last: Int): FilmSpeciesConnection\n "
    out += " starshipConnection(after: String, first: Int, before: Strin"
    out += 'g, last: Int): FilmStarshipsConnection\n\n  """The title '
    out += 'of this film."""\n  title: String\n  vehicleConnection(af'
    out += "ter: String, first: Int, before: String, last: Int): FilmVeh"
    out += 'iclesConnection\n}\n\n"""A connection to a list of items.'
    out += '"""\ntype FilmCharactersConnection {\n  """\n  A list '
    out += "of all of the objects returned in the connection. This is a "
    out += "convenience\n  field provided for quickly exploring the API;"
    out += ' rather than querying for\n  "{ edges { node } }" when no '
    out += "edge data is needed, this field can be be used\n  instead. N"
    out += 'ote that when clients like Relay need to fetch the "cursor'
    out += '" field on\n  the edge to enable efficient pagination, this'
    out += ' shortcut cannot be used, and the\n  full "{ edges { node }'
    out += ' }" version should be used instead.\n  """\n  characters'
    out += ': [Person]\n\n  """A list of edges."""\n  edges: [Film'
    out += 'CharactersEdge]\n\n  """Information to aid in pagination.'
    out += '"""\n  pageInfo: PageInfo!\n\n  """\n  A count of the '
    out += "total number of objects in this connection, ignoring paginat"
    out += "ion.\n  This allows a client to fetch the first five objects"
    out += ' by passing "5" as the\n  argument to "first", then fetc'
    out += 'h the total count so it could display "5 of 83",\n  for ex'
    out += 'ample.\n  """\n  totalCount: Int\n}\n\n"""An edge in a'
    out += ' connection."""\ntype FilmCharactersEdge {\n  """A cur'
    out += 'sor for use in pagination"""\n  cursor: String!\n\n  ""'
    out += '"The item at the end of the edge"""\n  node: Person\n}\n'
    out += '\n"""A connection to a list of items."""\ntype FilmPla'
    out += 'netsConnection {\n  """A list of edges."""\n  edges: ['
    out += 'FilmPlanetsEdge]\n\n  """Information to aid in pagination'
    out += '."""\n  pageInfo: PageInfo!\n\n  """\n  A list of all '
    out += "of the objects returned in the connection. This is a conveni"
    out += "ence\n  field provided for quickly exploring the API; rather"
    out += ' than querying for\n  "{ edges { node } }" when no edge da'
    out += "ta is needed, this field can be be used\n  instead. Note tha"
    out += 't when clients like Relay need to fetch the "cursor" field'
    out += " on\n  the edge to enable efficient pagination, this shortcu"
    out += 't cannot be used, and the\n  full "{ edges { node } }" ver'
    out += 'sion should be used instead.\n  """\n  planets: [Planet]'
    out += '\n\n  """\n  A count of the total number of objects in th'
    out += "is connection, ignoring pagination.\n  This allows a client "
    out += 'to fetch the first five objects by passing "5" as the\n  a'
    out += 'rgument to "first", then fetch the total count so it could'
    out += ' display "5 of 83",\n  for example.\n  """\n  totalCoun'
    out += 't: Int\n}\n\n"""An edge in a connection."""\ntype Film'
    out += 'PlanetsEdge {\n  """A cursor for use in pagination"""'
    out += '\n  cursor: String!\n\n  """The item at the end of the ed'
    out += 'ge"""\n  node: Planet\n}\n\n"""A connection to a list '
    out += 'of items."""\ntype FilmsConnection {\n  """A list of e'
    out += 'dges."""\n  edges: [FilmsEdge]\n\n  """\n  A list of a'
    out += "ll of the objects returned in the connection. This is a conv"
    out += "enience\n  field provided for quickly exploring the API; rat"
    out += 'her than querying for\n  "{ edges { node } }" when no edge'
    out += " data is needed, this field can be be used\n  instead. Note "
    out += 'that when clients like Relay need to fetch the "cursor" fi'
    out += "eld on\n  the edge to enable efficient pagination, this shor"
    out += 'tcut cannot be used, and the\n  full "{ edges { node } }" '
    out += 'version should be used instead.\n  """\n  films: [Film]\n'
    out += '\n  """Information to aid in pagination."""\n  pageInf'
    out += 'o: PageInfo!\n\n  """\n  A count of the total number of o'
    out += "bjects in this connection, ignoring pagination.\n  This allo"
    out += 'ws a client to fetch the first five objects by passing "5"'
    out += ' as the\n  argument to "first", then fetch the total count'
    out += ' so it could display "5 of 83",\n  for example.\n  """'
    out += '\n  totalCount: Int\n}\n\n"""An edge in a connection.""'
    out += '"\ntype FilmsEdge {\n  """A cursor for use in pagination'
    out += '"""\n  cursor: String!\n\n  """The item at the end of '
    out += 'the edge"""\n  node: Film\n}\n\n"""A connection to a l'
    out += 'ist of items."""\ntype FilmSpeciesConnection {\n  """A'
    out += ' list of edges."""\n  edges: [FilmSpeciesEdge]\n\n  ""'
    out += '"Information to aid in pagination."""\n  pageInfo: PageI'
    out += 'nfo!\n\n  """\n  A list of all of the objects returned in'
    out += " the connection. This is a convenience\n  field provided for"
    out += ' quickly exploring the API; rather than querying for\n  "{ '
    out += 'edges { node } }" when no edge data is needed, this field c'
    out += "an be be used\n  instead. Note that when clients like Relay "
    out += 'need to fetch the "cursor" field on\n  the edge to enable '
    out += "efficient pagination, this shortcut cannot be used, and the"
    out += '\n  full "{ edges { node } }" version should be used inste'
    out += 'ad.\n  """\n  species: [Species]\n\n  """\n  A count o'
    out += "f the total number of objects in this connection, ignoring p"
    out += "agination.\n  This allows a client to fetch the first five o"
    out += 'bjects by passing "5" as the\n  argument to "first", the'
    out += 'n fetch the total count so it could display "5 of 83",\n  '
    out += 'for example.\n  """\n  totalCount: Int\n}\n\n"""An edg'
    out += 'e in a connection."""\ntype FilmSpeciesEdge {\n  """A '
    out += 'cursor for use in pagination"""\n  cursor: String!\n\n  '
    out += '"""The item at the end of the edge"""\n  node: Species'
    out += '\n}\n\n"""A connection to a list of items."""\ntype Fi'
    out += 'lmStarshipsConnection {\n  """A list of edges."""\n  e'
    out += 'dges: [FilmStarshipsEdge]\n\n  """Information to aid in p'
    out += 'agination."""\n  pageInfo: PageInfo!\n\n  """\n  A lis'
    out += "t of all of the objects returned in the connection. This is "
    out += "a convenience\n  field provided for quickly exploring the AP"
    out += 'I; rather than querying for\n  "{ edges { node } }" when n'
    out += "o edge data is needed, this field can be be used\n  instead."
    out += ' Note that when clients like Relay need to fetch the "curso'
    out += 'r" field on\n  the edge to enable efficient pagination, thi'
    out += 's shortcut cannot be used, and the\n  full "{ edges { node '
    out += '} }" version should be used instead.\n  """\n  starships'
    out += ': [Starship]\n\n  """\n  A count of the total number of o'
    out += "bjects in this connection, ignoring pagination.\n  This allo"
    out += 'ws a client to fetch the first five objects by passing "5"'
    out += ' as the\n  argument to "first", then fetch the total count'
    out += ' so it could display "5 of 83",\n  for example.\n  """'
    out += '\n  totalCount: Int\n}\n\n"""An edge in a connection.""'
    out += '"\ntype FilmStarshipsEdge {\n  """A cursor for use in pa'
    out += 'gination"""\n  cursor: String!\n\n  """The item at the'
    out += ' end of the edge"""\n  node: Starship\n}\n\n"""A conne'
    out += 'ction to a list of items."""\ntype FilmVehiclesConnection'
    out += ' {\n  """A list of edges."""\n  edges: [FilmVehiclesEd'
    out += 'ge]\n\n  """Information to aid in pagination."""\n  pa'
    out += 'geInfo: PageInfo!\n\n  """\n  A count of the total number'
    out += " of objects in this connection, ignoring pagination.\n  This"
    out += " allows a client to fetch the first five objects by passing "
    out += '"5" as the\n  argument to "first", then fetch the total '
    out += 'count so it could display "5 of 83",\n  for example.\n  "'
    out += '""\n  totalCount: Int\n\n  """\n  A list of all of the '
    out += "objects returned in the connection. This is a convenience\n "
    out += " field provided for quickly exploring the API; rather than q"
    out += 'uerying for\n  "{ edges { node } }" when no edge data is n'
    out += "eeded, this field can be be used\n  instead. Note that when "
    out += 'clients like Relay need to fetch the "cursor" field on\n  '
    out += "the edge to enable efficient pagination, this shortcut canno"
    out += 't be used, and the\n  full "{ edges { node } }" version sh'
    out += 'ould be used instead.\n  """\n  vehicles: [Vehicle]\n}\n'
    out += '\n"""An edge in a connection."""\ntype FilmVehiclesEdg'
    out += 'e {\n  """A cursor for use in pagination"""\n  cursor:'
    out += ' String!\n\n  """The item at the end of the edge"""\n '
    out += ' node: Vehicle\n}\n\n"""An object with an ID"""\ninter'
    out += 'face Node {\n  """The id of the object."""\n  id: ID!'
    out += '\n}\n\n"""Information about pagination in a connection."'
    out += '""\ntype PageInfo {\n  """When paginating forwards, the'
    out += ' cursor to continue."""\n  endCursor: String\n\n  """W'
    out += 'hen paginating forwards, are there more items?"""\n  hasN'
    out += 'extPage: Boolean!\n\n  """When paginating backwards, are '
    out += 'there more items?"""\n  hasPreviousPage: Boolean!\n\n  "'
    out += '""When paginating backwards, the cursor to continue."""'
    out += '\n  startCursor: String\n}\n\n"""A connection to a list o'
    out += 'f items."""\ntype PeopleConnection {\n  """A list of e'
    out += 'dges."""\n  edges: [PeopleEdge]\n\n  """Information to'
    out += ' aid in pagination."""\n  pageInfo: PageInfo!\n\n  """'
    out += "\n  A list of all of the objects returned in the connection."
    out += " This is a convenience\n  field provided for quickly explori"
    out += 'ng the API; rather than querying for\n  "{ edges { node } }'
    out += '" when no edge data is needed, this field can be be used\n '
    out += " instead. Note that when clients like Relay need to fetch th"
    out += 'e "cursor" field on\n  the edge to enable efficient pagina'
    out += 'tion, this shortcut cannot be used, and the\n  full "{ edge'
    out += 's { node } }" version should be used instead.\n  """\n  '
    out += 'people: [Person]\n\n  """\n  A count of the total number '
    out += "of objects in this connection, ignoring pagination.\n  This "
    out += "allows a client to fetch the first five objects by passing "
    out += '"5" as the\n  argument to "first", then fetch the total '
    out += 'count so it could display "5 of 83",\n  for example.\n  "'
    out += '""\n  totalCount: Int\n}\n\n"""An edge in a connection.'
    out += '"""\ntype PeopleEdge {\n  """A cursor for use in pagin'
    out += 'ation"""\n  cursor: String!\n\n  """The item at the en'
    out += 'd of the edge"""\n  node: Person\n}\n\n"""An individua'
    out += 'l person or character within the Star Wars universe."""\n'
    out += 'type Person implements Node {\n  """\n  The birth year of'
    out += " the person, using the in-universe standard of BBY or ABY -"
    out += "\n  Before the Battle of Yavin or After the Battle of Yavin."
    out += " The Battle of Yavin is\n  a battle that occurs at the end o"
    out += 'f Star Wars episode IV: A New Hope.\n  """\n  birthYear: '
    out += 'String\n\n  """The ISO 8601 date format of the time that '
    out += 'this resource was created."""\n  created: String\n\n  "'
    out += '""The ISO 8601 date format of the time that this resource '
    out += 'was edited."""\n  edited: String\n\n  """\n  The eye c'
    out += 'olor of this person. Will be "unknown" if not known or "n'
    out += '/a" if the\n  person does not have an eye.\n  """\n  eye'
    out += "Color: String\n  filmConnection(after: String, first: Int, b"
    out += 'efore: String, last: Int): PersonFilmsConnection\n\n  """'
    out += '\n  The gender of this person. Either "Male", "Female" o'
    out += 'r "unknown",\n  "n/a" if the person does not have a gend'
    out += 'er.\n  """\n  gender: String\n\n  """\n  The hair colo'
    out += 'r of this person. Will be "unknown" if not known or "n/a'
    out += '" if the\n  person does not have hair.\n  """\n  hairCol'
    out += 'or: String\n\n  """The height of the person in centimeter'
    out += 's."""\n  height: Int\n\n  """A planet that this person'
    out += ' was born on or inhabits."""\n  homeworld: Planet\n\n  "'
    out += '""The ID of an object"""\n  id: ID!\n\n  """The mass'
    out += ' of the person in kilograms."""\n  mass: Int\n\n  """T'
    out += 'he name of this person."""\n  name: String\n\n  """The'
    out += ' skin color of this person."""\n  skinColor: String\n\n  '
    out += '"""The species that this person belongs to, or null if un'
    out += 'known."""\n  species: Species\n  starshipConnection(after'
    out += ": String, first: Int, before: String, last: Int): PersonStar"
    out += "shipsConnection\n  vehicleConnection(after: String, first: I"
    out += "nt, before: String, last: Int): PersonVehiclesConnection\n}"
    out += '\n\n"""A connection to a list of items."""\ntype Perso'
    out += 'nFilmsConnection {\n  """A list of edges."""\n  edges:'
    out += ' [PersonFilmsEdge]\n\n  """\n  A list of all of the objec'
    out += "ts returned in the connection. This is a convenience\n  fiel"
    out += "d provided for quickly exploring the API; rather than queryi"
    out += 'ng for\n  "{ edges { node } }" when no edge data is needed'
    out += ", this field can be be used\n  instead. Note that when clien"
    out += 'ts like Relay need to fetch the "cursor" field on\n  the e'
    out += "dge to enable efficient pagination, this shortcut cannot be "
    out += 'used, and the\n  full "{ edges { node } }" version should '
    out += 'be used instead.\n  """\n  films: [Film]\n\n  """Infor'
    out += 'mation to aid in pagination."""\n  pageInfo: PageInfo!\n'
    out += '\n  """\n  A count of the total number of objects in this'
    out += " connection, ignoring pagination.\n  This allows a client to"
    out += ' fetch the first five objects by passing "5" as the\n  arg'
    out += 'ument to "first", then fetch the total count so it could d'
    out += 'isplay "5 of 83",\n  for example.\n  """\n  totalCount:'
    out += ' Int\n}\n\n"""An edge in a connection."""\ntype Person'
    out += 'FilmsEdge {\n  """A cursor for use in pagination"""\n '
    out += ' cursor: String!\n\n  """The item at the end of the edge'
    out += '"""\n  node: Film\n}\n\n"""A connection to a list of i'
    out += 'tems."""\ntype PersonStarshipsConnection {\n  """A lis'
    out += 't of edges."""\n  edges: [PersonStarshipsEdge]\n\n  ""'
    out += '"Information to aid in pagination."""\n  pageInfo: PageI'
    out += 'nfo!\n\n  """\n  A list of all of the objects returned in'
    out += " the connection. This is a convenience\n  field provided for"
    out += ' quickly exploring the API; rather than querying for\n  "{ '
    out += 'edges { node } }" when no edge data is needed, this field c'
    out += "an be be used\n  instead. Note that when clients like Relay "
    out += 'need to fetch the "cursor" field on\n  the edge to enable '
    out += "efficient pagination, this shortcut cannot be used, and the"
    out += '\n  full "{ edges { node } }" version should be used inste'
    out += 'ad.\n  """\n  starships: [Starship]\n\n  """\n  A coun'
    out += "t of the total number of objects in this connection, ignorin"
    out += "g pagination.\n  This allows a client to fetch the first fiv"
    out += 'e objects by passing "5" as the\n  argument to "first", '
    out += 'then fetch the total count so it could display "5 of 83",'
    out += '\n  for example.\n  """\n  totalCount: Int\n}\n\n"""An'
    out += ' edge in a connection."""\ntype PersonStarshipsEdge {\n  '
    out += '"""A cursor for use in pagination"""\n  cursor: String'
    out += '!\n\n  """The item at the end of the edge"""\n  node: '
    out += 'Starship\n}\n\n"""A connection to a list of items."""'
    out += '\ntype PersonVehiclesConnection {\n  """A list of edges.'
    out += '"""\n  edges: [PersonVehiclesEdge]\n\n  """Information'
    out += ' to aid in pagination."""\n  pageInfo: PageInfo!\n\n  "'
    out += '""\n  A count of the total number of objects in this conne'
    out += "ction, ignoring pagination.\n  This allows a client to fetch"
    out += ' the first five objects by passing "5" as the\n  argument '
    out += 'to "first", then fetch the total count so it could display'
    out += ' "5 of 83",\n  for example.\n  """\n  totalCount: Int\n'
    out += '\n  """\n  A list of all of the objects returned in the c'
    out += "onnection. This is a convenience\n  field provided for quick"
    out += 'ly exploring the API; rather than querying for\n  "{ edges '
    out += '{ node } }" when no edge data is needed, this field can be '
    out += "be used\n  instead. Note that when clients like Relay need t"
    out += 'o fetch the "cursor" field on\n  the edge to enable effici'
    out += "ent pagination, this shortcut cannot be used, and the\n  ful"
    out += 'l "{ edges { node } }" version should be used instead.\n  '
    out += '"""\n  vehicles: [Vehicle]\n}\n\n"""An edge in a conne'
    out += 'ction."""\ntype PersonVehiclesEdge {\n  """A cursor fo'
    out += 'r use in pagination"""\n  cursor: String!\n\n  """The '
    out += 'item at the end of the edge"""\n  node: Vehicle\n}\n\n"'
    out += '""\nA large mass, planet or planetoid in the Star Wars Uni'
    out += 'verse, at the time of\n0 ABY.\n"""\ntype Planet implement'
    out += 's Node {\n  """The climates of this planet."""\n  clim'
    out += 'ates: [String]\n\n  """The ISO 8601 date format of the ti'
    out += 'me that this resource was created."""\n  created: String'
    out += '\n\n  """The diameter of this planet in kilometers."""'
    out += '\n  diameter: Int\n\n  """The ISO 8601 date format of the'
    out += ' time that this resource was edited."""\n  edited: String'
    out += "\n  filmConnection(after: String, first: Int, before: String"
    out += ', last: Int): PlanetFilmsConnection\n\n  """\n  A number '
    out += 'denoting the gravity of this planet, where "1" is normal o'
    out += 'r 1 standard\n  G. "2" is twice or 2 standard Gs. "0.5" '
    out += 'is half or 0.5 standard Gs.\n  """\n  gravity: String\n\n'
    out += '  """The ID of an object"""\n  id: ID!\n\n  """The '
    out += 'name of this planet."""\n  name: String\n\n  """\n  Th'
    out += "e number of standard days it takes for this planet to comple"
    out += 'te a single orbit\n  of its local star.\n  """\n  orbital'
    out += 'Period: Int\n\n  """The average population of sentient be'
    out += 'ings inhabiting this planet."""\n  population: Int\n  res'
    out += "identConnection(after: String, first: Int, before: String, l"
    out += 'ast: Int): PlanetResidentsConnection\n\n  """\n  The numb'
    out += "er of standard hours it takes for this planet to complete a "
    out += 'single\n  rotation on its axis.\n  """\n  rotationPeriod:'
    out += ' Int\n\n  """\n  The percentage of the planet surface tha'
    out += 't is naturally occuring water or bodies\n  of water.\n  ""'
    out += '"\n  surfaceWater: Float\n\n  """The terrains of this pl'
    out += 'anet."""\n  terrains: [String]\n}\n\n"""A connection t'
    out += 'o a list of items."""\ntype PlanetFilmsConnection {\n  "'
    out += '""A list of edges."""\n  edges: [PlanetFilmsEdge]\n\n  '
    out += '"""\n  A list of all of the objects returned in the conne'
    out += "ction. This is a convenience\n  field provided for quickly e"
    out += 'xploring the API; rather than querying for\n  "{ edges { no'
    out += 'de } }" when no edge data is needed, this field can be be u'
    out += "sed\n  instead. Note that when clients like Relay need to fe"
    out += 'tch the "cursor" field on\n  the edge to enable efficient '
    out += 'pagination, this shortcut cannot be used, and the\n  full "'
    out += '{ edges { node } }" version should be used instead.\n  ""'
    out += '"\n  films: [Film]\n\n  """Information to aid in paginat'
    out += 'ion."""\n  pageInfo: PageInfo!\n\n  """\n  A count of '
    out += "the total number of objects in this connection, ignoring pag"
    out += "ination.\n  This allows a client to fetch the first five obj"
    out += 'ects by passing "5" as the\n  argument to "first", then '
    out += 'fetch the total count so it could display "5 of 83",\n  fo'
    out += 'r example.\n  """\n  totalCount: Int\n}\n\n"""An edge '
    out += 'in a connection."""\ntype PlanetFilmsEdge {\n  """A cu'
    out += 'rsor for use in pagination"""\n  cursor: String!\n\n  "'
    out += '""The item at the end of the edge"""\n  node: Film\n}\n'
    out += '\n"""A connection to a list of items."""\ntype PlanetR'
    out += 'esidentsConnection {\n  """A list of edges."""\n  edge'
    out += 's: [PlanetResidentsEdge]\n\n  """Information to aid in pa'
    out += 'gination."""\n  pageInfo: PageInfo!\n\n  """\n  A list'
    out += " of all of the objects returned in the connection. This is a"
    out += " convenience\n  field provided for quickly exploring the API"
    out += '; rather than querying for\n  "{ edges { node } }" when no'
    out += " edge data is needed, this field can be be used\n  instead. "
    out += 'Note that when clients like Relay need to fetch the "cursor'
    out += '" field on\n  the edge to enable efficient pagination, this'
    out += ' shortcut cannot be used, and the\n  full "{ edges { node }'
    out += ' }" version should be used instead.\n  """\n  residents:'
    out += ' [Person]\n\n  """\n  A count of the total number of obje'
    out += "cts in this connection, ignoring pagination.\n  This allows "
    out += 'a client to fetch the first five objects by passing "5" as'
    out += ' the\n  argument to "first", then fetch the total count so'
    out += ' it could display "5 of 83",\n  for example.\n  """\n  '
    out += 'totalCount: Int\n}\n\n"""An edge in a connection."""\n'
    out += 'type PlanetResidentsEdge {\n  """A cursor for use in pagi'
    out += 'nation"""\n  cursor: String!\n\n  """The item at the e'
    out += 'nd of the edge"""\n  node: Person\n}\n\n"""A connectio'
    out += 'n to a list of items."""\ntype PlanetsConnection {\n  "'
    out += '""A list of edges."""\n  edges: [PlanetsEdge]\n\n  ""'
    out += '"Information to aid in pagination."""\n  pageInfo: PageI'
    out += 'nfo!\n\n  """\n  A list of all of the objects returned in'
    out += " the connection. This is a convenience\n  field provided for"
    out += ' quickly exploring the API; rather than querying for\n  "{ '
    out += 'edges { node } }" when no edge data is needed, this field c'
    out += "an be be used\n  instead. Note that when clients like Relay "
    out += 'need to fetch the "cursor" field on\n  the edge to enable '
    out += "efficient pagination, this shortcut cannot be used, and the"
    out += '\n  full "{ edges { node } }" version should be used inste'
    out += 'ad.\n  """\n  planets: [Planet]\n\n  """\n  A count of'
    out += " the total number of objects in this connection, ignoring pa"
    out += "gination.\n  This allows a client to fetch the first five ob"
    out += 'jects by passing "5" as the\n  argument to "first", then'
    out += ' fetch the total count so it could display "5 of 83",\n  f'
    out += 'or example.\n  """\n  totalCount: Int\n}\n\n"""An edge'
    out += ' in a connection."""\ntype PlanetsEdge {\n  """A curso'
    out += 'r for use in pagination"""\n  cursor: String!\n\n  """'
    out += 'The item at the end of the edge"""\n  node: Planet\n}\n\n'
    out += "type Root {\n  allFilms(after: String, first: Int, before: S"
    out += "tring, last: Int): FilmsConnection\n  allPeople(after: Strin"
    out += "g, first: Int, before: String, last: Int): PeopleConnection"
    out += "\n  allPlanets(after: String, first: Int, before: String, la"
    out += "st: Int): PlanetsConnection\n  allSpecies(after: String, fir"
    out += "st: Int, before: String, last: Int): SpeciesConnection\n  al"
    out += "lStarships(after: String, first: Int, before: String, last: "
    out += "Int): StarshipsConnection\n  allVehicles(after: String, firs"
    out += "t: Int, before: String, last: Int): VehiclesConnection\n  fi"
    out += 'lm(id: ID, filmID: ID): Film\n\n  """Fetches an object gi'
    out += 'ven its ID"""\n  node(\n    """The ID of an object""'
    out += '"\n    id: ID!\n  ): Node\n  person(id: ID, personID: ID): '
    out += "Person\n  planet(id: ID, planetID: ID): Planet\n  species(id"
    out += ": ID, speciesID: ID): Species\n  starship(id: ID, starshipID"
    out += ": ID): Starship\n  vehicle(id: ID, vehicleID: ID): Vehicle\n"
    out += '}\n\n"""A type of person or character within the Star War'
    out += 's Universe."""\ntype Species implements Node {\n  """T'
    out += 'he average height of this species in centimeters."""\n  a'
    out += 'verageHeight: Float\n\n  """The average lifespan of this '
    out += 'species in years, null if unknown."""\n  averageLifespan:'
    out += ' Int\n\n  """The classification of this species, such as '
    out += '"mammal" or "reptile"."""\n  classification: String\n'
    out += '\n  """The ISO 8601 date format of the time that this res'
    out += 'ource was created."""\n  created: String\n\n  """The d'
    out += 'esignation of this species, such as "sentient"."""\n  d'
    out += 'esignation: String\n\n  """The ISO 8601 date format of th'
    out += 'e time that this resource was edited."""\n  edited: Strin'
    out += 'g\n\n  """\n  Common eye colors for this species, null if'
    out += ' this species does not typically\n  have eyes.\n  """\n  '
    out += "eyeColors: [String]\n  filmConnection(after: String, first: "
    out += "Int, before: String, last: Int): SpeciesFilmsConnection\n\n "
    out += ' """\n  Common hair colors for this species, null if this'
    out += ' species does not typically\n  have hair.\n  """\n  hairC'
    out += 'olors: [String]\n\n  """A planet that this species origin'
    out += 'ates from."""\n  homeworld: Planet\n\n  """The ID of a'
    out += 'n object"""\n  id: ID!\n\n  """The language commonly s'
    out += 'poken by this species."""\n  language: String\n\n  """'
    out += 'The name of this species."""\n  name: String\n  personCon'
    out += "nection(after: String, first: Int, before: String, last: Int"
    out += '): SpeciesPeopleConnection\n\n  """\n  Common skin colors'
    out += " for this species, null if this species does not typically\n"
    out += '  have skin.\n  """\n  skinColors: [String]\n}\n\n"""A'
    out += ' connection to a list of items."""\ntype SpeciesConnectio'
    out += 'n {\n  """A list of edges."""\n  edges: [SpeciesEdge]'
    out += '\n\n  """Information to aid in pagination."""\n  pageI'
    out += 'nfo: PageInfo!\n\n  """\n  A list of all of the objects r'
    out += "eturned in the connection. This is a convenience\n  field pr"
    out += "ovided for quickly exploring the API; rather than querying f"
    out += 'or\n  "{ edges { node } }" when no edge data is needed, th'
    out += "is field can be be used\n  instead. Note that when clients l"
    out += 'ike Relay need to fetch the "cursor" field on\n  the edge '
    out += "to enable efficient pagination, this shortcut cannot be used"
    out += ', and the\n  full "{ edges { node } }" version should be u'
    out += 'sed instead.\n  """\n  species: [Species]\n\n  """\n  '
    out += "A count of the total number of objects in this connection, i"
    out += "gnoring pagination.\n  This allows a client to fetch the fir"
    out += 'st five objects by passing "5" as the\n  argument to "fir'
    out += 'st", then fetch the total count so it could display "5 of '
    out += '83",\n  for example.\n  """\n  totalCount: Int\n}\n\n"'
    out += '""An edge in a connection."""\ntype SpeciesEdge {\n  "'
    out += '""A cursor for use in pagination"""\n  cursor: String!'
    out += '\n\n  """The item at the end of the edge"""\n  node: S'
    out += 'pecies\n}\n\n"""A connection to a list of items."""\nt'
    out += 'ype SpeciesFilmsConnection {\n  """A list of edges."""'
    out += '\n  edges: [SpeciesFilmsEdge]\n\n  """\n  A list of all o'
    out += "f the objects returned in the connection. This is a convenie"
    out += "nce\n  field provided for quickly exploring the API; rather "
    out += 'than querying for\n  "{ edges { node } }" when no edge dat'
    out += "a is needed, this field can be be used\n  instead. Note that"
    out += ' when clients like Relay need to fetch the "cursor" field '
    out += "on\n  the edge to enable efficient pagination, this shortcut"
    out += ' cannot be used, and the\n  full "{ edges { node } }" vers'
    out += 'ion should be used instead.\n  """\n  films: [Film]\n\n  '
    out += '"""Information to aid in pagination."""\n  pageInfo: P'
    out += 'ageInfo!\n\n  """\n  A count of the total number of objec'
    out += "ts in this connection, ignoring pagination.\n  This allows a"
    out += ' client to fetch the first five objects by passing "5" as '
    out += 'the\n  argument to "first", then fetch the total count so '
    out += 'it could display "5 of 83",\n  for example.\n  """\n  t'
    out += 'otalCount: Int\n}\n\n"""An edge in a connection."""\nt'
    out += 'ype SpeciesFilmsEdge {\n  """A cursor for use in paginati'
    out += 'on"""\n  cursor: String!\n\n  """The item at the end o'
    out += 'f the edge"""\n  node: Film\n}\n\n"""A connection to a'
    out += ' list of items."""\ntype SpeciesPeopleConnection {\n  "'
    out += '""A list of edges."""\n  edges: [SpeciesPeopleEdge]\n\n'
    out += '  """Information to aid in pagination."""\n  pageInfo:'
    out += ' PageInfo!\n\n  """\n  A list of all of the objects retur'
    out += "ned in the connection. This is a convenience\n  field provid"
    out += "ed for quickly exploring the API; rather than querying for\n"
    out += '  "{ edges { node } }" when no edge data is needed, this f'
    out += "ield can be be used\n  instead. Note that when clients like "
    out += 'Relay need to fetch the "cursor" field on\n  the edge to e'
    out += "nable efficient pagination, this shortcut cannot be used, an"
    out += 'd the\n  full "{ edges { node } }" version should be used '
    out += 'instead.\n  """\n  people: [Person]\n\n  """\n  A coun'
    out += "t of the total number of objects in this connection, ignorin"
    out += "g pagination.\n  This allows a client to fetch the first fiv"
    out += 'e objects by passing "5" as the\n  argument to "first", '
    out += 'then fetch the total count so it could display "5 of 83",'
    out += '\n  for example.\n  """\n  totalCount: Int\n}\n\n"""An'
    out += ' edge in a connection."""\ntype SpeciesPeopleEdge {\n  "'
    out += '""A cursor for use in pagination"""\n  cursor: String!'
    out += '\n\n  """The item at the end of the edge"""\n  node: P'
    out += 'erson\n}\n\n"""A single transport craft that has hyperdri'
    out += 've capability."""\ntype Starship implements Node {\n  "'
    out += '""The maximum number of kilograms that this starship can t'
    out += 'ransport."""\n  cargoCapacity: Float\n\n  """\n  The m'
    out += "aximum length of time that this starship can provide consuma"
    out += "bles for its\n  entire crew without having to resupply.\n  "
    out += '"""\n  consumables: String\n\n  """The cost of this st'
    out += 'arship new, in galactic credits."""\n  costInCredits: Flo'
    out += 'at\n\n  """The ISO 8601 date format of the time that this'
    out += ' resource was created."""\n  created: String\n\n  """T'
    out += "he number of personnel needed to run or pilot this starship."
    out += '"""\n  crew: String\n\n  """The ISO 8601 date format o'
    out += 'f the time that this resource was edited."""\n  edited: S'
    out += "tring\n  filmConnection(after: String, first: Int, before: S"
    out += 'tring, last: Int): StarshipFilmsConnection\n\n  """The cl'
    out += 'ass of this starships hyperdrive."""\n  hyperdriveRating:'
    out += ' Float\n\n  """The ID of an object"""\n  id: ID!\n\n  '
    out += '"""The length of this starship in meters."""\n  length'
    out += ': Float\n\n  """The manufacturers of this starship."""'
    out += '\n  manufacturers: [String]\n\n  """\n  The maximum speed'
    out += " of this starship in atmosphere. null if this starship is\n "
    out += ' incapable of atmosphering flight.\n  """\n  maxAtmospher'
    out += 'ingSpeed: Int\n\n  """\n  The Maximum number of Megalight'
    out += 's this starship can travel in a standard hour.\n  A "Megali'
    out += 'ght" is a standard unit of distance and has never been defi'
    out += "ned before\n  within the Star Wars universe. This figure is "
    out += "only really useful for measuring\n  the difference in speed "
    out += "of starships. We can assume it is similar to AU, the\n  dist"
    out += 'ance between our Sun (Sol) and Earth.\n  """\n  MGLT: Int'
    out += '\n\n  """\n  The model or official name of this starship.'
    out += ' Such as "T-65 X-wing" or "DS-1\n  Orbital Battle Station'
    out += '".\n  """\n  model: String\n\n  """The name of this s'
    out += 'tarship. The common name, such as "Death Star"."""\n  n'
    out += 'ame: String\n\n  """The number of non-essential people th'
    out += 'is starship can transport."""\n  passengers: String\n  pi'
    out += "lotConnection(after: String, first: Int, before: String, las"
    out += 't: Int): StarshipPilotsConnection\n\n  """\n  The class o'
    out += 'f this starship, such as "Starfighter" or "Deep Space Mob'
    out += 'ile\n  Battlestation"\n  """\n  starshipClass: String\n}'
    out += '\n\n"""A connection to a list of items."""\ntype Stars'
    out += 'hipFilmsConnection {\n  """A list of edges."""\n  edge'
    out += 's: [StarshipFilmsEdge]\n\n  """\n  A list of all of the o'
    out += "bjects returned in the connection. This is a convenience\n  "
    out += "field provided for quickly exploring the API; rather than qu"
    out += 'erying for\n  "{ edges { node } }" when no edge data is ne'
    out += "eded, this field can be be used\n  instead. Note that when c"
    out += 'lients like Relay need to fetch the "cursor" field on\n  t'
    out += "he edge to enable efficient pagination, this shortcut cannot"
    out += ' be used, and the\n  full "{ edges { node } }" version sho'
    out += 'uld be used instead.\n  """\n  films: [Film]\n\n  """I'
    out += 'nformation to aid in pagination."""\n  pageInfo: PageInfo'
    out += '!\n\n  """\n  A count of the total number of objects in t'
    out += "his connection, ignoring pagination.\n  This allows a client"
    out += ' to fetch the first five objects by passing "5" as the\n  '
    out += 'argument to "first", then fetch the total count so it coul'
    out += 'd display "5 of 83",\n  for example.\n  """\n  totalCou'
    out += 'nt: Int\n}\n\n"""An edge in a connection."""\ntype Sta'
    out += 'rshipFilmsEdge {\n  """A cursor for use in pagination""'
    out += '"\n  cursor: String!\n\n  """The item at the end of the '
    out += 'edge"""\n  node: Film\n}\n\n"""A connection to a list '
    out += 'of items."""\ntype StarshipPilotsConnection {\n  """A '
    out += 'list of edges."""\n  edges: [StarshipPilotsEdge]\n\n  "'
    out += '""Information to aid in pagination."""\n  pageInfo: Pag'
    out += 'eInfo!\n\n  """\n  A list of all of the objects returned '
    out += "in the connection. This is a convenience\n  field provided f"
    out += 'or quickly exploring the API; rather than querying for\n  "'
    out += '{ edges { node } }" when no edge data is needed, this field'
    out += " can be be used\n  instead. Note that when clients like Rela"
    out += 'y need to fetch the "cursor" field on\n  the edge to enabl'
    out += "e efficient pagination, this shortcut cannot be used, and th"
    out += 'e\n  full "{ edges { node } }" version should be used inst'
    out += 'ead.\n  """\n  pilots: [Person]\n\n  """\n  A count of'
    out += " the total number of objects in this connection, ignoring pa"
    out += "gination.\n  This allows a client to fetch the first five ob"
    out += 'jects by passing "5" as the\n  argument to "first", then'
    out += ' fetch the total count so it could display "5 of 83",\n  f'
    out += 'or example.\n  """\n  totalCount: Int\n}\n\n"""An edge'
    out += ' in a connection."""\ntype StarshipPilotsEdge {\n  """'
    out += 'A cursor for use in pagination"""\n  cursor: String!\n\n '
    out += ' """The item at the end of the edge"""\n  node: Person'
    out += '\n}\n\n"""A connection to a list of items."""\ntype St'
    out += 'arshipsConnection {\n  """A list of edges."""\n  edges'
    out += ': [StarshipsEdge]\n\n  """Information to aid in paginatio'
    out += 'n."""\n  pageInfo: PageInfo!\n\n  """\n  A list of all'
    out += " of the objects returned in the connection. This is a conven"
    out += "ience\n  field provided for quickly exploring the API; rathe"
    out += 'r than querying for\n  "{ edges { node } }" when no edge d'
    out += "ata is needed, this field can be be used\n  instead. Note th"
    out += 'at when clients like Relay need to fetch the "cursor" fiel'
    out += "d on\n  the edge to enable efficient pagination, this shortc"
    out += 'ut cannot be used, and the\n  full "{ edges { node } }" ve'
    out += 'rsion should be used instead.\n  """\n  starships: [Stars'
    out += 'hip]\n\n  """\n  A count of the total number of objects i'
    out += "n this connection, ignoring pagination.\n  This allows a cli"
    out += 'ent to fetch the first five objects by passing "5" as the'
    out += '\n  argument to "first", then fetch the total count so it '
    out += 'could display "5 of 83",\n  for example.\n  """\n  tota'
    out += 'lCount: Int\n}\n\n"""An edge in a connection."""\ntype'
    out += ' StarshipsEdge {\n  """A cursor for use in pagination""'
    out += '"\n  cursor: String!\n\n  """The item at the end of the '
    out += 'edge"""\n  node: Starship\n}\n\n"""A single transport '
    out += 'craft that does not have hyperdrive capability"""\ntype V'
    out += 'ehicle implements Node {\n  """The maximum number of kilo'
    out += 'grams that this vehicle can transport."""\n  cargoCapacit'
    out += 'y: Int\n\n  """\n  The maximum length of time that this v'
    out += "ehicle can provide consumables for its\n  entire crew withou"
    out += 't having to resupply.\n  """\n  consumables: String\n\n  '
    out += '"""The cost of this vehicle new, in Galactic Credits.""'
    out += '"\n  costInCredits: Int\n\n  """The ISO 8601 date format'
    out += ' of the time that this resource was created."""\n  create'
    out += 'd: String\n\n  """The number of personnel needed to run o'
    out += 'r pilot this vehicle."""\n  crew: String\n\n  """The I'
    out += "SO 8601 date format of the time that this resource was edite"
    out += 'd."""\n  edited: String\n  filmConnection(after: String, '
    out += "first: Int, before: String, last: Int): VehicleFilmsConnecti"
    out += 'on\n\n  """The ID of an object"""\n  id: ID!\n\n  ""'
    out += '"The length of this vehicle in meters."""\n  length: Flo'
    out += 'at\n\n  """The manufacturers of this vehicle."""\n  ma'
    out += 'nufacturers: [String]\n\n  """The maximum speed of this v'
    out += 'ehicle in atmosphere."""\n  maxAtmospheringSpeed: Int\n\n'
    out += '  """\n  The model or official name of this vehicle. Such'
    out += ' as "All-Terrain Attack\n  Transport".\n  """\n  model:'
    out += ' String\n\n  """\n  The name of this vehicle. The common '
    out += 'name, such as "Sand Crawler" or "Speeder\n  bike".\n  "'
    out += '""\n  name: String\n\n  """The number of non-essential '
    out += 'people this vehicle can transport."""\n  passengers: Stri'
    out += "ng\n  pilotConnection(after: String, first: Int, before: Str"
    out += 'ing, last: Int): VehiclePilotsConnection\n\n  """The clas'
    out += 's of this vehicle, such as "Wheeled" or "Repulsorcraft".'
    out += '"""\n  vehicleClass: String\n}\n\n"""A connection to a'
    out += ' list of items."""\ntype VehicleFilmsConnection {\n  ""'
    out += '"A list of edges."""\n  edges: [VehicleFilmsEdge]\n\n  '
    out += '"""\n  A list of all of the objects returned in the conne'
    out += "ction. This is a convenience\n  field provided for quickly e"
    out += 'xploring the API; rather than querying for\n  "{ edges { no'
    out += 'de } }" when no edge data is needed, this field can be be u'
    out += "sed\n  instead. Note that when clients like Relay need to fe"
    out += 'tch the "cursor" field on\n  the edge to enable efficient '
    out += 'pagination, this shortcut cannot be used, and the\n  full "'
    out += '{ edges { node } }" version should be used instead.\n  ""'
    out += '"\n  films: [Film]\n\n  """Information to aid in paginat'
    out += 'ion."""\n  pageInfo: PageInfo!\n\n  """\n  A count of '
    out += "the total number of objects in this connection, ignoring pag"
    out += "ination.\n  This allows a client to fetch the first five obj"
    out += 'ects by passing "5" as the\n  argument to "first", then '
    out += 'fetch the total count so it could display "5 of 83",\n  fo'
    out += 'r example.\n  """\n  totalCount: Int\n}\n\n"""An edge '
    out += 'in a connection."""\ntype VehicleFilmsEdge {\n  """A c'
    out += 'ursor for use in pagination"""\n  cursor: String!\n\n  "'
    out += '""The item at the end of the edge"""\n  node: Film\n}\n'
    out += '\n"""A connection to a list of items."""\ntype Vehicle'
    out += 'PilotsConnection {\n  """A list of edges."""\n  edges:'
    out += ' [VehiclePilotsEdge]\n\n  """Information to aid in pagina'
    out += 'tion."""\n  pageInfo: PageInfo!\n\n  """\n  A list of '
    out += "all of the objects returned in the connection. This is a con"
    out += "venience\n  field provided for quickly exploring the API; ra"
    out += 'ther than querying for\n  "{ edges { node } }" when no edg'
    out += "e data is needed, this field can be be used\n  instead. Note"
    out += ' that when clients like Relay need to fetch the "cursor" f'
    out += "ield on\n  the edge to enable efficient pagination, this sho"
    out += 'rtcut cannot be used, and the\n  full "{ edges { node } }"'
    out += ' version should be used instead.\n  """\n  pilots: [Perso'
    out += 'n]\n\n  """\n  A count of the total number of objects in '
    out += "this connection, ignoring pagination.\n  This allows a clien"
    out += 't to fetch the first five objects by passing "5" as the\n '
    out += ' argument to "first", then fetch the total count so it cou'
    out += 'ld display "5 of 83",\n  for example.\n  """\n  totalCo'
    out += 'unt: Int\n}\n\n"""An edge in a connection."""\ntype Ve'
    out += 'hiclePilotsEdge {\n  """A cursor for use in pagination"'
    out += '""\n  cursor: String!\n\n  """The item at the end of th'
    out += 'e edge"""\n  node: Person\n}\n\n"""A connection to a l'
    out += 'ist of items."""\ntype VehiclesConnection {\n  """A li'
    out += 'st of edges."""\n  edges: [VehiclesEdge]\n\n  """Infor'
    out += 'mation to aid in pagination."""\n  pageInfo: PageInfo!\n'
    out += '\n  """\n  A count of the total number of objects in this'
    out += " connection, ignoring pagination.\n  This allows a client to"
    out += ' fetch the first five objects by passing "5" as the\n  arg'
    out += 'ument to "first", then fetch the total count so it could d'
    out += 'isplay "5 of 83",\n  for example.\n  """\n  totalCount:'
    out += ' Int\n\n  """\n  A list of all of the objects returned in'
    out += " the connection. This is a convenience\n  field provided for"
    out += ' quickly exploring the API; rather than querying for\n  "{ '
    out += 'edges { node } }" when no edge data is needed, this field c'
    out += "an be be used\n  instead. Note that when clients like Relay "
    out += 'need to fetch the "cursor" field on\n  the edge to enable '
    out += "efficient pagination, this shortcut cannot be used, and the"
    out += '\n  full "{ edges { node } }" version should be used inste'
    out += 'ad.\n  """\n  vehicles: [Vehicle]\n}\n\n"""An edge in '
    out += 'a connection."""\ntype VehiclesEdge {\n  """A cursor f'
    out += 'or use in pagination"""\n  cursor: String!\n\n  """The'
    out += ' item at the end of the edge"""\n  node: Vehicle\n}\n'
    return out^


def _path_164() -> String:
    var out = String()
    out += "nested_named_fragments/used-coordinates.json.expected"
    return out^


def _file_164() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "StarshipsCo'
    out += 'nnection": {},\n        "Root": {\n            "allStars'
    out += 'hips": [\n                "first"\n            ]\n       '
    out += ' },\n        "StarshipsEdge": {},\n        "Starship": {'
    out += '},\n        "String": {},\n        "ID": {},\n        "'
    out += 'StarshipPilotsConnection": {},\n        "StarshipPilotsEdg'
    out += 'e": {},\n        "Person": {},\n        "Planet": {},\n'
    out += '        "Node": {}\n    }\n}'
    return out^


def _path_165() -> String:
    var out = String()
    out += "not_all_combinations_are_needed/TestOperation.graphql"
    return out^


def _file_165() -> String:
    var out = String()
    out += "# The below field has:\n# - A, B, C type conditions\n# - a s"
    out += "hape that satisfies [A, B, C]\n# - a shape that satisfies [B"
    out += ", C]\n# Even though there's a shape that satisfies [B, C], w"
    out += "e don't want to generate a data class for this\n# as collect"
    out += "ing fields on [B, C] would not find fieldB1 despite [B, C] p"
    out += "otentially implementing bFragment\nquery TestQuery {\n    ro"
    out += "ot {\n        ... on A {\n            fieldA1\n            ."
    out += ".. on B {\n                ...bFragment\n            }\n    "
    out += "    }\n    }\n}\n\nfragment bFragment on B {\n    fieldB1\n}"
    return out^


def _path_166() -> String:
    var out = String()
    out += "not_all_combinations_are_needed/schema.graphqls"
    return out^


def _file_166() -> String:
    var out = String()
    out += "type Query {\n  root: C\n}\n\ninterface A {\n  fieldA1: Stri"
    out += "ng\n  fieldA2: String\n}\n\ninterface B {\n  fieldB1: String"
    out += "\n  fieldB2: String\n}\ninterface C {\n  fieldC: String\n}\n"
    out += "\ntype ABC implements A & B & C {\n  fieldA1: String\n  fiel"
    out += "dA2: String\n  fieldB1: String\n  fieldB2: String\n  fieldC:"
    out += " String\n}\n\ntype SomeC implements C {\n  fieldC: String\n}"
    out += "\n\ntype SomeBC implements C & B {\n  fieldB1: String\n  fie"
    out += "ldB2: String\n  fieldC: String\n}\n"
    return out^


def _path_167() -> String:
    var out = String()
    out += "not_all_combinations_are_needed/used-coordinates.json.expect"
    out += "ed"
    return out^


def _file_167() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "C": {},\n '
    out += '       "String": {},\n        "Query": {},\n        "B'
    out += '": {}\n    }\n}'
    return out^


def _path_168() -> String:
    var out = String()
    out += "object/TestOperation.graphql"
    return out^


def _file_168() -> String:
    var out = String()
    out += "# https://github.com/apollographql/apollo-kotlin/issues/1173"
    out += "\nquery TestQuery {\n  object {\n    random\n  }\n}\n"
    return out^


def _path_169() -> String:
    var out = String()
    out += "object/schema.graphqls"
    return out^


def _file_169() -> String:
    var out = String()
    out += "type Query {\n  object: Object\n}\n\ntype Object {\n  random"
    out += ": Int\n}"
    return out^


def _path_170() -> String:
    var out = String()
    out += "object/used-coordinates.json.expected"
    return out^


def _file_170() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Object": {'
    out += '},\n        "Int": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_171() -> String:
    var out = String()
    out += "operation_ids.tsv"
    return out^


def _file_171() -> String:
    var out = String()
    out += "antlr_tokens\tTestQuery\t197e186cfb461d1c38c0be4da7b182eff42"
    out += "e304043973b994c8c2de3535daea6\tquery TestQuery($operation: S"
    out += "tring) { typeWithGraphQLKeywords { on null(fragment: $operat"
    out += 'ion) alias: null(fragment: "A string\\nwith a new line") }'
    out += " }\narguments_hardcoded\tTestQuery\ta15321a7f7103480873db29a"
    out += "761ae001023b059eb7ad1af9e2816d1a2458c1b5\tquery TestQuery { "
    out += "reviews(episode: JEDI, starsInt: 10, starsFloat: 9.9) { star"
    out += "s commentary } testNullableArguments(int: null, string: null"
    out += ", float: null, review: null, episode: null, boolean: null, l"
    out += "ist: null) }\nbig_query\tTestQuery\taa02577aff7fefcf848c430a"
    out += "7256352c9ceee2cde9e795d95099839a4a4dbd15\tquery TestQuery { "
    out += 'character(id: "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi'
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += "ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoi"
    out += "hoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoiho"
    out += "ihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoi"
    out += "hoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoih"
    out += "oihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoiho"
    out += "ihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoih"
    out += "oivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoiho"
    out += "ihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoi"
    out += "hoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoih"
    out += "oihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi"
    out += "vvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoih"
    out += "oihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoiho"
    out += "ihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoi"
    out += "hoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivv"
    out += "oihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoi"
    out += "hoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoihoihoihoih"
    out += "oihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoivvoihoihoiho"
    out += 'ihoihoihoihoihoihoihoivvoihoihoihoihoihoihoihoihoihoihoi") '
    out += "{ name } }\ncapitalized_fields\tTestQuery\t79be9e4e97049f324"
    out += "5b5774e22d02ec3db4304788471b62abfbded44b756c6bd\tquery TestQ"
    out += "uery { Horse { __typename Donkey ... on Horse { Cow { Moo } "
    out += "} } }\ncase_sensitive_enum\tTestQuery\t1dbd1f94815f122a090e0"
    out += "9d84dd17b0bf55e8c44671cba8fd89a7c7c9fa79d63\tquery TestQuery"
    out += " { enum }\ncompanion\tTestQuery\tcfbc27985ac8f31224ce3aae170"
    out += "9268e0ff39ebcc30c5e78968becb1d1d234a6\tquery TestQuery { com"
    out += "panion { foo } }\ncustom_scalar_type\tTestQuery\tab392dcf31f"
    out += "c40a50aa171d889e97a082599dddfbe4946b2674204af36031a39\tquery"
    out += " TestQuery { hero { id name birthDate appearanceDates fieldW"
    out += "ithUnsupportedType profileLink links } nonNullTimestamp null"
    out += "ableTimestamp nonNullListOfNonNullTimestamp nonNullListOfNul"
    out += "lableTimestamp nullableListOfNonNullTimestamp nullableListOf"
    out += "NullableTimestamp nullableLong nullableFloat }\ncustom_scala"
    out += "r_type\tScalarWithGenericType\ta4310c5c764fd8691ab97d3c217ea"
    out += "e966f34ceaf5184630463fcfe5756fc9c6c\tquery ScalarWithGeneric"
    out += "Type { listOfString }\ndata_builders\tNodeQuery\tc91df108c7e"
    out += "22d226afdf25226288d452aad34224a2d09fc3b98e495f4903c4c\tquery"
    out += " NodeQuery { node { __typename id ...HumanFragment ...DroidF"
    out += "ragment } }  fragment HumanFragment on Human { homePlanet } "
    out += " fragment DroidFragment on Droid { primaryFunction }\ndata_b"
    out += "uilders\tCharacterQuery\tf4b46cb156d293f68b745d169b5089b3e08"
    out += "2087d36dea649b06aa4c6a7821e46\tquery CharacterQuery { charac"
    out += "ter { __typename id name ...HumanFragment ...DroidFragment }"
    out += " }  fragment HumanFragment on Human { homePlanet }  fragment"
    out += " DroidFragment on Droid { primaryFunction }\ndata_builders\t"
    out += "AnimalQuery\t0a4d6f7c4de2a81e6247e9f2205b24b2b42e03c1f25fe72"
    out += "67e13fe1342d905d7\tquery AnimalQuery { animal { __typename ."
    out += "..CatFragment ...DogFragment } }  fragment CatFragment on Ca"
    out += "t { meow }  fragment DogFragment on Dog { woof }\ndecapitali"
    out += "zed_fields\tTestQuery\teaf32cd8f3f693a5d7641fc3f4790638833dd"
    out += "5b5daccc5103d4bb4ddb4764aad\tquery TestQuery { Horse { __typ"
    out += "ename Donkey ... on Horse { Cow { Moo } } ...HorseFragment }"
    out += " }  fragment HorseFragment on Horse { Cow { Moo } }\ndepreca"
    out += "ted_merged_field\tCatQuery\t1339b44a5c30437b050faa2883275f02"
    out += "a22fffe77aa08983f50bccdab674d7ed\tquery CatQuery { cat { __t"
    out += "ypename ...AnimalFragment } }  fragment AnimalFragment on An"
    out += "imal { __typename ... on Cat { name } ... on Dog { name } }"
    out += "\ndeprecation\tTestQuery\t966ff95da151b6e5de110e4ef356053da7"
    out += "1e83ed39055254fefec22b9c8e15e4\tquery TestQuery($episode: Ep"
    out += "isode) { hero(episode: $episode) { name deprecated deprecate"
    out += "dBool deprecatedEmptyReason } }\nenum_field\tTestQuery\td9f4"
    out += "dcc9a9b855455b49cca3f8f542dba43a5324df22e1662f4fe0157d4c73d4"
    out += "\tquery TestQuery { gravity gravityAsEnum }\nenums_as_sealed"
    out += "\tTestQuery\t1dbd1f94815f122a090e09d84dd17b0bf55e8c44671cba8"
    out += "fd89a7c7c9fa79d63\tquery TestQuery { enum }\nescape_equals_h"
    out += "ashcode\tTestQuery\t84c1b3692563f1c4a789806c3a866e12df89f825"
    out += "af885b26f6a0d3dc0de2260d\tquery TestQuery { in out }\nescape"
    out += "d_kdocs\tTestQuery\tfc68a4134cf34ccf185a15db807690caeafd1aa0"
    out += "d5a9f184b995e5127be04ec9\tquery TestQuery { someType { someF"
    out += "ield } }\nfield_with_include_directive\tTestQuery\t7d815b13d"
    out += "f95ab484c7b20cb8059c07e3a8688d1ea0a251bff6d3f0b6fdb1cb7\tque"
    out += "ry TestQuery($includeName: Boolean!, $skipFriends: Boolean!)"
    out += ' @operationDirective(dummy: "hello") { hero { name @includ'
    out += "e(if: $includeName) friendsConnection @skip(if: $skipFriends"
    out += ") { totalCount } } }\nfieldset_with_multiple_super\tTestQuer"
    out += "y\t6faa0db26a1466e969ffc48d42fef45419406628c6c607fbbb1a0da1d"
    out += "592fdb2\tquery TestQuery { c { __typename ... on A { __typen"
    out += "ame fieldA1 ... on B { fieldB1 } } ... on B { __typename fie"
    out += "ldB2 ... on A { fieldA2 } } } }\nfragment_spread_with_includ"
    out += "e_directive\tTestQuery\tc028b2bef2e87616481fc4e418cdde6d31d6"
    out += "c4a48d669d7c8ac4c5ac0145ec07\tquery TestQuery($withDetails: "
    out += "Boolean!, $skipHumanDetails: Boolean!, $optionalWithDefaultF"
    out += "alse: Boolean = false , $optionalWithDefaultTrue: Boolean = "
    out += "true , $optionalWithNoDefault: Boolean) { hero { __typename "
    out += "id ...HeroDetails @include(if: $withDetails) @skip(if: $skip"
    out += "HumanDetails) ...HumanDetails @include(if: $withDetails) ..."
    out += "DroidDetails @skip(if: $optionalWithDefaultTrue) ...OtherDro"
    out += "idDetails @include(if: $optionalWithDefaultTrue) } getBoolea"
    out += "n(booleanArg: $optionalWithNoDefault) }  fragment HeroDetail"
    out += "s on Character { name }  fragment HumanDetails on Human { ho"
    out += "mePlanet }  fragment DroidDetails on Droid { primaryFunction"
    out += " }  fragment OtherDroidDetails on Droid { id }\nfragment_spr"
    out += "ead_with_nested_fields\tTestQuery\te21794a17c37fd41b0530e7df"
    out += "079fae9a579bc77435bb811a2e869909de32a55\tquery TestQuery { h"
    out += "ero { __typename ...HeroDetails } }  fragment HeroDetails on"
    out += " Character { name friendsConnection { totalCount edges { nod"
    out += "e { name } } } }\nfragment_used_twice\tTestQuery\t95ffb2ac3d"
    out += "aa9734e241ef2b3224b2a33ffff59e695e9a5ce2e7b9d6ed43fae4\tquer"
    out += "y TestQuery { hero { __typename ...HeroDetails ...HumanDetai"
    out += "ls } }  fragment CharacterDetails on Character { name birthD"
    out += "ate }  fragment HeroDetails on Character { __typename name ."
    out += "..CharacterDetails }  fragment HumanDetails on Human { __typ"
    out += "ename name ...CharacterDetails }\nfragment_with_inline_fragm"
    out += "ent\tTestQuery\te7d60efdcca39c19521839807ddc66ed9efa271ade2a"
    out += "d3e0a934c6c9b388830e\tquery TestQuery { hero { __typename na"
    out += "me ...HeroDetails appearsIn } }  fragment HumanDetails on Hu"
    out += "man { name }  fragment DroidDetails on Droid { name primaryF"
    out += "unction }  fragment HeroDetails on Character { __typename .."
    out += ".HumanDetails ... on Droid { __typename ...DroidDetails } na"
    out += "me friendsConnection { totalCount edges { node { name } } } "
    out += "}\nfragment_with_multiple_fieldsets\tTestQuery\t784a97bf4fc3"
    out += "3e2f184539f66ee6a732e219042070b1b85f7c9e88d92fc2855f\tquery "
    out += "TestQuery { i { __typename ...iFragment } }  fragment iFragm"
    out += "ent on I { __typename ... on A { fieldA } }\nfragments_same_"
    out += "type_condition\tTestQuery\tc3225dc1a6a27daa930abab4a098121fe"
    out += "d0a7bc2e955c3cb931002dc1e1900c3\tquery TestQuery { hero { __"
    out += "typename ...DroidDetails1 ...DroidDetails2 } }  fragment Dro"
    out += "idDetails1 on Droid { name }  fragment DroidDetails2 on Droi"
    out += "d { primaryFunction }\nfragments_with_defer_and_include_dire"
    out += "ctives\tSpreadMultipleWithDefer\t7cd4d1b6a14f96cff4bbbdbd3b3"
    out += "ab1aa365ffc65e1515ff6e22935010543ad71\tquery SpreadMultipleW"
    out += "ithDefer { hero { __typename ...DroidDetails @defer(label: "
    out += '"a_first") ...DroidDetails @defer(label: "a_second") } }'
    out += "  fragment DroidDetails on Droid { name }\nfragments_with_de"
    out += "fer_and_include_directives\tInlineMultipleWithDeferWithIf\t9"
    out += "dc79c78df7375c3d860d16df3ea839ea45c7f8420976f63414610d338f0c"
    out += "af1\tquery InlineMultipleWithDeferWithIf($cond: Boolean!) { "
    out += 'hero { __typename ... on Character @defer(label: "f_first"'
    out += ', if: false) { id } ... on Character @defer(label: "f_secon'
    out += 'd", if: true) { name } ... on Character @defer(label: "f_t'
    out += 'hird", if: $cond) { name } } }\nfragments_with_defer_and_in'
    out += "clude_directives\tSpreadMultipleWithDeferAndInclude\t1c9d61b"
    out += "4af65df2bfed92353244efbb66d20a35daf747507e66ed9d20dcd1517\tq"
    out += "uery SpreadMultipleWithDeferAndInclude($cond1: Boolean!, $co"
    out += "nd2: Boolean!, $cond3: Boolean!, $cond4: Boolean!) { hero { "
    out += "__typename ...DroidDetails @include(if: $cond1) ...DroidDeta"
    out += 'ils @skip(if: $cond2) ...DroidDetails @defer(label: "b_firs'
    out += 't") ...DroidDetails @defer(label: "b_second") ...DroidDet'
    out += 'ails @defer(label: "b_third") @include(if: $cond3) ...Droi'
    out += 'dDetails @defer(label: "b_fourth") @skip(if: $cond4) } }  '
    out += "fragment DroidDetails on Droid { name }\nfragments_with_defe"
    out += "r_and_include_directives\tInlineSingleWithDefer\t70222802c91"
    out += "92f810f19a54d31e039ce0fc3b8baac231841f0a0e8b4200c312b\tquery"
    out += " InlineSingleWithDefer { hero { __typename ... on Droid @def"
    out += "er { name } } }\nfragments_with_defer_and_include_directives"
    out += "\tInlineMultipleWithDefer\t9331f0c719bafb010d29f76c720d4488f"
    out += "45c5196bf3fb8908b2be30bc546e355\tquery InlineMultipleWithDef"
    out += 'er { hero { __typename ... on Droid @defer(label: "d_first'
    out += '") { name } ... on Droid @defer(label: "d_second") { id }'
    out += " } }\nfragments_with_defer_and_include_directives\tSpreadMul"
    out += "tipleWithDeferWithIf\tecdac17ca37d6cbf3a6e5059904fabfd96193c"
    out += "be0720eb27880026b518feec9f\tquery SpreadMultipleWithDeferWit"
    out += "hIf($cond: Boolean!) { hero { __typename ...CharacterDetails"
    out += ' @defer(label: "c_first", if: false) ...CharacterDetails2 '
    out += '@defer(label: "c_second", if: true) ...CharacterDetails3 @'
    out += 'defer(label: "c_third", if: $cond) } }  fragment Character'
    out += "Details on Droid { name }  fragment CharacterDetails2 on Dro"
    out += "id { id }  fragment CharacterDetails3 on Droid { birthDate }"
    out += "\nfragments_with_defer_and_include_directives\tSpreadSingleW"
    out += "ithDefer\tfad1c3622a6f35d5fa4ad7b5e4a8d50525c350d4688837022f"
    out += "0f7a6f0aed2ba0\tquery SpreadSingleWithDefer { hero { __typen"
    out += "ame ...DroidDetails @defer } }  fragment DroidDetails on Dro"
    out += "id { name }\nfragments_with_defer_and_include_directives\tIn"
    out += "lineMultipleWithDeferAndInclude\tf159c1ac4f33a49c5c9833e06a2"
    out += "606e2fc7ede812e119909eb45f95dc2aa01fc\tquery InlineMultipleW"
    out += "ithDeferAndInclude($cond1: Boolean!, $cond2: Boolean!, $cond"
    out += "3: Boolean!, $cond4: Boolean!) { hero { __typename ... on Dr"
    out += "oid @include(if: $cond1) { name } ... on Droid @skip(if: $co"
    out += 'nd2) { id } ... on Droid @defer(label: "e_first") { name }'
    out += ' ... on Droid @defer(label: "e_second") { id } ... on Droi'
    out += 'd @defer(label: "e_third") @include(if: $cond3) { name } .'
    out += '.. on Droid @defer(label: "e_fourth") @skip(if: $cond4) { '
    out += "id } } }\nfragments_with_type_condition\tTestQuery\t7d805690"
    out += "a4b15b327a23b61c94049254b0e6613ec62e9b913b716be71bb2e54c\tqu"
    out += "ery TestQuery { r2: hero { __typename ...HumanDetails ...Dro"
    out += "idDetails } luke: hero { __typename ...HumanDetails ...Droid"
    out += "Details } }  fragment HumanDetails on Human { name height } "
    out += " fragment DroidDetails on Droid { name primaryFunction }\nhe"
    out += "ro_details\tHeroDetails\t8f6f2c3852a89d45ea7eaa08a249906a1fb"
    out += "8f1733c4f2326d0fb8fb75c4af1e3\tquery HeroDetails { hero { ty"
    out += "pe name friendsConnection { totalCount edges { node { name }"
    out += " } } } }\nhero_details_semantic_naming\tHeroDetails\t5e11892"
    out += "e17cceb600c00f4565a27951dce5e8aadd95b64b8d13a835ed8fb11e1\tq"
    out += "uery HeroDetails { hero { name friendsConnection { totalCoun"
    out += "t edges { node { name } } } } }\nhero_name\tTestQuery\t17e30"
    out += "561f6043a4c67f3de02bc6c76798edb2d584095975a2f75862222ef4912"
    out += "\tquery TestQuery { hero { __typename name birthDate ... on "
    out += "Droid { primaryFunction } } }\nhero_name_query_long_name\tTe"
    out += "stQueryWithAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVer"
    out += "yAVeryAVeryAVeryLongName\t164dc148c38451cf968e075d4fd3114b0e"
    out += "03f4e5d8e126be67cf7156ef4cda9c\tquery TestQueryWithAVeryAVer"
    out += "yAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryLong"
    out += "Name($episodeAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAV"
    out += "eryAVeryAVeryAVeryAVeryAVeryLongName: Episode) { heroAVeryAV"
    out += "eryAVeryAVeryAVeryAVeryAV: hero(episode: $episodeAVeryAVeryA"
    out += "VeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVeryA"
    out += "VeryLongName) { nameAVeryAVeryAVeryAVeryAVeryAVeryAVeryAVery"
    out += "AVeryAVeryAVeryAVeryAVeryAVeryAVeryLongName: name } }\nhero_"
    out += "with_review\tTestQuery\t1faa220c7551ff1343a9bce722af8c12b87c"
    out += "70cc579f743aff1374ae1066f163\tmutation TestQuery($ep: Episod"
    out += "e!) { createReview(episode: $ep, review: { stars: 5 listOfEn"
    out += 'ums: [JEDI,EMPIRE,NEWHOPE] listOfStringNonOptional: ["1",'
    out += '"2","3"] favoriteColor: { red: 1 blue: 1 }  } ) { stars '
    out += "commentary } }\ninline_fragment_for_non_optional_field\tTest"
    out += "Query\te33ec8a463abf6b32191d1f07aa6c7e4d038a493cace83a45a646"
    out += "32eb65b1ced\tquery TestQuery { nonOptionalHero(episode: EMPI"
    out += "RE) { __typename name ... on Human { height } } }\ninline_fr"
    out += "agment_inside_inline_fragment\tTestQuery\t4f32ea4bdd2a95a29b"
    out += "de61273602c22c698cd333f1701001d1a339fb276c6438\tquery TestQu"
    out += 'ery { search(text: "bla-bla") { __typename ... on Characte'
    out += "r { __typename name ... on Human { homePlanet } ... on Droid"
    out += " { primaryFunction } } } }\ninline_fragment_intersection\tTe"
    out += "stOperation\tc99acd467295cdc6cf49f2f0e260f5879de276fba742d6f"
    out += "aa161453e53fbf9d4\tquery TestOperation { random { __typename"
    out += " ... on Being { __typename name friends { __typename name .."
    out += ". on Wookie { lifeExpectancy } } ... on Human { profilePictu"
    out += "reUrl friends { __typename isFamous ... on Wookie { race } }"
    out += " } } ... on Wookie { race friends { lifeExpectancy } } ... o"
    out += "n Being { friends { __typename ... on Wookie { lifeExpectanc"
    out += "y } } } } }\ninline_fragment_merge_fields\tTestQuery\t516a2d"
    out += "4b3fe97536486d2d559538aab9949d7c7e0de7081caec02439a0cb3969\t"
    out += "query TestQuery { hero { __typename name friendsConnection {"
    out += " edges { node { name } } } ... on Character { name profileLi"
    out += "nk friendsConnection { edges { node { name } } } } } }\ninli"
    out += "ne_fragment_simple\tTestQuery\t5438a5b2731bc2f21c90dcc4bff56"
    out += "28dd91f65534a3f5cab0dbbbfdd3b4bf19b\tquery TestQuery { hero "
    out += "{ __typename ... on Human { height } } }\ninline_fragment_ty"
    out += "pe_coercion\tTestQuery\t65c4fd857f5cbd2283f0783a3b3cefd9ead5"
    out += "abb159f5cc20922b0d8e04286662\tquery TestQuery { foo { __type"
    out += "name foo ... on Bar { bar } } }\ninline_fragment_with_includ"
    out += "e_directive\tTestQuery\t1fc50a1808d1ff72f74d821b563ee69df2fc"
    out += "04dd650e41d27d75d90d0413bd65\tquery TestQuery($withDetails: "
    out += "Boolean!, $skipHumanDetails: Boolean!) { hero { __typename i"
    out += "d ... on Human @include(if: $withDetails) @skip(if: $skipHum"
    out += "anDetails) { name homePlanet } ... on Droid @include(if: $wi"
    out += "thDetails) { name primaryFunction } ... on Character @includ"
    out += "e(if: $withDetails) { name } } }\ninline_fragments_with_frie"
    out += "nds\tTestQuery\t43bfea6068cd77041d723551dd119f0676f6c333620d"
    out += "d281a668eca49d14fcb5\tquery TestQuery { hero { __typename na"
    out += "me ... on Human { height friends { appearsIn } } ... on Droi"
    out += "d { primaryFunction friends { id } } } }\ninput_object_oneof"
    out += "\tFindUserQuery\tda63c6a7bf79d238f2d6fffd77742ac92c08bd42297"
    out += "14f24a726f773f7567fcc\tquery FindUserQuery($findUserInput: F"
    out += "indUserInput!) { findUser(findUserInput: $findUserInput) { i"
    out += "d } }\ninput_object_type\tTestQuery\t2a1de6af8435bb9169562d7"
    out += "8714566aaf26a9741ef16b72f49955dc615237b09\tmutation TestQuer"
    out += "y($ep: Episode!, $review: ReviewInput!) { createReview(episo"
    out += "de: $ep, review: $review) { stars commentary } }\ninput_obje"
    out += "ct_variable_and_argument\tTestQuery\t5de0170d60b7008300fa405"
    out += "99880d0b70e67a326a7b1fe27b8fa87aba7e5d36f\tquery TestQuery($"
    out += "episode: Episode, $stars: Int!, $greenValue: Float!) { heroW"
    out += "ithReview(episode: $episode, review: { stars: $stars favorit"
    out += "eColor: { red: 0 green: $greenValue blue: 0 }  booleanNonOpt"
    out += "ional: false listOfStringNonOptional: [] } , listOfInts: [$s"
    out += "tars,$stars]) { name height(unit: FOOT) } }\ninput_object_va"
    out += "riable_and_argument_with_generated_methods\tTestQuery\t5de01"
    out += "70d60b7008300fa40599880d0b70e67a326a7b1fe27b8fa87aba7e5d36f"
    out += "\tquery TestQuery($episode: Episode, $stars: Int!, $greenVal"
    out += "ue: Float!) { heroWithReview(episode: $episode, review: { st"
    out += "ars: $stars favoriteColor: { red: 0 green: $greenValue blue:"
    out += " 0 }  booleanNonOptional: false listOfStringNonOptional: [] "
    out += "} , listOfInts: [$stars,$stars]) { name height(unit: FOOT) }"
    out += " }\ninterface_always_nested\tTestQuery\t942dce7142e6653f801c"
    out += "8c4e96884e592106f75559c4ad96595a225c35d26260\tquery TestQuer"
    out += "y { root { __typename ... on A { __typename fieldA1 ... on B"
    out += " { fieldB1 } } } }\ninterface_on_interface\tGetHuman\tb5ec64"
    out += "31463438b91c2cf1c33eb4b6a1f9e2580b51fcf5150ef3685b9108a12c\t"
    out += "query GetHuman { human { id name height } node { __typename "
    out += "... on Human { height } } }\nintrospection_query\tTestQuery"
    out += "\t2bf29cc74f10b0b5551a609396f4e489fc4ebce15c0504cdd102be8447"
    out += "976b97\tquery TestQuery { __schema { queryType { name } type"
    out += 's { name } } __type(name: "Vehicle") { name kind } }\njava'
    out += "8annotation\tLoginBarber\t1a8d9f5ee31f38a8c4095cabd35889a9cb"
    out += "b5b44c83c1302286f743fd8d838110\tmutation LoginBarber($input:"
    out += " Login!) { login(input: $input) { response } }\njava_android"
    out += "_annotations\tMyQuery\tc9a856ba761821117e6a30df290b1259be461"
    out += "90a67a93d351fe3a648a4713435\tquery MyQuery($nullableInt: Int"
    out += ", $nonNullableInt: Int!, $nonNullableIntWithDefault: Int! = "
    out += "4 , $nullableInput: MyInput, $nonNullableInput: MyInput!, $n"
    out += "onNullableInputWithDefault: MyInput! = { nonNullableInt: 4 }"
    out += " ) { nullableInt(nullableInt: $nullableInt, nonNullableInt: "
    out += "$nonNullableInt, nonNullableIntWithDefault: $nonNullableIntW"
    out += "ithDefault, nullableInput: $nullableInput, nonNullableInput:"
    out += " $nonNullableInput, nonNullableInputWithDefault: $nonNullabl"
    out += "eInputWithDefault) nonNullableInt(nullableInt: $nullableInt,"
    out += " nonNullableInt: $nonNullableInt, nonNullableIntWithDefault:"
    out += " $nonNullableIntWithDefault, nullableInput: $nullableInput, "
    out += "nonNullableInput: $nonNullableInput, nonNullableInputWithDef"
    out += "ault: $nonNullableInputWithDefault) nullableMyType { nullabl"
    out += "eInt nonNullableInt } nonNullableMyType { nullableInt nonNul"
    out += "lableInt } nullableListOfNullableString nullableListOfNonNul"
    out += "lableString }\njava_apollo_optionals\tMyQuery\tc9a856ba76182"
    out += "1117e6a30df290b1259be46190a67a93d351fe3a648a4713435\tquery M"
    out += "yQuery($nullableInt: Int, $nonNullableInt: Int!, $nonNullabl"
    out += "eIntWithDefault: Int! = 4 , $nullableInput: MyInput, $nonNul"
    out += "lableInput: MyInput!, $nonNullableInputWithDefault: MyInput!"
    out += " = { nonNullableInt: 4 } ) { nullableInt(nullableInt: $nulla"
    out += "bleInt, nonNullableInt: $nonNullableInt, nonNullableIntWithD"
    out += "efault: $nonNullableIntWithDefault, nullableInput: $nullable"
    out += "Input, nonNullableInput: $nonNullableInput, nonNullableInput"
    out += "WithDefault: $nonNullableInputWithDefault) nonNullableInt(nu"
    out += "llableInt: $nullableInt, nonNullableInt: $nonNullableInt, no"
    out += "nNullableIntWithDefault: $nonNullableIntWithDefault, nullabl"
    out += "eInput: $nullableInput, nonNullableInput: $nonNullableInput,"
    out += " nonNullableInputWithDefault: $nonNullableInputWithDefault) "
    out += "nullableMyType { nullableInt nonNullableInt } nonNullableMyT"
    out += "ype { nullableInt nonNullableInt } nullableListOfNullableStr"
    out += "ing nullableListOfNonNullableString }\njava_guava_optionals"
    out += "\tMyQuery\tc9a856ba761821117e6a30df290b1259be46190a67a93d351"
    out += "fe3a648a4713435\tquery MyQuery($nullableInt: Int, $nonNullab"
    out += "leInt: Int!, $nonNullableIntWithDefault: Int! = 4 , $nullabl"
    out += "eInput: MyInput, $nonNullableInput: MyInput!, $nonNullableIn"
    out += "putWithDefault: MyInput! = { nonNullableInt: 4 } ) { nullabl"
    out += "eInt(nullableInt: $nullableInt, nonNullableInt: $nonNullable"
    out += "Int, nonNullableIntWithDefault: $nonNullableIntWithDefault, "
    out += "nullableInput: $nullableInput, nonNullableInput: $nonNullabl"
    out += "eInput, nonNullableInputWithDefault: $nonNullableInputWithDe"
    out += "fault) nonNullableInt(nullableInt: $nullableInt, nonNullable"
    out += "Int: $nonNullableInt, nonNullableIntWithDefault: $nonNullabl"
    out += "eIntWithDefault, nullableInput: $nullableInput, nonNullableI"
    out += "nput: $nonNullableInput, nonNullableInputWithDefault: $nonNu"
    out += "llableInputWithDefault) nullableMyType { nullableInt nonNull"
    out += "ableInt } nonNullableMyType { nullableInt nonNullableInt } n"
    out += "ullableListOfNullableString nullableListOfNonNullableString "
    out += "}\njava_hashcode\tTestQuery\t364c2cbd7ac173c53aefe10be9688f6"
    out += "c18dff4271f871be8f0b78dde44074068\tquery TestQuery { h }\nja"
    out += "va_java_optionals\tMyQuery\tc9a856ba761821117e6a30df290b1259"
    out += "be46190a67a93d351fe3a648a4713435\tquery MyQuery($nullableInt"
    out += ": Int, $nonNullableInt: Int!, $nonNullableIntWithDefault: In"
    out += "t! = 4 , $nullableInput: MyInput, $nonNullableInput: MyInput"
    out += "!, $nonNullableInputWithDefault: MyInput! = { nonNullableInt"
    out += ": 4 } ) { nullableInt(nullableInt: $nullableInt, nonNullable"
    out += "Int: $nonNullableInt, nonNullableIntWithDefault: $nonNullabl"
    out += "eIntWithDefault, nullableInput: $nullableInput, nonNullableI"
    out += "nput: $nonNullableInput, nonNullableInputWithDefault: $nonNu"
    out += "llableInputWithDefault) nonNullableInt(nullableInt: $nullabl"
    out += "eInt, nonNullableInt: $nonNullableInt, nonNullableIntWithDef"
    out += "ault: $nonNullableIntWithDefault, nullableInput: $nullableIn"
    out += "put, nonNullableInput: $nonNullableInput, nonNullableInputWi"
    out += "thDefault: $nonNullableInputWithDefault) nullableMyType { nu"
    out += "llableInt nonNullableInt } nonNullableMyType { nullableInt n"
    out += "onNullableInt } nullableListOfNullableString nullableListOfN"
    out += "onNullableString }\njava_jetbrains_annotations\tMyQuery\tc9a"
    out += "856ba761821117e6a30df290b1259be46190a67a93d351fe3a648a471343"
    out += "5\tquery MyQuery($nullableInt: Int, $nonNullableInt: Int!, $"
    out += "nonNullableIntWithDefault: Int! = 4 , $nullableInput: MyInpu"
    out += "t, $nonNullableInput: MyInput!, $nonNullableInputWithDefault"
    out += ": MyInput! = { nonNullableInt: 4 } ) { nullableInt(nullableI"
    out += "nt: $nullableInt, nonNullableInt: $nonNullableInt, nonNullab"
    out += "leIntWithDefault: $nonNullableIntWithDefault, nullableInput:"
    out += " $nullableInput, nonNullableInput: $nonNullableInput, nonNul"
    out += "lableInputWithDefault: $nonNullableInputWithDefault) nonNull"
    out += "ableInt(nullableInt: $nullableInt, nonNullableInt: $nonNulla"
    out += "bleInt, nonNullableIntWithDefault: $nonNullableIntWithDefaul"
    out += "t, nullableInput: $nullableInput, nonNullableInput: $nonNull"
    out += "ableInput, nonNullableInputWithDefault: $nonNullableInputWit"
    out += "hDefault) nullableMyType { nullableInt nonNullableInt } nonN"
    out += "ullableMyType { nullableInt nonNullableInt } nullableListOfN"
    out += "ullableString nullableListOfNonNullableString }\njava_jsr305"
    out += "_annotations\tMyQuery\tc9a856ba761821117e6a30df290b1259be461"
    out += "90a67a93d351fe3a648a4713435\tquery MyQuery($nullableInt: Int"
    out += ", $nonNullableInt: Int!, $nonNullableIntWithDefault: Int! = "
    out += "4 , $nullableInput: MyInput, $nonNullableInput: MyInput!, $n"
    out += "onNullableInputWithDefault: MyInput! = { nonNullableInt: 4 }"
    out += " ) { nullableInt(nullableInt: $nullableInt, nonNullableInt: "
    out += "$nonNullableInt, nonNullableIntWithDefault: $nonNullableIntW"
    out += "ithDefault, nullableInput: $nullableInput, nonNullableInput:"
    out += " $nonNullableInput, nonNullableInputWithDefault: $nonNullabl"
    out += "eInputWithDefault) nonNullableInt(nullableInt: $nullableInt,"
    out += " nonNullableInt: $nonNullableInt, nonNullableIntWithDefault:"
    out += " $nonNullableIntWithDefault, nullableInput: $nullableInput, "
    out += "nonNullableInput: $nonNullableInput, nonNullableInputWithDef"
    out += "ault: $nonNullableInputWithDefault) nullableMyType { nullabl"
    out += "eInt nonNullableInt } nonNullableMyType { nullableInt nonNul"
    out += "lableInt } nullableListOfNullableString nullableListOfNonNul"
    out += "lableString }\njava_primitive_types\tJavaPrimitiveQuery\t955"
    out += "e634c34cd7cd1d999806876aec12f800dbb9d36cc914e313b7a005034260"
    out += "5\tquery JavaPrimitiveQuery($nullableInt: Int, $nonNullableI"
    out += "nt: Int!, $nonNullableIntWithDefault: Int! = 4 , $nullableIn"
    out += "put: MyInput, $nonNullableInput: MyInput!, $nonNullableInput"
    out += "WithDefault: MyInput! = { nonNullableInt: 4 } ) { nullableIn"
    out += "t(nullableInt: $nullableInt, nonNullableInt: $nonNullableInt"
    out += ", nonNullableIntWithDefault: $nonNullableIntWithDefault, nul"
    out += "lableInput: $nullableInput, nonNullableInput: $nonNullableIn"
    out += "put, nonNullableInputWithDefault: $nonNullableInputWithDefau"
    out += "lt) nonNullableInt(nullableInt: $nullableInt, nonNullableInt"
    out += ": $nonNullableInt, nonNullableIntWithDefault: $nonNullableIn"
    out += "tWithDefault, nullableInput: $nullableInput, nonNullableInpu"
    out += "t: $nonNullableInput, nonNullableInputWithDefault: $nonNulla"
    out += "bleInputWithDefault) nullableMyType { nullableInt nonNullabl"
    out += "eInt } nonNullableMyType { nullableInt nonNullableInt } }\nl"
    out += "ist_field_clash\tTestQuery\t7ff234e260cd0239cd579487e50a6a7c"
    out += "3851dee41280941d22766193e8c4d477\tquery TestQuery { amenityC"
    out += "ategories { text } category }\nmerged_include\tTestQuery\t04"
    out += "be960ea987c2ecdae39be438ef48238012a14a3832a150246c279e9cbfcf"
    out += "b2\tquery TestQuery { hero { name } hero @include(if: false)"
    out += " { id } }\nmonomorphic\tTestQuery\tfd42891d34246c8eb8c35ffcf"
    out += "a1c8b99282f5a90e7e43ffcab1cdd5a13d8a241\tquery TestQuery { c"
    out += "at { __typename ... on Node { __typename ... on Animal { spe"
    out += "cies } } } }\nmultiple_fragments\tTestQuery\t17957893a92546c"
    out += "5a6a6c22ea23453c05b06d4bf74f3be7e2ecec5d89338e14c\tquery Tes"
    out += "tQuery { a { __typename ...aFragment } }  fragment fragment1"
    out += " on ANode { field1 }  fragment fragment2 on ANode { field2 }"
    out += "  fragment aFragment on A { node { __typename ...fragment1 ."
    out += "..fragment2 } }\nmutation_create_review\tCreateReviewForEpis"
    out += "ode\tb333ec8237cdc346478f07c98169eeb782c4afac1a0a8b94c62dfbc"
    out += "b27275b21\tmutation CreateReviewForEpisode($ep: Episode!, $r"
    out += "eview: ReviewInput!) { createReview(episode: $ep, review: $r"
    out += "eview) { stars commentary listOfListOfString listOfListOfEnu"
    out += "m listOfListOfCustom listOfListOfObject { name } } }\nmutati"
    out += "on_create_review_semantic_naming\tCreateReviewForEpisode\t0a"
    out += "f665fbb1ccec4fbec377a80b620cb423b737162848a7b16b842c2fa382b5"
    out += "4c\tmutation CreateReviewForEpisode($ep: Episode!, $review: "
    out += "ReviewInput!) { createReview(episode: $ep, review: $review) "
    out += "{ stars commentary } }\nnamed_fragment_delegate\tTestQuery\t"
    out += "73b2c830dc5cf246957890f00500cb83e254c050a6e6ad3ab8e6d9e4e26d"
    out += "bd60\tquery TestQuery { hero { __typename ...DroidDetails .."
    out += ".HumanDetails } }  fragment DroidDetails on Droid { name pri"
    out += "maryFunction friends { name } }  fragment HumanDetails on Hu"
    out += "man { name profileLink friendsConnection { edges { node { na"
    out += "me } } } }\nnamed_fragment_inside_inline_fragment\tGetHero\t"
    out += "9885eef2193cd56885e6e1bacd7f02b712820858880de6fb29b3f3b04458"
    out += "c831\tquery GetHero { hero { __typename ... on Character { _"
    out += "_typename ...characterName ...characterAppearsIn } } }  frag"
    out += "ment characterName on Character { name }  fragment character"
    out += "AppearsIn on Character { appearsIn }\nnamed_fragment_with_va"
    out += "riables\tGetUser\t1314916fa3163a17df2b7a0173e55fef3462150782"
    out += "4242308b3006e9ab4740b4\tquery GetUser($organizationId: Strin"
    out += "g!, $query: UserQuery!, $size: Int!) { __typename ...QueryFr"
    out += "agment }  fragment UserFragment on User { firstName lastName"
    out += " avatar(size: $size) }  fragment QueryFragment on Query { or"
    out += "ganization(id: $organizationId) { id user(query: $query) { _"
    out += "_typename ...UserFragment } } }\nnamed_fragment_without_impl"
    out += "ementation\tTestQuery\tbd506c9c818f2163b34753c735df7794c16d1"
    out += "35e4a8e6d24e2930e63eacf01df\tquery TestQuery { hero { __type"
    out += "name name ...HumanDetails ...DroidDetails } }  fragment Huma"
    out += "nDetails on Human { height }  fragment DroidDetails on Droid"
    out += " { primaryFunction }\nnested_conditional_inline\tTestQuery\t"
    out += "a9f066a7d1092096ab154f16f32114a4bd71e959b789f37879249cdf6309"
    out += "ea86\tquery TestQuery($episode: Episode) { hero(episode: $ep"
    out += "isode) { __typename name ... on Human { friends { __typename"
    out += " name ... on Human { height(unit: FOOT) } } } ... on Droid {"
    out += " friends { __typename name ... on Human { height(unit: METER"
    out += ") } } } } }\nnested_field_with_multiple_fieldsets\tTestQuery"
    out += "\t39e196d404a902ae82f38401080d30922ca3eadf8fd6dc53ef53d4673c"
    out += "6af264\tquery TestQuery { iface1 { __typename ... on Iface1 "
    out += "{ iface2 { __typename ... on Iface2 { scalar1 } ... on Impl2"
    out += " { scalar2 } } } ... on Impl1 { iface2 { __typename ... on I"
    out += "face2 { scalar3 } ... on Impl2 { scalar4 } } } } }\nnested_n"
    out += "amed_fragments\tAllStarships\ta76ec26a83546f1113b4f2d763d671"
    out += "18a12a70958ef57d44d3f33dedaf90ff72\tquery AllStarships { all"
    out += "Starships(first: 7) { edges { node { __typename ...starshipF"
    out += "ragment } } } }  fragment planetFragment on Planet { name } "
    out += " fragment pilotFragment on Person { name homeworld { __typen"
    out += "ame ...planetFragment } }  fragment starshipFragment on Star"
    out += "ship { id name pilotConnection { edges { node { __typename ."
    out += "..pilotFragment } } } }\nnot_all_combinations_are_needed\tTe"
    out += "stQuery\t16500a4d2f3e21ea2357fd3532aff655fc2b37e893570d1e8d1"
    out += "944c4af4f9f1d\tquery TestQuery { root { __typename ... on A "
    out += "{ __typename fieldA1 ... on B { __typename ...bFragment } } "
    out += "} }  fragment bFragment on B { fieldB1 }\nobject\tTestQuery"
    out += "\tbd6b7a2ff072ad667208aa68405e14eef396ea3931b1d0a0520841187f"
    out += "dff5ff\tquery TestQuery { object { random } }\noperationbase"
    out += "d2_ex7\tTestOperation\t7c26d34de71f3eedeb320747cb70ac07275fe"
    out += "2125d55c13a42be40e966f092e2\tquery TestOperation { animal { "
    out += "__typename ... on Animal { __typename species ... on WarmBlo"
    out += "oded { temperature } ... on Pet { name } } } }\noperationbas"
    out += "ed2_ex8\tTestOperation\t76f3639043a382e1d3caf22f8e89b4062473"
    out += "f12ffdda9067b6cc46c54259e2e2\tquery TestOperation { animal {"
    out += " __typename ...AnimalFragment } }  fragment AnimalFragment o"
    out += "n Animal { species parent { __typename species ... on Lion {"
    out += " temperature } ... on Cat { name } } }\noptional\tTestQuery"
    out += "\t9438477e508a2037f377e235bb022f24d375a02a5bb3dc6116c20c52e3"
    out += "0ff026\tquery TestQuery { hero { name appearsIn } }\npath_vs"
    out += "_flat_accessors\tTestQuery\t3b184fcb2cc03c785d68f3c22a4b89ef"
    out += "1a8240023d73c5dbd5f28223aee7d042\tquery TestQuery { root { _"
    out += "_typename ... on A { __typename ... on B { fieldB1 } } ... o"
    out += "n B { fieldB2 } } }\nrecursive_selection\tTestQuery\t0308cbb"
    out += "678ba65068f98c1e2db76c79bc46b6d4a171d6310a4bb5d98356651c5\tq"
    out += "uery TestQuery { tree { name children { name } parent { name"
    out += " } } }\nreserved_keywords\tTestQuery\td2f555fdc0bd9ea0a928c3"
    out += "9aa7818ac66b0c0a0870772b1fb57387c3c3cf8577\tquery TestQuery "
    out += "{ yield: hero { while: id it: name } objects: search(text: "
    out += '"abc") { __typename ... on Character { name } } }\nroot_qu'
    out += "ery_fragment\tTestQuery\t9c53d7ef056cfcd269d1bfd4137fdb5a41c"
    out += "ed7343ed524f03ec915c7a8d6f483\tquery TestQuery { __typename "
    out += "...QueryFragment }  fragment QueryFragment on Query { __type"
    out += "name hero { name } }\nroot_query_fragment_with_nested_fragme"
    out += "nts\tTestQuery\t28a70b2a9a393b236756d92edea600a8d90d3e5cfb24"
    out += "cdfeda92fec1b5778794\tquery TestQuery { __typename ...QueryF"
    out += "ragment }  fragment heroFragment on Character { name }  frag"
    out += "ment droidFragment on Droid { name primaryFunction }  fragme"
    out += "nt QueryFragment on Query { __typename hero { __typename ..."
    out += "heroFragment } droid(id: 1) { __typename ...droidFragment } "
    out += "human(id: 1) { __typename ... on Human { name homePlanet } }"
    out += " }\nroot_query_inline_fragment\tTestQuery\t25584d760eab0f411"
    out += "89b9f2bbdbba3c0ec491aced65ef23924ecdc8f41ffe78c\tquery TestQ"
    out += "uery { __typename ... on Query { __typename hero { __typenam"
    out += "e name appearsIn ... on Human { height } } droid(id: 1) { __"
    out += "typename ... on Droid { name primaryFunction } } } }\nsimple"
    out += "_fragment\tTestQuery\t590d21282ab1a5387ee626ec6ab47a1ba5fb1c"
    out += "93f8370ede7594be52e5d0f28f\tquery TestQuery { hero { __typen"
    out += "ame ...HeroDetails ...HumanDetails } }  fragment HumanDetail"
    out += "s on Human { __typename name }  fragment HeroDetails on Char"
    out += "acter { __typename ...HumanDetails }\nsimple_fragment_with_i"
    out += "nline_fragments\tTestQuery\t8e5edde6eecd2e5d94c3314f86d32413"
    out += "fdaea6cbe396360de2bc5b6f91e7536d\tquery TestQuery { hero { _"
    out += "_typename ...HeroDetails } }  fragment HeroDetails on Charac"
    out += "ter { name friends { __typename name ... on Human { height }"
    out += " ... on Droid { primaryFunction } } }\nsimple_inline_fragmen"
    out += "t\tTestQuery\t9788d8cb5185e8875c193d2e8aa5cb15fb66916d00f51b"
    out += "55a037b5b8ebffc788\tquery TestQuery { hero { __typename ... "
    out += "on Character { __typename id ... on Character { name } } ..."
    out += " on Human { height } ... on Droid { primaryFunction } } }\ns"
    out += "imple_union\tAnimalQuery\t0a4d6f7c4de2a81e6247e9f2205b24b2b4"
    out += "2e03c1f25fe7267e13fe1342d905d7\tquery AnimalQuery { animal {"
    out += " __typename ...CatFragment ...DogFragment } }  fragment CatF"
    out += "ragment on Cat { meow }  fragment DogFragment on Dog { woof "
    out += "}\nstarships\tTestQuery\tec95d84c104260ea1c99e15341279aaabe9"
    out += "8b7364279c2886a9ffe9adfeefb7f\tquery TestQuery($id: ID!) { s"
    out += "tarship(id: $id) { id name coordinates } }\nsubscriptions\tT"
    out += "estSubscription\tf053ee1afe42260f1511e417b6133f1cb8507c185e2"
    out += "e7b4e1e579696dbc8f2af\tsubscription TestSubscription($repo: "
    out += "String!) { commentAdded(repoFullName: $repo) { id content } "
    out += "}\nsuppressed_warnings\tCatQuery\ta9164e713b135ac6a07ce03604"
    out += "974a833b919eb0ff9099665d8e7ff076c2e2c5\tquery CatQuery($filt"
    out += "er: Filter) { search(filter: $filter) { mustaches } directio"
    out += "n }\ntarget_name\tTestQuery\t42f2acf77ef3db730fa970cbbba1ca0"
    out += "4133fcea023d8355d4eb0c27ebe51e30f\tquery TestQuery($input: R"
    out += "eservedInput, $scalar: ReservedScalar, $enum: ReservedEnum) "
    out += "{ object(input: $input) { field } interface { field } union "
    out += "{ __typename ... on ReservedObject { field } } scalar(scalar"
    out += ": $scalar) enum(enum: $enum) }\ntest_inline\tGetPage\t09dd0a"
    out += "176a2233eccc3b2d3a76f25a1083460354f399f8b1aaf172c18cfc202b\t"
    out += "query GetPage { collection { __typename items { title } ... "
    out += "on ParticularCollection { items { __typename ... on Particul"
    out += "arItem { image } } } } }\ntwo_heroes_unique\tTestQuery\t0a80"
    out += "8c27d1275380ed06d359e1dd1f2a890ab67186df249f66c1afec47972e22"
    out += "\tquery TestQuery { r2: hero { name } luke: hero(episode: EM"
    out += "PIRE) { id name } }\ntwo_heroes_with_friends\tTestQuery\t28b"
    out += "644b6fcd59e0677f51136035c5fc1deb6419f12b819bff2e6bf4c5f65991"
    out += "6\tquery TestQuery { r2: hero { name friendsConnection { tot"
    out += "alCount edges { node { name } } } } luke: hero(episode: EMPI"
    out += "RE) { id name friendsConnection { totalCount edges { node { "
    out += "name } } } } }\ntypename_always_first\tTestQuery\t5351cc2f9d"
    out += "ea89f8d8d9513a08a18eee20324eaba674211bf21f9c01cba9fdea\tquer"
    out += "y TestQuery { hero { __typename ... on Human { height __type"
    out += "name } ... on Droid { name __typename primaryFunction } } __"
    out += "typename }\ntypepolicy\tGetA\t64f5865843b43e7efa316fea6e9f6b"
    out += "175f0bc5d262d317306109dd68613547e4\tquery GetA { a { __typen"
    out += "ame ...AFragment1 id } }  fragment AFragment2 on A { bar myI"
    out += "d: id id __typename }  fragment AFragment1 on A { __typename"
    out += " foo ...AFragment2 id }\ntypepolicy\tGetInterfaceA\tfafa4b6a"
    out += "2fbfaebad5eb0b8643b861c74584addeaf7150298edecec92db79969\tqu"
    out += "ery GetInterfaceA { interfaceA { __typename ... on Interface"
    out += "A { interfaceAField } ... on B { idB } ... on C { idC } } }"
    out += "\ntypepolicy\tGetUnionA\tba33b4f46de278a6b35b63f9d681b03ad26"
    out += "ce7db817425d7ed9156e0bf7af54e\tquery GetUnionA { unionA { __"
    out += "typename ... on UnionA { __typename } ... on A { id } ... on"
    out += " B { idB } ... on C { idC } } }\nunion_fragment\tTestQuery\t"
    out += "6b4ab40afa26bf3c0c7d80ce98ca5288378f0323da59c6643d893efa510a"
    out += '6fec\tquery TestQuery { search(text: "test") { __typename '
    out += "... on Starship { id } ...Starship } }  fragment Starship on"
    out += " Starship { name }\nunion_inline_fragments\tTestQuery\t2c2de"
    out += "063c729a4ce1b51648279b6afd6372ac91ae33c304f4e33d20fb098cfc6"
    out += '\tquery TestQuery { search(text: "test") { __typename ... '
    out += "on Character { id name friends { __typename ... on Character"
    out += " { name } ... on Human { homePlanet friends { __typename ..."
    out += " on Character { firstAppearsIn } } } ... on Droid { primaryF"
    out += "unction friends { id } } } } ... on Starship { name } } }\nu"
    out += "nique_type_name\tHeroDetailQuery\t9e49497791948cf0840e8353d8"
    out += "7b142b6474e023a2082a3fe414b312565599de\tquery HeroDetailQuer"
    out += "y { heroDetailQuery { __typename name friends { name } ... o"
    out += "n Human { height friends { appearsIn friends { __typename .."
    out += ".HeroDetails } } } } }  fragment HeroDetails on Character { "
    out += "name friendsConnection { totalCount edges { node { name } } "
    out += "} }\nused_arguments\tGetA\t9ea4fe0d8d5f625417b080b65cba65b99"
    out += "4059847d59fac8d092ffd51eb6cd39e\tquery GetA { a { __typename"
    out += " ... on B { field(arg: 42) } ... on C { field(arg: 42) } } }"
    out += "\nvariable_default_value\tTestQuery\t7bba59b12a0090dd1fbc4c4"
    out += "09ea7e72bd6885a6b31d442bfeb86f4a67e5b62d9\tquery TestQuery($"
    out += "episode: Episode! = JEDI ) { hero(episode: $episode) { name "
    out += "} }\n"
    return out^


def _path_172() -> String:
    var out = String()
    out += "operationbased2_ex7/TestOperation.graphql"
    return out^


def _file_172() -> String:
    var out = String()
    out += "query TestOperation {\n  animal {\n    ... on Animal {\n    "
    out += "  species\n      # Nested WarmBlooded\n      ... on WarmBloo"
    out += "ded {\n        temperature\n      }\n      # Nested Pet\n   "
    out += "   ... on Pet {\n        name\n      }\n    }\n  }\n}"
    return out^


def _path_173() -> String:
    var out = String()
    out += "operationbased2_ex7/schema.graphqls"
    return out^


def _file_173() -> String:
    var out = String()
    out += "schema {\n  query: Query\n}\n\ninterface Animal {\n  species"
    out += ": String!\n}\n\ninterface Pet {\n  name: String!\n}\n\ninter"
    out += "face WarmBlooded {\n  temperature: Int!\n}\n\ntype Lion impl"
    out += "ements Animal & WarmBlooded {\n  species: String!\n  tempera"
    out += "ture: Int!\n}\ntype Cat implements Animal & WarmBlooded & Pe"
    out += "t {\n  species: String!\n  name: String!\n  temperature: Int"
    out += "!\n}\ntype Turtle implements Animal & Pet {\n  species: Stri"
    out += "ng!\n  name: String!\n}\ntype Panther implements Animal & Wa"
    out += "rmBlooded {\n  species: String!\n  temperature: Int!\n}\n\nt"
    out += "ype Query {\n  animal: Animal\n}\n"
    return out^


def _path_174() -> String:
    var out = String()
    out += "operationbased2_ex7/used-coordinates.json.expected"
    return out^


def _file_174() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Animal": {'
    out += '},\n        "Int": {},\n        "String": {},\n        '
    out += '"Query": {}\n    }\n}'
    return out^


def _path_175() -> String:
    var out = String()
    out += "operationbased2_ex8/TestOperation.graphql"
    return out^


def _file_175() -> String:
    var out = String()
    out += "query TestOperation {\n  animal {\n    ... AnimalFragment\n "
    out += " }\n}\nfragment AnimalFragment on Animal {\n  species\n  par"
    out += "ent {\n    species\n    ... on Lion {\n      temperature\n  "
    out += "  }\n    ... on Cat {\n      name\n    }\n  }\n}"
    return out^


def _path_176() -> String:
    var out = String()
    out += "operationbased2_ex8/schema.graphqls"
    return out^


def _file_176() -> String:
    var out = String()
    out += "schema {\n  query: Query\n}\n\ninterface Animal {\n  species"
    out += ": String!\n  parent: Animal!\n}\n\ninterface Pet {\n  name: "
    out += "String!\n}\n\ninterface WarmBlooded {\n  temperature: Int!\n"
    out += "}\n\ntype Lion implements Animal & WarmBlooded {\n  species:"
    out += " String!\n  temperature: Int!\n  parent: Animal!\n}\ntype Ca"
    out += "t implements Animal & WarmBlooded & Pet {\n  species: String"
    out += "!\n  name: String!\n  temperature: Int!\n  parent: Animal!\n"
    out += "}\ntype Turtle implements Animal & Pet {\n  species: String!"
    out += "\n  name: String!\n  parent: Animal!\n}\ntype Panther implem"
    out += "ents Animal & WarmBlooded {\n  species: String!\n  temperatu"
    out += "re: Int!\n  parent: Animal!\n}\n\ntype Query {\n  animal: An"
    out += "imal\n}\n"
    return out^


def _path_177() -> String:
    var out = String()
    out += "operationbased2_ex8/used-coordinates.json.expected"
    return out^


def _file_177() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Animal": {'
    out += '},\n        "String": {},\n        "Query": {},\n       '
    out += ' "Int": {}\n    }\n}'
    return out^


def _path_178() -> String:
    var out = String()
    out += "path_vs_flat_accessors/TestOperation.graphql"
    return out^


def _file_178() -> String:
    var out = String()
    out += "# This test generating accessors based on the inline fragmen"
    out += "t path input by the user versus\n# a more global approach. M"
    out += "atching the user input is more predictable but also more ver"
    out += "bose\n# User input: root.asA.asB (root.asB.asA doesn't make "
    out += "sense and is not possible)\n# Global: root.asAB (how to end "
    out += "up with AB doesn't matter)\nquery TestQuery {\n    root {\n "
    out += "       ... on A {\n            ... on B {\n                f"
    out += "ieldB1\n            }\n        }\n        ... on B {\n      "
    out += "      fieldB2\n        }\n    }\n}\n"
    return out^


def _path_179() -> String:
    var out = String()
    out += "path_vs_flat_accessors/schema.graphqls"
    return out^


def _file_179() -> String:
    var out = String()
    out += "type Query {\n  root: C\n}\n\ninterface A {\n  fieldA1: Stri"
    out += "ng\n  fieldA2: String\n}\n\ninterface B {\n  fieldB1: String"
    out += "\n  fieldB2: String\n}\ninterface C {\n  fieldC: String\n}\n"
    out += "\ntype ABC implements A & B & C {\n  fieldA1: String\n  fiel"
    out += "dA2: String\n  fieldB1: String\n  fieldB2: String\n  fieldC:"
    out += " String\n}\n\ntype AC implements A & C {\n  fieldA1: String"
    out += "\n  fieldA2: String\n  fieldC: String\n}\n\ntype BC implemen"
    out += "ts B & C {\n  fieldB1: String\n  fieldB2: String\n  fieldC: "
    out += "String\n}\n\ntype SomeC implements C {\n  fieldC: String\n}"
    out += "\n"
    return out^


def _path_180() -> String:
    var out = String()
    out += "path_vs_flat_accessors/used-coordinates.json.expected"
    return out^


def _file_180() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "C": {},\n '
    out += '       "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_181() -> String:
    var out = String()
    out += "recursive_selection/TestOperation.graphql"
    return out^


def _file_181() -> String:
    var out = String()
    out += "query TestQuery {\n  tree {\n    name\n    children {\n     "
    out += " name\n    }\n    parent {\n      name\n    }\n  }\n}\n"
    return out^


def _path_182() -> String:
    var out = String()
    out += "recursive_selection/used-coordinates.json.expected"
    return out^


def _file_182() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Tree": {},'
    out += '\n        "String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_183() -> String:
    var out = String()
    out += "reserved_keywords/TestOperation.graphql"
    return out^


def _file_183() -> String:
    var out = String()
    out += "query TestQuery {\n  yield: hero {\n    while: id\n    it: n"
    out += 'ame\n  }\n\n  objects: search(text: "abc") {\n    ... on C'
    out += "haracter {\n      name\n    }\n  }\n}\n"
    return out^


def _path_184() -> String:
    var out = String()
    out += "reserved_keywords/used-coordinates.json.expected"
    return out^


def _file_184() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "SearchResult": {},\n        "Query": {\n'
    out += '            "search": [\n                "text"\n       '
    out += '     ]\n        },\n        "ID": {},\n        "String":'
    out += ' {},\n        "Human": {},\n        "Droid": {},\n      '
    out += '  "Starship": {}\n    }\n}'
    return out^


def _path_185() -> String:
    var out = String()
    out += "root_query_fragment/TestOperation.graphql"
    return out^


def _file_185() -> String:
    var out = String()
    out += "query TestQuery {\n  ...QueryFragment\n}\n\nfragment QueryFr"
    out += "agment on Query {\n  __typename\n  hero {\n    name\n  }\n}"
    out += "\n"
    return out^


def _path_186() -> String:
    var out = String()
    out += "root_query_fragment/used-coordinates.json.expected"
    return out^


def _file_186() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "String": {'
    out += '},\n        "Query": {},\n        "Character": {}\n    }'
    out += "\n}"
    return out^


def _path_187() -> String:
    var out = String()
    out += "root_query_fragment_with_nested_fragments/TestOperation.grap"
    out += "hql"
    return out^


def _file_187() -> String:
    var out = String()
    out += "query TestQuery {\n  ...QueryFragment\n}\n\nfragment QueryFr"
    out += "agment on Query {\n  __typename\n  hero {\n    ...heroFragme"
    out += "nt\n  }\n  droid(id: 1) {\n    ...droidFragment\n  }\n  huma"
    out += "n(id: 1) {\n    ... on Human {\n      name\n      homePlanet"
    out += "\n    }\n  }\n}\n\nfragment heroFragment on Character {\n  n"
    out += "ame\n}\n\nfragment droidFragment on Droid {\n  name\n  prima"
    out += "ryFunction\n}\n"
    return out^


def _path_188() -> String:
    var out = String()
    out += "root_query_fragment_with_nested_fragments/used-coordinates.j"
    out += "son.expected"
    return out^


def _file_188() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "String": {'
    out += '},\n        "Query": {\n            "droid": [\n        '
    out += '        "id"\n            ],\n            "human": [\n  '
    out += '              "id"\n            ]\n        },\n        "C'
    out += 'haracter": {},\n        "Droid": {},\n        "Human": '
    out += "{}\n    }\n}"
    return out^


def _path_189() -> String:
    var out = String()
    out += "root_query_inline_fragment/TestOperation.graphql"
    return out^


def _file_189() -> String:
    var out = String()
    out += "query TestQuery {\n  ... on Query {\n    __typename\n    her"
    out += "o {\n      name\n      appearsIn\n      ... on Human {\n    "
    out += "    height\n      }\n    }\n    droid(id: 1) {\n      ... on"
    out += " Droid {\n        name\n        primaryFunction\n      }\n  "
    out += "  }\n  }\n}\n"
    return out^


def _path_190() -> String:
    var out = String()
    out += "root_query_inline_fragment/used-coordinates.json.expected"
    return out^


def _file_190() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "String": {'
    out += '},\n        "Character": {},\n        "Droid": {},\n    '
    out += '    "Query": {\n            "droid": [\n                '
    out += '"id"\n            ]\n        },\n        "Float": {},\n '
    out += '       "Episode": {}\n    }\n}'
    return out^


def _path_191() -> String:
    var out = String()
    out += "schema.graphqls"
    return out^


def _file_191() -> String:
    var out = String()
    out += '"""Dummy directive that can be placed on operations.""'
    out += '"\ndirective @operationDirective(\n  """blah"""\n  du'
    out += 'mmy: String!\n) on QUERY | MUTATION | SUBSCRIPTION\n\n"""'
    out += 'For testing fragment type coercion"""\ninterface Bar {\n '
    out += " bar: String!\n}\n\ntype BarObject implements Bar {\n  bar: "
    out += 'String!\n}\n\n"""A character from the Star Wars universe'
    out += '"""\ninterface Character {\n  """The dates of appearan'
    out += 'ces"""\n  appearanceDates: [Date!]!\n\n  """The movies'
    out += ' this character appears in"""\n  appearsIn: [Episode]!\n'
    out += '\n  """The date character was born."""\n  birthDate: D'
    out += 'ate!\n\n  """Test deprecated field"""\n  deprecated: S'
    out += 'tring! @deprecated(reason: "For test purpose only")\n\n  '
    out += '"""Test deprecated field"""\n  deprecatedBool: Boolean'
    out += '! @deprecated(reason: "For test purpose only")\n\n  """'
    out += 'The date character was born."""\n  fieldWithUnsupportedTy'
    out += 'pe: UnsupportedType!\n\n  """The movie this character fir'
    out += 'st appears in"""\n  firstAppearsIn: Episode!\n\n  """T'
    out += "he friends of the character, or an empty list if they have n"
    out += 'one"""\n  friends: [Character]\n\n  """The friends of '
    out += 'the character exposed as a connection with edges"""\n  fr'
    out += "iendsConnection(first: Int, after: ID): FriendsConnection!\n"
    out += '\n  """The ID of the character"""\n  id: ID!\n\n  ""'
    out += '"Links"""\n  links: [URL!]!\n\n  """The name of the c'
    out += 'haracter"""\n  name: String!\n\n  """Profile link""'
    out += '"\n  profileLink: URL!\n\n  """Hero type"""\n  type: '
    out += 'hero_type!\n}\n\n"""The input object sent when passing in'
    out += ' a color"""\ninput colorInput {\n  """\n  A descriptio'
    out += 'n with a dollar sign: $10\n  """\n  red: Int! = 1\n\n  "'
    out += '""Green color"""\n  green: Float = 0\n\n  """Blue co'
    out += 'lor"""\n  blue: Float! = 1.5\n\n  """for test purpose '
    out += 'only"""\n  enumWithDefaultValue: Episode = new\n\n  ""'
    out += '"Circle ref to review input"""\n  reviewRefInput: Review'
    out += 'RefInput\n}\n\n"""The `Date` scalar type represents date '
    out += 'format."""\nscalar Date\n\n"""An autonomous mechanical'
    out += ' character in the Star Wars universe"""\ntype Droid imple'
    out += 'ments Character {\n  """The dates of appearances"""\n '
    out += ' appearanceDates: [Date!]!\n\n  """The movies this droid '
    out += 'appears in"""\n  appearsIn: [Episode]!\n\n  """The dat'
    out += 'e droid was created."""\n  birthDate: Date!\n\n  """Te'
    out += 'st deprecated field"""\n  deprecated: String! @deprecated'
    out += '(reason: "For test purpose only")\n\n  """Test deprecat'
    out += 'ed field"""\n  deprecatedBool: Boolean! @deprecated(reaso'
    out += 'n: "For test purpose only")\n\n  """The date character '
    out += 'was born."""\n  fieldWithUnsupportedType: UnsupportedType'
    out += '!\n\n  """The movie this character first appears in"""'
    out += '\n  firstAppearsIn: Episode!\n\n  """This droid\'s friends'
    out += ', or an empty list if they have none"""\n  friends: [Char'
    out += 'acter]\n\n  """The friends of the droid exposed as a conn'
    out += 'ection with edges"""\n  friendsConnection(first: Int, aft'
    out += 'er: ID): FriendsConnection!\n\n  """The ID of the droid"'
    out += '""\n  id: ID!\n\n  """Links"""\n  links: [URL!]!\n\n'
    out += '  """What others call this droid"""\n  name: String!\n'
    out += '\n  """This droid\'s primary function"""\n  primaryFunc'
    out += 'tion: String\n\n  """Profile link"""\n  profileLink: U'
    out += 'RL!\n\n  """Hero type"""\n  type: hero_type!\n}\n\n"'
    out += '""The episodes in the Star Wars trilogy"""\nenum Episod'
    out += 'e {\n  """Star Wars Episode IV: A New Hope, released in 1'
    out += '977."""\n  NEWHOPE\n\n  """Star Wars Episode V: The Em'
    out += 'pire Strikes Back, released in 1980."""\n  EMPIRE\n\n  "'
    out += '""Star Wars Episode VI: Return of the Jedi, released in 19'
    out += '83."""\n  JEDI\n\n  """Test deprecated enum value""'
    out += '"\n  DEPRECATED @deprecated(reason: "For test purpose only'
    out += '")\n\n  """Test java reserved word"""\n  new @depreca'
    out += 'ted(reason: "For test purpose only")\n}\n\n"""For testi'
    out += 'ng fragment type coercion"""\ninterface Foo {\n  foo: Str'
    out += 'ing!\n}\n\n"""For testing fragment type coercion"""\nt'
    out += "ype FooBar implements Foo & Bar {\n  bar: String!\n  foo: St"
    out += 'ring!\n}\n\n"""For testing fragment type coercion"""\n'
    out += 'type FooObject implements Foo {\n  foo: String!\n}\n\n"""'
    out += 'A connection object for a character\'s friends"""\ntype Fr'
    out += 'iendsConnection {\n  """The edges for each of the charact'
    out += 'er\'s friends."""\n  edges: [FriendsEdge]\n\n  """A lis'
    out += "t of the friends, as a convenience when edges are not needed"
    out += '."""\n  friends: [Character]\n\n  """For test java bea'
    out += 'ns semantic naming only"""\n  isEmpty: Boolean!\n\n  ""'
    out += '"Information for paginating this connection"""\n  pageIn'
    out += 'fo: PageInfo!\n\n  """The total number of friends"""\n'
    out += '  totalCount: Int\n}\n\n"""An edge object for a character'
    out += '\'s friends"""\ntype FriendsEdge {\n  """A cursor used '
    out += 'for pagination"""\n  cursor: ID!\n\n  """The character'
    out += ' represented by this friendship edge"""\n  node: Characte'
    out += 'r\n}\n\n"""Lower case enum type name"""\nenum hero_typ'
    out += 'e {\n  human\n  droid\n}\n\n"""A humanoid creature from t'
    out += 'he Star Wars universe"""\ntype Human implements Character'
    out += ' {\n  """The dates of appearances"""\n  appearanceDate'
    out += 's: [Date!]!\n\n  """The movies this human appears in""'
    out += '"\n  appearsIn: [Episode]!\n\n  """The date character wa'
    out += 's born."""\n  birthDate: Date!\n\n  """Test deprecated'
    out += ' field"""\n  deprecated: String! @deprecated(reason: "Fo'
    out += 'r test purpose only")\n\n  """Test deprecated field""'
    out += '"\n  deprecatedBool: Boolean! @deprecated(reason: "For tes'
    out += 't purpose only")\n\n  """The date character was born."'
    out += '""\n  fieldWithUnsupportedType: UnsupportedType!\n\n  ""'
    out += '"The movie this character first appears in"""\n  firstAp'
    out += 'pearsIn: Episode!\n\n  """This human\'s friends, or an emp'
    out += 'ty list if they have none"""\n  friends: [Character]\n\n '
    out += ' """The friends of the human exposed as a connection with'
    out += ' edges"""\n  friendsConnection(first: Int, after: ID): Fr'
    out += 'iendsConnection!\n\n  """Height in the preferred unit, de'
    out += 'fault is meters"""\n  height(unit: LengthUnit = METER): F'
    out += 'loat\n\n  """The home planet of the human, or null if unk'
    out += 'nown"""\n  homePlanet: String\n\n  """The ID of the hu'
    out += 'man"""\n  id: ID!\n\n  """Links"""\n  links: [URL!]'
    out += '!\n\n  """Mass in kilograms, or null if unknown"""\n  '
    out += 'mass: Float\n\n  """What this human calls themselves""'
    out += '"\n  name: String!\n\n  """Profile link"""\n  profile'
    out += 'Link: URL!\n\n  """A list of starships this person has pi'
    out += 'loted, or an empty list if none"""\n  starships: [Starshi'
    out += 'p]\n\n  """Hero type"""\n  type: hero_type!\n}\n\n""'
    out += '"Units of height"""\nenum LengthUnit {\n  """The stan'
    out += 'dard unit around the world"""\n  METER\n\n  """Primari'
    out += 'ly used in the United States"""\n  FOOT\n}\n\n"""The m'
    out += "utation type, represents all updates we can make to our data"
    out += '"""\ntype Mutation {\n  createReview(episode: Episode, re'
    out += 'view: ReviewInput!): Review\n}\n\n"""Information for pagi'
    out += 'nating this connection"""\ntype PageInfo {\n  endCursor: '
    out += 'ID\n  hasNextPage: Boolean!\n  startCursor: ID\n}\n\n"""'
    out += "\nThe query type, represents all of the entry points into ou"
    out += 'r object graph\n"""\ntype Query {\n  character(id: ID!): '
    out += "Character\n  droid(id: ID!): Droid\n\n  testNullableArgument"
    out += "s(\n      int: Int,\n      float: Float,\n      string: Stri"
    out += "ng,\n      episode: Episode,\n      review: ReviewInput,\n  "
    out += '    boolean: Boolean,\n      list: [Episode]): Int!\n\n  "'
    out += '""For testing fragment type coercion"""\n  foo: Foo\n  '
    out += 'hero(\n    episode: Episode\n\n    """for test purpose on'
    out += 'ly"""\n    listOfListOfStringArgs: [[String]]\n  ): Chara'
    out += "cter\n  heroDetailQuery: Character\n  heroWithReview(\n    e"
    out += 'pisode: Episode\n    review: ReviewInput\n\n    """for te'
    out += 'st purpose only"""\n    listOfInts: [Int]\n  ): Human\n  '
    out += "human(id: ID!): Human\n  nonOptionalHero(episode: Episode): "
    out += "Character!\n  reviews(episode: Episode!, starsInt: Int, star"
    out += "sFloat: Float): [Review]\n  search(text: String): [SearchRes"
    out += "ult]\n  starship(id: ID!): Starship\n  tree: Tree\n  typeWit"
    out += "hGraphQLKeywords: TypeWithGraphQLKeywords\n  getBoolean(bool"
    out += "eanArg: Boolean): Boolean\n  listOfString: ListOfString\n  n"
    out += "onNullTimestamp: Timestamp!\n  nullableTimestamp: Timestamp"
    out += "\n  nonNullListOfNonNullTimestamp: [Timestamp!]!\n  nonNullL"
    out += "istOfNullableTimestamp: [Timestamp]!\n  nullableListOfNonNul"
    out += "lTimestamp: [Timestamp!]\n  nullableListOfNullableTimestamp:"
    out += ' [Timestamp]\n}\n\n"""Represents a review for a movie""'
    out += '"\ntype Review {\n  """Comment about the movie"""\n  '
    out += 'commentary: String\n\n  """for test purpose only"""\n '
    out += ' listOfListOfCustom: [[Date!]!]\n\n  """for test purpose '
    out += 'only"""\n  listOfListOfEnum: [[Episode!]!]\n\n  """for'
    out += ' test purpose only"""\n  listOfListOfObject: [[Character!'
    out += ']!]\n\n  """for test purpose only"""\n  listOfListOfSt'
    out += 'ring: [[String!]!]\n\n  """The number of stars this revie'
    out += 'w gave, 1-5"""\n  stars: Int!\n}\n\n"""The input objec'
    out += 't sent when someone is creating a new review"""\ninput Re'
    out += 'viewInput {\n  """0-5 stars"""\n  stars: Int!\n\n  "'
    out += '""for test purpose only"""\n  nullableIntFieldWithDefau'
    out += 'ltValue: Int = 10\n\n  """Comment about the movie, option'
    out += 'al"""\n  commentary: String\n\n  """Favorite color, op'
    out += 'tional"""\n  favoriteColor: colorInput!\n\n  """for te'
    out += 'st purpose only"""\n  enumWithDefaultValue: Episode = JED'
    out += 'I\n\n  """for test purpose only"""\n  nonNullableEnumW'
    out += 'ithDefaultValue: Episode! = JEDI\n\n  """for test purpose'
    out += ' only"""\n  nullableEnum: Episode\n\n  """for test pur'
    out += 'pose only"""\n  listOfCustomScalar: [Date] = ["1984-06-2'
    out += '1", "1984-11-21"]\n\n  """for test purpose only"""'
    out += '\n  customScalar: Date = "1984-06-21"\n\n  """for test '
    out += 'purpose only"""\n  listOfEnums: [Episode] = [NEWHOPE, EMP'
    out += 'IRE]\n\n  """for test purpose only"""\n  listOfInt: [I'
    out += 'nt] = [1, 2, 3]\n\n  """for test purpose only"""\n  li'
    out += 'stOfString: [String] = ["test1", "test2", "test3"]\n\n'
    out += '  """for test purpose only"""\n  listOfStringNonOption'
    out += 'al: [String]!\n\n  """for test purpose only"""\n  list'
    out += 'OfInputTypes: [colorInput] = []\n\n  """for test purpose '
    out += 'only"""\n  booleanWithDefaultValue: Boolean = true\n\n  '
    out += '"""for test purpose only"""\n  booleanNonOptional: Boo'
    out += 'lean\n\n  """for test purpose only"""\n  listOfListOfS'
    out += 'tring: [[String!]!]\n\n  """for test purpose only"""\n'
    out += '  listOfListOfEnum: [[Episode!]!]\n\n  """for test purpos'
    out += 'e only"""\n  listOfListOfCustom: [[Date!]!]\n\n  """fo'
    out += 'r test purpose only"""\n  listOfListOfObject: [[colorInpu'
    out += 't!]!]\n\n  """for test purpose only"""\n  CapitalizedF'
    out += 'ield: String\n\n  """for test purpose only"""\n  Capit'
    out += 'alizedInt: Int\n\n  """for test purpose only"""\n  in:'
    out += ' String\n}\n\n"""Circle ref to review input"""\ninput '
    out += "ReviewRefInput {\n  reviewInput: ReviewInput\n}\n\nunion Sea"
    out += "rchResult = Human | Droid | Starship\n\ntype Starship {\n  c"
    out += 'oordinates: [[Float!]!]\n\n  """The ID of the starship"'
    out += '""\n  id: ID!\n\n  """Length of the starship, along the'
    out += ' longest axis"""\n  length(unit: LengthUnit = METER): Flo'
    out += 'at\n\n  """The name of the starship"""\n  name: String'
    out += '!\n}\n\n"""To test recursive structures"""\ntype Tree '
    out += "{\n  children: [Tree!]!\n  name: String!\n  parent: Tree\n}"
    out += '\n\n"""UnsupportedType for testing"""\nscalar Unsuppor'
    out += 'tedType\n\n"""URL for testing"""\nscalar URL\n\ntype T'
    out += "ypeWithGraphQLKeywords {\n  on: String\n  null(fragment: Str"
    out += "ing): String\n}\n\nscalar ListOfString\n\nscalar Timestamp\n"
    out += "\n# TODO: remove when defer becomes part of the draft\ndirec"
    out += "tive @defer(\n  label: String\n  if: Boolean! = true\n) on F"
    out += "RAGMENT_SPREAD | INLINE_FRAGMENT\n\n# TODO: remove when defe"
    out += "r becomes part of the draft\ndirective @stream(\n  label: St"
    out += "ring\n  if: Boolean! = true\n  initialCount: Int = 0\n) on F"
    out += "IELD\n"
    return out^


def _path_192() -> String:
    var out = String()
    out += "simple_fragment/TestOperation.graphql"
    return out^


def _file_192() -> String:
    var out = String()
    out += '"""\nDemonstration of Java / Kotlin docs generation\nfor '
    out += 'both query and fragments\n"""\nquery TestQuery {\n  hero '
    out += "{\n    __typename\n    ...HeroDetails\n    ...HumanDetails\n"
    out += '  }\n}\n\n"""\nFragment with Java / Kotlin docs generatio'
    out += 'n\nwith multi lines support\n"""\nfragment HeroDetails on'
    out += ' Character {\n  __typename\n  ... HumanDetails\n}\n\n"""'
    out += '\nFragment with Java / Kotlin docs generation\n"""\nfragm'
    out += "ent HumanDetails on Human {\n  __typename\n  name\n}\n"
    return out^


def _path_193() -> String:
    var out = String()
    out += "simple_fragment/used-coordinates.json.expected"
    return out^


def _file_193() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {\n            "__typename": []\n        },\n        "Q'
    out += 'uery": {\n            "hero": []\n        },\n        "S'
    out += 'tring": {},\n        "Human": {\n            "__typename'
    out += '": [],\n            "name": []\n        }\n    }\n}'
    return out^


def _path_194() -> String:
    var out = String()
    out += "simple_fragment_with_inline_fragments/TestOperation.graphql"
    return out^


def _file_194() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ...HeroDetails\n  }\n}\n\nf"
    out += "ragment HeroDetails on Character {\n  name\n  friends {\n   "
    out += " name\n    ... on Human {\n      height\n    }\n    ... on D"
    out += "roid {\n      primaryFunction\n    }\n  }\n}\n"
    return out^


def _path_195() -> String:
    var out = String()
    out += "simple_fragment_with_inline_fragments/used-coordinates.json."
    out += "expected"
    return out^


def _file_195() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Query": {},\n    '
    out += '    "Float": {}\n    }\n}'
    return out^


def _path_196() -> String:
    var out = String()
    out += "simple_inline_fragment/TestOperation.graphql"
    return out^


def _file_196() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ... on Character {\n      i"
    out += "d\n      ... on Character {\n        name\n      }\n    }\n "
    out += "   ... on Human {\n      height\n    }\n    ... on Droid {\n"
    out += "      primaryFunction\n    }\n  }\n}\n"
    return out^


def _path_197() -> String:
    var out = String()
    out += "simple_inline_fragment/used-coordinates.json.expected"
    return out^


def _file_197() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "ID": {},\n       '
    out += ' "Float": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_198() -> String:
    var out = String()
    out += "simple_union/TestOperation.graphql"
    return out^


def _file_198() -> String:
    var out = String()
    out += "query AnimalQuery {\n    animal {\n        ...CatFragment\n "
    out += "       ...DogFragment\n    }\n}\n\nfragment CatFragment on C"
    out += "at {\n    meow\n}\n\nfragment DogFragment on Dog {\n    woof"
    out += "\n}"
    return out^


def _path_199() -> String:
    var out = String()
    out += "simple_union/schema.graphqls"
    return out^


def _file_199() -> String:
    var out = String()
    out += "type Query {\n  animal: Animal\n}\n\nunion Animal = Cat | Do"
    out += "g\n\ntype Cat {\n  meow: String!\n}\n\ntype Dog {\n  woof: S"
    out += "tring!\n}\n"
    return out^


def _path_200() -> String:
    var out = String()
    out += "simple_union/used-coordinates.json.expected"
    return out^


def _file_200() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Animal": {'
    out += '},\n        "String": {},\n        "Query": {},\n       '
    out += ' "Cat": {},\n        "Dog": {}\n    }\n}'
    return out^


def _path_201() -> String:
    var out = String()
    out += "starships/TestOperation.graphql"
    return out^


def _file_201() -> String:
    var out = String()
    out += "query TestQuery($id: ID!) {\n  starship(id: $id) {\n    id,"
    out += "\n    name,\n    coordinates\n  }\n}\n"
    return out^


def _path_202() -> String:
    var out = String()
    out += "starships/used-coordinates.json.expected"
    return out^


def _file_202() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Starship":'
    out += ' {},\n        "Query": {\n            "starship": [\n   '
    out += '             "id"\n            ]\n        },\n        "ID'
    out += '": {},\n        "String": {},\n        "Float": {}\n   '
    out += " }\n}"
    return out^


def _path_203() -> String:
    var out = String()
    out += "subscriptions/TestOperation.graphql"
    return out^


def _file_203() -> String:
    var out = String()
    out += "subscription TestSubscription($repo: String!) {\n  commentAd"
    out += "ded(repoFullName: $repo) {\n    id\n    content\n  }\n}"
    return out^


def _path_204() -> String:
    var out = String()
    out += "subscriptions/schema.graphqls"
    return out^


def _file_204() -> String:
    var out = String()
    out += '"""A comment about an entry, submitted by a user"""\nt'
    out += 'ype Comment {\n  """The text of the comment"""\n  cont'
    out += 'ent: String!\n\n  """A timestamp of when the comment was '
    out += 'posted"""\n  createdAt: Float!\n\n  """The SQL ID of t'
    out += 'his entry"""\n  id: Int!\n\n  """The GitHub user who p'
    out += 'osted the comment"""\n  postedBy: User\n\n  """The rep'
    out += 'ository which this comment is about"""\n  repoName: Strin'
    out += 'g!\n}\n\n"""Information about a GitHub repository submitt'
    out += 'ed to GitHunt"""\ntype Entry {\n  """The number of com'
    out += 'ments posted about this repository"""\n  commentCount: In'
    out += 't!\n\n  """Comments posted about this repository"""\n '
    out += ' comments(limit: Int, offset: Int): [Comment]!\n\n  """A '
    out += 'timestamp of when the entry was submitted"""\n  createdAt'
    out += ': Float!\n\n  """The hot score of this repository"""\n'
    out += '  hotScore: Float!\n\n  """The SQL ID of this entry"""'
    out += '\n  id: Int!\n\n  """The GitHub user who submitted this e'
    out += 'ntry"""\n  postedBy: User\n\n  """Information about th'
    out += 'e repository from GitHub"""\n  repository: Repository\n\n'
    out += '  """The score of this repository, upvotes - downvotes"'
    out += '""\n  score: Int!\n\n  """XXX to be changed"""\n  vo'
    out += 'te: Vote!\n}\n\n"""A list of options for the sort order o'
    out += 'f the feed"""\nenum FeedType {\n  """Sort by a combina'
    out += 'tion of freshness and score, using Reddit\'s algorithm"""'
    out += '\n  HOT\n\n  """Newest entries first"""\n  NEW\n\n  "'
    out += '""Highest score entries first"""\n  TOP\n}\n\ntype Muta'
    out += 'tion {\n  """Comment on a repository, returns the new com'
    out += 'ment"""\n  submitComment(\n    """\n    The full repos'
    out += 'itory name from GitHub, e.g. "apollostack/GitHunt-API"\n  '
    out += '  """\n    repoFullName: String!\n\n    """The text co'
    out += 'ntent for the new comment"""\n    commentContent: String!'
    out += '\n  ): Comment\n\n  """Submit a new repository, returns t'
    out += 'he new submission"""\n  submitRepository(\n    """\n  '
    out += '  The full repository name from GitHub, e.g. "apollostack/G'
    out += 'itHunt-API"\n    """\n    repoFullName: String!\n  ): En'
    out += 'try\n\n  """\n  Vote on a repository submission, returns '
    out += 'the submission that was voted on\n  """\n  vote(\n    "'
    out += '""\n    The full repository name from GitHub, e.g. "apoll'
    out += 'ostack/GitHunt-API"\n    """\n    repoFullName: String!'
    out += '\n\n    """The type of vote - UP, DOWN, or CANCEL"""\n'
    out += '    type: VoteType!\n  ): Entry\n}\n\ntype Query {\n  """'
    out += "Return the currently logged in user, or null if nobody is lo"
    out += 'gged in"""\n  currentUser: User\n\n  """A single entry'
    out += '"""\n  entry(\n    """\n    The full repository name f'
    out += 'rom GitHub, e.g. "apollostack/GitHunt-API"\n    """\n  '
    out += '  repoFullName: String!\n  ): Entry\n\n  """A feed of rep'
    out += 'ository submissions"""\n  feed(\n    """The sort order'
    out += ' for the feed"""\n    type: FeedType!\n\n    """The nu'
    out += 'mber of items to skip, for pagination"""\n    offset: Int'
    out += '\n\n    """The number of items to fetch starting from the'
    out += ' offset, for pagination"""\n    limit: Int\n  ): [Entry]'
    out += '\n}\n\n"""\nA repository object from the GitHub API. This'
    out += " uses the exact field names returned by the\nGitHub API for "
    out += "simplicity, even though the convention for GraphQL is usuall"
    out += 'y to camel case.\n"""\ntype Repository {\n  """The des'
    out += 'cription of the repository"""\n  description: String\n\n '
    out += ' """\n  The full name of the repository with the username'
    out += ', e.g. apollostack/GitHunt-API\n  """\n  full_name: Strin'
    out += 'g!\n\n  """The link to the repository on GitHub"""\n  '
    out += 'html_url: String!\n\n  """Just the name of the repository'
    out += ', e.g. GitHunt-API"""\n  name: String!\n\n  """The num'
    out += 'ber of open issues on this repository on GitHub"""\n  ope'
    out += 'n_issues_count: Int\n\n  """The owner of this repository '
    out += 'on GitHub, e.g. apollostack"""\n  owner: User\n\n  """'
    out += "The number of people who have starred this repository on Git"
    out += 'Hub"""\n  stargazers_count: Int!\n}\n\ntype Subscription '
    out += '{\n  """Subscription fires on every comment added"""\n'
    out += '  commentAdded(repoFullName: String!): Comment\n}\n\n"""'
    out += "\nA user object from the GitHub API. This uses the exact fie"
    out += 'ld names returned from the GitHub API.\n"""\ntype User {'
    out += '\n  """The URL to a directly embeddable image for this us'
    out += 'er\'s avatar"""\n  avatar_url: String!\n\n  """The URL '
    out += 'of this user\'s GitHub page"""\n  html_url: String!\n\n  '
    out += '"""The name of the user, e.g. apollostack"""\n  login:'
    out += ' String!\n}\n\n"""XXX to be removed"""\ntype Vote {\n '
    out += ' vote_value: Int!\n}\n\n"""The type of vote to record, wh'
    out += 'en submitting a vote"""\nenum VoteType {\n  UP\n  DOWN\n '
    out += " CANCEL\n}\n"
    return out^


def _path_205() -> String:
    var out = String()
    out += "subscriptions/used-coordinates.json.expected"
    return out^


def _file_205() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Comment": '
    out += '{},\n        "Subscription": {\n            "commentAdded'
    out += '": [\n                "repoFullName"\n            ]\n    '
    out += '    },\n        "Int": {},\n        "String": {}\n    }'
    out += "\n}"
    return out^


def _path_206() -> String:
    var out = String()
    out += "test_inline/TestOperation.graphql"
    return out^


def _file_206() -> String:
    var out = String()
    out += "query GetPage {\n  collection {\n    items {\n      title\n "
    out += "   }\n    ... on ParticularCollection {\n      items {\n    "
    out += "    ... on ParticularItem {\n          image\n        }\n   "
    out += "   }\n    }\n  }\n}\n\n"
    return out^


def _path_207() -> String:
    var out = String()
    out += "test_inline/schema.graphqls"
    return out^


def _file_207() -> String:
    var out = String()
    out += "type Query {\n  collection: Collection!\n}\n\ninterface Coll"
    out += "ection {\n  items: [Item!]!\n}\n\ntype ParticularCollection "
    out += "implements Collection {\n  items: [Item!]!\n}\n\ninterface I"
    out += "tem {\n  title: String!\n  description: String!\n}\n\ntype P"
    out += "articularItem implements Item {\n  title: String!\n  image: "
    out += "String!\n}\n\ntype GenericItem implements Item {\n  title: S"
    out += "tring!\n  genericField: String!\n}\n"
    return out^


def _path_208() -> String:
    var out = String()
    out += "test_inline/used-coordinates.json.expected"
    return out^


def _file_208() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Collection'
    out += '": {},\n        "Item": {},\n        "String": {},\n   '
    out += '     "Query": {}\n    }\n}'
    return out^


def _path_209() -> String:
    var out = String()
    out += "two_heroes_unique/TestOperation.graphql"
    return out^


def _file_209() -> String:
    var out = String()
    out += "query TestQuery {\n  r2: hero {\n    name\n  }\n  luke: hero"
    out += "(episode: EMPIRE) {\n    id\n    name\n  }\n}\n"
    return out^


def _path_210() -> String:
    var out = String()
    out += "two_heroes_unique/used-coordinates.json.expected"
    return out^


def _file_210() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'String": {},\n        "ID": {}\n    }\n}'
    return out^


def _path_211() -> String:
    var out = String()
    out += "two_heroes_with_friends/TestOperation.graphql"
    return out^


def _file_211() -> String:
    var out = String()
    out += "query TestQuery {\n  r2: hero {\n    name\n    friendsConnec"
    out += "tion {\n      totalCount\n      edges {\n        node {\n   "
    out += "       name\n        }\n      }\n    }\n  }\n  luke: hero(ep"
    out += "isode: EMPIRE) {\n    id\n    name\n    friendsConnection {"
    out += "\n      totalCount\n      edges {\n        node {\n         "
    out += " name\n        }\n      }\n    }\n  }\n}\n"
    return out^


def _path_212() -> String:
    var out = String()
    out += "two_heroes_with_friends/used-coordinates.json.expected"
    return out^


def _file_212() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'String": {},\n        "FriendsConnection": {},\n        '
    out += '"Int": {},\n        "FriendsEdge": {},\n        "ID": '
    out += "{}\n    }\n}"
    return out^


def _path_213() -> String:
    var out = String()
    out += "typename_always_first/TestOperation.graphql"
    return out^


def _file_213() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ... on Human {\n      heigh"
    out += "t\n      __typename\n    }\n    ... on Droid {\n      name\n"
    out += "      __typename\n      primaryFunction\n    }\n    __typena"
    out += "me\n  }\n  __typename\n}\n"
    return out^


def _path_214() -> String:
    var out = String()
    out += "typename_always_first/used-coordinates.json.expected"
    return out^


def _file_214() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "String": {},\n        "Float": {},\n    '
    out += '    "Query": {}\n    }\n}'
    return out^


def _path_215() -> String:
    var out = String()
    out += "union_fragment/TestOperation.graphql"
    return out^


def _file_215() -> String:
    var out = String()
    out += 'query TestQuery {\n  search(text: "test") {\n    ... on St'
    out += "arship {\n      id\n    }\n    ...Starship\n  }\n}\n\nfragme"
    out += "nt Starship on Starship {\n  name\n}\n"
    return out^


def _path_216() -> String:
    var out = String()
    out += "union_fragment/used-coordinates.json.expected"
    return out^


def _file_216() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "SearchResul'
    out += 't": {},\n        "Query": {\n            "search": [\n '
    out += '               "text"\n            ]\n        },\n        '
    out += '"ID": {},\n        "String": {},\n        "Starship": '
    out += '{},\n        "Human": {},\n        "Droid": {},\n       '
    out += ' "Character": {}\n    }\n}'
    return out^


def _path_217() -> String:
    var out = String()
    out += "union_inline_fragments/TestOperation.graphql"
    return out^


def _file_217() -> String:
    var out = String()
    out += 'query TestQuery {\n  search(text: "test") {\n    ... on Ch'
    out += "aracter {\n      id\n      name\n      friends {\n        .."
    out += ". on Character {\n          name\n        }\n        ... on "
    out += "Human {\n          homePlanet\n          friends {\n        "
    out += "    ... on Character {\n              firstAppearsIn\n      "
    out += "      }\n          }\n        }\n        ... on Droid {\n   "
    out += "       primaryFunction\n          friends {\n            id"
    out += "\n          }\n        }\n      }\n    }\n    ... on Starshi"
    out += "p {\n      name\n    }\n  }\n}\n"
    return out^


def _path_218() -> String:
    var out = String()
    out += "union_inline_fragments/used-coordinates.json.expected"
    return out^


def _file_218() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "SearchResul'
    out += 't": {},\n        "Query": {\n            "search": [\n '
    out += '               "text"\n            ]\n        },\n        '
    out += '"ID": {},\n        "String": {},\n        "Character":'
    out += ' {},\n        "Episode": {},\n        "Human": {},\n    '
    out += '    "Droid": {},\n        "Starship": {}\n    }\n}'
    return out^


def _path_219() -> String:
    var out = String()
    out += "unique_type_name/TestOperation.graphql"
    return out^


def _file_219() -> String:
    var out = String()
    out += "query HeroDetailQuery {\n  heroDetailQuery {\n    name\n    "
    out += "friends {\n      name\n    }\n    ... on Human {\n      heig"
    out += "ht\n      friends {\n        appearsIn\n        friends {\n "
    out += "         ...HeroDetails\n        }\n      }\n    }\n  }\n}\n"
    out += "\nfragment HeroDetails on Character {\n  name\n  friendsConn"
    out += "ection {\n    totalCount\n    edges {\n      node {\n       "
    out += " name\n      }\n    }\n  }\n}"
    return out^


def _path_220() -> String:
    var out = String()
    out += "unique_type_name/used-coordinates.json.expected"
    return out^


def _file_220() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Float": {},\n        "Episode": {},\n   '
    out += '     "String": {},\n        "Query": {},\n        "Frie'
    out += 'ndsConnection": {},\n        "Int": {},\n        "Friend'
    out += 'sEdge": {}\n    }\n}'
    return out^


def _path_221() -> String:
    var out = String()
    out += "used_arguments/TestOperation.graphql"
    return out^


def _file_221() -> String:
    var out = String()
    out += "fragment ADetails on A {\n  field(arg: 42)\n}\n\nquery GetA "
    out += "{\n  a {\n    ... on B {\n      field(arg: 42)\n    }\n    ."
    out += ".. on C {\n      field(arg: 42)\n    }\n  }\n}"
    return out^


def _path_222() -> String:
    var out = String()
    out += "used_arguments/schema.graphqls"
    return out^


def _file_222() -> String:
    var out = String()
    out += "interface A {\n  field(arg: Int!): Int\n}\n\ntype B implemen"
    out += "ts A {\n  field(arg: Int!): Int\n}\n\ntype C implements A {"
    out += "\n  field(arg: Int!): Int\n}\n\ntype Query {\n  a: A\n}"
    return out^


def _path_223() -> String:
    var out = String()
    out += "used_arguments/used-coordinates.json.expected"
    return out^


def _file_223() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "A": {\n   '
    out += '         "field": [\n                "arg"\n            '
    out += ']\n        },\n        "Int": {},\n        "B": {\n     '
    out += '       "field": [\n                "arg"\n            ]'
    out += '\n        },\n        "C": {\n            "field": [\n  '
    out += '              "arg"\n            ]\n        },\n        "'
    out += 'String": {},\n        "Query": {}\n    }\n}'
    return out^


def _path_224() -> String:
    var out = String()
    out += "validation/ArgumentNonOptional.expected"
    return out^


def _file_224() -> String:
    var out = String()
    out += "OtherValidationIssue (2:24)\nValue `null` cannot be used in "
    out += "position expecting `ReviewInput!`"
    return out^


def _path_225() -> String:
    var out = String()
    out += "validation/ArgumentNonOptional.graphql"
    return out^


def _file_225() -> String:
    var out = String()
    out += "mutation TestQuery {\n  createReview(review: null) {\n    co"
    out += "mmentary\n  }\n}\n"
    return out^


def _path_226() -> String:
    var out = String()
    out += "validation/BadDirectiveArgument.expected"
    return out^


def _file_226() -> String:
    var out = String()
    out += 'OtherValidationIssue (3:23)\nValue `"badarg"` cannot be us'
    out += "ed in position expecting `Boolean`"
    return out^


def _path_227() -> String:
    var out = String()
    out += "validation/BadDirectiveArgument.graphql"
    return out^


def _file_227() -> String:
    var out = String()
    out += 'query HeroName {\n  hero {\n    name @include(if: "badarg"'
    out += ")\n  }\n}"
    return out^


def _path_228() -> String:
    var out = String()
    out += "validation/CircularFragmentReference.expected"
    return out^


def _file_228() -> String:
    var out = String()
    out += "FragmentCycle (14:3)\nFragment 'characterFragment' spreads i"
    out += "tself, creating a cycle at '__characterFragment.friend.__fri"
    out += "endFragment.__characterFragment'"
    return out^


def _path_229() -> String:
    var out = String()
    out += "validation/CircularFragmentReference.graphql"
    return out^


def _file_229() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ...characterFragment\n  }\n"
    out += "}\n\nfragment characterFragment on Character {\n  friend {\n"
    out += "    ...friendFragment\n  }\n}\n\nfragment friendFragment on "
    out += "Character {\n  ...characterFragment\n}"
    return out^


def _path_230() -> String:
    var out = String()
    out += "validation/DuplicateOperation.expected"
    return out^


def _file_230() -> String:
    var out = String()
    out += "OtherValidationIssue (7:1)\nOperation TestQuery is already d"
    out += "efined"
    return out^


def _path_231() -> String:
    var out = String()
    out += "validation/DuplicateOperation.graphql"
    return out^


def _file_231() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n  }\n}\n\nquery TestQ"
    out += "uery {\n  hero {\n    name\n  }\n}\n"
    return out^


def _path_232() -> String:
    var out = String()
    out += "validation/FragmentDuplication.expected"
    return out^


def _file_232() -> String:
    var out = String()
    out += "OtherValidationIssue (11:1)\nFragment HeroFragment is alread"
    out += "y defined\n------------\nUnusedFragment (11:1)\nFragment 'He"
    out += "roFragment' is not used"
    return out^


def _path_233() -> String:
    var out = String()
    out += "validation/FragmentDuplication.graphql"
    return out^


def _file_233() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n  }\n}\n\nfragment He"
    out += "roFragment on Character {\n  name\n}\n\nfragment HeroFragmen"
    out += "t on Character {\n  name\n}\n"
    return out^


def _path_234() -> String:
    var out = String()
    out += "validation/FragmentUnknownType.expected"
    return out^


def _file_234() -> String:
    var out = String()
    out += "OtherValidationIssue (7:26)\nCannot find type `Banana` for f"
    out += "ragment `HeroFragment`\n------------\nUnusedFragment (7:1)\n"
    out += "Fragment 'HeroFragment' is not used"
    return out^


def _path_235() -> String:
    var out = String()
    out += "validation/FragmentUnknownType.graphql"
    return out^


def _file_235() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n  }\n}\n\nfragment He"
    out += "roFragment on Banana {\n  name\n}\n"
    return out^


def _path_236() -> String:
    var out = String()
    out += "validation/InlineFragmentCanNotBeSpread.expected"
    return out^


def _file_236() -> String:
    var out = String()
    out += "OtherValidationIssue (3:12)\nInline fragment cannot be sprea"
    out += "d here as result can never be of type `Review`"
    return out^


def _path_237() -> String:
    var out = String()
    out += "validation/InlineFragmentCanNotBeSpread.graphql"
    return out^


def _file_237() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ... on Review {\n      star"
    out += "s\n    }\n  }\n}\n"
    return out^


def _path_238() -> String:
    var out = String()
    out += "validation/InlineFragmentUnknonwType.expected"
    return out^


def _file_238() -> String:
    var out = String()
    out += "OtherValidationIssue (3:12)\nCannot find type `Banana` for i"
    out += "nline fragment"
    return out^


def _path_239() -> String:
    var out = String()
    out += "validation/InlineFragmentUnknonwType.graphql"
    return out^


def _file_239() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    ... on Banana {\n      choc"
    out += "olate\n    }\n  }\n}\n"
    return out^


def _path_240() -> String:
    var out = String()
    out += "validation/InputObjectFieldNonOptional.expected"
    return out^


def _file_240() -> String:
    var out = String()
    out += "OtherValidationIssue (2:24)\nNo value passed for required in"
    out += "putField `favoriteColor`\n------------\nOtherValidationIssue"
    out += " (2:24)\nNo value passed for required inputField `listOfStri"
    out += "ngNonOptional`\n------------\nOtherValidationIssue (3:12)\nV"
    out += "ariable `stars` of type `Int` used in position expecting typ"
    out += "e `Int!`"
    return out^


def _path_241() -> String:
    var out = String()
    out += "validation/InputObjectFieldNonOptional.graphql"
    return out^


def _file_241() -> String:
    var out = String()
    out += "mutation TestQuery($stars: Int) {\n  createReview(review: {"
    out += "\n    stars: $stars\n  }) {\n    commentary\n  }\n}\n\n"
    return out^


def _path_242() -> String:
    var out = String()
    out += "validation/InputObjectFieldTypeMismatch.expected"
    return out^


def _file_242() -> String:
    var out = String()
    out += "OtherValidationIssue (2:24)\nNo value passed for required in"
    out += "putField `stars`\n------------\nOtherValidationIssue (2:24)"
    out += "\nNo value passed for required inputField `listOfStringNonOp"
    out += "tional`\n------------\nOtherValidationIssue (4:12)\nVariable"
    out += " `red` of type `String!` used in position expecting type `In"
    out += "t!`"
    return out^


def _path_243() -> String:
    var out = String()
    out += "validation/InputObjectFieldTypeMismatch.graphql"
    return out^


def _file_243() -> String:
    var out = String()
    out += "mutation TestQuery($red: String!) {\n  createReview(review: "
    out += "{\n    favoriteColor: {\n      red: $red\n    }\n  }) {\n   "
    out += " commentary\n  }\n}\n"
    return out^


def _path_244() -> String:
    var out = String()
    out += "validation/InputObjectListFieldTypeMismatch.expected"
    return out^


def _file_244() -> String:
    var out = String()
    out += "OtherValidationIssue (2:24)\nNo value passed for required in"
    out += "putField `stars`\n------------\nOtherValidationIssue (2:24)"
    out += "\nNo value passed for required inputField `favoriteColor`\n-"
    out += "-----------\nOtherValidationIssue (3:31)\nVariable `item` of"
    out += " type `Int` used in position expecting type `String`"
    return out^


def _path_245() -> String:
    var out = String()
    out += "validation/InputObjectListFieldTypeMismatch.graphql"
    return out^


def _file_245() -> String:
    var out = String()
    out += "mutation TestQuery($item: Int) {\n  createReview(review: {\n"
    out += "    listOfStringNonOptional: [$item]\n  }) {\n    commentary"
    out += "\n  }\n}\n\n"
    return out^


def _path_246() -> String:
    var out = String()
    out += "validation/MissingDirective.expected"
    return out^


def _file_246() -> String:
    var out = String()
    out += "UnknownDirective (4:10)\nUnknown directive '@required'"
    return out^


def _path_247() -> String:
    var out = String()
    out += "validation/MissingDirective.graphql"
    return out^


def _file_247() -> String:
    var out = String()
    out += "query HeroName {\n  hero {\n    # ERROR: Unknown directive '"
    out += "@required'\n    name @required\n  }\n}"
    return out^


def _path_248() -> String:
    var out = String()
    out += "validation/MissingDirectiveArgument.expected"
    return out^


def _file_248() -> String:
    var out = String()
    out += "OtherValidationIssue (3:23)\nVariable `condition` is not def"
    out += "ined by operation `HeroName`"
    return out^


def _path_249() -> String:
    var out = String()
    out += "validation/MissingDirectiveArgument.graphql"
    return out^


def _file_249() -> String:
    var out = String()
    out += "query HeroName {\n  hero {\n    name @include(if: $condition"
    out += ")\n  }\n}"
    return out^


def _path_250() -> String:
    var out = String()
    out += "validation/MissingSelectionSet.expected"
    return out^


def _file_250() -> String:
    var out = String()
    out += "OtherValidationIssue (2:3)\nField `hero` of type `Character`"
    out += " must have a selection of sub-fields"
    return out^


def _path_251() -> String:
    var out = String()
    out += "validation/MissingSelectionSet.graphql"
    return out^


def _file_251() -> String:
    var out = String()
    out += "query TestQuery {\n  hero\n}\n"
    return out^


def _path_252() -> String:
    var out = String()
    out += "validation/QueryUnknowField.expected"
    return out^


def _file_252() -> String:
    var out = String()
    out += "OtherValidationIssue (2:3)\nCan't query `hero12` on type `Qu"
    out += "ery`"
    return out^


def _path_253() -> String:
    var out = String()
    out += "validation/QueryUnknowField.graphql"
    return out^


def _file_253() -> String:
    var out = String()
    out += "query TestQuery {\n  hero12 {\n    name\n  }\n}\n"
    return out^


def _path_254() -> String:
    var out = String()
    out += "validation/SyntaxError.expected"
    return out^


def _file_254() -> String:
    var out = String()
    out += "ParsingError (2:24)\nUnexpected token: '{'"
    return out^


def _path_255() -> String:
    var out = String()
    out += "validation/SyntaxError.graphql"
    return out^


def _file_255() -> String:
    var out = String()
    out += "# Invalid fragment (does not specify its type condition)\nfr"
    out += "agment HumanFragment {\n  name\n}"
    return out^


def _path_256() -> String:
    var out = String()
    out += "validation/TypeSystemDefinition.expected"
    return out^


def _file_256() -> String:
    var out = String()
    out += "OtherValidationIssue (7:1)\nFound an non-executable definiti"
    out += "on."
    return out^


def _path_257() -> String:
    var out = String()
    out += "validation/TypeSystemDefinition.graphql"
    return out^


def _file_257() -> String:
    var out = String()
    out += "query TestQuery {\n  hero {\n    name\n  }\n}\n\ntype LightS"
    out += "aber {\n  color: Int\n}"
    return out^


def _path_258() -> String:
    var out = String()
    out += "validation/UnusedVariable.expected"
    return out^


def _file_258() -> String:
    var out = String()
    out += "UnusedVariable (2:16)\nVariable `condition` is unused in ope"
    out += "ration `HeroName`"
    return out^


def _path_259() -> String:
    var out = String()
    out += "validation/UnusedVariable.graphql"
    return out^


def _file_259() -> String:
    var out = String()
    out += "# condition is unused here and should trigger a warning\nque"
    out += "ry HeroName($condition: Boolean!) {\n  hero {\n    name\n  }"
    out += "\n}"
    return out^


def _path_260() -> String:
    var out = String()
    out += "validation/VariableMissing.expected"
    return out^


def _file_260() -> String:
    var out = String()
    out += "OtherValidationIssue (2:17)\nVariable `episode` is not defin"
    out += "ed by operation `TestQuery`"
    return out^


def _path_261() -> String:
    var out = String()
    out += "validation/VariableMissing.graphql"
    return out^


def _file_261() -> String:
    var out = String()
    out += "query TestQuery {\n  hero(episode: $episode) {\n    name\n  "
    out += "}\n}\n"
    return out^


def _path_262() -> String:
    var out = String()
    out += "validation/VariableTypeMismatch.expected"
    return out^


def _file_262() -> String:
    var out = String()
    out += "OtherValidationIssue (2:17)\nVariable `episode` of type `Int"
    out += "` used in position expecting type `Episode!`"
    return out^


def _path_263() -> String:
    var out = String()
    out += "validation/VariableTypeMismatch.graphql"
    return out^


def _file_263() -> String:
    var out = String()
    out += "query TestQuery($episode: Int) {\n  hero(episode: $episode) "
    out += "{\n    name\n  }\n}\n"
    return out^


def _path_264() -> String:
    var out = String()
    out += "validation/schema.graphqls"
    return out^


def _file_264() -> String:
    var out = String()
    out += '"""\nThe query type, represents all of the entry points i'
    out += 'nto our object graph\n"""\ntype Query {\n  hero("" epis'
    out += 'ode: Episode! = NEWHOPE, "for test purpose only" listOfLis'
    out += 'tOfStringArgs: [[String]]): Character\n}\n\n"""\nThe epis'
    out += 'odes in the Star Wars trilogy\n"""\nenum Episode {\n  "'
    out += '""\n  Star Wars Episode IV: A New Hope, released in 1977.'
    out += '\n  """\n  NEWHOPE\n\n  """\n  Star Wars Episode V: Th'
    out += 'e Empire Strikes Back, released in 1980.\n  """\n  EMPIRE'
    out += '\n\n  """\n  Star Wars Episode VI: Return of the Jedi, re'
    out += 'leased in 1983.\n  """\n  JEDI\n\n  """\n  Test deprec'
    out += 'ated enum value\n  """\n  DEPRECATED @deprecated(reason: '
    out += '"For test purpose only")\n\n  """\n  Test java reserved'
    out += ' word\n  """\n  new @deprecated(reason: "For test purpos'
    out += 'e only")\n}\n\n"""\nA character from the Star Wars unive'
    out += 'rse\n"""\ninterface Character {\n  """\n  The ID of th'
    out += 'e character\n  """\n  id: ID!\n\n  """\n  The name of '
    out += 'the character\n  """\n  name: String!\n\n  friend: Charac'
    out += 'ter\n}\n\n"""\nThe `Date` scalar type represents date for'
    out += 'mat.\n"""\nscalar Date\n\n"""\nA humanoid creature fro'
    out += 'm the Star Wars universe\n"""\ntype Human implements Char'
    out += 'acter {\n  """\n  The ID of the human\n  """\n  id: ID'
    out += '!\n\n  """\n  What this human calls themselves\n  """'
    out += '\n  name: String!\n\n  """\n  Height in the preferred uni'
    out += 't, default is meters\n  """\n  height("" unit: LengthUn'
    out += 'it = METER): Float\n\n  """\n  The date character was bor'
    out += 'n.\n  """\n  birthDate: Date!\n}\n\n"""\nUnits of heig'
    out += 'ht\n"""\nenum LengthUnit {\n  """\n  The standard unit'
    out += ' around the world\n  """\n  METER\n\n  """\n  Primaril'
    out += 'y used in the United States\n  """\n  FOOT\n}\n\n"""\n'
    out += "An autonomous mechanical character in the Star Wars universe"
    out += '\n"""\ntype Droid implements Character {\n  """\n  The'
    out += ' ID of the droid\n  """\n  id: ID!\n\n  """\n  What ot'
    out += 'hers call this droid\n  """\n  name: String!\n\n  """'
    out += '\n  This droid\'s primary function\n  """\n  primaryFuncti'
    out += 'on: String\n}\n\n"""\nThe mutation type, represents all u'
    out += 'pdates we can make to our data\n"""\ntype Mutation {\n  c'
    out += 'reateReview("" episode: Episode, "" review: ReviewInput!'
    out += '): Review\n}\n\n"""\nThe input object sent when someone i'
    out += 's creating a new review\n"""\ninput ReviewInput {\n  ""'
    out += '"\n  0-5 stars\n  """\n  stars: Int!\n\n  """\n  Comm'
    out += 'ent about the movie, optional\n  """\n  commentary: Strin'
    out += 'g\n\n  """\n  Favorite color, optional\n  """\n  favor'
    out += 'iteColor: colorInput!\n\n  """\n  for test purpose only\n'
    out += '  """\n  listOfStringNonOptional: [String]!\n}\n\n"""'
    out += '\nThe input object sent when passing in a color\n"""\ninp'
    out += 'ut colorInput {\n  """\n  Red color\n  """\n  red: Int'
    out += '! = 1\n\n  """\n  Green color\n  """\n  green: Float ='
    out += ' 0.0\n\n  """\n  Blue color\n  """\n  blue: Float! = 1'
    out += '.5\n\n  """\n  for test purpose only\n  """\n  enumWit'
    out += 'hDefaultValue: Episode = new\n\n  """\n  Circle ref to re'
    out += 'view input\n  """\n  reviewRefInput: ReviewRefInput\n}\n'
    out += '\n"""\nCircle ref to review input\n"""\ninput ReviewRe'
    out += 'fInput {\n  reviewInput: ReviewInput\n}\n\n"""\nRepresent'
    out += 's a review for a movie\n"""\ntype Review {\n  """\n  T'
    out += 'he number of stars this review gave, 1-5\n  """\n  stars:'
    out += ' Int!\n\n  """\n  Comment about the movie\n  """\n  co'
    out += "mmentary: String\n}\n\nschema {\n  query: Query\n  mutation:"
    out += " Mutation\n}\n"
    return out^


def _path_265() -> String:
    var out = String()
    out += "variable_default_value/TestOperation.graphql"
    return out^


def _file_265() -> String:
    var out = String()
    out += "query TestQuery($episode: Episode! = JEDI) {\n  hero(episode"
    out += ": $episode) {\n    name\n  }\n}\n\n"
    return out^


def _path_266() -> String:
    var out = String()
    out += "variable_default_value/used-coordinates.json.expected"
    return out^


def _file_266() -> String:
    var out = String()
    out += '{\n    "typeToFieldsToArguments": {\n        "Character"'
    out += ': {},\n        "Query": {\n            "hero": [\n      '
    out += '          "episode"\n            ]\n        },\n        "'
    out += 'String": {},\n        "Episode": {}\n    }\n}'
    return out^


def fixture_paths() -> List[String]:
    """Return the path of each file, from `fixtures/`."""
    var out = List[String]()
    out.append(_path_0())
    out.append(_path_1())
    out.append(_path_2())
    out.append(_path_3())
    out.append(_path_4())
    out.append(_path_5())
    out.append(_path_6())
    out.append(_path_7())
    out.append(_path_8())
    out.append(_path_9())
    out.append(_path_10())
    out.append(_path_11())
    out.append(_path_12())
    out.append(_path_13())
    out.append(_path_14())
    out.append(_path_15())
    out.append(_path_16())
    out.append(_path_17())
    out.append(_path_18())
    out.append(_path_19())
    out.append(_path_20())
    out.append(_path_21())
    out.append(_path_22())
    out.append(_path_23())
    out.append(_path_24())
    out.append(_path_25())
    out.append(_path_26())
    out.append(_path_27())
    out.append(_path_28())
    out.append(_path_29())
    out.append(_path_30())
    out.append(_path_31())
    out.append(_path_32())
    out.append(_path_33())
    out.append(_path_34())
    out.append(_path_35())
    out.append(_path_36())
    out.append(_path_37())
    out.append(_path_38())
    out.append(_path_39())
    out.append(_path_40())
    out.append(_path_41())
    out.append(_path_42())
    out.append(_path_43())
    out.append(_path_44())
    out.append(_path_45())
    out.append(_path_46())
    out.append(_path_47())
    out.append(_path_48())
    out.append(_path_49())
    out.append(_path_50())
    out.append(_path_51())
    out.append(_path_52())
    out.append(_path_53())
    out.append(_path_54())
    out.append(_path_55())
    out.append(_path_56())
    out.append(_path_57())
    out.append(_path_58())
    out.append(_path_59())
    out.append(_path_60())
    out.append(_path_61())
    out.append(_path_62())
    out.append(_path_63())
    out.append(_path_64())
    out.append(_path_65())
    out.append(_path_66())
    out.append(_path_67())
    out.append(_path_68())
    out.append(_path_69())
    out.append(_path_70())
    out.append(_path_71())
    out.append(_path_72())
    out.append(_path_73())
    out.append(_path_74())
    out.append(_path_75())
    out.append(_path_76())
    out.append(_path_77())
    out.append(_path_78())
    out.append(_path_79())
    out.append(_path_80())
    out.append(_path_81())
    out.append(_path_82())
    out.append(_path_83())
    out.append(_path_84())
    out.append(_path_85())
    out.append(_path_86())
    out.append(_path_87())
    out.append(_path_88())
    out.append(_path_89())
    out.append(_path_90())
    out.append(_path_91())
    out.append(_path_92())
    out.append(_path_93())
    out.append(_path_94())
    out.append(_path_95())
    out.append(_path_96())
    out.append(_path_97())
    out.append(_path_98())
    out.append(_path_99())
    out.append(_path_100())
    out.append(_path_101())
    out.append(_path_102())
    out.append(_path_103())
    out.append(_path_104())
    out.append(_path_105())
    out.append(_path_106())
    out.append(_path_107())
    out.append(_path_108())
    out.append(_path_109())
    out.append(_path_110())
    out.append(_path_111())
    out.append(_path_112())
    out.append(_path_113())
    out.append(_path_114())
    out.append(_path_115())
    out.append(_path_116())
    out.append(_path_117())
    out.append(_path_118())
    out.append(_path_119())
    out.append(_path_120())
    out.append(_path_121())
    out.append(_path_122())
    out.append(_path_123())
    out.append(_path_124())
    out.append(_path_125())
    out.append(_path_126())
    out.append(_path_127())
    out.append(_path_128())
    out.append(_path_129())
    out.append(_path_130())
    out.append(_path_131())
    out.append(_path_132())
    out.append(_path_133())
    out.append(_path_134())
    out.append(_path_135())
    out.append(_path_136())
    out.append(_path_137())
    out.append(_path_138())
    out.append(_path_139())
    out.append(_path_140())
    out.append(_path_141())
    out.append(_path_142())
    out.append(_path_143())
    out.append(_path_144())
    out.append(_path_145())
    out.append(_path_146())
    out.append(_path_147())
    out.append(_path_148())
    out.append(_path_149())
    out.append(_path_150())
    out.append(_path_151())
    out.append(_path_152())
    out.append(_path_153())
    out.append(_path_154())
    out.append(_path_155())
    out.append(_path_156())
    out.append(_path_157())
    out.append(_path_158())
    out.append(_path_159())
    out.append(_path_160())
    out.append(_path_161())
    out.append(_path_162())
    out.append(_path_163())
    out.append(_path_164())
    out.append(_path_165())
    out.append(_path_166())
    out.append(_path_167())
    out.append(_path_168())
    out.append(_path_169())
    out.append(_path_170())
    out.append(_path_171())
    out.append(_path_172())
    out.append(_path_173())
    out.append(_path_174())
    out.append(_path_175())
    out.append(_path_176())
    out.append(_path_177())
    out.append(_path_178())
    out.append(_path_179())
    out.append(_path_180())
    out.append(_path_181())
    out.append(_path_182())
    out.append(_path_183())
    out.append(_path_184())
    out.append(_path_185())
    out.append(_path_186())
    out.append(_path_187())
    out.append(_path_188())
    out.append(_path_189())
    out.append(_path_190())
    out.append(_path_191())
    out.append(_path_192())
    out.append(_path_193())
    out.append(_path_194())
    out.append(_path_195())
    out.append(_path_196())
    out.append(_path_197())
    out.append(_path_198())
    out.append(_path_199())
    out.append(_path_200())
    out.append(_path_201())
    out.append(_path_202())
    out.append(_path_203())
    out.append(_path_204())
    out.append(_path_205())
    out.append(_path_206())
    out.append(_path_207())
    out.append(_path_208())
    out.append(_path_209())
    out.append(_path_210())
    out.append(_path_211())
    out.append(_path_212())
    out.append(_path_213())
    out.append(_path_214())
    out.append(_path_215())
    out.append(_path_216())
    out.append(_path_217())
    out.append(_path_218())
    out.append(_path_219())
    out.append(_path_220())
    out.append(_path_221())
    out.append(_path_222())
    out.append(_path_223())
    out.append(_path_224())
    out.append(_path_225())
    out.append(_path_226())
    out.append(_path_227())
    out.append(_path_228())
    out.append(_path_229())
    out.append(_path_230())
    out.append(_path_231())
    out.append(_path_232())
    out.append(_path_233())
    out.append(_path_234())
    out.append(_path_235())
    out.append(_path_236())
    out.append(_path_237())
    out.append(_path_238())
    out.append(_path_239())
    out.append(_path_240())
    out.append(_path_241())
    out.append(_path_242())
    out.append(_path_243())
    out.append(_path_244())
    out.append(_path_245())
    out.append(_path_246())
    out.append(_path_247())
    out.append(_path_248())
    out.append(_path_249())
    out.append(_path_250())
    out.append(_path_251())
    out.append(_path_252())
    out.append(_path_253())
    out.append(_path_254())
    out.append(_path_255())
    out.append(_path_256())
    out.append(_path_257())
    out.append(_path_258())
    out.append(_path_259())
    out.append(_path_260())
    out.append(_path_261())
    out.append(_path_262())
    out.append(_path_263())
    out.append(_path_264())
    out.append(_path_265())
    out.append(_path_266())
    return out^


def fixture_text(path: StringSlice) raises -> String:
    """Return the text of a file of `fixtures/`."""
    if path == _path_0():
        return _file_0()
    if path == _path_1():
        return _file_1()
    if path == _path_2():
        return _file_2()
    if path == _path_3():
        return _file_3()
    if path == _path_4():
        return _file_4()
    if path == _path_5():
        return _file_5()
    if path == _path_6():
        return _file_6()
    if path == _path_7():
        return _file_7()
    if path == _path_8():
        return _file_8()
    if path == _path_9():
        return _file_9()
    if path == _path_10():
        return _file_10()
    if path == _path_11():
        return _file_11()
    if path == _path_12():
        return _file_12()
    if path == _path_13():
        return _file_13()
    if path == _path_14():
        return _file_14()
    if path == _path_15():
        return _file_15()
    if path == _path_16():
        return _file_16()
    if path == _path_17():
        return _file_17()
    if path == _path_18():
        return _file_18()
    if path == _path_19():
        return _file_19()
    if path == _path_20():
        return _file_20()
    if path == _path_21():
        return _file_21()
    if path == _path_22():
        return _file_22()
    if path == _path_23():
        return _file_23()
    if path == _path_24():
        return _file_24()
    if path == _path_25():
        return _file_25()
    if path == _path_26():
        return _file_26()
    if path == _path_27():
        return _file_27()
    if path == _path_28():
        return _file_28()
    if path == _path_29():
        return _file_29()
    if path == _path_30():
        return _file_30()
    if path == _path_31():
        return _file_31()
    if path == _path_32():
        return _file_32()
    if path == _path_33():
        return _file_33()
    if path == _path_34():
        return _file_34()
    if path == _path_35():
        return _file_35()
    if path == _path_36():
        return _file_36()
    if path == _path_37():
        return _file_37()
    if path == _path_38():
        return _file_38()
    if path == _path_39():
        return _file_39()
    if path == _path_40():
        return _file_40()
    if path == _path_41():
        return _file_41()
    if path == _path_42():
        return _file_42()
    if path == _path_43():
        return _file_43()
    if path == _path_44():
        return _file_44()
    if path == _path_45():
        return _file_45()
    if path == _path_46():
        return _file_46()
    if path == _path_47():
        return _file_47()
    if path == _path_48():
        return _file_48()
    if path == _path_49():
        return _file_49()
    if path == _path_50():
        return _file_50()
    if path == _path_51():
        return _file_51()
    if path == _path_52():
        return _file_52()
    if path == _path_53():
        return _file_53()
    if path == _path_54():
        return _file_54()
    if path == _path_55():
        return _file_55()
    if path == _path_56():
        return _file_56()
    if path == _path_57():
        return _file_57()
    if path == _path_58():
        return _file_58()
    if path == _path_59():
        return _file_59()
    if path == _path_60():
        return _file_60()
    if path == _path_61():
        return _file_61()
    if path == _path_62():
        return _file_62()
    if path == _path_63():
        return _file_63()
    if path == _path_64():
        return _file_64()
    if path == _path_65():
        return _file_65()
    if path == _path_66():
        return _file_66()
    if path == _path_67():
        return _file_67()
    if path == _path_68():
        return _file_68()
    if path == _path_69():
        return _file_69()
    if path == _path_70():
        return _file_70()
    if path == _path_71():
        return _file_71()
    if path == _path_72():
        return _file_72()
    if path == _path_73():
        return _file_73()
    if path == _path_74():
        return _file_74()
    if path == _path_75():
        return _file_75()
    if path == _path_76():
        return _file_76()
    if path == _path_77():
        return _file_77()
    if path == _path_78():
        return _file_78()
    if path == _path_79():
        return _file_79()
    if path == _path_80():
        return _file_80()
    if path == _path_81():
        return _file_81()
    if path == _path_82():
        return _file_82()
    if path == _path_83():
        return _file_83()
    if path == _path_84():
        return _file_84()
    if path == _path_85():
        return _file_85()
    if path == _path_86():
        return _file_86()
    if path == _path_87():
        return _file_87()
    if path == _path_88():
        return _file_88()
    if path == _path_89():
        return _file_89()
    if path == _path_90():
        return _file_90()
    if path == _path_91():
        return _file_91()
    if path == _path_92():
        return _file_92()
    if path == _path_93():
        return _file_93()
    if path == _path_94():
        return _file_94()
    if path == _path_95():
        return _file_95()
    if path == _path_96():
        return _file_96()
    if path == _path_97():
        return _file_97()
    if path == _path_98():
        return _file_98()
    if path == _path_99():
        return _file_99()
    if path == _path_100():
        return _file_100()
    if path == _path_101():
        return _file_101()
    if path == _path_102():
        return _file_102()
    if path == _path_103():
        return _file_103()
    if path == _path_104():
        return _file_104()
    if path == _path_105():
        return _file_105()
    if path == _path_106():
        return _file_106()
    if path == _path_107():
        return _file_107()
    if path == _path_108():
        return _file_108()
    if path == _path_109():
        return _file_109()
    if path == _path_110():
        return _file_110()
    if path == _path_111():
        return _file_111()
    if path == _path_112():
        return _file_112()
    if path == _path_113():
        return _file_113()
    if path == _path_114():
        return _file_114()
    if path == _path_115():
        return _file_115()
    if path == _path_116():
        return _file_116()
    if path == _path_117():
        return _file_117()
    if path == _path_118():
        return _file_118()
    if path == _path_119():
        return _file_119()
    if path == _path_120():
        return _file_120()
    if path == _path_121():
        return _file_121()
    if path == _path_122():
        return _file_122()
    if path == _path_123():
        return _file_123()
    if path == _path_124():
        return _file_124()
    if path == _path_125():
        return _file_125()
    if path == _path_126():
        return _file_126()
    if path == _path_127():
        return _file_127()
    if path == _path_128():
        return _file_128()
    if path == _path_129():
        return _file_129()
    if path == _path_130():
        return _file_130()
    if path == _path_131():
        return _file_131()
    if path == _path_132():
        return _file_132()
    if path == _path_133():
        return _file_133()
    if path == _path_134():
        return _file_134()
    if path == _path_135():
        return _file_135()
    if path == _path_136():
        return _file_136()
    if path == _path_137():
        return _file_137()
    if path == _path_138():
        return _file_138()
    if path == _path_139():
        return _file_139()
    if path == _path_140():
        return _file_140()
    if path == _path_141():
        return _file_141()
    if path == _path_142():
        return _file_142()
    if path == _path_143():
        return _file_143()
    if path == _path_144():
        return _file_144()
    if path == _path_145():
        return _file_145()
    if path == _path_146():
        return _file_146()
    if path == _path_147():
        return _file_147()
    if path == _path_148():
        return _file_148()
    if path == _path_149():
        return _file_149()
    if path == _path_150():
        return _file_150()
    if path == _path_151():
        return _file_151()
    if path == _path_152():
        return _file_152()
    if path == _path_153():
        return _file_153()
    if path == _path_154():
        return _file_154()
    if path == _path_155():
        return _file_155()
    if path == _path_156():
        return _file_156()
    if path == _path_157():
        return _file_157()
    if path == _path_158():
        return _file_158()
    if path == _path_159():
        return _file_159()
    if path == _path_160():
        return _file_160()
    if path == _path_161():
        return _file_161()
    if path == _path_162():
        return _file_162()
    if path == _path_163():
        return _file_163()
    if path == _path_164():
        return _file_164()
    if path == _path_165():
        return _file_165()
    if path == _path_166():
        return _file_166()
    if path == _path_167():
        return _file_167()
    if path == _path_168():
        return _file_168()
    if path == _path_169():
        return _file_169()
    if path == _path_170():
        return _file_170()
    if path == _path_171():
        return _file_171()
    if path == _path_172():
        return _file_172()
    if path == _path_173():
        return _file_173()
    if path == _path_174():
        return _file_174()
    if path == _path_175():
        return _file_175()
    if path == _path_176():
        return _file_176()
    if path == _path_177():
        return _file_177()
    if path == _path_178():
        return _file_178()
    if path == _path_179():
        return _file_179()
    if path == _path_180():
        return _file_180()
    if path == _path_181():
        return _file_181()
    if path == _path_182():
        return _file_182()
    if path == _path_183():
        return _file_183()
    if path == _path_184():
        return _file_184()
    if path == _path_185():
        return _file_185()
    if path == _path_186():
        return _file_186()
    if path == _path_187():
        return _file_187()
    if path == _path_188():
        return _file_188()
    if path == _path_189():
        return _file_189()
    if path == _path_190():
        return _file_190()
    if path == _path_191():
        return _file_191()
    if path == _path_192():
        return _file_192()
    if path == _path_193():
        return _file_193()
    if path == _path_194():
        return _file_194()
    if path == _path_195():
        return _file_195()
    if path == _path_196():
        return _file_196()
    if path == _path_197():
        return _file_197()
    if path == _path_198():
        return _file_198()
    if path == _path_199():
        return _file_199()
    if path == _path_200():
        return _file_200()
    if path == _path_201():
        return _file_201()
    if path == _path_202():
        return _file_202()
    if path == _path_203():
        return _file_203()
    if path == _path_204():
        return _file_204()
    if path == _path_205():
        return _file_205()
    if path == _path_206():
        return _file_206()
    if path == _path_207():
        return _file_207()
    if path == _path_208():
        return _file_208()
    if path == _path_209():
        return _file_209()
    if path == _path_210():
        return _file_210()
    if path == _path_211():
        return _file_211()
    if path == _path_212():
        return _file_212()
    if path == _path_213():
        return _file_213()
    if path == _path_214():
        return _file_214()
    if path == _path_215():
        return _file_215()
    if path == _path_216():
        return _file_216()
    if path == _path_217():
        return _file_217()
    if path == _path_218():
        return _file_218()
    if path == _path_219():
        return _file_219()
    if path == _path_220():
        return _file_220()
    if path == _path_221():
        return _file_221()
    if path == _path_222():
        return _file_222()
    if path == _path_223():
        return _file_223()
    if path == _path_224():
        return _file_224()
    if path == _path_225():
        return _file_225()
    if path == _path_226():
        return _file_226()
    if path == _path_227():
        return _file_227()
    if path == _path_228():
        return _file_228()
    if path == _path_229():
        return _file_229()
    if path == _path_230():
        return _file_230()
    if path == _path_231():
        return _file_231()
    if path == _path_232():
        return _file_232()
    if path == _path_233():
        return _file_233()
    if path == _path_234():
        return _file_234()
    if path == _path_235():
        return _file_235()
    if path == _path_236():
        return _file_236()
    if path == _path_237():
        return _file_237()
    if path == _path_238():
        return _file_238()
    if path == _path_239():
        return _file_239()
    if path == _path_240():
        return _file_240()
    if path == _path_241():
        return _file_241()
    if path == _path_242():
        return _file_242()
    if path == _path_243():
        return _file_243()
    if path == _path_244():
        return _file_244()
    if path == _path_245():
        return _file_245()
    if path == _path_246():
        return _file_246()
    if path == _path_247():
        return _file_247()
    if path == _path_248():
        return _file_248()
    if path == _path_249():
        return _file_249()
    if path == _path_250():
        return _file_250()
    if path == _path_251():
        return _file_251()
    if path == _path_252():
        return _file_252()
    if path == _path_253():
        return _file_253()
    if path == _path_254():
        return _file_254()
    if path == _path_255():
        return _file_255()
    if path == _path_256():
        return _file_256()
    if path == _path_257():
        return _file_257()
    if path == _path_258():
        return _file_258()
    if path == _path_259():
        return _file_259()
    if path == _path_260():
        return _file_260()
    if path == _path_261():
        return _file_261()
    if path == _path_262():
        return _file_262()
    if path == _path_263():
        return _file_263()
    if path == _path_264():
        return _file_264()
    if path == _path_265():
        return _file_265()
    if path == _path_266():
        return _file_266()
    raise Error("no fixture " + String(path))
