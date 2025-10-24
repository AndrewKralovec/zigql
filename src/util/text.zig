const std = @import("std");

/// Ignored tokens other than comments and commas are assimilated to whitespace
/// <https://spec.graphql.org/October2021/#Ignored>
pub fn isWhitespaceAssimilated(c: u8) bool {
    return switch (c) {
        // 9, 32, 10, 13, 254 => return true,
        // '\t', ' ', '\n', '\r', 0xFEFF => true,
        '\t', ' ', '\n', '\r' => true,
        else => false,
    };
}

/// <https://spec.graphql.org/October2021/#NameContinue>
pub fn isNameContinue(c: u8) bool {
    switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9', '_' => return true,
        else => return false,
    }
}

pub fn isAsciiHexDigit(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

pub fn isAsciiDigit(c: u8) bool {
    return std.ascii.isDigit(c);
}

pub fn isLineTerminator(c: u8) bool {
    return c == '\n' or c == '\r';
}

// EscapedCharacter
//     "  \  /  b  f  n  r  t
pub fn isEscapedChar(c: u8) bool {
    switch (c) {
        '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => return true,
        else => return false,
    }
}

pub fn isNameStart(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '_' => true,
        else => false,
    };
}
