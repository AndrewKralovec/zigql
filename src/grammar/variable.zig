const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../parser.zig").Parser;
const TokenKind = @import("../lib/tokens.zig").TokenKind;

const parseName = @import("./name.zig").parseName;
const parseTypeReference = @import("./type.zig").parseTypeReference;
const parseConstValueLiteral = @import("./value.zig").parseConstValueLiteral;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;

pub fn parseVariableDefinitions(p: *Parser) !?[]ast.VariableDefinitionNode {
    if (!try p.expectOptionalToken(TokenKind.LParen)) {
        return null;
    }

    var nodes = std.ArrayList(ast.VariableDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (p.peek()) |_| {
        p.debug("parseVariableDefinitions");
        const varDef = try parseVariableDefinition(p);
        try nodes.append(varDef);

        if (try p.expectOptionalToken(TokenKind.RParen)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseVariableDefinition(p: *Parser) !ast.VariableDefinitionNode {
    p.debug("parseVariableDefinition");
    const variable = try parseVariable(p);
    _ = try p.expect(TokenKind.Colon);
    const typeNode = try parseTypeReference(p);

    var defaultValue: ?ast.ValueNode = null;
    if (try p.expectOptionalToken(TokenKind.Eq)) {
        defaultValue = try parseConstValueLiteral(p);
    }

    const directives = try parseConstDirectives(p);

    return ast.VariableDefinitionNode{
        .variable = variable,
        .type = typeNode,
        .defaultValue = defaultValue,
        .directives = directives,
    };
}

pub fn parseVariable(p: *Parser) !ast.VariableNode {
    p.debug("parseVariable");
    _ = try p.expect(TokenKind.Dollar);
    const name = try parseName(p);
    return ast.VariableNode{
        .name = name,
    };
}
