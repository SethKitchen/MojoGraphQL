# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Subgraphs of the Hive Federation Composition fixtures, and the
supergraph that Hive `composeServices` 0.27.0 prints for them.

The subgraphs are `bench/fixtures/hive-<name>/*.graphql`, which copy the
upstream `__tests__/fixtures`. Each subgraph is named after its file and
has the URL `http://<name>.example.com/graphql`. The supergraphs were
printed by `composeServices` from `bench/baselines/js-composition`.
"""


def BASIC_SUBGRAPHS() -> List[String]:
    """Return the names of the `basic` subgraphs."""
    return ["products", "reviews"]


def BASIC_SDL() -> List[String]:
    """Return the SDL of the `basic` subgraphs, in name order."""
    var out = List[String]()
    out.append(
        '\n      extend schema\n        @link(url: "https://specs.apollo.de'
        'v/federation/v2.0", import: ["@key"])\n\n      type Query {\n      '
        "  products: [Product!]!\n      }\n\n      type Product @key(fields:"
        ' "id") {\n        id: ID!\n        name: String!\n      }\n    '
    )
    out.append(
        '\n      extend schema\n        @link(url: "https://specs.apollo.de'
        'v/federation/v2.0", import: ["@key"])\n\n      type Query {\n      '
        '  reviews: [Review!]!\n      }\n\n      type Product @key(fields: "'
        'id") {\n        id: ID!\n        reviews: [Review!]!\n      }\n\n    '
        '  type Review @key(fields: "id") {\n        id: ID!\n        body:'
        " String!\n      }\n    "
    )
    return out^


def BASIC_SUPERGRAPH() -> String:
    """Return the supergraph of the `basic` subgraphs."""
    return (
        'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(ur'
        'l: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) {\n  que'
        "ry: Query\n}\n\ndirective @join__enumValue(graph: join__Graph!) rep"
        "eatable on ENUM_VALUE\n\ndirective @join__graph(name: String!, url"
        ": String!) on ENUM_VALUE\n\ndirective @join__field(\n  graph: join_"
        "_Graph\n  requires: join__FieldSet\n  provides: join__FieldSet\n  t"
        "ype: String\n  external: Boolean\n  override: String\n  usedOverrid"
        "den: Boolean\n) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFI"
        "NITION\n\ndirective @join__implements(graph: join__Graph!, interfa"
        "ce: String!) repeatable on OBJECT | INTERFACE\n\ndirective @join__"
        "type(\n  graph: join__Graph!\n  key: join__FieldSet\n  extension: B"
        "oolean! = false\n  resolvable: Boolean! = true\n  isInterfaceObjec"
        "t: Boolean! = false\n) repeatable on OBJECT | INTERFACE | UNION |"
        " ENUM | INPUT_OBJECT | SCALAR\n\ndirective @join__unionMember(grap"
        "h: join__Graph!, member: String!) repeatable on UNION\n\nscalar jo"
        "in__FieldSet\n\ndirective @link(url: String, as: String, for: link"
        "__Purpose, import: [link__Import]) repeatable on SCHEMA\n\nscalar "
        'link__Import\n\nenum link__Purpose {\n  """\n  `SECURITY` features p'
        'rovide metadata necessary to securely resolve fields.\n  """\n  SE'
        'CURITY\n  """\n  `EXECUTION` features provide metadata necessary f'
        'or operation execution.\n  """\n  EXECUTION\n}\n\nenum join__Graph {\n'
        '  PRODUCTS @join__graph(name: "products", url: "http://products.'
        'example.com/graphql")\n  REVIEWS @join__graph(name: "reviews", ur'
        'l: "http://reviews.example.com/graphql")\n}\n\ntype Query @join__ty'
        "pe(graph: PRODUCTS) @join__type(graph: REVIEWS) {\n  products: [P"
        "roduct!]! @join__field(graph: PRODUCTS)\n  reviews: [Review!]! @j"
        "oin__field(graph: REVIEWS)\n}\n\ntype Product @join__type(graph: PR"
        'ODUCTS, key: "id") @join__type(graph: REVIEWS, key: "id") {\n  id'
        ": ID!\n  name: String! @join__field(graph: PRODUCTS)\n  reviews: ["
        "Review!]! @join__field(graph: REVIEWS)\n}\n\ntype Review @join__typ"
        'e(graph: REVIEWS, key: "id") {\n  id: ID!\n  body: String!\n}'
    )


def STARS_STUFF_SUBGRAPHS() -> List[String]:
    """Return the names of the `stars-stuff` subgraphs."""
    return ["inventory", "pandas", "products", "reviews", "users"]


