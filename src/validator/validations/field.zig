const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;
const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;
const validateArgumentDefinitions = @import("./input.zig").validateArgumentDefinitions;

pub fn validateField(ctx: *ValidationContext, field: ast.FieldNode, parent_type_name: ?[]const u8) anyerror!void {
    // first do all the validation that we can without knowing the type of the field
    try validateDirectives(ctx, field.directives);
    try validateArguments(ctx, field.arguments);

    // KnownArgumentNamesRule for field arguments
    try checkKnownFieldArguments(ctx, field, parent_type_name);

    if (field.selection_set) |nested| {
        // TODO: resolve field return type from schema to pass as parent_type_name
        // for now pass null since we dont have field return type resolution
        try validateSelectionSet(ctx, nested, null);
    }
}

fn checkKnownFieldArguments(ctx: *ValidationContext, field: ast.FieldNode, parent_type_name: ?[]const u8) !void {
    const args = field.arguments orelse return;
    const type_name = parent_type_name orelse return;

    const arg_defs = ctx.schema.getFieldArguments(type_name, field.name.value) orelse {
        // field not found in schema handled by FieldsOnCorrectTypeRule
        return;
    };

    for (args) |arg| {
        var found = false;
        for (arg_defs) |arg_def| {
            if (std.mem.eql(u8, arg.name.value, arg_def.name.value)) {
                found = true;
                break;
            }
        }
        if (!found) {
            try ctx.addError(.UndefinedArgument);
        }
    }
}

pub fn validateFieldDefinitions(ctx: *ValidationContext, fields: []const ast.FieldDefinitionNode) anyerror!void {
    for (fields) |field_def| {
        try validateFieldDefinition(ctx, field_def);
    }
}

pub fn validateFieldDefinition(ctx: *ValidationContext, field_def: ast.FieldDefinitionNode) anyerror!void {
    // UniqueInputFieldNamesRule
    if (field_def.arguments) |args| {
        try validateArgumentDefinitions(ctx, args);
    }
}

pub fn validateLeafFieldSelection(ctx: *ValidationContext, field: ast.FieldNode) anyerror!void {
    _ = ctx;
    _ = field;
    // TODO: add validation logic
}
