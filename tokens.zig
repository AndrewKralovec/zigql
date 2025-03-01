pub const Token = struct {
    kind: TokenKind,
    data: []const u8,
    index: usize,
};

pub const TokenKind = enum {
    Whitespace, // \r | \n |   | \t
    Comment, // # comment
    Bang, // !
    Dollar, // $
    Amp, // &
    Spread, // ...
    Comma, // ,
    Colon, // :
    Eq, // =
    At, // @
    LParen, // (
    RParen, // )
    LBracket, // [
    RBracket, // ]
    LCurly, // {
    RCurly, // }
    Pipe, // |
    Eof,

    // composite nodes
    Name,
    StringValue,
    Int,
    Float,
};

pub fn punctuationKind(c: u8) ?TokenKind {
    return switch (c) {
        '{' => TokenKind.LCurly,
        '}' => TokenKind.RCurly,
        '!' => TokenKind.Bang,
        '$' => TokenKind.Dollar,
        '&' => TokenKind.Amp,
        '(' => TokenKind.LParen,
        ')' => TokenKind.RParen,
        ':' => TokenKind.Colon,
        ',' => TokenKind.Comma,
        '[' => TokenKind.LBracket,
        ']' => TokenKind.RBracket,
        '=' => TokenKind.Eq,
        '@' => TokenKind.At,
        '|' => TokenKind.Pipe,
        else => null,
    };
}
