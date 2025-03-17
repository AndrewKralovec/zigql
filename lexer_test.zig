const std = @import("std");
const Lexer = @import("./lexer.zig").Lexer;
const expect = std.testing.expect;

test "should parse all tokens from input" {
    const allocator = std.heap.page_allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(allocator, input);

    const tokens = try lexer.lex();
    defer allocator.free(tokens);

    try expect(tokens.len == 12);
}

test "should return error when limit is reached" {
    const allocator = std.heap.page_allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(allocator, input)
        .withLimit(11);

    _ = lexer.lex() catch |err| {
        try expect(err == error.LexingFailed);
    };
}