def STARS_STUFF_SDL() -> List[String]:
    """Return the SDL of the `stars-stuff` subgraphs, in name order."""
    var out = List[String]()
    out.append(
        '\n      extend schema\n        @link(\n          url: "https://spec'
        's.apollo.dev/federation/v2.1"\n          import: ["@key", "@share'
        'able", "@external", "@requires"]\n        )\n\n      type Product i'
        'mplements ProductItf @key(fields: "id") {\n        id: ID!\n      '
        "  dimensions: ProductDimension @external\n        delivery(zip: S"
        'tring): DeliveryEstimates\n          @requires(fields: "dimension'
        's { size weight }")\n      }\n\n      type ProductDimension @sharea'
        "ble {\n        size: String\n        weight: Float\n      }\n\n      "
        "type DeliveryEstimates {\n        estimatedDelivery: String\n     "
        "   fastestDelivery: String\n      }\n\n      interface ProductItf {"
        "\n        id: ID!\n        dimensions: ProductDimension\n        de"
        "livery(zip: String): DeliveryEstimates\n      }\n\n      enum Shipp"
        "ingClass {\n        STANDARD\n        EXPRESS\n        OVERNIGHT\n  "
        "    }\n    "
    )
    out.append(
        "\n      directive @tag(name: String!) repeatable on FIELD_DEFINIT"
        "ION\n\n      type Query {\n        allPandas: [Panda]\n        panda"
        "(name: ID!): Panda\n      }\n\n      type Panda {\n        name: ID!"
        '\n        favoriteFood: String @tag(name: "nom-nom-nom")\n      }\n'
        "    "
    )
    out.append(
        '\n      extend schema\n        @link(\n          url: "https://spec'
        's.apollo.dev/federation/v2.1"\n          import: [\n            "@'
        'key"\n            "@shareable"\n            "@tag"\n            "@i'
        'naccessible"\n            "@composeDirective"\n          ]\n       '
        ' )\n        @link(\n          url: "https://myspecs.dev/myDirectiv'
        'e/v1.0"\n          import: ["@myDirective", { name: "@anotherDire'
        'ctive", as: "@hello" }]\n        )\n        @composeDirective(name'
        ': "@myDirective")\n        @composeDirective(name: "@hello")\n\n   '
        "   directive @myDirective(a: String!) on FIELD_DEFINITION\n      "
        "directive @hello on FIELD_DEFINITION\n\n      type Query {\n       "
        " allProducts: [ProductItf]\n        product(id: ID!): ProductItf\n"
        "      }\n\n      interface ProductItf implements SkuItf {\n        "
        "id: ID!\n        sku: String\n        name: String\n        package"
        ": String\n        variation: ProductVariation\n        dimensions:"
        " ProductDimension\n        createdBy: User\n        hidden: String"
        ' @inaccessible\n        oldField: String @deprecated(reason: "ref'
        'actored out")\n      }\n\n      interface SkuItf {\n        sku: Str'
        "ing\n      }\n\n      type Product implements ProductItf & SkuItf\n "
        '       @key(fields: "id")\n        @key(fields: "sku package")\n  '
        '      @key(fields: "sku variation { id }") {\n        id: ID! @ta'
        'g(name: "hi-from-products")\n        sku: String\n        name: St'
        "ring @hello\n        package: String\n        variation: ProductVa"
        "riation\n        dimensions: ProductDimension\n        createdBy: "
        "User\n        hidden: String\n        reviewsScore: Float!\n       "
        " oldField: String\n      }\n      enum ShippingClass {\n        STA"
        "NDARD\n        EXPRESS\n      }\n      type ProductVariation {\n    "
        "    id: ID!\n        name: String\n      }\n      type ProductDimen"
        "sion @shareable {\n        size: String\n        weight: Float\n   "
        '   }\n      type User @key(fields: "email") {\n        email: ID!\n'
        "        totalProductsCreated: Int @shareable\n      }\n    "
    )
    out.append(
        '\n      schema\n        @link(\n          url: "https://specs.apoll'
        'o.dev/federation/v2.0"\n          import: ["@key", "@override", "'
        '@shareable"]\n        ) {\n        query: Query\n      }\n\n      typ'
        'e Product implements ProductItf @key(fields: "id") {\n        id:'
        " ID!\n        reviewsCount: Int!\n        reviewsScore: Float! @sh"
        'areable @override(from: "products")\n        reviews: [Review!]!\n'
        "      }\n\n      interface ProductItf {\n        id: ID!\n        re"
        "viewsCount: Int!\n        reviewsScore: Float!\n        reviews: ["
        "Review!]!\n      }\n\n      type Query {\n        review(id: Int!): "
        "Review\n      }\n\n      type Review {\n        id: Int!\n        bod"
        "y: String!\n      }\n    "
    )
    out.append(
        "\n      directive @tag(name: String!) repeatable on FIELD_DEFINIT"
        'ION | OBJECT\n\n      type User @key(fields: "email") {\n        em'
        'ail: ID! @tag(name: "test-from-users")\n        name: String\n    '
        "    totalProductsCreated: Int\n      }\n    "
    )
    return out^


