const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

const validateArguments = @import("./argument.zig").validateArguments;

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

pub fn validateDirectivesDefinition(ctx: *ValidationContext, def: ast.DirectiveDefinitionNode) !void {
    _ = ctx;
    _ = def;
    // TODO: add validation logic
    // TODO: try validateTypeSystemName(ctx, def.name, "");
    // TODO: try validateArgumentDefinitions(ctx, args);
}

pub fn validateDirectivesDefinitions(ctx: *ValidationContext) !void {
    _ = ctx;
    // TODO: add validation logic
}

pub fn validateDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode) !void {
    const dirs = directives orelse return;

    // var seen_directives = std.StringHashMap(bool).init(ctx.allocator);
    // defer seen_directives.deinit();

    for (dirs) |directive| {
        try validateArguments(ctx, directive.arguments);

        // KnownArgumentNamesRule
        try checkKnownDirectiveArguments(ctx, directive);
    }
}

fn checkKnownDirectiveArguments(ctx: *ValidationContext, directive: ast.DirectiveNode) !void {
    const args = directive.arguments orelse return;

    // check built in spec directives
    if (specified_directives.get(directive.name.value)) |known_args| {
        for (args) |arg| {
            var found = false;
            for (known_args) |known_arg| {
                if (std.mem.eql(u8, arg.name.value, known_arg)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try ctx.addError(.UndefinedArgument);
            }
        }
        return;
    }

    // check custom directive definitions from schema
    if (ctx.schema.getDirectiveArguments(directive.name.value)) |arg_defs| {
        for (args) |arg| {
            var found = false;
            for (arg_defs) |arg_def| {
                if (std.mem.eql(u8, arg.name.value, arg_def.name.value)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try ctx.addError(.UndefinedArgument);
            }
        }
    }
    // KnownDirectivesRule, handles directives not found in built ins or schema
}
