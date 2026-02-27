const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directives.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;
const validateVariableDefinitions = @import("variable.zig").validateVariableDefinitions;

pub fn validateOperation(ctx: *ValidationContext, op: ast.OperationDefinitionNode) !void {
    // LoneAnonymousOperationRule, count operations
    ctx.operation_count += 1;
    if (op.name == null) {
        ctx.anonymous_operation_count += 1;
    }

    // UniqueOperationNamesRule
    if (op.name) |name| {
        if (ctx.operation_names.contains(name.value)) {
            try ctx.addError(.DuplicateOperationName);
        } else {
            try ctx.operation_names.put(name.value, {});
        }
    }

    if (op.variable_definitions) |var_defs| {
        try validateVariableDefinitions(ctx, var_defs);
    }

    try validateDirectives(ctx, op.directives);
    if (op.selection_set) |sel_set| {
        try validateSelectionSet(ctx, sel_set);
    }
}