def STARS_STUFF_SUPERGRAPH() -> String:
    """Return the supergraph of the `stars-stuff` subgraphs."""
    return (
        'schema @link(url: "https://specs.apollo.dev/link/v1.0") @link(ur'
        'l: "https://specs.apollo.dev/join/v0.3", for: EXECUTION) @link(u'
        'rl: "https://specs.apollo.dev/tag/v0.3") @link(url: "https://spe'
        'cs.apollo.dev/inaccessible/v0.2", for: SECURITY) @link(\n  url: "'
        'https://myspecs.dev/myDirective/v1.0"\n  import: ["@myDirective",'
        ' {name: "@anotherDirective", as: "@hello"}]\n) {\n  query: Query\n}'
        "\n\ndirective @join__enumValue(graph: join__Graph!) repeatable on "
        "ENUM_VALUE\n\ndirective @join__graph(name: String!, url: String!) "
        "on ENUM_VALUE\n\ndirective @join__field(\n  graph: join__Graph\n  re"
        "quires: join__FieldSet\n  provides: join__FieldSet\n  type: String"
        "\n  external: Boolean\n  override: String\n  usedOverridden: Boolea"
        "n\n) repeatable on FIELD_DEFINITION | INPUT_FIELD_DEFINITION\n\ndir"
        "ective @join__implements(graph: join__Graph!, interface: String!"
        ") repeatable on OBJECT | INTERFACE\n\ndirective @join__type(\n  gra"
        "ph: join__Graph!\n  key: join__FieldSet\n  extension: Boolean! = f"
        "alse\n  resolvable: Boolean! = true\n  isInterfaceObject: Boolean!"
        " = false\n) repeatable on OBJECT | INTERFACE | UNION | ENUM | INP"
        "UT_OBJECT | SCALAR\n\ndirective @join__unionMember(graph: join__Gr"
        "aph!, member: String!) repeatable on UNION\n\nscalar join__FieldSe"
        "t\n\ndirective @link(url: String, as: String, for: link__Purpose, "
        "import: [link__Import]) repeatable on SCHEMA\n\nscalar link__Impor"
        't\n\nenum link__Purpose {\n  """\n  `SECURITY` features provide meta'
        'data necessary to securely resolve fields.\n  """\n  SECURITY\n  ""'
        '"\n  `EXECUTION` features provide metadata necessary for operatio'
        'n execution.\n  """\n  EXECUTION\n}\n\ndirective @tag(name: String!) '
        "repeatable on FIELD_DEFINITION | OBJECT | INTERFACE | UNION | AR"
        "GUMENT_DEFINITION | SCALAR | ENUM | ENUM_VALUE | INPUT_OBJECT | "
        "INPUT_FIELD_DEFINITION | SCHEMA\n\ndirective @inaccessible on FIEL"
        "D_DEFINITION | OBJECT | INTERFACE | UNION | ENUM | ENUM_VALUE | "
        "SCALAR | INPUT_OBJECT | INPUT_FIELD_DEFINITION | ARGUMENT_DEFINI"
        'TION\n\nenum join__Graph {\n  INVENTORY @join__graph(name: "invento'
        'ry", url: "http://inventory.example.com/graphql")\n  PANDAS @join'
        '__graph(name: "pandas", url: "http://pandas.example.com/graphql"'
        ')\n  PRODUCTS @join__graph(name: "products", url: "http://product'
        's.example.com/graphql")\n  REVIEWS @join__graph(name: "reviews", '
        'url: "http://reviews.example.com/graphql")\n  USERS @join__graph('
        'name: "users", url: "http://users.example.com/graphql")\n}\n\ndirec'
        "tive @myDirective(a: String!) on FIELD_DEFINITION\n\ndirective @he"
        "llo on FIELD_DEFINITION\n\ntype Product implements ProductItf & Sk"
        'uItf @join__type(graph: INVENTORY, key: "id") @join__type(graph:'
        ' PRODUCTS, key: "id") @join__type(graph: PRODUCTS, key: "sku pac'
        'kage") @join__type(graph: PRODUCTS, key: "sku variation { id }")'
        ' @join__type(graph: REVIEWS, key: "id") @join__implements(graph:'
        ' INVENTORY, interface: "ProductItf") @join__implements(graph: PR'
        'ODUCTS, interface: "ProductItf") @join__implements(graph: PRODUC'
        'TS, interface: "SkuItf") @join__implements(graph: REVIEWS, inter'
        'face: "ProductItf") {\n  id: ID! @tag(name: "hi-from-products")\n '
        " dimensions: ProductDimension @join__field(graph: INVENTORY, ext"
        "ernal: true) @join__field(graph: PRODUCTS)\n  delivery(zip: Strin"
        'g): DeliveryEstimates @join__field(graph: INVENTORY, requires: "'
        'dimensions{size weight}")\n  sku: String @join__field(graph: PROD'
        "UCTS)\n  package: String @join__field(graph: PRODUCTS)\n  variatio"
        "n: ProductVariation @join__field(graph: PRODUCTS)\n  name: String"
        " @hello @join__field(graph: PRODUCTS)\n  createdBy: User @join__f"
        "ield(graph: PRODUCTS)\n  hidden: String @join__field(graph: PRODU"
        "CTS)\n  reviewsScore: Float! @join__field(graph: REVIEWS, overrid"
        'e: "products")\n  oldField: String @join__field(graph: PRODUCTS)\n'
        "  reviewsCount: Int! @join__field(graph: REVIEWS)\n  reviews: [Re"
        "view!]! @join__field(graph: REVIEWS)\n}\n\ntype ProductDimension @j"
        "oin__type(graph: INVENTORY) @join__type(graph: PRODUCTS) {\n  siz"
        "e: String\n  weight: Float\n}\n\ntype DeliveryEstimates @join__type("
        "graph: INVENTORY) {\n  estimatedDelivery: String\n  fastestDeliver"
        "y: String\n}\n\ntype Query @join__type(graph: INVENTORY) @join__typ"
        "e(graph: PANDAS) @join__type(graph: PRODUCTS) @join__type(graph:"
        " REVIEWS) @join__type(graph: USERS) {\n  allPandas: [Panda] @join"
        "__field(graph: PANDAS)\n  panda(name: ID!): Panda @join__field(gr"
        "aph: PANDAS)\n  allProducts: [ProductItf] @join__field(graph: PRO"
        "DUCTS)\n  product(id: ID!): ProductItf @join__field(graph: PRODUC"
        "TS)\n  review(id: Int!): Review @join__field(graph: REVIEWS)\n}\n\nt"
        "ype Panda @join__type(graph: PANDAS) {\n  name: ID!\n  favoriteFoo"
        'd: String @tag(name: "nom-nom-nom")\n}\n\ntype ProductVariation @jo'
        "in__type(graph: PRODUCTS) {\n  id: ID!\n  name: String\n}\n\ntype Use"
        'r @join__type(graph: PRODUCTS, key: "email") @join__type(graph: '
        'USERS, key: "email") {\n  email: ID! @tag(name: "test-from-users"'
        ")\n  totalProductsCreated: Int\n  name: String @join__field(graph:"
        " USERS)\n}\n\ntype Review @join__type(graph: REVIEWS) {\n  id: Int!\n"
        "  body: String!\n}\n\ninterface ProductItf implements SkuItf @join_"
        "_type(graph: INVENTORY) @join__type(graph: PRODUCTS) @join__type"
        '(graph: REVIEWS) @join__implements(graph: PRODUCTS, interface: "'
        'SkuItf") {\n  id: ID!\n  dimensions: ProductDimension @join__field'
        "(graph: INVENTORY) @join__field(graph: PRODUCTS)\n  delivery(zip:"
        " String): DeliveryEstimates @join__field(graph: INVENTORY)\n  sku"
        ": String @join__field(graph: PRODUCTS)\n  name: String @join__fie"
        "ld(graph: PRODUCTS)\n  package: String @join__field(graph: PRODUC"
        "TS)\n  variation: ProductVariation @join__field(graph: PRODUCTS)\n"
        "  createdBy: User @join__field(graph: PRODUCTS)\n  hidden: String"
        " @join__field(graph: PRODUCTS) @inaccessible\n  oldField: String "
        '@join__field(graph: PRODUCTS) @deprecated(reason: "refactored ou'
        't")\n  reviewsCount: Int! @join__field(graph: REVIEWS)\n  reviewsS'
        "core: Float! @join__field(graph: REVIEWS)\n  reviews: [Review!]! "
        "@join__field(graph: REVIEWS)\n}\n\ninterface SkuItf @join__type(gra"
        "ph: PRODUCTS) {\n  sku: String\n}\n\nenum ShippingClass @join__type("
        "graph: INVENTORY) @join__type(graph: PRODUCTS) {\n  STANDARD @joi"
        "n__enumValue(graph: INVENTORY) @join__enumValue(graph: PRODUCTS)"
        "\n  EXPRESS @join__enumValue(graph: INVENTORY) @join__enumValue(g"
        "raph: PRODUCTS)\n  OVERNIGHT @join__enumValue(graph: INVENTORY)\n}"
    )
