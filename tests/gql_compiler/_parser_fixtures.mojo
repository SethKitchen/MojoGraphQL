# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The files of `parser_fixtures/`, written by `_embed_parser.mojo`.
Do not edit."""


def _path_0() -> String:
    var out = String()
    out += "lexer_err/0001_unterminated_spread_operator_with_one.graphql"
    return out^


def _input_0() -> String:
    var out = String()
    out += "."
    return out^


def _expected_0() -> String:
    var out = String()
    out += 'ERROR@0:1 "Unterminated spread operator" .\nEOF@1:1\n'
    return out^


def _path_1() -> String:
    var out = String()
    out += "lexer_err/0002_unterminated_spread_operator_with_2.graphql"
    return out^


def _input_1() -> String:
    var out = String()
    out += ".."
    return out^


def _expected_1() -> String:
    var out = String()
    out += 'ERROR@0:2 "Unterminated spread operator" ..\nEOF@2:2\n'
    return out^


def _path_2() -> String:
    var out = String()
    out += "lexer_err/0003_float_with_incorrect_decimal_point.graphql"
    return out^


def _input_2() -> String:
    var out = String()
    out += "456E34.54"
    return out^


def _expected_2() -> String:
    var out = String()
    out += 'ERROR@0:7 "Unexpected character `.` as float suffix" 456E3'
    out += '4.\nINT@7:9 "54"\nEOF@9:9\n'
    return out^


def _path_3() -> String:
    var out = String()
    out += "lexer_err/0004_unterminated_string_value.graphql"
    return out^


def _input_3() -> String:
    var out = String()
    out += '"'
    return out^


def _expected_3() -> String:
    var out = String()
    out += 'ERROR@0:1 "unexpected end of data while lexing string value'
    out += '" "\nEOF@1:1\n'
    return out^


def _path_4() -> String:
    var out = String()
    out += "lexer_err/0005_escaped_char.graphql"
    return out^


def _input_4() -> String:
    var out = String()
    out += '{\n    sku: "\\a invalidly escaped"\n    stringValue: "\\'
    out += '"properly escaped\\""\n    name: "\\invalidly escaped\\'
    out += '""\n}'
    return out^


def _expected_4() -> String:
    var out = String()
    out += 'L_CURLY@0:1 "{"\nWHITESPACE@1:6 "\\n    "\nNAME@6:9 "sk'
    out += 'u"\nCOLON@9:10 ":"\nWHITESPACE@10:11 " "\nERROR@11:33 '
    out += '"unexpected escaped character" "\\a invalidly escaped"\n'
    out += 'WHITESPACE@33:38 "\\n    "\nNAME@38:49 "stringValue"\nCO'
    out += 'LON@49:50 ":"\nWHITESPACE@50:51 " "\nSTRING_VALUE@51:73 '
    out += '"\\"\\\\\\"properly escaped\\\\\\"\\""\nWHITESPACE@73:'
    out += '78 "\\n    "\nNAME@78:82 "name"\nCOLON@82:83 ":"\nWHIT'
    out += 'ESPACE@83:84 " "\nERROR@84:106 "unexpected escaped charac'
    out += 'ter" "\\invalidly escaped\\""\nWHITESPACE@106:107 "\\n'
    out += '"\nR_CURLY@107:108 "}"\nEOF@108:108\n'
    return out^


def _path_5() -> String:
    var out = String()
    out += "lexer_err/0006_unterminated_string_value_in_list_value_argum"
    out += "ent.graphql"
    return out^


def _input_5() -> String:
    var out = String()
    out += 'extend schema\n  @link(url: "https://specs.apollo.dev/feder'
    out += 'ation/v2.0",\n        import: ["@key", "@external])\n\nt'
    out += 'ype Vehicle @key(fields: "id") {\n  id: ID!,\n  type: Stri'
    out += "ng,\n  modelCode: String,\n  brandName: String,\n  launchDat"
    out += "e: String\n}"
    return out^


def _expected_5() -> String:
    var out = String()
    out += 'NAME@0:6 "extend"\nWHITESPACE@6:7 " "\nNAME@7:13 "schem'
    out += 'a"\nWHITESPACE@13:16 "\\n  "\nAT@16:17 "@"\nNAME@17:21 '
    out += '"link"\nL_PAREN@21:22 "("\nNAME@22:25 "url"\nCOLON@25:'
    out += '26 ":"\nWHITESPACE@26:27 " "\nSTRING_VALUE@27:69 "\\"h'
    out += 'ttps://specs.apollo.dev/federation/v2.0\\""\nCOMMA@69:70 '
    out += '","\nWHITESPACE@70:79 "\\n        "\nNAME@79:85 "import'
    out += '"\nCOLON@85:86 ":"\nWHITESPACE@86:87 " "\nL_BRACKET@87:'
    out += '88 "["\nSTRING_VALUE@88:94 "\\"@key\\""\nCOMMA@94:95 '
    out += '","\nWHITESPACE@95:96 " "\nERROR@96:137 "unexpected lin'
    out += 'e terminator" "@external])\n\ntype Vehicle @key(fields: "'
    out += '\nNAME@137:139 "id"\nERROR@139:235 "unterminated string v'
    out += 'alue" ") {\n  id: ID!,\n  type: String,\n  modelCode: Stri'
    out += "ng,\n  brandName: String,\n  launchDate: String\n}\nEOF@235:"
    out += "235\n"
    return out^


def _path_6() -> String:
    var out = String()
    out += "lexer_err/0007_unterminated_string_value_in_object_value_arg"
    out += "ument.graphql"
    return out^


def _input_6() -> String:
    var out = String()
    out += 'mutation {\n  createStore(draft: {\n    name: [{ locale: "e'
    out += 'n", value: "my store }]\n  }) {\n    name(locale: "en")'
    out += "\n  }\n}"
    return out^


def _expected_6() -> String:
    var out = String()
    out += 'NAME@0:8 "mutation"\nWHITESPACE@8:9 " "\nL_CURLY@9:10 "'
    out += '{"\nWHITESPACE@10:13 "\\n  "\nNAME@13:24 "createStore"'
    out += '\nL_PAREN@24:25 "("\nNAME@25:30 "draft"\nCOLON@30:31 ":'
    out += '"\nWHITESPACE@31:32 " "\nL_CURLY@32:33 "{"\nWHITESPACE@'
    out += '33:38 "\\n    "\nNAME@38:42 "name"\nCOLON@42:43 ":"\nW'
    out += 'HITESPACE@43:44 " "\nL_BRACKET@44:45 "["\nL_CURLY@45:46 '
    out += '"{"\nWHITESPACE@46:47 " "\nNAME@47:53 "locale"\nCOLON@'
    out += '53:54 ":"\nWHITESPACE@54:55 " "\nSTRING_VALUE@55:59 "\\'
    out += '"en\\""\nCOMMA@59:60 ","\nWHITESPACE@60:61 " "\nNAME@'
    out += '61:66 "value"\nCOLON@66:67 ":"\nWHITESPACE@67:68 " "\n'
    out += 'ERROR@68:106 "unexpected line terminator" "my store }]\n '
    out += ' }) {\n    name(locale: "\nNAME@106:108 "en"\nERROR@108:1'
    out += '16 "unterminated string value" ")\n  }\n}\nEOF@116:116\n'
    return out^


def _path_7() -> String:
    var out = String()
    out += "lexer_err/0008_unterminated_string_value.graphql"
    return out^


def _input_7() -> String:
    var out = String()
    out += 'mutation {\n  createstore {\n    name(locale: "en)\n  }\n}'
    return out^


def _expected_7() -> String:
    var out = String()
    out += 'NAME@0:8 "mutation"\nWHITESPACE@8:9 " "\nL_CURLY@9:10 "'
    out += '{"\nWHITESPACE@10:13 "\\n  "\nNAME@13:24 "createstore"'
    out += '\nWHITESPACE@24:25 " "\nL_CURLY@25:26 "{"\nWHITESPACE@26'
    out += ':31 "\\n    "\nNAME@31:35 "name"\nL_PAREN@35:36 "("\nN'
    out += 'AME@36:42 "locale"\nCOLON@42:43 ":"\nWHITESPACE@43:44 "'
    out += ' "\nERROR@44:54 "unterminated string value" "en)\n  }\n}'
    out += "\nEOF@54:54\n"
    return out^


def _path_8() -> String:
    var out = String()
    out += "lexer_err/0009_unterminated_string_value_as_default.graphql"
    return out^


def _input_8() -> String:
    var out = String()
    out += 'type Person {\n  name: String\n  picture(url: String = "htt'
    out += "ps://spec.graphql.org/October2021/#DefaultValue): Url\n}"
    return out^


def _expected_8() -> String:
    var out = String()
    out += 'NAME@0:4 "type"\nWHITESPACE@4:5 " "\nNAME@5:11 "Person'
    out += '"\nWHITESPACE@11:12 " "\nL_CURLY@12:13 "{"\nWHITESPACE@'
    out += '13:16 "\\n  "\nNAME@16:20 "name"\nCOLON@20:21 ":"\nWHI'
    out += 'TESPACE@21:22 " "\nNAME@22:28 "String"\nWHITESPACE@28:31'
    out += ' "\\n  "\nNAME@31:38 "picture"\nL_PAREN@38:39 "("\nNAM'
    out += 'E@39:42 "url"\nCOLON@42:43 ":"\nWHITESPACE@43:44 " "\n'
    out += 'NAME@44:50 "String"\nWHITESPACE@50:51 " "\nEQ@51:52 "='
    out += '"\nWHITESPACE@52:53 " "\nERROR@53:112 "unterminated stri'
    out += 'ng value" "https://spec.graphql.org/October2021/#DefaultVa'
    out += "lue): Url\n}\nEOF@112:112\n"
    return out^


def _path_9() -> String:
    var out = String()
    out += "lexer_err/0010_unterminated_string_value_with_unicode.graphq"
    out += "l"
    return out^


def _input_9() -> String:
    var out = String()
    out += '"hello✨'
    return out^


def _expected_9() -> String:
    var out = String()
    out += 'ERROR@0:9 "unterminated string value" "hello✨\nEOF@9:9'
    out += "\n"
    return out^


def _path_10() -> String:
    var out = String()
    out += "lexer_err/0011_unterminated_string_value_with_unicode_and_es"
    out += "caped_characters.graphql"
    return out^


def _input_10() -> String:
    var out = String()
    out += '"\\n\\n\\\\u{c}\\nPSK\\\\u{1}\\\\0\\\\0\\\\0י'
    return out^


def _expected_10() -> String:
    var out = String()
    out += 'ERROR@0:33 "unterminated string value" "\\n\\n\\\\u{c}\\n'
    out += "PSK\\\\u{1}\\\\0\\\\0\\\\0י\nEOF@33:33\n"
    return out^


def _path_11() -> String:
    var out = String()
    out += "lexer_err/0012_string_value_with_line_terminators.graphql"
    return out^


def _input_11() -> String:
    var out = String()
    out += '"\nhello\n"'
    return out^


def _expected_11() -> String:
    var out = String()
    out += 'ERROR@0:9 "unexpected line terminator" "\nhello\n"\nEOF@'
    out += "9:9\n"
    return out^


def _path_12() -> String:
    var out = String()
    out += "lexer_err/0013_string_with_invalid_escapes.graphql"
    return out^


def _input_12() -> String:
    var out = String()
    out += 'type Query {\n  "This is \\"\\"a test \\a\\d\\q descripti'
    out += 'on"\n  invalidPlainEscape: String\n  "\\u008"\n  incomple'
    out += 'teUnicodeEscape: String\n  "\\uF"\n  incompleteUnicodeEsca'
    out += 'pe2: String\n  "\\uzzzz"\n  invalidUnicodeEscape: String\n'
    out += '  "\\u123k"\n  invalidUnicodeEscape2: String\n  "\\\'"\n '
    out += " invalidEscapeChar: String\n}\n"
    return out^


def _expected_12() -> String:
    var out = String()
    out += 'NAME@0:4 "type"\nWHITESPACE@4:5 " "\nNAME@5:10 "Query"'
    out += '\nWHITESPACE@10:11 " "\nL_CURLY@11:12 "{"\nWHITESPACE@12'
    out += ':15 "\\n  "\nERROR@15:54 "unexpected escaped character" '
    out += '"This is \\"\\"a test \\a\\d\\q description"\nWHITESPACE'
    out += '@54:57 "\\n  "\nNAME@57:75 "invalidPlainEscape"\nCOLON@7'
    out += '5:76 ":"\nWHITESPACE@76:77 " "\nNAME@77:83 "String"\nW'
    out += 'HITESPACE@83:86 "\\n  "\nERROR@86:93 "incomplete unicode '
    out += 'escape sequence" "\\u008"\nWHITESPACE@93:96 "\\n  "\nNA'
    out += 'ME@96:119 "incompleteUnicodeEscape"\nCOLON@119:120 ":"\n'
    out += 'WHITESPACE@120:121 " "\nNAME@121:127 "String"\nWHITESPAC'
    out += 'E@127:130 "\\n  "\nERROR@130:135 "incomplete unicode esca'
    out += 'pe sequence" "\\uF"\nWHITESPACE@135:138 "\\n  "\nNAME@1'
    out += '38:162 "incompleteUnicodeEscape2"\nCOLON@162:163 ":"\nWH'
    out += 'ITESPACE@163:164 " "\nNAME@164:170 "String"\nWHITESPACE@'
    out += '170:173 "\\n  "\nERROR@173:181 "invalid unicode escape se'
    out += 'quence" "\\uzzzz"\nWHITESPACE@181:184 "\\n  "\nNAME@184'
    out += ':204 "invalidUnicodeEscape"\nCOLON@204:205 ":"\nWHITESPA'
    out += 'CE@205:206 " "\nNAME@206:212 "String"\nWHITESPACE@212:21'
    out += '5 "\\n  "\nERROR@215:223 "invalid unicode escape sequence'
    out += '" "\\u123k"\nWHITESPACE@223:226 "\\n  "\nNAME@226:247 '
    out += '"invalidUnicodeEscape2"\nCOLON@247:248 ":"\nWHITESPACE@2'
    out += '48:249 " "\nNAME@249:255 "String"\nWHITESPACE@255:258 "'
    out += '\\n  "\nERROR@258:262 "unexpected escaped character" "\\'
    out += '\'"\nWHITESPACE@262:265 "\\n  "\nNAME@265:282 "invalidEsc'
    out += 'apeChar"\nCOLON@282:283 ":"\nWHITESPACE@283:284 " "\nNA'
    out += 'ME@284:290 "String"\nWHITESPACE@290:291 "\\n"\nR_CURLY@2'
    out += '91:292 "}"\nWHITESPACE@292:293 "\\n"\nEOF@293:293\n'
    return out^


def _path_13() -> String:
    var out = String()
    out += "lexer_err/0014_plus_sign.graphql"
    return out^


def _input_13() -> String:
    var out = String()
    out += "+1, +"
    return out^


def _expected_13() -> String:
    var out = String()
    out += 'ERROR@0:1 "Unexpected character \\"+\\"" +\nINT@1:2 "1'
    out += '"\nCOMMA@2:3 ","\nWHITESPACE@3:4 " "\nERROR@4:5 "Unexp'
    out += 'ected character \\"+\\"" +\nEOF@5:5\n'
    return out^


def _path_14() -> String:
    var out = String()
    out += "lexer_err/0015_minus_sign.graphql"
    return out^


def _input_14() -> String:
    var out = String()
    out += "-1, -"
    return out^


def _expected_14() -> String:
    var out = String()
    out += 'INT@0:2 "-1"\nCOMMA@2:3 ","\nWHITESPACE@3:4 " "\nERROR'
    out += '@4:5 "Unexpected character \\"-\\"" -\nEOF@5:5\n'
    return out^


def _path_15() -> String:
    var out = String()
    out += "lexer_err/0016_leading_zero.graphql"
    return out^


def _input_15() -> String:
    var out = String()
    out += "# No error:\n  0   1   42   1.1   0.2   1e04   1e+04   1e-04"
    out += "\n -0  -1  -42  -1.1  -0.2  -1e04  -1e+04  -1e-04\n# Errors:"
    out += "\n 00  01  042  01.1  00.2  01e04  01e+04  01e-04\n-00 -01 -"
    out += "042 -01.1 -00.2 -01e04 -01e+04 -01e-04\n"
    return out^


def _expected_15() -> String:
    var out = String()
    out += 'COMMENT@0:11 "# No error:"\nWHITESPACE@11:14 "\\n  "\nIN'
    out += 'T@14:15 "0"\nWHITESPACE@15:18 "   "\nINT@18:19 "1"\nWH'
    out += 'ITESPACE@19:22 "   "\nINT@22:24 "42"\nWHITESPACE@24:27 '
    out += '"   "\nFLOAT@27:30 "1.1"\nWHITESPACE@30:33 "   "\nFLOA'
    out += 'T@33:36 "0.2"\nWHITESPACE@36:39 "   "\nFLOAT@39:43 "1e0'
    out += '4"\nWHITESPACE@43:46 "   "\nFLOAT@46:51 "1e+04"\nWHITES'
    out += 'PACE@51:54 "   "\nFLOAT@54:59 "1e-04"\nWHITESPACE@59:61 '
    out += '"\\n "\nINT@61:63 "-0"\nWHITESPACE@63:65 "  "\nINT@65:'
    out += '67 "-1"\nWHITESPACE@67:69 "  "\nINT@69:72 "-42"\nWHITE'
    out += 'SPACE@72:74 "  "\nFLOAT@74:78 "-1.1"\nWHITESPACE@78:80 '
    out += '"  "\nFLOAT@80:84 "-0.2"\nWHITESPACE@84:86 "  "\nFLOAT'
    out += '@86:91 "-1e04"\nWHITESPACE@91:93 "  "\nFLOAT@93:99 "-1e'
    out += '+04"\nWHITESPACE@99:101 "  "\nFLOAT@101:107 "-1e-04"\nW'
    out += 'HITESPACE@107:108 "\\n"\nCOMMENT@108:117 "# Errors:"\nWH'
    out += 'ITESPACE@117:119 "\\n "\nERROR@119:121 "Numbers must not '
    out += 'have non-significant leading zeroes" 00\nWHITESPACE@121:123'
    out += ' "  "\nERROR@123:125 "Numbers must not have non-significa'
    out += 'nt leading zeroes" 01\nWHITESPACE@125:127 "  "\nERROR@127'
    out += ':129 "Numbers must not have non-significant leading zeroes'
    out += '" 04\nINT@129:130 "2"\nWHITESPACE@130:132 "  "\nERROR@1'
    out += '32:134 "Numbers must not have non-significant leading zeroe'
    out += 's" 01\nERROR@134:136 "Unterminated spread operator" .1\nW'
    out += 'HITESPACE@136:138 "  "\nERROR@138:140 "Numbers must not h'
    out += 'ave non-significant leading zeroes" 00\nERROR@140:142 "Unt'
    out += 'erminated spread operator" .2\nWHITESPACE@142:144 "  "\nE'
    out += 'RROR@144:146 "Numbers must not have non-significant leading'
    out += ' zeroes" 01\nNAME@146:149 "e04"\nWHITESPACE@149:151 "  '
    out += '"\nERROR@151:153 "Numbers must not have non-significant le'
    out += 'ading zeroes" 01\nNAME@153:154 "e"\nERROR@154:155 "Unexp'
    out += 'ected character \\"+\\"" +\nERROR@155:157 "Numbers must '
    out += 'not have non-significant leading zeroes" 04\nWHITESPACE@157'
    out += ':159 "  "\nERROR@159:161 "Numbers must not have non-signi'
    out += 'ficant leading zeroes" 01\nNAME@161:162 "e"\nERROR@162:16'
    out += '5 "Numbers must not have non-significant leading zeroes" -'
    out += '04\nWHITESPACE@165:166 "\\n"\nERROR@166:169 "Numbers must'
    out += ' not have non-significant leading zeroes" -00\nWHITESPACE@1'
    out += '69:170 " "\nERROR@170:173 "Numbers must not have non-sign'
    out += 'ificant leading zeroes" -01\nWHITESPACE@173:174 " "\nERRO'
    out += 'R@174:177 "Numbers must not have non-significant leading ze'
    out += 'roes" -04\nINT@177:178 "2"\nWHITESPACE@178:179 " "\nERR'
    out += 'OR@179:182 "Numbers must not have non-significant leading z'
    out += 'eroes" -01\nERROR@182:184 "Unterminated spread operator" '
    out += '.1\nWHITESPACE@184:185 " "\nERROR@185:188 "Numbers must n'
    out += 'ot have non-significant leading zeroes" -00\nERROR@188:190 '
    out += '"Unterminated spread operator" .2\nWHITESPACE@190:191 " '
    out += '"\nERROR@191:194 "Numbers must not have non-significant le'
    out += 'ading zeroes" -01\nNAME@194:197 "e04"\nWHITESPACE@197:198'
    out += ' " "\nERROR@198:201 "Numbers must not have non-significan'
    out += 't leading zeroes" -01\nNAME@201:202 "e"\nERROR@202:203 "'
    out += 'Unexpected character \\"+\\"" +\nERROR@203:205 "Numbers '
    out += 'must not have non-significant leading zeroes" 04\nWHITESPAC'
    out += 'E@205:206 " "\nERROR@206:209 "Numbers must not have non-s'
    out += 'ignificant leading zeroes" -01\nNAME@209:210 "e"\nERROR@2'
    out += '10:213 "Numbers must not have non-significant leading zeroe'
    out += 's" -04\nWHITESPACE@213:214 "\\n"\nEOF@214:214\n'
    return out^


def _path_16() -> String:
    var out = String()
    out += "lexer_err/0017_number_lookahead.graphql"
    return out^


def _input_16() -> String:
    var out = String()
    out += "# Both IntValue and FloatValue are specified with [lookahead"
    out += " != {Digit, `.`, NameStart}]\n00\n2.\n2.2.\n2.2.2\n2e2.\n2e2"
    out += ".2\n2.2e2.\n2.2e2.2\n2_\n2.2_\n2e2_\n2.2e2_\n2x\n2.2x\n2e2x"
    out += "\n2.2e2x\n2e2e\n2e2e2"
    return out^


def _expected_16() -> String:
    var out = String()
    out += 'COMMENT@0:88 "# Both IntValue and FloatValue are specified '
    out += 'with [lookahead != {Digit, `.`, NameStart}]"\nWHITESPACE@88'
    out += ':89 "\\n"\nERROR@89:91 "Numbers must not have non-signifi'
    out += 'cant leading zeroes" 00\nWHITESPACE@91:92 "\\n"\nERROR@92'
    out += ':95 "Unexpected character `\\n`, expected fractional digit'
    out += '" 2.\n\nERROR@95:99 "Unexpected character `.` as float suf'
    out += 'fix" 2.2.\nWHITESPACE@99:100 "\\n"\nERROR@100:104 "Unexp'
    out += 'ected character `.` as float suffix" 2.2.\nINT@104:105 "2'
    out += '"\nWHITESPACE@105:106 "\\n"\nERROR@106:110 "Unexpected c'
    out += 'haracter `.` as float suffix" 2e2.\nWHITESPACE@110:111 "\\'
    out += 'n"\nERROR@111:115 "Unexpected character `.` as float suffi'
    out += 'x" 2e2.\nINT@115:116 "2"\nWHITESPACE@116:117 "\\n"\nERR'
    out += 'OR@117:123 "Unexpected character `.` as float suffix" 2.2e'
    out += '2.\nWHITESPACE@123:124 "\\n"\nERROR@124:130 "Unexpected c'
    out += 'haracter `.` as float suffix" 2.2e2.\nINT@130:131 "2"\nWH'
    out += 'ITESPACE@131:132 "\\n"\nERROR@132:134 "Unexpected charact'
    out += 'er `_` as integer suffix" 2_\nWHITESPACE@134:135 "\\n"\nE'
    out += 'RROR@135:139 "Unexpected character `_` as float suffix" 2.'
    out += '2_\nWHITESPACE@139:140 "\\n"\nERROR@140:144 "Unexpected c'
    out += 'haracter `_` as float suffix" 2e2_\nWHITESPACE@144:145 "\\'
    out += 'n"\nERROR@145:151 "Unexpected character `_` as float suffi'
    out += 'x" 2.2e2_\nWHITESPACE@151:152 "\\n"\nERROR@152:154 "Unex'
    out += 'pected character `x` as integer suffix" 2x\nWHITESPACE@154:'
    out += '155 "\\n"\nERROR@155:159 "Unexpected character `x` as flo'
    out += 'at suffix" 2.2x\nWHITESPACE@159:160 "\\n"\nERROR@160:164 '
    out += '"Unexpected character `x` as float suffix" 2e2x\nWHITESPAC'
    out += 'E@164:165 "\\n"\nERROR@165:171 "Unexpected character `x` '
    out += 'as float suffix" 2.2e2x\nWHITESPACE@171:172 "\\n"\nERROR@'
    out += '172:176 "Unexpected character `e` as float suffix" 2e2e\nW'
    out += 'HITESPACE@176:177 "\\n"\nERROR@177:181 "Unexpected charac'
    out += 'ter `e` as float suffix" 2e2e\nINT@181:182 "2"\nEOF@182:1'
    out += "82\n"
    return out^


def _path_17() -> String:
    var out = String()
    out += "lexer_err/0018_eof_float_1.graphql"
    return out^


def _input_17() -> String:
    var out = String()
    out += "2."
    return out^


def _expected_17() -> String:
    var out = String()
    out += 'ERROR@0:2 "Unexpected EOF in float value" 2.\nEOF@2:2\n'
    return out^


def _path_18() -> String:
    var out = String()
    out += "lexer_err/0019_eof_float_2.graphql"
    return out^


def _input_18() -> String:
    var out = String()
    out += "2e"
    return out^


def _expected_18() -> String:
    var out = String()
    out += 'ERROR@0:2 "Unexpected EOF in float value" 2e\nEOF@2:2\n'
    return out^


def _path_19() -> String:
    var out = String()
    out += "lexer_err/0020_eof_float_3.graphql"
    return out^


def _input_19() -> String:
    var out = String()
    out += "2e-"
    return out^


def _expected_19() -> String:
    var out = String()
    out += 'ERROR@0:3 "Unexpected EOF in float value" 2e-\nEOF@3:3\n'
    return out^


def _path_20() -> String:
    var out = String()
    out += "lexer_err/0021_eof_float_4.graphql"
    return out^


def _input_20() -> String:
    var out = String()
    out += "2e+"
    return out^


def _expected_20() -> String:
    var out = String()
    out += 'ERROR@0:3 "Unexpected EOF in float value" 2e+\nEOF@3:3\n'
    return out^


def _path_21() -> String:
    var out = String()
    out += "lexer_err/0022_eof_string_1.graphql"
    return out^


def _input_21() -> String:
    var out = String()
    out += '"'
    return out^


def _expected_21() -> String:
    var out = String()
    out += 'ERROR@0:1 "unexpected end of data while lexing string value'
    out += '" "\nEOF@1:1\n'
    return out^


def _path_22() -> String:
    var out = String()
    out += "lexer_err/0023_eof_string_1.graphql"
    return out^


def _input_22() -> String:
    var out = String()
    out += '"\\'
    return out^


def _expected_22() -> String:
    var out = String()
    out += 'ERROR@0:2 "unterminated string value" "\\\nEOF@2:2\n'
    return out^


def _path_23() -> String:
    var out = String()
    out += "lexer_err/0024_eof_string_2.graphql"
    return out^


def _input_23() -> String:
    var out = String()
    out += '"\\u'
    return out^


def _expected_23() -> String:
    var out = String()
    out += 'ERROR@0:3 "unterminated string value" "\\u\nEOF@3:3\n'
    return out^


def _path_24() -> String:
    var out = String()
    out += "lexer_err/0025_eof_string_3.graphql"
    return out^


def _input_24() -> String:
    var out = String()
    out += '"\\u222'
    return out^


def _expected_24() -> String:
    var out = String()
    out += 'ERROR@0:6 "unterminated string value" "\\u222\nEOF@6:6\n'
    return out^


def _path_25() -> String:
    var out = String()
    out += "lexer_err/0026_eof_block_string_1.graphql"
    return out^


def _input_25() -> String:
    var out = String()
    out += '"""'
    return out^


