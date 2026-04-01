const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateEnumDefinition(ctx: *ValidationContext, enum_def: ast.EnumTypeDefinitionNode) std.mem.Allocator.Error!void {
    // TODO: validate directives on enum definition (DirectiveLocation.Enum)

    if (enum_def.values) |values| {
        for (values) |value| {
            try validateEnumValue(ctx, value);
        }
    } else {
        try ctx.addError(.EmptyValueSet);
    }
}

pub fn validateEnumExtension(ctx: *ValidationContext, enum_ext: ast.EnumTypeExtensionNode) std.mem.Allocator.Error!void {
    if (enum_ext.values) |values| {
        for (values) |value| {
            try validateEnumValue(ctx, value);
        }
    }
}

fn validateEnumValue(ctx: *ValidationContext, enum_val: ast.EnumValueDefinitionNode) std.mem.Allocator.Error!void {
    if (std.mem.startsWith(u8, enum_val.name.value, "__")) {
        try ctx.addError(.ReservedName);
    }
    // TODO: validate directives on enum value (DirectiveLocation.EnumValue)
}
