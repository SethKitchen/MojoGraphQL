# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

"""What a command prints: its output, its errors and the JSON envelope.

Port of `JsonOutput` of Rover `src/options/output.rs`, the `Display` and
the JSON of `RoverError` in `src/error/mod.rs`, and the `anyhow` format of
an error and its causes. Color is never written: Rover writes none when
its output is not a terminal, and these functions return text.
"""

from gql_json.writer import write_string


@fieldwise_init
struct OutputFormat(Equatable, ImplicitlyCopyable, Writable):
    """The `--format` of a command."""

    var value: UInt8
    """The format's index; see `is_valid`."""

    comptime PLAIN = OutputFormat(0)
    """Text for a person: `--format plain`, the default."""
    comptime JSON = OutputFormat(1)
    """The JSON envelope: `--format json`."""

    def is_valid(self) -> Bool:
        """Return True for `PLAIN` and `JSON`.

        Returns:
            Whether the value is in range.
        """
        return self.value <= 1

    def write_to(self, mut writer: Some[Writer]):
        """Write the flag value: `plain` or `json`.

        Args:
            writer: The writer.
        """
        if self.value == 0:
            writer.write("plain")
        elif self.value == 1:
            writer.write("json")
        else:
            writer.write("<invalid>")


@fieldwise_init
struct CommandOutput(Copyable, Movable):
    """The result of a command: its standard output, its standard error and
    its exit code."""

    var stdout: String
    """The text for standard output."""
    var stderr: String
    """The text for standard error."""
    var exit_code: Int
    """0 for success, 1 for an error, 2 for invalid arguments."""


def json_string(text: StringSlice) -> String:
    """Return a JSON string literal, as serde_json writes it.

    Args:
        text: The value.

    Returns:
        The quoted and escaped text.
    """
    var out = List[UInt8](capacity=text.byte_length() + 2)
    write_string(out, text.as_bytes())
    return String(unsafe_from_utf8=out)


def success_json(members: StringSlice) -> String:
    """Return the JSON envelope of a successful command.

    Args:
        members: The members of `data`, such as `"core_schema":"..."`;
            empty for none.

    Returns:
        `{"json_version":"1","data":{...,"success":true},"error":null}`.
    """
    var data = String(members) + "," if members.byte_length() > 0 else String(
        ""
    )
    return (
        '{"json_version":"1","data":{' + data + '"success":true},"error":null}'
    )


def _indent_lines(text: String, first: String, rest: String) -> String:
    """Prefix the first line of a text with `first` and the others with
    `rest`, as the `Indented` writer of `anyhow` does."""
    var out = String(first)
    var lines = text.split("\n")
    var index = 0
    while index < len(lines):
        if index > 0:
            out += "\n" + rest
        out += lines[index]
        index += 1
    return out^


@fieldwise_init
struct RoverError(Copyable, Movable):
    """An error of a command, as Rover prints it."""

    var message: String
    """The top-level message."""
    var causes: List[String]
    """The messages of the cause chain, outermost first."""
    var code: String
    """The error code, such as `E029`; empty for none."""
    var suggestions: List[String]
    """The suggestions printed under the error."""
    var details: String
    """The JSON of the build errors of a composition, or empty."""
    var data: String
    """The members of `data` in the JSON envelope, or empty."""

    @staticmethod
    def of(message: String) -> RoverError:
        """Make an error with only a message.

        Args:
            message: The message.

        Returns:
            The error, with no cause, code or suggestion.
        """
        return RoverError(message, List[String](), "", List[String](), "", "")

    def text(self) -> String:
        """Return the error as Rover writes it to standard error.

        Returns:
            Such as `error[E029]: Encountered 1 build error ...`, then the
            causes and the suggestions, each line ended by a line break.
        """
        var out = String(
            "error[" + self.code + "]: "
        ) if self.code != "" else String("error: ")
        out += self.message
        if len(self.causes) > 0:
            out += "\n\nCaused by:"
            var multiple = len(self.causes) > 1
            var index = 0
            while index < len(self.causes):
                out += "\n"
                if multiple:
                    var number = String(index)
                    var pad = String(" ") * (5 - number.byte_length())
                    out += _indent_lines(
                        self.causes[index], pad + number + ": ", "       "
                    )
                else:
                    out += _indent_lines(self.causes[index], "    ", "    ")
                index += 1
        out += "\n"
        for ref suggestion in self.suggestions:
            out += "        " + suggestion + "\n"
        return out^

    def json(self) -> String:
        """Return the JSON envelope of the error.

        Returns:
            `{"json_version":"1","data":{...,"success":false},"error":{...}}`.
        """
        var error: String
        if self.details != "":
            error = (
                '{"details":'
                + self.details
                + ',"code":'
                + json_string(self.code)
                + ',"message":'
                + json_string(self.message)
                + "}"
            )
        else:
            error = '{"message":' + json_string(self.message)
            if len(self.causes) > 0:
                var quoted = List[String]()
                var index = 0
                while index < len(self.causes):
                    quoted.append(json_string(self.causes[index]))
                    index += 1
                error += ',"causes":[' + String(",").join(quoted) + "]"
            error += (
                ',"code":'
                + (
                    json_string(self.code) if self.code
                    != "" else String("null")
                )
                + "}"
            )
        var data = self.data + "," if self.data != "" else String("")
        return (
            '{"json_version":"1","data":{'
            + data
            + '"success":false},"error":'
            + error
            + "}"
        )


@fieldwise_init
struct CommandResult(Copyable, Movable):
    """What a command produced, before `--format` and `--output` apply."""

    var error: Optional[RoverError]
    """The error, or None for success."""
    var text: String
    """The plain output of a success, without its final line break."""
    var members: String
    """The members of `data` in the JSON envelope of a success."""
    var descriptor: String
    """What the output is, such as `Supergraph Schema`."""
    var stderr: String
    """The notices that the command wrote to standard error first."""

    @staticmethod
    def failure(var error: RoverError, stderr: String = "") -> CommandResult:
        """Make the result of a command that failed.

        Args:
            error: The error.
            stderr: The notices written before the error.

        Returns:
            The result.
        """
        return CommandResult(error^, "", "", "", stderr)

    def render(
        self, format: OutputFormat, output_file: Optional[String]
    ) raises -> CommandOutput:
        """Print the result, as Rover `RoverPrinter::write_or_print`.

        With an output file, the plain or JSON text goes into the file, and
        standard error names the file.

        Args:
            format: The `--format`.
            output_file: The absolute path of `--output`, if it is set.

        Returns:
            The standard output, the standard error and the exit code.

        Raises:
            Error: If the output file cannot be written.
        """
        var stderr = self.stderr.copy()
        if self.error:
            ref error = self.error.value()
            if format == OutputFormat.PLAIN:
                return CommandOutput("", stderr + error.text(), 1)
            if output_file:
                _write(output_file.value(), error.json())
                stderr += (
                    "Error JSON was printed to " + output_file.value() + "\n"
                )
                return CommandOutput("", stderr^, 1)
            return CommandOutput(error.json() + "\n", stderr^, 1)
        var result = (
            self.text.copy() if format
            == OutputFormat.PLAIN else success_json(self.members)
        )
        if output_file:
            _write(output_file.value(), result)
            var what = self.descriptor if self.descriptor != "" else String(
                "The output"
            )
            stderr += what + " was printed to " + output_file.value() + "\n"
            return CommandOutput("", stderr^, 0)
        return CommandOutput(result + "\n", stderr^, 0)


def _write(path: String, text: String) raises:
    """Write a file, as Rover `Fs::write_file`."""
    with open(path, "w") as file:
        file.write(text)
