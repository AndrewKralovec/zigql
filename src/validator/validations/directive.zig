const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

// TODO: find out what has better performance, the custom map (keyword example) or the StaticStringMap.
/// Built in spec directive arguments.
///
/// See https://spec.graphql.org/October2021/#sec-Type-System.Directives
const specified_directives = std.StaticStringMap([]const []const u8).initComptime(.{
    .{ "skip", &.{"if"} },
    .{ "include", &.{"if"} },
    .{ "deprecated", &.{"reason"} },
    .{ "specifiedBy", &.{"url"} },
});

pub fn validateDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode) !void {
    _ = ctx;
    _ = directives;
    // TODO: add validation logic
}
