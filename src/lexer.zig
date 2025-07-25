const std = @import("std");
const Token = @import("lib/tokens.zig").Token;
const TokenKind = @import("lib/tokens.zig").TokenKind;
const Cursor = @import("lib/cursor.zig").Cursor;
const LimitTracker = @import("lib/limit_tracker.zig").LimitTracker;

/// The `Lexer` struct is responsible for walking over GraphQL text and producing a stream of tokens.
///
pub const Lexer = struct {
    finished: bool,
    cursor: Cursor,
    limitTracker: LimitTracker,

    /// Initializes a new `Lexer` from source text without a limit on the number of tokens
    /// that can be scanned.
    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .finished = false,
            .cursor = Cursor.init(source),
            .limitTracker = LimitTracker.init(
                std.math.maxInt(usize),
            ),
        };
    }

    /// Initializes a new `Lexer` with a limit on the number of tokens that can be scanned.
    /// This is useful for bounded parsing.
    pub fn withLimit(self: Lexer, limit: usize) Lexer {
        return Lexer{
            .finished = self.finished,
            .cursor = self.cursor,
            .limitTracker = LimitTracker.init(limit),
        };
    }

    /// Fully lex the input stream and return a struct containing all tokens and all errors encountered.
    /// Errors from the allocator are propagated immediately.
    /// The caller is responsible for freeing both slices.
    pub fn lex(self: *Lexer, allocator: std.mem.Allocator) !struct {
        tokens: []Token,
        errors: []anyerror,
    } {
        var tokens = std.ArrayList(Token).init(allocator);
        var errors = std.ArrayList(anyerror).init(allocator);
        defer {
            tokens.deinit();
            errors.deinit();
        }

        while (true) {
            const result = self.next() catch |err| {
                // collect lexing errors or throw on non lexing errors (from allocator).
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

        // Return both tokens and errors, regardless of whether errors occurred.
        return .{
            .tokens = try tokens.toOwnedSlice(),
            .errors = try errors.toOwnedSlice(),
        };
    }

    /// Return the next token in the stream, or null if we have reached EOF.
    /// If a limit was set and reached, `LimitReached` is returned.
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
    const allocator = std.testing.allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(input)
        .withLimit(100);
    const result = try lexer.lex(allocator);
    defer {
        allocator.free(result.tokens);
        allocator.free(result.errors);
    }

    try std.testing.expect(result.tokens.len == 12);
    try std.testing.expect(result.errors.len == 0);
}

test "should parse string blocks as a single token" {
    const allocator = std.testing.allocator;
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

    const result = try lexer.lex(allocator);
    defer {
        allocator.free(result.tokens);
        allocator.free(result.errors);
    }
    try std.testing.expect(result.tokens.len == 18);
    try std.testing.expect(result.errors.len == 0);
}

test "should return error when limit is reached" {
    const allocator = std.testing.allocator;
    const input = "{ user { id } }"; // 12 tokens including EOF.

    var lexer = Lexer
        .init(input)
        .withLimit(10);

    const result = try lexer.lex(allocator);
    defer {
        allocator.free(result.tokens);
        allocator.free(result.errors);
    }
    try std.testing.expect(result.tokens.len == 10);
    try std.testing.expect(result.errors.len == 1);
}