def _expected_25() -> String:
    var out = String()
    out += 'ERROR@0:3 "unterminated string value" """\nEOF@3:3\n'
    return out^


def _path_26() -> String:
    var out = String()
    out += "lexer_err/0027_eof_block_string_2.graphql"
    return out^


def _input_26() -> String:
    var out = String()
    out += '"""\\'
    return out^


def _expected_26() -> String:
    var out = String()
    out += 'ERROR@0:4 "unterminated string value" """\\\nEOF@4:4\n'
    return out^


def _path_27() -> String:
    var out = String()
    out += "lexer_err/0029_not_whitespace.graphql"
    return out^


def _input_27() -> String:
    var out = String()
    out += "﻿# U+FEFF\n# U+000B\n# U+000C\n# U+0085\n # U+00A0\n"
    out += "‎# U+200E\n‏# U+200F\n # U+2028\n # U+2029\n"
    return out^


def _expected_27() -> String:
    var out = String()
    out += 'WHITESPACE@0:3 "\\u{feff}"\nCOMMENT@3:11 "# U+FEFF"\nWHI'
    out += 'TESPACE@11:12 "\\n"\nERROR@12:13 "Unexpected character \\'
    out += '"\\u{b}\\"" \nCOMMENT@13:21 "# U+000B"\nWHITESPACE@21:'
    out += '22 "\\n"\nERROR@22:23 "Unexpected character \\"\\u{c}\\'
    out += '"" \nCOMMENT@23:31 "# U+000C"\nWHITESPACE@31:32 "\\n"'
    out += '\nERROR@32:34 "Unexpected character \\"\\u{85}\\"" \nC'
    out += 'OMMENT@34:42 "# U+0085"\nWHITESPACE@42:43 "\\n"\nERROR@4'
    out += '3:45 "Unexpected character \\"\\u{a0}\\""  \nCOMMENT@45'
    out += ':53 "# U+00A0"\nWHITESPACE@53:54 "\\n"\nERROR@54:57 "Un'
    out += 'expected character \\"\\u{200e}\\"" ‎\nCOMMENT@57:65 "'
    out += '# U+200E"\nWHITESPACE@65:66 "\\n"\nERROR@66:69 "Unexpect'
    out += 'ed character \\"\\u{200f}\\"" ‏\nCOMMENT@69:77 "# U+20'
    out += '0F"\nWHITESPACE@77:78 "\\n"\nERROR@78:81 "Unexpected cha'
    out += 'racter \\"\\u{2028}\\""  \nCOMMENT@81:89 "# U+2028"\n'
    out += 'WHITESPACE@89:90 "\\n"\nERROR@90:93 "Unexpected character'
    out += ' \\"\\u{2029}\\""  \nCOMMENT@93:101 "# U+2029"\nWHITE'
    out += 'SPACE@101:102 "\\n"\nEOF@102:102\n'
    return out^


