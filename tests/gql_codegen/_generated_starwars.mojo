# AUTO-GENERATED FILE. DO NOT MODIFY.
#
# gql_codegen wrote this module, as the Apollo Kotlin code
# generator writes Kotlin models.

"""The operations, their variables and their models."""

from gql_json.value import JsonDocument, JsonKind
from gql_json.writer import JsonWriter


def _member(document: JsonDocument, node: Int, name: StringSlice) raises -> Int:
    """Return the value of a member of an object, or -1 when it is missing."""
    if document.kind(node) != JsonKind.OBJECT:
        raise Error("expected an object with the field " + String(name))
    return document.find(node, name)


def _required(
    document: JsonDocument, node: Int, name: StringSlice
) raises -> Int:
    """Return the value of a member that must be there and not be null."""
    var value = _member(document, node, name)
    if value < 0:
        raise Error("missing field " + String(name))
    if document.kind(value) == JsonKind.NULL:
        raise Error("null for the non-null field " + String(name))
    return value


def _is_null(document: JsonDocument, value: Int) -> Bool:
    """Return True for a missing member or null."""
    return value < 0 or document.kind(value) == JsonKind.NULL


def _read_string(document: JsonDocument, value: Int) raises -> String:
    """Read a string."""
    if document.kind(value) != JsonKind.STRING:
        raise Error("expected a string")
    return document.string_value(value)


def _read_id(document: JsonDocument, value: Int) raises -> String:
    """Read an ID: a string, or the text of a number."""
    if document.kind(value) == JsonKind.NUMBER:
        return String(document.text(value))
    return _read_string(document, value)


def _read_int(document: JsonDocument, value: Int) raises -> Int:
    """Read an Int."""
    if not document.is_integer(value):
        raise Error("expected an integer")
    return Int(document.as_int64(value))


def _read_float(document: JsonDocument, value: Int) raises -> Float64:
    """Read a Float."""
    if document.kind(value) != JsonKind.NUMBER:
        raise Error("expected a number")
    return document.as_float64(value)


def _read_boolean(document: JsonDocument, value: Int) raises -> Bool:
    """Read a Boolean."""
    if document.kind(value) != JsonKind.BOOLEAN:
        raise Error("expected a boolean")
    return document.bool_value(value)


def _read_json(document: JsonDocument, value: Int) -> String:
    """Read a custom scalar: its JSON text."""
    var writer = JsonWriter()
    writer.value(document, value)
    return writer^.take_string()


def _items(document: JsonDocument, value: Int) raises -> List[Int]:
    """Return the items of a list."""
    if document.kind(value) != JsonKind.ARRAY:
        raise Error("expected a list")
    return document.children(value)


def _typename(document: JsonDocument, node: Int) raises -> String:
    """Return the `__typename` of an object."""
    return _read_string(document, _required(document, node, "__typename"))


def _is_one_of(value: String, *names: StaticString) -> Bool:
    """Return True when a `__typename` is one of the possible types."""
    for name in names:
        if value == name:
            return True
    return False


def _is_true(false_variables: List[String], name: StaticString) -> Bool:
    """Return True unless the variable of a condition is false."""
    for ref variable in false_variables:
        if variable == name:
            return False
    return True


@fieldwise_init
struct Episode(Equatable, ImplicitlyCopyable, Movable, Writable):
    """The enum Episode."""

    var value: UInt8
    """The index of the value; see `is_valid`."""

    comptime NEWHOPE = Episode(0)
    comptime EMPIRE = Episode(1)
    comptime JEDI = Episode(2)
    comptime UNKNOWN__ = Episode(3)

    def is_valid(self) -> Bool:
        """Return True for a value of the schema."""
        return self.value < 3

    def raw_value(self) raises -> String:
        """Return the name of the value in GraphQL."""
        if self == Episode.NEWHOPE:
            return "NEWHOPE"
        if self == Episode.EMPIRE:
            return "EMPIRE"
        if self == Episode.JEDI:
            return "JEDI"
        raise Error("the value of Episode is not known")

    @staticmethod
    def safe_value_of(raw: StringSlice) -> Episode:
        """Read a value; `UNKNOWN__` for another name."""
        if raw == "NEWHOPE":
            return Episode.NEWHOPE
        if raw == "EMPIRE":
            return Episode.EMPIRE
        if raw == "JEDI":
            return Episode.JEDI
        return Episode.UNKNOWN__

    def write_to(self, mut writer: Some[Writer]):
        """Write the name of the value."""
        try:
            writer.write(self.raw_value())
        except:
            writer.write("UNKNOWN__")


