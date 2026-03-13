const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;

pub fn validateFragment(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) !void {
    try validateDirectives(ctx, frag.directives);
    try validateSelectionSet(ctx, frag.selection_set, frag.type_condition.name.value);
}

pub fn validateFragmentSpread(ctx: *ValidationContext, frag: ast.FragmentSpreadNode) !void {
    // KnownFragmentNamesRule
    if (!ctx.fragment_names.contains(frag.name.value)) {
        try ctx.addError(.UndefinedFragment);
    }

    try validateDirectives(ctx, frag.directives);
}

pub fn validateInlineFragment(ctx: *ValidationContext, frag: ast.InlineFragmentNode) anyerror!void {
    try validateDirectives(ctx, frag.directives);

    const parent_type: ?[]const u8 = if (frag.type_condition) |tc| tc.name.value else null;
    try validateSelectionSet(ctx, frag.selection_set, parent_type);
}

pub fn checkUnusedFragments(
    ctx: *ValidationContext,
    doc: ast.DocumentNode,
) !void {
    var used = std.StringHashMap(void).init(ctx.allocator);
    defer used.deinit();

    for (doc.definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| {
                    if (op.selection_set) |sel_set| {
                        try collectUsedFragments(sel_set, &ctx.fragment_defs, &used);
                    }
                },
                else => {},
            },
            else => {},
        }
    }

    var it = ctx.fragment_names.iterator();
    while (it.next()) |entry| {
        if (!used.contains(entry.key_ptr.*)) {
            try ctx.addError(.UnusedFragment);
        }
    }
}

fn collectUsedFragments(
    sel_set: ast.SelectionSetNode,
    fragment_defs: *const std.StringHashMap(ast.FragmentDefinitionNode),
    used: *std.StringHashMap(void),
) !void {
    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => |field| {
                if (field.selection_set) |nested| {
                    try collectUsedFragments(nested, fragment_defs, used);
                }
            },
            .FragmentSpread => |spread| {
                const name = spread.name.value;
                const entry = try used.getOrPut(name);
                if (!entry.found_existing) {
                    // walk selection set on first time entry
                    entry.value_ptr.* = {};
                    if (fragment_defs.get(name)) |frag_def| {
                        try collectUsedFragments(frag_def.selection_set, fragment_defs, used);
                    }
                }
            },
            .InlineFragment => |inline_frag| {
                try collectUsedFragments(inline_frag.selection_set, fragment_defs, used);
            },
        }
    }
}
