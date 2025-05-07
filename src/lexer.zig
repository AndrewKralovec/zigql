const std = @import("std");
const Token = @import("lib/tokens.zig").Token;
const TokenKind = @import("lib/tokens.zig").TokenKind;
const Cursor = @import("lib/cursor.zig").Cursor;
const LimitTracker = @import("lib/limit_tracker.zig").LimitTracker;

pub const Lexer = struct {
    finished: bool,
    cursor: Cursor,
    limitTracker: LimitTracker,

    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .finished = false,
            .cursor = Cursor.init(source),
            .limitTracker = LimitTracker.init(std.math.maxInt(usize)),
        };
    }

    pub fn withLimit(self: Lexer, limit: usize) Lexer {
        return Lexer{
            .finished = self.finished,
            .cursor = self.cursor,
            .limitTracker = LimitTracker.init(limit),
        };
    }

    pub fn lex(self: *Lexer, allocator: std.mem.Allocator) ![]Token {
        var tokens = std.ArrayList(Token).init(allocator);
        var errors = std.ArrayList(anyerror).init(allocator);
        defer tokens.deinit();
        defer errors.deinit();

        while (true) {
            const result = self.next() catch |err| {
                try errors.append(err);
                continue;
            };
            if (result == null) {
                break;
            } else {
                const token = result.?;
                try tokens.append(token);
            }
        }

        if (errors.items.len > 0) {
            return error.LexingFailed;
        }

        return tokens.toOwnedSlice();
    }

    pub fn next(self: *Lexer) !?Token {
        if (self.finished) return null;

        if (self.limitTracker.checkAndIncrement()) {
            self.finished = true;
            return error.LimitReached;
        }

        const token = try self.cursor.advance();
        if (token.kind == TokenKind.Eof) {
            self.finished = true;
        }
        return token;
    }
};

//
// Test cases for the Lexer
//

test "should parse all tokens from input" {
    const allocator = std.heap.page_allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(input)
        .withLimit(100);
    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);

    try std.testing.expect(tokens.len == 12);
}

test "should parse string blocks as a single token" {
    const allocator = std.heap.page_allocator;
    const input =
        \\ """
        \\ The query type, represents all of the entry points into our object graph
        \\ """
        \\ type Query {
        \\   users(): User
        \\ }
    ;
    var lexer = Lexer
        .init(input)
        .withLimit(100);

    const tokens = try lexer.lex(allocator);
    defer allocator.free(tokens);
    try std.testing.expect(tokens.len == 18);
}

test "should return error when limit is reached" {
    const allocator = std.heap.page_allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(input)
        .withLimit(11);

    _ = lexer.lex(allocator) catch |err| {
        try std.testing.expect(err == error.LexingFailed);
    };
}
