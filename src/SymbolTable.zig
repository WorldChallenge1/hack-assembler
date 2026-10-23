const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const print = std.debug.print;

const MAX_SYMBOLS = 16 * 1024;
const MAX_SYMBOL_LENGTH = 64;
const PREDEFINED_COUNT = 23;

map: std.StringHashMapUnmanaged(u16),
variable_starting_offset: u16 = 16,

/// Owns the bytes of every name added by `add`.
symbol_storage: []u8,
symbol_storage_used: usize,

const SymbolTable = @This();

/// Creates a new empty symbol table.
pub fn init(allocator: std.mem.Allocator) !SymbolTable {
    var map: std.StringHashMapUnmanaged(u16) = .empty;
    errdefer map.deinit(allocator);
    try map.ensureTotalCapacity(allocator, MAX_SYMBOLS);

    const name_storage = try allocator.alloc(u8, MAX_SYMBOLS * MAX_SYMBOL_LENGTH);
    errdefer allocator.free(name_storage);

    map.putAssumeCapacityNoClobber("SP", 0);
    map.putAssumeCapacityNoClobber("LCL", 1);
    map.putAssumeCapacityNoClobber("ARG", 2);
    map.putAssumeCapacityNoClobber("THIS", 3);
    map.putAssumeCapacityNoClobber("THAT", 4);
    map.putAssumeCapacityNoClobber("R0", 0);
    map.putAssumeCapacityNoClobber("R1", 1);
    map.putAssumeCapacityNoClobber("R2", 2);
    map.putAssumeCapacityNoClobber("R3", 3);
    map.putAssumeCapacityNoClobber("R4", 4);
    map.putAssumeCapacityNoClobber("R5", 5);
    map.putAssumeCapacityNoClobber("R6", 6);
    map.putAssumeCapacityNoClobber("R7", 7);
    map.putAssumeCapacityNoClobber("R8", 8);
    map.putAssumeCapacityNoClobber("R9", 9);
    map.putAssumeCapacityNoClobber("R10", 10);
    map.putAssumeCapacityNoClobber("R11", 11);
    map.putAssumeCapacityNoClobber("R12", 12);
    map.putAssumeCapacityNoClobber("R13", 13);
    map.putAssumeCapacityNoClobber("R14", 14);
    map.putAssumeCapacityNoClobber("R15", 15);
    map.putAssumeCapacityNoClobber("SCREEN", 16384);
    map.putAssumeCapacityNoClobber("KBD", 24576);
    assert(map.count() == PREDEFINED_COUNT);

    return .{
        .map = map,
        .symbol_storage = name_storage,
        .symbol_storage_used = 0,
    };
}

/// Free all owned memory.
pub fn deinit(self: *SymbolTable, allocator: mem.Allocator) void {
    self.map.deinit(allocator);
    allocator.free(self.symbol_storage);
    self.* = undefined;
}

/// Adds the pair (symbol, address) to the table.
pub fn add_entry(self: *SymbolTable, symbol: []const u8, address: u16) !void {
    assert(symbol.len > 0);
    assert(!self.contains(symbol));
    assert(self.symbol_storage_used <= self.symbol_storage.len);

    if (symbol.len > MAX_SYMBOL_LENGTH) return error.NameTooLong;
    if (self.map.count() >= MAX_SYMBOLS) return error.SymbolTableFull;

    const start = self.symbol_storage_used;
    const end = start + symbol.len;
    assert(end <= self.symbol_storage.len);

    const owned_symbol = self.symbol_storage[start..end];
    @memcpy(owned_symbol, symbol);
    self.symbol_storage_used = end;
    self.map.putAssumeCapacityNoClobber(owned_symbol, address);
}

/// Does the symbol table contain the given symbol?
pub fn contains(self: *SymbolTable, symbol: []const u8) bool {
    return self.map.contains(symbol);
}

/// Returns the address associated with the symbol, adds it and return the address if it doesn't exist already.
pub fn get_address(self: *SymbolTable, symbol: []const u8) !u16 {
    if (self.contains(symbol)) return self.map.get(symbol).?;
    const offset = self.variable_starting_offset;
    try add_entry(self, symbol, self.variable_starting_offset);
    self.variable_starting_offset += 1;
    return offset;
}

pub fn print_map(self: *SymbolTable) void {
    var it = self.map.iterator();
    while (it.next()) |entry| {
        print("key: {s}, value {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}
