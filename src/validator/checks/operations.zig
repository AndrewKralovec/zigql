const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

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

/// Unique operation names
///
/// A GraphQL document is only valid if all defined operations have unique names.
///
/// See https://spec.graphql.org/draft/#sec-Operation-Name-Uniqueness
pub fn checkUniqueOperationNames(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    // TODO: remove later. writing out a fn for the rule just to get it out there.
    // instead this data should be collected and checked in a single pass of definitions
    var known_operation_names = std.StringHashMap(void).init(ctx.allocator);
    defer known_operation_names.deinit();

    for (definitions) |definition| {
        switch (definition) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| {
                    if (op.name) |name| {
                        if (known_operation_names.contains(name.value)) {
                            try ctx.addError(.DuplicateOperationName);
                        } else {
                            try known_operation_names.put(name.value, {});
                        }
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

// UniqueOperationNames
test "should allow no operations for unique operation names" {
    try expectValid(checkUniqueOperationNames,
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow anonymous operation" {
    try expectValid(checkUniqueOperationNames,
        \\ {
        \\  field
        \\ }
    );
}

test "should allow one operation for unique operation names" {
    try expectValid(checkUniqueOperationNames,
        \\ query Foo {
        \\   field
        \\ }
    );
}

test "should allow multiple operations" {
    try expectValid(checkUniqueOperationNames,
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow multiple operations with different types" {
    try expectValid(checkUniqueOperationNames,
        \\ query Foo {
        \\   field
        \\ }
        \\ mutation Bar {
        \\   field
        \\ }
        \\ subscription Baz {
        \\   field
        \\ }
    );
}

test "should allow fragment and operation named the same" {
    try expectValid(checkUniqueOperationNames,
        \\ query Foo {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when operations have the same name" {
    try expectErrors(checkUniqueOperationNames,
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ query Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (mutation)" {
    try expectErrors(checkUniqueOperationNames,
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (subscription)" {
    try expectErrors(checkUniqueOperationNames,
        \\ query Foo {
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
