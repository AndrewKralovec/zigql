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
    // TODO: the graphql-js implementation does not group by name, like UniqueArgumentNamesRule,
    // but these should be consistent. think about if we want all of these grouped by name or just summed.
    var seen_fields = std.StringHashMap(bool).init(ctx.allocator);
    defer seen_fields.deinit();

    for (fields) |field| {
        const name = field.name.value;
        const entry = try seen_fields.getOrPut(name);
        if (entry.found_existing) {
            if (!entry.value_ptr.*) {
                entry.value_ptr.* = true;
                try ctx.addError(.DuplicateInputField);
            }
        } else {
            entry.value_ptr.* = false;
        }

        // handle nested input objects
        try validateInputValue(ctx, field.value);
    }
}
