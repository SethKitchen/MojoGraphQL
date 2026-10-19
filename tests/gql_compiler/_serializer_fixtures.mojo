# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The files of `serializer_fixtures/`, written by `_embed_serializer.mojo`.
Do not edit."""


def _path_0() -> String:
    var out = String()
    out += "diagnostics/0012_schema_definition_with_missing_query_operat"
    out += "ion_type.graphql"
    return out^


def _input_0() -> String:
    var out = String()
    out += "schema {\n  subscription: customSubscription\n}\n\ntype cust"
    out += "omSubscription {\n  changeInPetHousehold: Result\n}\n\ntype "
    out += "Result {\n  id: String\n}"
    return out^


def _output_0() -> String:
    var out = String()
    out += "schema {\n  subscription: customSubscription\n}\n\ntype cust"
    out += "omSubscription {\n  changeInPetHousehold: Result\n}\n\ntype "
    out += "Result {\n  id: String\n}\n"
    return out^


def _path_1() -> String:
    var out = String()
    out += "diagnostics/0013_schema_definition_with_duplicate_root_type_"
    out += "operations.graphql"
    return out^


def _input_1() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery\n  query: thatOtherQuery\n"
    out += "}\n\ntype customPetQuery {\n  name: String\n}\ntype thatOthe"
    out += "rQuery {\n  age: Int\n}\n"
    return out^


def _output_1() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery\n  query: thatOtherQuery\n"
    out += "}\n\ntype customPetQuery {\n  name: String\n}\n\ntype thatOt"
    out += "herQuery {\n  age: Int\n}\n"
    return out^


def _path_2() -> String:
    var out = String()
    out += "diagnostics/0016_schema_with_built_in_scalar_definition.grap"
    out += "hql"
    return out^


def _input_2() -> String:
    var out = String()
    out += "type Query {\n  amount: Int\n}\n\nscalar Int\n"
    return out^


def _output_2() -> String:
    var out = String()
    out += "type Query {\n  amount: Int\n}\n\nscalar Int\n"
    return out^


def _path_3() -> String:
    var out = String()
    out += "diagnostics/0019_enum_definition_with_duplicate_values.graph"
    out += "ql"
    return out^


def _input_3() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet,\n  snacks: Snack,\n}\n\nenum Pet {"
    out += "\n    CAT\n    DOG\n    FOX\n    CAT\n}\n\nenum Snack {\n   "
    out += " THRIVE_PET_FOODS\n    LILYS_KITCHEN\n    ACANA\n    THRIVE_"
    out += "PET_FOODS\n}"
    return out^


def _output_3() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet\n  snacks: Snack\n}\n\nenum Pet {\n"
    out += "  CAT\n  DOG\n  FOX\n  CAT\n}\n\nenum Snack {\n  THRIVE_PET_"
    out += "FOODS\n  LILYS_KITCHEN\n  ACANA\n  THRIVE_PET_FOODS\n}\n"
    return out^


def _path_4() -> String:
    var out = String()
    out += "diagnostics/0021_union_definition_with_duplicate_members.gra"
    out += "phql"
    return out^


def _input_4() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Photo\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}"
    return out^


def _output_4() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Photo\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}\n"
    return out^


def _path_5() -> String:
    var out = String()
    out += "diagnostics/0022_duplicate_interface_definitions.graphql"
    return out^


def _input_5() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n}\n\ninterface NamedE"
    out += "ntity {\n  name: String\n}\n"
    return out^


def _output_5() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n}\n\ninterface NamedE"
    out += "ntity {\n  name: String\n}\n"
    return out^


def _path_6() -> String:
    var out = String()
    out += "diagnostics/0023_interface_definition_with_cyclic_implements"
    out += "_interfaces.graphql"
    return out^


def _input_6() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity implements NamedEntity {\n  name: String"
    out += "\n}"
    return out^


def _output_6() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity implements NamedEntity {\n  name: String"
    out += "\n}\n"
    return out^


def _path_7() -> String:
    var out = String()
    out += "diagnostics/0024_interface_definition_with_duplicate_fields."
    out += "graphql"
    return out^


def _input_7() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n  name: String\n}"
    return out^


def _output_7() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n  name: String\n}\n"
    return out^


def _path_8() -> String:
    var out = String()
    out += "diagnostics/0025_interface_definition_with_missing_transitiv"
    out += "e_fields.graphql"
    return out^


def _input_8() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Node {\n  id: ID!\n  thumbnail: String\n}"
    return out^


def _output_8() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Node {\n  id: ID!\n  thumbnail: String\n}\n"
    return out^


def _path_9() -> String:
    var out = String()
    out += "diagnostics/0026_interface_definition_with_missing_implemetn"
    out += "s_interface.graphql"
    return out^


def _input_9() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  url: String\n  width: Int\n}\n\ninterface Image i"
    out += "mplements Resource {\n  id: ID!\n  url: String\n  width: Int"
    out += "\n  thumbnail: String\n}"
    return out^


def _output_9() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  url: String\n  width: Int\n}\n\ninterface Image i"
    out += "mplements Resource {\n  id: ID!\n  url: String\n  width: Int"
    out += "\n  thumbnail: String\n}\n"
    return out^


def _path_10() -> String:
    var out = String()
    out += "diagnostics/0027_interface_definition_with_undefined_impleme"
    out += "nts_interface.graphql"
    return out^


def _input_10() -> String:
    var out = String()
    out += "type Query implements Resource {\n  id: ID!\n  width: Int\n}"
    out += "\n\ninterface Resource {\n  id: ID!\n  width: Int\n}\n\ninte"
    out += "rface Image implements Resource & Url {\n  id: ID!\n  url: S"
    out += "tring\n  width: Int\n  thumbnail: String\n}"
    return out^


def _output_10() -> String:
    var out = String()
    out += "type Query implements Resource {\n  id: ID!\n  width: Int\n}"
    out += "\n\ninterface Resource {\n  id: ID!\n  width: Int\n}\n\ninte"
    out += "rface Image implements Resource & Url {\n  id: ID!\n  url: S"
    out += "tring\n  width: Int\n  thumbnail: String\n}\n"
    return out^


def _path_11() -> String:
    var out = String()
    out += "diagnostics/0028_interface_definition_with_missing_fields_im"
    out += "plements_intrefaces_undefined_interfaces.graphql"
    return out^


def _input_11() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Url{\n  id: ID!\n  thumbnail: String\n}"
    return out^


def _output_11() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Url {\n  id: ID!\n  thumbnail: String\n}\n"
    return out^


def _path_12() -> String:
    var out = String()
    out += "diagnostics/0029_directive_definitions_with_duplicate_names."
    out += "graphql"
    return out^


def _input_12() -> String:
    var out = String()
    out += "schema @foo {\n    query: Query\n}\n\ntype Query {\n    id: "
    out += "ID!\n    field: String\n}\n\ndirective @foo on SCHEMA\ndirec"
    out += "tive @foo on SCHEMA"
    return out^


def _output_12() -> String:
    var out = String()
    out += "schema @foo {\n  query: Query\n}\n\ntype Query {\n  id: ID!"
    out += "\n  field: String\n}\n\ndirective @foo on SCHEMA\n\ndirectiv"
    out += "e @foo on SCHEMA\n"
    return out^


def _path_13() -> String:
    var out = String()
    out += "diagnostics/0030_schema_with_duplicate_input_objects.graphql"
    return out^


def _input_13() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}\n\ninput Poin"
    out += "t2D {\n  x: Float\n  y: Float\n}"
    return out^


def _output_13() -> String:
    var out = String()
    out += "type Query {\n  website: URL\n  amount: Int\n}\n\nscalar URL"
    out += ' @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}\n\ninput Poin"
    out += "t2D {\n  x: Float\n  y: Float\n}\n"
    return out^


def _path_14() -> String:
    var out = String()
    out += "diagnostics/0031_input_object_with_duplicate_fields.graphql"
    return out^


def _input_14() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  x: Float\n}"
    return out^


def _output_14() -> String:
    var out = String()
    out += "type Query {\n  website: URL\n  amount: Int\n}\n\nscalar URL"
    out += ' @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  x: Float\n}\n"
    return out^


def _path_15() -> String:
    var out = String()
    out += "diagnostics/0032_duplicate_object_type_definition.graphql"
    return out^


def _input_15() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\ntype Query {\n  name: Str"
    out += "ing\n}"
    return out^


def _output_15() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\ntype Query {\n  name: Str"
    out += "ing\n}\n"
    return out^


def _path_16() -> String:
    var out = String()
    out += "diagnostics/0033_object_type_definition_with_duplicate_field"
    out += "s.graphql"
    return out^


def _input_16() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  name: String\n}\n"
    return out^


def _output_16() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  name: String\n}\n"
    return out^


def _path_17() -> String:
    var out = String()
    out += "diagnostics/0034_object_type_definition_with_missing_transit"
    out += "ive_fields.graphql"
    return out^


def _input_17() -> String:
    var out = String()
    out += "type Query implements Node & Resource {\n  name: String\n}\n"
    out += "\ninterface Node {\n  id: ID!\n}\n\ninterface Resource {\n  "
    out += "width: Int\n}"
    return out^


def _output_17() -> String:
    var out = String()
    out += "type Query implements Node & Resource {\n  name: String\n}\n"
    out += "\ninterface Node {\n  id: ID!\n}\n\ninterface Resource {\n  "
    out += "width: Int\n}\n"
    return out^


def _path_18() -> String:
    var out = String()
    out += "diagnostics/0035_object_type_definition_with_missing_impleme"
    out += "nts_interfaces_definition.graphql"
    return out^


def _input_18() -> String:
    var out = String()
    out += "type Query implements Image {\n  name: String\n  id: ID!\n  "
    out += "url: String\n  width: Int\n  thumbnail: String\n}\n\ninterfa"
    out += "ce Node {\n  id: ID!\n}\n\ninterface Resource implements Nod"
    out += "e {\n  id: ID!\n  url: String\n  width: Int\n}\n\ninterface "
    out += "Image implements Resource {\n  id: ID!\n  url: String\n  wid"
    out += "th: Int\n  thumbnail: String\n}"
    return out^


def _output_18() -> String:
    var out = String()
    out += "type Query implements Image {\n  name: String\n  id: ID!\n  "
    out += "url: String\n  width: Int\n  thumbnail: String\n}\n\ninterfa"
    out += "ce Node {\n  id: ID!\n}\n\ninterface Resource implements Nod"
    out += "e {\n  id: ID!\n  url: String\n  width: Int\n}\n\ninterface "
    out += "Image implements Resource {\n  id: ID!\n  url: String\n  wid"
    out += "th: Int\n  thumbnail: String\n}\n"
    return out^


def _path_19() -> String:
    var out = String()
    out += "diagnostics/0038_object_type_with_undefined_field_type.graph"
    out += "ql"
    return out^


def _input_19() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n  relationship: Pers"
    out += "on\n}"
    return out^


def _output_19() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n  relationship: Pers"
    out += "on\n}\n"
    return out^


def _path_20() -> String:
    var out = String()
    out += "diagnostics/0039_interface_with_undefined_field_type.graphql"
    return out^


def _input_20() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n}\n\ninterface Conne"
    out += "ction {\n  relationship: Person\n}"
    return out^


def _output_20() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n}\n\ninterface Conne"
    out += "ction {\n  relationship: Person\n}\n"
    return out^


def _path_21() -> String:
    var out = String()
    out += "diagnostics/0043_undefined_union_member.graphql"
    return out^


def _input_21() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Dog implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  barkVolume: Int\n"
    out += "}\n\nunion CatOrDog = Cat | Dog\n\ntype Human {\n  name: Str"
    out += "ing\n  pets: [Pet]\n}\n\ntype Query {\n  human: Human\n}"
    return out^


def _output_21() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Dog implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  barkVolume: Int\n"
    out += "}\n\nunion CatOrDog = Cat | Dog\n\ntype Human {\n  name: Str"
    out += "ing\n  pets: [Pet]\n}\n\ntype Query {\n  human: Human\n}\n"
    return out^


def _path_22() -> String:
    var out = String()
    out += "diagnostics/0044_union_member_not_of_object_type.graphql"
    return out^


def _input_22() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Cat implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  meowVolume: Int\n"
    out += "}\n\ntype Dog implements Pet {\n  name: String\n  nickname: "
    out += "String\n  barkVolume: Int\n}\n\nunion CatOrDog = Cat | Pet\n"
    out += "\ntype Human {\n  name: String\n  pets: [Pet]\n}\n\ntype Que"
    out += "ry {\n  human: Human\n}"
    return out^


def _output_22() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Cat implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  meowVolume: Int\n"
    out += "}\n\ntype Dog implements Pet {\n  name: String\n  nickname: "
    out += "String\n  barkVolume: Int\n}\n\nunion CatOrDog = Cat | Pet\n"
    out += "\ntype Human {\n  name: String\n  pets: [Pet]\n}\n\ntype Que"
    out += "ry {\n  human: Human\n}\n"
    return out^


def _path_23() -> String:
    var out = String()
    out += "diagnostics/0046_duplicate_directive_arguments.graphql"
    return out^


def _input_23() -> String:
    var out = String()
    out += 'scalar newScalar @specifiedBy(url: "https://tools.ietf.org/'
    out += 'html/rfc4122", url: "https://tools.ietf.org/html/rfc4125"'
    out += ")\n\ntype Query {\n  status: String,\n  response: String @ex"
    out += "ample(if: false, if: true)\n}\n\ndirective @example(if: Bool"
    out += "ean) on FIELD_DEFINITION"
    return out^


def _output_23() -> String:
    var out = String()
    out += 'scalar newScalar @specifiedBy(url: "https://tools.ietf.org/'
    out += 'html/rfc4122", url: "https://tools.ietf.org/html/rfc4125"'
    out += ")\n\ntype Query {\n  status: String\n  response: String @exa"
    out += "mple(if: false, if: true)\n}\n\ndirective @example(if: Boole"
    out += "an) on FIELD_DEFINITION\n"
    return out^


def _path_24() -> String:
    var out = String()
    out += "diagnostics/0048_duplicate_field_argument_definition_names.g"
    out += "raphql"
    return out^


def _input_24() -> String:
    var out = String()
    out += "interface Duplicate {\n  duplicate(arg: Boolean, arg: Boolea"
    out += "n): Int\n}\n\ntype Query implements Duplicate {\n  single(ar"
    out += "g: Boolean): Int\n  duplicate(arg: Boolean, arg: Boolean): I"
    out += "nt\n}\n"
    return out^


def _output_24() -> String:
    var out = String()
    out += "interface Duplicate {\n  duplicate(arg: Boolean, arg: Boolea"
    out += "n): Int\n}\n\ntype Query implements Duplicate {\n  single(ar"
    out += "g: Boolean): Int\n  duplicate(arg: Boolean, arg: Boolean): I"
    out += "nt\n}\n"
    return out^


def _path_25() -> String:
    var out = String()
    out += "diagnostics/0049_duplicate_directive_argument_definition_nam"
    out += "es.graphql"
    return out^


def _input_25() -> String:
    var out = String()
    out += "directive @example(arg: Boolean, arg: Boolean) on FIELD\ntyp"
    out += "e Query {\n  x: Int\n}\n"
    return out^


def _output_25() -> String:
    var out = String()
    out += "directive @example(arg: Boolean, arg: Boolean) on FIELD\n\nt"
    out += "ype Query {\n  x: Int\n}\n"
    return out^


def _path_26() -> String:
    var out = String()
    out += "diagnostics/0052_undefined_directive.graphql"
    return out^


def _input_26() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    status: Int @directiveA"
    out += "\n}\n\ndirective @directiveB on FIELD_DEFINITION\n"
    return out^


def _output_26() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  status: Int @directiveA\n}\n"
    out += "\ndirective @directiveB on FIELD_DEFINITION\n"
    return out^


def _path_27() -> String:
    var out = String()
    out += "diagnostics/0057_duplicate_type_names.graphql"
    return out^


def _input_27() -> String:
    var out = String()
    out += "interface World {\n  a: Int\n}\ntype Object implements World"
    out += " {\n  a: Int\n}\n\n# not OK\ntype World implements World {\n"
    out += '  a: Int\n}\n\n# OK\nscalar X @specifiedBy(url: "https://ap'
    out += 'ollographql.com")\n# not OK\nunion X @X = Object\n# not OK'
    out += "\nenum X { Y, Z }\n\ntype X {\n  x: X\n}\n\ndirective @X(ok:"
    out += " Boolean) on UNION\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_27() -> String:
    var out = String()
    out += "interface World {\n  a: Int\n}\n\ntype Object implements Wor"
    out += "ld {\n  a: Int\n}\n\ntype World implements World {\n  a: Int"
    out += '\n}\n\nscalar X @specifiedBy(url: "https://apollographql.co'
    out += 'm")\n\nunion X @X = Object\n\nenum X {\n  Y\n  Z\n}\n\ntype'
    out += " X {\n  x: X\n}\n\ndirective @X(ok: Boolean) on UNION\n\ntyp"
    out += "e Query {\n  x: Int\n}\n"
    return out^


def _path_28() -> String:
    var out = String()
    out += "diagnostics/0059_root_operation_object_type.graphql"
    return out^


def _input_28() -> String:
    var out = String()
    out += "schema {\n    query: SomeInterface \n}\n\ninterface SomeInte"
    out += "rface {\n    name: String\n}\n\ntype ShouldBeTheQuery {\n   "
    out += " name: String\n}"
    return out^


def _output_28() -> String:
    var out = String()
    out += "schema {\n  query: SomeInterface\n}\n\ninterface SomeInterfa"
    out += "ce {\n  name: String\n}\n\ntype ShouldBeTheQuery {\n  name: "
    out += "String\n}\n"
    return out^


def _path_29() -> String:
    var out = String()
    out += "diagnostics/0060_root_operation_definition_undefined_operati"
    out += "on_type.graphql"
    return out^


def _input_29() -> String:
    var out = String()
    out += "schema {\n    query: SomeQuery\n}\n\ntype ShouldBeTheQuery {"
    out += "\n    name: String\n}"
    return out^


def _output_29() -> String:
    var out = String()
    out += "schema {\n  query: SomeQuery\n}\n\ntype ShouldBeTheQuery {\n"
    out += "  name: String\n}\n"
    return out^


def _path_30() -> String:
    var out = String()
    out += "diagnostics/0061_root_operation_with_default_undefined_query"
    out += ".graphql"
    return out^


def _input_30() -> String:
    var out = String()
    out += "schema {\n    query: Query\n}"
    return out^


def _output_30() -> String:
    var out = String()
    out += "schema {\n  query: Query\n}\n"
    return out^


def _path_31() -> String:
    var out = String()
    out += "diagnostics/0063_extension_orphan.graphql"
    return out^


def _input_31() -> String:
    var out = String()
    out += "type Query {\n  x: Int\n}\n\nextend scalar A @deprecated(rea"
    out += 'son: "Use B instead")\nextend type B { field: Int! }\nexte'
    out += "nd schema {\n  query: Query\n}\nextend union C = String\next"
    out += "end interface D {\n  field: Int\n}\nextend input E {\n  fiel"
    out += "d: Int\n}\nextend enum F {\n  MEMBER\n}\n"
    return out^


def _output_31() -> String:
    var out = String()
    out += "type Query {\n  x: Int\n}\n\nextend scalar A @deprecated(rea"
    out += 'son: "Use B instead")\n\nextend type B {\n  field: Int!\n}'
    out += "\n\nextend schema {\n  query: Query\n}\n\nextend union C = S"
    out += "tring\n\nextend interface D {\n  field: Int\n}\n\nextend inp"
    out += "ut E {\n  field: Int\n}\n\nextend enum F {\n  MEMBER\n}\n"
    return out^


def _path_32() -> String:
    var out = String()
    out += "diagnostics/0064_extension_wrong_type.graphql"
    return out^


def _input_32() -> String:
    var out = String()
    out += 'scalar Scalar @specifiedBy(url: "https://apollographql.com'
    out += '")\ninterface Intf {\n  field: Int,\n}\ntype Object {\n  fi'
    out += "eld: Int,\n}\nunion Union = Scalar | Object\ninput Input {\n"
    out += "  field: Int,\n}\nenum Enum {\n  MEMBER\n}\n\nextend union S"
    out += "calar = String\nextend interface Object {\n  field2: Scalar,"
    out += "\n}\nextend enum Intf {\n  MEMBER_2\n}\nextend type Input {"
    out += "\n  field2: Scalar,\n}\nextend input Enum {\n  field2: Scala"
    out += "r,\n}\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_32() -> String:
    var out = String()
    out += 'scalar Scalar @specifiedBy(url: "https://apollographql.com'
    out += '")\n\ninterface Intf {\n  field: Int\n}\n\ntype Object {\n '
    out += " field: Int\n}\n\nunion Union = Scalar | Object\n\ninput Inp"
    out += "ut {\n  field: Int\n}\n\nenum Enum {\n  MEMBER\n}\n\nextend "
    out += "union Scalar = String\n\nextend interface Object {\n  field2"
    out += ": Scalar\n}\n\nextend enum Intf {\n  MEMBER_2\n}\n\nextend t"
    out += "ype Input {\n  field2: Scalar\n}\n\nextend input Enum {\n  f"
    out += "ield2: Scalar\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_33() -> String:
    var out = String()
    out += "diagnostics/0070_self_referential_directive_definition.graph"
    out += "ql"
    return out^


def _input_33() -> String:
    var out = String()
    out += "type Query {\n  id: ID!\n  field(arg: Int @invalidExample): "
    out += "String\n}\n\n# Simple, direct self-reference\ndirective @inv"
    out += "alidExample(arg: String @invalidExample) on ARGUMENT_DEFINIT"
    out += "ION\n\n# Some more nested self-references\nextend scalar Str"
    out += 'ing @deprecatedType(reason: "use OurCustomString instead")'
    out += "\ndirective @deprecatedType(reason: String!) on OBJECT | INT"
    out += "ERFACE | ENUM | SCALAR | UNION\n\ndirective @loopA(arg: Bool"
    out += "ean @loopB) on ARGUMENT_DEFINITION\ndirective @loopB(arg: Bo"
    out += "olean @loopC) on ARGUMENT_DEFINITION\ndirective @loopC(arg: "
    out += "Boolean @loopA) on ARGUMENT_DEFINITION\n\nenum Enum { NON_RE"
    out += "CURSIVE }\nextend enum Enum { RECURSIVE @wrong }\ninput Name"
    out += " { value: String!, type: Enum }\ninput InputObject { name: N"
    out += "ame }\ndirective @wrong(input: InputObject) on INPUT_FIELD_D"
    out += "EFINITION | ENUM_VALUE\n\ndirective @thisOneShouldNotError(a"
    out += "rg: Boolean @loopC) on FIELD\n"
    return out^


def _output_33() -> String:
    var out = String()
    out += "type Query {\n  id: ID!\n  field(\n    arg: Int @invalidExam"
    out += "ple,\n  ): String\n}\n\ndirective @invalidExample(\n  arg: S"
    out += "tring @invalidExample,\n) on ARGUMENT_DEFINITION\n\nextend s"
    out += 'calar String @deprecatedType(reason: "use OurCustomString i'
    out += 'nstead")\n\ndirective @deprecatedType(reason: String!) on O'
    out += "BJECT | INTERFACE | ENUM | SCALAR | UNION\n\ndirective @loop"
    out += "A(\n  arg: Boolean @loopB,\n) on ARGUMENT_DEFINITION\n\ndire"
    out += "ctive @loopB(\n  arg: Boolean @loopC,\n) on ARGUMENT_DEFINIT"
    out += "ION\n\ndirective @loopC(\n  arg: Boolean @loopA,\n) on ARGUM"
    out += "ENT_DEFINITION\n\nenum Enum {\n  NON_RECURSIVE\n}\n\nextend "
    out += "enum Enum {\n  RECURSIVE @wrong\n}\n\ninput Name {\n  value:"
    out += " String!\n  type: Enum\n}\n\ninput InputObject {\n  name: Na"
    out += "me\n}\n\ndirective @wrong(input: InputObject) on INPUT_FIELD"
    out += "_DEFINITION | ENUM_VALUE\n\ndirective @thisOneShouldNotError"
    out += "(\n  arg: Boolean @loopC,\n) on FIELD\n"
    return out^


def _path_34() -> String:
    var out = String()
    out += "diagnostics/0080_directive_is_unique_with_extensions.graphql"
    return out^


def _input_34() -> String:
    var out = String()
    out += "directive @nonRepeatable on OBJECT | SCALAR | INTERFACE\next"
    out += "end type TestObject @nonRepeatable\ntype TestObject @nonRepe"
    out += "atable {\n  field: String\n}\nextend type TestObject @nonRep"
    out += "eatable\n\nscalar Scalar @nonRepeatable\nextend scalar Scala"
    out += 'r @nonRepeatable @specifiedBy(url: "example.com")\n\ninter'
    out += "face Intf @nonRepeatable {\n  field: String\n}\nextend inter"
    out += "face Intf @nonRepeatable\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_34() -> String:
    var out = String()
    out += "directive @nonRepeatable on OBJECT | SCALAR | INTERFACE\n\ne"
    out += "xtend type TestObject @nonRepeatable\n\ntype TestObject @non"
    out += "Repeatable {\n  field: String\n}\n\nextend type TestObject @"
    out += "nonRepeatable\n\nscalar Scalar @nonRepeatable\n\nextend scal"
    out += 'ar Scalar @nonRepeatable @specifiedBy(url: "example.com")'
    out += "\n\ninterface Intf @nonRepeatable {\n  field: String\n}\n\ne"
    out += "xtend interface Intf @nonRepeatable\n\ntype Query {\n  x: In"
    out += "t\n}\n"
    return out^


def _path_35() -> String:
    var out = String()
    out += "diagnostics/0081_directive_is_unique_type_system.graphql"
    return out^


def _input_35() -> String:
    var out = String()
    out += "directive @nonRepeatable on\n  SCHEMA | SCALAR | OBJECT | IN"
    out += "TERFACE | UNION | INPUT_OBJECT\nschema @nonRepeatable @nonRe"
    out += "peatable { query: Dummy }\nscalar TestScalar @nonRepeatable "
    out += '@nonRepeatable @specifiedBy(url: "example.com")\ntype Dumm'
    out += "y @nonRepeatable @nonRepeatable\ninterface TestInterface @no"
    out += "nRepeatable @nonRepeatable\nunion TestUnion @nonRepeatable @"
    out += "nonRepeatable\ninput TestInput @nonRepeatable @nonRepeatable"
    out += "\n"
    return out^


def _output_35() -> String:
    var out = String()
    out += "directive @nonRepeatable on SCHEMA | SCALAR | OBJECT | INTER"
    out += "FACE | UNION | INPUT_OBJECT\n\nschema @nonRepeatable @nonRep"
    out += "eatable {\n  query: Dummy\n}\n\nscalar TestScalar @nonRepeat"
    out += 'able @nonRepeatable @specifiedBy(url: "example.com")\n\nty'
    out += "pe Dummy @nonRepeatable @nonRepeatable\n\ninterface TestInte"
    out += "rface @nonRepeatable @nonRepeatable\n\nunion TestUnion @nonR"
    out += "epeatable @nonRepeatable\n\ninput TestInput @nonRepeatable @"
    out += "nonRepeatable\n"
    return out^


def _path_36() -> String:
    var out = String()
    out += "diagnostics/0084_circular_non_nullable_input_objects.graphql"
    return out^


def _input_36() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    example(arg: First): Int"
    out += "\n}\n\ninput First {\n  second: Second!\n  value: String\n}"
    out += "\n\ninput Second {\n  third: Third!\n  value: String\n}\n\ni"
    out += "nput Third {\n  fourth: Fourth!\n  value: String\n}\n\ninput"
    out += " Fourth {\n  first: First!\n}"
    return out^


def _output_36() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  example(arg: First): Int\n}"
    out += "\n\ninput First {\n  second: Second!\n  value: String\n}\n\n"
    out += "input Second {\n  third: Third!\n  value: String\n}\n\ninput"
    out += " Third {\n  fourth: Fourth!\n  value: String\n}\n\ninput Fou"
    out += "rth {\n  first: First!\n}\n"
    return out^


def _path_37() -> String:
    var out = String()
    out += "diagnostics/0094_object_type_extensions.graphql"
    return out^


def _input_37() -> String:
    var out = String()
    out += "type UniqueNames {\n  name: String\n}\nextend type UniqueNam"
    out += "es {\n  age: Int\n  age: Int\n}\n\ntype ConflictingNames {\n"
    out += "  name: String\n}\nextend type ConflictingNames {\n  name: S"
    out += "tring\n}\n\ndirective @nonRepeatable on OBJECT\ntype UniqueD"
    out += "irective @nonRepeatable {\n  a: Int!\n}\nextend type UniqueD"
    out += "irective @nonRepeatable {\n  b: Int\n}\n\ninterface Base {\n"
    out += "  name: String\n}\ntype UniqueInterfaces implements Base {\n"
    out += "  name: String\n  nickname: String\n}\nextend type UniqueInt"
    out += "erfaces implements Base {\n  age: Int\n}\n\ninterface Extend"
    out += "edInterface {\n  name: String\n}\ntype ImplementsBaseButNotE"
    out += "xtension implements ExtendedInterface {\n  name: String\n}\n"
    out += "extend interface ExtendedInterface {\n  fail: Boolean\n}\nty"
    out += "pe Query {\n  x: Int\n}\n"
    return out^


def _output_37() -> String:
    var out = String()
    out += "type UniqueNames {\n  name: String\n}\n\nextend type UniqueN"
    out += "ames {\n  age: Int\n  age: Int\n}\n\ntype ConflictingNames {"
    out += "\n  name: String\n}\n\nextend type ConflictingNames {\n  nam"
    out += "e: String\n}\n\ndirective @nonRepeatable on OBJECT\n\ntype U"
    out += "niqueDirective @nonRepeatable {\n  a: Int!\n}\n\nextend type"
    out += " UniqueDirective @nonRepeatable {\n  b: Int\n}\n\ninterface "
    out += "Base {\n  name: String\n}\n\ntype UniqueInterfaces implement"
    out += "s Base {\n  name: String\n  nickname: String\n}\n\nextend ty"
    out += "pe UniqueInterfaces implements Base {\n  age: Int\n}\n\ninte"
    out += "rface ExtendedInterface {\n  name: String\n}\n\ntype Impleme"
    out += "ntsBaseButNotExtension implements ExtendedInterface {\n  nam"
    out += "e: String\n}\n\nextend interface ExtendedInterface {\n  fail"
    out += ": Boolean\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_38() -> String:
    var out = String()
    out += "diagnostics/0095_interface_implementation_declared_once.grap"
    out += "hql"
    return out^


def _input_38() -> String:
    var out = String()
    out += "interface Intf {\n  field: String\n}\n\ntype Object implemen"
    out += "ts Intf & Intf {\n  field: String\n}\n\ntype Extended implem"
    out += "ents Intf {\n  field: String\n}\nextend type Extended implem"
    out += "ents Intf\n\ninterface SubIntf implements Intf & Intf {\n  f"
    out += "ield: String\n}\n\n# TODO(@goto-bus-stop): support interface"
    out += " extensions in validation\n# interface ExtendedIntf implemen"
    out += "ts Intf {\n#   field: String\n# }\n# extend interface Extend"
    out += "edIntf implements Intf\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_38() -> String:
    var out = String()
    out += "interface Intf {\n  field: String\n}\n\ntype Object implemen"
    out += "ts Intf & Intf {\n  field: String\n}\n\ntype Extended implem"
    out += "ents Intf {\n  field: String\n}\n\nextend type Extended impl"
    out += "ements Intf\n\ninterface SubIntf implements Intf & Intf {\n "
    out += " field: String\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_39() -> String:
    var out = String()
    out += "diagnostics/0096_schema_extensions.graphql"
    return out^


def _input_39() -> String:
    var out = String()
    out += "# Any non-repeatable directives provided must not already ap"
    out += "ply to the original Schema.\ndirective @nonRepeatable on SCH"
    out += "EMA\n\ntype Query {\n  viewCount: Int!\n}\n\nschema @nonRepe"
    out += "atable {\n  query: Query\n}\nextend schema @nonRepeatable\n"
    return out^


def _output_39() -> String:
    var out = String()
    out += "directive @nonRepeatable on SCHEMA\n\ntype Query {\n  viewCo"
    out += "unt: Int!\n}\n\nschema @nonRepeatable {\n  query: Query\n}\n"
    out += "\nextend schema @nonRepeatable\n"
    return out^


def _path_40() -> String:
    var out = String()
    out += "diagnostics/0097_enum_extensions.graphql"
    return out^


def _input_40() -> String:
    var out = String()
    out += "directive @nonRepeatable on ENUM\n\nenum E {\n  MEMBER_1\n  "
    out += "MEMBER_2\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_3\n "
    out += " MEMBER_4\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_2\n"
    out += "  MEMBER_4\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_40() -> String:
    var out = String()
    out += "directive @nonRepeatable on ENUM\n\nenum E {\n  MEMBER_1\n  "
    out += "MEMBER_2\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_3\n "
    out += " MEMBER_4\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_2\n"
    out += "  MEMBER_4\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_41() -> String:
    var out = String()
    out += "diagnostics/0098_interface_extensions.graphql"
    return out^


def _input_41() -> String:
    var out = String()
    out += "interface UniqueNames {\n  name: String\n}\nextend interface"
    out += " UniqueNames {\n  name: String\n}\n\ndirective @nonRepeatabl"
    out += "e on INTERFACE\n\ninterface Directives @nonRepeatable {\n  a"
    out += "ge: Int\n}\n\nextend interface Directives @nonRepeatable\n\n"
    out += "interface Base {\n  a: Int\n  b: Int\n  c: Int\n}\ninterface"
    out += " Derived {\n  a: Int\n}\nextend interface Derived implements"
    out += " Base {\n  c: Int\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_41() -> String:
    var out = String()
    out += "interface UniqueNames {\n  name: String\n}\n\nextend interfa"
    out += "ce UniqueNames {\n  name: String\n}\n\ndirective @nonRepeata"
    out += "ble on INTERFACE\n\ninterface Directives @nonRepeatable {\n "
    out += " age: Int\n}\n\nextend interface Directives @nonRepeatable\n"
    out += "\ninterface Base {\n  a: Int\n  b: Int\n  c: Int\n}\n\ninter"
    out += "face Derived {\n  a: Int\n}\n\nextend interface Derived impl"
    out += "ements Base {\n  c: Int\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_42() -> String:
    var out = String()
    out += "diagnostics/0099_input_object_extensions.graphql"
    return out^


def _input_42() -> String:
    var out = String()
    out += "input UniqueNames {\n  field: String\n}\nextend input Unique"
    out += "Names {\n  field: String\n}\n\ndirective @nonRepeatable on I"
    out += "NPUT_OBJECT\ninput UniqueDirective @nonRepeatable {\n  field"
    out += ": String\n}\nextend input UniqueDirective @nonRepeatable\n\n"
    out += "type Query {\n  x: Int\n}\n"
    return out^


def _output_42() -> String:
    var out = String()
    out += "input UniqueNames {\n  field: String\n}\n\nextend input Uniq"
    out += "ueNames {\n  field: String\n}\n\ndirective @nonRepeatable on"
    out += " INPUT_OBJECT\n\ninput UniqueDirective @nonRepeatable {\n  f"
    out += "ield: String\n}\n\nextend input UniqueDirective @nonRepeatab"
    out += "le\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_43() -> String:
    var out = String()
    out += "diagnostics/0100_union_extensions.graphql"
    return out^


def _input_43() -> String:
    var out = String()
    out += 'scalar ThisIsAScalar @specifiedBy(url: "https://example.com'
    out += '")\n\ntype WithFieldA { a: String }\ntype WithFieldB { b: S'
    out += "tring }\n\n# Extension can't add a non-object type\nunion No"
    out += "nObjectType = WithFieldA | WithFieldB\nextend union NonObjec"
    out += "tType = ThisIsAScalar\n\n# Extension can't add duplicate mem"
    out += "bers\nunion DuplicateMembers = WithFieldA\nextend union Dupl"
    out += "icateMembers = WithFieldA | WithFieldB\n\n# Extension can't "
    out += "add duplicate directives\ndirective @nonRepeatable on UNION"
    out += "\nunion DuplicateDirective @nonRepeatable = WithFieldA\nexte"
    out += "nd union DuplicateDirective @nonRepeatable = WithFieldB\n\nt"
    out += "ype Query {\n  x: Int\n}\n"
    return out^


def _output_43() -> String:
    var out = String()
    out += 'scalar ThisIsAScalar @specifiedBy(url: "https://example.com'
    out += '")\n\ntype WithFieldA {\n  a: String\n}\n\ntype WithFieldB '
    out += "{\n  b: String\n}\n\nunion NonObjectType = WithFieldA | With"
    out += "FieldB\n\nextend union NonObjectType = ThisIsAScalar\n\nunio"
    out += "n DuplicateMembers = WithFieldA\n\nextend union DuplicateMem"
    out += "bers = WithFieldA | WithFieldB\n\ndirective @nonRepeatable o"
    out += "n UNION\n\nunion DuplicateDirective @nonRepeatable = WithFie"
    out += "ldA\n\nextend union DuplicateDirective @nonRepeatable = With"
    out += "FieldB\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_44() -> String:
    var out = String()
    out += "diagnostics/0103_invalid_directive_on_input_value.graphql"
    return out^


def _input_44() -> String:
    var out = String()
    out += "directive @example(arg: String!) on INPUT_FIELD_DEFINITION |"
    out += " ARGUMENT_DEFINITION\n\ninput Input {\n  key: String! @examp"
    out += "le\n}\n\ndirective @directive(arg2: Int @example) on SCHEMA"
    out += "\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_44() -> String:
    var out = String()
    out += "directive @example(arg: String!) on INPUT_FIELD_DEFINITION |"
    out += " ARGUMENT_DEFINITION\n\ninput Input {\n  key: String! @examp"
    out += "le\n}\n\ndirective @directive(\n  arg2: Int @example,\n) on "
    out += "SCHEMA\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_45() -> String:
    var out = String()
    out += "diagnostics/0104_invalid_type_in_arg.graphql"
    return out^


def _input_45() -> String:
    var out = String()
    out += 'scalar AnInputType @specifiedBy(url: "http://example.com")'
    out += "\ntype OutputType {\n  not: AnInputType\n}\n\ninput InputObj"
    out += "ectWithOutputType {\n  thisIsWrong: OutputType\n}\n\ntype Ro"
    out += "ot {\n  id: ID!\n  undefinedTypes(a: number, b: number): Ope"
    out += "rationResult!\n  outputTypes(a: OutputType, b: OperationResu"
    out += "lt): ID!\n}\n\nunion OperationResult = Operation\n\ntype Ope"
    out += "ration {\n  id: ID!\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _output_45() -> String:
    var out = String()
    out += 'scalar AnInputType @specifiedBy(url: "http://example.com")'
    out += "\n\ntype OutputType {\n  not: AnInputType\n}\n\ninput InputO"
    out += "bjectWithOutputType {\n  thisIsWrong: OutputType\n}\n\ntype "
    out += "Root {\n  id: ID!\n  undefinedTypes(a: number, b: number): O"
    out += "perationResult!\n  outputTypes(a: OutputType, b: OperationRe"
    out += "sult): ID!\n}\n\nunion OperationResult = Operation\n\ntype O"
    out += "peration {\n  id: ID!\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _path_46() -> String:
    var out = String()
    out += "diagnostics/0107_built_in_directive_double_redefinition.grap"
    out += "hql"
    return out^


def _input_46() -> String:
    var out = String()
    out += "schema\n  # No error here (the *first* redefinition is used,"
    out += ' allowing SCHEMA location)\n  @deprecated(\n    reason: ""'
    out += '"\n    The person who got promoted by shipping this product'
    out += " has moved on to another team.\n    The service will shut do"
    out += 'wn next month.\n    """\n  ) {\n  query: Query\n}\n\ntype'
    out += " Query {\n  importantData: Int\n}\n\n# No error at first red"
    out += 'efinition\ndirective @deprecated(\n  reason: String = "No l'
    out += 'onger supported"\n) on FIELD_DEFINITION | ARGUMENT_DEFINITI'
    out += "ON | INPUT_FIELD_DEFINITION | ENUM_VALUE | SCHEMA\n\n# Error"
    out += " (name collision) at the second redefinition\ndirective @dep"
    out += 'recated(\n  reason: String = "No longer supported"\n) on F'
    out += "IELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITI"
    out += "ON | ENUM_VALUE | OBJECT | INTERFACE | UNION | ENUM | INPUT_"
    out += "OBJECT\n"
    return out^


