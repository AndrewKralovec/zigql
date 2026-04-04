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

    const directive_location: ast.DirectiveLocation = switch (operation.operation) {
        .Query => .Query,
        .Mutation => .Mutation,
        .Subscription => .Subscription,
    };
    try validateDirectives(ctx, operation.directives, directive_location);
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

pub fn validateSubscription(ctx: *ValidationContext, operation: ast.OperationDefinitionNode) !void {
    if (operation.operation != .Subscription) return;
    const sel_set = operation.selection_set orelse return;

    var visited = std.StringHashMap(void).init(ctx.allocator);
    defer visited.deinit();

    const root_field_count = try countSubscriptionRootFields(sel_set, &ctx.fragment_defs, &visited);

    if (root_field_count != 1) {
        try ctx.addError(.SubscriptionMultipleRootFields);
    }

    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => |field| {
                try checkSubscriptionField(ctx, field);
            },
            .InlineFragment => |inline_frag| {
                try checkSubscriptionDirectives(ctx, inline_frag.directives);
                for (inline_frag.selection_set.selections) |inner_sel| {
                    switch (inner_sel) {
                        .Field => |field| try checkSubscriptionField(ctx, field),
                        else => {},
                    }
                }
            },
            .FragmentSpread => |spread| {
                try checkSubscriptionDirectives(ctx, spread.directives);
                if (ctx.fragment_defs.get(spread.name.value)) |frag_def| {
                    for (frag_def.selection_set.selections) |inner_sel| {
                        switch (inner_sel) {
                            .Field => |field| try checkSubscriptionField(ctx, field),
                            else => {},
                        }
                    }
                }
            },
        }
    }
}

fn checkSubscriptionField(ctx: *ValidationContext, field: ast.FieldNode) !void {
    if (std.mem.eql(u8, field.name.value, "__schema") or std.mem.eql(u8, field.name.value, "__type")) {
        try ctx.addError(.SubscriptionIntrospection);
    }

    try checkSubscriptionDirectives(ctx, field.directives);
}

fn checkSubscriptionDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode) !void {
    const dirs = directives orelse return;
    for (dirs) |directive| {
        if (std.mem.eql(u8, directive.name.value, "skip") or std.mem.eql(u8, directive.name.value, "include")) {
            try ctx.addError(.SubscriptionConditionalSelection);
        }
    }
}

fn countSubscriptionRootFields(
    sel_set: ast.SelectionSetNode,
    fragment_defs: *const std.StringHashMap(ast.FragmentDefinitionNode),
    visited: *std.StringHashMap(void),
) !u32 {
    var count: u32 = 0;
    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => {
                count += 1;
            },
            .InlineFragment => |inline_frag| {
                count += try countSubscriptionRootFields(inline_frag.selection_set, fragment_defs, visited);
            },
            .FragmentSpread => |spread| {
                const name = spread.name.value;
                const entry = try visited.getOrPut(name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = {};
                    if (fragment_defs.get(name)) |frag_def| {
                        count += try countSubscriptionRootFields(frag_def.selection_set, fragment_defs, visited);
                    }
                }
            },
        }
    }
    return count;
}
