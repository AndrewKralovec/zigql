const std = @import("std");
const ast = @import("../../ast/ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;

pub fn parseName(p: *Parser) !ast.NameNode {
    p.debug("parseName");
    const token = try p.expect(TokenKind.Name);
    return ast.NameNode{
        .value = token.data,
    };
}
