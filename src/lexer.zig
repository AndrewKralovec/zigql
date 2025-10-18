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
    pub fn lex(self: *Lexer, allocator: std.mem.Allocator) !LexResult {
        var tokens = std.ArrayList(Token).init(allocator);
        var errors = std.ArrayList(anyerror).init(allocator);
        defer {
            tokens.deinit();
            errors.deinit();
        }

        while (true) {
            const result = self.next() catch |err| {
                // collect lexing errors or throw on non lexing errors (from allocator or limitReached).
                try errors.append(err);
                switch (err) {
                    error.LimitReached => break, // If we hit the limit, stop lexing.
                    else => continue,
                }
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
    /// This method is safe to call after EOF has been reached.
    /// If a limit was set and reached, `LimitReached` is returned.
    /// Token parsing errors are propagated immediately.
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

    /// Return the next token in the stream, returning an error if EOF has been reached.
    /// If a limit was set and reached, `LimitReached` is returned.
    /// Token parsing errors are propagated immediately.
    pub fn read(self: *Lexer) !Token {
        const token = try self.next();
        if (token == null) {
            return error.ReadAfterEof;
        }
        return token.?;
    }
};

const LexResult = struct {
    tokens: []Token,
    errors: []anyerror,
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
    std.debug.print("Errors={any}\n", .{result.errors.len});
    try std.testing.expect(result.errors.len == 1);
}

test "should return error when limit is reached on read" {
    const allocator = std.heap.page_allocator;
    const source =
        \\ query {
        \\  users(id: 1) {
        \\   id
        \\  }
        \\ }
    ;
    var lexer = Lexer.init(source);
    const result = try lexer.lex(allocator);
    defer {
        allocator.free(result.tokens);
        allocator.free(result.errors);
    }

    for (result.tokens) |token| {
        std.debug.print("Token={any}\n", .{token});
    }
    for (result.errors) |err| {
        std.debug.print("Error={any}\n", .{err});
    }
}
