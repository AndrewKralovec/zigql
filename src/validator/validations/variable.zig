const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateVariableDefinitions(ctx: *ValidationContext, var_defs: []const ast.VariableDefinitionNode) !void {
    _ = ctx;
    _ = var_defs;
    // TODO: add validation logic
}
