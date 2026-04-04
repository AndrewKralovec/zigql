const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateEnumDefinition(ctx: *ValidationContext, enum_def: ast.EnumTypeDefinitionNode) anyerror!void {
    try validateDirectives(ctx, enum_def.directives, "ENUM");

    if (enum_def.values) |values| {
        for (values) |value| {
            try validateEnumValue(ctx, value);
        }
    } else {
        try ctx.addError(.EmptyValueSet);
    }
}

pub fn validateEnumExtension(ctx: *ValidationContext, enum_ext: ast.EnumTypeExtensionNode) anyerror!void {
    if (enum_ext.values) |values| {
        for (values) |value| {
            try validateEnumValue(ctx, value);
        }
    }
}

fn validateEnumValue(ctx: *ValidationContext, enum_val: ast.EnumValueDefinitionNode) anyerror!void {
    if (std.mem.startsWith(u8, enum_val.name.value, "__")) {
        try ctx.addError(.ReservedName);
    }
    try validateDirectives(ctx, enum_val.directives, "ENUM_VALUE");
}