struct ReviewInput(Copyable, Movable):
    """The input object ReviewInput."""

    var stars: Int
    var commentary: Optional[Optional[String]]
    var favoriteColor: Optional[Optional[ColorInput]]
    var tags: Optional[Optional[List[String]]]
    var episodes: Optional[Optional[List[Optional[Episode]]]]
    var when: Optional[Optional[String]]
    var isFan: Optional[Optional[Bool]]

    def __init__(
        out self,
        stars: Int,
        commentary: Optional[Optional[String]] = None,
        favoriteColor: Optional[Optional[ColorInput]] = None,
        tags: Optional[Optional[List[String]]] = None,
        episodes: Optional[Optional[List[Optional[Episode]]]] = None,
        when: Optional[Optional[String]] = None,
        isFan: Optional[Optional[Bool]] = None,
    ):
        """Set every field."""
        self.stars = stars.copy()
        self.commentary = commentary.copy()
        self.favoriteColor = favoriteColor.copy()
        self.tags = tags.copy()
        self.episodes = episodes.copy()
        self.when = when.copy()
        self.isFan = isFan.copy()

    def write_json(self, mut writer: JsonWriter) raises:
        """Write the input object as JSON."""
        writer.begin_object()
        writer.key("stars")
        writer.int(Int64(self.stars))
        if self.commentary:
            writer.key("commentary")
            if self.commentary.value():
                writer.string(self.commentary.value().value())
            else:
                writer.null()
        if self.favoriteColor:
            writer.key("favoriteColor")
            if self.favoriteColor.value():
                self.favoriteColor.value().value().write_json(writer)
            else:
                writer.null()
        if self.tags:
            writer.key("tags")
            if self.tags.value():
                writer.begin_array()
                for ref v1 in self.tags.value().value():
                    writer.string(v1)
                writer.end_array()
            else:
                writer.null()
        if self.episodes:
            writer.key("episodes")
            if self.episodes.value():
                writer.begin_array()
                for ref v2 in self.episodes.value().value():
                    if v2:
                        writer.string(v2.value().raw_value())
                    else:
                        writer.null()
                writer.end_array()
            else:
                writer.null()
        if self.when:
            writer.key("when")
            if self.when.value():
                writer.raw(self.when.value().value())
            else:
                writer.null()
        if self.isFan:
            writer.key("isFan")
            if self.isFan.value():
                writer.bool(self.isFan.value().value())
            else:
                writer.null()
        writer.end_object()


struct ColorInput(Copyable, Movable):
    """The input object ColorInput."""

    var red: Optional[Int]
    var green: Int
    var blue: Int

    def __init__(out self, green: Int, blue: Int, red: Optional[Int] = None):
        """Set every field."""
        self.red = red.copy()
        self.green = green.copy()
        self.blue = blue.copy()

    def write_json(self, mut writer: JsonWriter) raises:
        """Write the input object as JSON."""
        writer.begin_object()
        if self.red:
            writer.key("red")
            writer.int(Int64(self.red.value()))
        writer.key("green")
        writer.int(Int64(self.green))
        writer.key("blue")
        writer.int(Int64(self.blue))
        writer.end_object()


@fieldwise_init
struct CharacterAppearances(Copyable, Movable):
    """The model fragmentData.CharacterAppearances.CharacterAppearances."""

    var appearsIn: List[Optional[Episode]]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j3 = _required(document, node, "appearsIn")
        var f_appearsIn = List[Optional[Episode]]()
        for v4 in _items(document, j3):
            var t5 = Optional[Episode](None)
            if not _is_null(document, v4):
                var t6 = Episode.safe_value_of(_read_string(document, v4))
                t5 = t6
            f_appearsIn.append(t5^)
        return Self(f_appearsIn^)


