const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;

pub fn validateFragment(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) !void {
    // TODO: FragmentsOnCompositeTypesRule

    try validateDirectives(ctx, frag.directives);
    try validateSelectionSet(ctx, frag.selection_set);
}

pub fn validateFragmentSpread(ctx: *ValidationContext, frag: ast.FragmentSpreadNode) !void {
    // KnownFragmentNamesRule
    if (!ctx.fragment_names.contains(frag.name.value)) {
        try ctx.addError(.UndefinedFragment);
    }

    // TODO: NoUnusedFragmentsRule
    // TODO: NoFragmentCyclesRule

    try validateDirectives(ctx, frag.directives);
}

pub fn validateInlineFragment(ctx: *ValidationContext, frag: ast.InlineFragmentNode) anyerror!void {
    try validateDirectives(ctx, frag.directives);
    try validateSelectionSet(ctx, frag.selection_set);
}
