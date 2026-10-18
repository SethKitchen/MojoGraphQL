# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The cases of `test_output_schema.mojo`: SDL, `----`, an operation, and
`====` between cases; and the expected output schema of each case, one per
line. The text is in a module, so that the suite reads no file.
"""

comptime OUTPUT_CASES = """type Query {
    "Get a user by ID"
    user(id: ID!): User
}

"A user in the system"
type User {
    "The user's unique identifier"
    id: ID!
    "The user's display name"
    name: String!
    "The user's email address"
    email: String
}
----
query GetUser($id: ID!) {
    user(id: $id) {
        id
        name
        email
    }
}
====
type Query {
    user(id: ID!): User
}

type User {
    id: ID!
    profile: Profile!
}

type Profile {
    bio: String
    avatar: String!
}
----
query GetUser($id: ID!) {
    user(id: $id) {
        id
        profile {
            bio
            avatar
        }
    }
}
====
scalar JSON

type Thing {
    id: ID!
    meta: JSON
    tags: [JSON]
}

type Query {
    thing: Thing
}
----
query GetThing {
    thing {
        id
        meta
        tags
    }
}
====
type Book {
    id: ID!
    name: String
}

type Author {
    id: ID!
    name: String
}

union SearchResult = Book | Author

type Query {
    search: SearchResult!
}
----
query Search {
    search {
        ... on Book { id name }
        ... on Author { id name }
    }
}
====
interface Node { id: ID! }
"A pet"
interface Pet implements Node { id: ID! name: String }
interface Furry { fur: String }
type Dog implements Node & Pet & Furry { id: ID! name: String fur: String barks: Boolean! mood: Mood }
type Cat implements Node & Pet & Furry { id: ID! name: String fur: String lives: Int owner: Person }
type Bird implements Node & Pet { id: ID! name: String lives: Int }
"Moods"
enum Mood { HAPPY SAD }
enum Plain { A B }
type Person { name: String tags: [[String!]]! plain: Plain }
interface Lonely { x: Int }
union Animal = Dog | Cat | Bird
type Query { pets: [Pet!]! node(id: ID!): Node lonely: Lonely person: Person animals: [Animal] }
----
query Q {
  pets { __typename id kind: name ... on Dog { barks mood } ... on Cat { lives owner { name } } ... on Bird { lives } ...PetBits ...PetBits ... on Nope { x } ...Missing ... { id } }
  node(id: 1) { id ... on Pet { name } ...DogOnly }
  lonely { x ... on Dog { name } }
  person { name tags plain missingField }
  again: person { name }
  again: person { tags }
  person { name }
  animals { ... on Furry { fur } ... on Dog { barks } ...Ghost }
  more: animals { ... on Pet { name } ... on Dog { mood } ... on Cat { mood: lives } }
  bare: person
}
fragment PetBits on Pet { name }
fragment DogOnly on Dog { barks }
fragment Ghost on Nope2 { a }
====
"Mapped desc"
scalar Mapped
scalar Yes
"Yes with desc"
scalar YesDesc
scalar Bare
type Query { a: Int }
type Mutation { m: Mapped y: Yes yd: YesDesc b: Bare f: Float! ids: [ID] list: [[Int!]!] }
----
mutation M { m y yd b f ids list __typename }
====
interface Pet { id: ID! }
type Dog implements Pet { id: ID! barks: Boolean }
type Cat implements Pet { id: ID! }
union Animal = Dog | Cat
type Query { pet: Pet animal: Animal }
----
query Q { pet { id ... on Dog { id } } animal { name ... on Dog { barks } } }
"""
"""The cases."""

comptime OUTPUT_EXPECTED = """{"type":"object","properties":{"data":{"type":"object","properties":{"user":{"description":"Get a user by ID","anyOf":[{"type":"object","properties":{"id":{"description":"The user's unique identifier","oneOf":[{"type":"string"},{"type":"integer"}]},"name":{"description":"The user's display name","type":"string"},"email":{"description":"The user's email address","anyOf":[{"type":"string"},{"type":"null"}]}},"required":["id","name"]},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"user":{"anyOf":[{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"profile":{"type":"object","properties":{"bio":{"anyOf":[{"type":"string"},{"type":"null"}]},"avatar":{"type":"string"}},"required":["avatar"]}},"required":["id","profile"]},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"thing":{"anyOf":[{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"meta":{"anyOf":[{},{"type":"null"}]},"tags":{"anyOf":[{"type":"array","items":{"anyOf":[{},{"type":"null"}]}},{"type":"null"}]}},"required":["id"]},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"search":{"allOf":[{"type":"object"},{"anyOf":[{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"name":{"anyOf":[{"type":"string"},{"type":"null"}]}},"required":["id"],"propertyNames":{"anyOf":[{"enum":["id","name"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}},{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"name":{"anyOf":[{"type":"string"},{"type":"null"}]}},"required":["id"],"propertyNames":{"anyOf":[{"enum":["id","name"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}}]}]}},"required":["search"]},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}},"definitions":{"$otherResponseKeys0":{"not":{"enum":["id","name"]}}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"pets":{"type":"array","items":{"allOf":[{"type":"object","properties":{"__typename":{"description":"The typename of this object","type":"string"},"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"kind":{"anyOf":[{"type":"string"},{"type":"null"}]},"name":{"anyOf":[{"type":"string"},{"type":"null"}]}},"required":["id"]},{"anyOf":[{"type":"object","properties":{"barks":{"type":"boolean"},"mood":{"anyOf":[{"$ref":"#/definitions/Mood"},{"type":"null"}]}},"required":["barks"],"propertyNames":{"anyOf":[{"enum":["barks","mood"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}},{"type":"object","properties":{"lives":{"anyOf":[{"type":"integer"},{"type":"null"}]},"owner":{"anyOf":[{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]}}},{"type":"null"}]}},"propertyNames":{"anyOf":[{"enum":["lives","owner"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}},{"type":"object","properties":{"lives":{"anyOf":[{"type":"integer"},{"type":"null"}]}},"propertyNames":{"anyOf":[{"enum":["lives"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}}]}]}},"node":{"anyOf":[{"allOf":[{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]},"name":{"anyOf":[{"type":"string"},{"type":"null"}]}},"required":["id"]},{"anyOf":[{"type":"object","propertyNames":{"$ref":"#/definitions/$otherResponseKeys2"}},{"type":"object","properties":{"barks":{"type":"boolean"}},"required":["barks"],"propertyNames":{"anyOf":[{"enum":["barks"]},{"$ref":"#/definitions/$otherResponseKeys2"}]}}]}]},{"type":"null"}]},"lonely":{"anyOf":[{"type":"object","properties":{"x":{"anyOf":[{"type":"integer"},{"type":"null"}]}}},{"type":"null"}]},"person":{"allOf":[{"anyOf":[{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]},"tags":{"type":"array","items":{"anyOf":[{"type":"array","items":{"type":"string"}},{"type":"null"}]}},"plain":{"anyOf":[{"$ref":"#/definitions/Plain"},{"type":"null"}]}},"required":["tags"]},{"type":"null"}]},{"anyOf":[{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]}}},{"type":"null"}]}]},"again":{"allOf":[{"anyOf":[{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]}}},{"type":"null"}]},{"anyOf":[{"type":"object","properties":{"tags":{"type":"array","items":{"anyOf":[{"type":"array","items":{"type":"string"}},{"type":"null"}]}}},"required":["tags"]},{"type":"null"}]}]},"animals":{"anyOf":[{"type":"array","items":{"anyOf":[{"allOf":[{"type":"object"},{"anyOf":[{"type":"object","propertyNames":{"$ref":"#/definitions/$otherResponseKeys4"}},{"allOf":[{"type":"object"},{"$ref":"#/definitions/$sharedField5"}],"propertyNames":{"anyOf":[{"enum":["fur"]},{"$ref":"#/definitions/$otherResponseKeys4"}]}},{"allOf":[{"type":"object","properties":{"barks":{"type":"boolean"}},"required":["barks"]},{"$ref":"#/definitions/$sharedField5"}],"propertyNames":{"anyOf":[{"enum":["barks","fur"]},{"$ref":"#/definitions/$otherResponseKeys4"}]}}]}]},{"type":"null"}]}},{"type":"null"}]},"more":{"anyOf":[{"type":"array","items":{"anyOf":[{"allOf":[{"type":"object","properties":{"name":{"anyOf":[{"type":"string"},{"type":"null"}]}}},{"anyOf":[{"type":"object","propertyNames":{"$ref":"#/definitions/$otherResponseKeys6"}},{"type":"object","properties":{"mood":{"anyOf":[{"$ref":"#/definitions/Mood"},{"type":"null"}]}},"propertyNames":{"anyOf":[{"enum":["mood"]},{"$ref":"#/definitions/$otherResponseKeys6"}]}},{"type":"object","properties":{"mood":{"anyOf":[{"type":"integer"},{"type":"null"}]}},"propertyNames":{"anyOf":[{"enum":["mood"]},{"$ref":"#/definitions/$otherResponseKeys6"}]}}]}]},{"type":"null"}]}},{"type":"null"}]},"bare":{"anyOf":[{},{"type":"null"}]}},"required":["pets"]},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}},"definitions":{"$otherResponseKeys0":{"not":{"enum":["barks","lives","mood","owner"]}},"Mood":{"description":"Moods","type":"string","enum":["HAPPY","SAD"]},"$otherResponseKeys2":{"not":{"enum":["barks"]}},"Plain":{"type":"string","enum":["A","B"]},"$otherResponseKeys4":{"not":{"enum":["barks","fur"]}},"$sharedField5":{"type":"object","properties":{"fur":{"anyOf":[{"type":"string"},{"type":"null"}]}}},"$otherResponseKeys6":{"not":{"enum":["mood"]}}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"m":{"anyOf":[{"description":"mapped","type":"string"},{"type":"null"}]},"y":{"anyOf":[true,{"type":"null"}]},"yd":{"anyOf":[{"description":"Yes with desc"},{"type":"null"}]},"b":{"anyOf":[{},{"type":"null"}]},"f":{"type":"number"},"ids":{"anyOf":[{"type":"array","items":{"anyOf":[{"oneOf":[{"type":"string"},{"type":"integer"}]},{"type":"null"}]}},{"type":"null"}]},"list":{"anyOf":[{"type":"array","items":{"type":"array","items":{"type":"integer"}}},{"type":"null"}]},"__typename":{"description":"The typename of this object","type":"string"}},"required":["f"]},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}}}
{"type":"object","properties":{"data":{"type":"object","properties":{"pet":{"anyOf":[{"allOf":[{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"required":["id"]},{"anyOf":[{"type":"object"},{"type":"object","properties":{"id":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"required":["id"]}]}]},{"type":"null"}]},"animal":{"anyOf":[{"allOf":[{"type":"object"},{"anyOf":[{"type":"object","propertyNames":{"$ref":"#/definitions/$otherResponseKeys0"}},{"type":"object","properties":{"barks":{"anyOf":[{"type":"boolean"},{"type":"null"}]}},"propertyNames":{"anyOf":[{"enum":["barks"]},{"$ref":"#/definitions/$otherResponseKeys0"}]}}]}]},{"type":"null"}]}}},"errors":{"type":"array","items":{"type":"object","properties":{"message":{"type":"string"},"locations":{"type":"array","items":{"type":"object","properties":{"line":{"type":"integer"},"column":{"type":"integer"}}}},"path":{"type":"array","items":{"oneOf":[{"type":"string"},{"type":"integer"}]}},"extensions":{"type":"object"}},"required":["message"]}},"extensions":{"type":"object"}},"definitions":{"$otherResponseKeys0":{"not":{"enum":["barks"]}}}}
"""
"""The expected output schemas, one per line."""
