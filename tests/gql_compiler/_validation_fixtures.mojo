# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The files of `validation_fixtures/`, written by `_embed_validation.mojo`.
Do not edit."""


def _path_0() -> String:
    var out = String()
    out += "diagnostics/0001_duplicate_operatoin_names.graphql"
    return out^


def _input_0() -> String:
    var out = String()
    out += "query getName {\n  cat\n}\n\nquery getName {\n  cat\n}\n\nty"
    out += "pe Query {\n  cat: String\n}"
    return out^


def _expected_0() -> String:
    var out = String()
    out += "Error: the operation `getName` is defined multiple times in "
    out += "the document\n╭─[ 0001_duplicate_operatoin_names.graphql"
    out += ":5:7 ]\n"
    return out^


def _path_1() -> String:
    var out = String()
    out += "diagnostics/0002_multiple_anonymous_operations.graphql"
    return out^


def _input_1() -> String:
    var out = String()
    out += 'query {\n  cat\n}\n\nmutation {\n  addPet(name: "Example")'
    out += " {\n    response\n  }\n}\n\ntype Query {\n  cat: String\n}\n"
    out += "\ntype Mutation {\n  addPet (name: String!, petType: PetType"
    out += "): Result!\n}\n\nenum PetType {\n  CAT\n  DOG\n}\n\ntype Res"
    out += "ult {\n  pageNumber: Int\n  response: String\n}\n"
    return out^


def _expected_1() -> String:
    var out = String()
    out += "Error: anonymous operation cannot be selected when the docum"
    out += "ent contains other operations\n╭─[ 0002_multiple_anonymo"
    out += "us_operations.graphql:1:1 ]\nError: anonymous operation cann"
    out += "ot be selected when the document contains other operations\n"
    out += "╭─[ 0002_multiple_anonymous_operations.graphql:5:1 ]\n"
    return out^


def _path_2() -> String:
    var out = String()
    out += "diagnostics/0003_anonymous_and_named_operation.graphql"
    return out^


def _input_2() -> String:
    var out = String()
    out += "query {\n  cat\n}\n\nmutation getName {\n  addPet {\n    res"
    out += "ponse\n  }\n}\n\ntype Query {\n  cat: String\n}\n\ntype Muta"
    out += "tion {\n  addPet (name: String!, petType: PetType): Result!"
    out += "\n}\n\nenum PetType {\n  CAT\n  DOG\n}\n\ntype Result {\n  p"
    out += "ageNumber: Int\n  response: String\n}\n"
    return out^


def _expected_2() -> String:
    var out = String()
    out += "Error: anonymous operation cannot be selected when the docum"
    out += "ent contains other operations\n╭─[ 0003_anonymous_and_na"
    out += "med_operation.graphql:1:1 ]\nError: the required argument `M"
    out += "utation.addPet(name:)` is not provided\n╭─[ 0003_anonymo"
    out += "us_and_named_operation.graphql:6:3 ]\n"
    return out^


def _path_3() -> String:
    var out = String()
    out += "diagnostics/0004_subscription_with_multiple_root_fields.grap"
    out += "hql"
    return out^


def _input_3() -> String:
    var out = String()
    out += "subscription sub {\n  newMessage {\n    body\n    sender\n  "
    out += "}\n  disallowedSecondRootField\n}\n\ntype Subscription {\n  "
    out += "newMessage: Result\n  disallowedSecondRootField: String\n}\n"
    out += "\ntype Result {\n  body: String,\n  sender: String\n}\n\ntyp"
    out += "e Query {\n  message: String\n}"
    return out^


def _expected_3() -> String:
    var out = String()
    out += "Error: subscription `sub` can only have one root field\n╭"
    out += "─[ 0004_subscription_with_multiple_root_fields.graphql:1:1"
    out += " ]\n"
    return out^


def _path_4() -> String:
    var out = String()
    out += "diagnostics/0005_subscription_with_multiple_root_fields_in_f"
    out += "ragment_spreads.graphql"
    return out^


def _input_4() -> String:
    var out = String()
    out += "subscription sub {\n  ...multipleSubscriptions\n}\n\nfragmen"
    out += "t multipleSubscriptions on Subscription {\n  newMessage {\n "
    out += "   body\n    sender\n  }\n  disallowedSecondRootField\n}\n\n"
    out += "type Subscription {\n  newMessage: Result\n  disallowedSecon"
    out += "dRootField: String\n}\n\ntype Result {\n  body: String,\n  s"
    out += "ender: String\n}\n\ntype Query {\n  message: String\n}"
    return out^


def _expected_4() -> String:
    var out = String()
    out += "Error: subscription `sub` can only have one root field\n╭"
    out += "─[ 0005_subscription_with_multiple_root_fields_in_fragment"
    out += "_spreads.graphql:1:1 ]\n"
    return out^


def _path_5() -> String:
    var out = String()
    out += "diagnostics/0006_subscription_with_multiple_root_fields_in_i"
    out += "nline_fragments.graphql"
    return out^


def _input_5() -> String:
    var out = String()
    out += "subscription sub {\n    ... on Subscription {\n        newMe"
    out += "ssage {\n          body\n          sender\n        }\n      "
    out += "  disallowedSecondRootField\n    }\n}\n\ntype Subscription {"
    out += "\n  newMessage: Result\n  disallowedSecondRootField: String"
    out += "\n}\n\ntype Result {\n  body: String,\n  sender: String\n}\n"
    out += "\ntype Query {\n  message: String\n}"
    return out^


def _expected_5() -> String:
    var out = String()
    out += "Error: subscription `sub` can only have one root field\n╭"
    out += "─[ 0006_subscription_with_multiple_root_fields_in_inline_f"
    out += "ragments.graphql:1:1 ]\n"
    return out^


def _path_6() -> String:
    var out = String()
    out += "diagnostics/0007_operation_with_undefined_variables.graphql"
    return out^


def _input_6() -> String:
    var out = String()
    out += "query ExampleQuery {\n  topProducts(\n    first: $undefinedV"
    out += "ariable\n    filter: {\n      offset: $offset\n      keyword"
    out += 's: ["a", $keyword]\n    }\n  ) {\n    name\n  }\n}\n\ninpu'
    out += "t Filter {\n  keywords: [String!]\n  offset: Int\n  limit: I"
    out += "nt\n}\n\ntype Query {\n  topProducts(first: Int, filter: Fil"
    out += "ter): Product,\n}\n\ntype Product {\n  name: String\n}\n"
    return out^


def _expected_6() -> String:
    var out = String()
    out += "Error: variable `$undefinedVariable` is not defined\n╭─["
    out += " 0007_operation_with_undefined_variables.graphql:3:12 ]\nErr"
    out += "or: variable `$offset` is not defined\n╭─[ 0007_operatio"
    out += "n_with_undefined_variables.graphql:5:15 ]\nError: variable `"
    out += "$keyword` is not defined\n╭─[ 0007_operation_with_undefi"
    out += "ned_variables.graphql:6:23 ]\n"
    return out^


def _path_7() -> String:
    var out = String()
    out += "diagnostics/0008_operation_with_undefined_variables_in_inlin"
    out += "e_fragment.graphql"
    return out^


def _input_7() -> String:
    var out = String()
    out += "query ExampleQuery {\n  topProducts {\n    name\n    ... on "
    out += "Product {\n        price(setPrice: $value)\n    }\n  }\n}\n"
    out += "\ntype Query {\n  topProducts(first: Int): Product,\n}\n\nty"
    out += "pe Product {\n  name: String\n  price(setPrice: Int): Int\n}"
    out += "\n"
    return out^


def _expected_7() -> String:
    var out = String()
    out += "Error: variable `$value` is not defined\n╭─[ 0008_operat"
    out += "ion_with_undefined_variables_in_inline_fragment.graphql:5:25"
    out += " ]\n"
    return out^


def _path_8() -> String:
    var out = String()
    out += "diagnostics/0009_operation_with_undefined_variables_in_fragm"
    out += "ent.graphql"
    return out^


def _input_8() -> String:
    var out = String()
    out += "directive @track(label: String) on FRAGMENT_DEFINITION\ndire"
    out += "ctive @report(label: String) on QUERY | MUTATION | SUBSCRIPT"
    out += "ION\n\nquery ExampleQuery($variable: Int) @report(label: $qu"
    out += "eryLabel) {\n  topProducts(first: $variable) {\n    name\n  "
    out += "}\n  ... subFrag\n}\n\nfragment subFrag on Query @track(labe"
    out += "l: $productsLabel) {\n  topProducts(first: $variable) {\n   "
    out += " price(setPrice: $value)\n  }\n}\n\ntype Query {\n  topProdu"
    out += "cts(first: Int): Product,\n  reviews: Review\n}\n\ntype Revi"
    out += "ew {\n  message: Message\n}\n\ntype Message {\n  body: Strin"
    out += "g\n  sender(attribute: String): String\n}\n\ntype Product {"
    out += "\n  name: String\n  price(setPrice: Int): Int\n}\n"
    return out^


def _expected_8() -> String:
    var out = String()
    out += "Error: variable `$queryLabel` is not defined\n╭─[ 0009_o"
    out += "peration_with_undefined_variables_in_fragment.graphql:4:51 ]"
    out += "\nError: variable `$productsLabel` is not defined\n╭─[ 0"
    out += "009_operation_with_undefined_variables_in_fragment.graphql:1"
    out += "1:41 ]\nError: variable `$value` is not defined\n╭─[ 000"
    out += "9_operation_with_undefined_variables_in_fragment.graphql:13:"
    out += "21 ]\n"
    return out^


def _path_9() -> String:
    var out = String()
    out += "diagnostics/0010_operation_with_unused_variable.graphql"
    return out^


def _input_9() -> String:
    var out = String()
    out += "query ExampleQuery($unusedVariable: Int) {\n  topProducts {"
    out += "\n    name\n  }\n}\n\ntype Query {\n  topProducts(first: Int"
    out += "): Product,\n}\n\ntype Product {\n  name: String\n  price(se"
    out += "tPrice: Int): Int\n}\n"
    return out^


def _expected_9() -> String:
    var out = String()
    out += "Error: unused variable: `$unusedVariable`\n╭─[ 0010_oper"
    out += "ation_with_unused_variable.graphql:1:20 ]\n"
    return out^


def _path_10() -> String:
    var out = String()
    out += "diagnostics/0011_syntactic_errors_from_parser.graphql"
    return out^


def _input_10() -> String:
    var out = String()
    out += "query getName {}\n\ntype Query {\n  topProducts(first: Int):"
    out += " Product,\n}\n\ntype Product {\n  name: String\n  birthday: "
    out += "String\n}"
    return out^


def _expected_10() -> String:
    var out = String()
    out += "Error: syntax error: expected at least one Selection in Sele"
    out += "ction Set\n╭─[ 0011_syntactic_errors_from_parser.graphql"
    out += ":1:16 ]\n"
    return out^


def _path_11() -> String:
    var out = String()
    out += "diagnostics/0012_schema_definition_with_missing_query_operat"
    out += "ion_type.graphql"
    return out^


def _input_11() -> String:
    var out = String()
    out += "schema {\n  subscription: customSubscription\n}\n\ntype cust"
    out += "omSubscription {\n  changeInPetHousehold: Result\n}\n\ntype "
    out += "Result {\n  id: String\n}"
    return out^


def _expected_11() -> String:
    var out = String()
    out += "Error: missing query root operation type in schema definitio"
    out += "n\n╭─[ 0012_schema_definition_with_missing_query_operati"
    out += "on_type.graphql:1:1 ]\n"
    return out^


def _path_12() -> String:
    var out = String()
    out += "diagnostics/0013_schema_definition_with_duplicate_root_type_"
    out += "operations.graphql"
    return out^


def _input_12() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery\n  query: thatOtherQuery\n"
    out += "}\n\ntype customPetQuery {\n  name: String\n}\ntype thatOthe"
    out += "rQuery {\n  age: Int\n}\n"
    return out^


def _expected_12() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `query` root operation "
    out += "type\n╭─[ 0013_schema_definition_with_duplicate_root_typ"
    out += "e_operations.graphql:3:3 ]\n"
    return out^


def _path_13() -> String:
    var out = String()
    out += "diagnostics/0014_subscription_operation_without_subscription"
    out += "_schema_operation_type.graphql"
    return out^


def _input_13() -> String:
    var out = String()
    out += "subscription messageSubscription {\n  newMessage {\n    body"
    out += "\n    sender\n  }\n}\n\nschema {\n  query: customPetQuery,\n"
    out += "}\n\ntype customPetQuery {\n  name: String,\n  newMessage: M"
    out += "essage\n  age: Int\n}\n\ntype Message {\n  body: String\n  s"
    out += "ender: String\n}"
    return out^


def _expected_13() -> String:
    var out = String()
    out += "Error: `subscription` root operation type is not defined\n"
    out += "╭─[ 0014_subscription_operation_without_subscription_sch"
    out += "ema_operation_type.graphql:1:1 ]\n"
    return out^


def _path_14() -> String:
    var out = String()
    out += "diagnostics/0015_mutation_operation_without_mutation_schema_"
    out += "definition.graphql"
    return out^


def _input_14() -> String:
    var out = String()
    out += "mutation adoptAPetMutation {\n  addPet {\n    owner {\n     "
    out += " name\n    }\n  }\n}\n\ntype Query {\n  name: String,\n  age"
    out += ": Int\n}"
    return out^


def _expected_14() -> String:
    var out = String()
    out += "Error: `mutation` root operation type is not defined\n╭─"
    out += "[ 0015_mutation_operation_without_mutation_schema_definition"
    out += ".graphql:1:1 ]\n"
    return out^


def _path_15() -> String:
    var out = String()
    out += "diagnostics/0016_schema_with_built_in_scalar_definition.grap"
    out += "hql"
    return out^


def _input_15() -> String:
    var out = String()
    out += "type Query {\n  amount: Int\n}\n\nscalar Int\n"
    return out^


def _expected_15() -> String:
    var out = String()
    out += "Error: built-in scalar definitions must be omitted\n╭─[ "
    out += "0016_schema_with_built_in_scalar_definition.graphql:5:1 ]\n"
    return out^


def _path_16() -> String:
    var out = String()
    out += "diagnostics/0017_schema_with_unspecified_scalar.graphql"
    return out^


def _input_16() -> String:
    var out = String()
    out += "# Placeholder for removed test, to avoid renumbering\n"
    return out^


def _expected_16() -> String:
    var out = String()
    out += "Error: missing query root operation type in schema definitio"
    out += "n\nError: syntax error: Unexpected <EOF>.\n╭─[ 0017_sche"
    out += "ma_with_unspecified_scalar.graphql:1:54 ]\n"
    return out^


def _path_17() -> String:
    var out = String()
    out += "diagnostics/0018_schema_with_specified_scalar_missing_values"
    out += ".graphql"
    return out^


def _input_17() -> String:
    var out = String()
    out += "# Placeholder for removed test, to avoid renumbering\n"
    return out^


def _expected_17() -> String:
    var out = String()
    out += "Error: missing query root operation type in schema definitio"
    out += "n\nError: syntax error: Unexpected <EOF>.\n╭─[ 0018_sche"
    out += "ma_with_specified_scalar_missing_values.graphql:1:54 ]\n"
    return out^


def _path_18() -> String:
    var out = String()
    out += "diagnostics/0019_enum_definition_with_duplicate_values.graph"
    out += "ql"
    return out^


def _input_18() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet,\n  snacks: Snack,\n}\n\nenum Pet {"
    out += "\n    CAT\n    DOG\n    FOX\n    CAT\n}\n\nenum Snack {\n   "
    out += " THRIVE_PET_FOODS\n    LILYS_KITCHEN\n    ACANA\n    THRIVE_"
    out += "PET_FOODS\n}"
    return out^


def _expected_18() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `CAT` value of enum typ"
    out += "e `Pet`\n╭─[ 0019_enum_definition_with_duplicate_values."
    out += "graphql:10:5 ]\nError: duplicate definitions for the `THRIVE"
    out += "_PET_FOODS` value of enum type `Snack`\n╭─[ 0019_enum_de"
    out += "finition_with_duplicate_values.graphql:17:5 ]\n"
    return out^


def _path_19() -> String:
    var out = String()
    out += "diagnostics/0020_enum_values_with_uncapitalised_values.graph"
    out += "ql"
    return out^


def _input_19() -> String:
    var out = String()
    out += "# Placeholder for removed test, to avoid renumbering\n"
    return out^


def _expected_19() -> String:
    var out = String()
    out += "Error: missing query root operation type in schema definitio"
    out += "n\nError: syntax error: Unexpected <EOF>.\n╭─[ 0020_enum"
    out += "_values_with_uncapitalised_values.graphql:1:54 ]\n"
    return out^


def _path_20() -> String:
    var out = String()
    out += "diagnostics/0021_union_definition_with_duplicate_members.gra"
    out += "phql"
    return out^


def _input_20() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Photo\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}"
    return out^


def _expected_20() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `Photo` member of union"
    out += " type `SearchResult`\n╭─[ 0021_union_definition_with_dup"
    out += "licate_members.graphql:5:30 ]\n"
    return out^


def _path_21() -> String:
    var out = String()
    out += "diagnostics/0022_duplicate_interface_definitions.graphql"
    return out^


def _input_21() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n}\n\ninterface NamedE"
    out += "ntity {\n  name: String\n}\n"
    return out^


def _expected_21() -> String:
    var out = String()
    out += "Error: the type `NamedEntity` is defined multiple times in t"
    out += "he schema\n╭─[ 0022_duplicate_interface_definitions.grap"
    out += "hql:9:11 ]\n"
    return out^


def _path_22() -> String:
    var out = String()
    out += "diagnostics/0023_interface_definition_with_cyclic_implements"
    out += "_interfaces.graphql"
    return out^


def _input_22() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity implements NamedEntity {\n  name: String"
    out += "\n}"
    return out^


def _expected_22() -> String:
    var out = String()
    out += "Error: interface NamedEntity cannot implement itself\n╭─"
    out += "[ 0023_interface_definition_with_cyclic_implements_interface"
    out += "s.graphql:5:34 ]\n"
    return out^


def _path_23() -> String:
    var out = String()
    out += "diagnostics/0024_interface_definition_with_duplicate_fields."
    out += "graphql"
    return out^


def _input_23() -> String:
    var out = String()
    out += "type Query implements NamedEntity {\n  name: String\n}\n\nin"
    out += "terface NamedEntity {\n  name: String\n  name: String\n}"
    return out^


def _expected_23() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `name` field of interfa"
    out += "ce type `NamedEntity`\n╭─[ 0024_interface_definition_wit"
    out += "h_duplicate_fields.graphql:7:3 ]\n"
    return out^


def _path_24() -> String:
    var out = String()
    out += "diagnostics/0025_interface_definition_with_missing_transitiv"
    out += "e_fields.graphql"
    return out^


def _input_24() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Node {\n  id: ID!\n  thumbnail: String\n}"
    return out^


def _expected_24() -> String:
    var out = String()
    out += "Error: type `Image` does not satisfy interface `Resource`: m"
    out += "issing field `width`\n╭─[ 0025_interface_definition_with"
    out += "_missing_transitive_fields.graphql:14:1 ]\n"
    return out^


def _path_25() -> String:
    var out = String()
    out += "diagnostics/0026_interface_definition_with_missing_implemetn"
    out += "s_interface.graphql"
    return out^


def _input_25() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  url: String\n  width: Int\n}\n\ninterface Image i"
    out += "mplements Resource {\n  id: ID!\n  url: String\n  width: Int"
    out += "\n  thumbnail: String\n}"
    return out^


def _expected_25() -> String:
    var out = String()
    out += "Error: interface `Image` declares that it implements `Resour"
    out += "ce`, but to do so it must also implement `Node`\n╭─[ 002"
    out += "6_interface_definition_with_missing_implemetns_interface.gra"
    out += "phql:15:1 ]\n"
    return out^


def _path_26() -> String:
    var out = String()
    out += "diagnostics/0027_interface_definition_with_undefined_impleme"
    out += "nts_interface.graphql"
    return out^


def _input_26() -> String:
    var out = String()
    out += "type Query implements Resource {\n  id: ID!\n  width: Int\n}"
    out += "\n\ninterface Resource {\n  id: ID!\n  width: Int\n}\n\ninte"
    out += "rface Image implements Resource & Url {\n  id: ID!\n  url: S"
    out += "tring\n  width: Int\n  thumbnail: String\n}"
    return out^


def _expected_26() -> String:
    var out = String()
    out += "Error: cannot find type `Url` in this document\n╭─[ 0027"
    out += "_interface_definition_with_undefined_implements_interface.gr"
    out += "aphql:11:39 ]\n"
    return out^


def _path_27() -> String:
    var out = String()
    out += "diagnostics/0028_interface_definition_with_missing_fields_im"
    out += "plements_intrefaces_undefined_interfaces.graphql"
    return out^


def _input_27() -> String:
    var out = String()
    out += "type Query implements Node {\n  id: ID!\n}\n\ninterface Node"
    out += " {\n  id: ID!\n}\n\ninterface Resource implements Node {\n  "
    out += "id: ID!\n  width: Int\n}\n\ninterface Image implements Resou"
    out += "rce & Url{\n  id: ID!\n  thumbnail: String\n}"
    return out^


def _expected_27() -> String:
    var out = String()
    out += "Error: interface `Image` declares that it implements `Resour"
    out += "ce`, but to do so it must also implement `Node`\n╭─[ 002"
    out += "8_interface_definition_with_missing_fields_implements_intref"
    out += "aces_undefined_interfaces.graphql:14:1 ]\nError: type `Image"
    out += "` does not satisfy interface `Resource`: missing field `widt"
    out += "h`\n╭─[ 0028_interface_definition_with_missing_fields_im"
    out += "plements_intrefaces_undefined_interfaces.graphql:14:1 ]\nErr"
    out += "or: cannot find type `Url` in this document\n╭─[ 0028_in"
    out += "terface_definition_with_missing_fields_implements_intrefaces"
    out += "_undefined_interfaces.graphql:14:39 ]\n"
    return out^


def _path_28() -> String:
    var out = String()
    out += "diagnostics/0029_directive_definitions_with_duplicate_names."
    out += "graphql"
    return out^


def _input_28() -> String:
    var out = String()
    out += "schema @foo {\n    query: Query\n}\n\ntype Query {\n    id: "
    out += "ID!\n    field: String\n}\n\ndirective @foo on SCHEMA\ndirec"
    out += "tive @foo on SCHEMA"
    return out^


def _expected_28() -> String:
    var out = String()
    out += "Error: the directive `@foo` is defined multiple times in the"
    out += " schema\n╭─[ 0029_directive_definitions_with_duplicate_n"
    out += "ames.graphql:11:12 ]\n"
    return out^


def _path_29() -> String:
    var out = String()
    out += "diagnostics/0030_schema_with_duplicate_input_objects.graphql"
    return out^


def _input_29() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}\n\ninput Poin"
    out += "t2D {\n  x: Float\n  y: Float\n}"
    return out^


def _expected_29() -> String:
    var out = String()
    out += "Error: the type `Point2D` is defined multiple times in the s"
    out += "chema\n╭─[ 0030_schema_with_duplicate_input_objects.grap"
    out += "hql:13:7 ]\n"
    return out^


def _path_30() -> String:
    var out = String()
    out += "diagnostics/0031_input_object_with_duplicate_fields.graphql"
    return out^


def _input_30() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  x: Float\n}"
    return out^


def _expected_30() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `x` field of input obje"
    out += "ct type `Point2D`\n╭─[ 0031_input_object_with_duplicate_"
    out += "fields.graphql:10:3 ]\n"
    return out^


def _path_31() -> String:
    var out = String()
    out += "diagnostics/0032_duplicate_object_type_definition.graphql"
    return out^


def _input_31() -> String:
    var out = String()
    out += "type Query {\n  name: String\n}\n\ntype Query {\n  name: Str"
    out += "ing\n}"
    return out^


def _expected_31() -> String:
    var out = String()
    out += "Error: the type `Query` is defined multiple times in the sch"
    out += "ema\n╭─[ 0032_duplicate_object_type_definition.graphql:5"
    out += ":6 ]\n"
    return out^


def _path_32() -> String:
    var out = String()
    out += "diagnostics/0033_object_type_definition_with_duplicate_field"
    out += "s.graphql"
    return out^


def _input_32() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  name: String\n}\n"
    return out^


def _expected_32() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `name` field of object "
    out += "type `Query`\n╭─[ 0033_object_type_definition_with_dupli"
    out += "cate_fields.graphql:3:3 ]\n"
    return out^


def _path_33() -> String:
    var out = String()
    out += "diagnostics/0034_object_type_definition_with_missing_transit"
    out += "ive_fields.graphql"
    return out^


def _input_33() -> String:
    var out = String()
    out += "type Query implements Node & Resource {\n  name: String\n}\n"
    out += "\ninterface Node {\n  id: ID!\n}\n\ninterface Resource {\n  "
    out += "width: Int\n}"
    return out^


def _expected_33() -> String:
    var out = String()
    out += "Error: type `Query` does not satisfy interface `Node`: missi"
    out += "ng field `id`\n╭─[ 0034_object_type_definition_with_miss"
    out += "ing_transitive_fields.graphql:1:1 ]\nError: type `Query` doe"
    out += "s not satisfy interface `Resource`: missing field `width`\n"
    out += "╭─[ 0034_object_type_definition_with_missing_transitive_"
    out += "fields.graphql:1:1 ]\n"
    return out^


def _path_34() -> String:
    var out = String()
    out += "diagnostics/0035_object_type_definition_with_missing_impleme"
    out += "nts_interfaces_definition.graphql"
    return out^


def _input_34() -> String:
    var out = String()
    out += "type Query implements Image {\n  name: String\n  id: ID!\n  "
    out += "url: String\n  width: Int\n  thumbnail: String\n}\n\ninterfa"
    out += "ce Node {\n  id: ID!\n}\n\ninterface Resource implements Nod"
    out += "e {\n  id: ID!\n  url: String\n  width: Int\n}\n\ninterface "
    out += "Image implements Resource {\n  id: ID!\n  url: String\n  wid"
    out += "th: Int\n  thumbnail: String\n}"
    return out^


def _expected_34() -> String:
    var out = String()
    out += "Error: interface `Query` declares that it implements `Image`"
    out += ", but to do so it must also implement `Resource`\n╭─[ 00"
    out += "35_object_type_definition_with_missing_implements_interfaces"
    out += "_definition.graphql:1:1 ]\nError: interface `Image` declares"
    out += " that it implements `Resource`, but to do so it must also im"
    out += "plement `Node`\n╭─[ 0035_object_type_definition_with_mis"
    out += "sing_implements_interfaces_definition.graphql:19:1 ]\n"
    return out^


def _path_35() -> String:
    var out = String()
    out += "diagnostics/0036_object_type_with_non_output_field_types.gra"
    out += "phql"
    return out^


def _input_35() -> String:
    var out = String()
    out += "query mainPage {\n  width\n  result {\n    ... on Person {\n"
    out += "      name\n    }\n  }\n  entity {\n    name\n  }\n}\n\ntype"
    out += " Query {\n  width: Int\n  img: Url\n  relationship: Person\n"
    out += "  entity: NamedEntity\n  depth: Number\n  result: SearchResu"
    out += "lt\n  permissions: Auth\n  coordinates: Point2D\n  main: mai"
    out += "nPage\n}\n\ntype Person {\n  name: String\n  age: Int\n}\n\n"
    out += "interface NamedEntity {\n  name: String\n}\n\nenum Number {"
    out += "\n  INT\n  FLOAT\n}\n\nunion SearchResult = Photo | Person\n"
    out += "\ndirective @Auth(username: String!) repeatable on OBJECT | "
    out += "INTERFACE\n\ninput Point2D {\n  x: Float\n  y: Float\n}\n\ns"
    out += 'calar Url @specifiedBy(url: "https://tools.ietf.org/html/rf'
    out += 'c3986")\n'
    return out^


def _expected_35() -> String:
    var out = String()
    out += "Error: cannot find type `Auth` in this document\n╭─[ 003"
    out += "6_object_type_with_non_output_field_types.graphql:20:16 ]\nE"
    out += "rror: `coordinates` field must return an output type\n╭─"
    out += "[ 0036_object_type_with_non_output_field_types.graphql:21:3 "
    out += "]\nError: cannot find type `mainPage` in this document\n╭"
    out += "─[ 0036_object_type_with_non_output_field_types.graphql:22"
    out += ":9 ]\nError: cannot find type `Photo` in this document\n╭"
    out += "─[ 0036_object_type_with_non_output_field_types.graphql:39"
    out += ":22 ]\n"
    return out^


def _path_36() -> String:
    var out = String()
    out += "diagnostics/0037_interface_with_non_output_fields.graphql"
    return out^


def _input_36() -> String:
    var out = String()
    out += "query mainPage {\n  name {\n    width\n  }\n}\n\ntype Query "
    out += "{\n  name: mainInterface\n}\n\ninterface mainInterface {\n  "
    out += "width: Int\n  img: Url\n  relationship: Person\n  entity: Na"
    out += "medEntity\n  depth: Number\n  result: SearchResult\n  permis"
    out += "sions: Auth\n  coordinates: Point2D\n  main: mainPage\n}\n\n"
    out += "type Person {\n  name: String\n  age: Int\n}\n\ninterface Na"
    out += "medEntity {\n  name: String\n}\n\nenum Number {\n  INT\n  FL"
    out += "OAT\n}\n\nunion SearchResult = Photo | Person\n\ndirective @"
    out += "Auth(username: String!) repeatable on OBJECT | INTERFACE\n\n"
    out += "input Point2D {\n  x: Float\n  y: Float\n}\n\nscalar Url @sp"
    out += 'ecifiedBy(url: "https://tools.ietf.org/html/rfc3986")\n'
    return out^


def _expected_36() -> String:
    var out = String()
    out += "Error: cannot find type `Auth` in this document\n╭─[ 003"
    out += "7_interface_with_non_output_fields.graphql:18:16 ]\nError: `"
    out += "coordinates` field must return an output type\n╭─[ 0037_"
    out += "interface_with_non_output_fields.graphql:19:3 ]\nError: cann"
    out += "ot find type `mainPage` in this document\n╭─[ 0037_inter"
    out += "face_with_non_output_fields.graphql:20:9 ]\nError: cannot fi"
    out += "nd type `Photo` in this document\n╭─[ 0037_interface_wit"
    out += "h_non_output_fields.graphql:37:22 ]\n"
    return out^


def _path_37() -> String:
    var out = String()
    out += "diagnostics/0038_object_type_with_undefined_field_type.graph"
    out += "ql"
    return out^


def _input_37() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n  relationship: Pers"
    out += "on\n}"
    return out^


def _expected_37() -> String:
    var out = String()
    out += "Error: cannot find type `Url` in this document\n╭─[ 0038"
    out += "_object_type_with_undefined_field_type.graphql:3:8 ]\nError:"
    out += " cannot find type `Person` in this document\n╭─[ 0038_ob"
    out += "ject_type_with_undefined_field_type.graphql:4:17 ]\n"
    return out^


def _path_38() -> String:
    var out = String()
    out += "diagnostics/0039_interface_with_undefined_field_type.graphql"
    return out^


def _input_38() -> String:
    var out = String()
    out += "type Query {\n  width: Int\n  img: Url\n}\n\ninterface Conne"
    out += "ction {\n  relationship: Person\n}"
    return out^


def _expected_38() -> String:
    var out = String()
    out += "Error: cannot find type `Url` in this document\n╭─[ 0039"
    out += "_interface_with_undefined_field_type.graphql:3:8 ]\nError: c"
    out += "annot find type `Person` in this document\n╭─[ 0039_inte"
    out += "rface_with_undefined_field_type.graphql:7:17 ]\n"
    return out^


def _path_39() -> String:
    var out = String()
    out += "diagnostics/0040_operation_with_undefined_fields_on_referenc"
    out += "e_type.graphql"
    return out^


def _input_39() -> String:
    var out = String()
    out += "query getProduct {\n  size\n  weight\n}\n\ntype Query {\n  n"
    out += "ame: String\n  topProducts: Product\n}\n\ntype Product {\n  "
    out += "inStock: Boolean @join__field(graph: INVENTORY)\n  name: Str"
    out += "ing @join__field(graph: PRODUCTS)\n}\n\ndirective @join__fie"
    out += "ld(graph: join__Graph, requires: join__FieldSet, provides: j"
    out += "oin__FieldSet) on FIELD_DEFINITION\n\nenum join__Graph {\n  "
    out += "INVENTORY\n  PRODUCTS\n}\nscalar join__FieldSet @specifiedBy"
    out += '(url: "https://apollographql.com")\n'
    return out^


def _expected_39() -> String:
    var out = String()
    out += "Error: type `Query` does not have a field `size`\n╭─[ 00"
    out += "40_operation_with_undefined_fields_on_reference_type.graphql"
    out += ":2:3 ]\nError: type `Query` does not have a field `weight`\n"
    out += "╭─[ 0040_operation_with_undefined_fields_on_reference_ty"
    out += "pe.graphql:3:3 ]\n"
    return out^


def _path_40() -> String:
    var out = String()
    out += "diagnostics/0041_subscription_operation_with_undefined_field"
    out += "s.graphql"
    return out^


def _input_40() -> String:
    var out = String()
    out += "subscription sub {\n  undefinedSubscriptionField\n}\n\ntype "
    out += "Subscription {\n  newMessage: Result\n}\n\ntype Result {\n  "
    out += "body: String,\n  sender: String\n}\n\ntype Query {\n  messag"
    out += "e: String\n}"
    return out^


def _expected_40() -> String:
    var out = String()
    out += "Error: type `Subscription` does not have a field `undefinedS"
    out += "ubscriptionField`\n╭─[ 0041_subscription_operation_with_"
    out += "undefined_fields.graphql:2:3 ]\n"
    return out^


def _path_41() -> String:
    var out = String()
    out += "diagnostics/0042_mutation_operation_with_undefined_fields.gr"
    out += "aphql"
    return out^


def _input_41() -> String:
    var out = String()
    out += "mutation adoptAPetMutation {\n  undefinedMutationField\n}\n"
    out += "\ntype Query {\n  name: String,\n  age: Int\n}\n\ntype Mutat"
    out += "ion {\n  addPet (name: String!, petType: PetType): Result!\n"
    out += "}\n\ntype Result {\n  id: String\n}\n\nenum PetType {\n  CAT"
    out += "\n  DOG\n}\n"
    return out^


def _expected_41() -> String:
    var out = String()
    out += "Error: type `Mutation` does not have a field `undefinedMutat"
    out += "ionField`\n╭─[ 0042_mutation_operation_with_undefined_fi"
    out += "elds.graphql:2:3 ]\n"
    return out^


def _path_42() -> String:
    var out = String()
    out += "diagnostics/0043_undefined_union_member.graphql"
    return out^


def _input_42() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Dog implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  barkVolume: Int\n"
    out += "}\n\nunion CatOrDog = Cat | Dog\n\ntype Human {\n  name: Str"
    out += "ing\n  pets: [Pet]\n}\n\ntype Query {\n  human: Human\n}"
    return out^


def _expected_42() -> String:
    var out = String()
    out += "Error: cannot find type `Cat` in this document\n╭─[ 0043"
    out += "_undefined_union_member.graphql:11:18 ]\n"
    return out^


def _path_43() -> String:
    var out = String()
    out += "diagnostics/0044_union_member_not_of_object_type.graphql"
    return out^


def _input_43() -> String:
    var out = String()
    out += "interface Pet {\n  name: String\n}\n\ntype Cat implements Pe"
    out += "t {\n  name: String\n  nickname: String\n  meowVolume: Int\n"
    out += "}\n\ntype Dog implements Pet {\n  name: String\n  nickname: "
    out += "String\n  barkVolume: Int\n}\n\nunion CatOrDog = Cat | Pet\n"
    out += "\ntype Human {\n  name: String\n  pets: [Pet]\n}\n\ntype Que"
    out += "ry {\n  human: Human\n}"
    return out^


def _expected_43() -> String:
    var out = String()
    out += "Error: union member `Pet` must be an object type\n╭─[ 00"
    out += "44_union_member_not_of_object_type.graphql:17:24 ]\n"
    return out^


def _path_44() -> String:
    var out = String()
    out += "diagnostics/0045_operation_with_unused_variable_in_fragment."
    out += "graphql"
    return out^


def _input_44() -> String:
    var out = String()
    out += "query ExampleQuery($variable: Int) {\n  topProducts {\n    n"
    out += "ame\n  }\n}\n\nfragment unusedFrag on Query {\n  topProducts"
    out += " {\n    price(setPrice: $variable)\n  }\n}\n\ntype Query {\n"
    out += "  topProducts(first: Int): Product,\n  reviews: Review\n}\n"
    out += "\ntype Review {\n  message: Message\n}\n\ntype Message {\n  "
    out += "body: String\n  sender(attribute: String): String\n}\n\ntype"
    out += " Product {\n  name: String\n  price(setPrice: Int): Int\n}\n"
    return out^


def _expected_44() -> String:
    var out = String()
    out += "Error: unused variable: `$variable`\n╭─[ 0045_operation_"
    out += "with_unused_variable_in_fragment.graphql:1:20 ]\nError: frag"
    out += "ment `unusedFrag` must be used in an operation\n╭─[ 0045"
    out += "_operation_with_unused_variable_in_fragment.graphql:7:1 ]\n"
    return out^


def _path_45() -> String:
    var out = String()
    out += "diagnostics/0046_duplicate_directive_arguments.graphql"
    return out^


def _input_45() -> String:
    var out = String()
    out += 'scalar newScalar @specifiedBy(url: "https://tools.ietf.org/'
    out += 'html/rfc4122", url: "https://tools.ietf.org/html/rfc4125"'
    out += ")\n\ntype Query {\n  status: String,\n  response: String @ex"
    out += "ample(if: false, if: true)\n}\n\ndirective @example(if: Bool"
    out += "ean) on FIELD_DEFINITION"
    return out^


def _expected_45() -> String:
    var out = String()
    out += "Error: the argument `url` is provided multiple times\n╭─"
    out += "[ 0046_duplicate_directive_arguments.graphql:1:75 ]\nError: "
    out += "the argument `if` is provided multiple times\n╭─[ 0046_d"
    out += "uplicate_directive_arguments.graphql:5:40 ]\n"
    return out^


def _path_46() -> String:
    var out = String()
    out += "diagnostics/0047_duplicate_field_arguments.graphql"
    return out^


def _input_46() -> String:
    var out = String()
    out += "type Query {\n  single(arg: Boolean): Int\n}\nquery GetDupli"
    out += "cate {\n  single(arg: true, arg: false)\n}\n"
    return out^


def _expected_46() -> String:
    var out = String()
    out += "Error: the argument `arg` is provided multiple times\n╭─"
    out += "[ 0047_duplicate_field_arguments.graphql:5:21 ]\n"
    return out^


def _path_47() -> String:
    var out = String()
    out += "diagnostics/0048_duplicate_field_argument_definition_names.g"
    out += "raphql"
    return out^


def _input_47() -> String:
    var out = String()
    out += "interface Duplicate {\n  duplicate(arg: Boolean, arg: Boolea"
    out += "n): Int\n}\n\ntype Query implements Duplicate {\n  single(ar"
    out += "g: Boolean): Int\n  duplicate(arg: Boolean, arg: Boolean): I"
    out += "nt\n}\n"
    return out^


def _expected_47() -> String:
    var out = String()
    out += "Error: the value `arg` is defined multiple times\n╭─[ 00"
    out += "48_duplicate_field_argument_definition_names.graphql:2:13 ]"
    out += "\nError: the value `arg` is defined multiple times\n╭─[ "
    out += "0048_duplicate_field_argument_definition_names.graphql:7:13 "
    out += "]\n"
    return out^


def _path_48() -> String:
    var out = String()
    out += "diagnostics/0049_duplicate_directive_argument_definition_nam"
    out += "es.graphql"
    return out^


def _input_48() -> String:
    var out = String()
    out += "directive @example(arg: Boolean, arg: Boolean) on FIELD\ntyp"
    out += "e Query {\n  x: Int\n}\n"
    return out^


def _expected_48() -> String:
    var out = String()
    out += "Error: the value `arg` is defined multiple times\n╭─[ 00"
    out += "49_duplicate_directive_argument_definition_names.graphql:1:2"
    out += "0 ]\n"
    return out^


def _path_49() -> String:
    var out = String()
    out += "diagnostics/0050_directives_in_invalid_locations.graphql"
    return out^


def _input_49() -> String:
    var out = String()
    out += "query queryA($status: String @skip(if: true)) @skip(if: fals"
    out += "e){\n  field\n  response(status: $status) @deprecated\n  hum"
    out += "an {\n    pets { ... pet @directiveB }\n  }\n}\n\nfragment p"
    out += "et on Cat @directiveB {\n  meowVolume\n  ... on Pet @directi"
    out += "veA {\n    name\n  }\n}\n\nsubscription subscriptionA @direc"
    out += "tiveA {\n  newMessage {\n    body\n    sender\n  }\n}\n\nmut"
    out += "ation myMutation @skip(if: true) {\n  setMessage (message: "
    out += '"Hello, World! Yours, GraphQL.")\n}\n\ninterface Pet @skip'
    out += "(if: true) {\n  name: String\n}\n\ntype Dog implements Pet {"
    out += "\n  name: String @directiveB\n  nickname: String\n  barkVolu"
    out += "me: Int\n}\n\ntype Cat implements Pet {\n  name: String\n  n"
    out += "ickname: String\n  meowVolume: Int\n}\n\ninput Example @incl"
    out += "ude(if: true) {\n  self: Example @include(if: true)\n  value"
    out += ": String\n}\n\nunion CatOrDog @directiveB = Cat | Dog\n\ntyp"
    out += "e Human {\n  name: String\n  pets: [Pet]\n}\n\nenum Status @"
    out += "directiveA {\n  GREEN @directiveA,\n  RED,\n  YELLOW\n}\n\nt"
    out += "ype Query @deprecated {\n  human: Human\n  field: String,\n "
    out += ' response(status: String @specifiedBy(url: "https://tools.i'
    out += 'etf.org/html/rfc4122")): Status\n}\n\ntype Subscription {\n'
    out += "  newMessage: Result\n}\n\ntype Mutation {\n  setMessage(mes"
    out += "sage: String): String\n}\n\nschema @include(if: true) {\n  q"
    out += "uery: Query\n  subscription: Subscription\n  mutation: Mutat"
    out += "ion\n}\n\ntype Result {\n  body: String,\n  sender: String\n"
    out += '}\n\nscalar spec @directiveB @specifiedBy(url: "https://spe'
    out += 'c.graphql.org/")\n\ndirective @directiveA on UNION\ndirecti'
    out += "ve @directiveB on ENUM\n"
    return out^


def _expected_49() -> String:
    var out = String()
    out += "Error: skip directive is not supported for VARIABLE_DEFINITI"
    out += "ON location\n╭─[ 0050_directives_in_invalid_locations.gr"
    out += "aphql:1:30 ]\nError: skip directive is not supported for QUE"
    out += "RY location\n╭─[ 0050_directives_in_invalid_locations.gr"
    out += "aphql:1:47 ]\nError: deprecated directive is not supported f"
    out += "or FIELD location\n╭─[ 0050_directives_in_invalid_locati"
    out += "ons.graphql:3:29 ]\nError: directiveB directive is not suppo"
    out += "rted for FRAGMENT_SPREAD location\n╭─[ 0050_directives_i"
    out += "n_invalid_locations.graphql:5:20 ]\nError: directiveB direct"
    out += "ive is not supported for FRAGMENT_DEFINITION location\n╭"
    out += "─[ 0050_directives_in_invalid_locations.graphql:9:21 ]\nEr"
    out += "ror: directiveA directive is not supported for INLINE_FRAGME"
    out += "NT location\n╭─[ 0050_directives_in_invalid_locations.gr"
    out += "aphql:11:14 ]\nError: directiveA directive is not supported "
    out += "for SUBSCRIPTION location\n╭─[ 0050_directives_in_invali"
    out += "d_locations.graphql:16:28 ]\nError: skip directive is not su"
    out += "pported for MUTATION location\n╭─[ 0050_directives_in_in"
    out += "valid_locations.graphql:23:21 ]\nError: skip directive is no"
    out += "t supported for INTERFACE location\n╭─[ 0050_directives_"
    out += "in_invalid_locations.graphql:27:15 ]\nError: directiveB dire"
    out += "ctive is not supported for FIELD_DEFINITION location\n╭─"
    out += "[ 0050_directives_in_invalid_locations.graphql:32:16 ]\nErro"
    out += "r: include directive is not supported for INPUT_OBJECT locat"
    out += "ion\n╭─[ 0050_directives_in_invalid_locations.graphql:43"
    out += ":15 ]\nError: include directive is not supported for INPUT_F"
    out += "IELD_DEFINITION location\n╭─[ 0050_directives_in_invalid"
    out += "_locations.graphql:44:17 ]\nError: directiveB directive is n"
    out += "ot supported for UNION location\n╭─[ 0050_directives_in_"
    out += "invalid_locations.graphql:48:16 ]\nError: directiveA directi"
    out += "ve is not supported for ENUM location\n╭─[ 0050_directiv"
    out += "es_in_invalid_locations.graphql:55:13 ]\nError: directiveA d"
    out += "irective is not supported for ENUM_VALUE location\n╭─[ 0"
    out += "050_directives_in_invalid_locations.graphql:56:9 ]\nError: d"
    out += "eprecated directive is not supported for OBJECT location\n"
    out += "╭─[ 0050_directives_in_invalid_locations.graphql:61:12 ]"
    out += "\nError: specifiedBy directive is not supported for ARGUMENT"
    out += "_DEFINITION location\n╭─[ 0050_directives_in_invalid_loc"
    out += "ations.graphql:64:27 ]\nError: include directive is not supp"
    out += "orted for SCHEMA location\n╭─[ 0050_directives_in_invali"
    out += "d_locations.graphql:75:8 ]\nError: directiveB directive is n"
    out += "ot supported for SCALAR location\n╭─[ 0050_directives_in"
    out += "_invalid_locations.graphql:86:13 ]\n"
    return out^


def _path_50() -> String:
    var out = String()
    out += "diagnostics/0051_subscription_operation_with_root_introspect"
    out += "ion_field.graphql"
    return out^


def _input_50() -> String:
    var out = String()
    out += "subscription sub {\n  __typename\n}\n\ntype Subscription {\n"
    out += "  __typename: String\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_50() -> String:
    var out = String()
    out += "Error: subscription `sub` can not have an introspection fiel"
    out += "d as a root field\n╭─[ 0051_subscription_operation_with_"
    out += "root_introspection_field.graphql:2:3 ]\nError: a field canno"
    out += "t be named `__typename` as names starting with two underscor"
    out += "es are reserved\n╭─[ 0051_subscription_operation_with_ro"
    out += "ot_introspection_field.graphql:6:3 ]\n"
    return out^


def _path_51() -> String:
    var out = String()
    out += "diagnostics/0052_undefined_directive.graphql"
    return out^


def _input_51() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    status: Int @directiveA"
    out += "\n}\n\ndirective @directiveB on FIELD_DEFINITION\n"
    return out^


def _expected_51() -> String:
    var out = String()
    out += "Error: cannot find directive `@directiveA` in this document"
    out += "\n╭─[ 0052_undefined_directive.graphql:3:17 ]\n"
    return out^


def _path_52() -> String:
    var out = String()
    out += "diagnostics/0053_argument_name_is_not_defined.graphql"
    return out^


def _input_52() -> String:
    var out = String()
    out += "type Query {\n  field(arg1: Int): Int\n  item: Field\n}\n\nt"
    out += "ype Field {\n  field(arg4: Int): Int\n}\n\nfragment X on Fie"
    out += "ld {\n  field(arg4: 1, arg2: 2, arg3: 3)\n}\n\nquery field {"
    out += "\n  field(arg2: 3)\n}\n\nquery fieldWithFragment {\n  item {"
    out += "\n    ...X\n  }\n}\n"
    return out^


def _expected_52() -> String:
    var out = String()
    out += "Error: the argument `arg2` is not supported by `Field.field`"
    out += "\n╭─[ 0053_argument_name_is_not_defined.graphql:11:18 ]"
    out += "\nError: the argument `arg3` is not supported by `Field.fiel"
    out += "d`\n╭─[ 0053_argument_name_is_not_defined.graphql:11:27 "
    out += "]\nError: the argument `arg2` is not supported by `Query.fie"
    out += "ld`\n╭─[ 0053_argument_name_is_not_defined.graphql:15:9 "
    out += "]\n"
    return out^


def _path_53() -> String:
    var out = String()
    out += "diagnostics/0054_argument_not_provided.graphql"
    return out^


def _input_53() -> String:
    var out = String()
    out += "type ComplicatedArgs {\n  multipleReqs(req1: Int!, req2: Int"
    out += "!): String\n  multipleOptAndReq(req1: Int!, req2: Int!, opt1"
    out += ": Int = 0, opt2: Int = 0): String\n}\n\ntype Basic { a: Int!"
    out += " }\n\ntype Query {\n  basic: Basic\n  complicatedArgs: Compl"
    out += "icatedArgs\n}\n\nfragment Y on ComplicatedArgs {\n    multip"
    out += "leReqs\n}\nfragment Z on ComplicatedArgs {\n    onlyOneArg: "
    out += "multipleReqs(req2: 1)\n}\n\nquery complicatedArgs {\n  basic"
    out += " @skip @include(wrong: false) {\n    a\n  }\n\n  complicated"
    out += "Args {\n    a: multipleReqs(req2: 1)\n    b: multipleOptAndR"
    out += "eq(req1: 1)\n    c: multipleOptAndReq(opt1: 1, opt2: 1, req1"
    out += ": 1)\n  }\n}\nquery complicatedArgsOnFragments {\n  complica"
    out += "tedArgs {\n    ...Y\n    ...Z\n  }\n}\n"
    return out^


def _expected_53() -> String:
    var out = String()
    out += "Error: the required argument `ComplicatedArgs.multipleReqs(r"
    out += "eq1:)` is not provided\n╭─[ 0054_argument_not_provided.g"
    out += "raphql:14:5 ]\nError: the required argument `ComplicatedArgs"
    out += ".multipleReqs(req2:)` is not provided\n╭─[ 0054_argument"
    out += "_not_provided.graphql:14:5 ]\nError: the required argument `"
    out += "ComplicatedArgs.multipleReqs(req1:)` is not provided\n╭─"
    out += "[ 0054_argument_not_provided.graphql:17:5 ]\nError: the requ"
    out += "ired argument `@skip(if:)` is not provided\n╭─[ 0054_arg"
    out += "ument_not_provided.graphql:21:9 ]\nError: the required argum"
    out += "ent `@include(if:)` is not provided\n╭─[ 0054_argument_n"
    out += "ot_provided.graphql:21:15 ]\nError: the argument `wrong` is "
    out += "not supported by `@include`\n╭─[ 0054_argument_not_provi"
    out += "ded.graphql:21:24 ]\nError: the required argument `Complicat"
    out += "edArgs.multipleReqs(req1:)` is not provided\n╭─[ 0054_ar"
    out += "gument_not_provided.graphql:26:5 ]\nError: the required argu"
    out += "ment `ComplicatedArgs.multipleOptAndReq(req2:)` is not provi"
    out += "ded\n╭─[ 0054_argument_not_provided.graphql:27:5 ]\nErro"
    out += "r: the required argument `ComplicatedArgs.multipleOptAndReq("
    out += "req2:)` is not provided\n╭─[ 0054_argument_not_provided."
    out += "graphql:28:5 ]\n"
    return out^


def _path_54() -> String:
    var out = String()
    out += "diagnostics/0055_duplicate_variable_definitions.graphql"
    return out^


def _input_54() -> String:
    var out = String()
    out += "query houseTrainedQuery($atOtherHomes: Boolean, $atOtherHome"
    out += "s: Boolean) {\n  dog {\n    isHouseTrained(atOtherHomes: $at"
    out += "OtherHomes)\n  }\n}\n\ntype Query {\n  dog: Dog\n}\n\ntype D"
    out += "og {\n  name: String!\n  nickname: String\n  barkVolume: Int"
    out += "\n  isHouseTrained(atOtherHomes: Boolean): Boolean!\n}"
    return out^


def _expected_54() -> String:
    var out = String()
    out += "Error: the variable `$atOtherHomes` is declared multiple tim"
    out += "es\n╭─[ 0055_duplicate_variable_definitions.graphql:1:49"
    out += " ]\n"
    return out^


def _path_55() -> String:
    var out = String()
    out += "diagnostics/0056_variables_are_input_types.graphql"
    return out^


def _input_55() -> String:
    var out = String()
    out += "query takesCat($cat: Cat) {\n  dog {\n    isHouseTrained(atO"
    out += "therHomes: $cat)\n  }\n}\n\nquery takesDogBang($dog: Dog!) {"
    out += "\n  dog {\n    isHouseTrained(atOtherHomes: $dog)\n  }\n}\n"
    out += "\nquery takesListOfPet($pets: [Pet]) {\n  booleanList(boolea"
    out += "nListArg: $pets)\n}\n\nquery takesCatOrDog($catOrDog: CatOrD"
    out += "og) {\n  dog {\n    isHouseTrained(atOtherHomes: $catOrDog)"
    out += "\n  }\n}\n\nquery takesCatOrDog2($catOrDog: Dragon) {\n  dog"
    out += " {\n    isHouseTrained(atOtherHomes: $catOrDog)\n  }\n}\n\nt"
    out += "ype Query {\n  dog: Dog\n  findDog(complex: ComplexInput): D"
    out += "og\n  booleanList(booleanListArg: [Boolean!]): Boolean\n}\n"
    out += "\ninput ComplexInput {\n  name: String\n  owner: String\n}\n"
    out += "\nenum DogCommand {\n  SIT\n  DOWN\n  HEEL\n}\n\ntype Dog im"
    out += "plements Pet {\n  name: String!\n  nickname: String\n  barkV"
    out += "olume: Int\n  doesKnowCommand(dogCommand: DogCommand!): Bool"
    out += "ean!\n  isHouseTrained(atOtherHomes: Boolean): Boolean!\n  o"
    out += "wner: Human\n}\n\ninterface Sentient {\n  name: String!\n}\n"
    out += "\ninterface Pet {\n  name: String!\n}\n\ntype Alien implemen"
    out += "ts Sentient {\n  name: String!\n  homePlanet: String\n}\n\nt"
    out += "ype Human implements Sentient {\n  name: String!\n  pets: [P"
    out += "et!]\n}\n\nenum CatCommand {\n  JUMP\n}\n\ntype Cat implemen"
    out += "ts Pet {\n  name: String!\n  nickname: String\n  doesKnowCom"
    out += "mand(catCommand: CatCommand!): Boolean!\n  meowVolume: Int\n"
    out += "}\n\nunion CatOrDog = Cat | Dog\nunion DogOrHuman = Dog | Hu"
    out += "man\nunion HumanOrAlien = Human | Alien\n"
    return out^


def _expected_55() -> String:
    var out = String()
    out += "Error: `$cat` variable must be of an input type\n╭─[ 005"
    out += "6_variables_are_input_types.graphql:1:16 ]\nError: variable "
    out += "`$cat` of type `Cat` cannot be used for argument `atOtherHom"
    out += "es` of type `Boolean`\n╭─[ 0056_variables_are_input_type"
    out += "s.graphql:3:20 ]\nError: `$dog` variable must be of an input"
    out += " type\n╭─[ 0056_variables_are_input_types.graphql:7:20 ]"
    out += "\nError: variable `$dog` of type `Dog!` cannot be used for a"
    out += "rgument `atOtherHomes` of type `Boolean`\n╭─[ 0056_varia"
    out += "bles_are_input_types.graphql:9:20 ]\nError: `$pets` variable"
    out += " must be of an input type\n╭─[ 0056_variables_are_input_"
    out += "types.graphql:13:22 ]\nError: variable `$pets` of type `[Pet"
    out += "]` cannot be used for argument `booleanListArg` of type `[Bo"
    out += "olean!]`\n╭─[ 0056_variables_are_input_types.graphql:14:"
    out += "15 ]\nError: `$catOrDog` variable must be of an input type\n"
    out += "╭─[ 0056_variables_are_input_types.graphql:17:21 ]\nErro"
    out += "r: variable `$catOrDog` of type `CatOrDog` cannot be used fo"
    out += "r argument `atOtherHomes` of type `Boolean`\n╭─[ 0056_va"
    out += "riables_are_input_types.graphql:19:20 ]\nError: cannot find "
    out += "type `Dragon` in this document\n╭─[ 0056_variables_are_i"
    out += "nput_types.graphql:23:22 ]\nError: variable `$catOrDog` of t"
    out += "ype `Dragon` cannot be used for argument `atOtherHomes` of t"
    out += "ype `Boolean`\n╭─[ 0056_variables_are_input_types.graphq"
    out += "l:25:20 ]\n"
    return out^


def _path_56() -> String:
    var out = String()
    out += "diagnostics/0057_duplicate_type_names.graphql"
    return out^


def _input_56() -> String:
    var out = String()
    out += "interface World {\n  a: Int\n}\ntype Object implements World"
    out += " {\n  a: Int\n}\n\n# not OK\ntype World implements World {\n"
    out += '  a: Int\n}\n\n# OK\nscalar X @specifiedBy(url: "https://ap'
    out += 'ollographql.com")\n# not OK\nunion X @X = Object\n# not OK'
    out += "\nenum X { Y, Z }\n\ntype X {\n  x: X\n}\n\ndirective @X(ok:"
    out += " Boolean) on UNION\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_56() -> String:
    var out = String()
    out += "Error: the type `World` is defined multiple times in the sch"
    out += "ema\n╭─[ 0057_duplicate_type_names.graphql:9:6 ]\nError:"
    out += " the type `X` is defined multiple times in the schema\n╭"
    out += "─[ 0057_duplicate_type_names.graphql:16:7 ]\nError: the ty"
    out += "pe `X` is defined multiple times in the schema\n╭─[ 0057"
    out += "_duplicate_type_names.graphql:18:6 ]\nError: the type `X` is"
    out += " defined multiple times in the schema\n╭─[ 0057_duplicat"
    out += "e_type_names.graphql:20:6 ]\n"
    return out^


def _path_57() -> String:
    var out = String()
    out += "diagnostics/0058_fragment_definitions_with_duplicate_names.g"
    out += "raphql"
    return out^


def _input_57() -> String:
    var out = String()
    out += "# https://github.com/apollographql/apollo-rs/issues/457\ntyp"
    out += "e Query {\n  pet: Pet\n}\ntype Pet {\n  name: String!\n  own"
    out += "er: String\n}\n\nquery getPet {\n  pet {\n    name\n    ... "
    out += "petFragment\n  }\n}\n\nfragment petFragment on Pet {\n  name"
    out += "\n  owner\n}\n\nfragment petFragment on Pet {\n  name\n  own"
    out += "er\n}\n"
    return out^


def _expected_57() -> String:
    var out = String()
    out += "Error: the fragment `petFragment` is defined multiple times "
    out += "in the document\n╭─[ 0058_fragment_definitions_with_dupl"
    out += "icate_names.graphql:22:10 ]\n"
    return out^


def _path_58() -> String:
    var out = String()
    out += "diagnostics/0059_root_operation_object_type.graphql"
    return out^


def _input_58() -> String:
    var out = String()
    out += "schema {\n    query: SomeInterface \n}\n\ninterface SomeInte"
    out += "rface {\n    name: String\n}\n\ntype ShouldBeTheQuery {\n   "
    out += " name: String\n}"
    return out^


def _expected_58() -> String:
    var out = String()
    out += "Error: `SomeInterface` field must return an object type\n╭"
    out += "─[ 0059_root_operation_object_type.graphql:2:12 ]\n"
    return out^


def _path_59() -> String:
    var out = String()
    out += "diagnostics/0060_root_operation_definition_undefined_operati"
    out += "on_type.graphql"
    return out^


def _input_59() -> String:
    var out = String()
    out += "schema {\n    query: SomeQuery\n}\n\ntype ShouldBeTheQuery {"
    out += "\n    name: String\n}"
    return out^


def _expected_59() -> String:
    var out = String()
    out += "Error: cannot find type `SomeQuery` in this document\n╭─"
    out += "[ 0060_root_operation_definition_undefined_operation_type.gr"
    out += "aphql:2:12 ]\n"
    return out^


def _path_60() -> String:
    var out = String()
    out += "diagnostics/0061_root_operation_with_default_undefined_query"
    out += ".graphql"
    return out^


def _input_60() -> String:
    var out = String()
    out += "schema {\n    query: Query\n}"
    return out^


def _expected_60() -> String:
    var out = String()
    out += "Error: cannot find type `Query` in this document\n╭─[ 00"
    out += "61_root_operation_with_default_undefined_query.graphql:2:12 "
    out += "]\n"
    return out^


def _path_61() -> String:
    var out = String()
    out += "diagnostics/0062_root_operation_with_list.graphql"
    return out^


def _input_61() -> String:
    var out = String()
    out += "schema {\n  query: [Object]\n}\ntype Object {\n  field: Int"
    out += "\n}"
    return out^


def _expected_61() -> String:
    var out = String()
    out += "Error: missing query root operation type in schema definitio"
    out += "n\n╭─[ 0062_root_operation_with_list.graphql:1:1 ]\nErro"
    out += "r: syntax error: expected R_CURLY, got [\n╭─[ 0062_root_"
    out += "operation_with_list.graphql:2:10 ]\nError: syntax error: exp"
    out += "ected a StringValue, Name or OperationDefinition\n╭─[ 00"
    out += "62_root_operation_with_list.graphql:2:10 ]\nError: syntax er"
    out += "ror: expected definition\n╭─[ 0062_root_operation_with_l"
    out += "ist.graphql:2:11 ]\nError: syntax error: expected a StringVa"
    out += "lue, Name or OperationDefinition\n╭─[ 0062_root_operatio"
    out += "n_with_list.graphql:2:17 ]\nError: syntax error: expected a "
    out += "StringValue, Name or OperationDefinition\n╭─[ 0062_root_"
    out += "operation_with_list.graphql:3:1 ]\n"
    return out^


def _path_62() -> String:
    var out = String()
    out += "diagnostics/0063_extension_orphan.graphql"
    return out^


def _input_62() -> String:
    var out = String()
    out += "type Query {\n  x: Int\n}\n\nextend scalar A @deprecated(rea"
    out += 'son: "Use B instead")\nextend type B { field: Int! }\nexte'
    out += "nd schema {\n  query: Query\n}\nextend union C = String\next"
    out += "end interface D {\n  field: Int\n}\nextend input E {\n  fiel"
    out += "d: Int\n}\nextend enum F {\n  MEMBER\n}\n"
    return out^


def _expected_62() -> String:
    var out = String()
    out += "Error: type extension for undefined type `A`\n╭─[ 0063_e"
    out += "xtension_orphan.graphql:5:15 ]\nError: type extension for un"
    out += "defined type `B`\n╭─[ 0063_extension_orphan.graphql:6:13"
    out += " ]\nError: duplicate definitions for the `query` root operat"
    out += "ion type\n╭─[ 0063_extension_orphan.graphql:8:3 ]\nError"
    out += ": type extension for undefined type `C`\n╭─[ 0063_extens"
    out += "ion_orphan.graphql:10:14 ]\nError: type extension for undefi"
    out += "ned type `D`\n╭─[ 0063_extension_orphan.graphql:11:18 ]"
    out += "\nError: type extension for undefined type `E`\n╭─[ 0063"
    out += "_extension_orphan.graphql:14:14 ]\nError: type extension for"
    out += " undefined type `F`\n╭─[ 0063_extension_orphan.graphql:1"
    out += "7:13 ]\n"
    return out^


def _path_63() -> String:
    var out = String()
    out += "diagnostics/0064_extension_wrong_type.graphql"
    return out^


def _input_63() -> String:
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


def _expected_63() -> String:
    var out = String()
    out += "Error: union member `Scalar` must be an object type\n╭─["
    out += " 0064_extension_wrong_type.graphql:8:15 ]\nError: adding a u"
    out += "nion type extension, but `Scalar` is a scalar type\n╭─[ "
    out += "0064_extension_wrong_type.graphql:16:14 ]\nError: adding an "
    out += "interface type extension, but `Object` is an object type\n"
    out += "╭─[ 0064_extension_wrong_type.graphql:17:18 ]\nError: ad"
    out += "ding an enum type extension, but `Intf` is an interface type"
    out += "\n╭─[ 0064_extension_wrong_type.graphql:20:13 ]\nError: "
    out += "adding an object type extension, but `Input` is an input obj"
    out += "ect type\n╭─[ 0064_extension_wrong_type.graphql:23:13 ]"
    out += "\nError: adding an input object type extension, but `Enum` i"
    out += "s an enum type\n╭─[ 0064_extension_wrong_type.graphql:26"
    out += ":14 ]\n"
    return out^


def _path_64() -> String:
    var out = String()
    out += "diagnostics/0065_subselection_of_enum.graphql"
    return out^


def _input_64() -> String:
    var out = String()
    out += "query SelectionOfEnum {\n  pet1 { name }\n  pet2 { name }\n "
    out += " pet3 { name }\n  pet4 { name }\n  pet5 { name }\n  pet6 { n"
    out += "ame }\n}\n\ntype Query {\n  pet1: Pet,\n  pet2: Pet!,\n  pet"
    out += "3: [Pet],\n  pet4: [Pet!],\n  pet5: [Pet]!,\n  pet6: [Pet!]!"
    out += ",\n}\n\nenum Pet {\n    CAT\n    DOG\n    FOX\n}\n"
    return out^


def _expected_64() -> String:
    var out = String()
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:2:3 ]\n"
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:3:3 ]\n"
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:4:3 ]\n"
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:5:3 ]\n"
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:6:3 ]\n"
    out += "Error: field selection of enum type `Pet` must not have subs"
    out += "elections\n╭─[ 0065_subselection_of_enum.graphql:7:3 ]\n"
    return out^


def _path_65() -> String:
    var out = String()
    out += "diagnostics/0066_subselection_of_scalar.graphql"
    return out^


def _input_65() -> String:
    var out = String()
    out += "query SelectionOfScalar {\n  url1 { name }\n  url2 { name }"
    out += "\n  url3 { name }\n  url4 { name }\n  url5 { name }\n  url6 "
    out += "{ name }\n}\n\ntype Query {\n  url1: URL,\n  url2: URL!,\n  "
    out += "url3: [URL],\n  url4: [URL!],\n  url5: [URL]!,\n  url6: [URL"
    out += '!]!,\n}\n\nscalar URL @specifiedBy(url: "https://tools.ietf'
    out += '.org/html/rfc3986")\n'
    return out^


def _expected_65() -> String:
    var out = String()
    out += "Error: field selection of scalar type `URL` must not have su"
    out += "bselections\n╭─[ 0066_subselection_of_scalar.graphql:2:3"
    out += " ]\nError: field selection of scalar type `URL` must not hav"
    out += "e subselections\n╭─[ 0066_subselection_of_scalar.graphql"
    out += ":3:3 ]\nError: field selection of scalar type `URL` must not"
    out += " have subselections\n╭─[ 0066_subselection_of_scalar.gra"
    out += "phql:4:3 ]\nError: field selection of scalar type `URL` must"
    out += " not have subselections\n╭─[ 0066_subselection_of_scalar"
    out += ".graphql:5:3 ]\nError: field selection of scalar type `URL` "
    out += "must not have subselections\n╭─[ 0066_subselection_of_sc"
    out += "alar.graphql:6:3 ]\nError: field selection of scalar type `U"
    out += "RL` must not have subselections\n╭─[ 0066_subselection_o"
    out += "f_scalar.graphql:7:3 ]\n"
    return out^


def _path_66() -> String:
    var out = String()
    out += "diagnostics/0067_subselection_of_interface.graphql"
    return out^


def _input_66() -> String:
    var out = String()
    out += "query SelectionOfInterface {\n  pet1\n  pet2\n  pet3\n  pet4"
    out += "\n  pet5\n  pet6\n}\n\ntype Query {\n  pet1: Pet,\n  pet2: P"
    out += "et!,\n  pet3: [Pet],\n  pet4: [Pet!],\n  pet5: [Pet]!,\n  pe"
    out += "t6: [Pet!]!,\n}\n\ninterface Pet {\n  id: String,\n}\n"
    return out^


def _expected_66() -> String:
    var out = String()
    out += "Error: interface, union and object types must have a subsele"
    out += "ction set\n╭─[ 0067_subselection_of_interface.graphql:2:"
    out += "3 ]\nError: interface, union and object types must have a su"
    out += "bselection set\n╭─[ 0067_subselection_of_interface.graph"
    out += "ql:3:3 ]\nError: interface, union and object types must have"
    out += " a subselection set\n╭─[ 0067_subselection_of_interface."
    out += "graphql:4:3 ]\nError: interface, union and object types must"
    out += " have a subselection set\n╭─[ 0067_subselection_of_inter"
    out += "face.graphql:5:3 ]\nError: interface, union and object types"
    out += " must have a subselection set\n╭─[ 0067_subselection_of_"
    out += "interface.graphql:6:3 ]\nError: interface, union and object "
    out += "types must have a subselection set\n╭─[ 0067_subselectio"
    out += "n_of_interface.graphql:7:3 ]\n"
    return out^


def _path_67() -> String:
    var out = String()
    out += "diagnostics/0068_subselection_of_union.graphql"
    return out^


def _input_67() -> String:
    var out = String()
    out += "query SelectionOfUnion {\n  pet1\n  pet2\n  pet3\n  pet4\n  "
    out += "pet5\n  pet6\n}\n\ntype Query {\n  pet1: CatOrDog,\n  pet2: "
    out += "CatOrDog!,\n  pet3: [CatOrDog],\n  pet4: [CatOrDog!],\n  pet"
    out += "5: [CatOrDog]!,\n  pet6: [CatOrDog!]!,\n}\n\ntype Cat { id: "
    out += "String! }\ntype Dog { id: String! }\nunion CatOrDog = Cat | "
    out += "Dog\n"
    return out^


def _expected_67() -> String:
    var out = String()
    out += "Error: interface, union and object types must have a subsele"
    out += "ction set\n╭─[ 0068_subselection_of_union.graphql:2:3 ]"
    out += "\nError: interface, union and object types must have a subse"
    out += "lection set\n╭─[ 0068_subselection_of_union.graphql:3:3 "
    out += "]\nError: interface, union and object types must have a subs"
    out += "election set\n╭─[ 0068_subselection_of_union.graphql:4:3"
    out += " ]\nError: interface, union and object types must have a sub"
    out += "selection set\n╭─[ 0068_subselection_of_union.graphql:5:"
    out += "3 ]\nError: interface, union and object types must have a su"
    out += "bselection set\n╭─[ 0068_subselection_of_union.graphql:6"
    out += ":3 ]\nError: interface, union and object types must have a s"
    out += "ubselection set\n╭─[ 0068_subselection_of_union.graphql:"
    out += "7:3 ]\n"
    return out^


def _path_68() -> String:
    var out = String()
    out += "diagnostics/0069_subselection_of_object.graphql"
    return out^


def _input_68() -> String:
    var out = String()
    out += "query SelectionOfObject {\n  pet1\n  pet2\n  pet3\n  pet4\n "
    out += " pet5\n  pet6\n}\n\ntype Query {\n  pet1: Pet,\n  pet2: Pet!"
    out += ",\n  pet3: [Pet],\n  pet4: [Pet!],\n  pet5: [Pet]!,\n  pet6:"
    out += " [Pet!]!,\n}\n\ntype Pet {\n  id: String,\n}\n"
    return out^


def _expected_68() -> String:
    var out = String()
    out += "Error: interface, union and object types must have a subsele"
    out += "ction set\n╭─[ 0069_subselection_of_object.graphql:2:3 ]"
    out += "\nError: interface, union and object types must have a subse"
    out += "lection set\n╭─[ 0069_subselection_of_object.graphql:3:3"
    out += " ]\nError: interface, union and object types must have a sub"
    out += "selection set\n╭─[ 0069_subselection_of_object.graphql:4"
    out += ":3 ]\nError: interface, union and object types must have a s"
    out += "ubselection set\n╭─[ 0069_subselection_of_object.graphql"
    out += ":5:3 ]\nError: interface, union and object types must have a"
    out += " subselection set\n╭─[ 0069_subselection_of_object.graph"
    out += "ql:6:3 ]\nError: interface, union and object types must have"
    out += " a subselection set\n╭─[ 0069_subselection_of_object.gra"
    out += "phql:7:3 ]\n"
    return out^


def _path_69() -> String:
    var out = String()
    out += "diagnostics/0070_self_referential_directive_definition.graph"
    out += "ql"
    return out^


def _input_69() -> String:
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


def _expected_69() -> String:
    var out = String()
    out += "Error: `invalidExample` directive definition cannot referenc"
    out += "e itself\n╭─[ 0070_self_referential_directive_definition"
    out += ".graphql:7:1 ]\nError: `deprecatedType` directive definition"
    out += " cannot reference itself\n╭─[ 0070_self_referential_dire"
    out += "ctive_definition.graphql:11:1 ]\nError: `loopA` directive de"
    out += "finition cannot reference itself\n╭─[ 0070_self_referent"
    out += "ial_directive_definition.graphql:13:1 ]\nError: `loopB` dire"
    out += "ctive definition cannot reference itself\n╭─[ 0070_self_"
    out += "referential_directive_definition.graphql:14:1 ]\nError: `loo"
    out += "pC` directive definition cannot reference itself\n╭─[ 00"
    out += "70_self_referential_directive_definition.graphql:15:1 ]\nErr"
    out += "or: `wrong` directive definition cannot reference itself\n"
    out += "╭─[ 0070_self_referential_directive_definition.graphql:2"
    out += "1:1 ]\n"
    return out^


def _path_70() -> String:
    var out = String()
    out += "diagnostics/0074_merge_identical_fields.graphql"
    return out^


def _input_70() -> String:
    var out = String()
    out += "type Query {\n  pet: Dog\n}\n\ntype Dog {\n  nickname: Strin"
    out += "g\n  name: String!\n}\n\nquery queryPupper {\n  pet {\n    ."
    out += "..conflictingBecauseAlias\n    ...sameAliasesWithDifferentFi"
    out += "eldTargets\n  }\n}\n\nfragment conflictingBecauseAlias on Do"
    out += "g {\n  name: nickname\n  name\n}\n\nfragment sameAliasesWith"
    out += "DifferentFieldTargets on Dog {\n  fido: name\n  fido: nickna"
    out += "me\n}\n"
    return out^


def _expected_70() -> String:
    var out = String()
    out += "Error: operation must not select different types using the s"
    out += "ame name `name`\n╭─[ 0074_merge_identical_fields.graphql"
    out += ":19:3 ]\nError: cannot select different fields into the same"
    out += " alias `name`\n╭─[ 0074_merge_identical_fields.graphql:1"
    out += "9:3 ]\nError: operation must not select different types usin"
    out += "g the same name `fido`\n╭─[ 0074_merge_identical_fields."
    out += "graphql:24:3 ]\nError: cannot select different fields into t"
    out += "he same alias `fido`\n╭─[ 0074_merge_identical_fields.gr"
    out += "aphql:24:3 ]\n"
    return out^


def _path_71() -> String:
    var out = String()
    out += "diagnostics/0075_merge_conflicting_args.graphql"
    return out^


def _input_71() -> String:
    var out = String()
    out += "enum DogCommand {\n  SIT\n  HEEL\n}\n\ntype Dog {\n  doesKno"
    out += "wCommand(dogCommand: DogCommand): Boolean\n  isAtLocation(x:"
    out += " Int, y: Int): Boolean\n}\n\ntype Query {\n  pet: Dog\n}\n\n"
    out += "query queryPupperA {\n  pet {\n    ...conflictingArgsOnValue"
    out += "s\n  }\n}\n\nquery queryPupperB($dogCommand: DogCommand) {\n"
    out += "  pet {\n    ...conflictingArgsValueAndVar\n  }\n}\n\nquery "
    out += "queryPupperC($varOne: DogCommand, $varTwo: DogCommand) {\n  "
    out += "pet {\n  ...conflictingArgsWithVars\n  }\n}\n\nquery queryPu"
    out += "pperD {\n  pet {\n    ...differingArgs\n  }\n}\n\nquery quer"
    out += "yPupperE {\n  pet {\n    ...conflictingArgs\n  }\n}\n\nfragm"
    out += "ent conflictingArgsOnValues on Dog {\n  doesKnowCommand(dogC"
    out += "ommand: SIT)\n  doesKnowCommand(dogCommand: HEEL)\n}\n\nfrag"
    out += "ment conflictingArgsValueAndVar on Dog {\n  doesKnowCommand("
    out += "dogCommand: SIT)\n  doesKnowCommand(dogCommand: $dogCommand)"
    out += "\n}\n\nfragment conflictingArgsWithVars on Dog {\n  doesKnow"
    out += "Command(dogCommand: $varOne)\n  doesKnowCommand(dogCommand: "
    out += "$varTwo)\n}\n\nfragment differingArgs on Dog {\n  doesKnowCo"
    out += "mmand(dogCommand: SIT)\n  doesKnowCommand\n}\n\nfragment con"
    out += "flictingArgs on Dog {\n  isAtLocation(x: 0)\n  isAtLocation("
    out += "y: 0)\n}"
    return out^


def _expected_71() -> String:
    var out = String()
    out += "Error: operation must not provide conflicting field argument"
    out += "s for the same name `doesKnowCommand`\n╭─[ 0075_merge_co"
    out += "nflicting_args.graphql:47:3 ]\nError: operation must not pro"
    out += "vide conflicting field arguments for the same name `doesKnow"
    out += "Command`\n╭─[ 0075_merge_conflicting_args.graphql:52:3 ]"
    out += "\nError: operation must not provide conflicting field argume"
    out += "nts for the same name `doesKnowCommand`\n╭─[ 0075_merge_"
    out += "conflicting_args.graphql:57:3 ]\nError: operation must not p"
    out += "rovide conflicting field arguments for the same name `doesKn"
    out += "owCommand`\n╭─[ 0075_merge_conflicting_args.graphql:62:3"
    out += " ]\nError: operation must not provide conflicting field argu"
    out += "ments for the same name `isAtLocation`\n╭─[ 0075_merge_c"
    out += "onflicting_args.graphql:67:3 ]\n"
    return out^


def _path_72() -> String:
    var out = String()
    out += "diagnostics/0076_merge_differing_responses.graphql"
    return out^


def _input_72() -> String:
    var out = String()
    out += "interface Pet {\n  name: String!\n}\n\nenum DogCommand {\n  "
    out += "SIT\n  HEEL\n}\n\nenum CatCommand {\n  JUMP\n}\n\ntype Dog i"
    out += "mplements Pet {\n  name: String!\n  nickname: String!\n  bar"
    out += "kVolume: Int!\n  doesKnowCommand(dogCommand: DogCommand!): B"
    out += "oolean!\n}\n\ntype Cat implements Pet {\n  name: String!\n  "
    out += "meowVolume: Int!\n  doesKnowCommand(catCommand: CatCommand!)"
    out += ": Boolean!\n}\n\ntype Query {\n  pet: Pet\n}\n\nquery getPet"
    out += " {\n  pet {\n    ...conflictingDifferingResponses\n  }\n}\n"
    out += "\nfragment conflictingDifferingResponses on Pet {\n  ... on "
    out += "Dog {\n    someValue: nickname\n  }\n  ... on Cat {\n    som"
    out += "eValue: meowVolume\n  }\n}\n"
    return out^


def _expected_72() -> String:
    var out = String()
    out += "Error: operation must not select different types using the s"
    out += "ame name `someValue`\n╭─[ 0076_merge_differing_responses"
    out += ".graphql:42:5 ]\n"
    return out^


def _path_73() -> String:
    var out = String()
    out += "diagnostics/0077_merge_conflict_deep.graphql"
    return out^


def _input_73() -> String:
    var out = String()
    out += "type O {\n  a: Int\n  b: Int\n}\ntype Query {\n  field: O,\n"
    out += "}\n\n{\n  field {\n    x: a\n  },\n  field {\n    x: b\n  }"
    out += "\n}\n"
    return out^


def _expected_73() -> String:
    var out = String()
    out += "Error: cannot select different fields into the same alias `x"
    out += "`\n╭─[ 0077_merge_conflict_deep.graphql:14:5 ]\n"
    return out^


def _path_74() -> String:
    var out = String()
    out += "diagnostics/0078_merge_conflict_nested_fragments.graphql"
    return out^


def _input_74() -> String:
    var out = String()
    out += "type T {\n  a: Int\n  b: Int\n  c: Int\n  d: Int\n}\n\ntype "
    out += "Query {\n  field: T\n}\n\n{\n  field {\n    ...F\n  }\n  fie"
    out += "ld {\n    ...I\n  }\n}\nfragment F on T {\n  x: a\n  ...G\n}"
    out += "\nfragment G on T {\n  y: c\n}\nfragment I on T {\n  y: d\n "
    out += " ...J\n}\nfragment J on T {\n  x: b\n}\n"
    return out^


def _expected_74() -> String:
    var out = String()
    out += "Error: cannot select different fields into the same alias `y"
    out += "`\n╭─[ 0078_merge_conflict_nested_fragments.graphql:25:3"
    out += " ]\nError: cannot select different fields into the same alia"
    out += "s `x`\n╭─[ 0078_merge_conflict_nested_fragments.graphql:"
    out += "32:3 ]\n"
    return out^


def _path_75() -> String:
    var out = String()
    out += "diagnostics/0079_directive_is_unique.graphql"
    return out^


def _input_75() -> String:
    var out = String()
    out += "directive @repeatable repeatable on FIELD\ndirective @unique"
    out += " on FIELD\n\ntype Query {\n  fieldA: Int\n  fieldB: Int\n}\n"
    out += "\nquery {\n  fieldA @repeatable @repeatable\n  fieldB @uniqu"
    out += "e @unique\n}\n"
    return out^


def _expected_75() -> String:
    var out = String()
    out += "Error: non-repeatable directive unique can only be used once"
    out += " per location\n╭─[ 0079_directive_is_unique.graphql:11:1"
    out += "8 ]\n"
    return out^


def _path_76() -> String:
    var out = String()
    out += "diagnostics/0080_directive_is_unique_with_extensions.graphql"
    return out^


def _input_76() -> String:
    var out = String()
    out += "directive @nonRepeatable on OBJECT | SCALAR | INTERFACE\next"
    out += "end type TestObject @nonRepeatable\ntype TestObject @nonRepe"
    out += "atable {\n  field: String\n}\nextend type TestObject @nonRep"
    out += "eatable\n\nscalar Scalar @nonRepeatable\nextend scalar Scala"
    out += 'r @nonRepeatable @specifiedBy(url: "example.com")\n\ninter'
    out += "face Intf @nonRepeatable {\n  field: String\n}\nextend inter"
    out += "face Intf @nonRepeatable\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_76() -> String:
    var out = String()
    out += "Error: non-repeatable directive nonRepeatable can only be us"
    out += "ed once per location\n╭─[ 0080_directive_is_unique_with_"
    out += "extensions.graphql:2:24 ]\nError: non-repeatable directive n"
    out += "onRepeatable can only be used once per location\n╭─[ 008"
    out += "0_directive_is_unique_with_extensions.graphql:6:24 ]\nError:"
    out += " non-repeatable directive nonRepeatable can only be used onc"
    out += "e per location\n╭─[ 0080_directive_is_unique_with_extens"
    out += "ions.graphql:9:22 ]\nError: non-repeatable directive nonRepe"
    out += "atable can only be used once per location\n╭─[ 0080_dire"
    out += "ctive_is_unique_with_extensions.graphql:14:23 ]\n"
    return out^


def _path_77() -> String:
    var out = String()
    out += "diagnostics/0081_directive_is_unique_type_system.graphql"
    return out^


def _input_77() -> String:
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


def _expected_77() -> String:
    var out = String()
    out += "Error: non-repeatable directive nonRepeatable can only be us"
    out += "ed once per location\n╭─[ 0081_directive_is_unique_type_"
    out += "system.graphql:3:23 ]\nError: non-repeatable directive nonRe"
    out += "peatable can only be used once per location\n╭─[ 0081_di"
    out += "rective_is_unique_type_system.graphql:4:34 ]\nError: `Dummy`"
    out += " has no fields\n╭─[ 0081_directive_is_unique_type_system"
    out += ".graphql:5:1 ]\nError: non-repeatable directive nonRepeatabl"
    out += "e can only be used once per location\n╭─[ 0081_directive"
    out += "_is_unique_type_system.graphql:5:27 ]\nError: `TestInterface"
    out += "` has no fields\n╭─[ 0081_directive_is_unique_type_syste"
    out += "m.graphql:6:1 ]\nError: non-repeatable directive nonRepeatab"
    out += "le can only be used once per location\n╭─[ 0081_directiv"
    out += "e_is_unique_type_system.graphql:6:40 ]\nError: `TestUnion` h"
    out += "as no member types\n╭─[ 0081_directive_is_unique_type_sy"
    out += "stem.graphql:7:1 ]\nError: non-repeatable directive nonRepea"
    out += "table can only be used once per location\n╭─[ 0081_direc"
    out += "tive_is_unique_type_system.graphql:7:32 ]\nError: `TestInput"
    out += "` has no input values\n╭─[ 0081_directive_is_unique_type"
    out += "_system.graphql:8:1 ]\nError: non-repeatable directive nonRe"
    out += "peatable can only be used once per location\n╭─[ 0081_di"
    out += "rective_is_unique_type_system.graphql:8:32 ]\n"
    return out^


def _path_78() -> String:
    var out = String()
    out += "diagnostics/0082_introspection_types_in_mutation.graphql"
    return out^


def _input_78() -> String:
    var out = String()
    out += "schema {\n  query: MyQueryRootType\n  mutation: MyMutationRo"
    out += "otType\n}\n\ntype MyQueryRootType {\n  someField: String\n}"
    out += "\n\ntype MyMutationRootType {\n  setSomeField(to: String): S"
    out += 'tring\n}\n\nmutation introspect {\n  __type(name: "User") '
    out += "{\n    name\n    fields {\n      name\n      type {\n       "
    out += " name\n      }\n    }\n  }\n}"
    return out^


def _expected_78() -> String:
    var out = String()
    out += "Error: type `MyMutationRootType` does not have a field `__ty"
    out += "pe`\n╭─[ 0082_introspection_types_in_mutation.graphql:15"
    out += ":3 ]\n"
    return out^


def _path_79() -> String:
    var out = String()
    out += "diagnostics/0083_type_introspection_from_disallowed_type.gra"
    out += "phql"
    return out^


def _input_79() -> String:
    var out = String()
    out += "query getProduct {\n  size\n  topProducts {\n    __type(name"
    out += ': "User") {\n      name\n      fields {\n        name\n   '
    out += "     type {\n          name\n        }\n      }\n    }\n    "
    out += "name\n    inStock\n  }\n}\n\ntype Query {\n  topProducts: Pr"
    out += "oduct\n  name: String\n  size: Int\n}\n\ntype Product {\n  i"
    out += "nStock: Boolean @join__field(graph: INVENTORY)\n  name: Stri"
    out += "ng @join__field(graph: PRODUCTS)\n  price: Int\n  shippingEs"
    out += "timate: Int\n  upc: String!\n  weight: Int\n}\n\ndirective @"
    out += "join__field(graph: join__Graph, requires: join__FieldSet, pr"
    out += "ovides: join__FieldSet) on FIELD_DEFINITION\n\nenum join__Gr"
    out += "aph {\n  INVENTORY\n  PRODUCTS\n}\n\nscalar join__FieldSet @"
    out += 'specifiedBy(url: "https://apollographql.com")\n'
    return out^


def _expected_79() -> String:
    var out = String()
    out += "Error: type `Product` does not have a field `__type`\n╭─"
    out += "[ 0083_type_introspection_from_disallowed_type.graphql:4:5 ]"
    out += "\n"
    return out^


def _path_80() -> String:
    var out = String()
    out += "diagnostics/0084_circular_non_nullable_input_objects.graphql"
    return out^


def _input_80() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    example(arg: First): Int"
    out += "\n}\n\ninput First {\n  second: Second!\n  value: String\n}"
    out += "\n\ninput Second {\n  third: Third!\n  value: String\n}\n\ni"
    out += "nput Third {\n  fourth: Fourth!\n  value: String\n}\n\ninput"
    out += " Fourth {\n  first: First!\n}"
    return out^


def _expected_80() -> String:
    var out = String()
    out += "Error: `First` input object cannot reference itself\n╭─["
    out += " 0084_circular_non_nullable_input_objects.graphql:6:1 ]\nErr"
    out += "or: `Second` input object cannot reference itself\n╭─[ 0"
    out += "084_circular_non_nullable_input_objects.graphql:11:1 ]\nErro"
    out += "r: `Third` input object cannot reference itself\n╭─[ 008"
    out += "4_circular_non_nullable_input_objects.graphql:16:1 ]\nError:"
    out += " `Fourth` input object cannot reference itself\n╭─[ 0084"
    out += "_circular_non_nullable_input_objects.graphql:21:1 ]\n"
    return out^


def _path_81() -> String:
    var out = String()
    out += "diagnostics/0085_fragment_spread_target_defined.graphql"
    return out^


def _input_81() -> String:
    var out = String()
    out += "type Dog {\n  name: String!\n}\ntype Query {\n  dog: Dog\n}"
    out += "\n\n{\n  dog {\n    ...undefinedFragment\n  }\n}\n"
    return out^


def _expected_81() -> String:
    var out = String()
    out += "Error: cannot find fragment `undefinedFragment` in this docu"
    out += "ment\n╭─[ 0085_fragment_spread_target_defined.graphql:10"
    out += ":5 ]\n"
    return out^


def _path_82() -> String:
    var out = String()
    out += "diagnostics/0086_unused_fragment.graphql"
    return out^


def _input_82() -> String:
    var out = String()
    out += "query Query {\n  products {\n      inStock\n      name\n  }"
    out += "\n}\n\ntype Query {\n  products: Product\n}\n\ntype Product "
    out += "{\n  inStock: Boolean\n  name: String\n}\n\nfragment nameFra"
    out += "gment on Product {\n  name\n}"
    return out^


def _expected_82() -> String:
    var out = String()
    out += "Error: fragment `nameFragment` must be used in an operation"
    out += "\n╭─[ 0086_unused_fragment.graphql:17:1 ]\n"
    return out^


def _path_83() -> String:
    var out = String()
    out += "diagnostics/0087_fragment_type_condition_on_composite_types."
    out += "graphql"
    return out^


def _input_83() -> String:
    var out = String()
    out += "query Query {\n  products {\n    inStock\n    name\n    pric"
    out += "e { ...fragOnScalar }\n    ...inlineFragOnScalar\n    ... on"
    out += " Int {\n      name\n    }\n  }\n}\ntype Query {\n  products:"
    out += " Product\n}\ntype Product {\n  price: Int\n  inStock: Boolea"
    out += "n\n  name: String\n}\n\nfragment fragOnScalar on Int {\n  na"
    out += "me\n}\n\nfragment inlineFragOnScalar on Product {\n  ... on "
    out += "Int {\n    name\n  }\n  name\n}\n"
    return out^


def _expected_83() -> String:
    var out = String()
    out += "Error: field selection of scalar type `Int` must not have su"
    out += "bselections\n╭─[ 0087_fragment_type_condition_on_composi"
    out += "te_types.graphql:5:5 ]\nError: inline fragment must have a c"
    out += "omposite type in its type condition\n╭─[ 0087_fragment_t"
    out += "ype_condition_on_composite_types.graphql:7:5 ]\nError: type "
    out += "`Int` does not have a field `name`\n╭─[ 0087_fragment_ty"
    out += "pe_condition_on_composite_types.graphql:8:7 ]\nError: fragme"
    out += "nt `fragOnScalar` must be used in an operation\n╭─[ 0087"
    out += "_fragment_type_condition_on_composite_types.graphql:21:1 ]\n"
    out += "Error: type `Int` does not have a field `name`\n╭─[ 0087"
    out += "_fragment_type_condition_on_composite_types.graphql:22:3 ]\n"
    out += "Error: inline fragment must have a composite type in its typ"
    out += "e condition\n╭─[ 0087_fragment_type_condition_on_composi"
    out += "te_types.graphql:26:3 ]\nError: type `Int` does not have a f"
    out += "ield `name`\n╭─[ 0087_fragment_type_condition_on_composi"
    out += "te_types.graphql:27:5 ]\n"
    return out^


def _path_84() -> String:
    var out = String()
    out += "diagnostics/0088_fragment_selection_set.graphql"
    return out^


def _input_84() -> String:
    var out = String()
    out += "type Query {\n  name: String\n  topProducts: Product\n}\n\nt"
    out += "ype Product {\n  inStock: Boolean\n  name: String\n}\n\nquer"
    out += "y getProduct {\n    name\n    topProduct {\n        ...produ"
    out += "ctFragment\n    }\n    topProducts {\n        ...productFrag"
    out += "ment\n    }\n}\n\nfragment productFragment on Product {\n  n"
    out += "otExistingField\n}"
    return out^


def _expected_84() -> String:
    var out = String()
    out += "Error: type `Query` does not have a field `topProduct`\n╭"
    out += "─[ 0088_fragment_selection_set.graphql:13:5 ]\nError: type"
    out += " `Product` does not have a field `notExistingField`\n╭─["
    out += " 0088_fragment_selection_set.graphql:22:3 ]\n"
    return out^


def _path_85() -> String:
    var out = String()
    out += "diagnostics/0089_fragment_type_condition_on_non_existent_typ"
    out += "es.graphql"
    return out^


def _input_85() -> String:
    var out = String()
    out += "query Query {\n  interface {\n    ...invalidFragmentConditio"
    out += "n\n    ...invalidInlineFragment\n    ... on MissingSecondTyp"
    out += "e {\n      a\n    }\n  }\n}\ntype Query {\n  interface: Inte"
    out += "rface\n}\ninterface Interface {\n  a: String\n}\n# interface"
    out += "s must have concrete implementations to be usable\ntype Just"
    out += "Implements implements Interface {\n  a: String\n}\n\nfragmen"
    out += "t invalidInlineFragment on Interface {\n  a\n  ... on Missin"
    out += "gType {\n    a\n  }\n}\n\nfragment invalidFragmentCondition "
    out += "on Interface2 {\n  a\n}\n"
    return out^


def _expected_85() -> String:
    var out = String()
    out += "Error: cannot find fragment `invalidFragmentCondition` in th"
    out += "is document\n╭─[ 0089_fragment_type_condition_on_non_exi"
    out += "stent_types.graphql:3:5 ]\nError: type condition `MissingSec"
    out += "ondType` of inline fragment is not a type defined in the sch"
    out += "ema\n╭─[ 0089_fragment_type_condition_on_non_existent_ty"
    out += "pes.graphql:5:12 ]\nError: type condition `MissingType` of i"
    out += "nline fragment is not a type defined in the schema\n╭─[ "
    out += "0089_fragment_type_condition_on_non_existent_types.graphql:2"
    out += "3:10 ]\nError: type condition `Interface2` of fragment `inva"
    out += "lidFragmentCondition` is not a type defined in the schema\n"
    out += "╭─[ 0089_fragment_type_condition_on_non_existent_types.g"
    out += "raphql:28:38 ]\n"
    return out^


def _path_86() -> String:
    var out = String()
    out += "diagnostics/0090_fragment_spread_impossible.graphql"
    return out^


def _input_86() -> String:
    var out = String()
    out += "type Query {\n    human: Human\n}\n\ninterface Sentient {\n "
    out += " name: String!\n}\n\ninterface Pet {\n  name: String!\n}\n\n"
    out += "type Dog implements Pet {\n  name: String!\n  barkVolume: In"
    out += "t\n}\n\ntype Cat implements Pet {\n  name: String!\n  meowVo"
    out += "lume: Int\n}\n\nunion CatOrDog = Cat | Dog\n\ntype Human imp"
    out += "lements Sentient {\n  name: String!\n  pets: [Pet!]\n}\n\nty"
    out += "pe Alien implements Sentient {\n  name: String!\n  homePlane"
    out += "t: String!\n}\n\nunion HumanOrAlien = Human | Alien\n\nquery"
    out += " getHuman {\n    human {\n        ...catInDogFragmentInvalid"
    out += "\n        ...sentientFragment\n        ...humanOrAlienFragme"
    out += "nt\n        ...nonIntersectingInterfaces\n        ...sentien"
    out += "tFragment2\n    }\n}\n\nfragment catInDogFragmentInvalid on "
    out += "Dog {\n  ... on Cat {\n    meowVolume\n  }\n}\n\nfragment se"
    out += "ntientFragment on Sentient {\n  ... on Dog {\n    barkVolume"
    out += "\n  }\n}\n\nfragment humanOrAlienFragment on HumanOrAlien {"
    out += "\n  ... on Cat {\n    meowVolume\n  }\n}\n\nfragment nonInte"
    out += "rsectingInterfaces on Pet {\n  ...sentientFragment2\n}\n\nfr"
    out += "agment sentientFragment2 on Sentient {\n  name\n}\n"
    return out^


def _expected_86() -> String:
    var out = String()
    out += "Error: fragment `catInDogFragmentInvalid` with type conditio"
    out += "n `Dog` cannot be applied to `Human`\n╭─[ 0090_fragment_"
    out += "spread_impossible.graphql:39:9 ]\nError: fragment `nonInters"
    out += "ectingInterfaces` with type condition `Pet` cannot be applie"
    out += "d to `Human`\n╭─[ 0090_fragment_spread_impossible.graphq"
    out += "l:42:9 ]\nError: inline fragment with type condition `Cat` c"
    out += "annot be applied to `Dog`\n╭─[ 0090_fragment_spread_impo"
    out += "ssible.graphql:48:3 ]\nError: inline fragment with type cond"
    out += "ition `Dog` cannot be applied to `Sentient`\n╭─[ 0090_fr"
    out += "agment_spread_impossible.graphql:54:3 ]\nError: inline fragm"
    out += "ent with type condition `Cat` cannot be applied to `HumanOrA"
    out += "lien`\n╭─[ 0090_fragment_spread_impossible.graphql:60:3 "
    out += "]\nError: fragment `sentientFragment2` with type condition `"
    out += "Sentient` cannot be applied to `Pet`\n╭─[ 0090_fragment_"
    out += "spread_impossible.graphql:66:3 ]\n"
    return out^


def _path_87() -> String:
    var out = String()
    out += "diagnostics/0091_recursive_interface_definition.graphql"
    return out^


def _input_87() -> String:
    var out = String()
    out += "interface A implements B {\n  name: String\n}\ninterface B i"
    out += "mplements A {\n  name: String\n}\ntype Impl implements A & B"
    out += " {\n  name: String\n}\ntype Query {\n  get: A\n}\n\nfragment"
    out += " recursive on A {\n  name\n}\n\nquery {\n  get { ...recursiv"
    out += "e }\n}\n"
    return out^


def _expected_87() -> String:
    var out = String()
    out += "Error: interface `A` declares that it implements `B`, but to"
    out += " do so it must also implement `A`\n╭─[ 0091_recursive_in"
    out += "terface_definition.graphql:1:1 ]\nError: interface `B` decla"
    out += "res that it implements `A`, but to do so it must also implem"
    out += "ent `B`\n╭─[ 0091_recursive_interface_definition.graphql"
    out += ":4:1 ]\n"
    return out^


def _path_88() -> String:
    var out = String()
    out += "diagnostics/0092_recursive_fragment_spread.graphql"
    return out^


def _input_88() -> String:
    var out = String()
    out += "# Schema\ntype Human {\n  name: String!\n}\ntype Query {\n  "
    out += "human: Human\n}\n\n# Query\n{\n  human { ...fragA }\n  __sch"
    out += "ema { types { ...cycle1 } }\n}\nfragment fragA on Human { na"
    out += "me, ...fragB }\nfragment fragB on Human { name, ...fragC }\n"
    out += "fragment fragC on Human { name, ...fragA }\n\n# Indirect cyc"
    out += "le\nfragment cycle1 on __Type { kind, ...cycle2 }\n\nfragmen"
    out += "t cycle2 on __Type {\n  kind\n  ofType { ...cycle1 }\n}\n"
    return out^


def _expected_88() -> String:
    var out = String()
    out += "Error: `fragA` fragment cannot reference itself\n╭─[ 009"
    out += "2_recursive_fragment_spread.graphql:14:1 ]\nError: `cycle1` "
    out += "fragment cannot reference itself\n╭─[ 0092_recursive_fra"
    out += "gment_spread.graphql:19:1 ]\n"
    return out^


def _path_89() -> String:
    var out = String()
    out += "diagnostics/0093_fragment_validation_with_recursive_type_sys"
    out += "tem.graphql"
    return out^


def _input_89() -> String:
    var out = String()
    out += "# ensure we don't get a stack overflow when the type system "
    out += "is recursive\ninterface A implements B {\n  a: A\n  b: B\n}"
    out += "\ninterface B implements A {\n  a: A\n  b: B\n}\n\ntype C im"
    out += "plements A & B {\n  a: A\n  b: B\n  value: Int!\n}\n\ntype Q"
    out += "uery {\n  c: C\n}\n\nfragment b on C {\n  value\n}\n\nquery "
    out += "{\n  c { ... b }\n}\n"
    return out^


def _expected_89() -> String:
    var out = String()
    out += "Error: interface `A` declares that it implements `B`, but to"
    out += " do so it must also implement `A`\n╭─[ 0093_fragment_val"
    out += "idation_with_recursive_type_system.graphql:2:1 ]\nError: int"
    out += "erface `B` declares that it implements `A`, but to do so it "
    out += "must also implement `B`\n╭─[ 0093_fragment_validation_wi"
    out += "th_recursive_type_system.graphql:6:1 ]\n"
    return out^


def _path_90() -> String:
    var out = String()
    out += "diagnostics/0094_object_type_extensions.graphql"
    return out^


def _input_90() -> String:
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


def _expected_90() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `age` field of object t"
    out += "ype `UniqueNames`\n╭─[ 0094_object_type_extensions.graph"
    out += "ql:6:3 ]\nError: duplicate definitions for the `name` field "
    out += "of object type `ConflictingNames`\n╭─[ 0094_object_type_"
    out += "extensions.graphql:13:3 ]\nError: non-repeatable directive n"
    out += "onRepeatable can only be used once per location\n╭─[ 009"
    out += "4_object_type_extensions.graphql:20:29 ]\nError: object type"
    out += " `UniqueInterfaces` implements interface `Base` more than on"
    out += "ce\n╭─[ 0094_object_type_extensions.graphql:31:41 ]\nErr"
    out += "or: type `ImplementsBaseButNotExtension` does not satisfy in"
    out += "terface `ExtendedInterface`: missing field `fail`\n╭─[ 0"
    out += "094_object_type_extensions.graphql:38:1 ]\n"
    return out^


def _path_91() -> String:
    var out = String()
    out += "diagnostics/0095_interface_implementation_declared_once.grap"
    out += "hql"
    return out^


def _input_91() -> String:
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


def _expected_91() -> String:
    var out = String()
    out += "Error: object type `Object` implements interface `Intf` more"
    out += " than once\n╭─[ 0095_interface_implementation_declared_o"
    out += "nce.graphql:5:31 ]\nError: object type `Extended` implements"
    out += " interface `Intf` more than once\n╭─[ 0095_interface_imp"
    out += "lementation_declared_once.graphql:12:33 ]\nError: interface "
    out += "type `SubIntf` implements interface `Intf` more than once\n"
    out += "╭─[ 0095_interface_implementation_declared_once.graphql:"
    out += "14:37 ]\n"
    return out^


def _path_92() -> String:
    var out = String()
    out += "diagnostics/0096_schema_extensions.graphql"
    return out^


def _input_92() -> String:
    var out = String()
    out += "# Any non-repeatable directives provided must not already ap"
    out += "ply to the original Schema.\ndirective @nonRepeatable on SCH"
    out += "EMA\n\ntype Query {\n  viewCount: Int!\n}\n\nschema @nonRepe"
    out += "atable {\n  query: Query\n}\nextend schema @nonRepeatable\n"
    return out^


def _expected_92() -> String:
    var out = String()
    out += "Error: non-repeatable directive nonRepeatable can only be us"
    out += "ed once per location\n╭─[ 0096_schema_extensions.graphql"
    out += ":11:15 ]\n"
    return out^


def _path_93() -> String:
    var out = String()
    out += "diagnostics/0097_enum_extensions.graphql"
    return out^


def _input_93() -> String:
    var out = String()
    out += "directive @nonRepeatable on ENUM\n\nenum E {\n  MEMBER_1\n  "
    out += "MEMBER_2\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_3\n "
    out += " MEMBER_4\n}\n\nextend enum E @nonRepeatable {\n  MEMBER_2\n"
    out += "  MEMBER_4\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_93() -> String:
    var out = String()
    out += "Error: non-repeatable directive nonRepeatable can only be us"
    out += "ed once per location\n╭─[ 0097_enum_extensions.graphql:1"
    out += "3:15 ]\nError: duplicate definitions for the `MEMBER_2` valu"
    out += "e of enum type `E`\n╭─[ 0097_enum_extensions.graphql:14:"
    out += "3 ]\nError: duplicate definitions for the `MEMBER_4` value o"
    out += "f enum type `E`\n╭─[ 0097_enum_extensions.graphql:15:3 ]"
    out += "\n"
    return out^


def _path_94() -> String:
    var out = String()
    out += "diagnostics/0098_interface_extensions.graphql"
    return out^


def _input_94() -> String:
    var out = String()
    out += "interface UniqueNames {\n  name: String\n}\nextend interface"
    out += " UniqueNames {\n  name: String\n}\n\ndirective @nonRepeatabl"
    out += "e on INTERFACE\n\ninterface Directives @nonRepeatable {\n  a"
    out += "ge: Int\n}\n\nextend interface Directives @nonRepeatable\n\n"
    out += "interface Base {\n  a: Int\n  b: Int\n  c: Int\n}\ninterface"
    out += " Derived {\n  a: Int\n}\nextend interface Derived implements"
    out += " Base {\n  c: Int\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_94() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `name` field of interfa"
    out += "ce type `UniqueNames`\n╭─[ 0098_interface_extensions.gra"
    out += "phql:5:3 ]\nError: non-repeatable directive nonRepeatable ca"
    out += "n only be used once per location\n╭─[ 0098_interface_ext"
    out += "ensions.graphql:14:29 ]\nError: type `Derived` does not sati"
    out += "sfy interface `Base`: missing field `b`\n╭─[ 0098_interf"
    out += "ace_extensions.graphql:21:1 ]\n"
    return out^


def _path_95() -> String:
    var out = String()
    out += "diagnostics/0099_input_object_extensions.graphql"
    return out^


def _input_95() -> String:
    var out = String()
    out += "input UniqueNames {\n  field: String\n}\nextend input Unique"
    out += "Names {\n  field: String\n}\n\ndirective @nonRepeatable on I"
    out += "NPUT_OBJECT\ninput UniqueDirective @nonRepeatable {\n  field"
    out += ": String\n}\nextend input UniqueDirective @nonRepeatable\n\n"
    out += "type Query {\n  x: Int\n}\n"
    return out^


def _expected_95() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `field` field of input "
    out += "object type `UniqueNames`\n╭─[ 0099_input_object_extensi"
    out += "ons.graphql:5:3 ]\nError: non-repeatable directive nonRepeat"
    out += "able can only be used once per location\n╭─[ 0099_input_"
    out += "object_extensions.graphql:12:30 ]\n"
    return out^


def _path_96() -> String:
    var out = String()
    out += "diagnostics/0100_union_extensions.graphql"
    return out^


def _input_96() -> String:
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


def _expected_96() -> String:
    var out = String()
    out += "Error: union member `ThisIsAScalar` must be an object type\n"
    out += "╭─[ 0100_union_extensions.graphql:8:30 ]\nError: duplica"
    out += "te definitions for the `WithFieldA` member of union type `Du"
    out += "plicateMembers`\n╭─[ 0100_union_extensions.graphql:12:33"
    out += " ]\nError: non-repeatable directive nonRepeatable can only b"
    out += "e used once per location\n╭─[ 0100_union_extensions.grap"
    out += "hql:17:33 ]\n"
    return out^


def _path_97() -> String:
    var out = String()
    out += "diagnostics/0101_mismatched_variable_usage.graphql"
    return out^


def _input_97() -> String:
    var out = String()
    out += "query intCannotGoIntoBoolean($intArg: Int) {\n  arguments {"
    out += "\n    booleanArgField(booleanArg: $intArg)\n  }\n}\n\nquery "
    out += "booleanListCannotGoIntoBoolean($booleanListArg: [Boolean]) {"
    out += "\n  arguments {\n    booleanArgField(booleanArg: $booleanLis"
    out += "tArg)\n  }\n}\n\nquery booleanArgQuery($booleanArg: Boolean)"
    out += " {\n  arguments {\n    nonNullBooleanArgField(nonNullBoolean"
    out += "Arg: $booleanArg)\n  }\n}\n\nquery listToNonNullList($boolea"
    out += "nList: [Boolean]) {\n  arguments {\n    nonNullBooleanListFi"
    out += "eld(nonNullBooleanListArg: $booleanList)\n  }\n}\n\nfragment"
    out += " nonNullIntArgFieldFrag on Arguments {\n    nonNullIntArgFie"
    out += "ld(nonNullIntArg: $intArg)\n}\n\nquery fragmentNonNullIntArg"
    out += "Field($intArg: Int) {\n    arguments {\n        ...nonNullIn"
    out += "tArgFieldFrag\n    }\n}\n\nfragment outerFrag on Arguments {"
    out += "\n    ...nonNullIntArgFieldInnerFrag\n}\n\nfragment nonNullI"
    out += "ntArgFieldInnerFrag on Arguments {\n    nonNullIntArgField(n"
    out += "onNullIntArg: $intArg)\n}\n\nquery doubleNestedFragmentNonNu"
    out += "llIntArgField($intArg: Int) {\n    arguments {\n        ...o"
    out += "uterFrag\n    }\n}\n\nquery intCannotGoIntoBooleanList($intA"
    out += "rg: Int) {\n    arguments {\n\tnonNullBooleanListField(nonNu"
    out += "llBooleanListArg: [$intArg])\n    }\n}\n\ntype Query {\n    "
    out += "arguments: Arguments\n}\n\ntype Arguments {\n    booleanArgF"
    out += "ield(booleanArg: Boolean): Boolean\n    nonNullIntArgField(n"
    out += "onNullIntArg: Int!): Int\n    nonNullBooleanArgField(nonNull"
    out += "BooleanArg: Boolean!): Boolean\n    nonNullBooleanListField("
    out += "nonNullBooleanListArg: [Boolean]!): Boolean\n}\n"
    return out^


def _expected_97() -> String:
    var out = String()
    out += "Error: variable `$intArg` of type `Int` cannot be used for a"
    out += "rgument `booleanArg` of type `Boolean`\n╭─[ 0101_mismatc"
    out += "hed_variable_usage.graphql:3:21 ]\nError: variable `$boolean"
    out += "ListArg` of type `[Boolean]` cannot be used for argument `bo"
    out += "oleanArg` of type `Boolean`\n╭─[ 0101_mismatched_variabl"
    out += "e_usage.graphql:9:21 ]\nError: variable `$booleanArg` of typ"
    out += "e `Boolean` cannot be used for argument `nonNullBooleanArg` "
    out += "of type `Boolean!`\n╭─[ 0101_mismatched_variable_usage.g"
    out += "raphql:15:28 ]\nError: variable `$booleanList` of type `[Boo"
    out += "lean]` cannot be used for argument `nonNullBooleanListArg` o"
    out += "f type `[Boolean]!`\n╭─[ 0101_mismatched_variable_usage."
    out += "graphql:21:29 ]\nError: variable `$intArg` of type `Int` can"
    out += "not be used for argument `nonNullIntArg` of type `Int!`\n╭"
    out += "─[ 0101_mismatched_variable_usage.graphql:26:24 ]\nError: "
    out += "variable `$intArg` of type `Int` cannot be used for argument"
    out += " `nonNullIntArg` of type `Int!`\n╭─[ 0101_mismatched_var"
    out += "iable_usage.graphql:40:24 ]\nError: expected value of type B"
    out += "oolean, found a variable\n╭─[ 0101_mismatched_variable_u"
    out += "sage.graphql:51:50 ]\n"
    return out^


def _path_98() -> String:
    var out = String()
    out += "diagnostics/0102_invalid_string_values.graphql"
    return out^


def _input_98() -> String:
    var out = String()
    out += "\ntype ComplicatedArgs {\n  # TODO List\n  # TODO Coercion\n"
    out += "  # TODO NotNulls\n  intArgField(intArg: Int): String\n  non"
    out += "NullIntArgField(nonNullIntArg: Int!): String\n  stringArgFie"
    out += "ld(stringArg: String): String\n  booleanArgField(booleanArg:"
    out += " Boolean): String\n  enumArgField(enumArg: FurColor): String"
    out += "\n  floatArgField(floatArg: Float): String\n  idArgField(idA"
    out += "rg: ID): String\n  stringListArgField(stringListArg: [String"
    out += "]): String\n  stringListNonNullArgField(stringListNonNullArg"
    out += ": [String!]): String\n  complexArgField(complexArg: ComplexI"
    out += "nput): String\n  multipleReqs(req1: Int!, req2: Int!): Strin"
    out += "g\n  nonNullFieldWithDefault(arg: Int! = 0): String\n  multi"
    out += "pleOpts(opt1: Int = 0, opt2: Int = 0): String\n  multipleOpt"
    out += "AndReq(req1: Int!, req2: Int!, opt1: Int = 0, opt2: Int = 0)"
    out += ": String\n}\n\nenum FurColor {\n  BROWN\n  BLACK\n  TAN\n  S"
    out += "POTTED\n  NO_FUR\n  UNKNOWN\n}\n\ninput ComplexInput {\n  re"
    out += "quiredField: Boolean!\n  nonNullField: Boolean! = false\n  i"
    out += "ntField: Int\n  stringField: String\n  booleanField: Boolean"
    out += "\n  stringListField: [String]\n}\n\nenum DogCommand {\n  SIT"
    out += "\n  HEEL\n  DOWN\n}\n\ntype Dog {\n  doesKnowCommand(dogComm"
    out += "and: DogCommand): Boolean\n  name(surname: Boolean): String"
    out += "\n  isHouseTrained(atOtherHomes: Boolean = true): Boolean\n}"
    out += "\n\ninterface Pet {\n  name(surname: Boolean): String\n}\n\n"
    out += "type Query {\n  complicatedArgs: ComplicatedArgs\n  dog: Dog"
    out += "\n  human(id: ID): Human\n}\n\ntype Human {\n  name(surname:"
    out += " Boolean): String\n  pets: [Pet]\n  relatives: [Human]!\n}\n"
    out += "\n\nquery intIntoString {\n  complicatedArgs {\n    stringAr"
    out += "gField(stringArg: 1)\n  }\n}\n\nquery floatIntoString {\n  c"
    out += "omplicatedArgs {\n    stringArgField(stringArg: 1.0)\n  }\n}"
    out += "\n\nquery booleanIntoString {\n  complicatedArgs {\n    stri"
    out += "ngArgField(stringArg: true)\n  }\n}\n\nquery unquotedStringI"
    out += "ntoString {\n  complicatedArgs {\n    stringArgField(stringA"
    out += "rg: BAR)\n  }\n}\n\nquery stringIntoInt {\n  complicatedArgs"
    out += ' {\n    intArgField(intArg: "3")\n  }\n}\n\nquery bigIntIn'
    out += "toInt {\n  complicatedArgs {\n    intArgField(intArg: 829384"
    out += "293849283498239482938)\n  }\n}\n\nquery unquotedStringIntoIn"
    out += "t {\n  complicatedArgs {\n    intArgField(intArg: FOO)\n  }"
    out += "\n}\n\nquery simpleFloatIntoInt {\n  complicatedArgs {\n    "
    out += "intArgField(intArg: 3.0)\n  }\n}\n\nquery floatIntoInt {\n  "
    out += "complicatedArgs {\n    intArgField(intArg: 3.333)\n  }\n}\n"
    out += "\nquery stringIntoFloat {\n  complicatedArgs {\n    floatArg"
    out += 'Field(floatArg: "3.333")\n  }\n}\n\nquery booleanIntoFloat'
    out += " {\n  complicatedArgs {\n    floatArgField(floatArg: true)\n"
    out += "  }\n}\n\nquery unquotedIntoFloat {\n  complicatedArgs {\n  "
    out += "  floatArgField(floatArg: FOO)\n  }\n}\n\nquery intIntoBoole"
    out += "an {\n  complicatedArgs {\n    booleanArgField(booleanArg: 2"
    out += ")\n  }\n}\n\nquery floatIntoBoolean {\n  complicatedArgs {\n"
    out += "    booleanArgField(booleanArg: 1.0)\n  }\n}\n\nquery string"
    out += "IntoBoolean {\n  complicatedArgs {\n    booleanArgField(bool"
    out += 'eanArg: "true")\n  }\n}\n\nquery unquotedIntoBoolean {\n  '
    out += "complicatedArgs {\n    booleanArgField(booleanArg: TRUE)\n  "
    out += "}\n}\n\nquery floatIntoId {\n  complicatedArgs {\n    idArgF"
    out += "ield(idArg: 1.0)\n  }\n}\n\nquery booleanIntoID {\n  complic"
    out += "atedArgs {\n    idArgField(idArg: true)\n  }\n}\n\nquery unq"
    out += "uotedIntoID {\n  complicatedArgs {\n    idArgField(idArg: SO"
    out += "METHING)\n  }\n}\n\n# Invalid Enum Value\nquery intIntoEnum "
    out += "{\n  dog {\n    doesKnowCommand(dogCommand: 2)\n  }\n}\n\nqu"
    out += "ery floatIntoEnum {\n  dog {\n    doesKnowCommand(dogCommand"
    out += ": 1.0)\n  }\n}\n\nquery stringIntoEnum {\n  dog {\n    doesK"
    out += 'nowCommand(dogCommand: "SIT")\n  }\n}\n\nquery booleanInto'
    out += "Enum {\n  dog {\n    doesKnowCommand(dogCommand: true)\n  }"
    out += "\n}\n\nquery unknownEnumValueIntoEnum {\n  dog {\n    doesKn"
    out += "owCommand(dogCommand: JUGGLE)\n  }\n}\n\nquery differentCase"
    out += "EnumValueIntoEnum {\n  dog {\n    doesKnowCommand(dogCommand"
    out += ": sit)\n  }\n}\n\nquery incorrectListItemType {\n  complicat"
    out += 'edArgs {\n    stringListArgField(stringListArg: ["one", 2]'
    out += ")\n  }\n}\n\nquery singleValueOfIncorrectType {\n  complicat"
    out += "edArgs {\n    stringListArgField(stringListArg: 1)\n  }\n}\n"
    out += "\n# Invalid non-nullable value\nquery incorrectValueType {\n"
    out += '  complicatedArgs {\n    multipleReqs(req2: "two", req1: '
    out += '"one")\n  }\n}\n\nquery incorrectValueAndMissingArgument {'
    out += '\n  complicatedArgs {\n    multipleReqs(req1: "one")\n  }'
    out += "\n}\n\nquery nullValue {\n  complicatedArgs {\n    multipleR"
    out += "eqs(req1: null)\n  }\n}\n\n# InvalidInputObjectValue\nquery "
    out += "partialObjectMissingField {\n  complicatedArgs {\n    comple"
    out += "xArgField(complexArg: { intField: 4 })\n  }\n}\n\nquery part"
    out += "ialObjectInvalidFieldType {\n  complicatedArgs {\n    comple"
    out += 'xArgField(complexArg: {\n      stringListField: ["one", 2]'
    out += ",\n      requiredField: true,\n    })\n  }\n}\n\nquery parti"
    out += "alObjectNullToNonNullField {\n  complicatedArgs {\n    compl"
    out += "exArgField(complexArg: {\n      requiredField: true,\n      "
    out += "nonNullField: null,\n    })\n  }\n}\n\nquery partialObjectUn"
    out += "knownFieldArg {\n  complicatedArgs {\n    complexArgField(co"
    out += "mplexArg: {\n      requiredField: true,\n      invalidField:"
    out += ' "value"\n    })\n  }\n}\n\n# Directive arguments\nquery w'
    out += 'ithDirectiveWithIncorrectTypes {\n  dog @include(if: "yes"'
    out += ") {\n    name @skip(if: ENUM)\n  }\n}\n\n# Variable default "
    out += "values\nquery variablesWithInvalidDefaultNullValues(\n  $a: "
    out += "Int! = null,\n  $b: String! = null,\n  $c: ComplexInput = { "
    out += "requiredField: null, intField: null }\n) {\n  complicatedArg"
    out += "s {\n    complexArgField(complexArg: $c)\n    intArgField(in"
    out += "tArg: $a)\n    stringArgField(stringArg: $b)\n  }\n}\n\nquer"
    out += 'y variablesWithInvalidDefaultValues(\n  $a: Int = "one",\n'
    out += '  $b: String = 4,\n  $c: ComplexInput = "NotVeryComplex"\n'
    out += ") {\n  complicatedArgs {\n    complexArgField(complexArg: $c"
    out += ")\n    intArgField(intArg: $a)\n    stringArgField(stringArg"
    out += ": $b)\n    again: stringArgField(stringArg: $b)\n  }\n}\n\nq"
    out += "uery variablesWithComplexInvalidDefaultValues(\n  $a: Comple"
    out += 'xInput = { requiredField: 123, intField: "abc" }\n) {\n  c'
    out += "omplicatedArgs {\n    complexArgField(complexArg: $a)\n  }\n"
    out += "}\n\nquery complexVariablesMissingRequiredField(\n  $a: Comp"
    out += "lexInput = {intField: 3}\n) {\n  complicatedArgs {\n    comp"
    out += "lexArgField(complexArg: $a)\n  }\n\n}\n\nquery listVariables"
    out += 'WithInvalidItem(\n  $a: [String] = ["one", 2]\n) {\n  comp'
    out += "licatedArgs {\n    stringListArgField(stringListArg: $a)\n  "
    out += "}\n}"
    return out^


def _expected_98() -> String:
    var out = String()
    out += "Error: expected value of type String, found an integer\n╭"
    out += "─[ 0102_invalid_string_values.graphql:71:31 ]\nError: expe"
    out += "cted value of type String, found a float\n╭─[ 0102_inval"
    out += "id_string_values.graphql:77:31 ]\nError: expected value of t"
    out += "ype String, found a boolean\n╭─[ 0102_invalid_string_val"
    out += "ues.graphql:83:31 ]\nError: expected value of type String, f"
    out += "ound an enum\n╭─[ 0102_invalid_string_values.graphql:89:"
    out += "31 ]\nError: expected value of type Int, found a string\n╭"
    out += "─[ 0102_invalid_string_values.graphql:95:25 ]\nError: int "
    out += "cannot represent non 32-bit signed integer value\n╭─[ 01"
    out += "02_invalid_string_values.graphql:101:25 ]\nError: expected v"
    out += "alue of type Int, found an enum\n╭─[ 0102_invalid_string"
    out += "_values.graphql:107:25 ]\nError: expected value of type Int,"
    out += " found a float\n╭─[ 0102_invalid_string_values.graphql:1"
    out += "13:25 ]\nError: expected value of type Int, found a float\n"
    out += "╭─[ 0102_invalid_string_values.graphql:119:25 ]\nError: "
    out += "expected value of type Float, found a string\n╭─[ 0102_i"
    out += "nvalid_string_values.graphql:125:29 ]\nError: expected value"
    out += " of type Float, found a boolean\n╭─[ 0102_invalid_string"
    out += "_values.graphql:131:29 ]\nError: expected value of type Floa"
    out += "t, found an enum\n╭─[ 0102_invalid_string_values.graphql"
    out += ":137:29 ]\nError: expected value of type Boolean, found an i"
    out += "nteger\n╭─[ 0102_invalid_string_values.graphql:143:33 ]"
    out += "\nError: expected value of type Boolean, found a float\n╭"
    out += "─[ 0102_invalid_string_values.graphql:149:33 ]\nError: exp"
    out += "ected value of type Boolean, found a string\n╭─[ 0102_in"
    out += "valid_string_values.graphql:155:33 ]\nError: expected value "
    out += "of type Boolean, found an enum\n╭─[ 0102_invalid_string_"
    out += "values.graphql:161:33 ]\nError: expected value of type ID, f"
    out += "ound a float\n╭─[ 0102_invalid_string_values.graphql:167"
    out += ":23 ]\nError: expected value of type ID, found a boolean\n"
    out += "╭─[ 0102_invalid_string_values.graphql:173:23 ]\nError: "
    out += "expected value of type ID, found an enum\n╭─[ 0102_inval"
    out += "id_string_values.graphql:179:23 ]\nError: expected value of "
    out += "type DogCommand, found an integer\n╭─[ 0102_invalid_stri"
    out += "ng_values.graphql:186:33 ]\nError: expected value of type Do"
    out += "gCommand, found a float\n╭─[ 0102_invalid_string_values."
    out += "graphql:192:33 ]\nError: expected value of type DogCommand, "
    out += "found a string\n╭─[ 0102_invalid_string_values.graphql:1"
    out += "98:33 ]\nError: expected value of type DogCommand, found a b"
    out += "oolean\n╭─[ 0102_invalid_string_values.graphql:204:33 ]"
    out += "\nError: value `JUGGLE` does not exist on `DogCommand`\n╭"
    out += "─[ 0102_invalid_string_values.graphql:210:33 ]\nError: val"
    out += "ue `sit` does not exist on `DogCommand`\n╭─[ 0102_invali"
    out += "d_string_values.graphql:216:33 ]\nError: expected value of t"
    out += "ype String, found an integer\n╭─[ 0102_invalid_string_va"
    out += "lues.graphql:222:47 ]\nError: expected value of type [String"
    out += "], found an integer\n╭─[ 0102_invalid_string_values.grap"
    out += "hql:228:39 ]\nError: expected value of type Int!, found a st"
    out += "ring\n╭─[ 0102_invalid_string_values.graphql:235:24 ]\nE"
    out += "rror: expected value of type Int!, found a string\n╭─[ 0"
    out += "102_invalid_string_values.graphql:235:37 ]\nError: the requi"
    out += "red argument `ComplicatedArgs.multipleReqs(req2:)` is not pr"
    out += "ovided\n╭─[ 0102_invalid_string_values.graphql:241:5 ]\n"
    out += "Error: expected value of type Int!, found a string\n╭─[ "
    out += "0102_invalid_string_values.graphql:241:24 ]\nError: the requ"
    out += "ired argument `ComplicatedArgs.multipleReqs(req1:)` is not p"
    out += "rovided\n╭─[ 0102_invalid_string_values.graphql:247:5 ]"
    out += "\nError: the required argument `ComplicatedArgs.multipleReqs"
    out += "(req2:)` is not provided\n╭─[ 0102_invalid_string_values"
    out += ".graphql:247:5 ]\nError: expected value of type Int!, found "
    out += "null\n╭─[ 0102_invalid_string_values.graphql:247:24 ]\nE"
    out += "rror: the required field `ComplexInput.requiredField` is not"
    out += " provided\n╭─[ 0102_invalid_string_values.graphql:254:33"
    out += " ]\nError: expected value of type String, found an integer\n"
    out += "╭─[ 0102_invalid_string_values.graphql:261:32 ]\nError: "
    out += "expected value of type Boolean!, found null\n╭─[ 0102_in"
    out += "valid_string_values.graphql:271:21 ]\nError: field `invalidF"
    out += "ield` does not exist on `ComplexInput`\n╭─[ 0102_invalid"
    out += "_string_values.graphql:280:21 ]\nError: expected value of ty"
    out += "pe Boolean!, found a string\n╭─[ 0102_invalid_string_val"
    out += "ues.graphql:287:20 ]\nError: expected value of type Boolean!"
    out += ", found an enum\n╭─[ 0102_invalid_string_values.graphql:"
    out += "288:20 ]\nError: expected value of type Int!, found null\n"
    out += "╭─[ 0102_invalid_string_values.graphql:294:14 ]\nError: "
    out += "expected value of type String!, found null\n╭─[ 0102_inv"
    out += "alid_string_values.graphql:295:17 ]\nError: the required fie"
    out += "ld `ComplexInput.requiredField` is not provided\n╭─[ 010"
    out += "2_invalid_string_values.graphql:296:22 ]\nError: expected va"
    out += "lue of type Boolean!, found null\n╭─[ 0102_invalid_strin"
    out += "g_values.graphql:296:39 ]\nError: expected value of type Int"
    out += ", found a string\n╭─[ 0102_invalid_string_values.graphql"
    out += ":306:13 ]\nError: expected value of type String, found an in"
    out += "teger\n╭─[ 0102_invalid_string_values.graphql:307:16 ]\n"
    out += "Error: expected value of type ComplexInput, found a string\n"
    out += "╭─[ 0102_invalid_string_values.graphql:308:22 ]\nError: "
    out += "expected value of type Boolean!, found an integer\n╭─[ 0"
    out += "102_invalid_string_values.graphql:319:39 ]\nError: expected "
    out += "value of type Int, found a string\n╭─[ 0102_invalid_stri"
    out += "ng_values.graphql:319:54 ]\nError: the required field `Compl"
    out += "exInput.requiredField` is not provided\n╭─[ 0102_invalid"
    out += "_string_values.graphql:327:22 ]\nError: expected value of ty"
    out += "pe String, found an integer\n╭─[ 0102_invalid_string_val"
    out += "ues.graphql:336:26 ]\n"
    return out^


def _path_99() -> String:
    var out = String()
    out += "diagnostics/0103_invalid_directive_on_input_value.graphql"
    return out^


def _input_99() -> String:
    var out = String()
    out += "directive @example(arg: String!) on INPUT_FIELD_DEFINITION |"
    out += " ARGUMENT_DEFINITION\n\ninput Input {\n  key: String! @examp"
    out += "le\n}\n\ndirective @directive(arg2: Int @example) on SCHEMA"
    out += "\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_99() -> String:
    var out = String()
    out += "Error: the required argument `@example(arg:)` is not provide"
    out += "d\n╭─[ 0103_invalid_directive_on_input_value.graphql:4:1"
    out += "6 ]\nError: the required argument `@example(arg:)` is not pr"
    out += "ovided\n╭─[ 0103_invalid_directive_on_input_value.graphq"
    out += "l:7:32 ]\n"
    return out^


def _path_100() -> String:
    var out = String()
    out += "diagnostics/0104_invalid_type_in_arg.graphql"
    return out^


def _input_100() -> String:
    var out = String()
    out += 'scalar AnInputType @specifiedBy(url: "http://example.com")'
    out += "\ntype OutputType {\n  not: AnInputType\n}\n\ninput InputObj"
    out += "ectWithOutputType {\n  thisIsWrong: OutputType\n}\n\ntype Ro"
    out += "ot {\n  id: ID!\n  undefinedTypes(a: number, b: number): Ope"
    out += "rationResult!\n  outputTypes(a: OutputType, b: OperationResu"
    out += "lt): ID!\n}\n\nunion OperationResult = Operation\n\ntype Ope"
    out += "ration {\n  id: ID!\n}\n\ntype Query {\n  x: Int\n}\n"
    return out^


def _expected_100() -> String:
    var out = String()
    out += "Error: `thisIsWrong` field must be of an input type\n╭─["
    out += " 0104_invalid_type_in_arg.graphql:7:3 ]\nError: cannot find "
    out += "type `number` in this document\n╭─[ 0104_invalid_type_in"
    out += "_arg.graphql:12:21 ]\nError: cannot find type `number` in th"
    out += "is document\n╭─[ 0104_invalid_type_in_arg.graphql:12:32 "
    out += "]\nError: `a` field must be of an input type\n╭─[ 0104_i"
    out += "nvalid_type_in_arg.graphql:13:15 ]\nError: `b` field must be"
    out += " of an input type\n╭─[ 0104_invalid_type_in_arg.graphql:"
    out += "13:30 ]\n"
    return out^


def _path_101() -> String:
    var out = String()
    out += "diagnostics/0105_executable_definition_in_type_system_docume"
    out += "nt.graphql"
    return out^


def _input_101() -> String:
    var out = String()
    out += "type Query {\n  field: Int\n}\n\nquery {\n  field\n}\n"
    return out^


def _expected_101() -> String:
    var out = String()
    out += "Error: a schema document must not contain an operation defin"
    out += "ition\n╭─[ 0105_executable_definition_in_type_system_doc"
    out += "ument.graphql:5:1 ]\n"
    return out^


def _path_102() -> String:
    var out = String()
    out += "diagnostics/0106_type_system_definition_in_executable_docume"
    out += "nt.graphql"
    return out^


def _input_102() -> String:
    var out = String()
    out += "type Query {\n  field: Int\n}\n\nquery {\n  field\n}\n"
    return out^


def _expected_102() -> String:
    var out = String()
    out += "Error: an executable document must not contain an object typ"
    out += "e definition\n╭─[ 0106_type_system_definition_in_executa"
    out += "ble_document.graphql:1:1 ]\n"
    return out^


def _path_103() -> String:
    var out = String()
    out += "diagnostics/0107_built_in_directive_double_redefinition.grap"
    out += "hql"
    return out^


def _input_103() -> String:
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


def _expected_103() -> String:
    var out = String()
    out += "Error: the directive `@deprecated` is defined multiple times"
    out += " in the schema\n╭─[ 0107_built_in_directive_double_redef"
    out += "inition.graphql:22:12 ]\n"
    return out^


def _path_104() -> String:
    var out = String()
    out += "diagnostics/0108_implicit_schema_extension.graphql"
    return out^


def _input_104() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\nextend schema {\n    qu"
    out += "ery: Query\n}"
    return out^


def _expected_104() -> String:
    var out = String()
    out += "Error: duplicate definitions for the `query` root operation "
    out += "type\n╭─[ 0108_implicit_schema_extension.graphql:6:5 ]\n"
    return out^


def _path_105() -> String:
    var out = String()
    out += "diagnostics/0109_null_in_list_issue_738.graphql"
    return out^


def _input_105() -> String:
    var out = String()
    out += 'scalar CustomScalar @specifiedBy(url: "https://example.com'
    out += '")\n\ninput WithList {\n  list: [String!]\n}\n\ntype Query '
    out += "{\n  foo(arg: [CustomScalar!]!): String!\n  bar(arg: [String"
    out += "!]): String!\n  list(arg: WithList): String!\n}\n\n{\n  a: f"
    out += 'oo(arg: [null, 1])\n  b: foo(arg: [null, null, "hello"])\n'
    out += '  bar(arg: [null])\n  list(arg: {list: ["ok", null]})\n}\n'
    return out^


def _expected_105() -> String:
    var out = String()
    out += "Error: expected value of type CustomScalar!, found null\n╭"
    out += "─[ 0109_null_in_list_issue_738.graphql:14:16 ]\nError: exp"
    out += "ected value of type CustomScalar!, found null\n╭─[ 0109_"
    out += "null_in_list_issue_738.graphql:15:16 ]\nError: expected valu"
    out += "e of type CustomScalar!, found null\n╭─[ 0109_null_in_li"
    out += "st_issue_738.graphql:15:22 ]\nError: expected value of type "
    out += "String!, found null\n╭─[ 0109_null_in_list_issue_738.gra"
    out += "phql:16:13 ]\nError: expected value of type String!, found n"
    out += "ull\n╭─[ 0109_null_in_list_issue_738.graphql:17:27 ]\n"
    return out^


def _path_106() -> String:
    var out = String()
    out += "diagnostics/0110_list_usage_in_non_list_type.graphql"
    return out^


def _input_106() -> String:
    var out = String()
    out += 'scalar CustomScalar @specifiedBy(url: "https://example.com'
    out += '")\n\ninput Args {\n  ok: CustomScalar # should accept a li'
    out += "st\n  int: Int!\n  str: String!\n  bool: Boolean!\n  opt: In"
    out += "t\n  id: ID!\n  list: [Int]\n}\n\ntype Query {\n  field(args"
    out += ": Args): String!\n}\n\nquery {\n  field(args: {\n    ok: [1,"
    out += ' "2", 3, []]\n    int: [1, 2, 3]\n    str: ["1"]\n    bo'
    out += 'ol: [true, false]\n    opt: [1, 2, 3]\n    id: [1, "2", 3]'
    out += "\n    list: [1, 2, 3]\n  })\n}\n"
    return out^


def _expected_106() -> String:
    var out = String()
    out += "Error: expected value of type Int!, found a list\n╭─[ 01"
    out += "10_list_usage_in_non_list_type.graphql:20:10 ]\nError: expec"
    out += "ted value of type String!, found a list\n╭─[ 0110_list_u"
    out += "sage_in_non_list_type.graphql:21:10 ]\nError: expected value"
    out += " of type Boolean!, found a list\n╭─[ 0110_list_usage_in_"
    out += "non_list_type.graphql:22:11 ]\nError: expected value of type"
    out += " Int, found a list\n╭─[ 0110_list_usage_in_non_list_type"
    out += ".graphql:23:10 ]\nError: expected value of type ID!, found a"
    out += " list\n╭─[ 0110_list_usage_in_non_list_type.graphql:24:9"
    out += " ]\n"
    return out^


def _path_107() -> String:
    var out = String()
    out += "diagnostics/0111_const_value.graphql"
    return out^


def _input_107() -> String:
    var out = String()
    out += "query(\n    $var1: Boolean!\n    $var2: Boolean! = $var1\n) "
    out += "{\n    f1 @include(if: $var1)\n    f2 @include(if: $var2)\n}"
    out += "\n\ndirective @someDir(arg: Boolean) on OBJECT\n\ntype Query"
    out += " @someDir(arg: $var1) {\n    f1: Int\n    f2: Int\n}\n"
    return out^


def _expected_107() -> String:
    var out = String()
    out += "Error: syntax error: unexpected variable value in a Const co"
    out += "ntext\n╭─[ 0111_const_value.graphql:3:23 ]\nError: varia"
    out += "ble `$var1` is not defined\n╭─[ 0111_const_value.graphql"
    out += ":3:23 ]\nError: syntax error: unexpected variable value in a"
    out += " Const context\n╭─[ 0111_const_value.graphql:11:26 ]\nEr"
    out += "ror: variable `$var1` is not defined\n╭─[ 0111_const_val"
    out += "ue.graphql:11:26 ]\n"
    return out^


def _path_108() -> String:
    var out = String()
    out += "diagnostics/0112_anonymous_subscription_with_multiple_root_f"
    out += "ields.graphql"
    return out^


def _input_108() -> String:
    var out = String()
    out += "subscription {\n  newMessage {\n    body\n    sender\n  }\n "
    out += " disallowedSecondRootField\n}\n\ntype Subscription {\n  newM"
    out += "essage: Result\n  disallowedSecondRootField: String\n}\n\nty"
    out += "pe Result {\n  body: String,\n  sender: String\n}\n\ntype Qu"
    out += "ery {\n  message: String\n}\n"
    return out^


def _expected_108() -> String:
    var out = String()
    out += "Error: anonymous subscription can only have one root field\n"
    out += "╭─[ 0112_anonymous_subscription_with_multiple_root_field"
    out += "s.graphql:1:1 ]\n"
    return out^


def _path_109() -> String:
    var out = String()
    out += "diagnostics/0113_partially_overlapping_fragments.graphql"
    return out^


def _input_109() -> String:
    var out = String()
    out += "type A {\n  unrelated: String\n  overlapping: Int\n}\ntype B"
    out += " {\n  overlapping: Int!\n}\ntype C {\n  overlapping: Int\n}"
    out += "\nunion Union = A | B | C\ntype Query {\n  root: Union\n}\n"
    out += "\n# There is a conflicting type due to `B.overlapping` and `"
    out += "C.overlapping` both being selected\n# to `root.overlapping`,"
    out += " but neither overlap with the initial selection set for `roo"
    out += "t`.\n\n{\n  root {\n    ... on A { unrelated }\n  }\n  root "
    out += "{\n    ... on B { overlapping }\n  }\n  root {\n    ... on C"
    out += " { overlapping }\n  }\n}\n"
    return out^


def _expected_109() -> String:
    var out = String()
    out += "Error: operation must not select different types using the s"
    out += "ame name `overlapping`\n╭─[ 0113_partially_overlapping_f"
    out += "ragments.graphql:27:16 ]\n"
    return out^


def _path_110() -> String:
    var out = String()
    out += "diagnostics/0114_interface_definition_with_missing_fields.gr"
    out += "aphql"
    return out^


def _input_110() -> String:
    var out = String()
    out += "directive @foo on INTERFACE\ntype Query {\n    foo: Node\n}"
    out += "\n\ninterface Node\n\nextend interface Node @foo"
    return out^


def _expected_110() -> String:
    var out = String()
    out += "Error: `Node` has no fields\n╭─[ 0114_interface_definiti"
    out += "on_with_missing_fields.graphql:6:1 ]\n"
    return out^


def _path_111() -> String:
    var out = String()
    out += "diagnostics/0115_object_definition_with_missing_fields.graph"
    out += "ql"
    return out^


def _input_111() -> String:
    var out = String()
    out += "directive @foo on OBJECT\ndirective @bar on OBJECT\ntype Que"
    out += "ry {\n    foo: User\n}\n\ntype User @foo\n\nextend type User"
    out += " @bar\n"
    return out^


def _expected_111() -> String:
    var out = String()
    out += "Error: `User` has no fields\n╭─[ 0115_object_definition_"
    out += "with_missing_fields.graphql:7:1 ]\n"
    return out^


def _path_112() -> String:
    var out = String()
    out += "diagnostics/0116_enum_definition_with_missing_values.graphql"
    return out^


def _input_112() -> String:
    var out = String()
    out += "directive @foo on ENUM\ntype Query {\n    foo: WEEKDAY\n}\n"
    out += "\nenum WEEKDAY\n\nextend enum WEEKDAY @foo"
    return out^


def _expected_112() -> String:
    var out = String()
    out += "Error: `WEEKDAY` has no enum values\n╭─[ 0116_enum_defin"
    out += "ition_with_missing_values.graphql:6:1 ]\n"
    return out^


def _path_113() -> String:
    var out = String()
    out += "diagnostics/0117_union_definition_with_missing_members.graph"
    out += "ql"
    return out^


def _input_113() -> String:
    var out = String()
    out += "directive @foo on UNION\ntype Query {\n    foo: Search\n}\n"
    out += "\nunion Search\n\nextend union Search @foo"
    return out^


def _expected_113() -> String:
    var out = String()
    out += "Error: `Search` has no member types\n╭─[ 0117_union_defi"
    out += "nition_with_missing_members.graphql:6:1 ]\n"
    return out^


def _path_114() -> String:
    var out = String()
    out += "diagnostics/0118_input_object_definition_with_missing_values"
    out += ".graphql"
    return out^


def _input_114() -> String:
    var out = String()
    out += "directive @foo on INPUT_OBJECT\ntype Query {\n    foo(id: In"
    out += "): String\n}\n\ninput In\n\nextend input In @foo"
    return out^


def _expected_114() -> String:
    var out = String()
    out += "Error: `In` has no input values\n╭─[ 0118_input_object_d"
    out += "efinition_with_missing_values.graphql:6:1 ]\n"
    return out^


def _path_115() -> String:
    var out = String()
    out += "diagnostics/0119_reserved_names.graphql"
    return out^


def _input_115() -> String:
    var out = String()
    out += "directive @__Prime(__if: Boolean!) on SCHEMA\n\nschema @__Pr"
    out += "ime(__if: true) {\n    query: __MyQuery\n}\n\ntype __MyQuery"
    out += " {\n    __secretField(__heatedArgument: __In): Int\n}\n\ninp"
    out += "ut __In {\n    __amount: __BigInt\n}\n\nscalar __BigInt\n\ne"
    out += "num __Maybe {\n    Yes\n    No\n    __FileNotFound\n}\n"
    return out^


def _expected_115() -> String:
    var out = String()
    out += "Error: a directive definition cannot be named `__Prime` as n"
    out += "ames starting with two underscores are reserved\n╭─[ 011"
    out += "9_reserved_names.graphql:1:12 ]\nError: an argument cannot b"
    out += "e named `__if` as names starting with two underscores are re"
    out += "served\n╭─[ 0119_reserved_names.graphql:1:20 ]\nError: a"
    out += "n object type cannot be named `__MyQuery` as names starting "
    out += "with two underscores are reserved\n╭─[ 0119_reserved_nam"
    out += "es.graphql:7:6 ]\nError: a field cannot be named `__secretFi"
    out += "eld` as names starting with two underscores are reserved\n"
    out += "╭─[ 0119_reserved_names.graphql:8:5 ]\nError: an argumen"
    out += "t cannot be named `__heatedArgument` as names starting with "
    out += "two underscores are reserved\n╭─[ 0119_reserved_names.gr"
    out += "aphql:8:19 ]\nError: an input object type cannot be named `_"
    out += "_In` as names starting with two underscores are reserved\n"
    out += "╭─[ 0119_reserved_names.graphql:11:7 ]\nError: an input "
    out += "object field cannot be named `__amount` as names starting wi"
    out += "th two underscores are reserved\n╭─[ 0119_reserved_names"
    out += ".graphql:12:5 ]\nError: a scalar type cannot be named `__Big"
    out += "Int` as names starting with two underscores are reserved\n"
    out += "╭─[ 0119_reserved_names.graphql:15:8 ]\nError: an enum t"
    out += "ype cannot be named `__Maybe` as names starting with two und"
    out += "erscores are reserved\n╭─[ 0119_reserved_names.graphql:1"
    out += "7:6 ]\nError: an enum value cannot be named `__FileNotFound`"
    out += " as names starting with two underscores are reserved\n╭─"
    out += "[ 0119_reserved_names.graphql:20:5 ]\n"
    return out^


def _path_116() -> String:
    var out = String()
    out += "diagnostics/0120_conditional_subscriptions.graphql"
    return out^


def _input_116() -> String:
    var out = String()
    out += "subscription ConditionalSub($condition: Boolean = true) {\n "
    out += "   ticker @include(if: $condition)\n}\n\ntype Query {\n    h"
    out += "ello: String\n}\n\ntype Subscription {\n    ticker: String\n"
    out += "}"
    return out^


def _expected_116() -> String:
    var out = String()
    out += "Error: subscription `ConditionalSub` can not specify @skip o"
    out += "r @include on root fields\n╭─[ 0120_conditional_subscrip"
    out += "tions.graphql:2:12 ]\n"
    return out^


def _path_117() -> String:
    var out = String()
    out += "diagnostics/0121_conditional_subscriptions_with_inline_fragm"
    out += "ent.graphql"
    return out^


def _input_117() -> String:
    var out = String()
    out += "subscription ConditionalInlineSub($condition: Boolean = true"
    out += ") {\n    ... @include(if: $condition) {\n        ticker\n   "
    out += " }\n}\n\ntype Query {\n    hello: String\n}\n\ntype Subscrip"
    out += "tion {\n    ticker: String\n}"
    return out^


def _expected_117() -> String:
    var out = String()
    out += "Error: subscription `ConditionalInlineSub` can not specify @"
    out += "skip or @include on root fields\n╭─[ 0121_conditional_su"
    out += "bscriptions_with_inline_fragment.graphql:2:9 ]\n"
    return out^


def _path_118() -> String:
    var out = String()
    out += "diagnostics/0122_conditional_subscriptions_with_named_fragme"
    out += "nt.graphql"
    return out^


def _input_118() -> String:
    var out = String()
    out += "subscription ConditionalInlineSub($condition: Boolean = true"
    out += ") {\n    ...mySubscription @include(if: $condition)\n}\n\nfr"
    out += "agment mySubscription on Subscription {\n    ticker\n}\n\nty"
    out += "pe Query {\n    hello: String\n}\n\ntype Subscription {\n   "
    out += " ticker: String\n}"
    return out^


def _expected_118() -> String:
    var out = String()
    out += "Error: subscription `ConditionalInlineSub` can not specify @"
    out += "skip or @include on root fields\n╭─[ 0122_conditional_su"
    out += "bscriptions_with_named_fragment.graphql:2:23 ]\n"
    return out^


def _path_119() -> String:
    var out = String()
    out += "diagnostics/0123_conditional_subscriptions_inside_inline_fra"
    out += "gment.graphql"
    return out^


def _input_119() -> String:
    var out = String()
    out += "subscription ConditionalInlineSub($condition: Boolean = true"
    out += ") {\n    ... {\n        ticker @include(if: $condition)\n   "
    out += " }\n}\n\ntype Query {\n    hello: String\n}\n\ntype Subscrip"
    out += "tion {\n    ticker: String\n}"
    return out^


def _expected_119() -> String:
    var out = String()
    out += "Error: subscription `ConditionalInlineSub` can not specify @"
    out += "skip or @include on root fields\n╭─[ 0123_conditional_su"
    out += "bscriptions_inside_inline_fragment.graphql:3:16 ]\n"
    return out^


def _path_120() -> String:
    var out = String()
    out += "diagnostics/0124_conditional_subscriptions_inside_named_frag"
    out += "ment.graphql"
    return out^


def _input_120() -> String:
    var out = String()
    out += "subscription ConditionalInlineSub($condition: Boolean = true"
    out += ") {\n    ...mySubscription\n}\n\nfragment mySubscription on "
    out += "Subscription {\n    ticker @include(if: $condition)\n}\n\nty"
    out += "pe Query {\n    hello: String\n}\n\ntype Subscription {\n   "
    out += " ticker: String\n}"
    return out^


def _expected_120() -> String:
    var out = String()
    out += "Error: subscription `ConditionalInlineSub` can not specify @"
    out += "skip or @include on root fields\n╭─[ 0124_conditional_su"
    out += "bscriptions_inside_named_fragment.graphql:6:12 ]\n"
    return out^


def _path_121() -> String:
    var out = String()
    out += "diagnostics/0125_defer_duplicate_label.graphql"
    return out^


def _input_121() -> String:
    var out = String()
    out += 'query Q {\n    me {\n        ... @defer(label: "dup") {\n '
    out += '           ... @defer(label: "dup") {\n                id'
    out += "\n            }\n        }\n    }\n}\n\ndirective @defer(\n "
    out += "   if: Boolean! = true\n    label: String\n) on FRAGMENT_SPR"
    out += "EAD | INLINE_FRAGMENT\n\ntype Query {\n    me: User\n}\n\nty"
    out += "pe User {\n    id: ID\n}\n"
    return out^


def _expected_121() -> String:
    var out = String()
    out += "Error: `@defer` label `dup` is not unique within the documen"
    out += "t\n╭─[ 0125_defer_duplicate_label.graphql:4:31 ]\n"
    return out^


def _path_122() -> String:
    var out = String()
    out += "diagnostics/0126_defer_label_variable.graphql"
    return out^


def _input_122() -> String:
    var out = String()
    out += "query Q($label: String!) {\n    me {\n        ... @defer(lab"
    out += "el: $label) {\n            id\n        }\n    }\n}\n\ndirect"
    out += "ive @defer(\n    if: Boolean! = true\n    label: String\n) o"
    out += "n FRAGMENT_SPREAD | INLINE_FRAGMENT\n\ntype Query {\n    me:"
    out += " User\n}\n\ntype User {\n    id: ID\n}\n"
    return out^


def _expected_122() -> String:
    var out = String()
    out += "Error: `@defer` label argument must be a static String, not "
    out += "a variable\n╭─[ 0126_defer_label_variable.graphql:3:27 ]"
    out += "\n"
    return out^


def _path_123() -> String:
    var out = String()
    out += "diagnostics/0127_defer_on_mutation_root.graphql"
    return out^


def _input_123() -> String:
    var out = String()
    out += "mutation M {\n    ... @defer {\n        mutationField\n    }"
    out += "\n}\n\ndirective @defer(\n    if: Boolean! = true\n    label"
    out += ": String\n) on FRAGMENT_SPREAD | INLINE_FRAGMENT\n\ntype Que"
    out += "ry {\n    field: String\n}\n\ntype Mutation {\n    mutationF"
    out += "ield: String\n}\n"
    return out^


def _expected_123() -> String:
    var out = String()
    out += "Error: `@defer` is not allowed on root selections of mutatio"
    out += "n operations\n╭─[ 0127_defer_on_mutation_root.graphql:2:"
    out += "9 ]\n"
    return out^


def _path_124() -> String:
    var out = String()
    out += "diagnostics/0128_defer_in_subscription_unconditional.graphql"
    return out^


def _input_124() -> String:
    var out = String()
    out += "subscription Sub {\n    newMessage {\n        ... @defer {\n"
    out += "            body\n        }\n    }\n}\n\ndirective @defer(\n"
    out += "    if: Boolean! = true\n    label: String\n) on FRAGMENT_SP"
    out += "READ | INLINE_FRAGMENT\n\ntype Query {\n    message: Message"
    out += "\n}\n\ntype Subscription {\n    newMessage: Message\n}\n\nty"
    out += "pe Message {\n    body: String\n}\n"
    return out^


def _expected_124() -> String:
    var out = String()
    out += "Error: `@defer` in a subscription operation must be disabled"
    out += " with an `if` argument\n╭─[ 0128_defer_in_subscription_u"
    out += "nconditional.graphql:3:13 ]\n"
    return out^


def _path_125() -> String:
    var out = String()
    out += "diagnostics/0129_duplicate_root_operation_types_query_mutati"
    out += "on.graphql"
    return out^


def _input_125() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  mutation: SharedType\n}\n\n"
    out += "type SharedType {\n  field: String\n}\n"
    return out^


def _expected_125() -> String:
    var out = String()
    out += "Error: the same type `SharedType` must not be used for multi"
    out += "ple root operation types\n╭─[ 0129_duplicate_root_operat"
    out += "ion_types_query_mutation.graphql:3:13 ]\n"
    return out^


def _path_126() -> String:
    var out = String()
    out += "diagnostics/0130_duplicate_root_operation_types_query_subscr"
    out += "iption.graphql"
    return out^


def _input_126() -> String:
    var out = String()
    out += "schema {\n  query: SharedType\n  subscription: SharedType\n}"
    out += "\n\ntype SharedType {\n  field: String\n}\n"
    return out^


def _expected_126() -> String:
    var out = String()
    out += "Error: the same type `SharedType` must not be used for multi"
    out += "ple root operation types\n╭─[ 0130_duplicate_root_operat"
    out += "ion_types_query_subscription.graphql:3:17 ]\n"
    return out^


def _path_127() -> String:
    var out = String()
    out += "diagnostics/0131_duplicate_root_operation_types_mutation_sub"
    out += "scription.graphql"
    return out^


def _input_127() -> String:
    var out = String()
    out += "schema {\n  query: Query\n  mutation: SharedType\n  subscrip"
    out += "tion: SharedType\n}\n\ntype Query {\n  field: String\n}\n\nt"
    out += "ype SharedType {\n  field: String\n}\n"
    return out^


def _expected_127() -> String:
    var out = String()
    out += "Error: the same type `SharedType` must not be used for multi"
    out += "ple root operation types\n╭─[ 0131_duplicate_root_operat"
    out += "ion_types_mutation_subscription.graphql:4:17 ]\n"
    return out^


def _path_128() -> String:
    var out = String()
    out += "ok/0001_annonymous_operation_definition.graphql"
    return out^


def _input_128() -> String:
    var out = String()
    out += "\nquery {\n  cat {\n    name\n  }\n}\n\ntype Query {\n  cat:"
    out += " Pet\n}\n\ntype Pet {\n  name: String\n}"
    return out^


def _expected_128() -> String:
    var out = String()
    return out^


def _path_129() -> String:
    var out = String()
    out += "ok/0002_multiple_named_operation_definitions.graphql"
    return out^


def _input_129() -> String:
    var out = String()
    out += "query getCatName {\n  cat {\n    name\n  }\n}\n\nquery getOw"
    out += "nerName {\n  cat {\n    owner {\n      name\n    }\n  }\n}\n"
    out += "\n\ntype Query {\n  cat: Pet\n}\n\ntype Pet {\n  name: Strin"
    out += "g,\n  owner: PetOwner\n}\n\ntype PetOwner {\n  name: String"
    out += "\n}\n"
    return out^


def _expected_129() -> String:
    var out = String()
    return out^


def _path_130() -> String:
    var out = String()
    out += "ok/0003_schema_definition_with_custom_operation_types.graphq"
    out += "l"
    return out^


def _input_130() -> String:
    var out = String()
    out += "schema {\n  query: customPetQuery,\n  subscription: customPe"
    out += "tSubscription\n  mutation: customPetMutation\n}\n\nenum PetT"
    out += "ype {\n  CAT,\n  DOG,\n}\n\ntype customPetQuery {\n  name: S"
    out += "tring,\n  age: Int\n}\n\ntype customPetSubscription {\n  cha"
    out += "ngeInPetHousehold: Result\n}\n\ntype customPetMutation {\n  "
    out += "addPet (name: String!, petType: PetType): Result!\n}\n\ntype"
    out += " Result {\n  id: String\n}\n"
    return out^


def _expected_130() -> String:
    var out = String()
    return out^


def _path_131() -> String:
    var out = String()
    out += "ok/0004_schema_with_custom_scalars.graphql"
    return out^


def _input_131() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    return out^


def _expected_131() -> String:
    var out = String()
    return out^


def _path_132() -> String:
    var out = String()
    out += "ok/0005_schema_with_valid_enum_definitions.graphql"
    return out^


def _input_132() -> String:
    var out = String()
    out += "type Query {\n  pet: Pet,\n  snacks: Snack,\n}\n\nenum Pet {"
    out += "\n    CAT\n    DOG\n    FOX\n}\n\nenum Snack {\n    THRIVE_P"
    out += "ET_FOODS\n    LILYS_KITCHEN\n    ACANA\n}"
    return out^


def _expected_132() -> String:
    var out = String()
    return out^


def _path_133() -> String:
    var out = String()
    out += "ok/0006_schema_with_valid_union.graphql"
    return out^


def _input_133() -> String:
    var out = String()
    out += "schema {\n  query: SearchQuery\n}\n\nunion SearchResult = Ph"
    out += "oto | Person\n\ntype Person {\n  name: String\n  age: Int\n}"
    out += "\n\ntype Photo {\n  height: Int\n  width: Int\n}\n\ntype Sea"
    out += "rchQuery {\n  firstSearchResult: SearchResult\n}"
    return out^


def _expected_133() -> String:
    var out = String()
    return out^


def _path_134() -> String:
    var out = String()
    out += "ok/0007_schema_with_interface_definition.graphql"
    return out^


def _input_134() -> String:
    var out = String()
    out += "type Query implements Node {\n    id: ID!\n}\n\ninterface No"
    out += "de {\n  id: ID!\n}\n\ninterface Resource implements Node {\n"
    out += "  id: ID!\n  width: Int\n  height: Int\n}\n\ninterface Image"
    out += " implements Resource & Node {\n  id: ID!\n  width: Int\n  he"
    out += "ight: Int\n  thumbnail: String\n}"
    return out^


def _expected_134() -> String:
    var out = String()
    return out^


def _path_135() -> String:
    var out = String()
    out += "ok/0008_schema_with_directive_definition.graphql"
    return out^


def _input_135() -> String:
    var out = String()
    out += "type Query {\n    literature: Book\n}\n\ndirective @delegate"
    out += "Field(name: String!) repeatable on OBJECT | INTERFACE\n\ntyp"
    out += 'e Book @delegateField(name: "pageCount") @delegateField(na'
    out += 'me: "author") {\n  id: ID!\n}'
    return out^


def _expected_135() -> String:
    var out = String()
    return out^


def _path_136() -> String:
    var out = String()
    out += "ok/0009_schema_with_input_object.graphql"
    return out^


def _input_136() -> String:
    var out = String()
    out += "type Query {\n  website: URL,\n  amount: Int\n}\n\nscalar UR"
    out += 'L @specifiedBy(url: "https://tools.ietf.org/html/rfc3986")'
    out += "\n\ninput Point2D {\n  x: Float\n  y: Float\n}"
    return out^


def _expected_136() -> String:
    var out = String()
    return out^


def _path_137() -> String:
    var out = String()
    out += "ok/0010_operation_with_defined_fields.graphql"
    return out^


def _input_137() -> String:
    var out = String()
    out += "query getProduct {\n  size\n  topProducts {\n    name\n    i"
    out += "nStock\n  }\n}\n\ntype Query {\n  topProducts: Product\n  na"
    out += "me: String\n  size: Int\n}\n\ntype Product {\n  inStock: Boo"
    out += "lean @join__field(graph: INVENTORY)\n  name: String @join__f"
    out += "ield(graph: PRODUCTS)\n  price: Int\n  shippingEstimate: Int"
    out += "\n  upc: String!\n  weight: Int\n}\n\ndirective @join__field"
    out += "(graph: join__Graph) on FIELD_DEFINITION\nenum join__Graph {"
    out += "\n  INVENTORY,\n  PRODUCTS,\n}\n"
    return out^


def _expected_137() -> String:
    var out = String()
    return out^


def _path_138() -> String:
    var out = String()
    out += "ok/0011_fragment_spreads_in_fragment_definitions.graphql"
    return out^


def _input_138() -> String:
    var out = String()
    out += "query IntrospectionQuery {\n  foo {\n    ...Bar\n  }\n}\n\nf"
    out += "ragment Bar on Foo {\n  baz {\n    ...Quux\n  }\n}\n\nfragme"
    out += "nt Quux on Baz {\n  id\n}\n\ntype Query {\n  foo: Foo\n}\n\n"
    out += "type Foo {\n  baz: Baz\n}\n\ntype Baz {\n  id: ID\n}\n"
    return out^


def _expected_138() -> String:
    var out = String()
    return out^


def _path_139() -> String:
    var out = String()
    out += "ok/0012_introspection_query.graphql"
    return out^


def _input_139() -> String:
    var out = String()
    out += "query IntrospectionQuery {\n  __schema {\n    queryType { na"
    out += "me }\n    mutationType { name }\n    subscriptionType { name"
    out += " }\n    types {\n      ...FullType\n    }\n    directives {"
    out += "\n      name\n      description\n      locations\n      args"
    out += " {\n        ...InputValue\n      }\n    }\n  }\n}\nfragment "
    out += "FullType on __Type {\n  kind\n  name\n  description\n  field"
    out += "s(includeDeprecated: true) {\n    name\n    description\n   "
    out += " args {\n      ...InputValue\n    }\n    type {\n      ...Ty"
    out += "peRef\n    }\n    isDeprecated\n    deprecationReason\n  }\n"
    out += "  inputFields {\n    ...InputValue\n  }\n  interfaces {\n   "
    out += " ...TypeRef\n  }\n  enumValues(includeDeprecated: true) {\n "
    out += "   name\n    description\n    isDeprecated\n    deprecationR"
    out += "eason\n  }\n  possibleTypes {\n    ...TypeRef\n  }\n}\nfragm"
    out += "ent InputValue on __InputValue {\n  name\n  description\n  t"
    out += "ype { ...TypeRef }\n  defaultValue\n}\nfragment TypeRef on _"
    out += "_Type {\n  kind\n  name\n  ofType {\n    kind\n    name\n   "
    out += " ofType {\n      kind\n      name\n      ofType {\n        k"
    out += "ind\n        name\n        ofType {\n          kind\n       "
    out += "   name\n          ofType {\n            kind\n            n"
    out += "ame\n            ofType {\n              kind\n             "
    out += " name\n              ofType {\n                kind\n       "
    out += "         name\n              }\n            }\n          }\n"
    out += "        }\n      }\n    }\n  }\n}\ntype Query {\n  field: In"
    out += "t\n}\n"
    return out^


def _expected_139() -> String:
    var out = String()
    return out^


def _path_140() -> String:
    var out = String()
    out += "ok/0013_operation_with_used_variable_in_fragment.graphql"
    return out^


def _input_140() -> String:
    var out = String()
    out += "query ExampleQuery($variable: Int) {\n  topProducts {\n    n"
    out += "ame\n  }\n  ... subFrag\n}\n\nfragment subFrag on Query {\n "
    out += " topProducts {\n    price(setPrice: $variable)\n  }\n}\n\nty"
    out += "pe Query {\n  topProducts(first: Int): Product,\n  reviews: "
    out += "Review\n}\n\ntype Review {\n  message: Message\n}\n\ntype Me"
    out += "ssage {\n  body: String\n  sender(attribute: String): String"
    out += "\n}\n\ntype Product {\n  name: String\n  price(setPrice: Int"
    out += "): Int\n}\n"
    return out^


def _expected_140() -> String:
    var out = String()
    return out^


def _path_141() -> String:
    var out = String()
    out += "ok/0014_float_values.graphql"
    return out^


def _input_141() -> String:
    var out = String()
    out += "type Query {\n  name(arg: WithAllKindsOfFloats): String\n}\n"
    out += "\ninput WithAllKindsOfFloats {\n  a_regular_float: Float = 1"
    out += ".2\n  an_integer_float: Float = 1234\n  a_float_that_doesnt_"
    out += "fit_an_int: Float = 9876543210\n  list_of_floats: [Float] = "
    out += "[4, 9876543210, 98765432109876543210]\n}\n"
    return out^


def _expected_141() -> String:
    var out = String()
    return out^


def _path_142() -> String:
    var out = String()
    out += "ok/0015_supergraph.graphql"
    return out^


def _input_142() -> String:
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


def _expected_142() -> String:
    var out = String()
    return out^


def _path_143() -> String:
    var out = String()
    out += "ok/0016_same_variables_in_multiple_operations.graphql"
    return out^


def _input_143() -> String:
    var out = String()
    out += "query A($atOtherHomes: Boolean) {\n  ...HouseTrainedFragment"
    out += "\n}\n\nquery B($atOtherHomes: Boolean) {\n  ...HouseTrainedF"
    out += "ragment\n}\n\nfragment HouseTrainedFragment on Query {\n  do"
    out += "g {\n    isHouseTrained(atOtherHomes: $atOtherHomes)\n  }\n}"
    out += "\n\ntype Query {\n  dog: Dog\n}\n\ntype Dog {\n  name: Strin"
    out += "g!\n  nickname: String\n  barkVolume: Int\n  isHouseTrained("
    out += "atOtherHomes: Boolean): Boolean!\n}"
    return out^


def _expected_143() -> String:
    var out = String()
    return out^


def _path_144() -> String:
    var out = String()
    out += "ok/0017_variables_are_input_types.graphql"
    return out^


def _input_144() -> String:
    var out = String()
    out += "query takesBoolean($atOtherHomes: Boolean) {\n  dog {\n    i"
    out += "sHouseTrained(atOtherHomes: $atOtherHomes)\n  }\n}\n\nquery "
    out += "takesComplexInput($complexInput: ComplexInput) {\n  findDog("
    out += "complex: $complexInput) {\n    name\n  }\n}\n\nquery TakesLi"
    out += "stOfBooleanBang($booleans: [Boolean!]) {\n  booleanList(bool"
    out += "eanListArg: $booleans)\n}\n\n\ntype Dog {\n  name: String!\n"
    out += "  nickname: String\n  barkVolume: Int\n  isHouseTrained(atOt"
    out += "herHomes: Boolean): Boolean!\n}\n\ninput ComplexInput {\n  n"
    out += "ame: String\n  owner: String\n}\n\ntype Query {\n  dog: Dog"
    out += "\n  findDog(complex: ComplexInput): Dog\n  booleanList(boole"
    out += "anListArg: [Boolean!]): Boolean\n}"
    return out^


def _expected_144() -> String:
    var out = String()
    return out^


def _path_145() -> String:
    var out = String()
    out += "ok/0018_non_clashing_names.graphql"
    return out^


def _input_145() -> String:
    var out = String()
    out += "# Types, directives, fragments, and operations each have the"
    out += "ir own namespace.\ntype A @A {\n  a: Int\n}\ntype Query {\n "
    out += " a: A\n}\n\ndirective @A on OBJECT\n\nfragment A on A {\n  a"
    out += "\n}\n\nquery A {\n  a {\n    ...A\n  }\n}\n"
    return out^


def _expected_145() -> String:
    var out = String()
    return out^


def _path_146() -> String:
    var out = String()
    out += "ok/0019_extensions.graphql"
    return out^


def _input_146() -> String:
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


def _expected_146() -> String:
    var out = String()
    return out^


def _path_147() -> String:
    var out = String()
    out += "ok/0020_merge_identical_fields.graphql"
    return out^


def _input_147() -> String:
    var out = String()
    out += "type Query {\n  pet: Dog\n}\n\ntype Dog {\n  nickname: Strin"
    out += "g\n  name: String!\n}\n\nquery queryPupper {\n  pet {\n    ."
    out += "..mergeIdenticalFields\n    ...mergeIdenticalAliasesAndField"
    out += "s\n  }\n}\n\nfragment mergeIdenticalFields on Dog {\n  name"
    out += "\n  name\n}\n\nfragment mergeIdenticalAliasesAndFields on Do"
    out += "g {\n  otherName: name\n  otherName: name\n}\n"
    return out^


def _expected_147() -> String:
    var out = String()
    return out^


def _path_148() -> String:
    var out = String()
    out += "ok/0021_merge_identical_fields_with_arguments.graphql"
    return out^


def _input_148() -> String:
    var out = String()
    out += "enum DogCommand {\n  SIT\n  HEEL\n}\n\ntype Dog {\n  doesKno"
    out += "wCommand(dogCommand: DogCommand): Boolean\n}\n\ntype Query {"
    out += "\n  pet: Dog\n}\n\nquery queryPupper {\n  pet {\n    ...merg"
    out += "eIdenticalFieldsWithIdenticalArgs\n  }\n}\n\nquery queryPupp"
    out += "erAgain($dogCommand: DogCommand) {\n  pet {\n    ...mergeIde"
    out += "nticalFieldsWithIdenticalValues\n  }\n}\n\nfragment mergeIde"
    out += "nticalFieldsWithIdenticalArgs on Dog {\n  doesKnowCommand(do"
    out += "gCommand: SIT)\n  doesKnowCommand(dogCommand: SIT)\n}\n\nfra"
    out += "gment mergeIdenticalFieldsWithIdenticalValues on Dog {\n  do"
    out += "esKnowCommand(dogCommand: $dogCommand)\n  doesKnowCommand(do"
    out += "gCommand: $dogCommand)\n}\n"
    return out^


def _expected_148() -> String:
    var out = String()
    return out^


def _path_149() -> String:
    var out = String()
    out += "ok/0022_merge_differing_fields_and_args.graphql"
    return out^


def _input_149() -> String:
    var out = String()
    out += "interface Pet {\n  name: String!\n}\n\nenum DogCommand {\n  "
    out += "SIT\n  HEEL\n}\n\nenum CatCommand {\n  JUMP\n}\n\ntype Query"
    out += " {\n  pet: Pet\n}\n\ntype Dog implements Pet {\n  name: Stri"
    out += "ng!\n  nickname: String!\n  barkVolume: Int!\n  doesKnowComm"
    out += "and(dogCommand: DogCommand!): Boolean!\n  isAtLocation(x: In"
    out += "t, y: Int): Boolean!\n}\n\ntype Cat implements Pet {\n  name"
    out += ": String!\n  meowVolume: Int!\n  doesKnowCommand(catCommand:"
    out += " CatCommand!): Boolean!\n}\n\nquery barkVolume {\n  pet {\n "
    out += "   ...safeDifferingFields\n  }\n}\n\nquery doesKnowCommand {"
    out += "\n  pet {\n    ...safeDifferingArgs\n  }\n}\n\nquery isAtLoc"
    out += "ation {\n  pet {\n    ...safeDifferingArgOrder\n  }\n}\n\nfr"
    out += "agment safeDifferingFields on Pet {\n  ... on Dog {\n    vol"
    out += "ume: barkVolume\n  }\n  ... on Cat {\n    volume: meowVolume"
    out += "\n  }\n}\n\nfragment safeDifferingArgs on Pet {\n  ... on Do"
    out += "g {\n    doesKnowCommand(dogCommand: SIT)\n  }\n  ... on Cat"
    out += " {\n    doesKnowCommand(catCommand: JUMP)\n  }\n}\n\nfragmen"
    out += "t safeDifferingArgOrder on Dog {\n  isAtLocation(x: 0, y: 0)"
    out += "\n  isAtLocation(y: 0, x: 0)\n}\n"
    return out^


def _expected_149() -> String:
    var out = String()
    return out^


def _path_150() -> String:
    var out = String()
    out += "ok/0024_used_variables_in_directives.graphql"
    return out^


def _input_150() -> String:
    var out = String()
    out += "type Query {\n  field(arg: Boolean): Int\n  fragField: Int\n"
    out += "  inlineField: Int\n}\n\nfragment fragment on Query {\n  fra"
    out += "gField @include(if: $indirectDirective)\n}\n\nquery (\n  $fi"
    out += "eldDirective: Boolean = true,\n  $fragDirective: Boolean = f"
    out += "alse,\n  $inlineDirective: Boolean = false,\n  $argDirective"
    out += ": Boolean = false,\n  $indirectDirective: Boolean = false,\n"
    out += ") {\n  field(arg: $argDirective) @skip(if: $fieldDirective)"
    out += "\n\n  ...fragment @include(if: $fragDirective)\n\n  ... @ski"
    out += "p(if: $inlineDirective) {\n    inlineField\n  }\n}\n"
    return out^


def _expected_150() -> String:
    var out = String()
    return out^


def _path_151() -> String:
    var out = String()
    out += "ok/0025_unique_directives.graphql"
    return out^


def _input_151() -> String:
    var out = String()
    out += "directive @repeatable repeatable on FIELD\ndirective @unique"
    out += " on FIELD\n\ntype Query {\n  field: Int\n}\n\n{\n  field @re"
    out += "peatable @repeatable\n  field @unique\n  field @unique\n}\n"
    return out^


def _expected_151() -> String:
    var out = String()
    return out^


def _path_152() -> String:
    var out = String()
    out += "ok/0026_type_introspection.graphql"
    return out^


def _input_152() -> String:
    var out = String()
    out += "type Query {\n  id: String\n  name: String\n  birthday: Date"
    out += '\n}\n\nscalar Date @specifiedBy(url: "datespec.com")\n\n{'
    out += '\n  __type(name: "User") {\n    name\n    fields {\n      '
    out += "name\n      type {\n        name\n      }\n    }\n  }\n}"
    return out^


def _expected_152() -> String:
    var out = String()
    return out^


def _path_153() -> String:
    var out = String()
    out += "ok/0027_typename_introspection_in_object.graphql"
    return out^


def _input_153() -> String:
    var out = String()
    out += "type Query {\n  id: String\n  name: String\n  birthday: Date"
    out += '\n}\n\nscalar Date @specifiedBy(url: "datespec.com")\n\n{'
    out += "\n    name\n    __typename\n}"
    return out^


def _expected_153() -> String:
    var out = String()
    return out^


def _path_154() -> String:
    var out = String()
    out += "ok/0028_typename_introspection_in_union.graphql"
    return out^


def _input_154() -> String:
    var out = String()
    out += "union SearchResult = Photo | Person\n\ntype Person {\n  name"
    out += ": String\n  age: Int\n}\n\ntype Photo {\n  height: Int\n  wi"
    out += "dth: Int\n}\n\ntype Query {\n  firstSearchResult: SearchResu"
    out += "lt\n}\n\n{\n  firstSearchResult {\n    __typename\n    ... o"
    out += "n Person {\n      name\n    }\n    ... on Photo {\n      hei"
    out += "ght\n    }\n  }\n}"
    return out^


def _expected_154() -> String:
    var out = String()
    return out^


def _path_155() -> String:
    var out = String()
    out += "ok/0029_used_variable_in_list_and_input.graphql"
    return out^


def _input_155() -> String:
    var out = String()
    out += "type Product {\n  attributes(includeNames: [String!]): [Stri"
    out += "ng!]\n}\n\ninput Opts {\n  prop: [[Int]!]!\n}\n\ntype Query "
    out += "{\n  field(\n    opts: Opts\n  ): [Product]\n}\n\nquery ($at"
    out += "tributeName: String!, $v: Int) {\n  field(opts: {\n    prop:"
    out += " [[2], [$v], [4]],\n  }) {\n    attributes(includeNames: [$a"
    out += "ttributeName])\n  }\n}\n"
    return out^


def _expected_155() -> String:
    var out = String()
    return out^


def _path_156() -> String:
    var out = String()
    out += "ok/0030_cyclical_nullable_input_objects.graphql"
    return out^


def _input_156() -> String:
    var out = String()
    out += "type Query {\n    name: String\n    example(arg: First): Int"
    out += "\n}\n\ninput First {\n  second: Second\n  value: String\n}\n"
    out += "\ninput Second {\n  third: [Third!]!\n  value: String\n}\n\n"
    out += "input Third {\n  fourth: Fourth\n  value: String\n}\n\ninput"
    out += " Fourth {\n  first: First\n}"
    return out^


def _expected_156() -> String:
    var out = String()
    return out^


def _path_157() -> String:
    var out = String()
    out += "ok/0031_fragment_spread_possible.graphql"
    return out^


def _input_157() -> String:
    var out = String()
    out += "interface Pet {\n  name: String!\n}\n\ntype Dog implements P"
    out += "et {\n  name: String!\n  barkVolume: Int\n}\n\ntype Cat impl"
    out += "ements Pet {\n  name: String!\n  meowVolume: Int\n}\n\nunion"
    out += " CatOrDog = Cat | Dog\n\ntype Human {\n  pets: [Pet!]\n}\n\n"
    out += "union DogOrHuman = Dog | Human\n\n# https://spec.graphql.org"
    out += "/October2021/#sec-Object-Spreads-In-Object-Scope\nfragment d"
    out += "ogFragment on Dog {\n  ... on Dog {\n    barkVolume\n  }\n}"
    out += "\n\n# https://spec.graphql.org/October2021/#sec-Abstract-Spr"
    out += "eads-in-Object-Scope\nfragment petNameFragment on Pet {\n  n"
    out += "ame\n}\n\nfragment interfaceWithinObjectFragment on Dog {\n "
    out += " ...petNameFragment\n}\n\nfragment catOrDogNameFragment on C"
    out += "atOrDog {\n  ... on Cat {\n    meowVolume\n  }\n}\n\nfragmen"
    out += "t unionWithObjectFragment on Dog {\n  ...catOrDogNameFragmen"
    out += "t\n}\n\n# https://spec.graphql.org/October2021/#sec-Object-S"
    out += "preads-In-Abstract-Scope\nfragment petFragment on Pet {\n  n"
    out += "ame\n  ... on Dog {\n    barkVolume\n  }\n}\n\nfragment catO"
    out += "rDogFragment on CatOrDog {\n  ... on Cat {\n    meowVolume\n"
    out += "  }\n}\n\n# https://spec.graphql.org/October2021/#sec-Abstra"
    out += "ct-Spreads-in-Abstract-Scope\nfragment unionWithInterface on"
    out += " Pet {\n  ...dogOrHumanFragment\n}\n\nfragment dogOrHumanFra"
    out += "gment on DogOrHuman {\n  ... on Dog {\n    barkVolume\n  }\n"
    out += "}\n\n# https://spec.graphql.org/October2021/#sec-Abstract-Sp"
    out += "reads-in-Abstract-Scope.Interface-Spreads-in-implemented-Int"
    out += "erface-Scope\ninterface Node {\n  id: ID!\n}\n\ninterface Re"
    out += "source implements Node {\n  id: ID!\n  url: String\n}\n\n# T"
    out += "he validation for fragment spreads works on concrete types."
    out += "\ntype ConcreteResource implements Resource & Node {\n  id: "
    out += "ID!\n  url: String\n}\n\nfragment interfaceWithInterface on "
    out += "Node {\n  ...resourceFragment\n}\n\nfragment resourceFragmen"
    out += "t on Resource {\n  url\n}\n\n# Make sure the above fragments"
    out += " are used\ntype Query {\n  pet: Pet\n  resource: Resource\n}"
    out += "\n\nquery UseAllFragments {\n  pet {\n    ... dogFragment\n "
    out += "   ... interfaceWithinObjectFragment\n    ... unionWithObjec"
    out += "tFragment\n    ... petFragment\n    ... catOrDogFragment\n  "
    out += "  ... unionWithInterface\n  }\n  resource {\n    ...interfac"
    out += "eWithInterface\n    ... @skip(if: true) {\n      urlInInline"
    out += "Fragment: url\n    }\n  }\n}\n"
    return out^


def _expected_157() -> String:
    var out = String()
    return out^


def _path_158() -> String:
    var out = String()
    out += "ok/0032_valid_of_correct_type.graphql"
    return out^


def _input_158() -> String:
    var out = String()
    out += "type ComplicatedArgs {\n  # TODO List\n  # TODO Coercion\n  "
    out += "# TODO NotNulls\n  intArgField(intArg: Int): String\n  nonNu"
    out += "llIntArgField(nonNullIntArg: Int!): String\n  stringArgField"
    out += "(stringArg: String): String\n  booleanArgField(booleanArg: B"
    out += "oolean): String\n  enumArgField(enumArg: FurColor): String\n"
    out += "  floatArgField(floatArg: Float): String\n  idArgField(idArg"
    out += ": ID): String\n  stringListArgField(stringListArg: [String])"
    out += ": String\n  stringListNonNullArgField(stringListNonNullArg: "
    out += "[String!]): String\n  customScalar(customScalar: Custom): St"
    out += "ring\n  complexArgField(complexArg: ComplexInput): String\n "
    out += " multipleReqs(req1: Int!, req2: Int!): String\n  nonNullFiel"
    out += "dWithDefault(arg: Int! = 0): String\n  multipleOpts(opt1: In"
    out += "t = 0, opt2: Int = 0): String\n  multipleOptAndReq(req1: Int"
    out += "!, req2: Int!, opt1: Int = 0, opt2: Int = 0): String\n}\n\ns"
    out += 'calar Custom @specifiedBy(url: "example.com")\n\nenum FurC'
    out += "olor {\n  BROWN\n  BLACK\n  TAN\n  SPOTTED\n  NO_FUR\n  UNKN"
    out += "OWN\n}\n\ninput ComplexInput {\n  requiredField: Boolean!\n "
    out += " nonNullField: Boolean! = false\n  intField: Int\n  stringFi"
    out += "eld: String\n  booleanField: Boolean\n  stringListField: [St"
    out += "ring]\n}\n\nenum DogCommand {\n  SIT\n  HEEL\n  DOWN\n}\n\nt"
    out += "ype Dog {\n  doesKnowCommand(dogCommand: DogCommand): Boolea"
    out += "n\n  name(surname: Boolean): String\n  isHouseTrained(atOthe"
    out += "rHomes: Boolean = true): Boolean\n}\n\ninterface Pet {\n  na"
    out += "me(surname: Boolean): String\n}\n\ntype Query {\n  complicat"
    out += "edArgs: ComplicatedArgs\n  dog: Dog\n  human(id: ID): Human"
    out += "\n}\n\ntype Human {\n  name(surname: Boolean): String\n  pet"
    out += "s: [Pet]\n  relatives: [Human]!\n}\n\nquery goodIntValue {\n"
    out += "  complicatedArgs {\n    intArgField(intArg: 2)\n  }\n}\n\nq"
    out += "uery goodNegativeIntValue{\n  complicatedArgs {\n    intArgF"
    out += "ield(intArg: -2)\n  }\n}\n\nquery goodBooleanValue {\n  comp"
    out += "licatedArgs {\n    booleanArgField(booleanArg: true)\n  }\n}"
    out += "\n\nquery goodStringValue {\n  complicatedArgs {\n    string"
    out += 'ArgField(stringArg: "foo")\n  }\n}\n\nquery goodFloatValue'
    out += " {\n  complicatedArgs {\n    floatArgField(floatArg: 1.1)\n "
    out += " }\n}\n\nquery goodNegativeFloatValue {\n  complicatedArgs {"
    out += "\n    floatArgField(floatArg: -1.1)\n  }\n}\n\nquery intInto"
    out += "Float {\n  complicatedArgs {\n    floatArgField(floatArg: 1)"
    out += "\n  }\n}\n\nquery intIntoID {\n  complicatedArgs {\n    idAr"
    out += "gField(idArg: 1)\n  }\n}\n\nquery stringIntoID {\n  complica"
    out += 'tedArgs {\n    idArgField(idArg: "someIdString")\n  }\n}\n'
    out += "\nquery goodEnumValue {\n  dog {\n    doesKnowCommand(dogCom"
    out += "mand: SIT)\n  }\n}\n\nquery enumWithUndefinedValue {\n  comp"
    out += "licatedArgs {\n    enumArgField(enumArg: UNKNOWN)\n  }\n}\n"
    out += "\nquery enumWithNullValue {\n  complicatedArgs {\n    enumAr"
    out += "gField(enumArg: null)\n  }\n}\n\nquery nullIntoNullableType "
    out += "{\n  complicatedArgs {\n    intArgField(intArg: null)\n  }\n"
    out += "}\n\nquery goodListValue {\n  complicatedArgs {\n    stringL"
    out += 'istArgField(stringListArg: ["one", null, "two"])\n  }\n}'
    out += "\n\nquery emptyListValue {\n  complicatedArgs {\n    stringL"
    out += "istArgField(stringListArg: [])\n  }\n}\n\nquery nullListValu"
    out += "e {\n  complicatedArgs {\n    stringListArgField(stringListA"
    out += "rg: null)\n  }\n}\n\nquery singleValueIntoList {\n  complica"
    out += 'tedArgs {\n    stringListArgField(stringListArg: "one")\n '
    out += " }\n}\n\n# Valid Non-Nullable Value\nquery argOnOptionalArg "
    out += "{\n  dog {\n    isHouseTrained(atOtherHomes: true)\n  }\n}\n"
    out += "\nquery noArgOnOptionalArg {\n  dog {\n    isHouseTrained\n "
    out += " }\n}\n\nquery multipleArgs {\n  complicatedArgs {\n    mult"
    out += "ipleReqs(req1: 1, req2: 2)\n  }\n}\n\nquery multiplArgsRever"
    out += "seOrder {\n  complicatedArgs {\n    multipleReqs(req2: 2, re"
    out += "q1: 1)\n  }\n}\n\nquery noArgsOnMultipleOptional {\n  compli"
    out += "catedArgs {\n    multipleOpts\n  }\n}\n\nquery oneArgOnMulti"
    out += "pleOptional {\n  complicatedArgs {\n    multipleOpts(opt1: 1"
    out += ")\n  }\n}\n\nquery secondArgOnMultipleOptional {\n  complica"
    out += "tedArgs {\n    multipleOpts(opt2: 1)\n  }\n}\n\nquery multip"
    out += "leRequiredArgsOnMixedList {\n  complicatedArgs {\n    multip"
    out += "leOptAndReq(req1: 3, req2: 4)\n  }\n}\n\nquery multipleRequi"
    out += "redAndOneOptionalArgOnMixedList {\n  complicatedArgs {\n    "
    out += "multipleOptAndReq(req1: 3, req2: 4, opt1: 5)\n  }\n}\n\nquer"
    out += "y AllRequiredAndOptionalArgsOnMixedList {\n  complicatedArgs"
    out += " {\n    multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6"
    out += ")\n  }\n}\n\n# Valid input object value\nquery optionalArgDe"
    out += "spiteRequiredFieldInType {\n  complicatedArgs {\n    complex"
    out += "ArgField\n  }\n}\n\nquery partialObjectOnlyRequired {\n  com"
    out += "plicatedArgs {\n    complexArgField(complexArg: { requiredFi"
    out += "eld: true })\n  }\n}\n\nquery partialObjectRequiredFieldCanB"
    out += "eFalse {\n  complicatedArgs {\n    complexArgField(complexAr"
    out += "g: { requiredField: false })\n  }\n}\n\nquery partialObjectI"
    out += "ncludingRequired {\n  complicatedArgs {\n    complexArgField"
    out += "(complexArg: { requiredField: true, intField: 4 })\n  }\n}\n"
    out += "\nquery fullObject {\n  complicatedArgs {\n    complexArgFie"
    out += "ld(complexArg: {\n      requiredField: true,\n      intField"
    out += ': 4,\n      stringField: "foo",\n      booleanField: false'
    out += ',\n      stringListField: ["one", "two"]\n    })\n  }\n}'
    out += "\n\nquery fullObjectWithFieldsInDifferentOrder {\n  complica"
    out += "tedArgs {\n    complexArgField(complexArg: {\n      stringLi"
    out += 'stField: ["one", "two"],\n      booleanField: false,\n  '
    out += '    requiredField: true,\n      stringField: "foo",\n     '
    out += " intField: 4,\n    })\n  }\n}\n\nquery withDirectivesOfValid"
    out += "Types {\n  dog @include(if: true) {\n    name\n  }\n  human "
    out += "@skip(if: false) {\n    name\n  }\n}\n\n\n# Variable default"
    out += " values\nquery withDefaultValues(\n  $a: Int = 1,\n  $b: Str"
    out += 'ing = "ok",\n  $c: ComplexInput = { requiredField: true, i'
    out += "ntField: 3 }\n) {\n  complicatedArgs {\n    complexArgField("
    out += "complexArg: $c)\n    intArgField(intArg: $a)\n    stringArgF"
    out += "ield(stringArg: $b)\n  }\n}\n\nquery variablesWithDefaultNul"
    out += "lValues(\n  $a: Int = null,\n  $b: String = null,\n  $c: Com"
    out += "plexInput = { requiredField: true, intField: null }\n) {\n  "
    out += "complicatedArgs {\n    complexArgField(complexArg: $c)\n    "
    out += "intArgField(intArg: $a)\n    stringArgField(stringArg: $b)\n"
    out += "  }\n\n}\n\n# Custom Scalars\nquery customScalarWithStringVa"
    out += "lue {\n  complicatedArgs {\n    customScalar(customScalar: "
    out += '"custom")\n  }\n}\n\nquery customScalarWithIntValue {\n  c'
    out += "omplicatedArgs {\n    customScalar(customScalar: 4)\n  }\n}"
    out += "\n\nquery customScalarWithBooleanValue {\n  complicatedArgs "
    out += "{\n    customScalar(customScalar: true)\n  }\n}\n\nquery cus"
    out += "tomScalarWithFloatValue {\n  complicatedArgs {\n    customSc"
    out += "alar(customScalar: 4.4)\n  }\n}\n\nquery customScalarWithVar"
    out += "iableValue($custom: Custom = 4) {\n  complicatedArgs {\n    "
    out += "customScalar(customScalar: $custom)\n  }\n\n}\n\nquery custo"
    out += "mScalarWithArbitraryInputObject {\n  complicatedArgs {\n    "
    out += 'customScalar(customScalar: { as: "@key" })\n  }\n}\n\nquer'
    out += "y customScalarWithListValue {\n  complicatedArgs {\n    cust"
    out += "omScalar(customScalar: [0, 1, 2])\n  }\n}\n"
    return out^


def _expected_158() -> String:
    var out = String()
    return out^


def _path_159() -> String:
    var out = String()
    out += "ok/0033_valid_variable_usage.graphql"
    return out^


def _input_159() -> String:
    var out = String()
    out += "query nullableStringArg($nonNullableVar: String!, $nonNullab"
    out += "leList: [String!]!, $nonNullableListList: [[Int!]!]) {\n  ar"
    out += "guments {\n    nullableString(nullableString: $nonNullableVa"
    out += "r)\n    nullableList(nullableList: $nonNullableList)\n    nu"
    out += "llableListList(nullableListList: $nonNullableListList)\n  }"
    out += "\n}\n\ntype Query {\n    arguments: Arguments\n}\n\ntype Arg"
    out += "uments {\n    nullableString(nullableString: String): String"
    out += "\n    nullableList(nullableList: [String]): String\n    null"
    out += "ableListList(nullableListList: [[Int]]): Int\n}\n\n"
    return out^


def _expected_159() -> String:
    var out = String()
    return out^


def _path_160() -> String:
    var out = String()
    out += "ok/0034_built_in_directive_redefinition.graphql"
    return out^


def _input_160() -> String:
    var out = String()
    out += 'schema\n  @deprecated(\n    reason: """\n    The person w'
    out += "ho got promoted by shipping this product has moved on to ano"
    out += "ther team.\n    The service will shut down next month.\n    "
    out += '"""\n  ) {\n  query: Query\n}\n\ntype Query {\n  importan'
    out += "tData: Int\n}\n\ndirective @deprecated(\n  reason: String = "
    out += '"No longer supported"\n) on FIELD_DEFINITION | ARGUMENT_DE'
    out += "FINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE | SCHEMA\n"
    return out^


