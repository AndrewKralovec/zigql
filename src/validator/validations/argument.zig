const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateInputValue = @import("./value.zig").validateInputValue;

pub fn validateArguments(ctx: *ValidationContext, arguments: ?[]const ast.ArgumentNode) !void {
    const args = arguments orelse return;

    // UniqueArgumentNamesRule
    try validateUniqueArguments(ctx, args);

    // UniqueInputFieldNamesRule, validate input object values within arguments
    for (args) |arg| {
        try validateInputValue(ctx, arg.value);
    }
}

fn validateUniqueArguments(ctx: *ValidationContext, args: []const ast.ArgumentNode) !void {
    var seen_args = std.StringHashMap(bool).init(ctx.allocator);
    defer seen_args.deinit();

    for (args) |arg| {
        const name = arg.name.value;
        const entry = try seen_args.getOrPut(name);
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
