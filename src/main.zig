const std = @import("std");
const print = std.debug.print;
const bufPrint = std.fmt.bufPrint;
const Parser = @import("Parser.zig");
const Code = @import("Code.zig");
const SymbolTable = @import("SymbolTable.zig");

const C_COMMAND_PREFIX = "111";
const OUTPUT_EXT = "hack";

pub fn main(init: std.process.Init) !void {
    const cwd = std.Io.Dir.cwd();
    const io = init.io;
    const allocator = init.arena.allocator();

    var it = try init.minimal.args.iterateAllocator(allocator);
    defer it.deinit();

    _ = it.skip(); // skip the program name
    const file_path = it.next() orelse return error.NoFileProvided;

    if (!std.mem.endsWith(u8, file_path, ".asm")) {
        return error.IncorrectFileFormat;
    }

    const output_path = try std.fmt.allocPrint(allocator, "{s}{c}{s}", .{ std.fs.path.stem(file_path), '.', OUTPUT_EXT });

    const file = try cwd.openFile(io, file_path, .{ .mode = .read_only });
    const output_file = try cwd.createFile(io, output_path, .{});
    defer file.close(io);
    defer output_file.close(io);

    var write_buffer: [4096]u8 = undefined;
    var file_writer = output_file.writer(io, &write_buffer);
    const writer = &file_writer.interface;

    // if anything below returns an error, still flush what was written so far.
    errdefer writer.flush() catch {};

    // alternative: delete the partial output instead of keeping it.
    // errdefer cwd.deleteFile(io, "./output/out.asm") catch {};

    try assemble(allocator, io, file, writer);
}

fn handle_c_command(parser: *Parser, writer: *std.Io.Writer) !void {
    const dest = parser.dest();
    const dest_bin = Code.dest(dest);
    const comp = parser.comp();
    const comp_bin = Code.comp(comp);
    const jump = parser.jump();
    const jump_bin = Code.jump(jump);

    return try writer.print("{s}{s}{s}{s}", .{ C_COMMAND_PREFIX, comp_bin, dest_bin, jump_bin });
}

fn handle_a_command(parser: *Parser, symbol_table: *SymbolTable, writer: *std.Io.Writer) !void {
    const symbol = parser.symbol();
    const is_numeric = std.ascii.isDigit(symbol[0]);
    const number = if (is_numeric) try std.fmt.parseInt(u16, symbol, 10) else try symbol_table.get_address(symbol);

    return try writer.print("{b:0>16}", .{number});
}

fn generate_output_file(parser: *Parser, symbol_table: *SymbolTable, writer: *std.Io.Writer) !void {
    var counter: u64 = 0;

    while (try parser.advance()) {
        const command_type = parser.command_type();
        if (command_type == .l_command) continue;
        if (counter > 0) {
            try writer.print("\n", .{});
        }
        switch (command_type) {
            .c_command => try handle_c_command(parser, writer),
            .a_command => try handle_a_command(parser, symbol_table, writer),
            else => unreachable,
        }
        counter += 1;
    }
    try writer.flush();
}

fn parse_symbols(parser: *Parser, symbol_table: *SymbolTable) !void {
    var address: u16 = 0;
    while (try parser.advance()) {
        const command_type = parser.command_type();
        if (command_type == .l_command) {
            const symbol = parser.symbol();
            try symbol_table.add_entry(symbol, address);
        } else {
            address += 1;
        }
    }
}

fn assemble(allocator: std.mem.Allocator, io: std.Io, file: std.Io.File, writer: *std.Io.Writer) !void {
    var symbol_table = try SymbolTable.init(allocator);
    defer symbol_table.deinit(allocator);

    var read_buffer: [4096]u8 = undefined;
    var parser = Parser.init(io, file, &read_buffer);

    try parse_symbols(&parser, &symbol_table);
    try parser.reset_file_offset();
    try generate_output_file(&parser, &symbol_table, writer);
}
