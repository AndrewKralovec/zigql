const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

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
    while (true) {
        p.debug("parseVariableDefinitions");
        const var_def = try parseVariableDefinition(p);
        try nodes.append(var_def);

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
    const type_node = try parseTypeReference(p);

    var default_value: ?ast.ValueNode = null;
    if (try p.expectOptionalToken(TokenKind.Eq)) {
        default_value = try parseConstValueLiteral(p);
    }

    const directives = try parseConstDirectives(p);

    return ast.VariableDefinitionNode{
        .variable = variable,
        .type = type_node,
        .default_value = default_value,
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