def _output_46() -> String:
    var out = String()
    out += 'schema @deprecated(reason: "The person who got promoted by '
    out += "shipping this product has moved on to another team.\\nThe se"
    out += 'rvice will shut down next month.") {\n  query: Query\n}\n\n'
    out += "type Query {\n  importantData: Int\n}\n\ndirective @deprecat"
    out += 'ed(reason: String = "No longer supported") on FIELD_DEFINI'
    out += "TION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_V"
    out += 'ALUE | SCHEMA\n\ndirective @deprecated(reason: String = "No'
    out += ' longer supported") on FIELD_DEFINITION | ARGUMENT_DEFINITI'
    out += "ON | INPUT_FIELD_DEFINITION | ENUM_VALUE | OBJECT | INTERFAC"
    out += "E | UNION | ENUM | INPUT_OBJECT\n"
    return out^


def _path_47() -> String:
    var out = String()
    out += "diagnostics/0108_implicit_schema_extension.graphql"
    return out^


def _input_47() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\nextend schema {\n    qu"
    out += "ery: Query\n}"
    return out^


def _output_47() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\nextend schema {\n  query:"
    out += " Query\n}\n"
    return out^


def _path_48() -> String:
    var out = String()
    out += "diagnostics/0114_interface_definition_with_missing_fields.gr"
    out += "aphql"
    return out^


def _input_48() -> String:
    var out = String()
    out += "directive @foo on INTERFACE\ntype Query {\n    foo: Node\n}"
    out += "\n\ninterface Node\n\nextend interface Node @foo"
    return out^


def _output_48() -> String:
    var out = String()
    out += "directive @foo on INTERFACE\n\ntype Query {\n  foo: Node\n}"
    out += "\n\ninterface Node\n\nextend interface Node @foo\n"
    return out^


def _path_49() -> String:
    var out = String()
    out += "diagnostics/0115_object_definition_with_missing_fields.graph"
    out += "ql"
    return out^


def _input_49() -> String:
    var out = String()
    out += "directive @foo on OBJECT\ndirective @bar on OBJECT\ntype Que"
    out += "ry {\n    foo: User\n}\n\ntype User @foo\n\nextend type User"
    out += " @bar\n"
    return out^


def _output_49() -> String:
    var out = String()
    out += "directive @foo on OBJECT\n\ndirective @bar on OBJECT\n\ntype"
    out += " Query {\n  foo: User\n}\n\ntype User @foo\n\nextend type Us"
    out += "er @bar\n"
    return out^


def _path_50() -> String:
    var out = String()
    out += "diagnostics/0116_enum_definition_with_missing_values.graphql"
    return out^


def _input_50() -> String:
    var out = String()
    out += "directive @foo on ENUM\ntype Query {\n    foo: WEEKDAY\n}\n"
    out += "\nenum WEEKDAY\n\nextend enum WEEKDAY @foo"
    return out^


def _output_50() -> String:
    var out = String()
    out += "directive @foo on ENUM\n\ntype Query {\n  foo: WEEKDAY\n}\n"
    out += "\nenum WEEKDAY\n\nextend enum WEEKDAY @foo\n"
    return out^


def _path_51() -> String:
    var out = String()
    out += "diagnostics/0117_union_definition_with_missing_members.graph"
    out += "ql"
    return out^


def _input_51() -> String:
    var out = String()
    out += "directive @foo on UNION\ntype Query {\n    foo: Search\n}\n"
    out += "\nunion Search\n\nextend union Search @foo"
    return out^


def _output_51() -> String:
    var out = String()
    out += "directive @foo on UNION\n\ntype Query {\n  foo: Search\n}\n"
    out += "\nunion Search\n\nextend union Search @foo\n"
    return out^


def _path_52() -> String:
    var out = String()
    out += "diagnostics/0118_input_object_definition_with_missing_values"
    out += ".graphql"
    return out^


def _input_52() -> String:
    var out = String()
    out += "directive @foo on INPUT_OBJECT\ntype Query {\n    foo(id: In"
    out += "): String\n}\n\ninput In\n\nextend input In @foo"
    return out^


def _output_52() -> String:
    var out = String()
    out += "directive @foo on INPUT_OBJECT\n\ntype Query {\n  foo(id: In"
    out += "): String\n}\n\ninput In\n\nextend input In @foo\n"
    return out^


def _path_53() -> String:
    var out = String()
    out += "diagnostics/0119_reserved_names.graphql"
    return out^


def _input_53() -> String:
    var out = String()
    out += "directive @__Prime(__if: Boolean!) on SCHEMA\n\nschema @__Pr"
    out += "ime(__if: true) {\n    query: __MyQuery\n}\n\ntype __MyQuery"
    out += " {\n    __secretField(__heatedArgument: __In): Int\n}\n\ninp"
    out += "ut __In {\n    __amount: __BigInt\n}\n\nscalar __BigInt\n\ne"
    out += "num __Maybe {\n    Yes\n    No\n    __FileNotFound\n}\n"
    return out^


def _output_53() -> String:
    var out = String()
    out += "directive @__Prime(__if: Boolean!) on SCHEMA\n\nschema @__Pr"
    out += "ime(__if: true) {\n  query: __MyQuery\n}\n\ntype __MyQuery {"
    out += "\n  __secretField(__heatedArgument: __In): Int\n}\n\ninput _"
    out += "_In {\n  __amount: __BigInt\n}\n\nscalar __BigInt\n\nenum __"
    out += "Maybe {\n  Yes\n  No\n  __FileNotFound\n}\n"
    return out^


def _path_54() -> String:
    var out = String()
    out += "diagnostics/0129_duplicate_root_operation_types_query_mutati"
    out += "on.graphql"
    return out^


def _input_54() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  mutation: SharedType\n}\n\n"
    out += "type SharedType {\n  field: String\n}\n"
    return out^


def _output_54() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  mutation: SharedType\n}\n\n"
    out += "type SharedType {\n  field: String\n}\n"
    return out^


