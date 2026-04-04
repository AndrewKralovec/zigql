const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateInputObjectDefinition(ctx: *ValidationContext, input_object: ast.InputObjectTypeDefinitionNode) anyerror!void {
    try validateDirectives(ctx, input_object.directives, "INPUT_OBJECT");
    // UniqueInputFieldNamesRule
    if (input_object.fields) |fields| {
        try validateInputValueDefinitions(ctx, fields, "INPUT_FIELD_DEFINITION");
    }
}

pub fn validateInputObjectExtension(ctx: *ValidationContext, input_ext: ast.InputObjectTypeExtensionNode) anyerror!void {
    // UniqueInputFieldNamesRule
    if (input_ext.fields) |fields| {
        try validateInputValueDefinitions(ctx, fields, "INPUT_FIELD_DEFINITION");
    }
}

pub fn validateArgumentDefinitions(ctx: *ValidationContext, input_values: []const ast.InputValueDefinitionNode) anyerror!void {
    // UniqueInputFieldNamesRule
    try validateInputValueDefinitions(ctx, input_values, "ARGUMENT_DEFINITION");
}

fn validateInputValueDefinitions(ctx: *ValidationContext, input_values: []const ast.InputValueDefinitionNode, location: []const u8) anyerror!void {
    var seen = std.StringHashMap(void).init(ctx.allocator);
    defer seen.deinit();

    for (input_values) |input_value| {
        const name = input_value.name.value;
        const entry = try seen.getOrPut(name);
        if (entry.found_existing) {
            try ctx.addError(.DuplicateInputField);
        }

        try validateDirectives(ctx, input_value.directives, location);
    }
}
