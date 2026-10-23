const std = @import("std");
const assert = std.debug.assert;

const dest_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "M", "001" },
    .{ "D", "010" },
    .{ "MD", "011" },
    .{ "A", "100" },
    .{ "AM", "101" },
    .{ "AD", "110" },
    .{ "AMD", "111" },
});

const comp_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "0", "0101010" },
    .{ "1", "0111111" },
    .{ "-1", "0111010" },
    .{ "D", "0001100" },
    .{ "A", "0110000" },
    .{ "M", "1110000" },
    .{ "!D", "0001101" },
    .{ "!A", "0110001" },
    .{ "!M", "1110001" },
    .{ "-D", "0001111" },
    .{ "-A", "0110011" },
    .{ "-M", "1110011" },
    .{ "D+1", "0011111" },
    .{ "A+1", "0110111" },
    .{ "M+1", "1110111" },
    .{ "D-1", "0001110" },
    .{ "A-1", "0110010" },
    .{ "M-1", "1110010" },
    .{ "D+A", "0000010" },
    .{ "D+M", "1000010" },
    .{ "D-A", "0010011" },
    .{ "D-M", "1010011" },
    .{ "A-D", "0000111" },
    .{ "M-D", "1000111" },
    .{ "D&A", "0000000" },
    .{ "D&M", "1000000" },
    .{ "D|A", "0010101" },
    .{ "D|M", "1010101" },
});

const jump_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "JGT", "001" },
    .{ "JEQ", "010" },
    .{ "JGE", "011" },
    .{ "JLT", "100" },
    .{ "JNE", "101" },
    .{ "JLE", "110" },
    .{ "JMP", "111" },
});

pub fn dest(mnemonic: ?[]const u8) []const u8 {
    if (mnemonic) |n| {
        const d = dest_map.get(n);
        return d.?;
    }
    return "000";
}

pub fn comp(mnemonic: []const u8) []const u8 {
    const c = comp_map.get(mnemonic);
    return c.?;
}

pub fn jump(mnemonic: ?[]const u8) []const u8 {
    if (mnemonic) |n| {
        const j = jump_map.get(n);
        return j.?;
    }
    return "000";
}
