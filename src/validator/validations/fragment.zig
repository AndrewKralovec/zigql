const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;

pub fn validateFragment(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) !void {
    // UniqueFragmentNamesRule
    const name = frag.name.value;
    if (ctx.fragment_names.contains(name)) {
        try ctx.addError(.DuplicateFragmentName);
    } else {
        try ctx.fragment_names.put(name, {});
    }

    try validateDirectives(ctx, frag.directives);
    try validateSelectionSet(ctx, frag.selection_set);
}
