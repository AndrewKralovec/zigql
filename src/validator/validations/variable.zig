const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateVariableDefinitions(ctx: *ValidationContext, var_defs: []const ast.VariableDefinitionNode) !void {
    // UniqueVariableNamesRule
    try checkUniqueVariableNames(ctx, var_defs);
}

fn checkUniqueVariableNames(ctx: *ValidationContext, var_defs: []const ast.VariableDefinitionNode) !void {
    var seen_vars = std.StringHashMap(bool).init(ctx.allocator);
    defer seen_vars.deinit();

    for (var_defs) |var_def| {
        const name = var_def.variable.name.value;
        const entry = try seen_vars.getOrPut(name);
        if (entry.found_existing) {
            if (!entry.value_ptr.*) {
                entry.value_ptr.* = true;
                try ctx.addError(.DuplicateVariableName);
            }
        } else {
            entry.value_ptr.* = false;
        }
    }
}