def _path_28() -> String:
    var out = String()
    out += "lexer_err/0030_escaped_surrogate.graphql"
    return out^


def _input_28() -> String:
    var out = String()
    out += "# TODO: move these cases back to ok/0004_string_value.graphq"
    out += "l when\n# https://github.com/apollographql/apollo-rs/issues/"
    out += '657 is implemented\n"string with unicode surrogate pair esc'
    out += 'ape \\uD83D\\uDE00"\n"string with minimal surrogate pair e'
    out += 'scape \\uD800\\uDC00"\n"string with maximal surrogate pair'
    out += ' escape \\uDBFF\\uDFFF"\n\n# TODO: emit two errors: https:/'
    out += '/github.com/apollographql/apollo-rs/issues/319\n"split pair'
    out += ' \\uD83D \\uDE00"\n\n"Backwards pair \\uDE00\\uD83D"\n"L'
    out += 'one lead surrogate \\uD83E"\n"Lone trail surrogate \\uDD80'
    out += '"\n'
    return out^


def _expected_28() -> String:
    var out = String()
    out += 'COMMENT@0:66 "# TODO: move these cases back to ok/0004_stri'
    out += 'ng_value.graphql when"\nWHITESPACE@66:67 "\\n"\nCOMMENT@6'
    out += '7:137 "# https://github.com/apollographql/apollo-rs/issues/'
    out += '657 is implemented"\nWHITESPACE@137:138 "\\n"\nERROR@138:'
    out += '194 "surrogate code point is invalid in unicode escape sequ'
    out += "ence (paired surrogate not supported yet: https://github.com"
    out += '/apollographql/apollo-rs/issues/657)" "string with unicode'
    out += ' surrogate pair escape \\uD83D\\uDE00"\nWHITESPACE@194:195 '
    out += '"\\n"\nERROR@195:251 "surrogate code point is invalid in '
    out += "unicode escape sequence (paired surrogate not supported yet:"
    out += ' https://github.com/apollographql/apollo-rs/issues/657)" "'
    out += 'string with minimal surrogate pair escape \\uD800\\uDC00"\n'
    out += 'WHITESPACE@251:252 "\\n"\nERROR@252:308 "surrogate code p'
    out += "oint is invalid in unicode escape sequence (paired surrogate"
    out += " not supported yet: https://github.com/apollographql/apollo-"
    out += 'rs/issues/657)" "string with maximal surrogate pair escape'
    out += ' \\uDBFF\\uDFFF"\nWHITESPACE@308:310 "\\n\\n"\nCOMMENT@31'
    out += '0:388 "# TODO: emit two errors: https://github.com/apollogr'
    out += 'aphql/apollo-rs/issues/319"\nWHITESPACE@388:389 "\\n"\nER'
    out += 'ROR@389:415 "surrogate code point is invalid in unicode esc'
    out += "ape sequence (paired surrogate not supported yet: https://gi"
    out += 'thub.com/apollographql/apollo-rs/issues/657)" "split pair '
    out += '\\uD83D \\uDE00"\nWHITESPACE@415:417 "\\n\\n"\nERROR@417:'
    out += '446 "surrogate code point is invalid in unicode escape sequ'
    out += "ence (paired surrogate not supported yet: https://github.com"
    out += '/apollographql/apollo-rs/issues/657)" "Backwards pair \\uD'
    out += 'E00\\uD83D"\nWHITESPACE@446:447 "\\n"\nERROR@447:475 "su'
    out += "rrogate code point is invalid in unicode escape sequence (pa"
    out += "ired surrogate not supported yet: https://github.com/apollog"
    out += 'raphql/apollo-rs/issues/657)" "Lone lead surrogate \\uD83E'
    out += '"\nWHITESPACE@475:476 "\\n"\nERROR@476:505 "surrogate co'
    out += "de point is invalid in unicode escape sequence (paired surro"
    out += "gate not supported yet: https://github.com/apollographql/apo"
    out += 'llo-rs/issues/657)" "Lone trail surrogate \\uDD80"\nWHITE'
    out += 'SPACE@505:506 "\\n"\nEOF@506:506\n'
    return out^