def _expected_160() -> String:
    var out = String()
    return out^


def _path_161() -> String:
    var out = String()
    out += "ok/0035_implicit_schema_definition_with_query_type.graphql"
    return out^


def _input_161() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}"
    return out^


def _expected_161() -> String:
    var out = String()
    return out^


def _path_162() -> String:
    var out = String()
    out += "ok/0036_implicit_schema_definition_with_several_default_type"
    out += "s.graphql"
    return out^


def _input_162() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\ntype Mutation {\n   add"
    out += "(name: String!): Result!\n}\n\ntype Result {\n  id: String\n"
    out += "}\n\n"
    return out^


def _expected_162() -> String:
    var out = String()
    return out^


def _path_163() -> String:
    var out = String()
    out += "ok/0037_implicit_schema_extension_with_directive.graphql"
    return out^


def _input_163() -> String:
    var out = String()
    out += "type Query {\n    name: String\n}\n\nextend schema @dir\ndir"
    out += "ective @dir on SCHEMA"
    return out^


def _expected_163() -> String:
    var out = String()
    return out^


def _path_164() -> String:
    var out = String()
    out += "ok/0038_argument_default.graphql"
    return out^


def _input_164() -> String:
    var out = String()
    out += "directive @defer(\n  label: String\n  if: Boolean! = true\n)"
    out += " on FRAGMENT_SPREAD | INLINE_FRAGMENT\n\ntype Query {\n  gui"
    out += "tarAmp(upTo: Int! = 11): String\n}\n\n{\n  ... @defer {\n   "
    out += " guitarAmp\n  }\n}\n"
    return out^


def _expected_164() -> String:
    var out = String()
    return out^


def _path_165() -> String:
    var out = String()
    out += "ok/0039_string_literals.graphql"
    return out^


def _input_165() -> String:
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


def _expected_165() -> String:
    var out = String()
    return out^


def _path_166() -> String:
    var out = String()
    out += "ok/0040_field_merging_issue_755.graphql"
    return out^


def _input_166() -> String:
    var out = String()
    out += "# Different fragments selecting the same name from different"
    out += " types\n# into different subselections -- all valid, unless "
    out += "apollo-rs\n# propagates type conditions incorrectly :)\n\nty"
    out += "pe Subselection {\n  createdAt: Int!\n}\n\ntype Issue {\n  c"
    out += "reatedAt: Int\n  subselection: [Subselection!]\n}\n\ntype Qu"
    out += "ery {\n  issue755: Issue\n}\n\nfragment topLevelFragment on "
    out += "Issue {\n  subselection {\n    createdAt\n    ...subselectio"
    out += "nFragment\n  }\n  ...collidingTopLevelFragment\n}\nfragment "
    out += "collidingTopLevelFragment on Issue {\n  subselection {\n    "
    out += "createdAt\n  }\n}\nfragment subselectionFragment on Subselec"
    out += "tion {\n  createdAt\n}\nquery  {\n  issue755 {\n    ...topLe"
    out += "velFragment\n  }\n}\n"
    return out^


def _expected_166() -> String:
    var out = String()
    return out^


def _path_167() -> String:
    var out = String()
    out += "ok/0041_unquoted_string_for_custom_scalar.graphql"
    return out^


def _input_167() -> String:
    var out = String()
    out += "scalar Currency\n\ntype Query {\n  convertToUSD(amount: Int!"
    out += ", currency: Currency!): Int!\n}\n\nquery {\n  convertToUSD(a"
    out += "mount: 100, currency: EUR)\n}\n"
    return out^


def _expected_167() -> String:
    var out = String()
    return out^


def _path_168() -> String:
    var out = String()
    out += "ok/0042_used_variable_in_operation_directive.graphql"
    return out^


def _input_168() -> String:
    var out = String()
    out += "directive @x(y: Int!) on QUERY | MUTATION | SUBSCRIPTION\ndi"
    out += "rective @z(f: Boolean) on FRAGMENT_DEFINITION\n\ntype Query "
    out += "{ field: Boolean }\ntype Mutation { field: Boolean }\ntype S"
    out += "ubscription { field: Boolean }\n\nquery Q ($a: Int!, $f: Boo"
    out += "lean) @x(y: $a) { field ...f }\nmutation M ($b: Int!) @x(y: "
    out += "$b) { field }\nsubscription S ($c: Int!) @x(y: $c) { field }"
    out += "\n\nfragment f on Query @z(f: $f) { field }\n"
    return out^


def _expected_168() -> String:
    var out = String()
    return out^


def _path_169() -> String:
    var out = String()
    out += "ok/0115_interface_definition_with_extension_defines_field.gr"
    out += "aphql"
    return out^


def _input_169() -> String:
    var out = String()
    out += "type Query {\n    foo: Node\n}\n\ninterface Node\n\nextend i"
    out += "nterface Node {\n    bar: String\n}\n"
    return out^


def _expected_169() -> String:
    var out = String()
    return out^


def _path_170() -> String:
    var out = String()
    out += "ok/0116_interface_without_implementations.graphql"
    return out^


def _input_170() -> String:
    var out = String()
    out += "type Query {\n  intf: Intf\n}\ninterface Intf {\n  field: In"
    out += "t\n}\n\nquery SelectDirectly {\n  intf { field }\n}\n\nquery"
    out += " UsingInlineFragment {\n  intf {\n    ... on Intf { field }"
    out += "\n  }\n}\n"
    return out^


def _expected_170() -> String:
    var out = String()
    return out^


def _path_171() -> String:
    var out = String()
    out += "ok/0117_subscription_conditions_not_at_root.graphql"
    return out^


def _input_171() -> String:
    var out = String()
    out += "subscription ConditionalSub($includeContent: Boolean = true,"
    out += " $small: Boolean = true) {\n    messages {\n        username"
    out += "\n        text @include(if: $includeContent)\n        avatar"
    out += " @skip(if: $small)\n    }\n}\n\ntype Query {\n    hello: Str"
    out += "ing\n}\n\ntype Message {\n    username: String\n    text: St"
    out += "ring\n    avatar: String\n}\n\ntype Subscription {\n    mess"
    out += "ages: Message\n}\n"
    return out^


def _expected_171() -> String:
    var out = String()
    return out^


def _path_172() -> String:
    var out = String()
    out += "ok/0118_directive_with_nested_input_types.graphql"
    return out^


def _input_172() -> String:
    var out = String()
    out += "directive @custom(input: NestedInput) on OBJECT | INTERFACE"
    out += "\n\ninput NestedInput {\n  name: String\n  nested: NestedInp"
    out += 'ut\n}\n\ntype Query @custom(input: {name: "hello", nested:'
    out += ' {name: "hello"}}) {\n  foo: String\n}\n\nquery myQuery {'
    out += "\n  foo\n}"
    return out^


def _expected_172() -> String:
    var out = String()
    return out^


def _path_173() -> String:
    var out = String()
    out += "ok/0119_directive_with_argument_type_collisions.graphql"
    return out^


def _input_173() -> String:
    var out = String()
    out += "directive @custom(input: Custom) on OBJECT | INTERFACE\n\nin"
    out += "put Custom {\n  name: String\n  nested: Custom\n}\n\ntype Qu"
    out += 'ery @custom(input: {name: "hello", nested: {name: "hello'
    out += '"}}) {\n  foo: String\n}\n\nquery myQuery {\n  foo\n}'
    return out^


def _expected_173() -> String:
    var out = String()
    return out^


def _path_174() -> String:
    var out = String()
    out += "ok/0120_defer_in_subscription_under_variable_skip.graphql"
    return out^


def _input_174() -> String:
    var out = String()
    out += "subscription Sub($cond: Boolean!) {\n    newMessage {\n     "
    out += "   ... @skip(if: $cond) {\n            ... @defer {\n       "
    out += "         body\n            }\n        }\n    }\n}\n\ndirecti"
    out += "ve @defer(\n    if: Boolean! = true\n    label: String\n) on"
    out += " FRAGMENT_SPREAD | INLINE_FRAGMENT\n\ntype Query {\n    mess"
    out += "age: Message\n}\n\ntype Subscription {\n    newMessage: Mess"
    out += "age\n}\n\ntype Message {\n    body: String\n}\n"
    return out^


def _expected_174() -> String:
    var out = String()
    return out^


def _path_175() -> String:
    var out = String()
    out += "ok/0121_defer_label_fragment_spread_multiple_times.graphql"
    return out^


def _input_175() -> String:
    var out = String()
    out += "# The label uniqueness rule counts @defer directives in the "
    out += "document as\n# written. A labeled @defer inside a fragment d"
    out += "efinition is a single\n# directive, so spreading the fragmen"
    out += "t in multiple places is valid, even\n# though execution emit"
    out += "s multiple same-label pending payloads (clients\n# disambigu"
    out += "ate by path/id). This mirrors Relay, which derives labels fr"
    out += "om\n# the enclosing fragment name.\nquery Q {\n    me {\n   "
    out += "     ...ItemFragment\n    }\n    friend {\n        ...ItemFr"
    out += "agment\n    }\n}\n\nfragment ItemFragment on User {\n    ..."
    out += ' @defer(label: "ItemFragment") {\n        id\n    }\n}\n\n'
    out += "directive @defer(\n    if: Boolean! = true\n    label: Strin"
    out += "g\n) on FRAGMENT_SPREAD | INLINE_FRAGMENT\n\ntype Query {\n "
    out += "   me: User\n    friend: User\n}\n\ntype User {\n    id: ID"
    out += "\n}\n"
    return out^


def _expected_175() -> String:
    var out = String()
    return out^


def validation_cases() -> List[String]:
    """Return the path of each case."""
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
    return out^


def validation_input(index: Int) -> String:
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
    if index == 74:
        return _input_74()
    if index == 75:
        return _input_75()
    if index == 76:
        return _input_76()
    if index == 77:
        return _input_77()
    if index == 78:
        return _input_78()
    if index == 79:
        return _input_79()
    if index == 80:
        return _input_80()
    if index == 81:
        return _input_81()
    if index == 82:
        return _input_82()
    if index == 83:
        return _input_83()
    if index == 84:
        return _input_84()
    if index == 85:
        return _input_85()
    if index == 86:
        return _input_86()
    if index == 87:
        return _input_87()
    if index == 88:
        return _input_88()
    if index == 89:
        return _input_89()
    if index == 90:
        return _input_90()
    if index == 91:
        return _input_91()
    if index == 92:
        return _input_92()
    if index == 93:
        return _input_93()
    if index == 94:
        return _input_94()
    if index == 95:
        return _input_95()
    if index == 96:
        return _input_96()
    if index == 97:
        return _input_97()
    if index == 98:
        return _input_98()
    if index == 99:
        return _input_99()
    if index == 100:
        return _input_100()
    if index == 101:
        return _input_101()
    if index == 102:
        return _input_102()
    if index == 103:
        return _input_103()
    if index == 104:
        return _input_104()
    if index == 105:
        return _input_105()
    if index == 106:
        return _input_106()
    if index == 107:
        return _input_107()
    if index == 108:
        return _input_108()
    if index == 109:
        return _input_109()
    if index == 110:
        return _input_110()
    if index == 111:
        return _input_111()
    if index == 112:
        return _input_112()
    if index == 113:
        return _input_113()
    if index == 114:
        return _input_114()
    if index == 115:
        return _input_115()
    if index == 116:
        return _input_116()
    if index == 117:
        return _input_117()
    if index == 118:
        return _input_118()
    if index == 119:
        return _input_119()
    if index == 120:
        return _input_120()
    if index == 121:
        return _input_121()
    if index == 122:
        return _input_122()
    if index == 123:
        return _input_123()
    if index == 124:
        return _input_124()
    if index == 125:
        return _input_125()
    if index == 126:
        return _input_126()
    if index == 127:
        return _input_127()
    if index == 128:
        return _input_128()
    if index == 129:
        return _input_129()
    if index == 130:
        return _input_130()
    if index == 131:
        return _input_131()
    if index == 132:
        return _input_132()
    if index == 133:
        return _input_133()
    if index == 134:
        return _input_134()
    if index == 135:
        return _input_135()
    if index == 136:
        return _input_136()
    if index == 137:
        return _input_137()
    if index == 138:
        return _input_138()
    if index == 139:
        return _input_139()
    if index == 140:
        return _input_140()
    if index == 141:
        return _input_141()
    if index == 142:
        return _input_142()
    if index == 143:
        return _input_143()
    if index == 144:
        return _input_144()
    if index == 145:
        return _input_145()
    if index == 146:
        return _input_146()
    if index == 147:
        return _input_147()
    if index == 148:
        return _input_148()
    if index == 149:
        return _input_149()
    if index == 150:
        return _input_150()
    if index == 151:
        return _input_151()
    if index == 152:
        return _input_152()
    if index == 153:
        return _input_153()
    if index == 154:
        return _input_154()
    if index == 155:
        return _input_155()
    if index == 156:
        return _input_156()
    if index == 157:
        return _input_157()
    if index == 158:
        return _input_158()
    if index == 159:
        return _input_159()
    if index == 160:
        return _input_160()
    if index == 161:
        return _input_161()
    if index == 162:
        return _input_162()
    if index == 163:
        return _input_163()
    if index == 164:
        return _input_164()
    if index == 165:
        return _input_165()
    if index == 166:
        return _input_166()
    if index == 167:
        return _input_167()
    if index == 168:
        return _input_168()
    if index == 169:
        return _input_169()
    if index == 170:
        return _input_170()
    if index == 171:
        return _input_171()
    if index == 172:
        return _input_172()
    if index == 173:
        return _input_173()
    if index == 174:
        return _input_174()
    if index == 175:
        return _input_175()
    return ""


def validation_expected(index: Int) -> String:
    """Return the expected lines of a case."""
    if index == 0:
        return _expected_0()
    if index == 1:
        return _expected_1()
    if index == 2:
        return _expected_2()
    if index == 3:
        return _expected_3()
    if index == 4:
        return _expected_4()
    if index == 5:
        return _expected_5()
    if index == 6:
        return _expected_6()
    if index == 7:
        return _expected_7()
    if index == 8:
        return _expected_8()
    if index == 9:
        return _expected_9()
    if index == 10:
        return _expected_10()
    if index == 11:
        return _expected_11()
    if index == 12:
        return _expected_12()
    if index == 13:
        return _expected_13()
    if index == 14:
        return _expected_14()
    if index == 15:
        return _expected_15()
    if index == 16:
        return _expected_16()
    if index == 17:
        return _expected_17()
    if index == 18:
        return _expected_18()
    if index == 19:
        return _expected_19()
    if index == 20:
        return _expected_20()
    if index == 21:
        return _expected_21()
    if index == 22:
        return _expected_22()
    if index == 23:
        return _expected_23()
    if index == 24:
        return _expected_24()
    if index == 25:
        return _expected_25()
    if index == 26:
        return _expected_26()
    if index == 27:
        return _expected_27()
    if index == 28:
        return _expected_28()
    if index == 29:
        return _expected_29()
    if index == 30:
        return _expected_30()
    if index == 31:
        return _expected_31()
    if index == 32:
        return _expected_32()
    if index == 33:
        return _expected_33()
    if index == 34:
        return _expected_34()
    if index == 35:
        return _expected_35()
    if index == 36:
        return _expected_36()
    if index == 37:
        return _expected_37()
    if index == 38:
        return _expected_38()
    if index == 39:
        return _expected_39()
    if index == 40:
        return _expected_40()
    if index == 41:
        return _expected_41()
    if index == 42:
        return _expected_42()
    if index == 43:
        return _expected_43()
    if index == 44:
        return _expected_44()
    if index == 45:
        return _expected_45()
    if index == 46:
        return _expected_46()
    if index == 47:
        return _expected_47()
    if index == 48:
        return _expected_48()
    if index == 49:
        return _expected_49()
    if index == 50:
        return _expected_50()
    if index == 51:
        return _expected_51()
    if index == 52:
        return _expected_52()
    if index == 53:
        return _expected_53()
    if index == 54:
        return _expected_54()
    if index == 55:
        return _expected_55()
    if index == 56:
        return _expected_56()
    if index == 57:
        return _expected_57()
    if index == 58:
        return _expected_58()
    if index == 59:
        return _expected_59()
    if index == 60:
        return _expected_60()
    if index == 61:
        return _expected_61()
    if index == 62:
        return _expected_62()
    if index == 63:
        return _expected_63()
    if index == 64:
        return _expected_64()
    if index == 65:
        return _expected_65()
    if index == 66:
        return _expected_66()
    if index == 67:
        return _expected_67()
    if index == 68:
        return _expected_68()
    if index == 69:
        return _expected_69()
    if index == 70:
        return _expected_70()
    if index == 71:
        return _expected_71()
    if index == 72:
        return _expected_72()
    if index == 73:
        return _expected_73()
    if index == 74:
        return _expected_74()
    if index == 75:
        return _expected_75()
    if index == 76:
        return _expected_76()
    if index == 77:
        return _expected_77()
    if index == 78:
        return _expected_78()
    if index == 79:
        return _expected_79()
    if index == 80:
        return _expected_80()
    if index == 81:
        return _expected_81()
    if index == 82:
        return _expected_82()
    if index == 83:
        return _expected_83()
    if index == 84:
        return _expected_84()
    if index == 85:
        return _expected_85()
    if index == 86:
        return _expected_86()
    if index == 87:
        return _expected_87()
    if index == 88:
        return _expected_88()
    if index == 89:
        return _expected_89()
    if index == 90:
        return _expected_90()
    if index == 91:
        return _expected_91()
    if index == 92:
        return _expected_92()
    if index == 93:
        return _expected_93()
    if index == 94:
        return _expected_94()
    if index == 95:
        return _expected_95()
    if index == 96:
        return _expected_96()
    if index == 97:
        return _expected_97()
    if index == 98:
        return _expected_98()
    if index == 99:
        return _expected_99()
    if index == 100:
        return _expected_100()
    if index == 101:
        return _expected_101()
    if index == 102:
        return _expected_102()
    if index == 103:
        return _expected_103()
    if index == 104:
        return _expected_104()
    if index == 105:
        return _expected_105()
    if index == 106:
        return _expected_106()
    if index == 107:
        return _expected_107()
    if index == 108:
        return _expected_108()
    if index == 109:
        return _expected_109()
    if index == 110:
        return _expected_110()
    if index == 111:
        return _expected_111()
    if index == 112:
        return _expected_112()
    if index == 113:
        return _expected_113()
    if index == 114:
        return _expected_114()
    if index == 115:
        return _expected_115()
    if index == 116:
        return _expected_116()
    if index == 117:
        return _expected_117()
    if index == 118:
        return _expected_118()
    if index == 119:
        return _expected_119()
    if index == 120:
        return _expected_120()
    if index == 121:
        return _expected_121()
    if index == 122:
        return _expected_122()
    if index == 123:
        return _expected_123()
    if index == 124:
        return _expected_124()
    if index == 125:
        return _expected_125()
    if index == 126:
        return _expected_126()
    if index == 127:
        return _expected_127()
    if index == 128:
        return _expected_128()
    if index == 129:
        return _expected_129()
    if index == 130:
        return _expected_130()
    if index == 131:
        return _expected_131()
    if index == 132:
        return _expected_132()
    if index == 133:
        return _expected_133()
    if index == 134:
        return _expected_134()
    if index == 135:
        return _expected_135()
    if index == 136:
        return _expected_136()
    if index == 137:
        return _expected_137()
    if index == 138:
        return _expected_138()
    if index == 139:
        return _expected_139()
    if index == 140:
        return _expected_140()
    if index == 141:
        return _expected_141()
    if index == 142:
        return _expected_142()
    if index == 143:
        return _expected_143()
    if index == 144:
        return _expected_144()
    if index == 145:
        return _expected_145()
    if index == 146:
        return _expected_146()
    if index == 147:
        return _expected_147()
    if index == 148:
        return _expected_148()
    if index == 149:
        return _expected_149()
    if index == 150:
        return _expected_150()
    if index == 151:
        return _expected_151()
    if index == 152:
        return _expected_152()
    if index == 153:
        return _expected_153()
    if index == 154:
        return _expected_154()
    if index == 155:
        return _expected_155()
    if index == 156:
        return _expected_156()
    if index == 157:
        return _expected_157()
    if index == 158:
        return _expected_158()
    if index == 159:
        return _expected_159()
    if index == 160:
        return _expected_160()
    if index == 161:
        return _expected_161()
    if index == 162:
        return _expected_162()
    if index == 163:
        return _expected_163()
    if index == 164:
        return _expected_164()
    if index == 165:
        return _expected_165()
    if index == 166:
        return _expected_166()
    if index == 167:
        return _expected_167()
    if index == 168:
        return _expected_168()
    if index == 169:
        return _expected_169()
    if index == 170:
        return _expected_170()
    if index == 171:
        return _expected_171()
    if index == 172:
        return _expected_172()
    if index == 173:
        return _expected_173()
    if index == 174:
        return _expected_174()
    if index == 175:
        return _expected_175()
    return ""