struct HeroQuery:
    """The query Hero."""

    comptime OPERATION_ID = (
        "de10189bf4ac5504f5ba4a3122851607374c9fe72abfdb0bfba66c78a4b95dd6"
    )
    comptime OPERATION_NAME = "Hero"
    comptime OPERATION_DOCUMENT = (
        "query Hero($episode: Episode, $withFriends: Boolean! = true ,"
        + " $skipName: Boolean = false ) { hero(episode: $episode) {"
        + " __typename name @skip(if: $skipName) id friends @include(if:"
        + " $withFriends) { name } ... on Droid { primaryFunction } ... on"
        + " Human { height(unit: FOOT) birthDate } ...CharacterAppearances } }"
        + "  fragment CharacterAppearances on Character { appearsIn }"
    )

    @staticmethod
    def parse_data(
        document: JsonDocument,
        node: Int,
        variables: HeroQuery_Variables,
    ) raises -> HeroQuery_Data:
        """Read the data of a response."""
        return HeroQuery_Data.from_json(
            document, node, variables.false_variables()
        )


struct HeroQuery_Variables(Copyable, Movable):
    """The variables of HeroQuery."""

    var episode: Optional[Optional[Episode]]
    var withFriends: Optional[Bool]
    var skipName: Optional[Optional[Bool]]

    def __init__(
        out self,
        episode: Optional[Optional[Episode]] = None,
        withFriends: Optional[Bool] = None,
        skipName: Optional[Optional[Bool]] = None,
    ):
        """Set every field."""
        self.episode = episode.copy()
        self.withFriends = withFriends.copy()
        self.skipName = skipName.copy()

    def write_json(
        self, mut writer: JsonWriter, with_default_values: Bool = False
    ) raises:
        """Write the variables as JSON, as upstream serializeVariables."""
        writer.begin_object()
        if self.episode:
            writer.key("episode")
            if self.episode.value():
                writer.string(self.episode.value().value().raw_value())
            else:
                writer.null()
        if self.withFriends:
            writer.key("withFriends")
            writer.bool(self.withFriends.value())
        elif with_default_values:
            writer.key("withFriends")
            writer.raw("true")
        if self.skipName:
            writer.key("skipName")
            if self.skipName.value():
                writer.bool(self.skipName.value().value())
            else:
                writer.null()
        elif with_default_values:
            writer.key("skipName")
            writer.raw("false")
        writer.end_object()

    def false_variables(self) -> List[String]:
        """Return the Boolean variables that are false, defaults too."""
        var out = List[String]()
        if self.withFriends:
            if not self.withFriends.value():
                out.append("withFriends")
        if self.skipName:
            if not self.skipName.value().or_else(True):
                out.append("skipName")
        else:
            out.append("skipName")
        return out^


@fieldwise_init
struct HeroQuery_Data(Copyable, Movable):
    """The model operationData.Hero.data."""

    var hero: Optional[HeroQuery_Data_Hero]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j7 = _member(document, node, "hero")
        var f_hero = Optional[HeroQuery_Data_Hero](None)
        if not _is_null(document, j7):
            var t8 = HeroQuery_Data_Hero.from_json(
                document, j7, false_variables
            )
            f_hero = t8^
        return Self(f_hero^)


@fieldwise_init
struct HeroQuery_Data_Hero(Copyable, Movable):
    """The model operationData.Hero.data.hero."""

    var __typename: String
    var name: Optional[String]
    var id: String
    var friends: Optional[List[Optional[HeroQuery_Data_Hero_Friend]]]
    var onDroid: Optional[HeroQuery_Data_Hero_OnDroid]
    var onHuman: Optional[HeroQuery_Data_Hero_OnHuman]
    var characterAppearances: CharacterAppearances

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var typename = _typename(document, node)
        var j9 = _required(document, node, "__typename")
        var f___typename = _read_string(document, j9)
        var j10 = _member(document, node, "name")
        var f_name = Optional[String](None)
        if not _is_null(document, j10):
            var t11 = _read_string(document, j10)
            f_name = t11^
        var j12 = _required(document, node, "id")
        var f_id = _read_id(document, j12)
        var j13 = _member(document, node, "friends")
        var f_friends = Optional[List[Optional[HeroQuery_Data_Hero_Friend]]](
            None
        )
        if not _is_null(document, j13):
            var t14 = List[Optional[HeroQuery_Data_Hero_Friend]]()
            for v15 in _items(document, j13):
                var t16 = Optional[HeroQuery_Data_Hero_Friend](None)
                if not _is_null(document, v15):
                    var t17 = HeroQuery_Data_Hero_Friend.from_json(
                        document, v15, false_variables
                    )
                    t16 = t17^
                t14.append(t16^)
            f_friends = t14^
        var f_onDroid = Optional[HeroQuery_Data_Hero_OnDroid](None)
        var c18 = _is_one_of(typename, "Droid")
        if c18:
            var t19 = HeroQuery_Data_Hero_OnDroid.from_json(
                document, node, false_variables
            )
            f_onDroid = t19^
        var f_onHuman = Optional[HeroQuery_Data_Hero_OnHuman](None)
        var c20 = _is_one_of(typename, "Human")
        if c20:
            var t21 = HeroQuery_Data_Hero_OnHuman.from_json(
                document, node, false_variables
            )
            f_onHuman = t21^
        var f_characterAppearances = CharacterAppearances.from_json(
            document, node, false_variables
        )
        return Self(
            f___typename^,
            f_name^,
            f_id^,
            f_friends^,
            f_onDroid^,
            f_onHuman^,
            f_characterAppearances^,
        )


