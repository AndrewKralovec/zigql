const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const checkUniqueArgs = @import("./argument.zig").checkUniqueArgs;

pub fn validateDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode) !void {
    const dirs = directives orelse return;
    for (dirs) |directive| {
        try checkUniqueArgs(ctx, directive.arguments);
    }
}
