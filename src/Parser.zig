const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const print = std.debug.print;

file_reader: std.Io.File.Reader,

/// The current command, or null when there is none: before the first `advance`
current_command: ?[]const u8,

pub const CommandType = enum { a_command, c_command, l_command };

const DELIMITER = '\n';
const COMMENT = "//";
const ASSIGNMENT_SYMBOL = '=';
const JUMP_SYMBOL = ';';

// Includes `\r` so that files with Windows line endings (`\r\n`) parse the same way.
const WHITESPACE = " \t\r";

const Parser = @This();
const ParserError = error{
    EndOfFile,
};

/// Opens the input file/stream and gets ready to parse it.
pub fn init(io: std.Io, file: std.Io.File, buffer: []u8) Parser {
    assert(buffer.len > 0);

    return .{
        .file_reader = file.reader(io, buffer),
        .current_command = null,
    };
}

/// Advances to the next command, if there is one.
///
/// Returns true if a command was found, and false at end of input.
pub fn advance(self: *Parser) !bool {
    // Clear first, so that no exit path (junk line, end of input, error) can leave
    // a stale command behind.
    self.current_command = null;

    const reader = &self.file_reader.interface;

    while (self.current_command == null) {
        const line = (try reader.takeDelimiter(DELIMITER)) orelse return false;
        assert(mem.findScalar(u8, line, DELIMITER) == null);

        self.current_command = command_from_line(line);
        if (self.current_command) |command| {
            assert(command.len > 0);
            assert(mem.find(u8, command, COMMENT) == null);
        }
    }

    assert(self.current_command != null);

    return true;
}

/// Returns the type of the current command:
/// - a_command for @Xxx where Xxx is either a symbol or a decimal number
/// - c_command for dest=comp;jump
/// - l_command (actually, pseudocommand) for (Xxx) where Xxx is a symbol.
/// Should be called only when `current_command` is not null.
pub fn command_type(self: *const Parser) CommandType {
    assert(self.current_command != null);
    const command = self.current_command.?;
    return switch (command[0]) {
        '@' => .a_command,
        '(' => .l_command,
        else => .c_command,
    };
}

/// Returns the symbol or decimal Xxx of the current command @Xxx or (Xxx).
/// Should be called only when command_type() is a_command or l_command.
pub fn symbol(self: *const Parser) []const u8 {
    assert(self.current_command != null);
    const command = self.current_command.?;
    const command_t = self.command_type();
    assert(command_t != .c_command);
    return switch (command_t) {
        .a_command => command[1..],
        .l_command => command[1..(command.len - 1)],
        else => unreachable,
    };
}

/// Returns the dest mnemonic in the current C-command (8 possibilities).
/// Should be called only when command_type() is c_command.
pub fn dest(self: *const Parser) ?[]const u8 {
    assert(self.current_command != null);
    const command = self.current_command.?;
    const command_t = self.command_type();
    assert(command_t == .c_command);
    const dest_pos = mem.findScalar(u8, command, ASSIGNMENT_SYMBOL);

    if (dest_pos) |pos| {
        return command[0..pos];
    }

    return null;
}

/// Returns the comp mnemonic in the current C-command (28 possibilities).
/// Should be called only when command_type() is c_command.
pub fn comp(self: *const Parser) []const u8 {
    assert(self.current_command != null);
    const command = self.current_command.?;
    const command_t = self.command_type();
    assert(command_t == .c_command);
    const comp_start_pos = if (mem.findScalar(u8, command, ASSIGNMENT_SYMBOL)) |start_pos| start_pos + 1 else 0;
    const comp_end_pos = if (mem.findScalar(u8, command, JUMP_SYMBOL)) |end_pos| end_pos else command.len;
    return command[comp_start_pos..comp_end_pos];
}

/// Returns the jump mnemonic in the current C-command (8 possibilities).
/// Should be called only when command_type() is c_command.
pub fn jump(self: *const Parser) ?[]const u8 {
    assert(self.current_command != null);
    const command = self.current_command.?;
    const command_t = self.command_type();
    assert(command_t == .c_command);
    const jump_pos = mem.findScalar(u8, command, JUMP_SYMBOL);

    if (jump_pos) |pos| {
        return command[pos + 1 ..];
    }

    return null;
}

/// Returns the command on this line, or null if the line is blank or only a comment.
/// Pure on purpose: it touches no parser state, so `advance` is the only place that assigns
/// `current_command`.
fn command_from_line(line: []const u8) ?[]const u8 {
    const comment_pos = mem.find(u8, line, COMMENT);
    const uncommented = if (comment_pos) |pos| line[0..pos] else line;
    const trimmed = mem.trim(u8, uncommented, WHITESPACE);
    if (trimmed.len == 0) return null;
    return trimmed;
}

/// resets the file to the start.
pub fn reset_file_offset(self: *Parser) !void {
    try self.file_reader.seekTo(0);
}