def _path_29() -> String:
    var out = String()
    out += "parser_err/0001_directive_definition_missing_location.graphq"
    out += "l"
    return out^


def _input_29() -> String:
    var out = String()
    out += "directive @example on"
    return out^


def _expected_29() -> String:
    var out = String()
    out += '- ERROR@21:21 "expected valid Directive Location" EOF\nrec'
    out += "ursion limit: 500, high: 0\n"
    return out^


def _path_30() -> String:
    var out = String()
    out += "parser_err/0002_enum_definition_with_missing_name.graphql"
    return out^


def _input_30() -> String:
    var out = String()
    out += "enum {\n    NORTH\n    EAST\n    SOUTH\n    WEST\n}"
    return out^


def _expected_30() -> String:
    var out = String()
    out += '- ERROR@5:6 "expected a Name" {\nrecursion limit: 500, hig'
    out += "h: 0\n"
    return out^


def _path_31() -> String:
    var out = String()
    out += "parser_err/0003_enum_definition_with_missing_values.graphql"
    return out^


def _input_31() -> String:
    var out = String()
    out += "enum Direction {\n}"
    return out^


def _expected_31() -> String:
    var out = String()
    out += '- ERROR@17:18 "expected Enum Value Definition" }\nrecursio'
    out += "n limit: 500, high: 0\n"
    return out^


