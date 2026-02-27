const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;

pub fn validateDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode) !void {
    const dirs = directives orelse return;
    for (dirs) |directive| {
        try validateArguments(ctx, directive.arguments);
    }
}