def _path_55() -> String:
    var out = String()
    out += "diagnostics/0130_duplicate_root_operation_types_query_subscr"
    out += "iption.graphql"
    return out^


def _input_55() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  subscription: SharedType\n}"
    out += "\n\ntype SharedType {\n  field: String\n}\n"
    return out^


def _output_55() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  subscription: SharedType\n}"
    out += "\n\ntype SharedType {\n  field: String\n}\n"
    return out^


def _path_56() -> String:
    var out = String()
    out += "diagnostics/0131_duplicate_root_operation_types_mutation_sub"
    out += "scription.graphql"
    return out^


def _input_56() -> String:
    var out = String()
    out += "schema {\n  query: Query\n  mutation: SharedType\n  subscrip"
    out += "tion: SharedType\n}\n\ntype Query {\n  field: String\n}\n\nt"
    out += "ype SharedType {\n  field: String\n}\n"
    return out^


def _output_56() -> String:
    var out = String()
    out += "schema {\n  query: Query\n  mutation: SharedType\n  subscrip"
    out += "tion: SharedType\n}\n\ntype Query {\n  field: String\n}\n\nt"
    out += "ype SharedType {\n  field: String\n}\n"
    return out^


def _path_57() -> String:
    var out = String()
    out += "ok/0003_schema_definition_with_custom_operation_types.graphq"
    out += "l"
    return out^