@fieldwise_init
struct HeroQuery_Data_Hero_Friend(Copyable, Movable):
    """The model operationData.Hero.data.hero.friends."""

    var name: String

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j22 = _required(document, node, "name")
        var f_name = _read_string(document, j22)
        return Self(f_name^)


@fieldwise_init
struct HeroQuery_Data_Hero_OnDroid(Copyable, Movable):
    """The model operationData.Hero.data.hero.onDroid."""

    var primaryFunction: Optional[String]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j23 = _member(document, node, "primaryFunction")
        var f_primaryFunction = Optional[String](None)
        if not _is_null(document, j23):
            var t24 = _read_string(document, j23)
            f_primaryFunction = t24^
        return Self(f_primaryFunction^)


@fieldwise_init
struct HeroQuery_Data_Hero_OnHuman(Copyable, Movable):
    """The model operationData.Hero.data.hero.onHuman."""

    var height: Optional[Float64]
    var birthDate: Optional[String]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j25 = _member(document, node, "height")
        var f_height = Optional[Float64](None)
        if not _is_null(document, j25):
            var t26 = _read_float(document, j25)
            f_height = t26
        var j27 = _member(document, node, "birthDate")
        var f_birthDate = Optional[String](None)
        if not _is_null(document, j27):
            var t28 = _read_json(document, j27)
            f_birthDate = t28^
        return Self(f_height^, f_birthDate^)


struct SearchQuery:
    """The query Search."""

    comptime OPERATION_ID = (
        "caaabee8cf7b970dfde1e34ad599b4fd224589f49c43d1a50e81831f60a42096"
    )
    comptime OPERATION_NAME = "Search"
    comptime OPERATION_DOCUMENT = (
        "query Search($text: String!, $verbose: Boolean! = false ) {"
        + " search(text: $text) { __typename ... on Human { name mass"
        + " @include(if: $verbose) } ... on Droid { name } } matrix }"
    )

    @staticmethod
    def parse_data(
        document: JsonDocument,
        node: Int,
        variables: SearchQuery_Variables,
    ) raises -> SearchQuery_Data:
        """Read the data of a response."""
        return SearchQuery_Data.from_json(
            document, node, variables.false_variables()
        )


struct SearchQuery_Variables(Copyable, Movable):
    """The variables of SearchQuery."""

    var text: String
    var verbose: Optional[Bool]

    def __init__(out self, text: String, verbose: Optional[Bool] = None):
        """Set every field."""
        self.text = text.copy()
        self.verbose = verbose.copy()

    def write_json(
        self, mut writer: JsonWriter, with_default_values: Bool = False
    ) raises:
        """Write the variables as JSON, as upstream serializeVariables."""
        writer.begin_object()
        writer.key("text")
        writer.string(self.text)
        if self.verbose:
            writer.key("verbose")
            writer.bool(self.verbose.value())
        elif with_default_values:
            writer.key("verbose")
            writer.raw("false")
        writer.end_object()

    def false_variables(self) -> List[String]:
        """Return the Boolean variables that are false, defaults too."""
        var out = List[String]()
        if self.verbose:
            if not self.verbose.value():
                out.append("verbose")
        else:
            out.append("verbose")
        return out^


