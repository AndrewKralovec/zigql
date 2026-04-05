const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const schema_mod = @import("../schema.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;

fn getPossibleTypes(
    allocator: std.mem.Allocator,
    type_def: schema_mod.TypeDefinition,
    type_name: []const u8,
    schema: *const schema_mod.Schema,
) !std.StringHashMap(void) {
    var result = std.StringHashMap(void).init(allocator);
    errdefer result.deinit();

    switch (type_def) {
        .Object => {
            try result.put(type_name, {});
        },
        .Interface => {
            var type_iter = schema.types.iterator();
            while (type_iter.next()) |entry| {
                if (entry.value_ptr.* == .Object) {
                    const obj = entry.value_ptr.Object;
                    if (obj.interfaces) |ifaces| {
                        for (ifaces) |iface| {
                            if (std.mem.eql(u8, iface.name.value, type_name)) {
                                try result.put(entry.key_ptr.*, {});
                                break;
                            }
                        }
                    }
                }
            }
        },
        .Union => |union_def| {
            if (union_def.members) |members| {
                for (members) |member| {
                    try result.put(member.name.value, {});
                }
            }
        },
        .Scalar, .Enum, .InputObject => {},
    }

    return result;
}

fn areTypesCompatible(
    allocator: std.mem.Allocator,
    parent_type_name: []const u8,
    condition_type_name: []const u8,
    schema: *const schema_mod.Schema,
) !bool {
    if (std.mem.eql(u8, parent_type_name, condition_type_name)) {
        return true;
    }

    const parent_type = schema.getType(parent_type_name) orelse return false;
    const condition_type = schema.getType(condition_type_name) orelse return false;

    var parent_types = try getPossibleTypes(allocator, parent_type, parent_type_name, schema);
    defer parent_types.deinit();

    var condition_types = try getPossibleTypes(allocator, condition_type, condition_type_name, schema);
    defer condition_types.deinit();

    var iter = condition_types.keyIterator();
    while (iter.next()) |key| {
        if (parent_types.contains(key.*)) {
            return true;
        }
    }

    return false;
}

pub fn validateInlineFragment(
    ctx: *ValidationContext,
    frag: ast.InlineFragmentNode,
    parent_type: ?[]const u8,
) anyerror!void {
    try validateDirectives(ctx, frag.directives, .InlineFragment);

    const selection_type: ?[]const u8 = if (frag.type_condition) |tc| blk: {
        if (ctx.schema.getType(tc.name.value)) |type_def| {
            const is_composite = switch (type_def) {
                .Object, .Interface, .Union => true,
                .Scalar, .Enum, .InputObject => false,
            };
            if (!is_composite) {
                try ctx.addError(.InvalidFragmentTarget);
                return;
            }

            if (parent_type) |parent| {
                if (ctx.schema.getType(parent)) |_| {
                    const compatible = try areTypesCompatible(
                        ctx.allocator,
                        parent,
                        tc.name.value,
                        ctx.schema,
                    );
                    if (!compatible) {
                        try ctx.addError(.InvalidFragmentSpread);
                    }
                }
            }
        }

        break :blk tc.name.value;
    } else parent_type;

    try validateSelectionSet(ctx, frag.selection_set, selection_type);
}

pub fn validateFragmentSpread(
    ctx: *ValidationContext,
    frag: ast.FragmentSpreadNode,
    parent_type: ?[]const u8,
) !void {
    if (!ctx.fragment_defs.contains(frag.name.value)) {
        try ctx.addError(.UndefinedFragment);
    }

    try validateDirectives(ctx, frag.directives, .FragmentSpread);

    if (parent_type) |parent| {
        if (ctx.fragment_defs.get(frag.name.value)) |frag_def| {
            const condition = frag_def.type_condition.name.value;

            const parent_exists = ctx.schema.getType(parent) != null;
            const condition_exists = ctx.schema.getType(condition) != null;

            if (parent_exists and condition_exists) {
                const compatible = try areTypesCompatible(
                    ctx.allocator,
                    parent,
                    condition,
                    ctx.schema,
                );
                if (!compatible) {
                    try ctx.addError(.InvalidFragmentSpread);
                }
            }
        }
    }
}

pub fn validateFragmentDefinition(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) !void {
    try validateDirectives(ctx, frag.directives, .FragmentDefinition);

    const type_condition = frag.type_condition.name.value;

    if (ctx.schema.getType(type_condition)) |type_def| {
        const is_composite = switch (type_def) {
            .Object, .Interface, .Union => true,
            .Scalar, .Enum, .InputObject => false,
        };
        if (!is_composite) {
            try ctx.addError(.InvalidFragmentTarget);
            return;
        }
    }

    try validateSelectionSet(ctx, frag.selection_set, type_condition);
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

    var it = ctx.fragment_defs.iterator();
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