def _input_57() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery,\n  subscription: customPe"
    out += "tSubscription\n  mutation: customPetMutation\n}\n\nenum PetT"
    out += "ype {\n  CAT,\n  DOG,\n}\n\ntype customPetQuery {\n  name: S"
    out += "tring,\n  age: Int\n}\n\ntype customPetSubscription {\n  cha"
    out += "ngeInPetHousehold: Result\n}\n\ntype customPetMutation {\n  "
    out += "addPet (name: String!, petType: PetType): Result!\n}\n\ntype"
    out += " Result {\n  id: String\n}\n"
    return out^


def _output_57() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery\n  subscription: customPet"
    out += "Subscription\n  mutation: customPetMutation\n}\n\nenum PetTy"
    out += "pe {\n  CAT\n  DOG\n}\n\ntype customPetQuery {\n  name: Stri"
    out += "ng\n  age: Int\n}\n\ntype customPetSubscription {\n  changeI"
    out += "nPetHousehold: Result\n}\n\ntype customPetMutation {\n  addP"
    out += "et(name: String!, petType: PetType): Result!\n}\n\ntype Resu"
    out += "lt {\n  id: String\n}\n"
    return out^


def _path_58() -> String:
    var out = String()
    out += "ok/0004_schema_with_custom_scalars.graphql"
    return out^


