# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""Port of Hive Federation Composition v0.27.0 `__tests__/context.spec.ts`.

Each test is one upstream test, for the Guild implementation. Each check is
the input of one `composeServices` call in it.
The expected errors are those of the subgraph phase of upstream
`validate` in Node.js on the same subgraphs, printed by graphql-js.
"""

from _harness import check, sg
from std.testing import TestSuite


def test_v2_0_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.0 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.0", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@authenticated".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_1_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.1 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.1", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@authenticated".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_2_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.2 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.2", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@authenticated".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@interfaceObject".'
            ),
        ],
    )


def test_v2_3_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.3 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@authenticated".'
            ),
        ],
    )


def test_v2_4_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.4 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.4", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@authenticated".'
            ),
        ],
    )


def test_v2_5_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.5 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.5", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
        ],
    )


def test_v2_6_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.6 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.6", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
        ],
    )


def test_v2_7_rejects_the_context_directives_before_federation_2_8() raises:
    # v2.7 > rejects the context directives before federation 2.8
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.7", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  segment:'
                    " String!\n}\n\ntype Query {\n  customer(id: ID!):"
                    " Customer\n}"
                ),
            ),
        ],
        [
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@context".'
            ),
            (
                "[INVALID_LINK_DIRECTIVE_USAGE] [orders] Cannot import unknown"
                ' element "@fromContext".'
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_the_context_name_rejects_an_empty_context() raises:
    # v2.8 > @context and @fromContext location > the context name > rejects an empty context name
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "") {\n  id: ID!\n}\n\ntype Query {\n '
                    " account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [accounts] Context name "" is invalid.'
                " It should have only alphanumeric characters."
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_the_context_name_rejects_a_context_name_th() raises:
    # v2.8 > @context and @fromContext location > the context name > rejects a context name that has an underscore
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "bad_name") {\n  id: ID!\n}\n\ntype Query'
                    " {\n  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [accounts] Context name "bad_name" is'
                " invalid. It should have only alphanumeric characters."
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_argument_rejects_fromcontext_on_argument_t() raises:
    # v2.8 > @context and @fromContext location > argument > rejects @fromContext on argument that has a default value
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "accountCtx") {\n  id: ID!\n  locale:'
                    ' String!\n}\n\ntype Formatter @key(fields: "id") {\n  id:'
                    ' ID!\n  format(locale: String = "en-US"'
                    ' @fromContext(field: "$accountCtx { locale }")):'
                    " Float!\n}\n\ntype Query {\n  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext arguments may not"
                ' have a default value: "Formatter.format(locale:)".'
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_argument_rejects_fromcontext_on_the_argume() raises:
    # v2.8 > @context and @fromContext location > argument > rejects @fromContext on the argument of a directive
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ndirective @tenant(locale: String'
                    ' @fromContext(field: "$accountCtx { locale }")) on'
                    ' FIELD_DEFINITION\n\ntype Account @key(fields: "id")'
                    ' @context(name: "accountCtx") {\n  id: ID!\n  locale:'
                    " String!\n}\n\ntype Query {\n  account(id: ID!):"
                    " Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                ' used on a directive definition "@tenant(locale:)".'
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_argument_rejects_fromcontext_if_the_parent() raises:
    # v2.8 > @context and @fromContext location > argument > rejects @fromContext if the parent type is abstract
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n  trip(v: Float"
                    ' @fromContext(field: "$meterCtx { voltage }")):'
                    " Boolean!\n}\n\ntype Sensor implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  voltage: Float!\n '
                    " trip(v: Float): Boolean!\n}\n\ntype Query {\n  device:"
                    " MeteredDevice\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [devices] @fromContext argument cannot be"
                " used on a field that exists on an abstract type"
                ' "MeteredDevice.trip(v:)".'
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_argument_rejects_fromcontext_on_a_field_th() raises:
    # v2.8 > @context and @fromContext location > argument > rejects @fromContext on a field that implements an interface field
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Renderable {\n  id:'
                    " ID!\n  render(locale: String): Float!\n}\n\ntype Account"
                    ' @key(fields: "id") @context(name: "accountCtx") {\n  id:'
                    " ID!\n  locale: String!\n}\n\ntype Formatter implements"
                    ' Renderable @key(fields: "id") {\n  id: ID!\n '
                    ' render(locale: String @fromContext(field: "$accountCtx {'
                    ' locale }")): Float!\n}\n\ntype Query {\n  account(id:'
                    " ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                " used on a field implementing an interface field"
                ' "Renderable.render".'
            ),
        ],
    )


def test_v2_8_context_and_fromcontext_location_argument_rejects_fromcontext_on_an_impleme() raises:
    # v2.8 > @context and @fromContext location > argument > rejects @fromContext on an implementation if the interface field has no argument
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Renderable {\n  id:'
                    " ID!\n  render: Boolean!\n}\n\ntype Account @key(fields:"
                    ' "id") @context(name: "accountCtx") {\n  id: ID!\n '
                    " locale: String!\n  formatter: Formatter!\n}\n\ntype"
                    ' Formatter implements Renderable @key(fields: "id") {\n '
                    " id: ID!\n  render(locale: String @fromContext(field:"
                    ' "$accountCtx { locale }")): Boolean!\n}\n\ntype Query {\n'
                    "  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                " used on a field implementing an interface field"
                ' "Renderable.render".'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_rejects_a_selected_fiel() raises:
    # v2.8 > invalid references and unsupported selection syntax > rejects a selected field that the provider type does not have
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "$invoiceCtx { amount }")): Float!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid for type Invoice. Error: Cannot query field"
                ' "amount" on type "Invoice".'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects two sibling fields inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' amount }")): Boolean!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: multiple selections are made"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_2() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a field alias inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { value:'
                    ' reference }")): Boolean!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: aliases are not allowed in the selection"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_3() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a query directive inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' @skip(if: true) }")): Boolean!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: directives are not allowed in the selection"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_4() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects unsupported syntax before reporting multiple selections inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' amount @skip(if: true) }")): Boolean!\n}\n\ntype Query'
                    " {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: directives are not allowed in the selection"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_5() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects fragment spreads inside a @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "$invoiceCtx { ...InvoiceFragment }")): Int!\n}\n\ntype'
                    " Query {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: fragment spread is not allowed"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_6() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects @fromContext that mixes fields and inline fragments
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource ='
                    ' Sensor\n\ntype Sensor @key(fields: "id") @context(name:'
                    ' "deviceCtx") {\n  id: ID!\n  model: String!\n}\n\ntype'
                    ' Diagnostics @key(fields: "id") {\n  id: ID!\n '
                    ' inspect(model: String @fromContext(field: "$deviceCtx {'
                    ' ... on Sensor { model } model }")): Int!\n}\n\ntype Query'
                    " {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: multiple fields could be selected"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_7() raises:
    # v2.8 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a field with an inline fragment in @fromContext
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource ='
                    ' Sensor\n\ntype Sensor @key(fields: "id") @context(name:'
                    ' "deviceCtx") {\n  id: ID!\n  model: String!\n}\n\ntype'
                    ' Diagnostics @key(fields: "id") {\n  id: ID!\n '
                    ' inspect(model: String @fromContext(field: "$deviceCtx {'
                    ' model ... on Sensor { model } }")): Int!\n}\n\ntype Query'
                    " {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: multiple selections are made"
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_the_context_reference_r() raises:
    # v2.8 > invalid references and unsupported selection syntax > the context reference > rejects a @fromContext that starts with a selection
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    ' id: ID!\n  audit(reference: String @fromContext(field: "{'
                    ' reference }")): Int!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [invoices] @fromContext argument"
                ' does not reference a context "{ reference }".'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_the_context_reference_r_2() raises:
    # v2.8 > invalid references and unsupported selection syntax > the context reference > rejects @fromContext when there's no @context
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  reference: String!\n  audit(reference:"
                    ' String @fromContext(field: "$invoiceCtx { reference }")):'
                    " Float!\n}\n\ntype Query {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [invoices] Context "invoiceCtx" is used at'
                ' location "Invoice.audit(reference:)" but is never set.'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_the_context_reference_r_3() raises:
    # v2.8 > invalid references and unsupported selection syntax > the context reference > rejects a @fromContext that is only a field name
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "reference")): Int!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [invoices] @fromContext argument"
                ' does not reference a context "reference".'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects() raises:
    # v2.8 > invalid references and unsupported selection syntax > type conditions > rejects interface type conditions in inline fragments
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Meter {\n  id: ID!\n '
                    " voltage: Float!\n}\n\ntype Sensor implements Meter"
                    ' @key(fields: "id") @context(name: "deviceCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n}\n\ntype Diagnostics"
                    ' @key(fields: "id") {\n  id: ID!\n  inspect(voltage: Float'
                    ' @fromContext(field: "$deviceCtx { ... on Meter { voltage'
                    ' } }")): Int!\n}\n\ntype Query {\n  sensor: Sensor\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(voltage:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects_2() raises:
    # v2.8 > invalid references and unsupported selection syntax > type conditions > rejects a type condition that the selection does not use
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Controller {'
                    ' model } ... on Camera { model } }")): Int!\n}\n\ntype'
                    " Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: type condition "Camera" is never used.'
            ),
        ],
    )


def test_v2_8_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects_3() raises:
    # v2.8 > invalid references and unsupported selection syntax > type conditions > rejects an inline fragment branch that is not a runtime type
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Controller {'
                    ' model } ... on Gateway { model } }")): Int!\n}\n\ntype'
                    " Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: type condition "Gateway" is never used.'
            ),
        ],
    )


def test_v2_8_selected_context_values_concrete_providers_accepts_equivalent_selections_fr() raises:
    # v2.8 > selected context values > concrete providers > accepts equivalent selections from multiple concrete providers
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | CorporateAccount |"
                    " GuestQuote\n\ntype GuestQuote {\n  id: ID!\n  note:"
                    ' String\n}\n\ntype RetailAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    " String!\n  region: String!\n}\n\ntype WholesaleAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  currency: String!\n  region: String!\n}\n\ntype"
                    ' CorporateAccount @key(fields: "id") @context(name:'
                    ' "priceCtx") {\n  id: ID!\n  currency: String!\n  region:'
                    " String!\n}\n\ntype QuoteEngine @key(fields:"
                    ' "serialNumber") {\n  serialNumber: String!\n '
                    " estimateCost(preferredCurrency: String"
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Float\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
            sg(
                "exchange",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ExchangeRate @key(fields:'
                    ' "code") {\n  code: String!\n  value: Float!\n '
                    " convert(to: String!): Float!\n}\n\ntype Query {\n "
                    " exchangeRate(code: String!): ExchangeRate\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_concrete_providers_accepts_typename_from_an_object() raises:
    # v2.8 > selected context values > concrete providers > accepts __typename from an object context provider
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Product @key(fields: "id")'
                    ' @context(name: "productCtx") {\n  id: ID!\n  sku:'
                    " String!\n  category: String\n  inspector:"
                    " ProductInspector!\n}\n\ntype ProductInspector"
                    ' @key(fields: "id") {\n  id: ID!\n  label(locale: String):'
                    " String\n  identify(typeName: String @fromContext(field:"
                    ' "$productCtx { __typename }")): String!\n}\n\ntype Query'
                    " {\n  product(id: ID!): Product\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_concrete_providers_rejects_a_selection_if_the_value() raises:
    # v2.8 > selected context values > concrete providers > rejects a selection if the value type is different between the providers
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote |"
                    " CorporateAccount\n\ntype GuestQuote {\n  id: ID!\n  note:"
                    ' String\n}\n\ntype RetailAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    ' String!\n}\n\ntype WholesaleAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    ' Int!\n}\n\ntype CorporateAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    " String!\n  region: String!\n}\n\ntype QuoteEngine"
                    ' @key(fields: "id") {\n  id: ID!\n  calculate(currency:'
                    ' String @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [pricing] Context "priceCtx" is'
                ' used in "QuoteEngine.calculate(currency:)" but the selection'
                ' is invalid: the type of the selection "Int" does not match'
                ' the expected type "String"'
            ),
        ],
    )


def test_v2_8_selected_context_values_concrete_providers_rejects_nullable_context_values() raises:
    # v2.8 > selected context values > concrete providers > rejects nullable context values for non-null @fromContext
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype RetailAccount @key(fields:'
                    ' "id") @context(name: "priceCtx") {\n  id: ID!\n '
                    " currency: String\n}\n\ntype QuoteEngine @key(fields:"
                    ' "id") {\n  id: ID!\n  calculate(currency: String!'
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  account(id: ID!):"
                    " RetailAccount\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [pricing] Context "priceCtx" is'
                ' used in "QuoteEngine.calculate(currency:)" but the selection'
                ' is invalid: the type of the selection "String" does not match'
                ' the expected type "String!"'
            ),
        ],
    )


def test_v2_8_selected_context_values_interfaces_and_unions_accepts_typename_from_an_inte() raises:
    # v2.8 > selected context values > interfaces and unions > accepts __typename from an interface context provider
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Node @key(fields: "id")'
                    ' @context(name: "nodeCtx") {\n  id: ID!\n}\n\ntype Sensor'
                    ' implements Node @key(fields: "id") {\n  id: ID!\n  label:'
                    " String!\n}\n\ntype Controller implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n  label:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(kind: String @fromContext(field:"
                    ' "$nodeCtx { __typename }")): String!\n}\n\ntype Query {\n'
                    "  device: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_interfaces_and_unions_accepts_a_context_on_an_inter() raises:
    # v2.8 > selected context values > interfaces and unions > accepts a context on an interface if the interface has the selected field
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n  amperage: Float\n}\n\ntype"
                    ' Sensor implements MeteredDevice @key(fields: "id") {\n '
                    " id: ID!\n  voltage: Float!\n  amperage: Float\n}\n\ntype"
                    ' Controller implements MeteredDevice @key(fields: "id")'
                    " {\n  id: ID!\n  voltage: Float!\n  amperage:"
                    ' Float\n}\n\ntype SafetyRelay @key(fields: "id") {\n  id:'
                    ' ID!\n  trip(v: Float @fromContext(field: "$meterCtx {'
                    ' voltage }")): Int!\n}\n\ntype Query {\n  device:'
                    " MeteredDevice\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_interfaces_and_unions_accepts_an_interface_context() raises:
    # v2.8 > selected context values > interfaces and unions > accepts an interface context that concrete branches resolve
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n}\n\ntype Sensor implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  reading:'
                    " Float!\n}\n\ntype Controller implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  reading:'
                    ' Float!\n}\n\ntype SafetyRelay @key(fields: "id") {\n  id:'
                    ' ID!\n  trip(reading: Float @fromContext(field: "$meterCtx'
                    " { ... on Sensor { reading } ... on Controller { reading }"
                    ' }")): Int!\n}\n\ntype Query {\n  device: MeteredDevice\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_interfaces_and_unions_rejects_a_context_field_on_a() raises:
    # v2.8 > selected context values > interfaces and unions > rejects a context field on a union if one provider does not have the field
    check(
        [
            sg(
                "media",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PlayableAsset'
                    ' @context(name: "assetCtx") = Film | Trailer\n\ntype Film'
                    ' @key(fields: "id") @context(name: "assetCtx") {\n  id:'
                    " ID!\n  rating: String!\n  player: Player!\n}\n\ntype"
                    ' Trailer @key(fields: "id") @context(name: "assetCtx") {\n'
                    "  id: ID!\n  campaign: String!\n  player:"
                    ' Player!\n}\n\ntype Player @key(fields: "id") {\n  id:'
                    " ID!\n  start(rating: String @fromContext(field:"
                    ' "$assetCtx { rating }")): Int!\n}\n\ntype Query {\n '
                    " asset: PlayableAsset\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [media] Context "assetCtx" is used'
                ' in "Player.start(rating:)" but the selection is invalid for'
                ' type Trailer. Error: Cannot query field "rating" on type'
                ' "Trailer".'
            ),
        ],
    )


def test_v2_8_selected_context_values_type_conditions_accepts_explicit_branch_selections() raises:
    # v2.8 > selected context values > type conditions > accepts explicit branch selections if the providers have different field names
    check(
        [
            sg(
                "fulfillment",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeliverySource ='
                    " CourierDelivery | LockerPickup | DroneDelivery |"
                    " StorePickup\n\ntype StorePickup {\n  id: ID!\n  desk:"
                    " String\n}\n\ntype DroneDelivery {\n  id: ID!\n  depot:"
                    ' String!\n}\n\ntype CourierDelivery @key(fields: "id")'
                    ' @context(name: "deliveryCtx") {\n  id: ID!\n '
                    " courierZone: String!\n}\n\ntype LockerPickup @key(fields:"
                    ' "id") @context(name: "deliveryCtx") {\n  id: ID!\n '
                    " lockerZone: String!\n}\n\ntype RoutePlanner @key(fields:"
                    ' "id") {\n  id: ID!\n  plan(zone: String'
                    ' @fromContext(field: "$deliveryCtx { ... on'
                    " CourierDelivery { courierZone } ... on LockerPickup {"
                    ' lockerZone } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeliverySource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_selected_context_values_type_conditions_rejects_type_conditions_that_do_not() raises:
    # v2.8 > selected context values > type conditions > rejects type conditions that do not include a concrete context provider
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller | Camera\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Gateway { model } }")):'
                    " Int!\n}\n\ntype Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_8_selected_context_values_type_conditions_rejects_a_conditional_selection_if() raises:
    # v2.8 > selected context values > type conditions > rejects a conditional selection if no inline fragment branch is a runtime type
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller | Camera\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Gateway { model } ... on Router {'
                    ' model } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_8_selected_context_values_type_conditions_rejects_two_branches_that_have_the() raises:
    # v2.8 > selected context values > type conditions > rejects two branches that have the same type condition
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    ' Controller\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Sensor {'
                    ' model } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: type conditions have same name"
            ),
        ],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a() raises:
    # v2.8 > complex query-plan-shaped context selections > checks nested list selection against [[[String]]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_2() raises:
    # v2.8 > complex query-plan-shaped context selections > checks nested list selection against [[[String]]]!
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]]]! @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[[String]]]!"'
            ),
        ],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_3() raises:
    # v2.8 > complex query-plan-shaped context selections > checks nested list selection against [[[String]!]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]!]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[[String]!]]"'
            ),
        ],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_4() raises:
    # v2.8 > complex query-plan-shaped context selections > checks nested list selection against [[String]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[String]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[String]]"'
            ),
        ],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_accepts_nested_field_paths_wit() raises:
    # v2.8 > complex query-plan-shaped context selections > accepts nested field paths within conditional selections
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [Product!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  sku: String!\n}\n\ntype"
                    ' Auditor @key(fields: "id") {\n  id: ID!\n  audit(codes:'
                    ' [String] @fromContext(field: "$catalogCtx { ... on'
                    ' Catalog { products { sku } } }")): Boolean\n}\n\ntype'
                    " Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_accepts_a_list_context_through() raises:
    # v2.8 > complex query-plan-shaped context selections > accepts a list context through an entity extension with multiple arguments
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ProductCatalog @key(fields:'
                    ' "id") @context(name: "productCtx") {\n  id: ID!\n '
                    " locale: String!\n  products: [Product!]!\n  auditor:"
                    ' InvoiceAuditor!\n}\n\ntype Product @key(fields: "id") {\n'
                    "  id: ID!\n  sku: String!\n  category:"
                    " ProductCategory!\n}\n\ntype ProductCategory @key(fields:"
                    ' "id") {\n  id: ID!\n  code: String!\n}\n\ntype'
                    ' InvoiceAuditor @key(fields: "id") {\n  id: ID!\n '
                    ' audit(skus: [String] @fromContext(field: "$productCtx {'
                    ' products { sku } }"), locale: String @fromContext(field:'
                    ' "$productCtx { locale }")): Float!\n}\n\ntype Query {\n '
                    " catalog(id: ID!): ProductCatalog\n}"
                ),
            ),
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nextend type Product @key(fields:'
                    ' "id") {\n  id: ID! @external\n  stock: Int!\n  warehouse:'
                    " String!\n}\n\ntype Query {\n  inventoryStatus: String!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ExchangeRate @key(fields:'
                    ' "code") {\n  code: String!\n  value: Float!\n '
                    " convert(to: String!): Float!\n}\n\ntype Query {\n "
                    " exchangeRate(code: String!): ExchangeRate\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_complex_query_plan_shaped_context_selections_rejects_an_invalid_field_benea() raises:
    # v2.8 > complex query-plan-shaped context selections > rejects an invalid field beneath a list context selection
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ProductCatalog @key(fields:'
                    ' "id") @context(name: "productCtx") {\n  id: ID!\n '
                    " products: [Product!]!\n}\n\ntype Product @key(fields:"
                    ' "id") {\n  id: ID!\n  sku: String!\n}\n\ntype'
                    ' InvoiceAuditor @key(fields: "id") {\n  id: ID!\n '
                    ' audit(skus: [String] @fromContext(field: "$productCtx {'
                    ' products { reference } }")): Float!\n}\n\ntype Query {\n '
                    " catalog(id: ID!): ProductCatalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "productCtx" is'
                ' used in "InvoiceAuditor.audit(skus:)" but the selection is'
                " invalid for type Product. Error: Cannot query field"
                ' "reference" on type "Product".'
            ),
        ],
    )


def test_v2_8_supergraph_does_not_leak_federation_contextfieldvalue_from_service_sdl() raises:
    # v2.8 > supergraph > does not leak federation__ContextFieldValue from service SDL
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nscalar'
                    " federation__ContextFieldValue\n\ntype Query {\n  account:"
                    ' Account\n}\n\ntype Account @context(name: "accountCtx")'
                    " {\n  locale: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_supergraph_materializes_a_nested_scalar_in_join_metadata() raises:
    # v2.8 > supergraph > materializes a nested scalar in join metadata
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype RewardLedger @shareable {\n '
                    " id: ID!\n  level: String!\n  voucher: String\n "
                    ' expiresAt: String\n}\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  profile:'
                    " RewardLedger!\n  cart: Cart!\n}\n\ntype Cart @key(fields:"
                    ' "id") {\n  id: ID!\n  checkout(level: String'
                    ' @fromContext(field: "$customerCtx { profile { level }'
                    ' }")): Float!\n}\n\ntype Query {\n  customer(id: ID!):'
                    " Customer\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_supergraph_materializes_a_list_valued_context_selection_in_join_metadata() raises:
    # v2.8 > supergraph > materializes a list-valued context selection in join metadata
    check(
        [
            sg(
                "warehouse",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype StockItem {\n  code: ID!\n '
                    " description: String\n  weightGrams: Int!\n}\n\ntype Shelf"
                    ' @key(fields: "shelfCode") @context(name: "shelfCtx") {\n '
                    " shelfCode: String!\n  aisle: String!\n  items:"
                    " [StockItem!]!\n  robot: PickRobot!\n}\n\ntype PickRobot"
                    ' @key(fields: "serial") {\n  serial: ID!\n '
                    ' reserveItems(skus: [ID] @fromContext(field: "$shelfCtx {'
                    ' items { code } }")): [ID!]!\n}\n\ntype Query {\n '
                    " shelf(shelfCode: String!): Shelf\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_supergraph_adds_the_subgraph_name_to_each_context_name() raises:
    # v2.8 > supergraph > adds the subgraph name to each context name
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "sourceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  auditInvoice(ref: String @fromContext(field:"
                    ' "$sourceCtx { reference }")): Int!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
            sg(
                "shipments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Parcel @key(fields: "id")'
                    ' @context(name: "sourceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  auditShipment(ref: String @fromContext(field:"
                    ' "$sourceCtx { reference }")): Int!\n}\n\ntype Query {\n '
                    " parcel(id: ID!): Parcel\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_type_and_interface_extensions_accepts() raises:
    # v2.8 > context providers and the public API > type and interface extensions > accepts a context on a type extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\nextend type Member"
                    ' @context(name: "memberCtx") {\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_type_and_interface_extensions_accepts_2() raises:
    # v2.8 > context providers and the public API > type and interface extensions > accepts a context on an interface extension
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend interface Node @context(name:"
                    ' "nodeCtx") {\n  label: String!\n}\n\ntype Sensor'
                    ' implements Node @key(fields: "id") {\n  id: ID!\n  label:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(label: String @fromContext(field:"
                    ' "$nodeCtx { label }")): String!\n}\n\ntype Query {\n '
                    " device: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_on() raises:
    # v2.8 > context providers and the public API > resolvable keys > accepts @fromContext on a type extension if the base type has a resolvable key
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n}\n\nextend type Wallet {\n '
                    ' apply(plan: String @fromContext(field: "$memberCtx { plan'
                    ' }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_if() raises:
    # v2.8 > context providers and the public API > resolvable keys > accepts @fromContext if one of the keys is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    ' false) @key(fields: "legacyId") {\n  id: ID!\n  legacyId:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_on_2() raises:
    # v2.8 > context providers and the public API > resolvable keys > accepts @fromContext on a type extension if one of the base keys is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id", resolvable: false) @key(fields: "legacyId") {\n '
                    " id: ID!\n  legacyId: ID!\n}\n\nextend type Wallet {\n "
                    ' apply(plan: String @fromContext(field: "$memberCtx { plan'
                    ' }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_if_2() raises:
    # v2.8 > context providers and the public API > resolvable keys > accepts @fromContext if an extension declares a resolvable key and the base type does not
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    " false) {\n  id: ID!\n  legacyId: ID!\n  apply(plan:"
                    ' String @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\nextend type Wallet @key(fields:"
                    ' "legacyId")\n\ntype Query {\n  member(id: ID!): Member\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_if() raises:
    # v2.8 > context providers and the public API > resolvable keys > rejects @fromContext if the only key of the object is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    " false) {\n  id: ID!\n  apply(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_on() raises:
    # v2.8 > context providers and the public API > resolvable keys > rejects @fromContext on a type extension if the base type key is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id", resolvable: false) {\n  id: ID!\n}\n\nextend type'
                    " Wallet {\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_on_2() raises:
    # v2.8 > context providers and the public API > resolvable keys > rejects @fromContext on a base type if only the type extension declares a resolvable key
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n}\n\ntype Wallet {\n  id: ID!\n  apply(plan:"
                    ' String @fromContext(field: "$memberCtx { plan }")):'
                    ' Int!\n}\n\nextend type Wallet @key(fields: "id",'
                    " resolvable: false)\n\ntype Query {\n  member(id: ID!):"
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_the_public_api_schema_removes_fromcont() raises:
    # v2.8 > context providers and the public API > the public API schema > removes @fromContext if another graph defines the same nullable argument
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String): Int!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_the_public_api_schema_removes_fromcont_2() raises:
    # v2.8 > context providers and the public API > the public API schema > removes @fromContext if another graph gives the argument a default value
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String ="
                    ' "standard"): Int!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_providers_and_the_public_api_the_public_api_schema_rejects_a_requir() raises:
    # v2.8 > context providers and the public API > the public API schema > rejects a required argument if another graph makes the same argument contextual
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String!): Int!\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS] Argument"
                ' "Wallet.apply(plan:)" is contextual in at least one subgraph'
                ' but in "Wallet.apply(plan:)" it does not have @fromContext,'
                " is not nullable and has no default value."
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr() raises:
    # v2.8 > context providers and the public API > @interfaceObject providers > rejects a provider type that has @interfaceObject
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") @context(name: "benefitCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$benefitCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_2() raises:
    # v2.8 > context providers and the public API > @interfaceObject providers > rejects a provider type extension that has @interfaceObject
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend type Benefit @interfaceObject"
                    ' @context(name: "benefitCtx") {\n  plan: String!\n '
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [benefits] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Benefit" has no @key in this subgraph.'
            ),
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_3() raises:
    # v2.8 > context providers and the public API > @interfaceObject providers > rejects a provider if @interfaceObject is on the definition and @context is on an extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\nextend type Benefit'
                    ' @context(name: "benefitCtx") {\n  plan: String!\n '
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_4() raises:
    # v2.8 > context providers and the public API > @interfaceObject providers > rejects a provider if @context is on the definition and @interfaceObject is on an extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @key(fields: "id")'
                    ' @context(name: "benefitCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\nextend type Benefit"
                    ' @interfaceObject\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [benefits] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Benefit" has no @key in this subgraph.'
            ),
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_8_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_5() raises:
    # v2.8 > context providers and the public API > @interfaceObject providers > rejects a provider that has @interfaceObject if an extension has @fromContext
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") @context(name: "benefitCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\nextend type Wallet'
                    ' {\n  apply(plan: String @fromContext(field: "$benefitCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  benefit(id: ID!):'
                    " Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_8_composition_across_subgraph_boundaries_accepts_an_external_field_if_the_sam() raises:
    # v2.8 > composition across subgraph boundaries > accepts an external field if the same subgraph declares the context
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  wallet:'
                    " Wallet!\n  plan: String! @external\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_composition_across_subgraph_boundaries_marks_an_external_field_as_used_if_o() raises:
    # v2.8 > composition across subgraph boundaries > marks an external field as used if only a context selection refers to it
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan: String!'
                    " @external\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_composition_across_subgraph_boundaries_rejects_a_context_declaration_from_a() raises:
    # v2.8 > composition across subgraph boundaries > rejects a context declaration from another sybgraph
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID! @external\n  plan: String! @external\n "
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [benefits] Context "memberCtx" is used at'
                ' location "Wallet.apply(plan:)" but is never set.'
            ),
            (
                '[EXTERNAL_UNUSED] [benefits] Field "Member.plan" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_8_composition_across_subgraph_boundaries_rejects_a_subgraph_that_uses_fromcon() raises:
    # v2.8 > composition across subgraph boundaries > rejects a subgraph that uses @fromContext but does not declare the context
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "analytics",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID! @external\n  wallet: Wallet!\n}\n\ntype"
                    ' Wallet @key(fields: "id") {\n  id: ID!\n  measure(age:'
                    ' Int @fromContext(field: "$memberCtx { age }")): Int!\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [analytics] Context "memberCtx" is used at'
                ' location "Wallet.measure(age:)" but is never set.'
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_authenticated_accepts_authenticated_contex() raises:
    # v2.8 > transitive security requirements > @authenticated > accepts authenticated context data if the field is also authenticated
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String! @authenticated\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @authenticated\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_transitive_security_requirements_authenticated_accepts_authenticated_condit() raises:
    # v2.8 > transitive security requirements > @authenticated > accepts authenticated conditional branches if the field is also authenticated
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  retailCurrency: String!"
                    " @authenticated\n}\n\ntype WholesaleAccount @key(fields:"
                    ' "id") @context(name: "priceCtx") @authenticated {\n  id:'
                    " ID!\n  wholesaleCurrency: String!"
                    ' @authenticated\n}\n\ntype QuoteEngine @key(fields: "id")'
                    " {\n  id: ID!\n  calculate(currency: String"
                    ' @fromContext(field: "$priceCtx { ... on RetailAccount {'
                    " retailCurrency } ... on WholesaleAccount {"
                    ' wholesaleCurrency } }")): Int! @authenticated\n}\n\ntype'
                    " Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_transitive_security_requirements_authenticated_rejects_a_field_that_reads_a() raises:
    # v2.8 > transitive security requirements > @authenticated > rejects a field that reads authenticated context data but has no auth requirement
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String! @authenticated\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_authenticated_rejects_a_field_if_the_conte() raises:
    # v2.8 > transitive security requirements > @authenticated > rejects a field if the context provider type is authenticated
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_authenticated_examines_every_fromcontext_o() raises:
    # v2.8 > transitive security requirements > @authenticated > examines every @fromContext of a field, not only the last one
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan: String!'
                    " @authenticated\n  tier: String!\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }"), tier: String @fromContext(field: "$memberCtx'
                    ' { tier }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_requiresscopes_accepts_context_data_if_the() raises:
    # v2.8 > transitive security requirements > @requiresScopes > accepts context data if the field has the merged @requiresScopes requirements
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requiresScopes"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @requiresScopes(scopes:'
                    ' [["member:read"]]) {\n  id: ID!\n  plan: String!'
                    ' @requiresScopes(scopes: [["plan:read"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @requiresScopes(scopes:'
                    ' [["member:read", "plan:read"]])\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_transitive_security_requirements_requiresscopes_rejects_a_field_that_has_no() raises:
    # v2.8 > transitive security requirements > @requiresScopes > rejects a field that has no scope for context data with @requiresScopes
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requiresScopes"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @requiresScopes(scopes:'
                    ' [["member:read"]]) {\n  id: ID!\n  plan: String!'
                    ' @requiresScopes(scopes: [["plan:read"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_policy_accepts_context_data_if_the_field_h() raises:
    # v2.8 > transitive security requirements > @policy > accepts context data if the field has the merged @policy requirements
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@policy"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @policy(policies:'
                    ' [["member_policy"]]) {\n  id: ID!\n  plan: String!'
                    ' @policy(policies: [["plan_policy"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @policy(policies: [["member_policy",'
                    ' "plan_policy"]])\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_transitive_security_requirements_policy_rejects_a_field_that_has_no_policy() raises:
    # v2.8 > transitive security requirements > @policy > rejects a field that has no policy for context data with @policy
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@policy"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @policy(policies:'
                    ' [["member_policy"]]) {\n  id: ID!\n  plan: String!'
                    ' @policy(policies: [["plan_policy"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_more_than_one_provider_accepts_context_dat() raises:
    # v2.8 > transitive security requirements > more than one provider > accepts context data from many providers if the field auth covers every path
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  currency: String!"
                    " @authenticated\n}\n\ntype WholesaleAccount @key(fields:"
                    ' "id") @context(name: "priceCtx") @authenticated {\n  id:'
                    " ID!\n  currency: String! @authenticated\n}\n\ntype"
                    ' QuoteEngine @key(fields: "id") {\n  id: ID!\n '
                    ' calculate(currency: String @fromContext(field: "$priceCtx'
                    ' { currency }")): Int! @authenticated\n}\n\ntype Query {\n'
                    "  source: PriceSource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_transitive_security_requirements_more_than_one_provider_rejects_a_field_if() raises:
    # v2.8 > transitive security requirements > more than one provider > rejects a field if only one provider path has an auth requirement
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  currency: String!\n}\n\ntype WholesaleAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  currency: String!"
                    ' @authenticated\n}\n\ntype QuoteEngine @key(fields: "id")'
                    " {\n  id: ID!\n  calculate(currency: String"
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [pricing] Field"
                ' "QuoteEngine.calculate" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive data in context"
                " pricing__priceCtx from @fromContext selection set."
            ),
        ],
    )


def test_v2_8_transitive_security_requirements_more_than_one_provider_rejects_a_field_if_2() raises:
    # v2.8 > transitive security requirements > more than one provider > rejects a field if a conditional provider branch has an auth requirement
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  retailCurrency: String!\n}\n\ntype"
                    ' WholesaleAccount @key(fields: "id") @context(name:'
                    ' "priceCtx") @authenticated {\n  id: ID!\n '
                    " wholesaleCurrency: String! @authenticated\n}\n\ntype"
                    ' QuoteEngine @key(fields: "id") {\n  id: ID!\n '
                    ' calculate(currency: String @fromContext(field: "$priceCtx'
                    " { ... on RetailAccount { retailCurrency } ... on"
                    ' WholesaleAccount { wholesaleCurrency } }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [pricing] Field"
                ' "QuoteEngine.calculate" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive data in context"
                " pricing__priceCtx from @fromContext selection set."
            ),
        ],
    )


def test_v2_8_context_reachability_rejects_a_context_set_by_the_parent_type_of_the_consum() raises:
    # v2.8 > context reachability > rejects a context set by the parent type of the consuming field
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_context_set_by_the_parent_type_even_if_the_t() raises:
    # v2.8 > context reachability > rejects a context set by the parent type even if the type can be its own ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  referrer: Member\n  discount(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_an_ancestor() raises:
    # v2.8 > context reachability > accepts a context set by an ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_a_grandparent() raises:
    # v2.8 > context reachability > accepts a context set by a grandparent
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  card: Card\n}\n\ntype Card'
                    ' @key(fields: "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_context_that_is_not_set_on_every_path_to_the() raises:
    # v2.8 > context reachability > rejects a context that is not set on every path to the consuming field
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n  wallet:"
                    " Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_context_whose_provider_is_never_on_the_query() raises:
    # v2.8 > context reachability > rejects a context whose provider is never on the query path
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " wallet: Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_consumer_that_is_not_reachable_from_the_root() raises:
    # v2.8 > context reachability > accepts a consumer that is not reachable from the root types
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_an_ancestor_reached_through_another_subgraph() raises:
    # v2.8 > context reachability > accepts an ancestor reached through another subgraph
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  wallet: Wallet\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_context_of_the_same_name_set_by_another_subg() raises:
    # v2.8 > context reachability > rejects a context of the same name set by another subgraph
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n}\n\ntype Query {\n  member:'
                    " Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Tier @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n  tier:'
                    " Tier\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_an_interface_the_ancestor_imp() raises:
    # v2.8 > context reachability > accepts a context set by an interface the ancestor implements
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Account @context(name:'
                    ' "memberCtx") {\n  plan: String!\n  wallet:'
                    " Wallet\n}\n\ntype Member implements Account @key(fields:"
                    ' "id") {\n  id: ID!\n  plan: String!\n  wallet:'
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_the_implementation_of_an_ance() raises:
    # v2.8 > context reachability > accepts a context set by the implementation of an ancestor interface
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Account {\n  wallet:'
                    " Wallet\n}\n\ntype Member implements Account @key(fields:"
                    ' "id") @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_a_union_the_ancestor_is_a_mem() raises:
    # v2.8 > context reachability > accepts a context set by a union the ancestor is a member of
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion Account @context(name:'
                    ' "memberCtx") = Member\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n  wallet:"
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { ... on Member { plan } }")): Int\n}\n\ntype'
                    " Query {\n  account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_context_set_by_a_root_type() raises:
    # v2.8 > context reachability > accepts a context set by a root type
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Query @context(name:'
                    ' "memberCtx") {\n  plan: String!\n  wallet:'
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_field_when_only_one_of_its_contexts_is_set_b() raises:
    # v2.8 > context reachability > rejects a field when only one of its contexts is set by an ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Tier @key(fields:"
                    ' "id") @context(name: "tierCtx") {\n  id: ID!\n  level:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }"), level: String @fromContext(field:'
                    ' "$tierCtx { level }")): Int\n}\n\ntype Query {\n  member:'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_prints_the_query_path_without_the_contextual_arguments() raises:
    # v2.8 > context reachability > prints the query path without the contextual arguments
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  discount(currency: String, plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_an_unreachable_context_no_matter_the_order_of() raises:
    # v2.8 > context reachability > rejects an unreachable context no matter the order of the types
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n  wallet:"
                    " Wallet\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Query {\n  wallet: Wallet\n '
                    ' member: Member\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Member'
                    ' @key(fields: "id") @context(name: "memberCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_consumer_reached_through_a_provides() raises:
    # v2.8 > context reachability > accepts a consumer reached through a @provides
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@provides"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet @provides(fields:"
                    ' "label")\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  label: String @external\n  discount(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "wallets",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " {\n  id: ID!\n  label: String @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_requires_that_can_only_be_satisfied_by_a_con() raises:
    # v2.8 > context reachability > rejects a @requires that can only be satisfied by a contextual field
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(plan: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_requires_satisfied_by_a_plain_field() raises:
    # v2.8 > context reachability > accepts a @requires satisfied by a plain field
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String): Int\n}\n\ntype'
                    " Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(plan: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_rejects_a_requires_that_needs_a_context_set_on_the_que() raises:
    # v2.8 > context reachability > rejects a @requires that needs a context set on the query root
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Query @context(name: "queryCtx")'
                    " {\n  locale: String!\n  wallet: Wallet\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  price(locale: String'
                    ' @fromContext(field: "$queryCtx { locale }")): Int\n}'
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(locale: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_requires_selection_that_sets_its_own_context() raises:
    # v2.8 > context reachability > accepts a @requires selection that sets its own context
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id") {\n  id:'
                    " ID!\n  wallet: Wallet @external\n  discount: Int"
                    ' @requires(fields: "wallet { price }")\n}\n\ntype Wallet'
                    ' @key(fields: "id") {\n  id: ID!\n  price(plan: String):'
                    " Int @external\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_8_context_reachability_accepts_a_field_with_a_contextual_argument_and_a_plain() raises:
    # v2.8 > context reachability > accepts a field with a contextual argument and a plain @requires
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  points: Int @external\n '
                    ' reward(plan: String @fromContext(field: "$memberCtx {'
                    ' plan }")): Int @requires(fields: "points")\n}\n\ntype'
                    " Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.8", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  points: Int\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_and_fromcontext_location_the_context_name_rejects_an_empty_context() raises:
    # v2.9 > @context and @fromContext location > the context name > rejects an empty context name
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "") {\n  id: ID!\n}\n\ntype Query {\n '
                    " account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [accounts] Context name "" is invalid.'
                " It should have only alphanumeric characters."
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_the_context_name_rejects_a_context_name_th() raises:
    # v2.9 > @context and @fromContext location > the context name > rejects a context name that has an underscore
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "bad_name") {\n  id: ID!\n}\n\ntype Query'
                    " {\n  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NAME_INVALID] [accounts] Context name "bad_name" is'
                " invalid. It should have only alphanumeric characters."
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_argument_rejects_fromcontext_on_argument_t() raises:
    # v2.9 > @context and @fromContext location > argument > rejects @fromContext on argument that has a default value
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Account @key(fields: "id")'
                    ' @context(name: "accountCtx") {\n  id: ID!\n  locale:'
                    ' String!\n}\n\ntype Formatter @key(fields: "id") {\n  id:'
                    ' ID!\n  format(locale: String = "en-US"'
                    ' @fromContext(field: "$accountCtx { locale }")):'
                    " Float!\n}\n\ntype Query {\n  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext arguments may not"
                ' have a default value: "Formatter.format(locale:)".'
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_argument_rejects_fromcontext_on_the_argume() raises:
    # v2.9 > @context and @fromContext location > argument > rejects @fromContext on the argument of a directive
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ndirective @tenant(locale: String'
                    ' @fromContext(field: "$accountCtx { locale }")) on'
                    ' FIELD_DEFINITION\n\ntype Account @key(fields: "id")'
                    ' @context(name: "accountCtx") {\n  id: ID!\n  locale:'
                    " String!\n}\n\ntype Query {\n  account(id: ID!):"
                    " Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                ' used on a directive definition "@tenant(locale:)".'
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_argument_rejects_fromcontext_if_the_parent() raises:
    # v2.9 > @context and @fromContext location > argument > rejects @fromContext if the parent type is abstract
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n  trip(v: Float"
                    ' @fromContext(field: "$meterCtx { voltage }")):'
                    " Boolean!\n}\n\ntype Sensor implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  voltage: Float!\n '
                    " trip(v: Float): Boolean!\n}\n\ntype Query {\n  device:"
                    " MeteredDevice\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [devices] @fromContext argument cannot be"
                " used on a field that exists on an abstract type"
                ' "MeteredDevice.trip(v:)".'
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_argument_rejects_fromcontext_on_a_field_th() raises:
    # v2.9 > @context and @fromContext location > argument > rejects @fromContext on a field that implements an interface field
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Renderable {\n  id:'
                    " ID!\n  render(locale: String): Float!\n}\n\ntype Account"
                    ' @key(fields: "id") @context(name: "accountCtx") {\n  id:'
                    " ID!\n  locale: String!\n}\n\ntype Formatter implements"
                    ' Renderable @key(fields: "id") {\n  id: ID!\n '
                    ' render(locale: String @fromContext(field: "$accountCtx {'
                    ' locale }")): Float!\n}\n\ntype Query {\n  account(id:'
                    " ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                " used on a field implementing an interface field"
                ' "Renderable.render".'
            ),
        ],
    )


def test_v2_9_context_and_fromcontext_location_argument_rejects_fromcontext_on_an_impleme() raises:
    # v2.9 > @context and @fromContext location > argument > rejects @fromContext on an implementation if the interface field has no argument
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Renderable {\n  id:'
                    " ID!\n  render: Boolean!\n}\n\ntype Account @key(fields:"
                    ' "id") @context(name: "accountCtx") {\n  id: ID!\n '
                    " locale: String!\n  formatter: Formatter!\n}\n\ntype"
                    ' Formatter implements Renderable @key(fields: "id") {\n '
                    " id: ID!\n  render(locale: String @fromContext(field:"
                    ' "$accountCtx { locale }")): Boolean!\n}\n\ntype Query {\n'
                    "  account(id: ID!): Account\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXT_NOT_SET] [accounts] @fromContext argument cannot be"
                " used on a field implementing an interface field"
                ' "Renderable.render".'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_rejects_a_selected_fiel() raises:
    # v2.9 > invalid references and unsupported selection syntax > rejects a selected field that the provider type does not have
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "$invoiceCtx { amount }")): Float!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid for type Invoice. Error: Cannot query field"
                ' "amount" on type "Invoice".'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects two sibling fields inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' amount }")): Boolean!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: multiple selections are made"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_2() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a field alias inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { value:'
                    ' reference }")): Boolean!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: aliases are not allowed in the selection"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_3() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a query directive inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' @skip(if: true) }")): Boolean!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: directives are not allowed in the selection"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_4() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects unsupported syntax before reporting multiple selections inside @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    " String!\n  amount: Float!\n}\n\ntype InvoiceAuditor"
                    ' @key(fields: "id") {\n  id: ID!\n  audit(reference:'
                    ' String @fromContext(field: "$invoiceCtx { reference'
                    ' amount @skip(if: true) }")): Boolean!\n}\n\ntype Query'
                    " {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: directives are not allowed in the selection"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_5() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects fragment spreads inside a @fromContext
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "$invoiceCtx { ...InvoiceFragment }")): Int!\n}\n\ntype'
                    " Query {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [invoices] Context "invoiceCtx" is'
                ' used in "InvoiceAuditor.audit(reference:)" but the selection'
                " is invalid: fragment spread is not allowed"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_6() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects @fromContext that mixes fields and inline fragments
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource ='
                    ' Sensor\n\ntype Sensor @key(fields: "id") @context(name:'
                    ' "deviceCtx") {\n  id: ID!\n  model: String!\n}\n\ntype'
                    ' Diagnostics @key(fields: "id") {\n  id: ID!\n '
                    ' inspect(model: String @fromContext(field: "$deviceCtx {'
                    ' ... on Sensor { model } model }")): Int!\n}\n\ntype Query'
                    " {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: multiple fields could be selected"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_unsupported_selection_s_7() raises:
    # v2.9 > invalid references and unsupported selection syntax > unsupported selection syntax > rejects a field with an inline fragment in @fromContext
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource ='
                    ' Sensor\n\ntype Sensor @key(fields: "id") @context(name:'
                    ' "deviceCtx") {\n  id: ID!\n  model: String!\n}\n\ntype'
                    ' Diagnostics @key(fields: "id") {\n  id: ID!\n '
                    ' inspect(model: String @fromContext(field: "$deviceCtx {'
                    ' model ... on Sensor { model } }")): Int!\n}\n\ntype Query'
                    " {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: multiple selections are made"
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_the_context_reference_r() raises:
    # v2.9 > invalid references and unsupported selection syntax > the context reference > rejects a @fromContext that starts with a selection
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    ' id: ID!\n  audit(reference: String @fromContext(field: "{'
                    ' reference }")): Int!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [invoices] @fromContext argument"
                ' does not reference a context "{ reference }".'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_the_context_reference_r_2() raises:
    # v2.9 > invalid references and unsupported selection syntax > the context reference > rejects @fromContext when there's no @context
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    " {\n  id: ID!\n  reference: String!\n  audit(reference:"
                    ' String @fromContext(field: "$invoiceCtx { reference }")):'
                    " Float!\n}\n\ntype Query {\n  invoice(id: ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [invoices] Context "invoiceCtx" is used at'
                ' location "Invoice.audit(reference:)" but is never set.'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_the_context_reference_r_3() raises:
    # v2.9 > invalid references and unsupported selection syntax > the context reference > rejects a @fromContext that is only a field name
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "invoiceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype InvoiceAuditor @key(fields: "id") {\n '
                    " id: ID!\n  audit(reference: String @fromContext(field:"
                    ' "reference")): Int!\n}\n\ntype Query {\n  invoice(id:'
                    " ID!): Invoice\n}"
                ),
            ),
        ],
        [
            (
                "[NO_CONTEXT_IN_SELECTION] [invoices] @fromContext argument"
                ' does not reference a context "reference".'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects() raises:
    # v2.9 > invalid references and unsupported selection syntax > type conditions > rejects interface type conditions in inline fragments
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Meter {\n  id: ID!\n '
                    " voltage: Float!\n}\n\ntype Sensor implements Meter"
                    ' @key(fields: "id") @context(name: "deviceCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n}\n\ntype Diagnostics"
                    ' @key(fields: "id") {\n  id: ID!\n  inspect(voltage: Float'
                    ' @fromContext(field: "$deviceCtx { ... on Meter { voltage'
                    ' } }")): Int!\n}\n\ntype Query {\n  sensor: Sensor\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(voltage:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects_2() raises:
    # v2.9 > invalid references and unsupported selection syntax > type conditions > rejects a type condition that the selection does not use
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Controller {'
                    ' model } ... on Camera { model } }")): Int!\n}\n\ntype'
                    " Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: type condition "Camera" is never used.'
            ),
        ],
    )


def test_v2_9_invalid_references_and_unsupported_selection_syntax_type_conditions_rejects_3() raises:
    # v2.9 > invalid references and unsupported selection syntax > type conditions > rejects an inline fragment branch that is not a runtime type
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Controller {'
                    ' model } ... on Gateway { model } }")): Int!\n}\n\ntype'
                    " Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: type condition "Gateway" is never used.'
            ),
        ],
    )


def test_v2_9_selected_context_values_concrete_providers_accepts_equivalent_selections_fr() raises:
    # v2.9 > selected context values > concrete providers > accepts equivalent selections from multiple concrete providers
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | CorporateAccount |"
                    " GuestQuote\n\ntype GuestQuote {\n  id: ID!\n  note:"
                    ' String\n}\n\ntype RetailAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    " String!\n  region: String!\n}\n\ntype WholesaleAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  currency: String!\n  region: String!\n}\n\ntype"
                    ' CorporateAccount @key(fields: "id") @context(name:'
                    ' "priceCtx") {\n  id: ID!\n  currency: String!\n  region:'
                    " String!\n}\n\ntype QuoteEngine @key(fields:"
                    ' "serialNumber") {\n  serialNumber: String!\n '
                    " estimateCost(preferredCurrency: String"
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Float\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
            sg(
                "exchange",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ExchangeRate @key(fields:'
                    ' "code") {\n  code: String!\n  value: Float!\n '
                    " convert(to: String!): Float!\n}\n\ntype Query {\n "
                    " exchangeRate(code: String!): ExchangeRate\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_concrete_providers_accepts_typename_from_an_object() raises:
    # v2.9 > selected context values > concrete providers > accepts __typename from an object context provider
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Product @key(fields: "id")'
                    ' @context(name: "productCtx") {\n  id: ID!\n  sku:'
                    " String!\n  category: String\n  inspector:"
                    " ProductInspector!\n}\n\ntype ProductInspector"
                    ' @key(fields: "id") {\n  id: ID!\n  label(locale: String):'
                    " String\n  identify(typeName: String @fromContext(field:"
                    ' "$productCtx { __typename }")): String!\n}\n\ntype Query'
                    " {\n  product(id: ID!): Product\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_concrete_providers_rejects_a_selection_if_the_value() raises:
    # v2.9 > selected context values > concrete providers > rejects a selection if the value type is different between the providers
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote |"
                    " CorporateAccount\n\ntype GuestQuote {\n  id: ID!\n  note:"
                    ' String\n}\n\ntype RetailAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    ' String!\n}\n\ntype WholesaleAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    ' Int!\n}\n\ntype CorporateAccount @key(fields: "id")'
                    ' @context(name: "priceCtx") {\n  id: ID!\n  currency:'
                    " String!\n  region: String!\n}\n\ntype QuoteEngine"
                    ' @key(fields: "id") {\n  id: ID!\n  calculate(currency:'
                    ' String @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [pricing] Context "priceCtx" is'
                ' used in "QuoteEngine.calculate(currency:)" but the selection'
                ' is invalid: the type of the selection "Int" does not match'
                ' the expected type "String"'
            ),
        ],
    )


def test_v2_9_selected_context_values_concrete_providers_rejects_nullable_context_values() raises:
    # v2.9 > selected context values > concrete providers > rejects nullable context values for non-null @fromContext
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype RetailAccount @key(fields:'
                    ' "id") @context(name: "priceCtx") {\n  id: ID!\n '
                    " currency: String\n}\n\ntype QuoteEngine @key(fields:"
                    ' "id") {\n  id: ID!\n  calculate(currency: String!'
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  account(id: ID!):"
                    " RetailAccount\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [pricing] Context "priceCtx" is'
                ' used in "QuoteEngine.calculate(currency:)" but the selection'
                ' is invalid: the type of the selection "String" does not match'
                ' the expected type "String!"'
            ),
        ],
    )


def test_v2_9_selected_context_values_interfaces_and_unions_accepts_typename_from_an_inte() raises:
    # v2.9 > selected context values > interfaces and unions > accepts __typename from an interface context provider
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Node @key(fields: "id")'
                    ' @context(name: "nodeCtx") {\n  id: ID!\n}\n\ntype Sensor'
                    ' implements Node @key(fields: "id") {\n  id: ID!\n  label:'
                    " String!\n}\n\ntype Controller implements Node"
                    ' @key(fields: "id") {\n  id: ID!\n  label:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(kind: String @fromContext(field:"
                    ' "$nodeCtx { __typename }")): String!\n}\n\ntype Query {\n'
                    "  device: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_interfaces_and_unions_accepts_a_context_on_an_inter() raises:
    # v2.9 > selected context values > interfaces and unions > accepts a context on an interface if the interface has the selected field
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n  voltage: Float!\n  amperage: Float\n}\n\ntype"
                    ' Sensor implements MeteredDevice @key(fields: "id") {\n '
                    " id: ID!\n  voltage: Float!\n  amperage: Float\n}\n\ntype"
                    ' Controller implements MeteredDevice @key(fields: "id")'
                    " {\n  id: ID!\n  voltage: Float!\n  amperage:"
                    ' Float\n}\n\ntype SafetyRelay @key(fields: "id") {\n  id:'
                    ' ID!\n  trip(v: Float @fromContext(field: "$meterCtx {'
                    ' voltage }")): Int!\n}\n\ntype Query {\n  device:'
                    " MeteredDevice\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_interfaces_and_unions_accepts_an_interface_context() raises:
    # v2.9 > selected context values > interfaces and unions > accepts an interface context that concrete branches resolve
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface MeteredDevice'
                    ' @key(fields: "id") @context(name: "meterCtx") {\n  id:'
                    " ID!\n}\n\ntype Sensor implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  reading:'
                    " Float!\n}\n\ntype Controller implements MeteredDevice"
                    ' @key(fields: "id") {\n  id: ID!\n  reading:'
                    ' Float!\n}\n\ntype SafetyRelay @key(fields: "id") {\n  id:'
                    ' ID!\n  trip(reading: Float @fromContext(field: "$meterCtx'
                    " { ... on Sensor { reading } ... on Controller { reading }"
                    ' }")): Int!\n}\n\ntype Query {\n  device: MeteredDevice\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_interfaces_and_unions_rejects_a_context_field_on_a() raises:
    # v2.9 > selected context values > interfaces and unions > rejects a context field on a union if one provider does not have the field
    check(
        [
            sg(
                "media",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PlayableAsset'
                    ' @context(name: "assetCtx") = Film | Trailer\n\ntype Film'
                    ' @key(fields: "id") @context(name: "assetCtx") {\n  id:'
                    " ID!\n  rating: String!\n  player: Player!\n}\n\ntype"
                    ' Trailer @key(fields: "id") @context(name: "assetCtx") {\n'
                    "  id: ID!\n  campaign: String!\n  player:"
                    ' Player!\n}\n\ntype Player @key(fields: "id") {\n  id:'
                    " ID!\n  start(rating: String @fromContext(field:"
                    ' "$assetCtx { rating }")): Int!\n}\n\ntype Query {\n '
                    " asset: PlayableAsset\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [media] Context "assetCtx" is used'
                ' in "Player.start(rating:)" but the selection is invalid for'
                ' type Trailer. Error: Cannot query field "rating" on type'
                ' "Trailer".'
            ),
        ],
    )


def test_v2_9_selected_context_values_type_conditions_accepts_explicit_branch_selections() raises:
    # v2.9 > selected context values > type conditions > accepts explicit branch selections if the providers have different field names
    check(
        [
            sg(
                "fulfillment",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeliverySource ='
                    " CourierDelivery | LockerPickup | DroneDelivery |"
                    " StorePickup\n\ntype StorePickup {\n  id: ID!\n  desk:"
                    " String\n}\n\ntype DroneDelivery {\n  id: ID!\n  depot:"
                    ' String!\n}\n\ntype CourierDelivery @key(fields: "id")'
                    ' @context(name: "deliveryCtx") {\n  id: ID!\n '
                    " courierZone: String!\n}\n\ntype LockerPickup @key(fields:"
                    ' "id") @context(name: "deliveryCtx") {\n  id: ID!\n '
                    " lockerZone: String!\n}\n\ntype RoutePlanner @key(fields:"
                    ' "id") {\n  id: ID!\n  plan(zone: String'
                    ' @fromContext(field: "$deliveryCtx { ... on'
                    " CourierDelivery { courierZone } ... on LockerPickup {"
                    ' lockerZone } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeliverySource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_selected_context_values_type_conditions_rejects_type_conditions_that_do_not() raises:
    # v2.9 > selected context values > type conditions > rejects type conditions that do not include a concrete context provider
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller | Camera\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Gateway { model } }")):'
                    " Int!\n}\n\ntype Query {\n  source: DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_9_selected_context_values_type_conditions_rejects_a_conditional_selection_if() raises:
    # v2.9 > selected context values > type conditions > rejects a conditional selection if no inline fragment branch is a runtime type
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    " Controller | Camera\n\ntype Camera {\n  id: ID!\n  model:"
                    ' String!\n}\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Gateway { model } ... on Router {'
                    ' model } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                ' invalid: no type condition matches the location "Sensor"'
            ),
        ],
    )


def test_v2_9_selected_context_values_type_conditions_rejects_two_branches_that_have_the() raises:
    # v2.9 > selected context values > type conditions > rejects two branches that have the same type condition
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion DeviceSource = Sensor |'
                    ' Controller\n\ntype Sensor @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Controller @key(fields: "id")'
                    ' @context(name: "deviceCtx") {\n  id: ID!\n  model:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(model: String @fromContext(field:"
                    ' "$deviceCtx { ... on Sensor { model } ... on Sensor {'
                    ' model } }")): Int!\n}\n\ntype Query {\n  source:'
                    " DeviceSource\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [devices] Context "deviceCtx" is'
                ' used in "Diagnostics.inspect(model:)" but the selection is'
                " invalid: type conditions have same name"
            ),
        ],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a() raises:
    # v2.9 > complex query-plan-shaped context selections > checks nested list selection against [[[String]]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_2() raises:
    # v2.9 > complex query-plan-shaped context selections > checks nested list selection against [[[String]]]!
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]]]! @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[[String]]]!"'
            ),
        ],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_3() raises:
    # v2.9 > complex query-plan-shaped context selections > checks nested list selection against [[[String]!]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[[String]!]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[[String]!]]"'
            ),
        ],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_checks_nested_list_selection_a_4() raises:
    # v2.9 > complex query-plan-shaped context selections > checks nested list selection against [[String]]
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [[Product!]!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  codes:"
                    ' [String]!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  audit(codes: [[String]] @fromContext(field:"
                    ' "$catalogCtx { products { codes } }")):'
                    " Boolean\n}\n\ntype Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "catalogCtx" is'
                ' used in "Auditor.audit(codes:)" but the selection is invalid:'
                ' the type of the selection "[[[String]]]" does not match the'
                ' expected type "[[String]]"'
            ),
        ],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_accepts_nested_field_paths_wit() raises:
    # v2.9 > complex query-plan-shaped context selections > accepts nested field paths within conditional selections
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Catalog @context(name:'
                    ' "catalogCtx") {\n  products: [Product!]!\n  auditor:'
                    " Auditor\n}\n\ntype Product {\n  sku: String!\n}\n\ntype"
                    ' Auditor @key(fields: "id") {\n  id: ID!\n  audit(codes:'
                    ' [String] @fromContext(field: "$catalogCtx { ... on'
                    ' Catalog { products { sku } } }")): Boolean\n}\n\ntype'
                    " Query {\n  catalog: Catalog\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_accepts_a_list_context_through() raises:
    # v2.9 > complex query-plan-shaped context selections > accepts a list context through an entity extension with multiple arguments
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ProductCatalog @key(fields:'
                    ' "id") @context(name: "productCtx") {\n  id: ID!\n '
                    " locale: String!\n  products: [Product!]!\n  auditor:"
                    ' InvoiceAuditor!\n}\n\ntype Product @key(fields: "id") {\n'
                    "  id: ID!\n  sku: String!\n  category:"
                    " ProductCategory!\n}\n\ntype ProductCategory @key(fields:"
                    ' "id") {\n  id: ID!\n  code: String!\n}\n\ntype'
                    ' InvoiceAuditor @key(fields: "id") {\n  id: ID!\n '
                    ' audit(skus: [String] @fromContext(field: "$productCtx {'
                    ' products { sku } }"), locale: String @fromContext(field:'
                    ' "$productCtx { locale }")): Float!\n}\n\ntype Query {\n '
                    " catalog(id: ID!): ProductCatalog\n}"
                ),
            ),
            sg(
                "inventory",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nextend type Product @key(fields:'
                    ' "id") {\n  id: ID! @external\n  stock: Int!\n  warehouse:'
                    " String!\n}\n\ntype Query {\n  inventoryStatus: String!\n}"
                ),
            ),
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ExchangeRate @key(fields:'
                    ' "code") {\n  code: String!\n  value: Float!\n '
                    " convert(to: String!): Float!\n}\n\ntype Query {\n "
                    " exchangeRate(code: String!): ExchangeRate\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_complex_query_plan_shaped_context_selections_rejects_an_invalid_field_benea() raises:
    # v2.9 > complex query-plan-shaped context selections > rejects an invalid field beneath a list context selection
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype ProductCatalog @key(fields:'
                    ' "id") @context(name: "productCtx") {\n  id: ID!\n '
                    " products: [Product!]!\n}\n\ntype Product @key(fields:"
                    ' "id") {\n  id: ID!\n  sku: String!\n}\n\ntype'
                    ' InvoiceAuditor @key(fields: "id") {\n  id: ID!\n '
                    ' audit(skus: [String] @fromContext(field: "$productCtx {'
                    ' products { reference } }")): Float!\n}\n\ntype Query {\n '
                    " catalog(id: ID!): ProductCatalog\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [catalog] Context "productCtx" is'
                ' used in "InvoiceAuditor.audit(skus:)" but the selection is'
                " invalid for type Product. Error: Cannot query field"
                ' "reference" on type "Product".'
            ),
        ],
    )


def test_v2_9_supergraph_does_not_leak_federation_contextfieldvalue_from_service_sdl() raises:
    # v2.9 > supergraph > does not leak federation__ContextFieldValue from service SDL
    check(
        [
            sg(
                "accounts",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nscalar'
                    " federation__ContextFieldValue\n\ntype Query {\n  account:"
                    ' Account\n}\n\ntype Account @context(name: "accountCtx")'
                    " {\n  locale: String!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_supergraph_materializes_a_nested_scalar_in_join_metadata() raises:
    # v2.9 > supergraph > materializes a nested scalar in join metadata
    check(
        [
            sg(
                "orders",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype RewardLedger @shareable {\n '
                    " id: ID!\n  level: String!\n  voucher: String\n "
                    ' expiresAt: String\n}\n\ntype Customer @key(fields: "id")'
                    ' @context(name: "customerCtx") {\n  id: ID!\n  profile:'
                    " RewardLedger!\n  cart: Cart!\n}\n\ntype Cart @key(fields:"
                    ' "id") {\n  id: ID!\n  checkout(level: String'
                    ' @fromContext(field: "$customerCtx { profile { level }'
                    ' }")): Float!\n}\n\ntype Query {\n  customer(id: ID!):'
                    " Customer\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_supergraph_materializes_a_list_valued_context_selection_in_join_metadata() raises:
    # v2.9 > supergraph > materializes a list-valued context selection in join metadata
    check(
        [
            sg(
                "warehouse",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype StockItem {\n  code: ID!\n '
                    " description: String\n  weightGrams: Int!\n}\n\ntype Shelf"
                    ' @key(fields: "shelfCode") @context(name: "shelfCtx") {\n '
                    " shelfCode: String!\n  aisle: String!\n  items:"
                    " [StockItem!]!\n  robot: PickRobot!\n}\n\ntype PickRobot"
                    ' @key(fields: "serial") {\n  serial: ID!\n '
                    ' reserveItems(skus: [ID] @fromContext(field: "$shelfCtx {'
                    ' items { code } }")): [ID!]!\n}\n\ntype Query {\n '
                    " shelf(shelfCode: String!): Shelf\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_supergraph_adds_the_subgraph_name_to_each_context_name() raises:
    # v2.9 > supergraph > adds the subgraph name to each context name
    check(
        [
            sg(
                "invoices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Invoice @key(fields: "id")'
                    ' @context(name: "sourceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  auditInvoice(ref: String @fromContext(field:"
                    ' "$sourceCtx { reference }")): Int!\n}\n\ntype Query {\n '
                    " invoice(id: ID!): Invoice\n}"
                ),
            ),
            sg(
                "shipments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Parcel @key(fields: "id")'
                    ' @context(name: "sourceCtx") {\n  id: ID!\n  reference:'
                    ' String!\n}\n\ntype Auditor @key(fields: "id") {\n  id:'
                    " ID!\n  auditShipment(ref: String @fromContext(field:"
                    ' "$sourceCtx { reference }")): Int!\n}\n\ntype Query {\n '
                    " parcel(id: ID!): Parcel\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_type_and_interface_extensions_accepts() raises:
    # v2.9 > context providers and the public API > type and interface extensions > accepts a context on a type extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\nextend type Member"
                    ' @context(name: "memberCtx") {\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_type_and_interface_extensions_accepts_2() raises:
    # v2.9 > context providers and the public API > type and interface extensions > accepts a context on an interface extension
    check(
        [
            sg(
                "devices",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Node @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend interface Node @context(name:"
                    ' "nodeCtx") {\n  label: String!\n}\n\ntype Sensor'
                    ' implements Node @key(fields: "id") {\n  id: ID!\n  label:'
                    ' String!\n}\n\ntype Diagnostics @key(fields: "id") {\n '
                    " id: ID!\n  inspect(label: String @fromContext(field:"
                    ' "$nodeCtx { label }")): String!\n}\n\ntype Query {\n '
                    " device: Node\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_on() raises:
    # v2.9 > context providers and the public API > resolvable keys > accepts @fromContext on a type extension if the base type has a resolvable key
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n}\n\nextend type Wallet {\n '
                    ' apply(plan: String @fromContext(field: "$memberCtx { plan'
                    ' }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_if() raises:
    # v2.9 > context providers and the public API > resolvable keys > accepts @fromContext if one of the keys is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    ' false) @key(fields: "legacyId") {\n  id: ID!\n  legacyId:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_on_2() raises:
    # v2.9 > context providers and the public API > resolvable keys > accepts @fromContext on a type extension if one of the base keys is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id", resolvable: false) @key(fields: "legacyId") {\n '
                    " id: ID!\n  legacyId: ID!\n}\n\nextend type Wallet {\n "
                    ' apply(plan: String @fromContext(field: "$memberCtx { plan'
                    ' }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_accepts_fromcontext_if_2() raises:
    # v2.9 > context providers and the public API > resolvable keys > accepts @fromContext if an extension declares a resolvable key and the base type does not
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    " false) {\n  id: ID!\n  legacyId: ID!\n  apply(plan:"
                    ' String @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\nextend type Wallet @key(fields:"
                    ' "legacyId")\n\ntype Query {\n  member(id: ID!): Member\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_if() raises:
    # v2.9 > context providers and the public API > resolvable keys > rejects @fromContext if the only key of the object is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id", resolvable:'
                    " false) {\n  id: ID!\n  apply(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_on() raises:
    # v2.9 > context providers and the public API > resolvable keys > rejects @fromContext on a type extension if the base type key is not resolvable
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\ntype Wallet @key(fields:"
                    ' "id", resolvable: false) {\n  id: ID!\n}\n\nextend type'
                    " Wallet {\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_resolvable_keys_rejects_fromcontext_on_2() raises:
    # v2.9 > context providers and the public API > resolvable keys > rejects @fromContext on a base type if only the type extension declares a resolvable key
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n}\n\ntype Wallet {\n  id: ID!\n  apply(plan:"
                    ' String @fromContext(field: "$memberCtx { plan }")):'
                    ' Int!\n}\n\nextend type Wallet @key(fields: "id",'
                    " resolvable: false)\n\ntype Query {\n  member(id: ID!):"
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NO_RESOLVABLE_KEY] [benefits] Object "Wallet" has no'
                " resolvable key but has a field with a contextual argument."
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_the_public_api_schema_removes_fromcont() raises:
    # v2.9 > context providers and the public API > the public API schema > removes @fromContext if another graph defines the same nullable argument
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String): Int!\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_the_public_api_schema_removes_fromcont_2() raises:
    # v2.9 > context providers and the public API > the public API schema > removes @fromContext if another graph gives the argument a default value
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String ="
                    ' "standard"): Int!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_providers_and_the_public_api_the_public_api_schema_rejects_a_requir() raises:
    # v2.9 > context providers and the public API > the public API schema > rejects a required argument if another graph makes the same argument contextual
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") @shareable'
                    " {\n  id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "payments",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " @shareable {\n  id: ID!\n  apply(plan: String!): Int!\n}"
                ),
            ),
        ],
        [
            (
                "[CONTEXTUAL_ARGUMENT_NOT_CONTEXTUAL_IN_ALL_SUBGRAPHS] Argument"
                ' "Wallet.apply(plan:)" is contextual in at least one subgraph'
                ' but in "Wallet.apply(plan:)" it does not have @fromContext,'
                " is not nullable and has no default value."
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr() raises:
    # v2.9 > context providers and the public API > @interfaceObject providers > rejects a provider type that has @interfaceObject
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") @context(name: "benefitCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$benefitCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_2() raises:
    # v2.9 > context providers and the public API > @interfaceObject providers > rejects a provider type extension that has @interfaceObject
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @key(fields: "id")'
                    " {\n  id: ID!\n}\n\nextend type Benefit @interfaceObject"
                    ' @context(name: "benefitCtx") {\n  plan: String!\n '
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [benefits] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Benefit" has no @key in this subgraph.'
            ),
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_3() raises:
    # v2.9 > context providers and the public API > @interfaceObject providers > rejects a provider if @interfaceObject is on the definition and @context is on an extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") {\n  id: ID!\n}\n\nextend type Benefit'
                    ' @context(name: "benefitCtx") {\n  plan: String!\n '
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_4() raises:
    # v2.9 > context providers and the public API > @interfaceObject providers > rejects a provider if @context is on the definition and @interfaceObject is on an extension
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @key(fields: "id")'
                    ' @context(name: "benefitCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet!\n}\n\nextend type Benefit"
                    ' @interfaceObject\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$benefitCtx { plan }")): Int!\n}\n\ntype Query {\n '
                    " benefit(id: ID!): Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                "[INTERFACE_OBJECT_USAGE_ERROR] [benefits] The @interfaceObject"
                " directive can only be applied to entity types but type"
                ' "Benefit" has no @key in this subgraph.'
            ),
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_9_context_providers_and_the_public_api_interfaceobject_providers_rejects_a_pr_5() raises:
    # v2.9 > context providers and the public API > @interfaceObject providers > rejects a provider that has @interfaceObject if an extension has @fromContext
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Benefit @interfaceObject'
                    ' @key(fields: "id") @context(name: "benefitCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\nextend type Wallet'
                    ' {\n  apply(plan: String @fromContext(field: "$benefitCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  benefit(id: ID!):'
                    " Benefit\n}"
                ),
            ),
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Benefit @key(fields:'
                    ' "id") {\n  id: ID!\n}\n\ntype Coupon implements Benefit'
                    ' @key(fields: "id") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [
            (
                '[CONTEXT_INVALID_SELECTION] [benefits] Context "benefitCtx" is'
                ' used in "Wallet.apply(plan:)" but the selection is invalid:'
                " One of the types in the selection is an interfaceObject:"
                ' "Benefit"'
            ),
        ],
    )


def test_v2_9_composition_across_subgraph_boundaries_accepts_an_external_field_if_the_sam() raises:
    # v2.9 > composition across subgraph boundaries > accepts an external field if the same subgraph declares the context
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  wallet:'
                    " Wallet!\n  plan: String! @external\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_composition_across_subgraph_boundaries_marks_an_external_field_as_used_if_o() raises:
    # v2.9 > composition across subgraph boundaries > marks an external field as used if only a context selection refers to it
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan: String!'
                    " @external\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_composition_across_subgraph_boundaries_rejects_a_context_declaration_from_a() raises:
    # v2.9 > composition across subgraph boundaries > rejects a context declaration from another sybgraph
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID! @external\n  plan: String! @external\n "
                    ' wallet: Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  apply(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int!\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [benefits] Context "memberCtx" is used at'
                ' location "Wallet.apply(plan:)" but is never set.'
            ),
            (
                '[EXTERNAL_UNUSED] [benefits] Field "Member.plan" is marked'
                " @external but is not used in any federation directive (@key,"
                " @provides, @requires) or to satisfy an interface; the field"
                " declaration has no use and should be removed (or the field"
                " should not be @external)."
            ),
        ],
    )


def test_v2_9_composition_across_subgraph_boundaries_rejects_a_subgraph_that_uses_fromcon() raises:
    # v2.9 > composition across subgraph boundaries > rejects a subgraph that uses @fromContext but does not declare the context
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  age:'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
            sg(
                "analytics",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID! @external\n  wallet: Wallet!\n}\n\ntype"
                    ' Wallet @key(fields: "id") {\n  id: ID!\n  measure(age:'
                    ' Int @fromContext(field: "$memberCtx { age }")): Int!\n}'
                ),
            ),
        ],
        [
            (
                '[CONTEXT_NOT_SET] [analytics] Context "memberCtx" is used at'
                ' location "Wallet.measure(age:)" but is never set.'
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_authenticated_accepts_authenticated_contex() raises:
    # v2.9 > transitive security requirements > @authenticated > accepts authenticated context data if the field is also authenticated
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String! @authenticated\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @authenticated\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_transitive_security_requirements_authenticated_accepts_authenticated_condit() raises:
    # v2.9 > transitive security requirements > @authenticated > accepts authenticated conditional branches if the field is also authenticated
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  retailCurrency: String!"
                    " @authenticated\n}\n\ntype WholesaleAccount @key(fields:"
                    ' "id") @context(name: "priceCtx") @authenticated {\n  id:'
                    " ID!\n  wholesaleCurrency: String!"
                    ' @authenticated\n}\n\ntype QuoteEngine @key(fields: "id")'
                    " {\n  id: ID!\n  calculate(currency: String"
                    ' @fromContext(field: "$priceCtx { ... on RetailAccount {'
                    " retailCurrency } ... on WholesaleAccount {"
                    ' wholesaleCurrency } }")): Int! @authenticated\n}\n\ntype'
                    " Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_transitive_security_requirements_authenticated_rejects_a_field_that_reads_a() raises:
    # v2.9 > transitive security requirements > @authenticated > rejects a field that reads authenticated context data but has no auth requirement
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String! @authenticated\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_authenticated_rejects_a_field_if_the_conte() raises:
    # v2.9 > transitive security requirements > @authenticated > rejects a field if the context provider type is authenticated
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @authenticated {\n  id: ID!\n'
                    "  plan: String!\n  wallet: Wallet!\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  apply(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int!\n}\n\ntype Query {\n  member(id: ID!): Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_authenticated_examines_every_fromcontext_o() raises:
    # v2.9 > transitive security requirements > @authenticated > examines every @fromContext of a field, not only the last one
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan: String!'
                    " @authenticated\n  tier: String!\n  wallet:"
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }"), tier: String @fromContext(field: "$memberCtx'
                    ' { tier }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_requiresscopes_accepts_context_data_if_the() raises:
    # v2.9 > transitive security requirements > @requiresScopes > accepts context data if the field has the merged @requiresScopes requirements
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requiresScopes"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @requiresScopes(scopes:'
                    ' [["member:read"]]) {\n  id: ID!\n  plan: String!'
                    ' @requiresScopes(scopes: [["plan:read"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @requiresScopes(scopes:'
                    ' [["member:read", "plan:read"]])\n}\n\ntype Query {\n '
                    " member(id: ID!): Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_transitive_security_requirements_requiresscopes_rejects_a_field_that_has_no() raises:
    # v2.9 > transitive security requirements > @requiresScopes > rejects a field that has no scope for context data with @requiresScopes
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requiresScopes"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @requiresScopes(scopes:'
                    ' [["member:read"]]) {\n  id: ID!\n  plan: String!'
                    ' @requiresScopes(scopes: [["plan:read"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_policy_accepts_context_data_if_the_field_h() raises:
    # v2.9 > transitive security requirements > @policy > accepts context data if the field has the merged @policy requirements
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@policy"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @policy(policies:'
                    ' [["member_policy"]]) {\n  id: ID!\n  plan: String!'
                    ' @policy(policies: [["plan_policy"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int! @policy(policies: [["member_policy",'
                    ' "plan_policy"]])\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_transitive_security_requirements_policy_rejects_a_field_that_has_no_policy() raises:
    # v2.9 > transitive security requirements > @policy > rejects a field that has no policy for context data with @policy
    check(
        [
            sg(
                "identity",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@policy"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") @policy(policies:'
                    ' [["member_policy"]]) {\n  id: ID!\n  plan: String!'
                    ' @policy(policies: [["plan_policy"]])\n  wallet:'
                    ' Wallet!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    ' ID!\n  apply(plan: String @fromContext(field: "$memberCtx'
                    ' { plan }")): Int!\n}\n\ntype Query {\n  member(id: ID!):'
                    " Member\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [identity] Field"
                ' "Wallet.apply" does not specify necessary @authenticated,'
                " @requiresScopes and/or @policy auth requirements to access"
                " the transitive data in context identity__memberCtx from"
                " @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_more_than_one_provider_accepts_context_dat() raises:
    # v2.9 > transitive security requirements > more than one provider > accepts context data from many providers if the field auth covers every path
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  currency: String!"
                    " @authenticated\n}\n\ntype WholesaleAccount @key(fields:"
                    ' "id") @context(name: "priceCtx") @authenticated {\n  id:'
                    " ID!\n  currency: String! @authenticated\n}\n\ntype"
                    ' QuoteEngine @key(fields: "id") {\n  id: ID!\n '
                    ' calculate(currency: String @fromContext(field: "$priceCtx'
                    ' { currency }")): Int! @authenticated\n}\n\ntype Query {\n'
                    "  source: PriceSource\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_transitive_security_requirements_more_than_one_provider_rejects_a_field_if() raises:
    # v2.9 > transitive security requirements > more than one provider > rejects a field if only one provider path has an auth requirement
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  currency: String!\n}\n\ntype WholesaleAccount"
                    ' @key(fields: "id") @context(name: "priceCtx")'
                    " @authenticated {\n  id: ID!\n  currency: String!"
                    ' @authenticated\n}\n\ntype QuoteEngine @key(fields: "id")'
                    " {\n  id: ID!\n  calculate(currency: String"
                    ' @fromContext(field: "$priceCtx { currency }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [pricing] Field"
                ' "QuoteEngine.calculate" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive data in context"
                " pricing__priceCtx from @fromContext selection set."
            ),
        ],
    )


def test_v2_9_transitive_security_requirements_more_than_one_provider_rejects_a_field_if_2() raises:
    # v2.9 > transitive security requirements > more than one provider > rejects a field if a conditional provider branch has an auth requirement
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion PriceSource = RetailAccount'
                    " | WholesaleAccount | GuestQuote\n\ntype GuestQuote {\n "
                    " id: ID!\n  note: String\n}\n\ntype RetailAccount"
                    ' @key(fields: "id") @context(name: "priceCtx") {\n  id:'
                    " ID!\n  retailCurrency: String!\n}\n\ntype"
                    ' WholesaleAccount @key(fields: "id") @context(name:'
                    ' "priceCtx") @authenticated {\n  id: ID!\n '
                    " wholesaleCurrency: String! @authenticated\n}\n\ntype"
                    ' QuoteEngine @key(fields: "id") {\n  id: ID!\n '
                    ' calculate(currency: String @fromContext(field: "$priceCtx'
                    " { ... on RetailAccount { retailCurrency } ... on"
                    ' WholesaleAccount { wholesaleCurrency } }")):'
                    " Int!\n}\n\ntype Query {\n  source: PriceSource\n}"
                ),
            ),
        ],
        [
            (
                "[MISSING_TRANSITIVE_AUTH_REQUIREMENTS] [pricing] Field"
                ' "QuoteEngine.calculate" does not specify necessary'
                " @authenticated, @requiresScopes and/or @policy auth"
                " requirements to access the transitive data in context"
                " pricing__priceCtx from @fromContext selection set."
            ),
        ],
    )


def test_v2_9_context_reachability_rejects_a_context_set_by_the_parent_type_of_the_consum() raises:
    # v2.9 > context reachability > rejects a context set by the parent type of the consuming field
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_context_set_by_the_parent_type_even_if_the_t() raises:
    # v2.9 > context reachability > rejects a context set by the parent type even if the type can be its own ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  referrer: Member\n  discount(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_an_ancestor() raises:
    # v2.9 > context reachability > accepts a context set by an ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_a_grandparent() raises:
    # v2.9 > context reachability > accepts a context set by a grandparent
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  card: Card\n}\n\ntype Card'
                    ' @key(fields: "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_context_that_is_not_set_on_every_path_to_the() raises:
    # v2.9 > context reachability > rejects a context that is not set on every path to the consuming field
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n  wallet:"
                    " Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_context_whose_provider_is_never_on_the_query() raises:
    # v2.9 > context reachability > rejects a context whose provider is never on the query path
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " wallet: Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_consumer_that_is_not_reachable_from_the_root() raises:
    # v2.9 > context reachability > accepts a consumer that is not reachable from the root types
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_an_ancestor_reached_through_another_subgraph() raises:
    # v2.9 > context reachability > accepts an ancestor reached through another subgraph
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  wallet: Wallet\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n}\n\ntype Query {\n '
                    " member: Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_context_of_the_same_name_set_by_another_subg() raises:
    # v2.9 > context reachability > rejects a context of the same name set by another subgraph
    check(
        [
            sg(
                "catalog",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n}\n\ntype Query {\n  member:'
                    " Member\n}"
                ),
            ),
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Tier @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n  tier:'
                    " Tier\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_an_interface_the_ancestor_imp() raises:
    # v2.9 > context reachability > accepts a context set by an interface the ancestor implements
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Account @context(name:'
                    ' "memberCtx") {\n  plan: String!\n  wallet:'
                    " Wallet\n}\n\ntype Member implements Account @key(fields:"
                    ' "id") {\n  id: ID!\n  plan: String!\n  wallet:'
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Query {\n '
                    " account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_the_implementation_of_an_ance() raises:
    # v2.9 > context reachability > accepts a context set by the implementation of an ancestor interface
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ninterface Account {\n  wallet:'
                    " Wallet\n}\n\ntype Member implements Account @key(fields:"
                    ' "id") @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_a_union_the_ancestor_is_a_mem() raises:
    # v2.9 > context reachability > accepts a context set by a union the ancestor is a member of
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\nunion Account @context(name:'
                    ' "memberCtx") = Member\n\ntype Member @key(fields: "id")'
                    " {\n  id: ID!\n  plan: String!\n  wallet:"
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { ... on Member { plan } }")): Int\n}\n\ntype'
                    " Query {\n  account: Account\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_context_set_by_a_root_type() raises:
    # v2.9 > context reachability > accepts a context set by a root type
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Query @context(name:'
                    ' "memberCtx") {\n  plan: String!\n  wallet:'
                    ' Wallet\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}'
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_field_when_only_one_of_its_contexts_is_set_b() raises:
    # v2.9 > context reachability > rejects a field when only one of its contexts is set by an ancestor
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Tier @key(fields:"
                    ' "id") @context(name: "tierCtx") {\n  id: ID!\n  level:'
                    ' String!\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }"), level: String @fromContext(field:'
                    ' "$tierCtx { level }")): Int\n}\n\ntype Query {\n  member:'
                    " Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_prints_the_query_path_without_the_contextual_arguments() raises:
    # v2.9 > context reachability > prints the query path without the contextual arguments
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  discount(currency: String, plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_an_unreachable_context_no_matter_the_order_of() raises:
    # v2.9 > context reachability > rejects an unreachable context no matter the order of the types
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  discount(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n  wallet:"
                    " Wallet\n}"
                ),
            ),
        ],
        [],
    )
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Query {\n  wallet: Wallet\n '
                    ' member: Member\n}\n\ntype Wallet @key(fields: "id") {\n '
                    " id: ID!\n  discount(plan: String @fromContext(field:"
                    ' "$memberCtx { plan }")): Int\n}\n\ntype Member'
                    ' @key(fields: "id") @context(name: "memberCtx") {\n  id:'
                    " ID!\n  plan: String!\n  wallet: Wallet\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_consumer_reached_through_a_provides() raises:
    # v2.9 > context reachability > accepts a consumer reached through a @provides
    check(
        [
            sg(
                "benefits",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@provides"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet @provides(fields:"
                    ' "label")\n}\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  label: String @external\n  discount(plan: String"
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "wallets",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated",'
                    ' "@interfaceObject"])\n\ntype Wallet @key(fields: "id")'
                    " {\n  id: ID!\n  label: String @shareable\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_requires_that_can_only_be_satisfied_by_a_con() raises:
    # v2.9 > context reachability > rejects a @requires that can only be satisfied by a contextual field
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(plan: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_requires_satisfied_by_a_plain_field() raises:
    # v2.9 > context reachability > accepts a @requires satisfied by a plain field
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String): Int\n}\n\ntype'
                    " Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(plan: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_rejects_a_requires_that_needs_a_context_set_on_the_que() raises:
    # v2.9 > context reachability > rejects a @requires that needs a context set on the query root
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Query @context(name: "queryCtx")'
                    " {\n  locale: String!\n  wallet: Wallet\n}\n\ntype Wallet"
                    ' @key(fields: "id") {\n  id: ID!\n  price(locale: String'
                    ' @fromContext(field: "$queryCtx { locale }")): Int\n}'
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  price(locale: String): Int @external\n  discount:"
                    ' Int @requires(fields: "price")\n}\n\ntype Query {\n '
                    " noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_requires_selection_that_sets_its_own_context() raises:
    # v2.9 > context reachability > accepts a @requires selection that sets its own context
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  price(plan: String'
                    ' @fromContext(field: "$memberCtx { plan }")):'
                    " Int\n}\n\ntype Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id") {\n  id:'
                    " ID!\n  wallet: Wallet @external\n  discount: Int"
                    ' @requires(fields: "wallet { price }")\n}\n\ntype Wallet'
                    ' @key(fields: "id") {\n  id: ID!\n  price(plan: String):'
                    " Int @external\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [],
    )


def test_v2_9_context_reachability_accepts_a_field_with_a_contextual_argument_and_a_plain() raises:
    # v2.9 > context reachability > accepts a field with a contextual argument and a plain @requires
    check(
        [
            sg(
                "pricing",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Member @key(fields: "id")'
                    ' @context(name: "memberCtx") {\n  id: ID!\n  plan:'
                    " String!\n  wallet: Wallet\n}\n\ntype Wallet @key(fields:"
                    ' "id") {\n  id: ID!\n  points: Int @external\n '
                    ' reward(plan: String @fromContext(field: "$memberCtx {'
                    ' plan }")): Int @requires(fields: "points")\n}\n\ntype'
                    " Query {\n  member: Member\n}"
                ),
            ),
            sg(
                "shipping",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.9", import:'
                    ' ["@key", "@shareable", "@external", "@context",'
                    ' "@fromContext", "@authenticated", "@interfaceObject",'
                    ' "@requires"])\n\ntype Wallet @key(fields: "id") {\n  id:'
                    " ID!\n  points: Int\n}\n\ntype Query {\n  noop: Int\n}"
                ),
            ),
        ],
        [],
    )


comptime _V23 = (
    "extend schema @link(url:"
    ' "https://specs.apollo.dev/federation/v2.3", import: ["@key",'
    ' "@shareable", "@external", "@requires", "@interfaceObject"])\n\n'
)

comptime _UNUSED = (
    " is marked @external but is not used in any federation directive"
    " (@key, @provides, @requires) or to satisfy an interface; the field"
    " declaration has no use and should be removed (or the field should not"
    " be @external)."
)


def _one(sdl: String, expected: List[String]) raises:
    check([sg("a", String(_V23) + sdl)], expected)


def test_interface_extension_before_definition() raises:
    _one(
        (
            "type Query {\n  n: Node\n}\n\nextend interface Node {\n  a: Int\n}"
            "\n\ninterface Node {\n  b: Int\n}\n\ntype X implements Node {\n"
            "  a: Int\n  b: Int\n}"
        ),
        [],
    )


def test_type_import_with_alias() raises:
    check(
        [
            sg(
                "a",
                (
                    "extend schema @link(url:"
                    ' "https://specs.apollo.dev/federation/v2.3", import:'
                    ' ["@key", { name: "FieldSet", as: "MyFieldSet" }])\n\ntype'
                    ' Query {\n  t: T\n}\n\ntype T @key(fields: "id") {\n  id:'
                    " ID!\n}"
                ),
            ),
        ],
        [],
    )


def test_reserved_field_name_in_requires() raises:
    _one(
        (
            'type Query {\n  t: T\n}\n\ntype T @key(fields: "id") {\n  id:'
            " ID!\n  __x: String @external\n  y: String @requires(fields:"
            ' "__x")\n}'
        ),
        [
            String(
                '[INVALID_GRAPHQL] [a] Name "__x" must not begin with "__",'
                " which is reserved by GraphQL introspection."
            )
        ],
    )


def test_reserved_type_name_with_key() raises:
    _one(
        (
            'type Query {\n  t: __T\n}\n\ntype __T @key(fields: "id") {\n'
            "  id: ID!\n}"
        ),
        [
            String(
                '[INVALID_GRAPHQL] [a] Name "__T" must not begin with "__",'
                " which is reserved by GraphQL introspection."
            )
        ],
    )


def test_external_that_implements_an_interface_field() raises:
    # The interface field is a use, so EXTERNAL_UNUSED is not reported.
    _one(
        (
            "type Query {\n  t: T\n}\n\ninterface I {\n  f: String\n}\n\ntype T"
            ' implements I @key(fields: "id") {\n  id: ID!\n'
            "  f: String @external\n}"
        ),
        [
            String(
                '[EXTERNAL_MISSING_ON_BASE] Field "T.f" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "a").'
            )
        ],
    )


def test_external_returning_shareable_object() raises:
    # A @shareable output type is a use, so EXTERNAL_UNUSED is not reported.
    _one(
        (
            "type Query {\n  t: T\n}\n\ntype O @shareable {\n  x:"
            ' Int\n}\n\ntype T @key(fields: "id") {\n  id: ID!\n  o: O'
            " @external\n}"
        ),
        [
            String(
                '[EXTERNAL_MISSING_ON_BASE] Field "T.o" is marked @external'
                " on all the subgraphs in which it is listed (subgraph"
                ' "a").'
            )
        ],
    )


def test_object_extension_before_definition() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\nextend type T {\n  a: Int\n}\n\ntype T"
            ' @key(fields: "id") {\n  id: ID!\n}'
        ),
        [],
    )


def test_federation_1_fieldset_scalar() raises:
    # In v1.0 the specification type is `_FieldSet`, not `FieldSet`.
    check(
        [
            sg(
                "a",
                (
                    "type Query {\n  t: T\n}\n\nscalar FieldSet\n\ntype T"
                    ' @key(fields: "id") {\n  id: ID!\n}'
                ),
            )
        ],
        [],
    )


def test_external_on_interface_field() raises:
    _one(
        "type Query {\n  i: I\n}\n\ninterface I {\n  f: String @external\n}",
        [],
    )


def test_external_on_interface_object() raises:
    _one(
        (
            "type Query {\n  i: I\n}\n\ntype I @interfaceObject @key(fields:"
            ' "id") {\n  id: ID!\n  f: String @external\n}'
        ),
        [String('[EXTERNAL_UNUSED] [a] Field "I.f"') + _UNUSED],
    )


def test_external_returning_non_shareable_object() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\ntype O {\n  x: Int\n}\n\ntype T"
            ' @key(fields: "id") {\n  id: ID!\n  o: O @external\n}'
        ),
        [String('[EXTERNAL_UNUSED] [a] Field "T.o"') + _UNUSED],
    )


def test_external_returning_a_list() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\ntype O {\n  x: Int\n}\n\ntype T"
            ' @key(fields: "id") {\n  id: ID!\n  o: [O!]! @external\n}'
        ),
        [String('[EXTERNAL_UNUSED] [a] Field "T.o"') + _UNUSED],
    )


def test_external_returning_enum() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\nenum E {\n  A\n}\n\ntype T"
            ' @key(fields: "id") {\n  id: ID!\n  e: E @external\n}'
        ),
        [String('[EXTERNAL_UNUSED] [a] Field "T.e"') + _UNUSED],
    )


def test_external_not_in_the_interface() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\ninterface I {\n  id: ID!\n}\n\ntype T"
            ' implements I @key(fields: "id") {\n  id: ID!\n'
            "  f: String @external\n}"
        ),
        [String('[EXTERNAL_UNUSED] [a] Field "T.f"') + _UNUSED],
    )


def test_external_with_unknown_interface() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\ntype T implements Missing"
            ' @key(fields: "id") {\n  id: ID!\n  f: String @external\n}'
        ),
        [
            String("[INVALID_GRAPHQL] [a] Unknown type Missing"),
            String('[EXTERNAL_UNUSED] [a] Field "T.f"') + _UNUSED,
            String(
                "[INVALID_GRAPHQL] [a] Type Missing must define one or more"
                " fields."
            ),
        ],
    )


def test_external_implementing_an_object() raises:
    _one(
        (
            "type Query {\n  t: T\n}\n\ntype O {\n  f: String\n}\n\ntype T"
            ' implements O @key(fields: "id") {\n  id: ID!\n'
            "  f: String @external\n}"
        ),
        [String("THROWS Expected O to be an interface type")],
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
