const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateArguments(ctx: *ValidationContext, arguments: ?[]const ast.ArgumentNode) !void {
    const args = arguments orelse return;
    try checkUniqueArguments(ctx, args);
}

fn checkUniqueArguments(ctx: *ValidationContext, args: []const ast.ArgumentNode) !void {
    var seen_args = std.StringHashMap(void).init(ctx.allocator);
    defer seen_args.deinit();

    for (args) |arg| {
        const name = arg.name.value;
        const entry = try seen_args.getOrPut(name);
        if (entry.found_existing) {
            try ctx.addError(.DuplicateArgumentName);
        }
    }
}
