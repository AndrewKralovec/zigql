const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateInputObjectDefinition(ctx: *ValidationContext, input_object: ast.InputObjectTypeDefinitionNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = input_object;
    // TODO: add validation logic
}

pub fn validateArgumentDefinitions(ctx: *ValidationContext, input_values: ast.InputValueDefinitionNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = input_values;
    // TODO: add validation logic
}

pub fn validateInputValueDefinitions(ctx: *ValidationContext, input_values: ast.InputValueDefinitionNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = input_values;
    // TODO: add validation logic
}
