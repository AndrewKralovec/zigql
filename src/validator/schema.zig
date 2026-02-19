const std = @import("std");

pub const Schema = struct {
    pub fn init(allocator: std.mem.Allocator) Schema {
        _ = allocator;
        return Schema{};
    }
    pub fn deinit(self: *Schema) void {
        _ = self;
    }
};
