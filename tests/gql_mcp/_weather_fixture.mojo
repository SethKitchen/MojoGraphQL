# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""The weather example of Apollo MCP Server 2.0.0: `examples/weather/api.graphql`
and the three operations of `examples/weather/operations/`.
"""

comptime WEATHER_SCHEMA = '''"""A weather alert"""
type Alert {
  """The severity of this alert"""
  severity: String

  """A description of the alert"""
  description: String

  """Information about how people should respond to the alert"""
  instruction: String
}

"""A coordinate, consisting of a latitude and longitude"""
type Coordinate {
  """The latitude of this coordinate"""
  latitude: String!

  """The longitude of this coordinate"""
  longitude: String!
}

"""A weather forecast"""
type Forecast {
  """The coordinate associated with this forecast"""
  coordinate: Coordinate!

  """
  The National Weather Service (NWS) URL where the forecast data can be read
  """
  forecastURL: String!

  """A detailed weather forecast from the National Weather Service (NWS)"""
  detailed: String!
}

"""A coordinate, consisting of a latitude and longitude"""
input InputCoordinate {
  """The latitude of this coordinate"""
  latitude: String!

  """The longitude of this coordinate"""
  longitude: String!
}

type Query {
  """Get the weather forecast for a coordinate"""
  forecast(coordinate: InputCoordinate!): Forecast

  """
  Get the weather alerts for a state
  """
  alerts(
    """The two-letter state abbreviation (e.g., 'CO' for Colorado)"""
    state: String!
  ): [Alert]
}
'''
"""The SDL of the weather API."""

comptime ALERTS_OPERATION = """query GetAlerts($state: String!) {
  alerts(state: $state) {
    severity
    description
    instruction
  }
}
"""
"""The text of `operations/alerts.graphql`."""

comptime ALL_OPERATION = """query GetAllWeatherData($coordinate: InputCoordinate!, $state: String!) {
  forecast(coordinate: $coordinate) {
    detailed
  }
  alerts(state: $state) {
    severity
    description
    instruction
  }
}
"""
"""The text of `operations/all.graphql`."""

comptime FORECAST_OPERATION = """query GetForecast($coordinate: InputCoordinate!) {
  forecast(coordinate: $coordinate) {
    detailed
  }
}
"""
"""The text of `operations/forecast.graphql`."""

comptime WEATHER_TOOLS_LIST = """{"tools":[{"name":"GetAlerts","description":"Get the weather alerts for a state\\nThe returned value is optional and is an array of type `Alert`\\n---\\n\\"\\"\\"A weather alert\\"\\"\\"\\ntype Alert {\\n  \\"\\"\\"The severity of this alert\\"\\"\\"\\n  severity: String\\n  \\"\\"\\"A description of the alert\\"\\"\\"\\n  description: String\\n  \\"\\"\\"Information about how people should respond to the alert\\"\\"\\"\\n  instruction: String\\n}\\n","inputSchema":{"type":"object","properties":{"state":{"description":"The two-letter state abbreviation (e.g., 'CO' for Colorado)","type":"string"}},"required":["state"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}},{"name":"GetAllWeatherData","description":"Get the weather forecast for a coordinate\\nThe returned value is optional and has type `Forecast`\\n---\\nGet the weather alerts for a state\\nThe returned value is optional and is an array of type `Alert`\\n---\\n\\"\\"\\"A weather alert\\"\\"\\"\\ntype Alert {\\n  \\"\\"\\"The severity of this alert\\"\\"\\"\\n  severity: String\\n  \\"\\"\\"A description of the alert\\"\\"\\"\\n  description: String\\n  \\"\\"\\"Information about how people should respond to the alert\\"\\"\\"\\n  instruction: String\\n}\\n\\n\\"\\"\\"A weather forecast\\"\\"\\"\\ntype Forecast {\\n  \\"\\"\\"A detailed weather forecast from the National Weather Service (NWS)\\"\\"\\"\\n  detailed: String!\\n}\\n","inputSchema":{"type":"object","properties":{"coordinate":{"$ref":"#/definitions/InputCoordinate"},"state":{"description":"The two-letter state abbreviation (e.g., 'CO' for Colorado)","type":"string"}},"required":["coordinate","state"],"definitions":{"InputCoordinate":{"description":"A coordinate, consisting of a latitude and longitude","type":"object","properties":{"latitude":{"description":"The latitude of this coordinate","type":"string"},"longitude":{"description":"The longitude of this coordinate","type":"string"}},"required":["latitude","longitude"]}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}},{"name":"GetForecast","description":"Get the weather forecast for a coordinate\\nThe returned value is optional and has type `Forecast`\\n---\\n\\"\\"\\"A weather forecast\\"\\"\\"\\ntype Forecast {\\n  \\"\\"\\"A detailed weather forecast from the National Weather Service (NWS)\\"\\"\\"\\n  detailed: String!\\n}\\n","inputSchema":{"type":"object","properties":{"coordinate":{"$ref":"#/definitions/InputCoordinate"}},"required":["coordinate"],"definitions":{"InputCoordinate":{"description":"A coordinate, consisting of a latitude and longitude","type":"object","properties":{"latitude":{"description":"The latitude of this coordinate","type":"string"},"longitude":{"description":"The longitude of this coordinate","type":"string"}},"required":["latitude","longitude"]}}},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}},{"name":"execute","description":"Execute a GraphQL operation. Use the `introspect` tool to get information about the GraphQL schema. Always use the schema to create operations - do not try arbitrary operations. If available, first use the `validate` tool to validate operations. DO NOT try to execute introspection queries.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input for the execute tool.","type":"object","properties":{"query":{"description":"The GraphQL operation","type":"string"},"variables":{"description":"The variable values represented as JSON","type":"string","default":null}},"required":["query"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":true}},{"name":"introspect","description":"Get information about a given GraphQL type defined in the schema. Instructions: Use this tool to explore the schema by providing specific type names. Start with the root query (Query) or mutation (Mutation) types to discover available fields. If the search tool is also available, use this tool first to get the fields, then use the search tool with relevant field return types and argument input types (ignore default GraphQL scalars) as search terms.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input for the introspect tool.","type":"object","properties":{"type_name":{"description":"The name of the type to get information about.","type":"string"},"depth":{"description":"How far to recurse the type hierarchy. Use 0 for no limit. Defaults to 1.","type":"integer","format":"uint","minimum":0,"default":1}},"required":["type_name"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}},{"name":"search","description":"Search a GraphQL schema for types matching the provided search terms. Returns complete type definitions including all related types needed to construct GraphQL operations. Instructions: If the introspect tool is also available, you can discover type names by using the introspect tool starting from the root Query or Mutation types. Avoid reusing previously searched terms for more efficient exploration.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input for the search tool.","type":"object","properties":{"terms":{"description":"The search terms","type":"array","items":{"type":"string"}}},"required":["terms"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}},{"name":"validate","description":"Validates a GraphQL operation against the schema. Use the `introspect` tool first to get information about the GraphQL schema. Operations should be validated prior to calling the `execute` tool.","inputSchema":{"$schema":"http://json-schema.org/draft-07/schema#","title":"Input","description":"Input for the validate tool","type":"object","properties":{"operation":{"description":"The GraphQL operation","type":"string"}},"required":["operation"]},"annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}}]}"""
"""The tools/list result of the upstream binary for the weather example, with the four built-in tools on."""
