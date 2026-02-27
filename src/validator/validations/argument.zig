const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

pub fn validateArguments(ctx: *ValidationContext, arguments: ?[]const ast.ArgumentNode) !void {
    const args = arguments orelse return;

    ctx.seen_names.clearRetainingCapacity(); // clear for UniqueArgumentNamesRule
    for (args) |arg| {
        // UniqueArgumentNamesRule
        try checkArgUniqueness(ctx, arg.name.value);
    }
}

pub fn checkArgUniqueness(ctx: *ValidationContext, name: []const u8) !void {
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