def _path_32() -> String:
    var out = String()
    out += "parser_err/0004_enum_definition_with_missing_curly.graphql"
    return out^


def _input_32() -> String:
    var out = String()
    out += "enum Direction { NORTH WEST"
    return out^


def _expected_32() -> String:
    var out = String()
    out += '- ERROR@27:27 "expected R_CURLY, got EOF" EOF\nrecursion l'
    out += "imit: 500, high: 0\n"
    return out^


def _path_33() -> String:
    var out = String()
    out += "parser_err/0005_enum_extension_with_missing_name.graphql"
    return out^


def _input_33() -> String:
    var out = String()
    out += "extend enum {\n    NORTH\n    EAST\n}"
    return out^


def _expected_33() -> String:
    var out = String()
    out += '- ERROR@12:13 "expected a Name" {\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_34() -> String:
    var out = String()
    out += "parser_err/0006_enum_extension_with_missing_requirements.gra"
    out += "phql"
    return out^


def _input_34() -> String:
    var out = String()
    out += "extend enum Direction"
    return out^


def _expected_34() -> String:
    var out = String()
    out += '- ERROR@21:21 "expected Directive or Enum Values Definition'
    out += '" EOF\nrecursion limit: 500, high: 0\n'
    return out^


def _path_35() -> String:
    var out = String()
    out += "parser_err/0007_fragment_definition_with_invalid_fragment_na"
    out += "me.graphql"
    return out^


def _input_35() -> String:
    var out = String()
    out += "fragment on User @example {\n    id\n}"
    return out^


def _expected_35() -> String:
    var out = String()
    out += "- ERROR@9:11 \"Fragment Name cannot be 'on'\" on\nrecursion "
    out += "limit: 500, high: 1\n"
    return out^


def _path_36() -> String:
    var out = String()
    out += "parser_err/0008_fragment_definition_with_invalid_type_condit"
    out += "ion.graphql"
    return out^


def _input_36() -> String:
    var out = String()
    out += "fragment friendFields User @example {\n    id\n}"
    return out^


def _expected_36() -> String:
    var out = String()
    out += "- ERROR@22:26 \"expected 'on'\" User\nrecursion limit: 500, "
    out += "high: 1\n"
    return out^


def _path_37() -> String:
    var out = String()
    out += "parser_err/0009_fragment_definition_with_invalid_selection_s"
    out += "et.graphql"
    return out^


def _input_37() -> String:
    var out = String()
    out += "fragment friendFields on User"
    return out^


def _expected_37() -> String:
    var out = String()
    out += '- ERROR@29:29 "expected a Selection Set" EOF\nrecursion li'
    out += "mit: 500, high: 0\n"
    return out^


def _path_38() -> String:
    var out = String()
    out += "parser_err/0010_input_definition_with_missing_name.graphql"
    return out^


def _input_38() -> String:
    var out = String()
    out += "input {\n    a: String\n    b: Int!\n}"
    return out^


def _expected_38() -> String:
    var out = String()
    out += '- ERROR@6:7 "expected a Name" {\nrecursion limit: 500, hig'
    out += "h: 0\n"
    return out^


def _path_39() -> String:
    var out = String()
    out += "parser_err/0011_input_definition_with_missing_input_values.g"
    out += "raphql"
    return out^


def _input_39() -> String:
    var out = String()
    out += "input ExampleInputObject {}"
    return out^


def _expected_39() -> String:
    var out = String()
    out += '- ERROR@26:27 "expected an Input Value Definition" }\nrecu'
    out += "rsion limit: 500, high: 0\n"
    return out^


def _path_40() -> String:
    var out = String()
    out += "parser_err/0012_input_extension_with_missing_name.graphql"
    return out^


def _input_40() -> String:
    var out = String()
    out += "extend input {\n    a: String\n}"
    return out^


def _expected_40() -> String:
    var out = String()
    out += '- ERROR@13:14 "expected a Name" {\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_41() -> String:
    var out = String()
    out += "parser_err/0013_input_extension_with_missing_requirements.gr"
    out += "aphql"
    return out^


def _input_41() -> String:
    var out = String()
    out += "extend input ExampleInputObject"
    return out^


def _expected_41() -> String:
    var out = String()
    out += '- ERROR@31:31 "expected Directives or an Input Fields Defin'
    out += 'ition" EOF\nrecursion limit: 500, high: 0\n'
    return out^


def _path_42() -> String:
    var out = String()
    out += "parser_err/0014_interface_extension_with_missing_name.graphq"
    out += "l"
    return out^


def _input_42() -> String:
    var out = String()
    out += "extend interface {\n    value: Int\n}"
    return out^


def _expected_42() -> String:
    var out = String()
    out += '- ERROR@17:18 "expected a Name" {\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_43() -> String:
    var out = String()
    out += "parser_err/0015_interface_extension_with_missing_requirement"
    out += "s.graphql"
    return out^


def _input_43() -> String:
    var out = String()
    out += "extend interface ValuedEntity"
    return out^


def _expected_43() -> String:
    var out = String()
    out += '- ERROR@29:29 "exptected an Implements Interfaces, Directiv'
    out += 'es, or a Fields Definition" EOF\nrecursion limit: 500, high'
    out += ": 0\n"
    return out^


def _path_44() -> String:
    var out = String()
    out += "parser_err/0016_object_type_extension_with_missing_name.grap"
    out += "hql"
    return out^


def _input_44() -> String:
    var out = String()
    out += "extend type {\n    name: String\n    age: Int\n    picture: "
    out += "Url\n}"
    return out^


def _expected_44() -> String:
    var out = String()
    out += '- ERROR@12:13 "expected a Name" {\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_45() -> String:
    var out = String()
    out += "parser_err/0017_object_type_extension_with_missing_requireme"
    out += "nts.graphql"
    return out^


def _input_45() -> String:
    var out = String()
    out += "extend type Person"
    return out^


def _expected_45() -> String:
    var out = String()
    out += '- ERROR@18:18 "expected an Implements Interface, Directives'
    out += ' or a Fields Definition" EOF\nrecursion limit: 500, high: 0'
    out += "\n"
    return out^


def _path_46() -> String:
    var out = String()
    out += "parser_err/0018_scalar_definition_with_missing_name.graphql"
    return out^


def _input_46() -> String:
    var out = String()
    out += "scalar @deprecated"
    return out^


def _expected_46() -> String:
    var out = String()
    out += '- ERROR@7:8 "expected a Name" @\nrecursion limit: 500, hig'
    out += "h: 0\n"
    return out^


def _path_47() -> String:
    var out = String()
    out += "parser_err/0019_scalar_extension_with_missing_name.graphql"
    return out^


def _input_47() -> String:
    var out = String()
    out += "extend scalar @deprecated"
    return out^


def _expected_47() -> String:
    var out = String()
    out += '- ERROR@14:15 "expected a Name" @\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_48() -> String:
    var out = String()
    out += "parser_err/0020_union_definition_with_missing_name.graphql"
    return out^


def _input_48() -> String:
    var out = String()
    out += "union = Photo | Person"
    return out^


def _expected_48() -> String:
    var out = String()
    out += '- ERROR@6:7 "expected a Name" =\nrecursion limit: 500, hig'
    out += "h: 0\n"
    return out^


def _path_49() -> String:
    var out = String()
    out += "parser_err/0021_union_definition_with_missing_union_members."
    out += "graphql"
    return out^


def _input_49() -> String:
    var out = String()
    out += "union ="
    return out^


def _expected_49() -> String:
    var out = String()
    out += '- ERROR@6:7 "expected a Name" =\n- ERROR@7:7 "expected Un'
    out += 'ion Member Type" EOF\nrecursion limit: 500, high: 0\n'
    return out^


def _path_50() -> String:
    var out = String()
    out += "parser_err/0022_union_extension_with_missing_name.graphql"
    return out^


def _input_50() -> String:
    var out = String()
    out += "extend union = Photo | Person"
    return out^


