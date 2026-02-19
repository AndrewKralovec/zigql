const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

/// Executable definitions
///
/// A GraphQL document is only valid for execution if all definitions are either
/// operation or fragment definitions.
///
/// See https://spec.graphql.org/draft/#sec-Executable-Definitions
pub fn checkExecutableDefinitions(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    for (definitions) |definition| {
        switch (definition) {
            .TypeSystemDefinition,
            .TypeSystemExtension,
            => {
                try ctx.addError(.NonExecutableDefinition);
            },
            else => {},
        }
    }
}

/// Lone anonymous operation
///
/// A GraphQL document is only valid if when it contains an anonymous operation
/// (the query short-hand) that it contains only that one operation definition.
///
/// See https:///spec.graphql.org/draft/#sec-Lone-Anonymous-Operation
pub fn checkLoneAnonymousOperation(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    // TODO: remove later. writing out a fn for the rule just to get it out there.
    // instead this data should be collected and checked in a single pass of definitions
    var operation_count: u32 = 0;
    for (definitions) |definition| {
        switch (definition) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => {
                    operation_count += 1;
                },
                else => {},
            },
            else => {},
        }
    }

    if (operation_count <= 1) return;

    for (definitions) |definition| {
        switch (definition) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| {
                    if (op.name == null) {
                        try ctx.addError(.ManyAnonymousOperations);
                    }
                },
                else => {},
            },
            else => {},
        }
    }
}

//
// Tests
//

const parse = @import("../../zig_ql.zig").parse;
const Schema = @import("../schema.zig").Schema;

// ExecutableDefinitions

test "should allow executable definitions with only operations" {
    try expectValid(checkExecutableDefinitions,
        \\ query Foo {
        \\   user {
        \\     name
        \\   }
        \\ }
    );
}

test "should allow executable definitions with operation and fragment" {
    try expectValid(checkExecutableDefinitions,
        \\ query Foo {
        \\   user {
        \\     name
        \\     ...Frag
        \\   }
        \\ }
        \\ fragment Frag on User {
        \\   name
        \\ }
    );
}

test "should return for executable definitions with type definition" {
    try expectErrors(checkExecutableDefinitions,
        \\ query Foo {
        \\   user {
        \\     name
        \\   }
        \\ }
        \\ type User {
        \\   name: String
        \\ }
        \\ extend type Guest {
        \\   role: String
        \\ }
    , 2);
}

test "should return for executable definitions with schema definition" {
    try expectErrors(checkExecutableDefinitions,
        \\ schema {
        \\   query: Query
        \\ }
        \\ type Query {
        \\   test: String
        \\ }
        \\ extend schema @directive
    , 3);
}

// LoneAnonymousOperation

test "should allow no operations" {
    try expectValid(checkLoneAnonymousOperation,
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow one operation" {
    try expectValid(checkLoneAnonymousOperation,
        \\ {
        \\   field
        \\ }
    );
}

test "should allow multiple named operations" {
    try expectValid(checkLoneAnonymousOperation,
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow anonymous operation with fragment" {
    try expectValid(checkLoneAnonymousOperation,
        \\ {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when multiple anon operations are used" {
    try expectErrors(checkLoneAnonymousOperation,
        \\ {
        \\   fieldA
        \\ }
        \\ {
        \\   fieldB
        \\ }
    , 2);
}

test "should return errors when anon operation with a mutation are used" {
    try expectErrors(checkLoneAnonymousOperation,
        \\ {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when anon operation with a subscription are used" {
    try expectErrors(checkLoneAnonymousOperation,
        \\ {
        \\   fieldA
        \\ }
        \\ subscription Foo {
        \\   fieldB
        \\ }
    , 1);
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
