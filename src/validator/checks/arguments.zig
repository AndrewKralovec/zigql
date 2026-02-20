const std = @import("std");
const ast = @import("../../grammar/ast.zig");
const ValidationContext = @import("../validation_context.zig").ValidationContext;

// Unique argument names
//
// A GraphQL field or directive is only valid if all supplied arguments are
// uniquely named.
//
// See https://spec.graphql.org/draft/#sec-Argument-Names
pub fn checkUniqueArguments(ctx: *ValidationContext, definitions: []const ast.DefinitionNode) !void {
    // TODO: remove later. writing out a fn for the rule just to get it out there.
    // validation is doing multiple pass enhance laster
    for (definitions) |def| {
        switch (def) {
            .ExecutableDefinition => |ex| switch (ex) {
                .OperationDefinition => |op| {
                    try validateOperation(ctx, op);
                },
                .FragmentDefinition => |frag| {
                    try validateFragment(ctx, frag);
                },
            },
            else => {},
        }
    }
}

fn validateOperation(ctx: *ValidationContext, op: ast.OperationDefinitionNode) anyerror!void {
    if (op.directives) |directives| {
        for (directives) |directive| {
            try validateDirective(ctx, directive);
        }
    }

    if (op.selection_set) |sel_set| {
        try validateSelectionSet(ctx, sel_set);
    }
}

fn validateFragment(ctx: *ValidationContext, frag: ast.FragmentDefinitionNode) anyerror!void {
    if (frag.directives) |directives| {
        for (directives) |directive| {
            try validateDirective(ctx, directive);
        }
    }

    try validateSelectionSet(ctx, frag.selection_set);
}

fn validateSelectionSet(ctx: *ValidationContext, sel_set: ast.SelectionSetNode) anyerror!void {
    for (sel_set.selections) |selection| {
        switch (selection) {
            .Field => |field| try validateField(ctx, field),
            .FragmentSpread => |spread| try validateFragmentSpread(ctx, spread),
            .InlineFragment => |inline_frag| try validateInlineFragment(ctx, inline_frag),
        }
    }
}

fn validateField(ctx: *ValidationContext, field: ast.FieldNode) anyerror!void {
    try assertUniqueArguments(ctx, field.arguments);

    if (field.directives) |directives| {
        for (directives) |directive| {
            try validateDirective(ctx, directive);
        }
    }

    if (field.selection_set) |sel_set| {
        try validateSelectionSet(ctx, sel_set);
    }
}

fn validateFragmentSpread(ctx: *ValidationContext, spread: ast.FragmentSpreadNode) anyerror!void {
    if (spread.directives) |directives| {
        for (directives) |directive| {
            try validateDirective(ctx, directive);
        }
    }
}

fn validateInlineFragment(ctx: *ValidationContext, inline_frag: ast.InlineFragmentNode) anyerror!void {
    if (inline_frag.directives) |directives| {
        for (directives) |directive| {
            try validateDirective(ctx, directive);
        }
    }

    try validateSelectionSet(ctx, inline_frag.selection_set);
}

fn validateDirective(ctx: *ValidationContext, directive: ast.DirectiveNode) anyerror!void {
    try assertUniqueArguments(ctx, directive.arguments);
}

fn assertUniqueArguments(ctx: *ValidationContext, arguments: ?[]const ast.ArgumentNode) !void {
    const args = arguments orelse return;

    var seen = std.StringHashMap(bool).init(ctx.allocator);
    defer seen.deinit();

    for (args) |arg| {
        const name = arg.name.value;
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

// UniqueArgumentNamesRule

test "should allow fields with no arguments" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field
        \\ }
    );
}

test "should allow no arguments on directive" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field @directive
        \\ }
    );
}

test "should allow fields with one argument" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field(arg: "value")
        \\ }
    );
}

test "should allow argument on directive" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field @directive(arg: "value")
        \\ }
    );
}

test "should allow same argument on two fields" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   one: field(arg: "value")
        \\   two: field(arg: "value")
        \\ }
    );
}

test "should allow same argument on field and directive" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field(arg: "value") @directive(arg: "value")
        \\ }
    );
}

test "should allow same argument on two directives" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field @directive1(arg: "value") @directive2(arg: "value")
        \\ }
    );
}

test "should allow multiple field arguments" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field(arg1: "value", arg2: "value", arg3: "value")
        \\ }
    );
}

test "should allow multiple directive arguments" {
    try expectValid(checkUniqueArguments,
        \\ {
        \\   field @directive(arg1: "value", arg2: "value", arg3: "value")
        \\ }
    );
}

test "should return errors on duplicate field arguments" {
    try expectErrors(checkUniqueArguments,
        \\ {
        \\   field(arg1: "value", arg1: "value")
        \\ }
    , 1);
}

test "should return errors on many duplicate field arguments" {
    try expectErrors(checkUniqueArguments,
        \\ {
        \\   field(arg1: "value", arg1: "value", arg1: "value")
        \\ }
    , 1);
}

test "should return errors on duplicate directive arguments" {
    try expectErrors(checkUniqueArguments,
        \\ {
        \\   field @directive(arg1: "value", arg1: "value")
        \\ }
    , 1);
}

test "should return errors on many duplicate directive arguments" {
    try expectErrors(checkUniqueArguments,
        \\ {
        \\   field @directive(arg1: "value", arg1: "value", arg1: "value")
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
