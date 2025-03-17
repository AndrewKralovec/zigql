const std = @import("std");
const tokens = @import("./tokens.zig");
const Cursor = @import("./cursor.zig").Cursor;
const expect = std.testing.expect;

test "should bump next character" {
    const input = "{ user { id } }";

    var cursor = Cursor.init(input);

    const c_opt = cursor.bump();
    const expected: u8 = input[0];
    const c = c_opt.?;
    try expect(c == expected);
}

test "should return current string after bump" {
    const input = "{ user { id } }";

    var cursor = Cursor.init(input);

    _ = cursor.bump();
    const current = cursor.currentStr();
    const expected = input[0..1];
    try expect(std.mem.eql(u8, current, expected));
}

test "should return previous string after bump" {
    const input = "{ user { id } }";

    var cursor = Cursor.init(input);

    _ = cursor.bump();
    const token = cursor.bump();
    const expectedT = ' ';
    const prev = cursor.prevStr();
    const expectedPre = input[0..1];

    try expect(token == expectedT);
    try expect(std.mem.eql(u8, prev, expectedPre));
}

test "should return null when bumping past end of input" {
    const input = "";

    var cursor = Cursor.init(input);
    const char = cursor.bump();
    try expect(char == null);
}

test "should advance cursor and parse token" {
    const input = "{ user { id } }";

    var cursor = Cursor.init(input);
    const token = try cursor.advance();
    try expect(token.kind == tokens.TokenKind.LCurly);
    try expect(token.data.len == 1);
    try expect(std.mem.eql(u8, token.data, "{"));
}

test "should return error when advancing on unexpected character" {
    const input = "*";

    var cursor = Cursor.init(input);
    _ = cursor.advance() catch |err| {
        try expect(err == error.UnexpectedChar);
        return;
    };
}
