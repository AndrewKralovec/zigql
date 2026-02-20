const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn checkUniqueArgs(ctx: *ValidationContext, arguments: ?[]const ast.ArgumentNode) !void {
    const args = arguments orelse return;
    ctx.seen_names.clearRetainingCapacity();

    for (args) |arg| {
        const name = arg.name.value;
        const entry = try ctx.seen_names.getOrPut(name);
        if (entry.found_existing) {
            if (!entry.value_ptr.*) {
                entry.value_ptr.* = true;
                try ctx.addError(.DuplicateArgumentName);
            }
        } else {
            entry.value_ptr.* = false;
        }
    }
}
