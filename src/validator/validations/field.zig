const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateField(ctx: *ValidationContext, field: ast.FieldNode) !void {
    _ = ctx;
    _ = field;
    // TODO: add validation logic
}
