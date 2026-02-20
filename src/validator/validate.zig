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

// ExecutableDefinitions

// ExecutableDefinitions

test "should allow executable definitions with only operations" {
    try expectValid(
        \\ query Foo {
        \\   user {
        \\     name
        \\   }
        \\ }
    );
}

test "should allow executable definitions with operation and fragment" {
    try expectValid(
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
    try expectErrors(
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
    try expectErrors(
        \\ schema {
        \\   query: Query
        \\ }
        \\ type Query {
        \\   test: String
        \\ }
        \\ extend schema @directive
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
