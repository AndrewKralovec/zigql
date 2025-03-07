const std = @import("std");
const Token = @import("tokens.zig").Token;
const TokenKind = @import("tokens.zig").TokenKind;
const Cursor = @import("cursor.zig").Cursor;

pub const Lexer = struct {
    finished: bool,
    allocator: std.mem.Allocator,
    cursor: Cursor,
    limitTracker: LimitTracker,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return Lexer{
            .finished = false,
            .allocator = allocator,
            .cursor = Cursor.init(source),
            .limitTracker = LimitTracker.init(std.math.maxInt(usize)),
        };
    }

    pub fn withLimit(self: Lexer, limit: usize) Lexer {
        return Lexer{
            .finished = self.finished,
            .allocator = self.allocator,
            .cursor = self.cursor,
            .limitTracker = LimitTracker.init(limit),
        };
    }

    pub fn lex(self: *Lexer) ![]Token {
        var tokens = std.ArrayList(Token).init(self.allocator);
        var errors = std.ArrayList(anyerror).init(self.allocator);
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

pub const LimitTracker = struct {
    limit: usize,
    current: usize,

    pub fn init(limit: usize) LimitTracker {
        return LimitTracker{
            .limit = limit,
            .current = 0,
        };
    }

    pub fn checkAndIncrement(self: *LimitTracker) bool {
        if (self.current >= self.limit) {
            return true;
        }
        self.current += 1;
        return false;
    }
};
