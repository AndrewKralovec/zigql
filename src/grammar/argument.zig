const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseName = @import("./name.zig").parseName;
const parseValueLiteral = @import("./value.zig").parseValueLiteral;
const parseInputValueDef = @import("./input.zig").parseInputValueDef;

pub fn parseArguments(p: *Parser, isConst: bool) !?[]ast.ArgumentNode {
    p.debug("parseArguments");
    if (!try p.expectOptionalToken(TokenKind.LParen)) {
        return null;
    }

    var nodes = std.ArrayList(ast.ArgumentNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const arg = try parseArgument(p, isConst);
        try nodes.append(arg);

        if (try p.expectOptionalToken(TokenKind.RParen)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseArgument(p: *Parser, isConst: bool) !ast.ArgumentNode {
    p.debug("parseArgument");
    const name = try parseName(p);
    _ = try p.expect(TokenKind.Colon);

    const value = try parseValueLiteral(p, isConst);
    return ast.ArgumentNode{
        .name = name,
        .value = value,
    };
}

pub fn parseArgumentDefs(p: *Parser) !?[]ast.InputValueDefinitionNode {
    p.debug("parseArgumentDefs");
    if (!try p.expectOptionalToken(TokenKind.LParen)) {
        return null;
    }

    var nodes = std.ArrayList(ast.InputValueDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        const arg = try parseInputValueDef(p);
        try nodes.append(arg);

        if (try p.expectOptionalToken(TokenKind.RParen)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}
