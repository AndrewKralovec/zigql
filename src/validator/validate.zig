const std = @import("std");
const ast = @import("../grammar/ast.zig");
const ValidationContext = @import("validation_context.zig").ValidationContext;

// // const arguments_checks = @import("checks/arguments.zig");
// // const document_checks = @import("checks/document.zig");
// // const fragments_checks = @import("checks/fragments.zig");
// // const operations_checks = @import("checks/operations.zig");
// // const variables_checks = @import("checks/variables.zig");

// // pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
// //     try document_checks.checkExecutableDefinitions(ctx, doc.definitions);
// //     try operations_checks.checkLoneAnonymousOperation(ctx, doc.definitions);
// //     try operations_checks.checkUniqueOperationNames(ctx, doc.definitions);
// //     try fragments_checks.checkUniqueFragmentNames(ctx, doc.definitions);
// //     try variables_checks.checkUniqueVariableNames(ctx, doc.definitions);
// //     try arguments_checks.checkUniqueArguments(ctx, doc.definitions);
// // }

const document_validation = @import("validations/document.zig");

pub fn validateDocument(ctx: *ValidationContext, doc: ast.DocumentNode) !void {
    try document_validation.validateDocument(ctx, doc);
}

//
// Tests
//

const parse = @import("../zig_ql.zig").parse;
const Schema = @import("./schema.zig").Schema;

// LoneAnonymousOperation

test "should allow no operations" {
    try expectValid(
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow one operation" {
    try expectValid(
        \\ {
        \\   field
        \\ }
    );
}

test "should allow multiple named operations" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow anonymous operation with fragment" {
    try expectValid(
        \\ {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when multiple anon operations are used" {
    try expectErrors(
        \\ {
        \\   fieldA
        \\ }
        \\ {
        \\   fieldB
        \\ }
    , 2);
}

test "should return errors when anon operation with a mutation are used" {
    try expectErrors(
        \\ {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when anon operation with a subscription are used" {
    try expectErrors(
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
    try expectValid(
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow anonymous operation" {
    try expectValid(
        \\ {
        \\  field
        \\ }
    );
}

test "should allow one operation for unique operation names" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
    );
}

test "should allow multiple operations" {
    try expectValid(
        \\ query Foo {
        \\   field
        \\ }
        \\ query Bar {
        \\   field
        \\ }
    );
}

test "should allow multiple operations with different types" {
    try expectValid(
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
    try expectValid(
        \\ query Foo {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when operations have the same name" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ query Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (mutation)" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ mutation Foo {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when operations ops of same name and different types (subscription)" {
    try expectErrors(
        \\ query Foo {
        \\   fieldA
        \\ }
        \\ subscription Foo {
        \\   fieldB
        \\ }
    , 1);
}

// UniqueVariableNamesRule

test "should allow operations with no variables" {
    try expectValid(
        \\ query {
        \\   field
        \\ }
    );
}

test "should allow unique variable names" {
    try expectValid(
        \\ query A($x: Int, $y: String) { __typename }
        \\ query B($x: String, $y: Int) { __typename }
    );
}

test "should return errors for duplicate variables with different types" {
    try expectErrors(
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

    try expectErrors(
        \\ query A($x: Int, $x: Int, $x: String) { __typename }
        \\ query B($x: String, $x: Int) { __typename }
        \\ query C($x: Int, $x: Int) { __typename }
    , 3);
}

// Test helpers

fn expectErrors(
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

    try validateDocument(&ctx, query_doc);

    try std.testing.expectEqual(expected_error_count, ctx.errorCount());
}

fn expectValid(
    query_source: []const u8,
) !void {
    try expectErrors(query_source, 0);
}