@fieldwise_init
struct SearchQuery_Data(Copyable, Movable):
    """The model operationData.Search.data."""

    var search: List[SearchQuery_Data_Search]
    var matrix: Optional[List[Optional[List[Int]]]]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j29 = _required(document, node, "search")
        var f_search = List[SearchQuery_Data_Search]()
        for v30 in _items(document, j29):
            var t31 = SearchQuery_Data_Search.from_json(
                document, v30, false_variables
            )
            f_search.append(t31^)
        var j32 = _member(document, node, "matrix")
        var f_matrix = Optional[List[Optional[List[Int]]]](None)
        if not _is_null(document, j32):
            var t33 = List[Optional[List[Int]]]()
            for v34 in _items(document, j32):
                var t35 = Optional[List[Int]](None)
                if not _is_null(document, v34):
                    var t36 = List[Int]()
                    for v37 in _items(document, v34):
                        var t38 = _read_int(document, v37)
                        t36.append(t38)
                    t35 = t36^
                t33.append(t35^)
            f_matrix = t33^
        return Self(f_search^, f_matrix^)


@fieldwise_init
struct SearchQuery_Data_Search(Copyable, Movable):
    """The model operationData.Search.data.search."""

    var __typename: String
    var onHuman: Optional[SearchQuery_Data_Search_OnHuman]
    var onDroid: Optional[SearchQuery_Data_Search_OnDroid]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var typename = _typename(document, node)
        var j39 = _required(document, node, "__typename")
        var f___typename = _read_string(document, j39)
        var f_onHuman = Optional[SearchQuery_Data_Search_OnHuman](None)
        var c40 = _is_one_of(typename, "Human")
        if c40:
            var t41 = SearchQuery_Data_Search_OnHuman.from_json(
                document, node, false_variables
            )
            f_onHuman = t41^
        var f_onDroid = Optional[SearchQuery_Data_Search_OnDroid](None)
        var c42 = _is_one_of(typename, "Droid")
        if c42:
            var t43 = SearchQuery_Data_Search_OnDroid.from_json(
                document, node, false_variables
            )
            f_onDroid = t43^
        return Self(f___typename^, f_onHuman^, f_onDroid^)


@fieldwise_init
struct SearchQuery_Data_Search_OnHuman(Copyable, Movable):
    """The model operationData.Search.data.search.onHuman."""

    var name: String
    var mass: Optional[Float64]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j44 = _required(document, node, "name")
        var f_name = _read_string(document, j44)
        var j45 = _member(document, node, "mass")
        var f_mass = Optional[Float64](None)
        if not _is_null(document, j45):
            var t46 = _read_float(document, j45)
            f_mass = t46
        return Self(f_name^, f_mass^)


@fieldwise_init
struct SearchQuery_Data_Search_OnDroid(Copyable, Movable):
    """The model operationData.Search.data.search.onDroid."""

    var name: String

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j47 = _required(document, node, "name")
        var f_name = _read_string(document, j47)
        return Self(f_name^)


struct CreateReviewMutation:
    """The mutation CreateReview."""

    comptime OPERATION_ID = (
        "dc627071c7ae8b1974e800a5232a0bf5cd1ea9cf58d41fed253ac319074fe90b"
    )
    comptime OPERATION_NAME = "CreateReview"
    comptime OPERATION_DOCUMENT = (
        "mutation CreateReview($episode: Episode, $review: ReviewInput!) {"
        + " createReview(episode: $episode, review: $review) { stars"
        + " commentary from } }"
    )

    @staticmethod
    def parse_data(
        document: JsonDocument,
        node: Int,
        variables: CreateReviewMutation_Variables,
    ) raises -> CreateReviewMutation_Data:
        """Read the data of a response."""
        return CreateReviewMutation_Data.from_json(
            document, node, variables.false_variables()
        )


struct CreateReviewMutation_Variables(Copyable, Movable):
    """The variables of CreateReviewMutation."""

    var episode: Optional[Optional[Episode]]
    var review: ReviewInput

    def __init__(
        out self,
        review: ReviewInput,
        episode: Optional[Optional[Episode]] = None,
    ):
        """Set every field."""
        self.episode = episode.copy()
        self.review = review.copy()

    def write_json(
        self, mut writer: JsonWriter, with_default_values: Bool = False
    ) raises:
        """Write the variables as JSON, as upstream serializeVariables."""
        writer.begin_object()
        if self.episode:
            writer.key("episode")
            if self.episode.value():
                writer.string(self.episode.value().value().raw_value())
            else:
                writer.null()
        writer.key("review")
        self.review.write_json(writer)
        writer.end_object()

    def false_variables(self) -> List[String]:
        """Return the Boolean variables that are false, defaults too."""
        var out = List[String]()
        return out^


