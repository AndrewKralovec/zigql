const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;
const validateVariableDefinitions = @import("./variable.zig").validateVariableDefinitions;
const validateUnusedVariables = @import("./variable.zig").validateUnusedVariables;

pub fn validateOperation(ctx: *ValidationContext, operation: ast.OperationDefinitionNode) !void {
    // LoneAnonymousOperationRule, count operations
    ctx.operation_count += 1;
    if (operation.name == null) {
        ctx.anonymous_operation_count += 1;
    }

    // UniqueOperationNamesRule
    if (operation.name) |name| {
        if (ctx.operation_names.contains(name.value)) {
            try ctx.addError(.DuplicateOperationName);
        } else {
            try ctx.operation_names.put(name.value, {});
        }
    }

    try validateDirectives(ctx, operation.directives);
    if (operation.variable_definitions) |var_defs| {
        try validateVariableDefinitions(ctx, var_defs);
    }

    // TODO: support custom root type names
    const root_type_name: ?[]const u8 = switch (operation.operation) {
        .Query => "Query",
        .Mutation => "Mutation",
        .Subscription => "Subscription",
    };

    try validateUnusedVariables(ctx, operation);
    if (operation.selection_set) |sel_set| {
        try validateSelectionSet(ctx, sel_set, root_type_name);
    }
}