def _expected_50() -> String:
    var out = String()
    out += '- ERROR@13:14 "expected a Name" =\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_51() -> String:
    var out = String()
    out += "parser_err/0023_union_extension_with_missing_requirements.gr"
    out += "aphql"
    return out^


def _input_51() -> String:
    var out = String()
    out += "extend union SearchResult"
    return out^


def _expected_51() -> String:
    var out = String()
    out += '- ERROR@25:25 "expected Directives or Union Member Types" '
    out += "EOF\nrecursion limit: 500, high: 0\n"
    return out^


def _path_52() -> String:
    var out = String()
    out += "parser_err/0024_document_with_incorrect_definition.graphql"
    return out^


def _input_52() -> String:
    var out = String()
    out += "awsas8d2934213hkj0987"
    return out^


def _expected_52() -> String:
    var out = String()
    out += '- ERROR@0:21 "expected definition" awsas8d2934213hkj0987\n'
    out += "recursion limit: 500, high: 0\n"
    return out^


def _path_53() -> String:
    var out = String()
    out += "parser_err/0025_document_with_incorrect_definition_and_selec"
    out += "tion_set.graphql"
    return out^


def _input_53() -> String:
    var out = String()
    out += "uasdf21230jkdw\n\n{\n    pet\n    faveSnack\n}"
    return out^


def _expected_53() -> String:
    var out = String()
    out += '- ERROR@0:14 "expected definition" uasdf21230jkdw\nrecursi'
    out += "on limit: 500, high: 1\n"
    return out^


def _path_54() -> String:
    var out = String()
    out += "parser_err/0026_invalid_definition_squished_between_two_vali"
    out += "d_definitions.graphql"
    return out^


def _input_54() -> String:
    var out = String()
    out += 'enum Direction @example {\n    """\n    description\n    '
    out += '"""\n    NORTH\n    EAST\n    SOUTH\n    WEST\n}\n\nuasdf'
    out += "21230jkdw\n\n{\n    pet\n    faveSnack\n}"
    return out^


def _expected_54() -> String:
    var out = String()
    out += '- ERROR@99:113 "expected definition" uasdf21230jkdw\nrecur'
    out += "sion limit: 500, high: 1\n"
    return out^


def _path_55() -> String:
    var out = String()
    out += "parser_err/0027_invalid_type_system_extension.graphql"
    return out^


def _input_55() -> String:
    var out = String()
    out += "extend Cat"
    return out^


def _expected_55() -> String:
    var out = String()
    out += '- ERROR@0:6 "Invalid Type System Extension. This extension '
    out += 'cannot be applied." extend\n- ERROR@7:10 "expected definit'
    out += 'ion" Cat\nrecursion limit: 500, high: 0\n'
    return out^


def _path_56() -> String:
    var out = String()
    out += "parser_err/0028_invalid_type_system_extension_followed_by_va"
    out += "lid.graphql"
    return out^


def _input_56() -> String:
    var out = String()
    out += "extend Cat\n\nextend interface NamedEntity {\n    name: Stri"
    out += "ng\n}"
    return out^


def _expected_56() -> String:
    var out = String()
    out += '- ERROR@0:6 "Invalid Type System Extension. This extension '
    out += 'cannot be applied." extend\n- ERROR@7:10 "expected definit'
    out += 'ion" Cat\nrecursion limit: 500, high: 0\n'
    return out^


def _path_57() -> String:
    var out = String()
    out += "parser_err/0029_operation_definition_with_empty_selection_se"
    out += "t.graphql"
    return out^


def _input_57() -> String:
    var out = String()
    out += "query {}"
    return out^


def _expected_57() -> String:
    var out = String()
    out += '- ERROR@7:8 "expected at least one Selection in Selection S'
    out += 'et" }\nrecursion limit: 500, high: 1\n'
    return out^


def _path_58() -> String:
    var out = String()
    out += "parser_err/0030_operation_definition_with_description.graphq"
    out += "l"
    return out^


def _input_58() -> String:
    var out = String()
    out += '"after this PR this should not be an issue: https://github.'
    out += 'com/graphql/graphql-spec/pull/892"\nquery empty {}'
    return out^


def _expected_58() -> String:
    var out = String()
    out += '- ERROR@0:93 "expected an Operation Type or a Selection Set'
    out += '" "after this PR this should not be an issue: https://gith'
    out += 'ub.com/graphql/graphql-spec/pull/892"\n- ERROR@107:108 "ex'
    out += 'pected at least one Selection in Selection Set" }\nrecursio'
    out += "n limit: 500, high: 1\n"
    return out^


def _path_59() -> String:
    var out = String()
    out += "parser_err/0031_argument_with_erronous_string_value.graphql"
    return out^


def _input_59() -> String:
    var out = String()
    out += '{\n  user(id: "\\string ID")\n}'
    return out^


def _expected_59() -> String:
    var out = String()
    out += '- ERROR@13:25 "unexpected escaped character" "\\string ID'
    out += '"\n- ERROR@25:26 "expected a valid Value" )\nrecursion li'
    out += "mit: 500, high: 1\n"
    return out^


def _path_60() -> String:
    var out = String()
    out += "parser_err/0032_input_value_with_erronous_string_value.graph"
    out += "ql"
    return out^


def _input_60() -> String:
    var out = String()
    out += 'type Person {\n  name: String\n  picture(reference: "\\a re'
    out += 'ference image"): Url\n}'
    return out^


def _expected_60() -> String:
    var out = String()
    out += '- ERROR@50:70 "unexpected escaped character" "\\a referen'
    out += 'ce image"\n- ERROR@70:71 "expected a Type" )\nrecursion l'
    out += "imit: 500, high: 0\n"
    return out^


def _path_61() -> String:
    var out = String()
    out += "parser_err/0033_directive_with_erronous_string_value.graphql"
    return out^


def _input_61() -> String:
    var out = String()
    out += "directive @delegateField(name: String!) repeatable on OBJECT"
    out += ' | INTERFACE\n\ntype Book @delegateField(name: "\\ errronou'
    out += 's string \\""){\n  id: ID!\n}'
    return out^


def _expected_61() -> String:
    var out = String()
    out += '- ERROR@105:128 "unexpected escaped character" "\\ errron'
    out += 'ous string \\""\n- ERROR@128:129 "expected a valid Value'
    out += '" )\nrecursion limit: 500, high: 0\n'
    return out^


def _path_62() -> String:
    var out = String()
    out += "parser_err/0034_unterminated_string_value_in_list.graphql"
    return out^


def _input_62() -> String:
    var out = String()
    out += 'extend schema\n  @link(url: "https://specs.apollo.dev/feder'
    out += 'ation/v2.0",\n        import: ["@key", "@external])\n\n'
    out += '\ntype Vehicle @key(fields: "id") {\n  id: ID!,\n  type: S'
    out += "tring,\n  modelCode: String,\n  brandName: String,\n  launch"
    out += "Date: String\n}\n"
    return out^


def _expected_62() -> String:
    var out = String()
    out += '- ERROR@96:138 "unexpected line terminator" "@external])'
    out += '\n\n\ntype Vehicle @key(fields: "\n- ERROR@140:237 "unterm'
    out += 'inated string value" ") {\n  id: ID!,\n  type: String,\n  '
    out += "modelCode: String,\n  brandName: String,\n  launchDate: Stri"
    out += 'ng\n}\n\n- ERROR@237:237 "expected R_PAREN, got EOF" EOF\n'
    out += "recursion limit: 500, high: 1\n"
    return out^


def _path_63() -> String:
    var out = String()
    out += "parser_err/0035_unterminated_string_value_in_object_value.gr"
    out += "aphql"
    return out^


def _input_63() -> String:
    var out = String()
    out += 'mutation {\n  createStore(draft: {\n    name: [{ locale: "e'
    out += 'n", value: "my store }]\n  }) {\n    name(locale: "en")'
    out += "\n  }\n}"
    return out^


def _expected_63() -> String:
    var out = String()
    out += '- ERROR@68:106 "unexpected line terminator" "my store }]'
    out += '\n  }) {\n    name(locale: "\n- ERROR@108:116 "unterminate'
    out += 'd string value" ")\n  }\n}\n- ERROR@116:116 "expected R_C'
    out += 'URLY, got EOF" EOF\n- ERROR@116:116 "expected R_CURLY, got'
    out += ' EOF" EOF\n- ERROR@116:116 "expected R_PAREN, got EOF" EO'
    out += 'F\n- ERROR@116:116 "expected R_CURLY, got EOF" EOF\nrecurs'
    out += "ion limit: 500, high: 4\n"
    return out^


def _path_64() -> String:
    var out = String()
    out += "parser_err/0036_unterminated_string_in_default_value.graphql"
    return out^


def _input_64() -> String:
    var out = String()
    out += 'type Person {\n  name: String\n  picture(url: String = "htt'
    out += "ps://spec.graphql.org/October2021/#DefaultValue): Url\n}"
    return out^


