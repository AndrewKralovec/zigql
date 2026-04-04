const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;
const schema_mod = @import("../schema.zig");

const validateArguments = @import("./argument.zig").validateArguments;

const BuiltinDirective = struct {
    arguments: []const []const u8,
    repeatable: bool,
    locations: []const []const u8,
};

/// Built-in spec directives with their arguments, repeatability, and valid locations.
///
/// See https://spec.graphql.org/October2021/#sec-Type-System.Directives
const specified_directives = std.StaticStringMap(BuiltinDirective).initComptime(.{
    .{ "skip", BuiltinDirective{
        .arguments = &.{"if"},
        .repeatable = false,
        .locations = &.{ "FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT" },
    } },
    .{ "include", BuiltinDirective{
        .arguments = &.{"if"},
        .repeatable = false,
        .locations = &.{ "FIELD", "FRAGMENT_SPREAD", "INLINE_FRAGMENT" },
    } },
    .{ "deprecated", BuiltinDirective{
        .arguments = &.{"reason"},
        .repeatable = false,
        .locations = &.{ "FIELD_DEFINITION", "ARGUMENT_DEFINITION", "INPUT_FIELD_DEFINITION", "ENUM_VALUE" },
    } },
    .{ "specifiedBy", BuiltinDirective{
        .arguments = &.{"url"},
        .repeatable = false,
        .locations = &.{"SCALAR"},
    } },
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

pub fn validateDirectives(ctx: *ValidationContext, directives: ?[]const ast.DirectiveNode, location: []const u8) !void {
    const dirs = directives orelse return;

    var seen_directives = std.StringHashMap(void).init(ctx.allocator);
    defer seen_directives.deinit();

    for (dirs) |directive| {
        try validateArguments(ctx, directive.arguments);

        // KnownArgumentNamesRule
        try checkKnownDirectiveArguments(ctx, directive);

        // KnownDirectivesRule
        const is_defined = try checkDirectiveDefined(ctx, directive.name.value);

        // DirectivesAreInValidLocationsRule
        if (is_defined) {
            try checkDirectiveLocation(ctx, directive.name.value, location);
        }

        // UniqueDirectivesPerLocationRule
        try checkDirectiveUniqueness(ctx, directive.name.value, &seen_directives);
    }
}

fn checkKnownDirectiveArguments(ctx: *ValidationContext, directive: ast.DirectiveNode) !void {
    const args = directive.arguments orelse return;

    // check built-in spec directives
    if (specified_directives.get(directive.name.value)) |dir_info| {
        for (args) |arg| {
            var found = false;
            for (dir_info.arguments) |known_arg| {
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
}

/// Returns true if the directive is defined (built-in or schema), false otherwise.
fn checkDirectiveDefined(ctx: *ValidationContext, directive_name: []const u8) !bool {
    if (specified_directives.has(directive_name)) {
        return true;
    }

    if (ctx.schema.getDirective(directive_name) != null) {
        return true;
    }

    try ctx.addError(.UndefinedDirective);
    return false;
}

fn checkDirectiveLocation(ctx: *ValidationContext, directive_name: []const u8, location: []const u8) !void {
    // check built-in directives
    if (specified_directives.get(directive_name)) |dir_info| {
        for (dir_info.locations) |valid_location| {
            if (std.mem.eql(u8, location, valid_location)) {
                return;
            }
        }
        try ctx.addError(.UnsupportedDirectiveLocation);
        return;
    }

    // check schema-defined directives
    if (ctx.schema.getDirective(directive_name)) |dir_info| {
        for (dir_info.locations) |loc_node| {
            if (std.mem.eql(u8, location, loc_node.value)) {
                return;
            }
        }
        try ctx.addError(.UnsupportedDirectiveLocation);
    }
}

fn checkDirectiveUniqueness(ctx: *ValidationContext, directive_name: []const u8, seen: *std.StringHashMap(void)) !void {
    const entry = try seen.getOrPut(directive_name);
    if (!entry.found_existing) return;

    // check if repeatable
    if (specified_directives.get(directive_name)) |dir_info| {
        if (dir_info.repeatable) return;
    } else if (ctx.schema.getDirective(directive_name)) |dir_info| {
        if (dir_info.repeatable) return;
    }

    try ctx.addError(.DuplicateDirective);
}
