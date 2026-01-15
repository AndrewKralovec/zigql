const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("../core/parser.zig").Parser;
const TokenKind = @import("../core/tokens.zig").TokenKind;

const parseDescription = @import("./description.zig").parseDescription;
const parseName = @import("./name.zig").parseName;
const parseConstDirectives = @import("./directive.zig").parseConstDirectives;
const parseConstValueLiteral = @import("./value.zig").parseConstValueLiteral;
const parseTypeReference = @import("./type.zig").parseTypeReference;

pub fn parseInputObjectTypeDefinition(p: *Parser) !ast.InputObjectTypeDefinitionNode {
    p.debug("parseInputObjectTypeDefinition");
    const description = try parseDescription(p);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Input);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const fields = try parseInputFieldsDefinition(p);

    return ast.InputObjectTypeDefinitionNode{
        .description = description,
        .name = name,
        .directives = directives,
        .fields = fields,
    };
}

pub fn parseInputFieldsDefinition(p: *Parser) !?[]ast.InputValueDefinitionNode {
    p.debug("parseInputFieldsDefinition");
    if (!try p.expectOptionalToken(TokenKind.LCurly)) {
        return null;
    }

    var nodes = std.ArrayList(ast.InputValueDefinitionNode).init(p.allocator);
    defer nodes.deinit();
    while (true) {
        const field = try parseInputValueDef(p);
        try nodes.append(field);

        if (try p.expectOptionalToken(TokenKind.RCurly)) {
            break;
        }
    }
    return try nodes.toOwnedSlice();
}

pub fn parseInputValueDef(p: *Parser) !ast.InputValueDefinitionNode {
    p.debug("parseInputValueDef");
    const name = try parseName(p);
    _ = try p.expect(TokenKind.Colon);
    const type_node = try parseTypeReference(p);
    var default_value: ?ast.ValueNode = null;
    if (try p.expectOptionalToken(TokenKind.Eq)) {
        default_value = try parseConstValueLiteral(p);
    }
    const directives = try parseConstDirectives(p);

    return ast.InputValueDefinitionNode{
        .name = name,
        .type = type_node,
        .default_value = default_value,
        .directives = directives,
    };
}

pub fn parseInputObjectTypeExtension(p: *Parser) !ast.InputObjectTypeExtensionNode {
    p.debug("parseInputObjectTypeExtension");
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Extend);
    _ = try p.expectKeyword(ast.SyntaxKeyWord.Input);
    const name = try parseName(p);
    const directives = try parseConstDirectives(p);
    const fields = try parseInputFieldsDefinition(p);

    const directives_empty = if (directives) |d| d.len == 0 else true;
    const fields_empty = if (fields) |f| f.len == 0 else true;
    if (directives_empty and fields_empty) {
        return error.UnexpectedToken;
    }

    return ast.InputObjectTypeExtensionNode{
        .name = name,
        .directives = directives,
        .fields = fields,
    };
}
