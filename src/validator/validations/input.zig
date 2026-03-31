const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateInputObjectDefinition(ctx: *ValidationContext, input_object: ast.InputObjectTypeDefinitionNode) std.mem.Allocator.Error!void {
    // UniqueInputFieldNamesRule
    if (input_object.fields) |fields| {
        try validateInputValueDefinitions(ctx, fields);
    }
}

pub fn validateInputObjectExtension(ctx: *ValidationContext, input_ext: ast.InputObjectTypeExtensionNode) std.mem.Allocator.Error!void {
    // UniqueInputFieldNamesRule
    if (input_ext.fields) |fields| {
        try validateInputValueDefinitions(ctx, fields);
    }
}

pub fn validateArgumentDefinitions(ctx: *ValidationContext, input_values: []const ast.InputValueDefinitionNode) std.mem.Allocator.Error!void {
    // UniqueInputFieldNamesRule
    try validateInputValueDefinitions(ctx, input_values);
}

fn validateInputValueDefinitions(ctx: *ValidationContext, input_values: []const ast.InputValueDefinitionNode) std.mem.Allocator.Error!void {
    var seen = std.StringHashMap(void).init(ctx.allocator);
    defer seen.deinit();

    for (input_values) |input_value| {
        const name = input_value.name.value;
        const entry = try seen.getOrPut(name);
        if (entry.found_existing) {
            try ctx.addError(.DuplicateInputField);
        }
    }
}