def _expected_64() -> String:
    var out = String()
    out += '- ERROR@53:112 "unterminated string value" "https://spec.'
    out += "graphql.org/October2021/#DefaultValue): Url\n}\n- ERROR@112:"
    out += '112 "expected a valid Value" EOF\n- ERROR@112:112 "expect'
    out += 'ed R_PAREN, got EOF" EOF\n- ERROR@112:112 "expected a type'
    out += '" EOF\n- ERROR@112:112 "expected R_CURLY, got EOF" EOF\nr'
    out += "ecursion limit: 500, high: 0\n"
    return out^


def _path_65() -> String:
    var out = String()
    out += "parser_err/0040_operation_definition_missing_selection_set.g"
    out += "raphql"
    return out^


def _input_65() -> String:
    var out = String()
    out += "query __typename }"
    return out^


def _expected_65() -> String:
    var out = String()
    out += '- ERROR@17:18 "expected a Selection Set" }\nrecursion limi'
    out += "t: 500, high: 0\n"
    return out^


def _path_66() -> String:
    var out = String()
    out += "parser_err/0041_operation_definition_with_missing_selection_"
    out += "set.graphql"
    return out^


def _input_66() -> String:
    var out = String()
    out += "query __typename"
    return out^


def _expected_66() -> String:
    var out = String()
    out += '- ERROR@16:16 "expected a Selection Set" EOF\nrecursion li'
    out += "mit: 500, high: 0\n"
    return out^


def _path_67() -> String:
    var out = String()
    out += "parser_err/0042_document_with_incorrect_token.graphql"
    return out^


def _input_67() -> String:
    var out = String()
    out += "@\n# comment\n{\n    pet\n    faveSnack\n}\n\n# comment\n}\n"
    out += "\ntype Query {\n    name: String\n}"
    return out^


def _expected_67() -> String:
    var out = String()
    out += '- ERROR@0:1 "expected a StringValue, Name or OperationDefin'
    out += 'ition" @\n- ERROR@49:50 "expected a StringValue, Name or O'
    out += 'perationDefinition" }\nrecursion limit: 500, high: 1\n'
    return out^


def _path_68() -> String:
    var out = String()
    out += "parser_err/0043_type_with_trailing_garbage.graphql"
    return out^


def _input_68() -> String:
    var out = String()
    out += "type Person {\n  id: ID!\n  appearedIn: [Film]s\n  name: Str"
    out += "ing\n  directed: [Film]\n}\n"
    return out^


def _expected_68() -> String:
    var out = String()
    out += '- ERROR@48:52 "expected a type" name\nrecursion limit: 500'
    out += ", high: 1\n"
    return out^


def _path_69() -> String:
    var out = String()
    out += "parser_err/0044_list_type_with_no_type.graphql"
    return out^


def _input_69() -> String:
    var out = String()
    out += "type List {\n  field: [] @coolDirective\n  deepError: [[[Ite"
    out += "m Type]]]\n}\n"
    return out^


def _expected_69() -> String:
    var out = String()
    out += '- ERROR@22:23 "expected item type" ]\n- ERROR@23:24 "expe'
    out += 'cted R_BRACK, got  "  \n- ERROR@60:64 "expected R_BRACK, g'
    out += 'ot Type" Type\n- ERROR@60:64 "expected R_BRACK, got Type"'
    out += ' Type\n- ERROR@60:64 "expected R_BRACK, got Type" Type\n- '
    out += 'ERROR@64:65 "expected a type" ]\n- ERROR@64:65 "expected '
    out += 'R_CURLY, got ]" ]\n- ERROR@64:65 "expected a StringValue, '
    out += 'Name or OperationDefinition" ]\n- ERROR@65:66 "expected a '
    out += 'StringValue, Name or OperationDefinition" ]\n- ERROR@66:67 '
    out += '"expected a StringValue, Name or OperationDefinition" ]\n-'
    out += ' ERROR@68:69 "expected a StringValue, Name or OperationDefi'
    out += 'nition" }\nrecursion limit: 500, high: 3\n'
    return out^


def _path_70() -> String:
    var out = String()
    out += "parser_err/0045_ignored_token_spans.graphql"
    return out^


def _input_70() -> String:
    var out = String()
    out += "cats\n# https://github.com/apollographql/apollo-rs/issues/32"
    out += "5\n\ninterface X\n\ncats\ntype Query {\n    name: String\n}"
    out += "\n"
    return out^


def _expected_70() -> String:
    var out = String()
    out += '- ERROR@0:4 "expected definition" cats\n- ERROR@75:79 "ex'
    out += 'pected definition" cats\nrecursion limit: 500, high: 0\n'
    return out^


def _path_71() -> String:
    var out = String()
    out += "parser_err/0046_incomplete_spreads.graphql"
    return out^


def _input_71() -> String:
    var out = String()
    out += "{ inner { ... }}\n"
    return out^


def _expected_71() -> String:
    var out = String()
    out += '- ERROR@10:13 "expected an Inline Fragment or a Fragment Sp'
    out += 'read" ...\nrecursion limit: 500, high: 2\n'
    return out^


def _path_72() -> String:
    var out = String()
    out += "parser_err/0047_empty_variable_definition.graphql"
    return out^


def _input_72() -> String:
    var out = String()
    out += "query Op() {\n  field\n}"
    return out^


def _expected_72() -> String:
    var out = String()
    out += '- ERROR@9:10 "expected a Variable Definition" )\nrecursion'
    out += " limit: 500, high: 1\n"
    return out^


def _path_73() -> String:
    var out = String()
    out += "parser_err/0048_unbalanced_list_type_1.graphql"
    return out^


def _input_73() -> String:
    var out = String()
    out += "type Query {\n    unbalanced: [[Int]]]\n}\n"
    return out^


def _expected_73() -> String:
    var out = String()
    out += '- ERROR@36:37 "expected R_CURLY, got ]" ]\n- ERROR@36:37 '
    out += '"expected a StringValue, Name or OperationDefinition" ]\n-'
    out += ' ERROR@38:39 "expected a StringValue, Name or OperationDefi'
    out += 'nition" }\nrecursion limit: 500, high: 2\n'
    return out^


def _path_74() -> String:
    var out = String()
    out += "parser_err/0049_unbalanced_list_type_2.graphql"
    return out^


def _input_74() -> String:
    var out = String()
    out += "type Query {\n    unbalanced: [[[Int]]\n}\n"
    return out^


def _expected_74() -> String:
    var out = String()
    out += '- ERROR@38:39 "expected R_BRACK, got }" }\nrecursion limit'
    out += ": 500, high: 3\n"
    return out^


def _path_75() -> String:
    var out = String()
    out += "parser_err/0050_invalid_implements_list.graphql"
    return out^


def _input_75() -> String:
    var out = String()
    out += "type Obj implements A & { field: Int }\n\ntype Obj implement"
    out += "s A B { field: Int }\n\ntype Obj implements A && B { field: "
    out += "Int }\n"
    return out^


def _expected_75() -> String:
    var out = String()
    out += '- ERROR@24:25 "expected an Interface name" {\n- ERROR@62:6'
    out += '3 "expected definition" B\n- ERROR@103:104 "expected an I'
    out += 'nterface name" &\nrecursion limit: 500, high: 1\n'
    return out^


def _path_76() -> String:
    var out = String()
    out += "parser_err/0051_union_with_invalid_members_list.graphql"
    return out^


def _input_76() -> String:
    var out = String()
    out += '"Missing separator"\nunion SearchResult = Photo Person\n\n'
    out += '"Double separator"\nunion SearchResult2 = Photo || Person'
    out += '\n\n"Dangling separator"\nunion SearchResult3 = | Photo | '
    out += "Person |\n"
    return out^


def _expected_76() -> String:
    var out = String()
    out += '- ERROR@47:53 "expected definition" Person\n- ERROR@103:10'
    out += '4 "expected Union Member Type" |\n- ERROR@175:175 "expect'
    out += 'ed Union Member Type" EOF\nrecursion limit: 500, high: 0\n'
    return out^


def _path_77() -> String:
    var out = String()
    out += "parser_err/0052_const_value.graphql"
    return out^


def _input_77() -> String:
    var out = String()
    out += "query(\n    $var1: Boolean!\n    $var2: Boolean! = $var\n) {"
    out += "\n    f1 @include(if: $var1)\n    f2 @include(if: $var2)\n}"
    out += "\n\ndirective @someDir(arg: Boolean) on OBJECT\n\ntype Query"
    out += " @someDir(arg: $var1) {\n    f1: Int\n    f2: Int\n}\n"
    return out^


def _expected_77() -> String:
    var out = String()
    out += '- ERROR@49:50 "unexpected variable value in a Const context'
    out += '" $\n- ERROR@184:185 "unexpected variable value in a Const'
    out += ' context" $\nrecursion limit: 500, high: 1\n'
    return out^


def _path_78() -> String:
    var out = String()
    out += "parser_err/0053_on_without_type_condition.graphql"
    return out^


def _input_78() -> String:
    var out = String()
    out += "query {\n  ... on {\n    field\n  }\n}\n\nfragment F on {\n "
    out += " field\n}\n"
    return out^


