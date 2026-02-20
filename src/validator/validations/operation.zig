const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directives.zig").validateDirectives;
const validateSelectionSet = @import("./selection_set.zig").validateSelectionSet;

pub fn validateOperation(ctx: *ValidationContext, op: ast.OperationDefinitionNode) void {
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

    // UniqueVariableNamesRule
    if (op.variable_definitions) |var_defs| {
        ctx.seen_names.clearRetainingCapacity();
        for (var_defs) |var_def| {
            const name = var_def.variable.name.value;
            const entry = try ctx.seen_names.getOrPut(name);
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

    try validateDirectives(op.directives);
    if (op.selection_set) |sel_set| {
        try validateSelectionSet(sel_set);
    }
}