def _input_58() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    return out^


def _output_58() -> String:
    var out = String()
    out += "type Query {\n  website: URL\n  amount: Int\n}\n\nscalar URL"
    out += ' @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n"
    return out^


def _path_59() -> String:
    var out = String()
    out += "ok/0005_schema_with_valid_enum_definitions.graphql"
    return out^


def _input_59() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet,\n  snacks: Snack,\n}\n\nenum Pet {"
    out += "\n    CAT\n    DOG\n    FOX\n}\n\nenum Snack {\n    THRIVE_P"
    out += "ET_FOODS\n    LILYS_KITCHEN\n    ACANA\n}"
    return out^


def _output_59() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet\n  snacks: Snack\n}\n\nenum Pet {\n"
    out += "  CAT\n  DOG\n  FOX\n}\n\nenum Snack {\n  THRIVE_PET_FOODS\n"
    out += "  LILYS_KITCHEN\n  ACANA\n}\n"
    return out^


def _path_60() -> String:
    var out = String()
    out += "ok/0006_schema_with_valid_union.graphql"
    return out^


def _input_60() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Person\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}"
    return out^


def _output_60() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Person\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}\n"
    return out^


def _path_61() -> String:
    var out = String()
    out += "ok/0007_schema_with_interface_definition.graphql"
    return out^


def _input_61() -> String:
    var out = String()
    out += "type Query implements Node {\n    id: ID!\n}\n\ninterface No"
    out += "de {\n  id: ID!\n}\n\ninterface Resource implements Node {\n"
    out += "  id: ID!\n  width: Int\n  height: Int\n}\n\ninterface Image"
    out += " implements Resource & Node {\n  id: ID!\n  width: Int\n  he"
    out += "ight: Int\n  thumbnail: String\n}"
    return out^


def _output_61() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n  height: Int\n}\n\ninterface Image i"
    out += "mplements Resource & Node {\n  id: ID!\n  width: Int\n  heig"
    out += "ht: Int\n  thumbnail: String\n}\n"
    return out^


def _path_62() -> String:
    var out = String()
    out += "ok/0008_schema_with_directive_definition.graphql"
    return out^


def _input_62() -> String:
    var out = String()
    out += "type Query {\n    literature: Book\n}\n\ndirective @delegate"
    out += "Field(name: String!) repeatable on OBJECT | INTERFACE\n\ntyp"
    out += 'e Book @delegateField(name: "pageCount") @delegateField(na'
    out += 'me: "author") {\n  id: ID!\n}'
    return out^


def _output_62() -> String:
    var out = String()
    out += "type Query {\n  literature: Book\n}\n\ndirective @delegateFi"
    out += "eld(name: String!) repeatable on OBJECT | INTERFACE\n\ntype "
    out += 'Book @delegateField(name: "pageCount") @delegateField(name'
    out += ': "author") {\n  id: ID!\n}\n'
    return out^


def _path_63() -> String:
    var out = String()
    out += "ok/0009_schema_with_input_object.graphql"
    return out^


def _input_63() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}"
    return out^


def _output_63() -> String:
    var out = String()
    out += "type Query {\n  website: URL\n  amount: Int\n}\n\nscalar URL"
    out += ' @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}\n"
    return out^


def _path_64() -> String:
    var out = String()
    out += "ok/0014_float_values.graphql"
    return out^


def _input_64() -> String:
    var out = String()
    out += "type Query {\n  name(arg: WithAllKindsOfFloats): String\n}\n"
    out += "\ninput WithAllKindsOfFloats {\n  a_regular_float: Float = 1"
    out += ".2\n  an_integer_float: Float = 1234\n  a_float_that_doesnt_"
    out += "fit_an_int: Float = 9876543210\n  list_of_floats: [Float] = "
    out += "[4, 9876543210, 98765432109876543210]\n}\n"
    return out^


def _output_64() -> String:
    var out = String()
    out += "type Query {\n  name(arg: WithAllKindsOfFloats): String\n}\n"
    out += "\ninput WithAllKindsOfFloats {\n  a_regular_float: Float = 1"
    out += ".2\n  an_integer_float: Float = 1234\n  a_float_that_doesnt_"
    out += "fit_an_int: Float = 9876543210\n  list_of_floats: [Float] = "
    out += "[\n    4,\n    9876543210,\n    98765432109876543210,\n  ]\n"
    out += "}\n"
    return out^


def _path_65() -> String:
    var out = String()
    out += "ok/0015_supergraph.graphql"
    return out^


