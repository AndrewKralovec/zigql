const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

// Unique fragment names
//
// A GraphQL document is only valid if all defined fragments have unique names.
//
// See https://spec.graphql.org/draft/#sec-Fragment-Name-Uniqueness
pub fn checkUniqueFragmentNames(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    // TODO: remove later. writing out a fn for the rule just to get it out there.
    // instead this data should be collected and checked in a single pass of definitions
    var known_fragment_ames = std.StringHashMap(void).init(ctx.allocator);
    defer known_fragment_ames.deinit();

    for (definitions) |definition| {
        switch (definition) {
            .ExecutableDefinition => |ex| switch (ex) {
                .FragmentDefinition => |frag| {
                    if (known_fragment_ames.contains(frag.name.value)) {
                        try ctx.addError(.DuplicateFragmentName);
                    } else {
                        try known_fragment_ames.put(frag.name.value, {});
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

// UniqueFragmentNamesRule

test "should allow no fragments" {
    try expectValid(checkUniqueFragmentNames,
        \\ {
        \\   field
        \\ }
    );
}

test "should allow one fragment" {
    try expectValid(checkUniqueFragmentNames,
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   field
        \\ }
    );
}

test "should allow multi fragment" {
    try expectValid(checkUniqueFragmentNames,
        \\ {
        \\   ...fragA
        \\   ...fragB
        \\   ...fragC
        \\ }
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragB on Type {
        \\   fieldB
        \\ }
        \\ fragment fragC on Type {
        \\   fieldC
        \\ }
    );
}

test "should allow unique inline fragments" {
    try expectValid(checkUniqueFragmentNames,
        \\ {
        \\   ...on Type {
        \\     fieldA
        \\   }
        \\   ...on Type {
        \\     fieldB
        \\   }
        \\ }
    );
}

test "should allow a fragment and operation named the same" {
    try expectValid(checkUniqueFragmentNames,
        \\ query Foo {
        \\   ...Foo
        \\ }
        \\ fragment Foo on Type {
        \\   field
        \\ }
    );
}

test "should return errors when fragments are named the same" {
    try expectErrors(checkUniqueFragmentNames,
        \\ {
        \\   ...fragA
        \\ }
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragA on Type {
        \\   fieldB
        \\ }
    , 1);
}

test "should return errors when fragments named the same without being referenced" {
    try expectErrors(checkUniqueFragmentNames,
        \\ fragment fragA on Type {
        \\   fieldA
        \\ }
        \\ fragment fragA on Type {
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
