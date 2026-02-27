const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;
const validateDirectives = @import("./directive.zig").validateDirectives;

pub fn validateSelectionSet(ctx: *ValidationContext, sel_set: ast.SelectionSetNode) !void {
    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => |field| {
                try validateArguments(ctx, field.arguments);
                try validateDirectives(ctx, field.directives);
                if (field.selection_set) |nested| {
                    try validateSelectionSet(ctx, nested);
                }
            },
            .FragmentSpread => |spread| {
                try validateDirectives(ctx, spread.directives);
            },
            .InlineFragment => |inline_frag| {
                try validateDirectives(ctx, inline_frag.directives);
                try validateSelectionSet(ctx, inline_frag.selection_set);
            },
        }
    }
}