def _input_65() -> String:
    var out = String()
    out += 'schema\n@core(feature: "https://specs.apollo.dev/core/v0.1'
    out += '"),\n@core(feature: "https://specs.apollo.dev/join/v0.1")'
    out += "\n{\n  query: Query\n  mutation: Mutation\n}\n\ndirective @c"
    out += "ore(feature: String!) repeatable on SCHEMA\ndirective @join_"
    out += "_field(graph: join__Graph, requires: join__FieldSet, provide"
    out += "s: join__FieldSet) on FIELD_DEFINITION\ndirective @join__typ"
    out += "e(graph: join__Graph!, key: join__FieldSet) repeatable on OB"
    out += "JECT | INTERFACE\ndirective @join__owner(graph: join__Graph!"
    out += ") on OBJECT | INTERFACE\ndirective @join__graph(name: String"
    out += "!, url: String!) on ENUM_VALUE\ndirective @stream on FIELD\n"
    out += "directive @transform(from: String!) on FIELD\n\nunion Accoun"
    out += "tType = PasswordAccount | SMSAccount\n\ntype Amazon {\n  ref"
    out += "errer: String\n}\n\nunion Body = Image | Text\n\ntype Book i"
    out += "mplements Product\n@join__owner(graph: BOOKS)\n@join__type(g"
    out += 'raph: BOOKS, key: "isbn")\n@join__type(graph: INVENTORY, k'
    out += 'ey: "isbn")\n@join__type(graph: PRODUCT, key: "isbn")\n@'
    out += 'join__type(graph: REVIEWS, key: "isbn")\n{\n  isbn: String'
    out += "! @join__field(graph: BOOKS)\n  title: String @join__field(g"
    out += "raph: BOOKS)\n  year: Int @join__field(graph: BOOKS)\n  simi"
    out += "larBooks: [Book]! @join__field(graph: BOOKS)\n  metadata: [M"
    out += "etadataOrError] @join__field(graph: BOOKS)\n  inStock: Boole"
    out += "an @join__field(graph: INVENTORY)\n  isCheckedOut: Boolean @"
    out += "join__field(graph: INVENTORY)\n  upc: String! @join__field(g"
    out += "raph: PRODUCT)\n  sku: String! @join__field(graph: PRODUCT)"
    out += '\n  name(delimeter: String = " "): String @join__field(gra'
    out += 'ph: PRODUCT, requires: "title year")\n  price: String @joi'
    out += "n__field(graph: PRODUCT)\n  details: ProductDetailsBook @joi"
    out += "n__field(graph: PRODUCT)\n  reviews: [Review] @join__field(g"
    out += "raph: REVIEWS)\n  relatedReviews: [Review!]! @join__field(gr"
    out += 'aph: REVIEWS, requires: "similarBooks{isbn}")\n}\n\nunion '
    out += "Brand = Ikea | Amazon\n\ntype Car implements Vehicle\n@join_"
    out += '_owner(graph: PRODUCT)\n@join__type(graph: PRODUCT, key: "i'
    out += 'd")\n@join__type(graph: REVIEWS, key: "id")\n{\n  id: Str'
    out += "ing! @join__field(graph: PRODUCT)\n  description: String @jo"
    out += "in__field(graph: PRODUCT)\n  price: String @join__field(grap"
    out += "h: PRODUCT)\n  retailPrice: String @join__field(graph: REVIE"
    out += 'WS, requires: "price")\n}\n\ntype Error {\n  code: Int\n  '
    out += "message: String\n}\n\ntype Furniture implements Product\n@jo"
    out += "in__owner(graph: PRODUCT)\n@join__type(graph: PRODUCT, key: "
    out += '"upc")\n@join__type(graph: PRODUCT, key: "sku")\n@join__'
    out += 'type(graph: INVENTORY, key: "sku")\n@join__type(graph: REV'
    out += 'IEWS, key: "upc")\n{\n  upc: String! @join__field(graph: P'
    out += "RODUCT)\n  sku: String! @join__field(graph: PRODUCT)\n  name"
    out += ": String @join__field(graph: PRODUCT)\n  price: String @join"
    out += "__field(graph: PRODUCT)\n  brand: Brand @join__field(graph: "
    out += "PRODUCT)\n  metadata: [MetadataOrError] @join__field(graph: "
    out += "PRODUCT)\n  details: ProductDetailsFurniture @join__field(gr"
    out += "aph: PRODUCT)\n  inStock: Boolean @join__field(graph: INVENT"
    out += "ORY)\n  isHeavy: Boolean @join__field(graph: INVENTORY)\n  r"
    out += "eviews: [Review] @join__field(graph: REVIEWS)\n}\n\ntype Ike"
    out += "a {\n  asile: Int\n}\n\ntype Image implements NamedObject {"
    out += "\n  name: String!\n  attributes: ImageAttributes!\n}\n\ntype"
    out += " ImageAttributes {\n  url: String!\n}\n\nscalar join__FieldS"
    out += 'et @specifiedBy(url: "https://spec.graphql.org/")\n\nenum '
    out += 'join__Graph {\nACCOUNTS @join__graph(name: "accounts" url:'
    out += ' "")\nBOOKS @join__graph(name: "books" url: "")\nDOCUM'
    out += 'ENTS @join__graph(name: "documents" url: "")\nINVENTORY '
    out += '@join__graph(name: "inventory" url: "")\nPRODUCT @join__'
    out += 'graph(name: "product" url: "")\nREVIEWS @join__graph(nam'
    out += 'e: "reviews" url: "")\n}\n\ntype KeyValue {\n  key: Stri'
    out += "ng!\n  value: String!\n}\n\ntype Library\n@join__owner(graph"
    out += ': BOOKS)\n@join__type(graph: BOOKS, key: "id")\n@join__typ'
    out += 'e(graph: ACCOUNTS, key: "id")\n{\n  id: ID! @join__field(g'
    out += "raph: BOOKS)\n  name: String @join__field(graph: BOOKS)\n  u"
    out += "serAccount(id: ID! = 1): User @join__field(graph: ACCOUNTS, "
    out += 'requires: "name")\n}\n\nunion MetadataOrError = KeyValue |'
    out += " Error\n\ntype Mutation {\n  login(username: String!, passwo"
    out += "rd: String!): User @join__field(graph: ACCOUNTS)\n  reviewPr"
    out += "oduct(upc: String!, body: String!): Product @join__field(gra"
    out += "ph: REVIEWS)\n  updateReview(review: UpdateReviewInput!): Re"
    out += "view @join__field(graph: REVIEWS)\n  deleteReview(id: ID!): "
    out += "Boolean @join__field(graph: REVIEWS)\n}\n\ntype Name {\n  fi"
    out += "rst: String\n  last: String\n}\n\ninterface NamedObject {\n "
    out += " name: String!\n}\n\ntype PasswordAccount\n@join__owner(grap"
    out += 'h: ACCOUNTS)\n@join__type(graph: ACCOUNTS, key: "email")\n'
    out += "{\n  email: String! @join__field(graph: ACCOUNTS)\n}\n\ninte"
    out += "rface Product {\n  upc: String!\n  sku: String!\n  name: Str"
    out += "ing\n  price: String\n  details: ProductDetails\n  inStock: "
    out += "Boolean\n  reviews: [Review]\n}\n\ninterface ProductDetails "
    out += "{\n  country: String\n}\n\ntype ProductDetailsBook implement"
    out += "s ProductDetails {\n  country: String\n  pages: Int\n}\n\nty"
    out += "pe ProductDetailsFurniture implements ProductDetails {\n  co"
    out += "untry: String\n  color: String\n}\n\ntype Query {\n  user(id"
    out += ": ID!): User @join__field(graph: ACCOUNTS)\n  me: User @join"
    out += "__field(graph: ACCOUNTS)\n  book(isbn: String!): Book @join_"
    out += "_field(graph: BOOKS)\n  books: [Book] @join__field(graph: BO"
    out += "OKS)\n  library(id: ID!): Library @join__field(graph: BOOKS)"
    out += "\n  body: Body! @join__field(graph: DOCUMENTS)\n  product(up"
    out += "c: String!): Product @join__field(graph: PRODUCT)\n  vehicle"
    out += "(id: String!): Vehicle @join__field(graph: PRODUCT)\n  topPr"
    out += "oducts(first: Int = 5): [Product] @join__field(graph: PRODUC"
    out += "T)\n  topCars(first: Int = 5): [Car] @join__field(graph: PRO"
    out += "DUCT)\n  topReviews(first: Int = 5): [Review] @join__field(g"
    out += "raph: REVIEWS)\n}\n\ntype Review\n@join__owner(graph: REVIEW"
    out += 'S)\n@join__type(graph: REVIEWS, key: "id")\n{\n  id: ID! @'
    out += "join__field(graph: REVIEWS)\n  body(format: Boolean = false)"
    out += ": String @join__field(graph: REVIEWS)\n  author: User @join_"
    out += '_field(graph: REVIEWS, provides: "username")\n  product: P'
    out += "roduct @join__field(graph: REVIEWS)\n  metadata: [MetadataOr"
    out += "Error] @join__field(graph: REVIEWS)\n}\n\ntype SMSAccount\n@"
    out += "join__owner(graph: ACCOUNTS)\n@join__type(graph: ACCOUNTS, k"
    out += 'ey: "number")\n{\n  number: String @join__field(graph: ACC'
    out += "OUNTS)\n}\n\ntype Text implements NamedObject {\n  name: Str"
    out += "ing!\n  attributes: TextAttributes!\n}\n\ntype TextAttribute"
    out += "s {\n  bold: Boolean\n  text: String\n}\n\nunion Thing = Car"
    out += " | Ikea\n\ninput UpdateReviewInput {\n  id: ID!\n  body: Str"
    out += "ing\n}\n\ntype User\n@join__owner(graph: ACCOUNTS)\n@join__t"
    out += 'ype(graph: ACCOUNTS, key: "id")\n@join__type(graph: ACCOUN'
    out += 'TS, key: "username name{first last}")\n@join__type(graph: '
    out += 'INVENTORY, key: "id")\n@join__type(graph: PRODUCT, key: "'
    out += 'id")\n@join__type(graph: REVIEWS, key: "id")\n{\n  id: ID'
    out += "! @join__field(graph: ACCOUNTS)\n  name: Name @join__field(g"
    out += "raph: ACCOUNTS)\n  username: String @join__field(graph: ACCO"
    out += "UNTS)\n  birthDate(locale: String): String @join__field(grap"
    out += "h: ACCOUNTS)\n  account: AccountType @join__field(graph: ACC"
    out += "OUNTS)\n  metadata: [UserMetadata] @join__field(graph: ACCOU"
    out += "NTS)\n  goodDescription: Boolean @join__field(graph: INVENTO"
    out += 'RY, requires: "metadata{description}")\n  vehicle: Vehicle'
    out += " @join__field(graph: PRODUCT)\n  thing: Thing @join__field(g"
    out += "raph: PRODUCT)\n  reviews: [Review] @join__field(graph: REVI"
    out += "EWS)\n  numberOfReviews: Int! @join__field(graph: REVIEWS)\n"
    out += "  goodAddress: Boolean @join__field(graph: REVIEWS, requires"
    out += ': "metadata{address}")\n}\n\ntype UserMetadata {\n  name: '
    out += "String\n  address: String\n  description: String\n}\n\ntype "
    out += "Van implements Vehicle\n@join__owner(graph: PRODUCT)\n@join_"
    out += '_type(graph: PRODUCT, key: "id")\n@join__type(graph: REVIE'
    out += 'WS, key: "id")\n{\n  id: String! @join__field(graph: PRODU'
    out += "CT)\n  description: String @join__field(graph: PRODUCT)\n  p"
    out += "rice: String @join__field(graph: PRODUCT)\n  retailPrice: St"
    out += 'ring @join__field(graph: REVIEWS, requires: "price")\n}\n'
    out += "\ninterface Vehicle {\n  id: String!\n  description: String"
    out += "\n  price: String\n  retailPrice: String\n}"
    return out^


