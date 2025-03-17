const std = @import("std");
const text = @import("text.zig");
const tokens = @import("tokens.zig");
const CharIndices = text.CharIndices;
const Token = tokens.Token;
const TokenKind = tokens.TokenKind;

pub const Cursor = struct {
    index: usize,
    offset: usize,
    source: []const u8,
    chars: CharIndices,
    pending: ?u8,

    pub fn init(input: []const u8) Cursor {
        return Cursor{
            .index = 0,
            .offset = 0,
            .source = input,
            .chars = CharIndices.init(input),
            .pending = null,
        };
    }

    pub fn isPending(self: *Cursor) bool {
        return self.pending != null;
    }

    pub fn prevStr(self: *Cursor) []const u8 {
        const slice = self.source[self.index..self.offset];
        self.index = self.offset;
        if (self.offset < self.source.len) {
            self.pending = self.source[self.offset];
        } else {
            self.pending = null;
        }
        return slice;
    }

    pub fn currentStr(self: *Cursor) []const u8 {
        self.pending = null;

        const nxt = self.chars.next();
        if (nxt != null) {
            const current = self.index;
            self.index = nxt.?.pos;
            self.offset = nxt.?.pos;
            self.pending = nxt.?.char;
            return self.source[current..nxt.?.pos];
        } else {
            const current = self.index;
            self.index = self.source.len - 1;
            return self.source[current..];
        }
    }

    pub fn bump(self: *Cursor) ?u8 {
        if (self.pending) |c| {
            self.pending = null;
            return c;
        }

        if (self.offset >= self.source.len) {
            return null;
        }

        const ex = self.chars.next();
        if (ex == null) {
            return null;
        }
        const c = ex.?.char;
        self.offset = ex.?.pos;

        return c;
    }

    // TODO: Return error type.
    pub fn eatc(self: *Cursor, c: u8) bool {
        if (self.pending != null) {
            @panic("Don't call eatc when a character is pending");
        }

        if (self.offset < self.source.len) {
            const c_in = self.source[self.offset];
            self.offset += 1;

            if (c_in == c) {
                return true;
            }

            self.pending = c_in;
        }

        return false;
    }

    // TODO: Split this up into smaller functions. There seems to be a problem with the LLVM version when doing so.
    // Need to investigate further.
    pub fn advance(self: *Cursor) !Token {
        // TODO: Invalid record 'LLVM 18.1.7':
        // This code is a long running function because there seems to be a problem splitting the function into smaller parts.
        var state = State.Start;
        var token = Token{
            .kind = TokenKind.Eof,
            .data = "",
            .index = self.index,
        };

        while (true) {
            var c_opt = self.bump();
            if (c_opt == null) {
                // TODO: Fix llvm error (version: 0.14.0-dev.544+7aaebd17).
                // Make this long running block of code a self.eof func once zig is fixed.
                switch (state) {
                    State.Start => {
                        token.index = token.index + 1;
                        return token;
                    },
                    State.StringLiteralStart => {
                        return error.UnexpectedEndOfData;
                    },
                    State.StringLiteral, State.BlockStringLiteral, State.StringLiteralEscapedUnicode, State.BlockStringLiteralBackslash, State.StringLiteralBackslash => {
                        return error.UnterminatedString;
                    },
                    State.SpreadOperator => {
                        return error.UnterminatedSpreadOperator;
                    },
                    State.MinusSign => {
                        return error.UnexpectedCharacter;
                    },
                    State.DecimalPoint, State.ExponentIndicator, State.ExponentSign => {
                        return error.UnexpectedEOFInFloat;
                    },
                    State.Ident, State.LeadingZero, State.IntegerPart, State.FractionalPart, State.ExponentDigit, State.Whitespace, State.Comment => {
                        token.data = self.currentStr();
                        return token;
                    },
                }
            }
            const c = c_opt.?;
            c_opt = null; // TODO: trick compiler so i can use var, figure out proper way to do this in zig.
            switch (state) {
                State.Start => {
                    const t = tokens.punctuationKind(c);
                    if (t != null) {
                        token.kind = t.?;
                        token.data = self.currentStr();
                        return token;
                    }

                    if (text.isNameStart(c)) {
                        token.kind = TokenKind.Name;
                        state = State.Ident;
                        continue;
                    }

                    if (c != '0' and text.isAsciiDigit(c)) {
                        token.kind = TokenKind.Int;
                        state = State.IntegerPart;
                        continue;
                    }

                    switch (c) {
                        '"' => {
                            token.kind = TokenKind.StringValue;
                            state = State.StringLiteralStart;
                        },
                        '#' => {
                            token.kind = TokenKind.Comment;
                            state = State.Comment;
                        },
                        '.' => {
                            token.kind = TokenKind.Spread;
                            state = State.SpreadOperator;
                        },
                        '-' => {
                            token.kind = TokenKind.Int;
                            state = State.MinusSign;
                        },
                        '0' => {
                            token.kind = TokenKind.Int;
                            state = State.LeadingZero;
                        },
                        else => {
                            if (text.isWhitespaceAssimilated(c)) {
                                token.kind = TokenKind.Whitespace;
                                state = State.Whitespace;
                            } else {
                                return error.UnexpectedChar;
                            }
                        },
                    }
                },
                State.Ident => {
                    if (text.isNameContinue(c)) {
                        continue;
                    }
                    token.data = self.prevStr();
                    return token;
                },
                State.Whitespace => {
                    if (text.isWhitespaceAssimilated(c)) {
                        continue;
                    }
                    token.data = self.prevStr();
                    return token;
                },
                State.BlockStringLiteral => {
                    switch (c) {
                        '\\' => {
                            state = State.BlockStringLiteral;
                        },
                        '"' => {
                            // Require two additional quotes to complete the triple quote.
                            if (self.eatc('"') and self.eatc('"')) {
                                token.data = self.currentStr();
                                return token;
                            }
                        },
                        else => {},
                    }
                },
                State.StringLiteralStart => {
                    switch (c) {
                        '"' => {
                            if (self.eatc('"')) {
                                state = State.BlockStringLiteral;
                                continue;
                            }

                            if (self.isPending()) {
                                token.data = self.prevStr();
                            } else {
                                token.data = self.currentStr();
                            }

                            return token;
                        },
                        '\\' => {
                            state = State.StringLiteralBackslash;
                        },
                        else => {
                            state = State.StringLiteral;
                            continue;
                        },
                    }
                },
                State.StringLiteralEscapedUnicode => {
                    if (c == '"') {
                        return error.IncompleteUnicode;
                    } else if (text.isAsciiHexDigit(c)) {
                        return error.IncompleteUnicodeEscapeSequence;
                    } else {
                        state = State.StringLiteral;
                        continue;
                    }
                },
                State.StringLiteral => {
                    switch (c) {
                        '"' => {
                            token.data = self.currentStr();
                            return token;
                        },
                        '\\' => {
                            state = State.StringLiteralBackslash;
                        },
                        else => {
                            if (text.isLineTerminator(c)) {
                                return error.UnexpectedLineTerminator;
                            }
                        },
                    }
                },
                State.BlockStringLiteralBackslash => {
                    switch (c) {
                        '"' => {
                            // If this is \""", we need to eat 3 in total, and then continue parsing.
                            // The lexer does not un-escape escape sequences so it's OK
                            // if we take this path for \"", even if that is technically not an escape
                            // sequence.
                            if (self.eatc(c)) {
                                _ = self.eatc('"');
                            }
                            state = State.BlockStringLiteral;
                        },
                        // We need to stay in the backslash state:
                        // it's legal to write \\\""" with two literal backslashes
                        // and then the escape sequence.
                        '\\' => {},
                        else => {
                            state = State.BlockStringLiteral;
                        },
                    }
                },
                State.StringLiteralBackslash => {
                    if (text.isEscapedChar(c)) {
                        state = State.StringLiteral;
                    } else if (c == 'u') {
                        state = State.StringLiteralEscapedUnicode;
                    } else {
                        return error.UnexpectedCharacter;
                    }
                },
                State.LeadingZero => {
                    if (c == '.') {
                        token.kind = TokenKind.Float;
                        state = State.DecimalPoint;
                    } else if (c == 'e' or c == 'E') {
                        token.kind = TokenKind.Float;
                        state = State.ExponentIndicator;
                    } else if (text.isAsciiHexDigit(c)) {
                        return error.LeadingZero;
                    } else if (text.isNameStart(c)) {
                        return error.UnexpectedCharacter;
                    } else {
                        token.data = self.prevStr();
                        return token;
                    }
                },
                State.IntegerPart => {
                    if (text.isAsciiHexDigit(c)) {
                        continue;
                    }
                    if (c == '.') {
                        token.kind = TokenKind.Float;
                        state = State.DecimalPoint;
                    } else if (c == 'e' or c == 'E') {
                        token.kind = TokenKind.Float;
                        state = State.ExponentIndicator;
                    } else if (text.isNameStart(c)) {
                        return error.UnexpectedCharacter;
                    } else {
                        token.data = self.prevStr();
                        return token;
                    }
                },
                State.DecimalPoint => {
                    if (text.isAsciiDigit(c)) {
                        state = State.FractionalPart;
                    } else {
                        return error.UnexpectedCharacter;
                    }
                },
                State.FractionalPart => {
                    if (text.isAsciiDigit(c)) {
                        continue;
                    }
                    if (c == 'e' or c == 'E') {
                        state = State.ExponentIndicator;
                    } else if (c == '.' or text.isNameStart(c)) {
                        return error.UnexpectCharacterAsFloatSuffix;
                    } else {
                        token.data = self.prevStr();
                        return token;
                    }
                },
                State.ExponentIndicator => {
                    if (text.isAsciiDigit(c)) {
                        state = State.ExponentDigit;
                    } else if (c == '+' or c == '-') {
                        state = State.ExponentSign;
                    } else {
                        return error.UnexpectedCharacter;
                    }
                },
                State.ExponentSign => {
                    if (text.isAsciiDigit(c)) {
                        state = State.ExponentDigit;
                    } else {
                        return error.UnexpectedCharacter;
                    }
                },
                State.ExponentDigit => {
                    if (text.isAsciiDigit(c)) {
                        continue;
                    }
                    if (c == '.' or text.isNameStart(c)) {
                        return error.UnexpectCharacterAsFloatSuffix;
                    } else {
                        token.data = self.prevStr();
                        return token;
                    }
                },
                State.SpreadOperator => {
                    if (c == '.' and self.eatc('.')) {
                        token.data = self.currentStr();
                        return token;
                    }
                    return error.UnterminatedSpreadOperator;
                },
                State.MinusSign => {
                    if (c == '0') {
                        state = State.LeadingZero;
                    } else if (text.isAsciiDigit(c)) {
                        state = State.IntegerPart;
                    } else {
                        return error.UnexpectedCharacter;
                    }
                },
                State.Comment => {
                    if (text.isLineTerminator(c)) {
                        token.data = self.prevStr();
                        return token;
                    }
                },
            }
        }
    }
};

const State = union(enum) {
    Start,
    Ident,
    StringLiteralEscapedUnicode,
    StringLiteral,
    StringLiteralStart,
    BlockStringLiteral,
    BlockStringLiteralBackslash,
    StringLiteralBackslash,
    LeadingZero,
    IntegerPart,
    DecimalPoint,
    FractionalPart,
    ExponentIndicator,
    ExponentSign,
    ExponentDigit,
    Whitespace,
    Comment,
    SpreadOperator,
    MinusSign,
};
