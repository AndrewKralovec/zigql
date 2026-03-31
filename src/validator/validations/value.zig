const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

// TODO: add schema validation (field exists, type correctness, required fields, etc) once schema support is implemented.
pub fn validateInputValue(ctx: *ValidationContext, value: ast.ValueNode) anyerror!void {
    switch (value) {
        .Object => |obj| {
            // UniqueInputFieldNamesRule
            try validateObjectFields(ctx, obj.fields);
        },
        .List => |list| {
            for (list.values) |item| {
                try validateInputValue(ctx, item);
            }
        },
        else => {},
    }
}

fn validateObjectFields(ctx: *ValidationContext, fields: []const ast.ObjectFieldNode) !void {
    var seen_fields = std.StringHashMap(void).init(ctx.allocator);
    defer seen_fields.deinit();

    for (fields) |field| {
        const name = field.name.value;
        const entry = try seen_fields.getOrPut(name);
        if (entry.found_existing) {
            try ctx.addError(.DuplicateInputField);
        }

        // handle nested input objects
        try validateInputValue(ctx, field.value);
    }
}

pub fn validateValues(
    ctx: *ValidationContext,
    arg_def: ast.InputValueDefinitionNode,
    arg: ast.ArgumentNode,
    var_defs: ?[]const ast.VariableDefinitionNode,
) anyerror!void {
    _ = arg_def;
    _ = var_defs;

    // UniqueInputFieldNamesRule: check for duplicate fields in input object values.
    // TODO: this will be subsumed by full value_of_correct_type validation,
    // which also checks type coercion, enum values, required fields, etc.
    try validateInputValue(ctx, arg.value);
}