def _output_65() -> String:
    var out = String()
    out += 'schema @core(feature: "https://specs.apollo.dev/core/v0.1"'
    out += ') @core(feature: "https://specs.apollo.dev/join/v0.1") {\n'
    out += "  query: Query\n  mutation: Mutation\n}\n\ndirective @core(f"
    out += "eature: String!) repeatable on SCHEMA\n\ndirective @join__fi"
    out += "eld(graph: join__Graph, requires: join__FieldSet, provides: "
    out += "join__FieldSet) on FIELD_DEFINITION\n\ndirective @join__type"
    out += "(graph: join__Graph!, key: join__FieldSet) repeatable on OBJ"
    out += "ECT | INTERFACE\n\ndirective @join__owner(graph: join__Graph"
    out += "!) on OBJECT | INTERFACE\n\ndirective @join__graph(name: Str"
    out += "ing!, url: String!) on ENUM_VALUE\n\ndirective @stream on FI"
    out += "ELD\n\ndirective @transform(from: String!) on FIELD\n\nunion"
    out += " AccountType = PasswordAccount | SMSAccount\n\ntype Amazon {"
    out += "\n  referrer: String\n}\n\nunion Body = Image | Text\n\ntype"
    out += " Book implements Product @join__owner(graph: BOOKS) @join__t"
    out += 'ype(graph: BOOKS, key: "isbn") @join__type(graph: INVENTOR'
    out += 'Y, key: "isbn") @join__type(graph: PRODUCT, key: "isbn")'
    out += ' @join__type(graph: REVIEWS, key: "isbn") {\n  isbn: Strin'
    out += "g! @join__field(graph: BOOKS)\n  title: String @join__field("
    out += "graph: BOOKS)\n  year: Int @join__field(graph: BOOKS)\n  sim"
    out += "ilarBooks: [Book]! @join__field(graph: BOOKS)\n  metadata: ["
    out += "MetadataOrError] @join__field(graph: BOOKS)\n  inStock: Bool"
    out += "ean @join__field(graph: INVENTORY)\n  isCheckedOut: Boolean "
    out += "@join__field(graph: INVENTORY)\n  upc: String! @join__field("
    out += "graph: PRODUCT)\n  sku: String! @join__field(graph: PRODUCT)"
    out += '\n  name(delimeter: String = " "): String @join__field(gra'
    out += 'ph: PRODUCT, requires: "title year")\n  price: String @joi'
    out += "n__field(graph: PRODUCT)\n  details: ProductDetailsBook @joi"
    out += "n__field(graph: PRODUCT)\n  reviews: [Review] @join__field(g"
    out += "raph: REVIEWS)\n  relatedReviews: [Review!]! @join__field(gr"
    out += 'aph: REVIEWS, requires: "similarBooks{isbn}")\n}\n\nunion '
    out += "Brand = Ikea | Amazon\n\ntype Car implements Vehicle @join__"
    out += 'owner(graph: PRODUCT) @join__type(graph: PRODUCT, key: "id'
    out += '") @join__type(graph: REVIEWS, key: "id") {\n  id: String'
    out += "! @join__field(graph: PRODUCT)\n  description: String @join_"
    out += "_field(graph: PRODUCT)\n  price: String @join__field(graph: "
    out += "PRODUCT)\n  retailPrice: String @join__field(graph: REVIEWS,"
    out += ' requires: "price")\n}\n\ntype Error {\n  code: Int\n  mes'
    out += "sage: String\n}\n\ntype Furniture implements Product @join__"
    out += 'owner(graph: PRODUCT) @join__type(graph: PRODUCT, key: "upc'
    out += '") @join__type(graph: PRODUCT, key: "sku") @join__type(gr'
    out += 'aph: INVENTORY, key: "sku") @join__type(graph: REVIEWS, ke'
    out += 'y: "upc") {\n  upc: String! @join__field(graph: PRODUCT)\n'
    out += "  sku: String! @join__field(graph: PRODUCT)\n  name: String "
    out += "@join__field(graph: PRODUCT)\n  price: String @join__field(g"
    out += "raph: PRODUCT)\n  brand: Brand @join__field(graph: PRODUCT)"
    out += "\n  metadata: [MetadataOrError] @join__field(graph: PRODUCT)"
    out += "\n  details: ProductDetailsFurniture @join__field(graph: PRO"
    out += "DUCT)\n  inStock: Boolean @join__field(graph: INVENTORY)\n  "
    out += "isHeavy: Boolean @join__field(graph: INVENTORY)\n  reviews: "
    out += "[Review] @join__field(graph: REVIEWS)\n}\n\ntype Ikea {\n  a"
    out += "sile: Int\n}\n\ntype Image implements NamedObject {\n  name:"
    out += " String!\n  attributes: ImageAttributes!\n}\n\ntype ImageAtt"
    out += "ributes {\n  url: String!\n}\n\nscalar join__FieldSet @speci"
    out += 'fiedBy(url: "https://spec.graphql.org/")\n\nenum join__Gra'
    out += 'ph {\n  ACCOUNTS @join__graph(name: "accounts", url: "")'
    out += '\n  BOOKS @join__graph(name: "books", url: "")\n  DOCUME'
    out += 'NTS @join__graph(name: "documents", url: "")\n  INVENTOR'
    out += 'Y @join__graph(name: "inventory", url: "")\n  PRODUCT @j'
    out += 'oin__graph(name: "product", url: "")\n  REVIEWS @join__g'
    out += 'raph(name: "reviews", url: "")\n}\n\ntype KeyValue {\n  '
    out += "key: String!\n  value: String!\n}\n\ntype Library @join__own"
    out += 'er(graph: BOOKS) @join__type(graph: BOOKS, key: "id") @joi'
    out += 'n__type(graph: ACCOUNTS, key: "id") {\n  id: ID! @join__fi'
    out += "eld(graph: BOOKS)\n  name: String @join__field(graph: BOOKS)"
    out += "\n  userAccount(id: ID! = 1): User @join__field(graph: ACCOU"
    out += 'NTS, requires: "name")\n}\n\nunion MetadataOrError = KeyVa'
    out += "lue | Error\n\ntype Mutation {\n  login(username: String!, p"
    out += "assword: String!): User @join__field(graph: ACCOUNTS)\n  rev"
    out += "iewProduct(upc: String!, body: String!): Product @join__fiel"
    out += "d(graph: REVIEWS)\n  updateReview(review: UpdateReviewInput!"
    out += "): Review @join__field(graph: REVIEWS)\n  deleteReview(id: I"
    out += "D!): Boolean @join__field(graph: REVIEWS)\n}\n\ntype Name {"
    out += "\n  first: String\n  last: String\n}\n\ninterface NamedObjec"
    out += "t {\n  name: String!\n}\n\ntype PasswordAccount @join__owner"
    out += '(graph: ACCOUNTS) @join__type(graph: ACCOUNTS, key: "email'
    out += '") {\n  email: String! @join__field(graph: ACCOUNTS)\n}\n\n'
    out += "interface Product {\n  upc: String!\n  sku: String!\n  name:"
    out += " String\n  price: String\n  details: ProductDetails\n  inSto"
    out += "ck: Boolean\n  reviews: [Review]\n}\n\ninterface ProductDeta"
    out += "ils {\n  country: String\n}\n\ntype ProductDetailsBook imple"
    out += "ments ProductDetails {\n  country: String\n  pages: Int\n}\n"
    out += "\ntype ProductDetailsFurniture implements ProductDetails {\n"
    out += "  country: String\n  color: String\n}\n\ntype Query {\n  use"
    out += "r(id: ID!): User @join__field(graph: ACCOUNTS)\n  me: User @"
    out += "join__field(graph: ACCOUNTS)\n  book(isbn: String!): Book @j"
    out += "oin__field(graph: BOOKS)\n  books: [Book] @join__field(graph"
    out += ": BOOKS)\n  library(id: ID!): Library @join__field(graph: BO"
    out += "OKS)\n  body: Body! @join__field(graph: DOCUMENTS)\n  produc"
    out += "t(upc: String!): Product @join__field(graph: PRODUCT)\n  veh"
    out += "icle(id: String!): Vehicle @join__field(graph: PRODUCT)\n  t"
    out += "opProducts(first: Int = 5): [Product] @join__field(graph: PR"
    out += "ODUCT)\n  topCars(first: Int = 5): [Car] @join__field(graph:"
    out += " PRODUCT)\n  topReviews(first: Int = 5): [Review] @join__fie"
    out += "ld(graph: REVIEWS)\n}\n\ntype Review @join__owner(graph: REV"
    out += 'IEWS) @join__type(graph: REVIEWS, key: "id") {\n  id: ID! '
    out += "@join__field(graph: REVIEWS)\n  body(format: Boolean = false"
    out += "): String @join__field(graph: REVIEWS)\n  author: User @join"
    out += '__field(graph: REVIEWS, provides: "username")\n  product: '
    out += "Product @join__field(graph: REVIEWS)\n  metadata: [MetadataO"
    out += "rError] @join__field(graph: REVIEWS)\n}\n\ntype SMSAccount @"
    out += "join__owner(graph: ACCOUNTS) @join__type(graph: ACCOUNTS, ke"
    out += 'y: "number") {\n  number: String @join__field(graph: ACCOU'
    out += "NTS)\n}\n\ntype Text implements NamedObject {\n  name: Strin"
    out += "g!\n  attributes: TextAttributes!\n}\n\ntype TextAttributes "
    out += "{\n  bold: Boolean\n  text: String\n}\n\nunion Thing = Car |"
    out += " Ikea\n\ninput UpdateReviewInput {\n  id: ID!\n  body: Strin"
    out += "g\n}\n\ntype User @join__owner(graph: ACCOUNTS) @join__type("
    out += 'graph: ACCOUNTS, key: "id") @join__type(graph: ACCOUNTS, k'
    out += 'ey: "username name{first last}") @join__type(graph: INVENT'
    out += 'ORY, key: "id") @join__type(graph: PRODUCT, key: "id") @'
    out += 'join__type(graph: REVIEWS, key: "id") {\n  id: ID! @join__'
    out += "field(graph: ACCOUNTS)\n  name: Name @join__field(graph: ACC"
    out += "OUNTS)\n  username: String @join__field(graph: ACCOUNTS)\n  "
    out += "birthDate(locale: String): String @join__field(graph: ACCOUN"
    out += "TS)\n  account: AccountType @join__field(graph: ACCOUNTS)\n "
    out += " metadata: [UserMetadata] @join__field(graph: ACCOUNTS)\n  g"
    out += "oodDescription: Boolean @join__field(graph: INVENTORY, requi"
    out += 'res: "metadata{description}")\n  vehicle: Vehicle @join__f'
    out += "ield(graph: PRODUCT)\n  thing: Thing @join__field(graph: PRO"
    out += "DUCT)\n  reviews: [Review] @join__field(graph: REVIEWS)\n  n"
    out += "umberOfReviews: Int! @join__field(graph: REVIEWS)\n  goodAdd"
    out += 'ress: Boolean @join__field(graph: REVIEWS, requires: "metad'
    out += 'ata{address}")\n}\n\ntype UserMetadata {\n  name: String\n '
    out += " address: String\n  description: String\n}\n\ntype Van imple"
    out += "ments Vehicle @join__owner(graph: PRODUCT) @join__type(graph"
    out += ': PRODUCT, key: "id") @join__type(graph: REVIEWS, key: "i'
    out += 'd") {\n  id: String! @join__field(graph: PRODUCT)\n  descri'
    out += "ption: String @join__field(graph: PRODUCT)\n  price: String "
    out += "@join__field(graph: PRODUCT)\n  retailPrice: String @join__f"
    out += 'ield(graph: REVIEWS, requires: "price")\n}\n\ninterface Ve'
    out += "hicle {\n  id: String!\n  description: String\n  price: Stri"
    out += "ng\n  retailPrice: String\n}\n"
    return out^


def _path_66() -> String:
    var out = String()
    out += "ok/0019_extensions.graphql"
    return out^


def _input_66() -> String:
    var out = String()
    out += "scalar Scalar\n\ntype Object implements Intf {\n  field: Int"
    out += ",\n}\n\ninterface Intf {\n  field: Int,\n}\n\ninput Input {"
    out += "\n  field: Enum,\n}\nenum Enum {\n  MEMBER,\n}\n\nextend sca"
    out += 'lar Scalar @specifiedBy(url: "https://apollographql.com")'
    out += "\nextend interface Intf {\n  field2: Scalar,\n}\nextend type"
    out += " Object {\n  field2: Scalar,\n}\nextend enum Enum {\n  MEMBE"
    out += "R_2,\n}\nextend input Input {\n  field2: Int,\n}\n\ntype Que"
    out += "ry {\n  object: Object,\n}\n"
    return out^


def _output_66() -> String:
    var out = String()
    out += "scalar Scalar\n\ntype Object implements Intf {\n  field: Int"
    out += "\n}\n\ninterface Intf {\n  field: Int\n}\n\ninput Input {\n "
    out += " field: Enum\n}\n\nenum Enum {\n  MEMBER\n}\n\nextend scalar"
    out += ' Scalar @specifiedBy(url: "https://apollographql.com")\n\n'
    out += "extend interface Intf {\n  field2: Scalar\n}\n\nextend type "
    out += "Object {\n  field2: Scalar\n}\n\nextend enum Enum {\n  MEMBE"
    out += "R_2\n}\n\nextend input Input {\n  field2: Int\n}\n\ntype Que"
    out += "ry {\n  object: Object\n}\n"
    return out^


def _path_67() -> String:
    var out = String()
    out += "ok/0030_cyclical_nullable_input_objects.graphql"
    return out^


def _input_67() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    example(arg: First): Int"
    out += "\n}\n\ninput First {\n  second: Second\n  value: String\n}\n"
    out += "\ninput Second {\n  third: [Third!]!\n  value: String\n}\n\n"
    out += "input Third {\n  fourth: Fourth\n  value: String\n}\n\ninput"
    out += " Fourth {\n  first: First\n}"
    return out^


def _output_67() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  example(arg: First): Int\n}"
    out += "\n\ninput First {\n  second: Second\n  value: String\n}\n\ni"
    out += "nput Second {\n  third: [Third!]!\n  value: String\n}\n\ninp"
    out += "ut Third {\n  fourth: Fourth\n  value: String\n}\n\ninput Fo"
    out += "urth {\n  first: First\n}\n"
    return out^


def _path_68() -> String:
    var out = String()
    out += "ok/0034_built_in_directive_redefinition.graphql"
    return out^


def _input_68() -> String:
    var out = String()
    out += 'schema\n  @deprecated(\n    reason: """\n    The person w'
    out += "ho got promoted by shipping this product has moved on to ano"
    out += "ther team.\n    The service will shut down next month.\n    "
    out += '"""\n  ) {\n  query: Query\n}\n\ntype Query {\n  importan'
    out += "tData: Int\n}\n\ndirective @deprecated(\n  reason: String = "
    out += '"No longer supported"\n) on FIELD_DEFINITION | ARGUMENT_DE'
    out += "FINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE | SCHEMA\n"
    return out^


def _output_68() -> String:
    var out = String()
    out += 'schema @deprecated(reason: "The person who got promoted by '
    out += "shipping this product has moved on to another team.\\nThe se"
    out += 'rvice will shut down next month.") {\n  query: Query\n}\n\n'
    out += "type Query {\n  importantData: Int\n}\n\ndirective @deprecat"
    out += 'ed(reason: String = "No longer supported") on FIELD_DEFINI'
    out += "TION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_V"
    out += "ALUE | SCHEMA\n"
    return out^


