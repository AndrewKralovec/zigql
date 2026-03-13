const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateInputValue = @import("./value.zig").validateInputValue;

pub fn validateVariableDefinitions(ctx: *ValidationContext, var_defs: []const ast.VariableDefinitionNode) !void {
    var seen_vars = std.StringHashMap(bool).init(ctx.allocator);
    defer seen_vars.deinit();

    for (var_defs) |var_def| {
        if (var_def.directives) |directives| {
            try validateDirectives(ctx, directives);
        }

        // UniqueVariableNamesRule
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

        // UniqueInputFieldNamesRule, validate default values for input object uniqueness
        if (var_def.default_value) |default_val| {
            try validateInputValue(ctx, default_val);
        }
    }
}

pub fn validateUnusedVariables(ctx: *ValidationContext, operation: ast.OperationDefinitionNode) !void {
    const sel_set = operation.selection_set orelse return;

    var defined_vars = std.StringHashMap(void).init(ctx.allocator);
    defer defined_vars.deinit();

    if (operation.variable_definitions) |var_defs| {
        for (var_defs) |var_def| {
            try defined_vars.put(var_def.variable.name.value, {});
        }
    }

    var used_vars = std.StringHashMap(void).init(ctx.allocator);
    defer used_vars.deinit();

    var visited_fragments = std.StringHashMap(void).init(ctx.allocator);
    defer visited_fragments.deinit();

    try collectUsedVariables(sel_set, &ctx.fragment_defs, &used_vars, &visited_fragments);

    if (operation.directives) |directives| {
        try collectVariablesFromDirectives(directives, &used_vars);
    }

    // NoUnusedVariablesRule
    var def_it = defined_vars.iterator();
    while (def_it.next()) |entry| {
        if (!used_vars.contains(entry.key_ptr.*)) {
            try ctx.addError(.UnusedVariable);
        }
    }

    // NoUndefinedVariablesRule
    var used_it = used_vars.iterator();
    while (used_it.next()) |entry| {
        if (!defined_vars.contains(entry.key_ptr.*)) {
            try ctx.addError(.UndefinedVariable);
        }
    }
}

fn collectUsedVariables(
    sel_set: ast.SelectionSetNode,
    fragment_defs: *const std.StringHashMap(ast.FragmentDefinitionNode),
    used_vars: *std.StringHashMap(void),
    visited_fragments: *std.StringHashMap(void),
) !void {
    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => |field| {
                if (field.arguments) |args| {
                    for (args) |arg| {
                        try collectVariablesFromValue(arg.value, used_vars);
                    }
                }
                if (field.directives) |directives| {
                    try collectVariablesFromDirectives(directives, used_vars);
                }
                if (field.selection_set) |nested| {
                    try collectUsedVariables(nested, fragment_defs, used_vars, visited_fragments);
                }
            },
            .FragmentSpread => |spread| {
                if (spread.directives) |directives| {
                    try collectVariablesFromDirectives(directives, used_vars);
                }
                const name = spread.name.value;
                const entry = try visited_fragments.getOrPut(name);
                if (!entry.found_existing) {
                    entry.value_ptr.* = {};
                    if (fragment_defs.get(name)) |frag_def| {
                        if (frag_def.directives) |directives| {
                            try collectVariablesFromDirectives(directives, used_vars);
                        }
                        try collectUsedVariables(frag_def.selection_set, fragment_defs, used_vars, visited_fragments);
                    }
                }
            },
            .InlineFragment => |inline_frag| {
                if (inline_frag.directives) |directives| {
                    try collectVariablesFromDirectives(directives, used_vars);
                }
                try collectUsedVariables(inline_frag.selection_set, fragment_defs, used_vars, visited_fragments);
            },
        }
    }
}

fn collectVariablesFromDirectives(
    directives: []const ast.DirectiveNode,
    used_vars: *std.StringHashMap(void),
) !void {
    for (directives) |directive| {
        if (directive.arguments) |args| {
            for (args) |arg| {
                try collectVariablesFromValue(arg.value, used_vars);
            }
        }
    }
}

fn collectVariablesFromValue(
    value: ast.ValueNode,
    used_vars: *std.StringHashMap(void),
) !void {
    switch (value) {
        .Variable => |variable| {
            try used_vars.put(variable.name.value, {});
        },
        .List => |list| {
            for (list.values) |item| {
                try collectVariablesFromValue(item, used_vars);
            }
        },
        .Object => |obj| {
            for (obj.fields) |field| {
                try collectVariablesFromValue(field.value, used_vars);
            }
        },
        else => {},
    }
}
