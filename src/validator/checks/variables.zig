const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

// Unique variable names
//
// A GraphQL operation is only valid if all its variables are uniquely named.
//
// See https://spec.graphql.org/draft/#sec-Variable-Uniqueness
pub fn checkUniqueVariableNames(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    // TODO: remove later. writing out a fn for the rule just to get it out there.
    // validation is doing multiple pass enhance laster
    for (definitions) |definition| {
        switch (definition) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| {
                    if (op.variable_definitions) |variable_definitions| {
                        try assertUniqueVariableNames(ctx, variable_definitions);
                    }
                },
                else => {},
            },
            else => {},
        }
    }
}

fn assertUniqueVariableNames(ctx: *ValidationContext, variable_definitions: ?[]const ast.VariableDefinitionNode) !void {
    const var_defs = variable_definitions orelse return;

    var seen = std.StringHashMap(bool).init(ctx.allocator);
    defer seen.deinit();

    for (var_defs) |var_def| {
        const name = var_def.variable.name.value;
        const entry = try seen.getOrPut(name);
        if (entry.found_existing) {
            if (!entry.value_ptr.*) {
                entry.value_ptr.* = true;
                try ctx.addError(.DuplicateVariableName);
            }
        } else {
            entry.value_ptr.* = false;
        }
    }
}

//
// Tests
//

const parse = @import("../../zig_ql.zig").parse;
const Schema = @import("../schema.zig").Schema;

// UniqueVariableNamesRule

test "should allow operations with no variables" {
    try expectValid(checkUniqueVariableNames,
        \\ query {
        \\   field
        \\ }
    );
}

test "should allow unique variable names" {
    try expectValid(checkUniqueVariableNames,
        \\ query A($x: Int, $y: String) { __typename }
        \\ query B($x: String, $y: Int) { __typename }
    );
}

test "should return errors for duplicate variables with different types" {
    try expectErrors(checkUniqueVariableNames,
        \\ query($bar: String, $foo: Int, $bar: Boolean) {
        \\   field
        \\ }
    , 1);
}

test "should return errors for duplicate variable names" {
    // NOTE: why expect 3 errors? errors are grouped, explained...
    // query A: $x x3 => grouped: 1 error, actual: 2 errors (after first $x)
    // query B: $x x2 => grouped: 1 error, actual: 1 error
    // query C: $x x2 => grouped: 1 error, actual: 1 error
    // total  :          grouped: 3,       actual: 4

    try expectErrors(checkUniqueVariableNames,
        \\ query A($x: Int, $x: Int, $x: String) { __typename }
        \\ query B($x: String, $x: Int) { __typename }
        \\ query C($x: Int, $x: Int) { __typename }
    , 3);
}

// Test helpers

fn expectErrors(
    comptime check_fn: fn (*ValidationContext, []const ast.DefinitionNode) anyerror!void,
    query_source: []const u8,
    expected_error_count: usize,
) !void {
    const allocator = std.testing.allocator;
    var schema = Schema.init(allocator);
    defer schema.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const query_doc = try parse(arena.allocator(), query_source);

    var ctx = ValidationContext.init(allocator, &schema);
    defer ctx.deinit();

    try check_fn(&ctx, query_doc.definitions);

    try std.testing.expectEqual(expected_error_count, ctx.errorCount());
}

fn expectValid(
    comptime check_fn: fn (*ValidationContext, []const ast.DefinitionNode) anyerror!void,
    query_source: []const u8,
) !void {
    try expectErrors(check_fn, query_source, 0);
}