def _expected_78() -> String:
    var out = String()
    out += '- ERROR@17:18 "expected a Name in Type Condition" {\n- ERR'
    out += 'OR@50:51 "expected a Name in Type Condition" {\nrecursion '
    out += "limit: 500, high: 2\n"
    return out^


def _path_79() -> String:
    var out = String()
    out += "parser_err/0054_root_operation_type_with_extra_brackets.grap"
    out += "hql"
    return out^


def _input_79() -> String:
    var out = String()
    out += "schema {\n  query: Query\n  { mutation: Mutation\n  { subscr"
    out += "iption: Subscription\n}\n"
    return out^


def _expected_79() -> String:
    var out = String()
    out += '- ERROR@26:27 "expected R_CURLY, got {" {\n- ERROR@80:80 '
    out += '"expected R_CURLY, got EOF" EOF\nrecursion limit: 500, hig'
    out += "h: 2\n"
    return out^


def _path_80() -> String:
    var out = String()
    out += "parser_err/0055_object_definition_with_missing_name.graphql"
    return out^


def _input_80() -> String:
    var out = String()
    out += "type  {\n  id: String\n}"
    return out^


def _expected_80() -> String:
    var out = String()
    out += '- ERROR@6:7 "expected a name" {\nrecursion limit: 500, hig'
    out += "h: 0\n"
    return out^


def _path_81() -> String:
    var out = String()
    out += "parser_err/0056_object_definition_with_missing_curly.graphql"
    return out^


def _input_81() -> String:
    var out = String()
    out += "type Person { id: String"
    return out^


def _expected_81() -> String:
    var out = String()
    out += '- ERROR@24:24 "expected R_CURLY, got EOF" EOF\nrecursion l'
    out += "imit: 500, high: 0\n"
    return out^


def _path_82() -> String:
    var out = String()
    out += "parser_err/0057_object_definition_with_missing_fields.graphq"
    out += "l"
    return out^


def _input_82() -> String:
    var out = String()
    out += "type Person {\n}"
    return out^


def _expected_82() -> String:
    var out = String()
    out += '- ERROR@14:15 "expected Field Definition" }\nrecursion lim'
    out += "it: 500, high: 0\n"
    return out^


def _path_83() -> String:
    var out = String()
    out += "parser_err/0058_interface_definition_with_missing_name.graph"
    out += "ql"
    return out^


def _input_83() -> String:
    var out = String()
    out += "interface {\n  id: String\n}"
    return out^


def _expected_83() -> String:
    var out = String()
    out += '- ERROR@10:11 "expected a Name" {\nrecursion limit: 500, h'
    out += "igh: 0\n"
    return out^


def _path_84() -> String:
    var out = String()
    out += "parser_err/0059_interface_definition_with_missing_fields.gra"
    out += "phql"
    return out^


def _input_84() -> String:
    var out = String()
    out += "interface Person {\n}"
    return out^


def _expected_84() -> String:
    var out = String()
    out += '- ERROR@19:20 "expected Field Definition" }\nrecursion lim'
    out += "it: 500, high: 0\n"
    return out^


def _path_85() -> String:
    var out = String()
    out += "parser_err/0060_interface_definition_with_missing_curly.grap"
    out += "hql"
    return out^


def _input_85() -> String:
    var out = String()
    out += "interface Person { id: String"
    return out^


def _expected_85() -> String:
    var out = String()
    out += '- ERROR@29:29 "expected R_CURLY, got EOF" EOF\nrecursion l'
    out += "imit: 500, high: 0\n"
    return out^


def _path_86() -> String:
    var out = String()
    out += "parser_err/0061_empty.graphql"
    return out^


def _input_86() -> String:
    var out = String()
    return out^


def _expected_86() -> String:
    var out = String()
    out += '- ERROR@0:0 "Unexpected <EOF>." EOF\nrecursion limit: 500,'
    out += " high: 0\n"
    return out^


def _path_87() -> String:
    var out = String()
    out += "parser_err/0062_multibyte_japanese_in_type_name.graphql"
    return out^


def _input_87() -> String:
    var out = String()
    out += "type Query { field: 日本語 }\n"
    return out^


def _expected_87() -> String:
    var out = String()
    out += '- ERROR@20:23 "Unexpected character \\"日\\"" 日\n- ER'
    out += 'ROR@23:26 "Unexpected character \\"本\\"" 本\n- ERROR@'
    out += '26:29 "Unexpected character \\"語\\"" 語\n- ERROR@30:3'
    out += '1 "expected a Type" }\nrecursion limit: 500, high: 0\n'
    return out^


def _path_88() -> String:
    var out = String()
    out += "parser_err/0063_multibyte_chinese_in_type_name.graphql"
    return out^


def _input_88() -> String:
    var out = String()
    out += "type Query { field: 中文类型 }\n"
    return out^


def _expected_88() -> String:
    var out = String()
    out += '- ERROR@20:23 "Unexpected character \\"中\\"" 中\n- ER'
    out += 'ROR@23:26 "Unexpected character \\"文\\"" 文\n- ERROR@'
    out += '26:29 "Unexpected character \\"类\\"" 类\n- ERROR@29:3'
    out += '2 "Unexpected character \\"型\\"" 型\n- ERROR@33:34 "'
    out += 'expected a Type" }\nrecursion limit: 500, high: 0\n'
    return out^


def _path_89() -> String:
    var out = String()
    out += "parser_err/0064_multibyte_korean_in_type_name.graphql"
    return out^


def _input_89() -> String:
    var out = String()
    out += "type Query { field: 한글타입 }\n"
    return out^


def _expected_89() -> String:
    var out = String()
    out += '- ERROR@20:23 "Unexpected character \\"한\\"" 한\n- ER'
    out += 'ROR@23:26 "Unexpected character \\"글\\"" 글\n- ERROR@'
    out += '26:29 "Unexpected character \\"타\\"" 타\n- ERROR@29:3'
    out += '2 "Unexpected character \\"입\\"" 입\n- ERROR@33:34 "'
    out += 'expected a Type" }\nrecursion limit: 500, high: 0\n'
    return out^


def _path_90() -> String:
    var out = String()
    out += "parser_err/0065_multibyte_emoji_in_type_name.graphql"
    return out^


def _input_90() -> String:
    var out = String()
    out += "type Query { field: 🦀🚀💡 }\n"
    return out^


def _expected_90() -> String:
    var out = String()
    out += '- ERROR@20:24 "Unexpected character \\"🦀\\"" 🦀\n- '
    out += 'ERROR@24:28 "Unexpected character \\"🚀\\"" 🚀\n- ER'
    out += 'ROR@28:32 "Unexpected character \\"💡\\"" 💡\n- ERRO'
    out += 'R@33:34 "expected a Type" }\nrecursion limit: 500, high: 0'
    out += "\n"
    return out^


def _path_91() -> String:
    var out = String()
    out += "parser_err/0066_multibyte_mixed_ascii_and_cjk.graphql"
    return out^


def _input_91() -> String:
    var out = String()
    out += "type Query { field: Type日本語Name }\n"
    return out^


def _expected_91() -> String:
    var out = String()
    out += '- ERROR@24:27 "Unexpected character \\"日\\"" 日\n- ER'
    out += 'ROR@27:30 "Unexpected character \\"本\\"" 本\n- ERROR@'
    out += '30:33 "Unexpected character \\"語\\"" 語\n- ERROR@38:3'
    out += '9 "expected a type" }\nrecursion limit: 500, high: 0\n'
    return out^


def _path_92() -> String:
    var out = String()
    out += "parser_err/0067_multibyte_multiple_fields_with_errors.graphq"
    out += "l"
    return out^


def _input_92() -> String:
    var out = String()
    out += "type Query { a: 日本語 b: 中文 c: String }\n"
    return out^


def _expected_92() -> String:
    var out = String()
    out += '- ERROR@16:19 "Unexpected character \\"日\\"" 日\n- ER'
    out += 'ROR@19:22 "Unexpected character \\"本\\"" 本\n- ERROR@'
    out += '22:25 "Unexpected character \\"語\\"" 語\n- ERROR@27:2'
    out += '8 "expected R_CURLY, got :" :\n- ERROR@27:28 "expected a '
    out += 'StringValue, Name or OperationDefinition" :\n- ERROR@29:32 '
    out += '"Unexpected character \\"中\\"" 中\n- ERROR@32:35 "Un'
    out += 'expected character \\"文\\"" 文\n- ERROR@36:37 "expect'
    out += 'ed definition" c\n- ERROR@37:38 "expected a StringValue, N'
    out += 'ame or OperationDefinition" :\n- ERROR@39:45 "expected def'
    out += 'inition" String\n- ERROR@46:47 "expected a StringValue, Na'
    out += 'me or OperationDefinition" }\nrecursion limit: 500, high: 0'
    out += "\n"
    return out^


def parser_cases() -> List[String]:
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
    return out^


def parser_input(index: Int) -> String:
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
    return ""


def parser_expected(index: Int) -> String:
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
    return ""
