const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;
const validateDirectives = @import("./directive.zig").validateDirectives;
const validateSelectionSet = @import("./selection.zig").validateSelectionSet;

pub fn validateField(ctx: *ValidationContext, field: ast.FieldNode) anyerror!void {
    // first do all the validation that we can without knowing the type of the field.

    try validateDirectives(ctx, field.directives);

    try validateArguments(ctx, field.arguments);
    if (field.selection_set) |nested| {
        try validateSelectionSet(ctx, nested);
    }
}
