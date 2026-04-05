const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;
const validateDirectives = @import("./directive.zig").validateDirectives;
const validateField = @import("./field.zig").validateField;
const validateInlineFragment = @import("./fragment.zig").validateInlineFragment;
const validateFragmentSpread = @import("./fragment.zig").validateFragmentSpread;

pub fn validateSelectionSet(ctx: *ValidationContext, sel_set: ast.SelectionSetNode, parent_type_name: ?[]const u8) !void {
    for (sel_set.selections) |sel| {
        switch (sel) {
            .Field => |field| {
                try validateField(ctx, field, parent_type_name);
            },
            .FragmentSpread => |frag_spread| {
                try validateFragmentSpread(ctx, frag_spread, parent_type_name);
            },
            .InlineFragment => |inline_frag| {
                try validateInlineFragment(ctx, inline_frag, parent_type_name);
            },
        }
    }
}
