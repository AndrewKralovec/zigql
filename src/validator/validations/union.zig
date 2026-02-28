const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateUnionDefinition(ctx: *ValidationContext, union_def: ast.UnionTypeDefinitionNode) std.mem.Allocator.Error!void {
    _ = ctx;
    _ = union_def;
    // TODO: add validation logic
}
