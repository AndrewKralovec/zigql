const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directives.zig").validateDirectives;
const validateSelectionSet = @import("./selection_set.zig").validateSelectionSet;

pub fn validateFragment(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) !void {
    try validateDirectives(ctx, frag.directives);
    try validateSelectionSet(ctx, frag.selection_set);
}
