# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""What Rover 1.0.0 (`39a041a`) prints for the stub endpoint of
`_endpoint.mojo`.

Each entry is `<command>-<path>.<format>.<stream>`: the standard output
(`out`), the standard error (`err`) or the exit code (`rc`) of
`rover <command> introspect http://127.0.0.1:<port>/<path> --format
<format> -H x-token:abc -H "X-Two: b c"`, run with the release build of
the Rover clone. The `graph-legacy` entries are left out: Rover 1.0.0
fails them, as the module docstring of `gql_seamstress.introspect` explains.
The program name in a suggestion is `seamstress`, where Rover writes
`rover`.
"""

from std.collections import Dict


def snapshots() -> Dict[String, String]:
    """Return every snapshot by name."""
    var out = Dict[String, String]()
    out["graph-array.json.err"] = ""
    out["graph-array.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 2"],"code":null}'
        "}\n"
    )
    out["graph-array.json.rc"] = "1\n"
    out["graph-array.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 2\n"
    )
    out["graph-array.plain.out"] = ""
    out["graph-array.plain.rc"] = "1\n"
    out["graph-bad-kind.json.err"] = ""
    out["graph-bad-kind.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 157"],"code":nul'
        "l}}\n"
    )
    out["graph-bad-kind.json.rc"] = "1\n"
    out["graph-bad-kind.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 157\n"
    )
    out["graph-bad-kind.plain.out"] = ""
    out["graph-bad-kind.plain.rc"] = "1\n"
    out["graph-data-null.json.err"] = ""
    out["graph-data-null.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["graph-data-null.json.rc"] = "1\n"
    out[
        "graph-data-null.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["graph-data-null.plain.out"] = ""
    out["graph-data-null.plain.rc"] = "1\n"
    out["graph-errors-odd.json.err"] = ""
    out["graph-errors-odd.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 43"],"code":null'
        "}}\n"
    )
    out["graph-errors-odd.json.rc"] = "1\n"
    out["graph-errors-odd.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 43\n"
    )
    out["graph-errors-odd.plain.out"] = ""
    out["graph-errors-odd.plain.rc"] = "1\n"
    out["graph-graph.json.err"] = ""
    out["graph-graph.json.out"] = (
        '{"json_version":"1","data":{"introspection_response":{"__schema"'
        ':{"queryType":{"name":"Query"},"mutationType":{"name":"Mutation"'
        '},"subscriptionType":{"name":"Subscription"},"types":[{"kind":"O'
        'BJECT","name":"__Schema","description":"A GraphQL Schema defines'
        " the capabilities of a GraphQL server. It exposes all available "
        "types and directives on the server, as well as the entry points "
        'for query, mutation, and subscription operations.","fields":[{"n'
        'ame":"description","description":null,"args":[],"type":{"kind":"'
        'SCALAR","name":"String","ofType":null},"isDeprecated":false,"dep'
        'recationReason":null},{"name":"types","description":"A list of a'
        'll types supported by this server.","args":[],"type":{"kind":"NO'
        'N_NULL","name":null,"ofType":{"kind":"LIST","name":null,"ofType"'
        ':{"kind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","name"'
        ':"__Type","ofType":null}}}},"isDeprecated":false,"deprecationRea'
        'son":null},{"name":"queryType","description":"The type that quer'
        'y operations will be rooted at.","args":[],"type":{"kind":"NON_N'
        'ULL","name":null,"ofType":{"kind":"OBJECT","name":"__Type","ofTy'
        'pe":null}},"isDeprecated":false,"deprecationReason":null},{"name'
        '":"mutationType","description":"If this server supports mutation'
        ', the type that mutation operations will be rooted at.","args":['
        '],"type":{"kind":"OBJECT","name":"__Type","ofType":null},"isDepr'
        'ecated":false,"deprecationReason":null},{"name":"subscriptionTyp'
        'e","description":"If this server support subscription, the type '
        'that subscription operations will be rooted at.","args":[],"type'
        '":{"kind":"OBJECT","name":"__Type","ofType":null},"isDeprecated"'
        ':false,"deprecationReason":null},{"name":"directives","descripti'
        'on":"A list of all directives supported by this server.","args":'
        '[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"LIST"'
        ',"name":null,"ofType":{"kind":"NON_NULL","name":null,"ofType":{"'
        'kind":"OBJECT","name":"__Directive","ofType":null}}}},"isDepreca'
        'ted":false,"deprecationReason":null}],"inputFields":null,"interf'
        'aces":[],"enumValues":null,"possibleTypes":null},{"kind":"OBJECT'
        '","name":"__Type","description":"The fundamental unit of any Gra'
        "phQL Schema is the type. There are many kinds of types in GraphQ"
        "L as represented by the `__TypeKind` enum.\\n\\nDepending on the k"
        "ind of a type, certain fields describe information about that ty"
        "pe. Scalar types provide no information beyond a name, descripti"
        "on and optional `specifiedByURL`, while Enum types provide their"
        " values. Object and Interface types provide the fields they desc"
        "ribe. Abstract types, Union and Interface, provide the Object ty"
        "pes possible at runtime. List and NonNull types compose other ty"
        'pes.","fields":[{"name":"kind","description":null,"args":[],"typ'
        'e":{"kind":"NON_NULL","name":null,"ofType":{"kind":"ENUM","name"'
        ':"__TypeKind","ofType":null}},"isDeprecated":false,"deprecationR'
        'eason":null},{"name":"name","description":null,"args":[],"type":'
        '{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated":f'
        'alse,"deprecationReason":null},{"name":"description","descriptio'
        'n":null,"args":[],"type":{"kind":"SCALAR","name":"String","ofTyp'
        'e":null},"isDeprecated":false,"deprecationReason":null},{"name":'
        '"fields","description":null,"args":[{"name":"includeDeprecated",'
        '"description":null,"type":{"kind":"SCALAR","name":"Boolean","ofT'
        'ype":null},"defaultValue":"false","isDeprecated":false,"deprecat'
        'ionReason":null}],"type":{"kind":"LIST","name":null,"ofType":{"k'
        'ind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","name":"__'
        'Field","ofType":null}}},"isDeprecated":false,"deprecationReason"'
        ':null},{"name":"interfaces","description":null,"args":[],"type":'
        '{"kind":"LIST","name":null,"ofType":{"kind":"NON_NULL","name":nu'
        'll,"ofType":{"kind":"OBJECT","name":"__Type","ofType":null}}},"i'
        'sDeprecated":false,"deprecationReason":null},{"name":"possibleTy'
        'pes","description":null,"args":[],"type":{"kind":"LIST","name":n'
        'ull,"ofType":{"kind":"NON_NULL","name":null,"ofType":{"kind":"OB'
        'JECT","name":"__Type","ofType":null}}},"isDeprecated":false,"dep'
        'recationReason":null},{"name":"enumValues","description":null,"a'
        'rgs":[{"name":"includeDeprecated","description":null,"type":{"ki'
        'nd":"SCALAR","name":"Boolean","ofType":null},"defaultValue":"fal'
        'se","isDeprecated":false,"deprecationReason":null}],"type":{"kin'
        'd":"LIST","name":null,"ofType":{"kind":"NON_NULL","name":null,"o'
        'fType":{"kind":"OBJECT","name":"__EnumValue","ofType":null}}},"i'
        'sDeprecated":false,"deprecationReason":null},{"name":"inputField'
        's","description":null,"args":[{"name":"includeDeprecated","descr'
        'iption":null,"type":{"kind":"SCALAR","name":"Boolean","ofType":n'
        'ull},"defaultValue":"false","isDeprecated":false,"deprecationRea'
        'son":null}],"type":{"kind":"LIST","name":null,"ofType":{"kind":"'
        'NON_NULL","name":null,"ofType":{"kind":"OBJECT","name":"__InputV'
        'alue","ofType":null}}},"isDeprecated":false,"deprecationReason":'
        'null},{"name":"ofType","description":null,"args":[],"type":{"kin'
        'd":"OBJECT","name":"__Type","ofType":null},"isDeprecated":false,'
        '"deprecationReason":null},{"name":"specifiedByURL","description"'
        ':null,"args":[],"type":{"kind":"SCALAR","name":"String","ofType"'
        ':null},"isDeprecated":false,"deprecationReason":null}],"inputFie'
        'lds":null,"interfaces":[],"enumValues":null,"possibleTypes":null'
        '},{"kind":"ENUM","name":"__TypeKind","description":"An enum desc'
        'ribing what kind of type a given `__Type` is.","fields":null,"in'
        'putFields":null,"interfaces":null,"enumValues":[{"name":"SCALAR"'
        ',"description":"Indicates this type is a scalar.","isDeprecated"'
        ':false,"deprecationReason":null},{"name":"OBJECT","description":'
        '"Indicates this type is an object. `fields` and `interfaces` are'
        ' valid fields.","isDeprecated":false,"deprecationReason":null},{'
        '"name":"INTERFACE","description":"Indicates this type is an inte'
        "rface. `fields`, `interfaces`, and `possibleTypes` are valid fie"
        'lds.","isDeprecated":false,"deprecationReason":null},{"name":"UN'
        'ION","description":"Indicates this type is a union. `possibleTyp'
        'es` is a valid field.","isDeprecated":false,"deprecationReason":'
        'null},{"name":"ENUM","description":"Indicates this type is an en'
        'um. `enumValues` is a valid field.","isDeprecated":false,"deprec'
        'ationReason":null},{"name":"INPUT_OBJECT","description":"Indicat'
        "es this type is an input object. `inputFields` is a valid field."
        '","isDeprecated":false,"deprecationReason":null},{"name":"LIST",'
        '"description":"Indicates this type is a list. `ofType` is a vali'
        'd field.","isDeprecated":false,"deprecationReason":null},{"name"'
        ':"NON_NULL","description":"Indicates this type is a non-null. `o'
        'fType` is a valid field.","isDeprecated":false,"deprecationReaso'
        'n":null}],"possibleTypes":null},{"kind":"OBJECT","name":"__Field'
        '","description":"Object and Interface types are described by a l'
        "ist of Fields, each of which has a name, potentially a list of a"
        'rguments, and a return type.","fields":[{"name":"name","descript'
        'ion":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofTyp'
        'e":{"kind":"SCALAR","name":"String","ofType":null}},"isDeprecate'
        'd":false,"deprecationReason":null},{"name":"description","descri'
        'ption":null,"args":[],"type":{"kind":"SCALAR","name":"String","o'
        'fType":null},"isDeprecated":false,"deprecationReason":null},{"na'
        'me":"args","description":null,"args":[{"name":"includeDeprecated'
        '","description":null,"type":{"kind":"SCALAR","name":"Boolean","o'
        'fType":null},"defaultValue":"false","isDeprecated":false,"deprec'
        'ationReason":null}],"type":{"kind":"NON_NULL","name":null,"ofTyp'
        'e":{"kind":"LIST","name":null,"ofType":{"kind":"NON_NULL","name"'
        ':null,"ofType":{"kind":"OBJECT","name":"__InputValue","ofType":n'
        'ull}}}},"isDeprecated":false,"deprecationReason":null},{"name":"'
        'type","description":null,"args":[],"type":{"kind":"NON_NULL","na'
        'me":null,"ofType":{"kind":"OBJECT","name":"__Type","ofType":null'
        '}},"isDeprecated":false,"deprecationReason":null},{"name":"isDep'
        'recated","description":null,"args":[],"type":{"kind":"NON_NULL",'
        '"name":null,"ofType":{"kind":"SCALAR","name":"Boolean","ofType":'
        'null}},"isDeprecated":false,"deprecationReason":null},{"name":"d'
        'eprecationReason","description":null,"args":[],"type":{"kind":"S'
        'CALAR","name":"String","ofType":null},"isDeprecated":false,"depr'
        'ecationReason":null}],"inputFields":null,"interfaces":[],"enumVa'
        'lues":null,"possibleTypes":null},{"kind":"OBJECT","name":"__Inpu'
        'tValue","description":"Arguments provided to Fields or Directive'
        "s and the input fields of an InputObject are represented as Inpu"
        "t Values which describe their type and optionally a default valu"
        'e.","fields":[{"name":"name","description":null,"args":[],"type"'
        ':{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name"'
        ':"String","ofType":null}},"isDeprecated":false,"deprecationReaso'
        'n":null},{"name":"description","description":null,"args":[],"typ'
        'e":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated'
        '":false,"deprecationReason":null},{"name":"type","description":n'
        'ull,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"k'
        'ind":"OBJECT","name":"__Type","ofType":null}},"isDeprecated":fal'
        'se,"deprecationReason":null},{"name":"defaultValue","description'
        '":"A GraphQL-formatted string representing the default value for'
        ' this input value.","args":[],"type":{"kind":"SCALAR","name":"St'
        'ring","ofType":null},"isDeprecated":false,"deprecationReason":nu'
        'll},{"name":"isDeprecated","description":null,"args":[],"type":{'
        '"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"'
        'Boolean","ofType":null}},"isDeprecated":false,"deprecationReason'
        '":null},{"name":"deprecationReason","description":null,"args":[]'
        ',"type":{"kind":"SCALAR","name":"String","ofType":null},"isDepre'
        'cated":false,"deprecationReason":null}],"inputFields":null,"inte'
        'rfaces":[],"enumValues":null,"possibleTypes":null},{"kind":"OBJE'
        'CT","name":"__EnumValue","description":"One possible value for a'
        " given Enum. Enum values are unique values, not a placeholder fo"
        "r a string or numeric value. However an Enum value is returned i"
        'n a JSON response as a string.","fields":[{"name":"name","descri'
        'ption":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofT'
        'ype":{"kind":"SCALAR","name":"String","ofType":null}},"isDepreca'
        'ted":false,"deprecationReason":null},{"name":"description","desc'
        'ription":null,"args":[],"type":{"kind":"SCALAR","name":"String",'
        '"ofType":null},"isDeprecated":false,"deprecationReason":null},{"'
        'name":"isDeprecated","description":null,"args":[],"type":{"kind"'
        ':"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"Boolea'
        'n","ofType":null}},"isDeprecated":false,"deprecationReason":null'
        '},{"name":"deprecationReason","description":null,"args":[],"type'
        '":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated"'
        ':false,"deprecationReason":null}],"inputFields":null,"interfaces'
        '":[],"enumValues":null,"possibleTypes":null},{"kind":"OBJECT","n'
        'ame":"__Directive","description":"A Directive provides a way to '
        "describe alternate runtime execution and type validation behavio"
        "r in a GraphQL document.\\n\\nIn some cases, you need to provide o"
        "ptions to alter GraphQL's execution behavior in ways field argum"
        "ents will not suffice, such as conditionally including or skippi"
        "ng a field. Directives provide this by describing additional inf"
        'ormation to the executor.","fields":[{"name":"name","description'
        '":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":'
        '{"kind":"SCALAR","name":"String","ofType":null}},"isDeprecated":'
        'false,"deprecationReason":null},{"name":"description","descripti'
        'on":null,"args":[],"type":{"kind":"SCALAR","name":"String","ofTy'
        'pe":null},"isDeprecated":false,"deprecationReason":null},{"name"'
        ':"locations","description":null,"args":[],"type":{"kind":"NON_NU'
        'LL","name":null,"ofType":{"kind":"LIST","name":null,"ofType":{"k'
        'ind":"NON_NULL","name":null,"ofType":{"kind":"ENUM","name":"__Di'
        'rectiveLocation","ofType":null}}}},"isDeprecated":false,"depreca'
        'tionReason":null},{"name":"args","description":null,"args":[{"na'
        'me":"includeDeprecated","description":null,"type":{"kind":"SCALA'
        'R","name":"Boolean","ofType":null},"defaultValue":"false","isDep'
        'recated":false,"deprecationReason":null}],"type":{"kind":"NON_NU'
        'LL","name":null,"ofType":{"kind":"LIST","name":null,"ofType":{"k'
        'ind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","name":"__'
        'InputValue","ofType":null}}}},"isDeprecated":false,"deprecationR'
        'eason":null},{"name":"isRepeatable","description":null,"args":[]'
        ',"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR"'
        ',"name":"Boolean","ofType":null}},"isDeprecated":false,"deprecat'
        'ionReason":null}],"inputFields":null,"interfaces":[],"enumValues'
        '":null,"possibleTypes":null},{"kind":"ENUM","name":"__DirectiveL'
        'ocation","description":"A Directive can be adjacent to many part'
        "s of the GraphQL language, a __DirectiveLocation describes one s"
        'uch possible adjacencies.","fields":null,"inputFields":null,"int'
        'erfaces":null,"enumValues":[{"name":"QUERY","description":"Locat'
        'ion adjacent to a query operation.","isDeprecated":false,"deprec'
        'ationReason":null},{"name":"MUTATION","description":"Location ad'
        'jacent to a mutation operation.","isDeprecated":false,"deprecati'
        'onReason":null},{"name":"SUBSCRIPTION","description":"Location a'
        'djacent to a subscription operation.","isDeprecated":false,"depr'
        'ecationReason":null},{"name":"FIELD","description":"Location adj'
        'acent to a field.","isDeprecated":false,"deprecationReason":null'
        '},{"name":"FRAGMENT_DEFINITION","description":"Location adjacent'
        ' to a fragment definition.","isDeprecated":false,"deprecationRea'
        'son":null},{"name":"FRAGMENT_SPREAD","description":"Location adj'
        'acent to a fragment spread.","isDeprecated":false,"deprecationRe'
        'ason":null},{"name":"INLINE_FRAGMENT","description":"Location ad'
        'jacent to an inline fragment.","isDeprecated":false,"deprecation'
        'Reason":null},{"name":"VARIABLE_DEFINITION","description":"Locat'
        'ion adjacent to a variable definition.","isDeprecated":false,"de'
        'precationReason":null},{"name":"SCHEMA","description":"Location '
        'adjacent to a schema definition.","isDeprecated":false,"deprecat'
        'ionReason":null},{"name":"SCALAR","description":"Location adjace'
        'nt to a scalar definition.","isDeprecated":false,"deprecationRea'
        'son":null},{"name":"OBJECT","description":"Location adjacent to '
        'an object type definition.","isDeprecated":false,"deprecationRea'
        'son":null},{"name":"FIELD_DEFINITION","description":"Location ad'
        'jacent to a field definition.","isDeprecated":false,"deprecation'
        'Reason":null},{"name":"ARGUMENT_DEFINITION","description":"Locat'
        'ion adjacent to an argument definition.","isDeprecated":false,"d'
        'eprecationReason":null},{"name":"INTERFACE","description":"Locat'
        'ion adjacent to an interface definition.","isDeprecated":false,"'
        'deprecationReason":null},{"name":"UNION","description":"Location'
        ' adjacent to a union definition.","isDeprecated":false,"deprecat'
        'ionReason":null},{"name":"ENUM","description":"Location adjacent'
        ' to an enum definition.","isDeprecated":false,"deprecationReason'
        '":null},{"name":"ENUM_VALUE","description":"Location adjacent to'
        ' an enum value definition.","isDeprecated":false,"deprecationRea'
        'son":null},{"name":"INPUT_OBJECT","description":"Location adjace'
        'nt to an input object type definition.","isDeprecated":false,"de'
        'precationReason":null},{"name":"INPUT_FIELD_DEFINITION","descrip'
        'tion":"Location adjacent to an input object field definition.","'
        'isDeprecated":false,"deprecationReason":null}],"possibleTypes":n'
        'ull},{"kind":"SCALAR","name":"Int","description":"The `Int` scal'
        "ar type represents non-fractional signed whole numeric values. I"
        'nt can represent values between -(2^31) and 2^31 - 1.","fields":'
        'null,"inputFields":null,"interfaces":null,"enumValues":null,"pos'
        'sibleTypes":null},{"kind":"SCALAR","name":"Float","description":'
        '"The `Float` scalar type represents signed double-precision frac'
        "tional values as specified by [IEEE 754](https://en.wikipedia.or"
        'g/wiki/IEEE_floating_point).","fields":null,"inputFields":null,"'
        'interfaces":null,"enumValues":null,"possibleTypes":null},{"kind"'
        ':"SCALAR","name":"String","description":"The `String` scalar typ'
        "e represents textual data, represented as UTF-8 character sequen"
        "ces. The String type is most often used by GraphQL to represent "
        'free-form human-readable text.","fields":null,"inputFields":null'
        ',"interfaces":null,"enumValues":null,"possibleTypes":null},{"kin'
        'd":"SCALAR","name":"Boolean","description":"The `Boolean` scalar'
        ' type represents `true` or `false`.","fields":null,"inputFields"'
        ':null,"interfaces":null,"enumValues":null,"possibleTypes":null},'
        '{"kind":"SCALAR","name":"ID","description":"The `ID` scalar type'
        " represents a unique identifier, often used to refetch an object"
        " or as key for a cache. The ID type appears in a JSON response a"
        "s a String; however, it is not intended to be human-readable. Wh"
        'en expected as an input type, any string (such as `\\"4\\"`) or in'
        'teger (such as `4`) input value will be accepted as an ID.","fie'
        'lds":null,"inputFields":null,"interfaces":null,"enumValues":null'
        ',"possibleTypes":null},{"kind":"SCALAR","name":"Date","descripti'
        'on":"A date, as `YYYY-MM-DD`.","fields":null,"inputFields":null,'
        '"interfaces":null,"enumValues":null,"possibleTypes":null},{"kind'
        '":"OBJECT","name":"Query","description":"The root of every query'
        '.","fields":[{"name":"node","description":"Find a node by its ID'
        '.","args":[{"name":"id","description":"The ID of an object","typ'
        'e":{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","nam'
        'e":"ID","ofType":null}},"defaultValue":null,"isDeprecated":false'
        ',"deprecationReason":null}],"type":{"kind":"INTERFACE","name":"N'
        'ode","ofType":null},"isDeprecated":false,"deprecationReason":nul'
        'l},{"name":"books","description":null,"args":[{"name":"first","d'
        'escription":null,"type":{"kind":"SCALAR","name":"Int","ofType":n'
        'ull},"defaultValue":"10","isDeprecated":false,"deprecationReason'
        '":null},{"name":"after","description":null,"type":{"kind":"SCALA'
        'R","name":"String","ofType":null},"defaultValue":null,"isDepreca'
        'ted":false,"deprecationReason":null},{"name":"order","descriptio'
        'n":null,"type":{"kind":"ENUM","name":"Order","ofType":null},"def'
        'aultValue":"ASC","isDeprecated":false,"deprecationReason":null}]'
        ',"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"LIST","'
        'name":null,"ofType":{"kind":"NON_NULL","name":null,"ofType":{"ki'
        'nd":"OBJECT","name":"Book","ofType":null}}}},"isDeprecated":fals'
        'e,"deprecationReason":null},{"name":"search","description":null,'
        '"args":[{"name":"text","description":null,"type":{"kind":"NON_NU'
        'LL","name":null,"ofType":{"kind":"SCALAR","name":"String","ofTyp'
        'e":null}},"defaultValue":null,"isDeprecated":false,"deprecationR'
        'eason":null},{"name":"filter","description":null,"type":{"kind":'
        '"INPUT_OBJECT","name":"SearchFilter","ofType":null},"defaultValu'
        'e":null,"isDeprecated":false,"deprecationReason":null}],"type":{'
        '"kind":"LIST","name":null,"ofType":{"kind":"UNION","name":"Searc'
        'hResult","ofType":null}},"isDeprecated":false,"deprecationReason'
        '":null},{"name":"legacy","description":null,"args":[],"type":{"k'
        'ind":"SCALAR","name":"String","ofType":null},"isDeprecated":true'
        ',"deprecationReason":"No longer supported"},{"name":"old","descr'
        'iption":null,"args":[{"name":"arg","description":null,"type":{"k'
        'ind":"SCALAR","name":"Int","ofType":null},"defaultValue":null,"i'
        'sDeprecated":true,"deprecationReason":"Use `arg2`."}],"type":{"k'
        'ind":"SCALAR","name":"Int","ofType":null},"isDeprecated":true,"d'
        'eprecationReason":"Use `new`."},{"name":"long","description":nul'
        'l,"args":[],"type":{"kind":"SCALAR","name":"String","ofType":nul'
        'l},"isDeprecated":false,"deprecationReason":null}],"inputFields"'
        ':null,"interfaces":[],"enumValues":null,"possibleTypes":null},{"'
        'kind":"OBJECT","name":"Mutation","description":null,"fields":[{"'
        'name":"addBook","description":null,"args":[{"name":"input","desc'
        'ription":null,"type":{"kind":"NON_NULL","name":null,"ofType":{"k'
        'ind":"INPUT_OBJECT","name":"BookInput","ofType":null}},"defaultV'
        'alue":null,"isDeprecated":false,"deprecationReason":null}],"type'
        '":{"kind":"OBJECT","name":"Book","ofType":null},"isDeprecated":f'
        'alse,"deprecationReason":null}],"inputFields":null,"interfaces":'
        '[],"enumValues":null,"possibleTypes":null},{"kind":"OBJECT","nam'
        'e":"Subscription","description":null,"fields":[{"name":"bookAdde'
        'd","description":null,"args":[],"type":{"kind":"OBJECT","name":"'
        'Book","ofType":null},"isDeprecated":false,"deprecationReason":nu'
        'll}],"inputFields":null,"interfaces":[],"enumValues":null,"possi'
        'bleTypes":null},{"kind":"OBJECT","name":"Book","description":"A '
        'book.\\n\\nIt has a title and an author.","fields":[{"name":"id","'
        'description":null,"args":[],"type":{"kind":"NON_NULL","name":nul'
        'l,"ofType":{"kind":"SCALAR","name":"ID","ofType":null}},"isDepre'
        'cated":false,"deprecationReason":null},{"name":"title","descript'
        'ion":null,"args":[],"type":{"kind":"SCALAR","name":"String","ofT'
        'ype":null},"isDeprecated":false,"deprecationReason":null},{"name'
        '":"author","description":null,"args":[],"type":{"kind":"OBJECT",'
        '"name":"Author","ofType":null},"isDeprecated":false,"deprecation'
        'Reason":null},{"name":"tags","description":null,"args":[],"type"'
        ':{"kind":"LIST","name":null,"ofType":{"kind":"LIST","name":null,'
        '"ofType":{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR'
        '","name":"String","ofType":null}}}},"isDeprecated":false,"deprec'
        'ationReason":null}],"inputFields":null,"interfaces":[{"kind":"IN'
        'TERFACE","name":"Node","ofType":null}],"enumValues":null,"possib'
        'leTypes":null},{"kind":"OBJECT","name":"Author","description":nu'
        'll,"fields":[{"name":"id","description":null,"args":[],"type":{"'
        'kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"I'
        'D","ofType":null}},"isDeprecated":false,"deprecationReason":null'
        '},{"name":"name","description":null,"args":[],"type":{"kind":"SC'
        'ALAR","name":"String","ofType":null},"isDeprecated":false,"depre'
        'cationReason":null}],"inputFields":null,"interfaces":[{"kind":"I'
        'NTERFACE","name":"Node","ofType":null}],"enumValues":null,"possi'
        'bleTypes":null},{"kind":"INTERFACE","name":"Node","description":'
        '"An object with an ID.","fields":[{"name":"id","description":nul'
        'l,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kin'
        'd":"SCALAR","name":"ID","ofType":null}},"isDeprecated":false,"de'
        'precationReason":null}],"inputFields":null,"interfaces":[],"enum'
        'Values":null,"possibleTypes":[{"kind":"OBJECT","name":"Book","of'
        'Type":null},{"kind":"OBJECT","name":"Author","ofType":null}]},{"'
        'kind":"UNION","name":"SearchResult","description":null,"fields":'
        'null,"inputFields":null,"interfaces":null,"enumValues":null,"pos'
        'sibleTypes":[{"kind":"OBJECT","name":"Book","ofType":null},{"kin'
        'd":"OBJECT","name":"Author","ofType":null}]},{"kind":"ENUM","nam'
        'e":"Order","description":null,"fields":null,"inputFields":null,"'
        'interfaces":null,"enumValues":[{"name":"ASC","description":null,'
        '"isDeprecated":false,"deprecationReason":null},{"name":"DESC","d'
        'escription":"Newest first.","isDeprecated":false,"deprecationRea'
        'son":null},{"name":"RANDOM","description":null,"isDeprecated":tr'
        'ue,"deprecationReason":"Not stable."}],"possibleTypes":null},{"k'
        'ind":"INPUT_OBJECT","name":"BookInput","description":null,"field'
        's":null,"inputFields":[{"name":"title","description":null,"type"'
        ':{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name"'
        ':"String","ofType":null}},"defaultValue":null,"isDeprecated":fal'
        'se,"deprecationReason":null},{"name":"tags","description":null,"'
        'type":{"kind":"LIST","name":null,"ofType":{"kind":"SCALAR","name'
        '":"String","ofType":null}},"defaultValue":"[\\"a\\", \\"b\\"]","isDe'
        'precated":false,"deprecationReason":null},{"name":"rating","desc'
        'ription":null,"type":{"kind":"SCALAR","name":"Float","ofType":nu'
        'll},"defaultValue":"1.5","isDeprecated":false,"deprecationReason'
        '":null},{"name":"meta","description":null,"type":{"kind":"INPUT_'
        'OBJECT","name":"SearchFilter","ofType":null},"defaultValue":"{te'
        'xt: \\"q\\", limit: 2}","isDeprecated":false,"deprecationReason":n'
        'ull}],"interfaces":null,"enumValues":null,"possibleTypes":null},'
        '{"kind":"INPUT_OBJECT","name":"SearchFilter","description":null,'
        '"fields":null,"inputFields":[{"name":"text","description":null,"'
        'type":{"kind":"SCALAR","name":"String","ofType":null},"defaultVa'
        'lue":null,"isDeprecated":false,"deprecationReason":null},{"name"'
        ':"limit","description":null,"type":{"kind":"SCALAR","name":"Int"'
        ',"ofType":null},"defaultValue":"5","isDeprecated":true,"deprecat'
        'ionReason":"No longer supported"}],"interfaces":null,"enumValues'
        '":null,"possibleTypes":null}],"directives":[{"name":"skip","desc'
        'ription":"Directs the executor to skip this field or fragment wh'
        'en the `if` argument is true.","locations":["FIELD","FRAGMENT_SP'
        'READ","INLINE_FRAGMENT"],"args":[{"name":"if","description":"Ski'
        'pped when true.","type":{"kind":"NON_NULL","name":null,"ofType":'
        '{"kind":"SCALAR","name":"Boolean","ofType":null}},"defaultValue"'
        ':null,"isDeprecated":false,"deprecationReason":null}]},{"name":"'
        'include","description":"Directs the executor to include this fie'
        'ld or fragment only when the `if` argument is true.","locations"'
        ':["FIELD","FRAGMENT_SPREAD","INLINE_FRAGMENT"],"args":[{"name":"'
        'if","description":"Included when true.","type":{"kind":"NON_NULL'
        '","name":null,"ofType":{"kind":"SCALAR","name":"Boolean","ofType'
        '":null}},"defaultValue":null,"isDeprecated":false,"deprecationRe'
        'ason":null}]},{"name":"deprecated","description":"Marks an eleme'
        'nt of a GraphQL schema as no longer supported.","locations":["FI'
        'ELD_DEFINITION","ARGUMENT_DEFINITION","INPUT_FIELD_DEFINITION","'
        'ENUM_VALUE"],"args":[{"name":"reason","description":"Explains wh'
        "y this element was deprecated, usually also including a suggesti"
        "on for how to access supported similar data. Formatted using the"
        " Markdown syntax, as specified by [CommonMark](https://commonmar"
        'k.org/).","type":{"kind":"SCALAR","name":"String","ofType":null}'
        ',"defaultValue":"\\"No longer supported\\"","isDeprecated":false,"'
        'deprecationReason":null}]},{"name":"specifiedBy","description":"'
        'Exposes a URL that specifies the behavior of this scalar.","loca'
        'tions":["SCALAR"],"args":[{"name":"url","description":"The URL t'
        'hat specifies the behavior of this scalar.","type":{"kind":"NON_'
        'NULL","name":null,"ofType":{"kind":"SCALAR","name":"String","ofT'
        'ype":null}},"defaultValue":null,"isDeprecated":false,"deprecatio'
        'nReason":null}]},{"name":"tagged","description":"Marks a field w'
        'ith a name.","locations":["FIELD_DEFINITION","OBJECT"],"args":[{'
        '"name":"name","description":null,"type":{"kind":"NON_NULL","name'
        '":null,"ofType":{"kind":"SCALAR","name":"String","ofType":null}}'
        ',"defaultValue":null,"isDeprecated":false,"deprecationReason":nu'
        'll},{"name":"weight","description":"How strong","type":{"kind":"'
        'SCALAR","name":"Int","ofType":null},"defaultValue":"1","isDeprec'
        'ated":false,"deprecationReason":null}]},{"name":"oneOf","descrip'
        'tion":"Indicates exactly one field must be supplied and this fie'
        'ld must not be `null`.","locations":["INPUT_OBJECT"],"args":[]}]'
        '}},"success":true},"error":null}\n'
    )
    out["graph-graph.json.rc"] = "0\n"
    out["graph-graph.plain.err"] = ""
    out["graph-graph.plain.out"] = (
        "schema {\n  query: Query\n  mutation: Mutation\n  subscription:"
        ' Subscription\n}\n\n"""A date, as `YYYY-MM-DD`."""\nscalar'
        ' Date\n\n"""The root of every query."""\ntype Query {\n  """Find a'
        ' node by its ID."""\n  node(\n    """The ID of an object"""\n    id:'
        " ID!,\n  ): Node\n  books(first: Int = 10, after: String, order: Order"
        " = ASC): [Book!]!\n  search(text: String!, filter: SearchFilter):"
        ' [SearchResult]\n  legacy: String @deprecated(reason: "No longer'
        ' supported")\n  old(\n    arg: Int @deprecated(reason: "Use'
        ' `arg2`."),\n  ): Int @deprecated(reason: "Use `new`.")\n  long:'
        " String\n}\n\ntype Mutation {\n  addBook(input: BookInput!):"
        ' Book\n}\n\ntype Subscription {\n  bookAdded: Book\n}\n\n"""\nA'
        ' book.\n\nIt has a title and an author.\n"""\ntype Book implements'
        " Node {\n  id: ID!\n  title: String\n  author: Author\n  tags:"
        " [[String!]]\n}\n\ntype Author implements Node {\n  id: ID!\n  name:"
        ' String\n}\n\n"""An object with an ID."""\ninterface Node {\n  id:'
        " ID!\n}\n\nunion SearchResult = Book | Author\n\nenum Order {\n  ASC\n"
        '  """Newest first."""\n  DESC\n  RANDOM @deprecated(reason: "Not'
        ' stable.")\n}\n\ninput BookInput {\n  title: String!\n  tags: [String]'
        ' = ["a", "b"]\n  rating: Float = 1.5\n  meta: SearchFilter = {text:'
        ' "q", limit: 2}\n}\n\ninput SearchFilter {\n  text: String\n  limit:'
        ' Int = 5 @deprecated(reason: "No longer supported")\n}\n\n"""Marks a'
        ' field with a name."""\ndirective @tagged(\n  name: String!,\n  """How'
        ' strong"""\n  weight: Int = 1,\n) on FIELD_DEFINITION |'
        ' OBJECT\n\n"""Exposes a URL that specifies the behavior of this'
        ' scalar."""\ndirective @specifiedBy(\n  """The URL that specifies the'
        ' behavior of this scalar."""\n  url: String!,\n) on'
        ' SCALAR\n\n"""\nIndicates exactly one field must be supplied and this'
        ' field must not be `null`.\n"""\ndirective @oneOf on INPUT_OBJECT\n\n'
    )
    out["graph-graph.plain.rc"] = "0\n"
    out["graph-invalid.json.err"] = ""
    out["graph-invalid.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a syntax error at line 1, column 2"],"code":nul'
        "l}}\n"
    )
    out["graph-invalid.json.rc"] = "1\n"
    out["graph-invalid.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a syntax error at line 1, column 2\n"
    )
    out["graph-invalid.plain.out"] = ""
    out["graph-invalid.plain.rc"] = "1\n"
    out["graph-no-data.json.err"] = ""
    out["graph-no-data.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["graph-no-data.json.rc"] = "1\n"
    out[
        "graph-no-data.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["graph-no-data.plain.out"] = ""
    out["graph-no-data.plain.rc"] = "1\n"
    out["graph-no-service.json.err"] = ""
    out["graph-no-service.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["graph-no-service.json.rc"] = "1\n"
    out[
        "graph-no-service.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["graph-no-service.plain.out"] = ""
    out["graph-no-service.plain.rc"] = "1\n"
    out["graph-null.json.err"] = ""
    out["graph-null.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Schema not found in Introspection Result.","code":"E011"}}\n'
    )
    out["graph-null.json.rc"] = "1\n"
    out[
        "graph-null.plain.err"
    ] = "error[E011]: Schema not found in Introspection Result.\n"
    out["graph-null.plain.out"] = ""
    out["graph-null.plain.rc"] = "1\n"
    out["graph-partial.json.err"] = ""
    out["graph-partial.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Data was returned, but with errors: b'
        'oom bang"],"code":null}}\n'
    )
    out["graph-partial.json.rc"] = "1\n"
    out["graph-partial.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Data was returned, but with"
        " errors: boom bang\n"
    )
    out["graph-partial.plain.out"] = ""
    out["graph-partial.plain.rc"] = "1\n"
    out["graph-small.json.err"] = ""
    out["graph-small.json.out"] = (
        '{"json_version":"1","data":{"introspection_response":{"__schema"'
        ':{"queryType":{"name":"Query"},"mutationType":null,"subscription'
        'Type":null,"types":[{"kind":"OBJECT","name":"__Schema","descript'
        'ion":"A GraphQL Schema defines the capabilities of a GraphQL ser'
        "ver. It exposes all available types and directives on the server"
        ", as well as the entry points for query, mutation, and subscript"
        'ion operations.","fields":[{"name":"description","description":n'
        'ull,"args":[],"type":{"kind":"SCALAR","name":"String","ofType":n'
        'ull},"isDeprecated":false,"deprecationReason":null},{"name":"typ'
        'es","description":"A list of all types supported by this server.'
        '","args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kin'
        'd":"LIST","name":null,"ofType":{"kind":"NON_NULL","name":null,"o'
        'fType":{"kind":"OBJECT","name":"__Type","ofType":null}}}},"isDep'
        'recated":false,"deprecationReason":null},{"name":"queryType","de'
        'scription":"The type that query operations will be rooted at.","'
        'args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":'
        '"OBJECT","name":"__Type","ofType":null}},"isDeprecated":false,"d'
        'eprecationReason":null},{"name":"mutationType","description":"If'
        " this server supports mutation, the type that mutation operation"
        's will be rooted at.","args":[],"type":{"kind":"OBJECT","name":"'
        '__Type","ofType":null},"isDeprecated":false,"deprecationReason":'
        'null},{"name":"subscriptionType","description":"If this server s'
        "upport subscription, the type that subscription operations will "
        'be rooted at.","args":[],"type":{"kind":"OBJECT","name":"__Type"'
        ',"ofType":null},"isDeprecated":false,"deprecationReason":null},{'
        '"name":"directives","description":"A list of all directives supp'
        'orted by this server.","args":[],"type":{"kind":"NON_NULL","name'
        '":null,"ofType":{"kind":"LIST","name":null,"ofType":{"kind":"NON'
        '_NULL","name":null,"ofType":{"kind":"OBJECT","name":"__Directive'
        '","ofType":null}}}},"isDeprecated":false,"deprecationReason":nul'
        'l}],"inputFields":null,"interfaces":[],"enumValues":null,"possib'
        'leTypes":null},{"kind":"OBJECT","name":"__Type","description":"T'
        "he fundamental unit of any GraphQL Schema is the type. There are"
        " many kinds of types in GraphQL as represented by the `__TypeKin"
        "d` enum.\\n\\nDepending on the kind of a type, certain fields desc"
        "ribe information about that type. Scalar types provide no inform"
        "ation beyond a name, description and optional `specifiedByURL`, "
        "while Enum types provide their values. Object and Interface type"
        "s provide the fields they describe. Abstract types, Union and In"
        "terface, provide the Object types possible at runtime. List and "
        'NonNull types compose other types.","fields":[{"name":"kind","de'
        'scription":null,"args":[],"type":{"kind":"NON_NULL","name":null,'
        '"ofType":{"kind":"ENUM","name":"__TypeKind","ofType":null}},"isD'
        'eprecated":false,"deprecationReason":null},{"name":"name","descr'
        'iption":null,"args":[],"type":{"kind":"SCALAR","name":"String","'
        'ofType":null},"isDeprecated":false,"deprecationReason":null},{"n'
        'ame":"description","description":null,"args":[],"type":{"kind":"'
        'SCALAR","name":"String","ofType":null},"isDeprecated":false,"dep'
        'recationReason":null},{"name":"fields","description":null,"args"'
        ':[{"name":"includeDeprecated","description":null,"type":{"kind":'
        '"SCALAR","name":"Boolean","ofType":null},"defaultValue":"false",'
        '"isDeprecated":false,"deprecationReason":null}],"type":{"kind":"'
        'LIST","name":null,"ofType":{"kind":"NON_NULL","name":null,"ofTyp'
        'e":{"kind":"OBJECT","name":"__Field","ofType":null}}},"isDepreca'
        'ted":false,"deprecationReason":null},{"name":"interfaces","descr'
        'iption":null,"args":[],"type":{"kind":"LIST","name":null,"ofType'
        '":{"kind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","name'
        '":"__Type","ofType":null}}},"isDeprecated":false,"deprecationRea'
        'son":null},{"name":"possibleTypes","description":null,"args":[],'
        '"type":{"kind":"LIST","name":null,"ofType":{"kind":"NON_NULL","n'
        'ame":null,"ofType":{"kind":"OBJECT","name":"__Type","ofType":nul'
        'l}}},"isDeprecated":false,"deprecationReason":null},{"name":"enu'
        'mValues","description":null,"args":[{"name":"includeDeprecated",'
        '"description":null,"type":{"kind":"SCALAR","name":"Boolean","ofT'
        'ype":null},"defaultValue":"false","isDeprecated":false,"deprecat'
        'ionReason":null}],"type":{"kind":"LIST","name":null,"ofType":{"k'
        'ind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","name":"__'
        'EnumValue","ofType":null}}},"isDeprecated":false,"deprecationRea'
        'son":null},{"name":"inputFields","description":null,"args":[{"na'
        'me":"includeDeprecated","description":null,"type":{"kind":"SCALA'
        'R","name":"Boolean","ofType":null},"defaultValue":"false","isDep'
        'recated":false,"deprecationReason":null}],"type":{"kind":"LIST",'
        '"name":null,"ofType":{"kind":"NON_NULL","name":null,"ofType":{"k'
        'ind":"OBJECT","name":"__InputValue","ofType":null}}},"isDeprecat'
        'ed":false,"deprecationReason":null},{"name":"ofType","descriptio'
        'n":null,"args":[],"type":{"kind":"OBJECT","name":"__Type","ofTyp'
        'e":null},"isDeprecated":false,"deprecationReason":null},{"name":'
        '"specifiedByURL","description":null,"args":[],"type":{"kind":"SC'
        'ALAR","name":"String","ofType":null},"isDeprecated":false,"depre'
        'cationReason":null}],"inputFields":null,"interfaces":[],"enumVal'
        'ues":null,"possibleTypes":null},{"kind":"ENUM","name":"__TypeKin'
        'd","description":"An enum describing what kind of type a given `'
        '__Type` is.","fields":null,"inputFields":null,"interfaces":null,'
        '"enumValues":[{"name":"SCALAR","description":"Indicates this typ'
        'e is a scalar.","isDeprecated":false,"deprecationReason":null},{'
        '"name":"OBJECT","description":"Indicates this type is an object.'
        ' `fields` and `interfaces` are valid fields.","isDeprecated":fal'
        'se,"deprecationReason":null},{"name":"INTERFACE","description":"'
        "Indicates this type is an interface. `fields`, `interfaces`, and"
        ' `possibleTypes` are valid fields.","isDeprecated":false,"deprec'
        'ationReason":null},{"name":"UNION","description":"Indicates this'
        ' type is a union. `possibleTypes` is a valid field.","isDeprecat'
        'ed":false,"deprecationReason":null},{"name":"ENUM","description"'
        ':"Indicates this type is an enum. `enumValues` is a valid field.'
        '","isDeprecated":false,"deprecationReason":null},{"name":"INPUT_'
        'OBJECT","description":"Indicates this type is an input object. `'
        'inputFields` is a valid field.","isDeprecated":false,"deprecatio'
        'nReason":null},{"name":"LIST","description":"Indicates this type'
        ' is a list. `ofType` is a valid field.","isDeprecated":false,"de'
        'precationReason":null},{"name":"NON_NULL","description":"Indicat'
        'es this type is a non-null. `ofType` is a valid field.","isDepre'
        'cated":false,"deprecationReason":null}],"possibleTypes":null},{"'
        'kind":"OBJECT","name":"__Field","description":"Object and Interf'
        "ace types are described by a list of Fields, each of which has a"
        ' name, potentially a list of arguments, and a return type.","fie'
        'lds":[{"name":"name","description":null,"args":[],"type":{"kind"'
        ':"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"String'
        '","ofType":null}},"isDeprecated":false,"deprecationReason":null}'
        ',{"name":"description","description":null,"args":[],"type":{"kin'
        'd":"SCALAR","name":"String","ofType":null},"isDeprecated":false,'
        '"deprecationReason":null},{"name":"args","description":null,"arg'
        's":[{"name":"includeDeprecated","description":null,"type":{"kind'
        '":"SCALAR","name":"Boolean","ofType":null},"defaultValue":"false'
        '","isDeprecated":false,"deprecationReason":null}],"type":{"kind"'
        ':"NON_NULL","name":null,"ofType":{"kind":"LIST","name":null,"ofT'
        'ype":{"kind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT","n'
        'ame":"__InputValue","ofType":null}}}},"isDeprecated":false,"depr'
        'ecationReason":null},{"name":"type","description":null,"args":[]'
        ',"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"OBJECT"'
        ',"name":"__Type","ofType":null}},"isDeprecated":false,"deprecati'
        'onReason":null},{"name":"isDeprecated","description":null,"args"'
        ':[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCAL'
        'AR","name":"Boolean","ofType":null}},"isDeprecated":false,"depre'
        'cationReason":null},{"name":"deprecationReason","description":nu'
        'll,"args":[],"type":{"kind":"SCALAR","name":"String","ofType":nu'
        'll},"isDeprecated":false,"deprecationReason":null}],"inputFields'
        '":null,"interfaces":[],"enumValues":null,"possibleTypes":null},{'
        '"kind":"OBJECT","name":"__InputValue","description":"Arguments p'
        "rovided to Fields or Directives and the input fields of an Input"
        "Object are represented as Input Values which describe their type"
        ' and optionally a default value.","fields":[{"name":"name","desc'
        'ription":null,"args":[],"type":{"kind":"NON_NULL","name":null,"o'
        'fType":{"kind":"SCALAR","name":"String","ofType":null}},"isDepre'
        'cated":false,"deprecationReason":null},{"name":"description","de'
        'scription":null,"args":[],"type":{"kind":"SCALAR","name":"String'
        '","ofType":null},"isDeprecated":false,"deprecationReason":null},'
        '{"name":"type","description":null,"args":[],"type":{"kind":"NON_'
        'NULL","name":null,"ofType":{"kind":"OBJECT","name":"__Type","ofT'
        'ype":null}},"isDeprecated":false,"deprecationReason":null},{"nam'
        'e":"defaultValue","description":"A GraphQL-formatted string repr'
        'esenting the default value for this input value.","args":[],"typ'
        'e":{"kind":"SCALAR","name":"String","ofType":null},"isDeprecated'
        '":false,"deprecationReason":null},{"name":"isDeprecated","descri'
        'ption":null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofT'
        'ype":{"kind":"SCALAR","name":"Boolean","ofType":null}},"isDeprec'
        'ated":false,"deprecationReason":null},{"name":"deprecationReason'
        '","description":null,"args":[],"type":{"kind":"SCALAR","name":"S'
        'tring","ofType":null},"isDeprecated":false,"deprecationReason":n'
        'ull}],"inputFields":null,"interfaces":[],"enumValues":null,"poss'
        'ibleTypes":null},{"kind":"OBJECT","name":"__EnumValue","descript'
        'ion":"One possible value for a given Enum. Enum values are uniqu'
        "e values, not a placeholder for a string or numeric value. Howev"
        'er an Enum value is returned in a JSON response as a string.","f'
        'ields":[{"name":"name","description":null,"args":[],"type":{"kin'
        'd":"NON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"Stri'
        'ng","ofType":null}},"isDeprecated":false,"deprecationReason":nul'
        'l},{"name":"description","description":null,"args":[],"type":{"k'
        'ind":"SCALAR","name":"String","ofType":null},"isDeprecated":fals'
        'e,"deprecationReason":null},{"name":"isDeprecated","description"'
        ':null,"args":[],"type":{"kind":"NON_NULL","name":null,"ofType":{'
        '"kind":"SCALAR","name":"Boolean","ofType":null}},"isDeprecated":'
        'false,"deprecationReason":null},{"name":"deprecationReason","des'
        'cription":null,"args":[],"type":{"kind":"SCALAR","name":"String"'
        ',"ofType":null},"isDeprecated":false,"deprecationReason":null}],'
        '"inputFields":null,"interfaces":[],"enumValues":null,"possibleTy'
        'pes":null},{"kind":"OBJECT","name":"__Directive","description":"'
        "A Directive provides a way to describe alternate runtime executi"
        "on and type validation behavior in a GraphQL document.\\n\\nIn som"
        "e cases, you need to provide options to alter GraphQL's executio"
        "n behavior in ways field arguments will not suffice, such as con"
        "ditionally including or skipping a field. Directives provide thi"
        's by describing additional information to the executor.","fields'
        '":[{"name":"name","description":null,"args":[],"type":{"kind":"N'
        'ON_NULL","name":null,"ofType":{"kind":"SCALAR","name":"String","'
        'ofType":null}},"isDeprecated":false,"deprecationReason":null},{"'
        'name":"description","description":null,"args":[],"type":{"kind":'
        '"SCALAR","name":"String","ofType":null},"isDeprecated":false,"de'
        'precationReason":null},{"name":"locations","description":null,"a'
        'rgs":[],"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"'
        'LIST","name":null,"ofType":{"kind":"NON_NULL","name":null,"ofTyp'
        'e":{"kind":"ENUM","name":"__DirectiveLocation","ofType":null}}}}'
        ',"isDeprecated":false,"deprecationReason":null},{"name":"args","'
        'description":null,"args":[{"name":"includeDeprecated","descripti'
        'on":null,"type":{"kind":"SCALAR","name":"Boolean","ofType":null}'
        ',"defaultValue":"false","isDeprecated":false,"deprecationReason"'
        ':null}],"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"'
        'LIST","name":null,"ofType":{"kind":"NON_NULL","name":null,"ofTyp'
        'e":{"kind":"OBJECT","name":"__InputValue","ofType":null}}}},"isD'
        'eprecated":false,"deprecationReason":null},{"name":"isRepeatable'
        '","description":null,"args":[],"type":{"kind":"NON_NULL","name":'
        'null,"ofType":{"kind":"SCALAR","name":"Boolean","ofType":null}},'
        '"isDeprecated":false,"deprecationReason":null}],"inputFields":nu'
        'll,"interfaces":[],"enumValues":null,"possibleTypes":null},{"kin'
        'd":"ENUM","name":"__DirectiveLocation","description":"A Directiv'
        "e can be adjacent to many parts of the GraphQL language, a __Dir"
        'ectiveLocation describes one such possible adjacencies.","fields'
        '":null,"inputFields":null,"interfaces":null,"enumValues":[{"name'
        '":"QUERY","description":"Location adjacent to a query operation.'
        '","isDeprecated":false,"deprecationReason":null},{"name":"MUTATI'
        'ON","description":"Location adjacent to a mutation operation.","'
        'isDeprecated":false,"deprecationReason":null},{"name":"SUBSCRIPT'
        'ION","description":"Location adjacent to a subscription operatio'
        'n.","isDeprecated":false,"deprecationReason":null},{"name":"FIEL'
        'D","description":"Location adjacent to a field.","isDeprecated":'
        'false,"deprecationReason":null},{"name":"FRAGMENT_DEFINITION","d'
        'escription":"Location adjacent to a fragment definition.","isDep'
        'recated":false,"deprecationReason":null},{"name":"FRAGMENT_SPREA'
        'D","description":"Location adjacent to a fragment spread.","isDe'
        'precated":false,"deprecationReason":null},{"name":"INLINE_FRAGME'
        'NT","description":"Location adjacent to an inline fragment.","is'
        'Deprecated":false,"deprecationReason":null},{"name":"VARIABLE_DE'
        'FINITION","description":"Location adjacent to a variable definit'
        'ion.","isDeprecated":false,"deprecationReason":null},{"name":"SC'
        'HEMA","description":"Location adjacent to a schema definition.",'
        '"isDeprecated":false,"deprecationReason":null},{"name":"SCALAR",'
        '"description":"Location adjacent to a scalar definition.","isDep'
        'recated":false,"deprecationReason":null},{"name":"OBJECT","descr'
        'iption":"Location adjacent to an object type definition.","isDep'
        'recated":false,"deprecationReason":null},{"name":"FIELD_DEFINITI'
        'ON","description":"Location adjacent to a field definition.","is'
        'Deprecated":false,"deprecationReason":null},{"name":"ARGUMENT_DE'
        'FINITION","description":"Location adjacent to an argument defini'
        'tion.","isDeprecated":false,"deprecationReason":null},{"name":"I'
        'NTERFACE","description":"Location adjacent to an interface defin'
        'ition.","isDeprecated":false,"deprecationReason":null},{"name":"'
        'UNION","description":"Location adjacent to a union definition.",'
        '"isDeprecated":false,"deprecationReason":null},{"name":"ENUM","d'
        'escription":"Location adjacent to an enum definition.","isDeprec'
        'ated":false,"deprecationReason":null},{"name":"ENUM_VALUE","desc'
        'ription":"Location adjacent to an enum value definition.","isDep'
        'recated":false,"deprecationReason":null},{"name":"INPUT_OBJECT",'
        '"description":"Location adjacent to an input object type definit'
        'ion.","isDeprecated":false,"deprecationReason":null},{"name":"IN'
        'PUT_FIELD_DEFINITION","description":"Location adjacent to an inp'
        'ut object field definition.","isDeprecated":false,"deprecationRe'
        'ason":null}],"possibleTypes":null},{"kind":"SCALAR","name":"Int"'
        ',"description":"The `Int` scalar type represents non-fractional '
        "signed whole numeric values. Int can represent values between -("
        '2^31) and 2^31 - 1.","fields":null,"inputFields":null,"interface'
        's":null,"enumValues":null,"possibleTypes":null},{"kind":"SCALAR"'
        ',"name":"String","description":"The `String` scalar type represe'
        "nts textual data, represented as UTF-8 character sequences. The "
        "String type is most often used by GraphQL to represent free-form"
        ' human-readable text.","fields":null,"inputFields":null,"interfa'
        'ces":null,"enumValues":null,"possibleTypes":null},{"kind":"SCALA'
        'R","name":"Boolean","description":"The `Boolean` scalar type rep'
        'resents `true` or `false`.","fields":null,"inputFields":null,"in'
        'terfaces":null,"enumValues":null,"possibleTypes":null},{"kind":"'
        'OBJECT","name":"Query","description":null,"fields":[{"name":"a",'
        '"description":null,"args":[],"type":{"kind":"SCALAR","name":"Int'
        '","ofType":null},"isDeprecated":false,"deprecationReason":null}]'
        ',"inputFields":null,"interfaces":[],"enumValues":null,"possibleT'
        'ypes":null}],"directives":[{"name":"skip","description":"Directs'
        " the executor to skip this field or fragment when the `if` argum"
        'ent is true.","locations":["FIELD","FRAGMENT_SPREAD","INLINE_FRA'
        'GMENT"],"args":[{"name":"if","description":"Skipped when true.",'
        '"type":{"kind":"NON_NULL","name":null,"ofType":{"kind":"SCALAR",'
        '"name":"Boolean","ofType":null}},"defaultValue":null,"isDeprecat'
        'ed":false,"deprecationReason":null}]},{"name":"include","descrip'
        'tion":"Directs the executor to include this field or fragment on'
        'ly when the `if` argument is true.","locations":["FIELD","FRAGME'
        'NT_SPREAD","INLINE_FRAGMENT"],"args":[{"name":"if","description"'
        ':"Included when true.","type":{"kind":"NON_NULL","name":null,"of'
        'Type":{"kind":"SCALAR","name":"Boolean","ofType":null}},"default'
        'Value":null,"isDeprecated":false,"deprecationReason":null}]},{"n'
        'ame":"deprecated","description":"Marks an element of a GraphQL s'
        'chema as no longer supported.","locations":["FIELD_DEFINITION","'
        'ARGUMENT_DEFINITION","INPUT_FIELD_DEFINITION","ENUM_VALUE"],"arg'
        's":[{"name":"reason","description":"Explains why this element wa'
        "s deprecated, usually also including a suggestion for how to acc"
        "ess supported similar data. Formatted using the Markdown syntax,"
        ' as specified by [CommonMark](https://commonmark.org/).","type":'
        '{"kind":"SCALAR","name":"String","ofType":null},"defaultValue":"'
        '\\"No longer supported\\"","isDeprecated":false,"deprecationReason'
        '":null}]},{"name":"specifiedBy","description":"Exposes a URL tha'
        't specifies the behavior of this scalar.","locations":["SCALAR"]'
        ',"args":[{"name":"url","description":"The URL that specifies the'
        ' behavior of this scalar.","type":{"kind":"NON_NULL","name":null'
        ',"ofType":{"kind":"SCALAR","name":"String","ofType":null}},"defa'
        'ultValue":null,"isDeprecated":false,"deprecationReason":null}]}]'
        '}},"success":true},"error":null}\n'
    )
    out["graph-small.json.rc"] = "0\n"
    out["graph-small.plain.err"] = ""
    out["graph-small.plain.out"] = "type Query {\n  a: Int\n}\n\n"
    out["graph-small.plain.rc"] = "0\n"
    out["graph-status.json.err"] = ""
    out["graph-status.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        "HTTP 422 Unprocessable Entity) had a syntax error at line 1, col"
        'umn 2"],"code":null}}\n'
    )
    out["graph-status.json.rc"] = "1\n"
    out["graph-status.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 422 Unprocessable Entity) had a syntax error at l"
        "ine 1, column 2\n"
    )
    out["graph-status.plain.out"] = ""
    out["graph-status.plain.rc"] = "1\n"
    out["graph-too-large.json.err"] = ""
    out["graph-too-large.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        "HTTP 413 Payload Too Large) had a syntax error at line 1, column"
        ' 2"],"code":null}}\n'
    )
    out["graph-too-large.json.rc"] = "1\n"
    out["graph-too-large.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 413 Payload Too Large) had a syntax error at line"
        " 1, column 2\n"
    )
    out["graph-too-large.plain.out"] = ""
    out["graph-too-large.plain.rc"] = "1\n"
    out["graph-unknown-type.json.err"] = ""
    out["graph-unknown-type.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 165"],"code":nul'
        "l}}\n"
    )
    out["graph-unknown-type.json.rc"] = "1\n"
    out["graph-unknown-type.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 165\n"
    )
    out["graph-unknown-type.plain.out"] = ""
    out["graph-unknown-type.plain.rc"] = "1\n"
    out["subgraph-array.json.err"] = ""
    out["subgraph-array.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 2"],"code":null}'
        "}\n"
    )
    out["subgraph-array.json.rc"] = "1\n"
    out["subgraph-array.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 2\n"
    )
    out["subgraph-array.plain.out"] = ""
    out["subgraph-array.plain.rc"] = "1\n"
    out["subgraph-empty-data.json.err"] = ""
    out["subgraph-empty-data.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"No introspection response available.","code":"E011"}}\n'
    )
    out["subgraph-empty-data.json.rc"] = "1\n"
    out[
        "subgraph-empty-data.plain.err"
    ] = "error[E011]: No introspection response available.\n"
    out["subgraph-empty-data.plain.out"] = ""
    out["subgraph-empty-data.plain.rc"] = "1\n"
    out["subgraph-errors-empty.json.err"] = ""
    out["subgraph-errors-empty.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["subgraph-errors-empty.json.rc"] = "1\n"
    out[
        "subgraph-errors-empty.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["subgraph-errors-empty.plain.out"] = ""
    out["subgraph-errors-empty.plain.rc"] = "1\n"
    out["subgraph-errors-null.json.err"] = ""
    out["subgraph-errors-null.json.out"] = (
        '{"json_version":"1","data":{"introspection_response":"type Query'
        ' {\\n  a: Int\\n}\\n","success":true},"error":null}\n'
    )
    out["subgraph-errors-null.json.rc"] = "0\n"
    out["subgraph-errors-null.plain.err"] = ""
    out["subgraph-errors-null.plain.out"] = "type Query {\n  a: Int\n}\n\n"
    out["subgraph-errors-null.plain.rc"] = "0\n"
    out["subgraph-headers.json.err"] = ""
    out["subgraph-headers.json.out"] = (
        '{"json_version":"1","data":{"introspection_response":"\\"\\"\\"x-token=abc'
        ' x-two=b c\\"\\"\\"\\ntype Query {\\n  a:'
        ' Int\\n}\\n","success":true},"error":null}\n'
    )
    out["subgraph-headers.json.rc"] = "0\n"
    out["subgraph-headers.plain.err"] = ""
    out[
        "subgraph-headers.plain.out"
    ] = '"""x-token=abc x-two=b c"""\ntype Query {\n  a: Int\n}\n\n'
    out["subgraph-headers.plain.rc"] = "0\n"
    out["subgraph-invalid-credentials.json.err"] = ""
    out["subgraph-invalid-credentials.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Invalid credentials provided. See \\"A'
        'uthenticating with GraphOS\\" [https://www.apollographql.com/docs'
        '/rover/configuring]."],"code":null}}\n'
    )
    out["subgraph-invalid-credentials.json.rc"] = "1\n"
    out["subgraph-invalid-credentials.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Invalid credentials provide"
        'd. See "Authenticating with GraphOS" [https://www.apollographql.'
        "com/docs/rover/configuring].\n"
    )
    out["subgraph-invalid-credentials.plain.out"] = ""
    out["subgraph-invalid-credentials.plain.rc"] = "1\n"
    out["subgraph-invalid.json.err"] = ""
    out["subgraph-invalid.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a syntax error at line 1, column 2"],"code":nul'
        "l}}\n"
    )
    out["subgraph-invalid.json.rc"] = "1\n"
    out["subgraph-invalid.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a syntax error at line 1, column 2\n"
    )
    out["subgraph-invalid.plain.out"] = ""
    out["subgraph-invalid.plain.rc"] = "1\n"
    out["subgraph-no-data.json.err"] = ""
    out["subgraph-no-data.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["subgraph-no-data.json.rc"] = "1\n"
    out[
        "subgraph-no-data.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["subgraph-no-data.plain.out"] = ""
    out["subgraph-no-data.plain.rc"] = "1\n"
    out["subgraph-no-service-partial.json.err"] = ""
    out["subgraph-no-service-partial.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        "\"This endpoint doesn't support subgraph introspection via the Qu"
        'ery._service field","code":"E007"}}\n'
    )
    out["subgraph-no-service-partial.json.rc"] = "1\n"
    out["subgraph-no-service-partial.plain.err"] = (
        "error[E007]: This endpoint doesn't support subgraph introspectio"
        "n via the Query._service field\n        Try running the command o"
        "n a valid federated graph, or use the appropriate `seamstress graph` "
        "command instead of `seamstress subgraph`.\n"
    )
    out["subgraph-no-service-partial.plain.out"] = ""
    out["subgraph-no-service-partial.plain.rc"] = "1\n"
    out["subgraph-no-service.json.err"] = ""
    out["subgraph-no-service.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["No data field provided"],"code":null}'
        "}\n"
    )
    out["subgraph-no-service.json.rc"] = "1\n"
    out[
        "subgraph-no-service.plain.err"
    ] = "error: Service error\n\nCaused by:\n    No data field provided\n"
    out["subgraph-no-service.plain.out"] = ""
    out["subgraph-no-service.plain.rc"] = "1\n"
    out["subgraph-null.json.err"] = ""
    out["subgraph-null.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"No introspection response available.","code":"E011"}}\n'
    )
    out["subgraph-null.json.rc"] = "1\n"
    out[
        "subgraph-null.plain.err"
    ] = "error[E011]: No introspection response available.\n"
    out["subgraph-null.plain.out"] = ""
    out["subgraph-null.plain.rc"] = "1\n"
    out["subgraph-partial.json.err"] = ""
    out["subgraph-partial.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Data was returned, but with errors: b'
        'oom bang"],"code":null}}\n'
    )
    out["subgraph-partial.json.rc"] = "1\n"
    out["subgraph-partial.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Data was returned, but with"
        " errors: boom bang\n"
    )
    out["subgraph-partial.plain.out"] = ""
    out["subgraph-partial.plain.rc"] = "1\n"
    out["subgraph-sdl-number.json.err"] = ""
    out["subgraph-sdl-number.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 28"],"code":null'
        "}}\n"
    )
    out["subgraph-sdl-number.json.rc"] = "1\n"
    out["subgraph-sdl-number.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 28\n"
    )
    out["subgraph-sdl-number.plain.out"] = ""
    out["subgraph-sdl-number.plain.rc"] = "1\n"
    out["subgraph-service-no-sdl.json.err"] = ""
    out["subgraph-service-no-sdl.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        'HTTP 200 OK) had a data error at line 1, column 22"],"code":null'
        "}}\n"
    )
    out["subgraph-service-no-sdl.json.rc"] = "1\n"
    out["subgraph-service-no-sdl.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 200 OK) had a data error at line 1, column 22\n"
    )
    out["subgraph-service-no-sdl.plain.out"] = ""
    out["subgraph-service-no-sdl.plain.rc"] = "1\n"
    out["subgraph-status.json.err"] = ""
    out["subgraph-status.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        "HTTP 422 Unprocessable Entity) had a syntax error at line 1, col"
        'umn 2"],"code":null}}\n'
    )
    out["subgraph-status.json.rc"] = "1\n"
    out["subgraph-status.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 422 Unprocessable Entity) had a syntax error at l"
        "ine 1, column 2\n"
    )
    out["subgraph-status.plain.out"] = ""
    out["subgraph-status.plain.rc"] = "1\n"
    out["subgraph-subgraph_products.json.err"] = ""
    out["subgraph-subgraph_products.json.out"] = (
        '{"json_version":"1","data":{"introspection_response":"extend schema'
        ' @link(url: \\"https://specs.apollo.dev/federation/v2.3\\", import:'
        ' [\\"@key\\"])\\n\\ntype Query {\\n  products: [Product]\\n}\\n\\ntype'
        ' Product @key(fields: \\"id\\") {\\n  id: ID!\\n  name:'
        ' String\\n}\\n","success":true},"error":null}\n'
    )
    out["subgraph-subgraph_products.json.rc"] = "0\n"
    out["subgraph-subgraph_products.plain.err"] = ""
    out["subgraph-subgraph_products.plain.out"] = (
        'extend schema @link(url: "https://specs.apollo.dev/federation/v2'
        '.3", import: ["@key"])\n\ntype Query {\n  products: [Product]\n}\n\nty'
        'pe Product @key(fields: "id") {\n  id: ID!\n  name: String\n}\n\n'
    )
    out["subgraph-subgraph_products.plain.rc"] = "0\n"
    out["subgraph-too-large.json.err"] = ""
    out["subgraph-too-large.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Deserialization error: the response ('
        "HTTP 413 Payload Too Large) had a syntax error at line 1, column"
        ' 2"],"code":null}}\n'
    )
    out["subgraph-too-large.json.rc"] = "1\n"
    out["subgraph-too-large.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Deserialization error: the "
        "response (HTTP 413 Payload Too Large) had a syntax error at line"
        " 1, column 2\n"
    )
    out["subgraph-too-large.plain.out"] = ""
    out["subgraph-too-large.plain.rc"] = "1\n"
    out["subgraph-unauthorized.json.err"] = ""
    out["subgraph-unauthorized.json.out"] = (
        '{"json_version":"1","data":{"success":false},"error":{"message":'
        '"Service error","causes":["Invalid credentials provided. See \\"A'
        'uthenticating with GraphOS\\" [https://www.apollographql.com/docs'
        '/rover/configuring]."],"code":null}}\n'
    )
    out["subgraph-unauthorized.json.rc"] = "1\n"
    out["subgraph-unauthorized.plain.err"] = (
        "error: Service error\n\nCaused by:\n    Invalid credentials provide"
        'd. See "Authenticating with GraphOS" [https://www.apollographql.'
        "com/docs/rover/configuring].\n"
    )
    out["subgraph-unauthorized.plain.out"] = ""
    out["subgraph-unauthorized.plain.rc"] = "1\n"
    return out^