def _path_69() -> String:
    var out = String()
    out += "ok/0035_implicit_schema_definition_with_query_type.graphql"
    return out^


def _input_69() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}"
    return out^


def _output_69() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n"
    return out^


def _path_70() -> String:
    var out = String()
    out += "ok/0036_implicit_schema_definition_with_several_default_type"
    out += "s.graphql"
    return out^


def _input_70() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\ntype Mutation {\n   add"
    out += "(name: String!): Result!\n}\n\ntype Result {\n  id: String\n"
    out += "}\n\n"
    return out^


def _output_70() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\ntype Mutation {\n  add(na"
    out += "me: String!): Result!\n}\n\ntype Result {\n  id: String\n}\n"
    return out^


def _path_71() -> String:
    var out = String()
    out += "ok/0037_implicit_schema_extension_with_directive.graphql"
    return out^


def _input_71() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\nextend schema @dir\ndir"
    out += "ective @dir on SCHEMA"
    return out^


def _output_71() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\nextend schema @dir\n\ndir"
    out += "ective @dir on SCHEMA\n"
    return out^


def _path_72() -> String:
    var out = String()
    out += "ok/0039_string_literals.graphql"
    return out^


def _input_72() -> String:
    var out = String()
    out += 'type Query {\n  "LF: a\\nb"\n  f1: Int\n\n  "CRLF: a\\r\\'
    out += 'nb"\n  f2: Int\n\n  """\n    a\n\n    b\n  \n\n  """'
    out += '\n  f3: Int\n\n  "a \\"b\\" c"\n  f4: Int\n\n  """a '
    out += '\\"""b\\""" c"""\n  f5: Int\n\n  """\n  regex: '
    out += '\\d+\n  """\n  f6: Int\n\n  "\\nLeading empty line to pr'
    out += 'eserve"\n  f7: Int\n\n  " \\nLeading whitespace-only line '
    out += 'to preserve"\n  f8: Int\n\n  "Trailing empty line to prese'
    out += 'rve\\n"\n  f9: Int\n\n  "Trailing whitespace-only line to '
    out += 'preserve\\n\\t"\n  f10: Int\n\n  f11(arg: String = "a\\nb'
    out += '"): Int\n\n  f12(arg: String = "a \\"b\\" c"): Int\n\n '
    out += ' f13(arg: String = "regex: \\\\d+"): Int\n\n  "Trailing b'
    out += 'ackslash \\\\"\n  f14: Int\n\n  "Trailing quote\\""\n  f'
    out += '15: Int\n\n  "   Leading whitespace on a single line to pre'
    out += 'serve"\n  f16: Int\n\n  "   Leading whitespace in multi-li'
    out += "ne string to preserve\\nNo leading whitespace on second line"
    out += '"\n  f17: Int\n\n  "\\n   Leading empty line + indent to p'
    out += 'reserve"\n  f18: Int\n\n  "When serialized as a block stri'
    out += 'ng, \\\\\\"\\"\\" outputs \\\\ in front of the escaped tr'
    out += 'iple quote"\n  f19: Int\n}\n'
    return out^


def _output_72() -> String:
    var out = String()
    out += 'type Query {\n  """\n  LF: a\n  b\n  """\n  f1: Int\n '
    out += ' "CRLF: a\\r\\nb"\n  f2: Int\n  """\n  a\n\n  b\n  ""'
    out += '"\n  f3: Int\n  """a "b" c"""\n  f4: Int\n  """a'
    out += ' \\"""b\\""" c"""\n  f5: Int\n  """regex: \\d+"'
    out += '""\n  f6: Int\n  "\\nLeading empty line to preserve"\n  '
    out += 'f7: Int\n  " \\nLeading whitespace-only line to preserve"'
    out += '\n  f8: Int\n  "Trailing empty line to preserve\\n"\n  f9:'
    out += ' Int\n  "Trailing whitespace-only line to preserve\\n\t"\n'
    out += '  f10: Int\n  f11(arg: String = "a\\nb"): Int\n  f12(arg: '
    out += 'String = "a \\"b\\" c"): Int\n  f13(arg: String = "rege'
    out += 'x: \\\\d+"): Int\n  """\n  Trailing backslash \\\n  ""'
    out += '"\n  f14: Int\n  """\n  Trailing quote"\n  """\n  f1'
    out += '5: Int\n  "   Leading whitespace on a single line to preser'
    out += 've"\n  f16: Int\n  """\n     Leading whitespace in multi'
    out += "-line string to preserve\n  No leading whitespace on second "
    out += 'line\n  """\n  f17: Int\n  "\\n   Leading empty line + i'
    out += 'ndent to preserve"\n  f18: Int\n  """\n  When serialized'
    out += ' as a block string, \\\\""" outputs \\ in front of the es'
    out += 'caped triple quote\n  """\n  f19: Int\n}\n'
    return out^


def _path_73() -> String:
    var out = String()
    out += "ok/0115_interface_definition_with_extension_defines_field.gr"
    out += "aphql"
    return out^


def _input_73() -> String:
    var out = String()
    out += "type Query {\n    foo: Node\n}\n\ninterface Node\n\nextend i"
    out += "nterface Node {\n    bar: String\n}\n"
    return out^


def _output_73() -> String:
    var out = String()
    out += "type Query {\n  foo: Node\n}\n\ninterface Node\n\nextend int"
    out += "erface Node {\n  bar: String\n}\n"
    return out^


def serializer_cases() -> List[String]:
    """Return the path of each case, from `input/`."""
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
    return out^


def serializer_input(index: Int) -> String:
    """Return the input document of a case."""
    if index == 0:
        return _input_0()
    if index == 1:
        return _input_1()
    if index == 2:
        return _input_2()
    if index == 3:
        return _input_3()
    if index == 4:
        return _input_4()
    if index == 5:
        return _input_5()
    if index == 6:
        return _input_6()
    if index == 7:
        return _input_7()
    if index == 8:
        return _input_8()
    if index == 9:
        return _input_9()
    if index == 10:
        return _input_10()
    if index == 11:
        return _input_11()
    if index == 12:
        return _input_12()
    if index == 13:
        return _input_13()
    if index == 14:
        return _input_14()
    if index == 15:
        return _input_15()
    if index == 16:
        return _input_16()
    if index == 17:
        return _input_17()
    if index == 18:
        return _input_18()
    if index == 19:
        return _input_19()
    if index == 20:
        return _input_20()
    if index == 21:
        return _input_21()
    if index == 22:
        return _input_22()
    if index == 23:
        return _input_23()
    if index == 24:
        return _input_24()
    if index == 25:
        return _input_25()
    if index == 26:
        return _input_26()
    if index == 27:
        return _input_27()
    if index == 28:
        return _input_28()
    if index == 29:
        return _input_29()
    if index == 30:
        return _input_30()
    if index == 31:
        return _input_31()
    if index == 32:
        return _input_32()
    if index == 33:
        return _input_33()
    if index == 34:
        return _input_34()
    if index == 35:
        return _input_35()
    if index == 36:
        return _input_36()
    if index == 37:
        return _input_37()
    if index == 38:
        return _input_38()
    if index == 39:
        return _input_39()
    if index == 40:
        return _input_40()
    if index == 41:
        return _input_41()
    if index == 42:
        return _input_42()
    if index == 43:
        return _input_43()
    if index == 44:
        return _input_44()
    if index == 45:
        return _input_45()
    if index == 46:
        return _input_46()
    if index == 47:
        return _input_47()
    if index == 48:
        return _input_48()
    if index == 49:
        return _input_49()
    if index == 50:
        return _input_50()
    if index == 51:
        return _input_51()
    if index == 52:
        return _input_52()
    if index == 53:
        return _input_53()
    if index == 54:
        return _input_54()
    if index == 55:
        return _input_55()
    if index == 56:
        return _input_56()
    if index == 57:
        return _input_57()
    if index == 58:
        return _input_58()
    if index == 59:
        return _input_59()
    if index == 60:
        return _input_60()
    if index == 61:
        return _input_61()
    if index == 62:
        return _input_62()
    if index == 63:
        return _input_63()
    if index == 64:
        return _input_64()
    if index == 65:
        return _input_65()
    if index == 66:
        return _input_66()
    if index == 67:
        return _input_67()
    if index == 68:
        return _input_68()
    if index == 69:
        return _input_69()
    if index == 70:
        return _input_70()
    if index == 71:
        return _input_71()
    if index == 72:
        return _input_72()
    if index == 73:
        return _input_73()
    return ""


def serializer_output(index: Int) -> String:
    """Return the expected output of a case."""
    if index == 0:
        return _output_0()
    if index == 1:
        return _output_1()
    if index == 2:
        return _output_2()
    if index == 3:
        return _output_3()
    if index == 4:
        return _output_4()
    if index == 5:
        return _output_5()
    if index == 6:
        return _output_6()
    if index == 7:
        return _output_7()
    if index == 8:
        return _output_8()
    if index == 9:
        return _output_9()
    if index == 10:
        return _output_10()
    if index == 11:
        return _output_11()
    if index == 12:
        return _output_12()
    if index == 13:
        return _output_13()
    if index == 14:
        return _output_14()
    if index == 15:
        return _output_15()
    if index == 16:
        return _output_16()
    if index == 17:
        return _output_17()
    if index == 18:
        return _output_18()
    if index == 19:
        return _output_19()
    if index == 20:
        return _output_20()
    if index == 21:
        return _output_21()
    if index == 22:
        return _output_22()
    if index == 23:
        return _output_23()
    if index == 24:
        return _output_24()
    if index == 25:
        return _output_25()
    if index == 26:
        return _output_26()
    if index == 27:
        return _output_27()
    if index == 28:
        return _output_28()
    if index == 29:
        return _output_29()
    if index == 30:
        return _output_30()
    if index == 31:
        return _output_31()
    if index == 32:
        return _output_32()
    if index == 33:
        return _output_33()
    if index == 34:
        return _output_34()
    if index == 35:
        return _output_35()
    if index == 36:
        return _output_36()
    if index == 37:
        return _output_37()
    if index == 38:
        return _output_38()
    if index == 39:
        return _output_39()
    if index == 40:
        return _output_40()
    if index == 41:
        return _output_41()
    if index == 42:
        return _output_42()
    if index == 43:
        return _output_43()
    if index == 44:
        return _output_44()
    if index == 45:
        return _output_45()
    if index == 46:
        return _output_46()
    if index == 47:
        return _output_47()
    if index == 48:
        return _output_48()
    if index == 49:
        return _output_49()
    if index == 50:
        return _output_50()
    if index == 51:
        return _output_51()
    if index == 52:
        return _output_52()
    if index == 53:
        return _output_53()
    if index == 54:
        return _output_54()
    if index == 55:
        return _output_55()
    if index == 56:
        return _output_56()
    if index == 57:
        return _output_57()
    if index == 58:
        return _output_58()
    if index == 59:
        return _output_59()
    if index == 60:
        return _output_60()
    if index == 61:
        return _output_61()
    if index == 62:
        return _output_62()
    if index == 63:
        return _output_63()
    if index == 64:
        return _output_64()
    if index == 65:
        return _output_65()
    if index == 66:
        return _output_66()
    if index == 67:
        return _output_67()
    if index == 68:
        return _output_68()
    if index == 69:
        return _output_69()
    if index == 70:
        return _output_70()
    if index == 71:
        return _output_71()
    if index == 72:
        return _output_72()
    if index == 73:
        return _output_73()
    return ""
