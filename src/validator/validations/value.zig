const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateInputValue(ctx: *ValidationContext, value: ast.ValueNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = value;
    // TODO: add validation logic
}

fn validateObjectFields(ctx: *ValidationContext, fields: []const ast.ObjectFieldNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = fields;
    // TODO: add validation logic
}