@fieldwise_init
struct CreateReviewMutation_Data(Copyable, Movable):
    """The model operationData.CreateReview.data."""

    var createReview: Optional[CreateReviewMutation_Data_CreateReview]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j48 = _member(document, node, "createReview")
        var f_createReview = Optional[CreateReviewMutation_Data_CreateReview](
            None
        )
        if not _is_null(document, j48):
            var t49 = CreateReviewMutation_Data_CreateReview.from_json(
                document, j48, false_variables
            )
            f_createReview = t49^
        return Self(f_createReview^)


@fieldwise_init
struct CreateReviewMutation_Data_CreateReview(Copyable, Movable):
    """The model operationData.CreateReview.data.createReview."""

    var stars: Int
    var commentary: Optional[String]
    var from_: Optional[String]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j50 = _required(document, node, "stars")
        var f_stars = _read_int(document, j50)
        var j51 = _member(document, node, "commentary")
        var f_commentary = Optional[String](None)
        if not _is_null(document, j51):
            var t52 = _read_string(document, j51)
            f_commentary = t52^
        var j53 = _member(document, node, "from")
        var f_from = Optional[String](None)
        if not _is_null(document, j53):
            var t54 = _read_string(document, j53)
            f_from = t54^
        return Self(f_stars, f_commentary^, f_from^)


struct DeferredQuery:
    """The query Deferred."""

    comptime OPERATION_ID = (
        "1f4fb5b95882c00263e4bf6be22e9220da11be27e86a1701073f1ea850d67a67"
    )
    comptime OPERATION_NAME = "Deferred"
    comptime OPERATION_DOCUMENT = (
        "query Deferred { hero { __typename id ... on Droid @defer(label:"
        + ' "droid") { primaryFunction } } }'
    )

    @staticmethod
    def parse_data(
        document: JsonDocument,
        node: Int,
        variables: DeferredQuery_Variables,
    ) raises -> DeferredQuery_Data:
        """Read the data of a response."""
        return DeferredQuery_Data.from_json(
            document, node, variables.false_variables()
        )


struct DeferredQuery_Variables(Copyable, Movable):
    """The variables of DeferredQuery."""

    def __init__(out self):
        """Set every field."""
        pass

    def write_json(
        self, mut writer: JsonWriter, with_default_values: Bool = False
    ) raises:
        """Write the variables as JSON, as upstream serializeVariables."""
        writer.begin_object()
        writer.end_object()

    def false_variables(self) -> List[String]:
        """Return the Boolean variables that are false, defaults too."""
        var out = List[String]()
        return out^


@fieldwise_init
struct DeferredQuery_Data(Copyable, Movable):
    """The model operationData.Deferred.data."""

    var hero: Optional[DeferredQuery_Data_Hero]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j55 = _member(document, node, "hero")
        var f_hero = Optional[DeferredQuery_Data_Hero](None)
        if not _is_null(document, j55):
            var t56 = DeferredQuery_Data_Hero.from_json(
                document, j55, false_variables
            )
            f_hero = t56^
        return Self(f_hero^)


@fieldwise_init
struct DeferredQuery_Data_Hero(Copyable, Movable):
    """The model operationData.Deferred.data.hero."""

    var __typename: String
    var id: String
    var onDroid: Optional[DeferredQuery_Data_Hero_OnDroid]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var typename = _typename(document, node)
        var j57 = _required(document, node, "__typename")
        var f___typename = _read_string(document, j57)
        var j58 = _required(document, node, "id")
        var f_id = _read_id(document, j58)
        var f_onDroid = Optional[DeferredQuery_Data_Hero_OnDroid](None)
        var c60 = _is_one_of(typename, "Droid")
        var c61 = c60 and True
        var c59 = c61
        if c59:
            try:
                var t62 = DeferredQuery_Data_Hero_OnDroid.from_json(
                    document, node, false_variables
                )
                f_onDroid = t62^
            except:
                pass
        return Self(f___typename^, f_id^, f_onDroid^)


@fieldwise_init
struct DeferredQuery_Data_Hero_OnDroid(Copyable, Movable):
    """The model operationData.Deferred.data.hero.onDroid."""

    var primaryFunction: Optional[String]

    @staticmethod
    def from_json(
        document: JsonDocument, node: Int, false_variables: List[String]
    ) raises -> Self:
        """Read the model from a JSON object."""
        var j63 = _member(document, node, "primaryFunction")
        var f_primaryFunction = Optional[String](None)
        if not _is_null(document, j63):
            var t64 = _read_string(document, j63)
            f_primaryFunction = t64^
        return Self(f_primaryFunction^)
