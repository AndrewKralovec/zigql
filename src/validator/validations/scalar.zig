const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateScalarDefinition(ctx: *ValidationContext, scalar_def: ast.ScalarTypeDefinitionNode) anyerror!void {
    try validateDirectives(ctx, scalar_def.directives, .Scalar);
}
