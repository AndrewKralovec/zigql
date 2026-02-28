const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateScalarDefinition(ctx: *ValidationContext, scalar_def: ast.ScalarTypeDefinitionNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = scalar_def;
    // TODO: add validation logic
}
